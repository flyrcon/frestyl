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
  alias Frestyl.Portfolios.PortfolioFeedback
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

  # Simplified normalization without media files
  def normalize_portfolio_for_template_simple(portfolio) do
    # Convert theme to template_theme and ensure it's an atom
    template_theme = case Map.get(portfolio, :theme, "default") do
      "creative" -> :creative
      "corporate" -> :corporate
      "minimalist" -> :minimalist
      "default" -> :creative
      _ -> :creative
    end

    # Convert portfolio_sections to sections and add template_theme
    normalized = portfolio
    |> Map.put(:template_theme, template_theme)
    |> Map.put(:sections, Map.get(portfolio, :portfolio_sections, []))

    normalized
  end

  # Also update your get_portfolio_by_slug_with_sections_simple/1 function:
  def get_portfolio_by_slug_with_sections_simple(slug) do
    case Repo.get_by(Portfolio, slug: slug)
        |> Repo.preload([:user, :portfolio_sections]) do
      nil ->
        {:error, :not_found}
      portfolio ->
        normalized_portfolio = normalize_portfolio_for_template_simple(portfolio)
        {:ok, normalized_portfolio}
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
  Gets feedback statistics for a portfolio
  """
  def get_feedback_stats(portfolio_id) do
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
