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

  # Portfolio CRUD operations

  def list_user_portfolios(user_id) do
    Portfolio
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], desc: p.updated_at)
    |> Repo.all()
  end

  def get_portfolio!(id), do: Repo.get!(Portfolio, id)

  def get_portfolio_by_slug!(user_id, slug) do
    Repo.get_by!(Portfolio, user_id: user_id, slug: slug)
  end

  def get_portfolio_by_slug(slug) do
    case Repo.get_by(Portfolio, slug: slug) do
      nil -> {:error, :not_found}
      portfolio -> {:ok, portfolio}
    end
  end

  def get_portfolio_for_share!(share_token) do
    share = get_share_by_token!(share_token)

    Repo.get!(Portfolio, share.portfolio_id)
    |> Repo.preload([:portfolio_sections, :portfolio_media])
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

  def list_portfolio_media(portfolio_id) do
    PortfolioMedia
    |> where([m], m.portfolio_id == ^portfolio_id)
    |> order_by([m], m.position)
    |> Repo.all()
  end

  def get_media!(id), do: Repo.get!(PortfolioMedia, id)

  def create_media(attrs \\ %{}) do
    # Ensure the struct is correctly referenced
    %PortfolioMedia{}
    |> PortfolioMedia.changeset(attrs)
    |> Repo.insert()
  end

  def update_media(%PortfolioMedia{} = media, attrs) do
    media
    |> PortfolioMedia.changeset(attrs)
    |> Repo.update()
  end

  def delete_media(%PortfolioMedia{} = media) do
    Repo.delete(media)
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

  def create_default_portfolio(user_id) do
    with {:ok, portfolio} <- create_portfolio(user_id, %{title: "My Professional Portfolio"}) do
      # Create default sections
      create_section(%{
        portfolio_id: portfolio.id,
        title: "Introduction",
        section_type: :intro,
        position: 1,
        content: %{
          headline: "Hello, I'm [Your Name]",
          summary: "A brief introduction about yourself and your professional journey."
        }
      })

      create_section(%{
        portfolio_id: portfolio.id,
        title: "Experience",
        section_type: :experience,
        position: 2,
        content: %{
          jobs: []
        }
      })

      create_section(%{
        portfolio_id: portfolio.id,
        title: "Education",
        section_type: :education,
        position: 3,
        content: %{
          education: []
        }
      })

      create_section(%{
        portfolio_id: portfolio.id,
        title: "Skills",
        section_type: :skills,
        position: 4,
        content: %{
          skills: []
        }
      })

      create_section(%{
        portfolio_id: portfolio.id,
        title: "Contact Information",
        section_type: :contact,
        position: 5,
        content: %{
          email: "",
          phone: "",
          location: ""
        }
      })

      {:ok, portfolio}
    end
  end

  # Subscription tier checks

  def can_create_portfolio?(%User{} = user) do
    # Logic to check if user can create (more) portfolios based on their subscription
    # For free tier, limit to 1 portfolio
    case user.subscription_tier do
      "free" ->
        portfolio_count =
          Portfolio
          |> where([p], p.user_id == ^user.id)
          |> Repo.aggregate(:count, :id)

        portfolio_count < 1

      _ -> true
    end
  end

  def get_portfolio_limits(%User{} = user) do
    # Return portfolio feature limits based on user's subscription tier
    case user.subscription_tier do
      "free" -> %{
        max_portfolios: 1,
        custom_domain: false,
        advanced_analytics: false,
        custom_themes: false,
        max_media_size_mb: 50,
        ats_optimization: false
      }
      "basic" -> %{
        max_portfolios: 3,
        custom_domain: false,
        advanced_analytics: true,
        custom_themes: true,
        max_media_size_mb: 200,
        ats_optimization: false
      }
      "premium" -> %{
        max_portfolios: 10,
        custom_domain: true,
        advanced_analytics: true,
        custom_themes: true,
        max_media_size_mb: 500,
        ats_optimization: true
      }
      "pro" -> %{
        max_portfolios: -1, # unlimited
        custom_domain: true,
        advanced_analytics: true,
        custom_themes: true,
        max_media_size_mb: 1000,
        ats_optimization: true
      }
      _ -> %{
        max_portfolios: 1,
        custom_domain: false,
        advanced_analytics: false,
        custom_themes: false,
        max_media_size_mb: 50,
        ats_optimization: false
      }
    end
  end
end
