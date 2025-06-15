# lib/frestyl/portfolios.ex
defmodule Frestyl.Portfolios do
  @moduledoc """
  The Portfolios context.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Portfolios.{Portfolio, PortfolioSection, PortfolioMedia,
                          PortfolioShare, PortfolioVisit}
  alias Frestyl.Accounts.User
  alias Frestyl.Portfolios.{Portfolio, PortfolioFeedback, PortfolioVisit}
  alias Frestyl.Notifications

  # Portfolio CRUD operations

  def list_user_portfolios(user_id) do
    Portfolio
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], desc: p.updated_at)
    |> Repo.all()
  end

  def get_portfolio!(id), do: Repo.get!(Portfolio, id)

  def list_section_media(section_id) do
    Repo.all(
      from pm in PortfolioMedia,
      where: pm.section_id == ^section_id,
      order_by: [asc: pm.position, asc: pm.inserted_at]
    )
  end

  def get_portfolio_by_slug!(user_id, slug) do
    Repo.get_by!(Portfolio, user_id: user_id, slug: slug)
  end

  def get_portfolio_by_slug(slug) do
    Repo.get_by(Portfolio, slug: slug)
  end

  def get_portfolio_for_share!(share_token) do
    share = get_share_by_token!(share_token)

    Repo.get!(Portfolio, share.portfolio_id)
    |> Repo.preload([:portfolio_sections, :portfolio_media])
  end

  def get_portfolio_customization(portfolio_id) do
    case get_portfolio!(portfolio_id) do
      nil -> %{}
      portfolio -> portfolio.customization || %{}
    end
  end

  def create_portfolio(user_id, attrs \\ %{}) do
    %Portfolio{user_id: user_id}
    |> Portfolio.changeset(attrs)
    |> Repo.insert()
  end

  def update_portfolio(%Portfolio{} = portfolio, attrs) do
    portfolio
    |> Portfolio.changeset(attrs)
    |> Repo.update()
  end

  def delete_portfolio(%Portfolio{} = portfolio) do
    Repo.delete(portfolio)
  end

  # Portfolio Section operations

  def list_portfolio_sections(portfolio_id) do
    PortfolioSection
    |> where([s], s.portfolio_id == ^portfolio_id)
    |> order_by([s], s.position)
    |> Repo.all()
  end

  def get_section!(id), do: Repo.get!(PortfolioSection, id)

  def create_section(attrs \\ %{}) do
    %PortfolioSection{}
    |> PortfolioSection.changeset(attrs)
    |> Repo.insert()
  end

  def update_section(%PortfolioSection{} = section, attrs) do
    section
    |> PortfolioSection.changeset(attrs)
    |> Repo.update()
  end

  def delete_section(%PortfolioSection{} = section) do
    Repo.delete(section)
  end

  # Portfolio Media operations

  def create_media(attrs) do
    %PortfolioMedia{}
    |> PortfolioMedia.changeset(attrs)
    |> Repo.insert()
  end

  def list_section_media(section_id) do
    from(m in PortfolioMedia,
      where: m.section_id == ^section_id,
      order_by: [asc: m.position, asc: m.inserted_at])
    |> Repo.all()
  end

  def list_portfolio_media(portfolio_id) do
    from(m in PortfolioMedia,
      where: m.portfolio_id == ^portfolio_id,
      order_by: [asc: m.position, asc: m.inserted_at])
    |> Repo.all()
  end

  def get_media!(id), do: Repo.get!(PortfolioMedia, id)

  def delete_media(media) do
    Repo.delete(media)
  end

  def update_media(media, attrs) do
    media
    |> PortfolioMedia.changeset(attrs)
    |> Repo.update()
  end

  def get_portfolio_analytics(portfolio_id, user_id) do
    # Placeholder - implement your analytics logic
    %{
      total_visits: 0,
      unique_visitors: 0,
      last_visit: nil
    }
  end

  def get_portfolio_by_slug_with_sections_simple(slug) do
    # Create the ordered sections query separately
    sections_query = from s in PortfolioSection, order_by: s.position

    query = from p in Portfolio,
      where: p.slug == ^slug,
      preload: [portfolio_sections: ^sections_query]

    case Repo.one(query) do
      nil -> {:error, :not_found}
      portfolio -> {:ok, portfolio}
    end
  end

  # Portfolio Share operations

  def list_portfolio_shares(portfolio_id) do
    PortfolioShare
    |> where([s], s.portfolio_id == ^portfolio_id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def get_share!(id), do: Repo.get!(PortfolioShare, id)

  def get_share_by_token!(token) do
    Repo.get_by!(PortfolioShare, token: token)
  end

  def get_share_by_token(token) do
    Repo.get_by(PortfolioShare, token: token)
  end

  def change_share(%PortfolioShare{} = share, attrs \\ %{}) do
    PortfolioShare.changeset(share, attrs)
  end

  def create_share(attrs \\ %{}) do
    %PortfolioShare{}
    |> PortfolioShare.changeset(attrs)
    |> Repo.insert()
  end

  def update_share(%PortfolioShare{} = share, attrs) do
    share
    |> PortfolioShare.changeset(attrs)
    |> Repo.update()
  end

  def delete_share(%PortfolioShare{} = share) do
    Repo.delete(share)
  end

  def track_share_access(%PortfolioShare{} = share) do
    share
    |> PortfolioShare.changeset(%{
      access_count: share.access_count + 1,
      last_accessed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  # Portfolio Visit operations

  def create_visit(attrs \\ %{}) do
    %PortfolioVisit{}
    |> PortfolioVisit.changeset(attrs)
    |> Repo.insert()
  end

  def get_portfolio_visit_stats(portfolio_id) do
    from(v in PortfolioVisit,
      where: v.portfolio_id == ^portfolio_id,
      group_by: fragment("date_trunc('day', ?)", v.inserted_at),
      select: {
        fragment("date_trunc('day', ?)", v.inserted_at),
        count(v.id)
      },
      order_by: fragment("date_trunc('day', ?)", v.inserted_at)
    )
    |> Repo.all()
  end

  defp get_feedback_stats(portfolio_id) do
    try do
      # Only try to get feedback stats if the table exists
      query = from f in PortfolioFeedback,
        where: f.portfolio_id == ^portfolio_id,
        group_by: f.status,
        select: {f.status, count(f.id)}

      stats = Repo.all(query) |> Enum.into(%{})

      %{
        total: Map.values(stats) |> Enum.sum(),
        pending: Map.get(stats, :pending, 0),
        reviewed: Map.get(stats, :reviewed, 0),
        implemented: Map.get(stats, :implemented, 0),
        dismissed: Map.get(stats, :dismissed, 0)
      }
    rescue
      _ ->
        # Return safe defaults if PortfolioFeedback doesn't exist yet
        %{
          total: 0,
          pending: 0,
          reviewed: 0,
          implemented: 0,
          dismissed: 0
        }
    end
  end

  # Resume parsing functions

  @doc """
  Parse a resume file and extract information.
  This is a placeholder for the actual implementation.
  """
  def parse_resume(file) do
    # Placeholder for resume parsing logic
    # This would integrate with an AI service or use a rule-based parser

    # For now, return a stub structure
    {:ok, %{
      personal_info: %{
        name: "",
        email: "",
        phone: "",
        location: ""
      },
      experience: [],
      education: [],
      skills: []
    }}
  end

  # ATS optimization helpers

  @doc """
  Optimize a resume section for ATS compatibility.
  This is a placeholder for the actual implementation.
  """
  def optimize_for_ats(section, job_description \\ nil) do
    # Placeholder for ATS optimization logic
    # This would use AI to enhance the content
    {:ok, section}
  end

  # Portfolio setup helpers

  def create_default_portfolio(user_id, attrs \\ %{}) do
    # Generate a unique slug if not provided
    title = Map.get(attrs, :title, "My Professional Portfolio")
    slug = case Map.get(attrs, :slug) do
      nil -> generate_unique_slug(title)
      existing_slug -> existing_slug
    end

    # Get template configuration
    theme = Map.get(attrs, :theme, "executive")
    template_config = Frestyl.Portfolios.PortfolioTemplates.get_template_config(theme)

    # Prepare portfolio attributes with defaults
    portfolio_attrs = %{
      title: title,
      slug: slug,
      description: Map.get(attrs, :description, "Welcome to my professional portfolio"),
      theme: theme,
      customization: Map.get(attrs, :customization, template_config),
      visibility: Map.get(attrs, :visibility, :link_only),
      user_id: user_id
    }

    case create_portfolio(user_id, portfolio_attrs) do
      {:ok, portfolio} ->
        # Create default sections based on template
        create_default_sections(portfolio, theme)
        {:ok, portfolio}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Create default sections based on template type
  defp create_default_sections(portfolio, template) do
    sections = case template do
      "executive" -> [
        %{
          title: "Executive Summary",
          section_type: :intro,
          position: 1,
          content: %{
            "headline" => "Professional Executive",
            "summary" => "Results-driven leader with proven track record of success.",
            "location" => "Your City, State"
          }
        },
        %{
          title: "Professional Experience",
          section_type: :experience,
          position: 2,
          content: %{"jobs" => []}
        },
        %{
          title: "Key Achievements",
          section_type: :achievements,
          position: 3,
          content: %{"achievements" => []}
        },
        %{
          title: "Education",
          section_type: :education,
          position: 4,
          content: %{"education" => []}
        },
        %{
          title: "Contact Information",
          section_type: :contact,
          position: 5,
          content: %{"email" => "", "phone" => "", "location" => ""}
        }
      ]

      "developer" -> [
        %{
          title: "About Me",
          section_type: :intro,
          position: 1,
          content: %{
            "headline" => "Software Developer",
            "summary" => "Passionate developer creating innovative solutions.",
            "location" => "Your City, State"
          }
        },
        %{
          title: "Featured Projects",
          section_type: :projects,
          position: 2,
          content: %{"projects" => []}
        },
        %{
          title: "Technical Skills",
          section_type: :skills,
          position: 3,
          content: %{"skills" => []}
        },
        %{
          title: "Experience",
          section_type: :experience,
          position: 4,
          content: %{"jobs" => []}
        },
        %{
          title: "Contact",
          section_type: :contact,
          position: 5,
          content: %{"email" => "", "phone" => "", "location" => ""}
        }
      ]

      "designer" -> [
        %{
          title: "Creative Introduction",
          section_type: :intro,
          position: 1,
          content: %{
            "headline" => "Creative Designer",
            "summary" => "Bringing ideas to life through thoughtful design.",
            "location" => "Your City, State"
          }
        },
        %{
          title: "Featured Work",
          section_type: :media_showcase,
          position: 2,
          content: %{
            "title" => "Portfolio Gallery",
            "description" => "A showcase of my best creative work"
          }
        },
        %{
          title: "Case Studies",
          section_type: :case_study,
          position: 3,
          content: %{
            "client" => "",
            "project_title" => "",
            "overview" => ""
          }
        },
        %{
          title: "Skills & Tools",
          section_type: :skills,
          position: 4,
          content: %{"skills" => []}
        },
        %{
          title: "Let's Connect",
          section_type: :contact,
          position: 5,
          content: %{"email" => "", "phone" => "", "location" => ""}
        }
      ]

      "consultant" -> [
        %{
          title: "Professional Overview",
          section_type: :intro,
          position: 1,
          content: %{
            "headline" => "Business Consultant",
            "summary" => "Driving business growth through strategic insights.",
            "location" => "Your City, State"
          }
        },
        %{
          title: "Client Results",
          section_type: :achievements,
          position: 2,
          content: %{"achievements" => []}
        },
        %{
          title: "Case Studies",
          section_type: :case_study,
          position: 3,
          content: %{
            "client" => "",
            "project_title" => "",
            "overview" => ""
          }
        },
        %{
          title: "Expertise Areas",
          section_type: :skills,
          position: 4,
          content: %{"skills" => []}
        },
        %{
          title: "Client Testimonials",
          section_type: :testimonial,
          position: 5,
          content: %{"testimonials" => []}
        },
        %{
          title: "Contact",
          section_type: :contact,
          position: 6,
          content: %{"email" => "", "phone" => "", "location" => ""}
        }
      ]

      "academic" -> [
        %{
          title: "Academic Profile",
          section_type: :intro,
          position: 1,
          content: %{
            "headline" => "Academic Researcher",
            "summary" => "Advancing knowledge through research and teaching.",
            "location" => "University, City"
          }
        },
        %{
          title: "Research Highlights",
          section_type: :projects,
          position: 2,
          content: %{"projects" => []}
        },
        %{
          title: "Publications",
          section_type: :achievements,
          position: 3,
          content: %{"achievements" => []}
        },
        %{
          title: "Education",
          section_type: :education,
          position: 4,
          content: %{"education" => []}
        },
        %{
          title: "Teaching Experience",
          section_type: :experience,
          position: 5,
          content: %{"jobs" => []}
        },
        %{
          title: "Contact Information",
          section_type: :contact,
          position: 6,
          content: %{"email" => "", "phone" => "", "location" => ""}
        }
      ]

      _ ->
        # Default sections for any template
        [
          %{
            title: "Introduction",
            section_type: :intro,
            position: 1,
            content: %{
              "headline" => "Welcome to My Portfolio",
              "summary" => "Brief introduction about yourself and your professional journey.",
              "location" => "Your City, State"
            }
          },
          %{
            title: "Experience",
            section_type: :experience,
            position: 2,
            content: %{"jobs" => []}
          },
          %{
            title: "Skills",
            section_type: :skills,
            position: 3,
            content: %{"skills" => []}
          },
          %{
            title: "Contact",
            section_type: :contact,
            position: 4,
            content: %{"email" => "", "phone" => "", "location" => ""}
          }
        ]
    end

    # Create all sections
    Enum.each(sections, fn section_attrs ->
      section_attrs = Map.put(section_attrs, :portfolio_id, portfolio.id)
      case create_section(section_attrs) do
        {:ok, _section} -> :ok
        {:error, error} ->
          IO.puts("Warning: Failed to create section #{section_attrs.title}: #{inspect(error)}")
      end
    end)
  end

  # Subscription tier checks

  def can_create_portfolio?(%User{} = user) do
    # Logic to check if user can create (more) portfolios based on their subscription
    # For free tier, limit to 2 portfolios (updated from 1)
    case user.subscription_tier do
      "free" ->
        portfolio_count =
          Portfolio
          |> where([p], p.user_id == ^user.id)
          |> Repo.aggregate(:count, :id)

        portfolio_count < 2  # Updated limit

      _ -> true
    end
  end

  def get_portfolio_limits(%User{} = user) do
    # Return portfolio feature limits based on user's subscription tier
    case user.subscription_tier do
      "free" -> %{
        max_portfolios: 2,  # Updated from 1
        custom_domain: false,
        advanced_analytics: false,
        custom_themes: false,
        max_media_size_mb: 50,
        ats_optimization: false,
        collaboration_features: true,  # New feature
        stats_visibility: true,        # New feature
        video_recording: true          # New feature
      }
      "basic" -> %{
        max_portfolios: 5,  # Increased
        custom_domain: false,
        advanced_analytics: true,
        custom_themes: true,
        max_media_size_mb: 200,
        ats_optimization: false,
        collaboration_features: true,
        stats_visibility: true,
        video_recording: true
      }
      "premium" -> %{
        max_portfolios: 15,  # Increased
        custom_domain: true,
        advanced_analytics: true,
        custom_themes: true,
        max_media_size_mb: 500,
        ats_optimization: true,
        collaboration_features: true,
        stats_visibility: true,
        video_recording: true
      }
      "pro" -> %{
        max_portfolios: -1, # unlimited
        custom_domain: true,
        advanced_analytics: true,
        custom_themes: true,
        max_media_size_mb: 1000,
        ats_optimization: true,
        collaboration_features: true,
        stats_visibility: true,
        video_recording: true
      }
      _ -> %{
        max_portfolios: 2,
        custom_domain: false,
        advanced_analytics: false,
        custom_themes: false,
        max_media_size_mb: 50,
        ats_optimization: false,
        collaboration_features: true,
        stats_visibility: true,
        video_recording: true
      }
    end
  end

  @doc """
  Gets the number of visits for a portfolio in the last 7 days.
  """
  def get_weekly_visits(portfolio_id) do
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 60 * 60, :second)

    from(v in PortfolioVisit,
      where: v.portfolio_id == ^portfolio_id,
      where: v.inserted_at >= ^seven_days_ago,
      select: count(v.id)
    )
    |> Repo.one()
  end

  @doc """
  Gets the number of visits for a portfolio today.
  """
  def get_daily_visits(portfolio_id) do
    today = Date.utc_today()
    start_of_day = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(today, ~T[23:59:59], "Etc/UTC")

    from(v in PortfolioVisit,
      where: v.portfolio_id == ^portfolio_id,
      where: v.inserted_at >= ^start_of_day,
      where: v.inserted_at <= ^end_of_day,
      select: count(v.id)
    )
    |> Repo.one()
  end

  @doc """
  Gets visit statistics for a portfolio.
  """
  def get_portfolio_stats(portfolio_id) do
    %{
      total_visits: get_total_visits(portfolio_id),
      weekly_visits: get_weekly_visits(portfolio_id),
      daily_visits: get_daily_visits(portfolio_id),
      unique_visits: get_unique_visits(portfolio_id)
    }
  end

  @doc """
  Gets recent visits for a portfolio with pagination.
  """
  def get_recent_visits(portfolio_id, limit \\ 10) do
    from(v in PortfolioVisit,
      where: v.portfolio_id == ^portfolio_id,
      order_by: [desc: v.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  # Additional helper functions that might be missing

  @doc """
  Gets portfolio by slug for public viewing (simpler version)
  """
  def get_portfolio_by_slug_public(slug) do
    query = from p in Portfolio,
      where: p.slug == ^slug and p.visibility != :private,
      preload: [:user, portfolio_sections: []]

    case Repo.one(query) do
      nil -> {:error, :not_found}
      portfolio -> {:ok, portfolio}
    end
  end

  @doc """
  Lists portfolio sections ordered by position
  """
  def list_portfolio_sections_ordered(portfolio_id) do
    from(s in PortfolioSection,
      where: s.portfolio_id == ^portfolio_id and s.visible == true,
      order_by: [asc: s.position, asc: s.id]
    )
    |> Repo.all()
  end

  @doc """
  Gets portfolio metadata for sharing
  """
  def get_portfolio_metadata(portfolio_id) do
    from(p in Portfolio,
      where: p.id == ^portfolio_id,
      select: %{
        id: p.id,
        title: p.title,
        description: p.description,
        slug: p.slug,
        visibility: p.visibility,
        updated_at: p.updated_at
      }
    )
    |> Repo.one()
  end

  @doc """
  Checks if portfolio is publicly accessible
  """
  def portfolio_public?(portfolio) do
    portfolio.visibility in [:public, :link_only]
  end

  @doc """
  Gets portfolio owner information
  """
  def get_portfolio_owner(portfolio_id) do
    from(p in Portfolio,
      join: u in User, on: u.id == p.user_id,
      where: p.id == ^portfolio_id,
      select: %{
        id: u.id,
        name: u.name,
        username: u.username,
        email: u.email
      }
    )
    |> Repo.one()
  end

  @doc """
  Updates portfolio visibility
  """
  def update_portfolio_visibility(portfolio, visibility) do
    portfolio
    |> Portfolio.changeset(%{visibility: visibility})
    |> Repo.update()
  end

  @doc """
  Gets portfolio sharing statistics
  """
  def get_portfolio_share_stats(portfolio_id) do
    total_shares = from(s in PortfolioShare,
      where: s.portfolio_id == ^portfolio_id)
      |> Repo.aggregate(:count, :id)

    active_shares = from(s in PortfolioShare,
      where: s.portfolio_id == ^portfolio_id and
            (is_nil(s.expires_at) or s.expires_at > ^DateTime.utc_now()))
      |> Repo.aggregate(:count, :id)

    total_share_views = from(s in PortfolioShare,
      where: s.portfolio_id == ^portfolio_id)
      |> Repo.aggregate(:sum, :view_count)

    %{
      total_shares: total_shares,
      active_shares: active_shares,
      total_share_views: total_share_views || 0
    }
  end

  @doc """
  Validates portfolio slug availability
  """
  def slug_available?(slug, portfolio_id \\ nil) do
    query = from(p in Portfolio, where: p.slug == ^slug)

    query = if portfolio_id do
      from(p in query, where: p.id != ^portfolio_id)
    else
      query
    end

    !Repo.exists?(query)
  end

  @doc """
  Generates a unique slug for a portfolio
  """
  def generate_unique_slug(title, portfolio_id \\ nil) do
    base_slug = title
      |> String.downcase()
      |> String.replace(~r/[^\w\s-]/, "")
      |> String.replace(~r/\s+/, "-")
      |> String.slice(0, 50)

    if slug_available?(base_slug, portfolio_id) do
      base_slug
    else
      # Append a number to make it unique
      1..100
      |> Enum.find_value(fn i ->
        candidate = "#{base_slug}-#{i}"
        if slug_available?(candidate, portfolio_id), do: candidate
      end) || "#{base_slug}-#{System.unique_integer([:positive])}"
    end
  end

  @doc """
  Archives a portfolio (soft delete)
  """
  def archive_portfolio(portfolio) do
    portfolio
    |> Portfolio.changeset(%{
      archived: true,
      archived_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Restores an archived portfolio
  """
  def restore_portfolio(portfolio) do
    portfolio
    |> Portfolio.changeset(%{
      archived: false,
      archived_at: nil
    })
    |> Repo.update()
  end

  @doc """
  Lists user's portfolios with filtering options
  """
  def list_user_portfolios_filtered(user_id, opts \\ []) do
    query = from p in Portfolio,
      where: p.user_id == ^user_id

    query = case Keyword.get(opts, :archived, false) do
      true -> from p in query, where: p.archived == true
      false -> from p in query, where: is_nil(p.archived) or p.archived == false
      :all -> query
    end

    query = case Keyword.get(opts, :visibility) do
      nil -> query
      visibility -> from p in query, where: p.visibility == ^visibility
    end

    order_by = Keyword.get(opts, :order_by, [desc: :updated_at])

    query
    |> order_by(^order_by)
    |> Repo.all()
  end

    @doc """
  Gets the total number of visits for a portfolio.

  ## Examples

      iex> get_total_visits(portfolio_id)
      42

  """
  def get_total_visits(portfolio_id) do
    from(v in PortfolioVisit,
      where: v.portfolio_id == ^portfolio_id,
      select: count(v.id)
    )
    |> Repo.one()
  end

  @doc """
  Gets the total number of unique visits for a portfolio (by IP address).

  ## Examples

      iex> get_unique_visits(portfolio_id)
      25

  """
  def get_unique_visits(portfolio_id) do
    from(v in PortfolioVisit,
      where: v.portfolio_id == ^portfolio_id,
      distinct: v.ip_address,
      select: count(v.id)
    )
    |> Repo.one()
  end

  @doc """
  Gets visit statistics for a portfolio within a date range.

  ## Examples

      iex> get_visits_in_range(portfolio_id, ~D[2025-01-01], ~D[2025-01-31])
      %{total: 42, unique: 25}

  """
  def get_visits_in_range(portfolio_id, start_date, end_date) do
    start_datetime = DateTime.new!(start_date, ~T[00:00:00])
    end_datetime = DateTime.new!(end_date, ~T[23:59:59])

    base_query = from(v in PortfolioVisit,
      where: v.portfolio_id == ^portfolio_id,
      where: v.inserted_at >= ^start_datetime,
      where: v.inserted_at <= ^end_datetime
    )

    total = from(v in base_query, select: count(v.id)) |> Repo.one()
    unique = from(v in base_query, distinct: v.ip_address, select: count(v.id)) |> Repo.one()

    %{total: total, unique: unique}
  end

  @doc """
  Records a visit to a portfolio.

  ## Examples

      iex> create_portfolio_visit(%{portfolio_id: 1, ip_address: "127.0.0.1"})
      {:ok, %PortfolioVisit{}}

  """
  def create_portfolio_visit(attrs \\ %{}) do
    %PortfolioVisit{}
    |> PortfolioVisit.changeset(attrs)
    |> Repo.insert()
  end

    # Portfolio analytics functions
  def get_portfolio_analytics(portfolio_id, user_id) do
    # Verify ownership
    portfolio = get_portfolio!(portfolio_id)
    unless portfolio.user_id == user_id do
      raise "Unauthorized access"
    end

    # Get various stats using your existing helper functions
    total_visits = get_total_visits(portfolio_id)
    weekly_visits = get_weekly_visits(portfolio_id)
    share_stats = get_share_stats(portfolio_id)
    feedback_stats = get_feedback_stats(portfolio_id) # Uses your existing function

    %{
      views: total_visits,
      weekly_visits: weekly_visits,
      shares: share_stats.total_shares,
      active_shares: share_stats.active_shares,
      feedback: feedback_stats.total,
      last_updated: portfolio.updated_at,
      created_at: portfolio.inserted_at
    }
  rescue
    _ ->
      # Return default stats if anything fails
      %{
        views: 0,
        weekly_visits: 0,
        shares: 0,
        active_shares: 0,
        feedback: 0,
        last_updated: nil,
        created_at: nil
      }
  end

  def get_user_portfolio_overview(user_id) do
    portfolios = list_user_portfolios(user_id)

    total_visits = Enum.reduce(portfolios, 0, fn portfolio, acc ->
      acc + get_total_visits(portfolio.id)
    end)

    total_shares = Enum.reduce(portfolios, 0, fn portfolio, acc ->
      share_count = from(s in PortfolioShare, where: s.portfolio_id == ^portfolio.id)
                   |> Repo.aggregate(:count, :id)
      acc + share_count
    end)

    total_feedback = Enum.reduce(portfolios, 0, fn portfolio, acc ->
      # Use your existing get_feedback_stats function
      feedback_count = try do
        feedback_stats = get_feedback_stats(portfolio.id)
        feedback_stats.total
      rescue
        _ -> 0
      end
      acc + feedback_count
    end)

    %{
      total_portfolios: length(portfolios),
      total_visits: total_visits,
      total_shares: total_shares,
      total_feedback: total_feedback,
      recent_activity: get_recent_activity(user_id)
    }
  rescue
    _ ->
      # Return safe defaults if anything fails
      %{
        total_portfolios: length(list_user_portfolios(user_id)),
        total_visits: 0,
        total_shares: 0,
        total_feedback: 0,
        recent_activity: %{recent_visits: [], recent_feedback: []}
      }
  end


  defp get_share_stats(portfolio_id) do
    try do
      query = from s in PortfolioShare, where: s.portfolio_id == ^portfolio_id

      total_shares = Repo.aggregate(query, :count, :id)
      active_shares = query
                     |> where([s], is_nil(s.expires_at) or s.expires_at > ^DateTime.utc_now())
                     |> Repo.aggregate(:count, :id)

      %{total_shares: total_shares, active_shares: active_shares}
    rescue
      _ -> %{total_shares: 0, active_shares: 0}
    end
  end

  defp get_recent_activity(user_id) do
    try do
      # Get recent visits, feedback, shares for user's portfolios
      portfolio_ids = from(p in Portfolio, where: p.user_id == ^user_id, select: p.id) |> Repo.all()

      recent_visits = from(v in PortfolioVisit,
                          where: v.portfolio_id in ^portfolio_ids,
                          order_by: [desc: v.inserted_at],
                          limit: 10,
                          preload: [:portfolio])
                     |> Repo.all()

      recent_feedback = try do
        from(f in PortfolioFeedback,
            where: f.portfolio_id in ^portfolio_ids,
            order_by: [desc: f.inserted_at],
            limit: 5,
            preload: [:portfolio, :reviewer])
        |> Repo.all()
      rescue
        _ -> []
      end

      %{
        recent_visits: recent_visits,
        recent_feedback: recent_feedback
      }
    rescue
      _ ->
        %{
          recent_visits: [],
          recent_feedback: []
        }
    end
  end

  # Safe function to get portfolio by slug with sections
  def get_portfolio_by_slug_with_sections_simple(slug) do
    # Use a single query with proper preloading
    query = from p in Portfolio,
      where: p.slug == ^slug,
      preload: [:user, portfolio_sections: []]

    case Repo.one(query) do
      nil ->
        {:error, :not_found}
      portfolio ->
        # 🔥 DEBUG: Check what we actually loaded
        IO.puts("🔥 Portfolio loaded from DB:")
        IO.puts("🔥 User association loaded: #{Ecto.assoc_loaded?(portfolio.user)}")

        if Ecto.assoc_loaded?(portfolio.user) do
          IO.puts("🔥 User found - Name: #{inspect(portfolio.user.name)}, Username: #{inspect(portfolio.user.username)}")
        else
          IO.puts("🔥 USER NOT LOADED, forcing preload...")
          portfolio = Repo.preload(portfolio, :user, force: true)
          IO.puts("🔥 After force preload - loaded: #{Ecto.assoc_loaded?(portfolio.user)}")
        end

        {:ok, portfolio}
    end
  end

  # Simplified normalization without media files
  def normalize_portfolio_for_template_simple(portfolio) do
    # Convert theme to template_theme and ensure it's an atom
    template_theme = case Map.get(portfolio, :theme, "executive") do
      "creative" -> :creative
      "corporate" -> :corporate
      "minimalist" -> :minimalist
      "executive" -> :executive
      "developer" -> :developer
      "designer" -> :designer
      "consultant" -> :consultant
      "academic" -> :academic
      "default" -> :executive
      _ -> :executive
    end

    # Convert portfolio_sections to sections and add template_theme
    normalized = portfolio
    |> Map.put(:template_theme, template_theme)
    |> Map.put(:sections, Map.get(portfolio, :portfolio_sections, []))

    normalized
  end

  def get_portfolio_by_slug_with_sections(slug) do
    query = from p in Portfolio,
      where: p.slug == ^slug,
      preload: [
        :user,
        portfolio_sections: [portfolio_media: []],
        portfolio_media: []
      ]

    case Repo.one(query) do
      nil -> {:error, :not_found}
      portfolio -> {:ok, normalize_portfolio_for_template(portfolio)}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking portfolio changes.

  ## Examples

      iex> change_portfolio(portfolio)
      %Ecto.Changeset{data: %Portfolio{}}

  """
  def change_portfolio(%Portfolio{} = portfolio, attrs \\ %{}) do
    Portfolio.changeset(portfolio, attrs)
  end

  def get_portfolio_by_share_token(token) do
    query = from s in PortfolioShare,
      where: s.token == ^token,
      join: p in Portfolio, on: p.id == s.portfolio_id,
      preload: [
        portfolio: [
          :user,
          portfolio_sections: [portfolio_media: []],
          portfolio_media: []
        ]
      ]

    case Repo.one(query) do
      nil -> {:error, :not_found}
      share ->
        portfolio = normalize_portfolio_for_template(share.portfolio)
        {:ok, portfolio, share}
    end
  end

  def increment_share_view_count(token) do
    from(s in PortfolioShare, where: s.token == ^token)
    |> Repo.update_all(inc: [view_count: 1])
  end

  def create_portfolio_share(portfolio_id, attrs \\ %{}) do
    attrs = Map.put(attrs, :portfolio_id, portfolio_id)

    %PortfolioShare{}
    |> PortfolioShare.changeset(attrs)
    |> Repo.insert()
  end

  def get_portfolio_by_share_token_simple(token) do
    query = from s in PortfolioShare,
      where: s.token == ^token,
      join: p in Portfolio, on: p.id == s.portfolio_id,
      preload: [
        portfolio: [
          :user,
          portfolio_sections: []  # Don't try to load media files yet
        ]
      ]

    case Repo.one(query) do
      nil -> {:error, :not_found}
      share ->
        portfolio = normalize_portfolio_for_template_simple(share.portfolio)
        {:ok, portfolio, share}
    end
  end

  # Helper to increment view count
  def increment_share_view_count(token) do
    from(s in PortfolioShare, where: s.token == ^token)
    |> Repo.update_all(inc: [view_count: 1])
  end

  # Normalize your existing schema to match template expectations
  defp normalize_portfolio_for_template(portfolio) do
    # Convert your schema to match what the template expects
    sections = Enum.map(portfolio.portfolio_sections, fn section ->
      %{
        id: section.id,
        title: section.title,
        section_type: section.section_type,
        content: section.content || %{},
        visible: section.visible,
        position: section.position,
        media_files: Enum.map(section.portfolio_media, fn media ->
          %{
            id: media.id,
            title: media.title,
            description: media.description,
            media_type: String.to_atom(media.media_type || "image"),
            file_path: media.file_path,
            file_size: media.file_size,
            mime_type: media.mime_type
          }
        end)
      }
    end)

    # Convert portfolio to expected format
    %{
      id: portfolio.id,
      title: portfolio.title,
      description: portfolio.description,
      slug: portfolio.slug,
      template_theme: portfolio.template_theme || portfolio.theme || "creative",
      inserted_at: portfolio.inserted_at,
      updated_at: portfolio.updated_at,
      user: portfolio.user,
      sections: sections
    }
  end

    @doc """
  Creates feedback for a portfolio section
  """
  def create_feedback(attrs \\ %{}) do
    %PortfolioFeedback{}
    |> PortfolioFeedback.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, feedback} ->
        # Send notification to portfolio owner
        notify_portfolio_owner(feedback)
        {:ok, feedback}
      error -> error
    end
  end

  @doc """
  Creates a quick note from the collaboration sidebar
  """
  def create_quick_note(attrs \\ %{}) do
    %PortfolioFeedback{}
    |> PortfolioFeedback.quick_note_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a highlight feedback
  """
  def create_highlight(attrs \\ %{}) do
    %PortfolioFeedback{}
    |> PortfolioFeedback.highlight_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists all feedback for a portfolio
  """
  def list_portfolio_feedback(portfolio_id) do
    PortfolioFeedback
    |> where([f], f.portfolio_id == ^portfolio_id)
    |> order_by([f], desc: f.inserted_at)
    |> preload([:reviewer, :section, :share])
    |> Repo.all()
  end

  @doc """
  Lists feedback for a specific section
  """
  def list_section_feedback(section_id) do
    PortfolioFeedback
    |> where([f], f.section_id == ^section_id)
    |> order_by([f], desc: f.inserted_at)
    |> preload([:reviewer, :share])
    |> Repo.all()
  end

  @doc """
  Gets feedback by share token (for collaboration sessions)
  """
  def list_feedback_by_share(share_id) do
    PortfolioFeedback
    |> where([f], f.share_id == ^share_id)
    |> order_by([f], desc: f.inserted_at)
    |> preload([:section])
    |> Repo.all()
  end

  @doc """
  Updates feedback status (reviewed, implemented, etc.)
  """
  def update_feedback_status(%PortfolioFeedback{} = feedback, status) do
    feedback
    |> PortfolioFeedback.changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Deletes feedback
  """
  def delete_feedback(%PortfolioFeedback{} = feedback) do
    Repo.delete(feedback)
  end

  @doc """
  Exports feedback as JSON for external processing
  """
  def export_feedback(portfolio_id) do
    feedback = list_portfolio_feedback(portfolio_id)

    %{
      portfolio_id: portfolio_id,
      exported_at: DateTime.utc_now(),
      total_feedback: length(feedback),
      feedback: Enum.map(feedback, fn f ->
        %{
          id: f.id,
          content: f.content,
          type: f.feedback_type,
          status: f.status,
          section: f.section && f.section.title,
          section_reference: f.section_reference,
          metadata: f.metadata,
          reviewer: f.reviewer && f.reviewer.name,
          created_at: f.inserted_at
        }
      end)
    }
  end

  @doc """
  Bulk submit feedback from collaboration session
  """
  def submit_collaboration_feedback(share_id, feedback_items) when is_list(feedback_items) do
    share = get_share_by_token!(share_id)

    results = Enum.map(feedback_items, fn item ->
      attrs = Map.merge(item, %{
        portfolio_id: share.portfolio_id,
        share_id: share.id
      })

      case item[:type] do
        "note" -> create_quick_note(attrs)
        "highlight" -> create_highlight(attrs)
        _ -> create_feedback(attrs)
      end
    end)

    # Count successful submissions
    {successes, errors} = Enum.split_with(results, &match?({:ok, _}, &1))

    if length(successes) > 0 do
      # Notify portfolio owner of bulk feedback
      portfolio = get_portfolio!(share.portfolio_id) |> Repo.preload(:user)
      notify_bulk_feedback(portfolio, share, length(successes))
    end

    {:ok, %{submitted: length(successes), errors: length(errors)}}
  end

  # Enhanced media URL helpers

  @doc """
  Gets the proper URL for portfolio media using the storage system
  """
  def get_media_url(%{file_path: file_path}) when not is_nil(file_path) do
    Frestyl.Storage.LocalStorage.to_url_path(file_path)
  end
  def get_media_url(%{filename: filename}) when not is_nil(filename) do
    "/uploads/#{filename}"
  end
  def get_media_url(_), do: "/images/placeholder.jpg"

  @doc """
  Gets video thumbnail URL - integrates with your existing thumbnail system
  """
  def get_video_thumbnail(%{id: id}) do
    "/uploads/thumbnails/video_#{id}.jpg"
  end
  def get_video_thumbnail(%{file_path: file_path}) when not is_nil(file_path) do
    # Generate thumbnail path based on video file path
    base_name = Path.basename(file_path, Path.extname(file_path))
    "/uploads/thumbnails/#{base_name}.jpg"
  end
  def get_video_thumbnail(_), do: "/images/video-thumbnail.jpg"

  # Private notification helpers

  defp notify_portfolio_owner(%PortfolioFeedback{} = feedback) do
    portfolio = get_portfolio!(feedback.portfolio_id) |> Repo.preload(:user)

    # Create notification using your existing system
    Frestyl.Notifications.create_notification(%{
      user_id: portfolio.user_id,
      type: "portfolio_feedback",
      title: "New Portfolio Feedback",
      message: "Someone provided feedback on your portfolio: #{portfolio.title}",
      metadata: %{
        portfolio_id: portfolio.id,
        feedback_id: feedback.id,
        feedback_type: feedback.feedback_type,
        section: feedback.section_reference
      }
    })
  rescue
    # Gracefully handle if notifications system isn't available
    _ -> :ok
  end

  defp notify_bulk_feedback(portfolio, share, count) do
    Frestyl.Notifications.create_notification(%{
      user_id: portfolio.user_id,
      type: "portfolio_bulk_feedback",
      title: "Portfolio Review Completed",
      message: "#{share.name || "A reviewer"} submitted #{count} feedback items for #{portfolio.title}",
      metadata: %{
        portfolio_id: portfolio.id,
        share_id: share.id,
        feedback_count: count
      }
    })
  rescue
    # Gracefully handle if notifications system isn't available
    _ -> :ok
  end
end
