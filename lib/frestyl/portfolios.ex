# lib/frestyl/portfolios.ex - FIXED VERSION

defmodule Frestyl.Portfolios do
  @moduledoc """
  The Portfolios context - FIXED to properly handle section loading and display.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Portfolios.{Portfolio, PortfolioSection, PortfolioMedia,
                          PortfolioShare, PortfolioVisit}
  alias Frestyl.Accounts.User

  # 🔥 FIXED: Get portfolio by slug with complete section data for public view
  def get_portfolio_by_slug_with_sections_simple(slug) do
    IO.puts("🔥 LOADING PORTFOLIO: #{slug}")

    query = from p in Portfolio,
      where: p.slug == ^slug,
      preload: [
        :user,
        portfolio_sections: [portfolio_media: []]
      ]

    case Repo.one(query) do
      nil ->
        IO.puts("🔥 PORTFOLIO NOT FOUND")
        {:error, :not_found}

      portfolio ->
        IO.puts("🔥 PORTFOLIO FOUND: #{portfolio.title}")
        IO.puts("🔥 RAW SECTIONS COUNT: #{length(portfolio.portfolio_sections)}")

        # 🔥 CRITICAL: Transform to expected structure with proper field mapping
        normalized_portfolio = %{
          id: portfolio.id,
          title: portfolio.title,
          description: portfolio.description,
          slug: portfolio.slug,
          theme: portfolio.theme,
          customization: portfolio.customization,
          visibility: portfolio.visibility,
          inserted_at: portfolio.inserted_at,
          updated_at: portfolio.updated_at,
          user: portfolio.user,
          # 🔥 KEY FIX: Map portfolio_sections to sections with complete data
          sections: transform_sections_for_display(portfolio.portfolio_sections)
        }

        IO.puts("🔥 NORMALIZED SECTIONS COUNT: #{length(normalized_portfolio.sections)}")

        {:ok, normalized_portfolio}
    end
  end

  # 🔥 FIXED: Get portfolio by share token with complete section data
  def get_portfolio_by_share_token_simple(token) do
    IO.puts("🔥 LOADING SHARED PORTFOLIO: #{token}")

    query = from s in PortfolioShare,
      where: s.token == ^token,
      join: p in Portfolio, on: p.id == s.portfolio_id,
      preload: [
        portfolio: [
          :user,
          portfolio_sections: [portfolio_media: []]
        ]
      ]

    case Repo.one(query) do
      nil ->
        IO.puts("🔥 SHARED PORTFOLIO NOT FOUND")
        {:error, :not_found}

      share ->
        portfolio = share.portfolio
        IO.puts("🔥 SHARED PORTFOLIO FOUND: #{portfolio.title}")
        IO.puts("🔥 RAW SECTIONS COUNT: #{length(portfolio.portfolio_sections)}")

        # 🔥 CRITICAL: Transform to expected structure
        normalized_portfolio = %{
          id: portfolio.id,
          title: portfolio.title,
          description: portfolio.description,
          slug: portfolio.slug,
          theme: portfolio.theme,
          customization: portfolio.customization,
          visibility: portfolio.visibility,
          inserted_at: portfolio.inserted_at,
          updated_at: portfolio.updated_at,
          user: portfolio.user,
          # 🔥 KEY FIX: Map portfolio_sections to sections with complete data
          sections: transform_sections_for_display(portfolio.portfolio_sections)
        }

        IO.puts("🔥 SHARED NORMALIZED SECTIONS COUNT: #{length(normalized_portfolio.sections)}")

        {:ok, normalized_portfolio, share}
    end
  end

  # 🔥 CRITICAL: Transform portfolio_sections to sections with complete content
  defp transform_sections_for_display(portfolio_sections) when is_list(portfolio_sections) do
    IO.puts("🔥 TRANSFORMING #{length(portfolio_sections)} SECTIONS")

    portfolio_sections
    |> Enum.filter(fn section ->
      visible = Map.get(section, :visible, true)
      IO.puts("🔥 Section #{section.title}: visible=#{visible}")
      visible
    end)
    |> Enum.sort_by(fn section -> section.position end)
    |> Enum.map(fn section ->
      # 🔥 CRITICAL: Ensure content is properly structured
      content = case section.content do
        nil -> %{}
        content when is_map(content) -> content
        _ -> %{}
      end

      # 🔥 Transform media files to expected format
      media_files = transform_media_files_for_display(section.portfolio_media || [])

      transformed = %{
        id: section.id,
        title: section.title,
        section_type: normalize_section_type(section.section_type),
        content: content,
        position: section.position,
        visible: Map.get(section, :visible, true),
        media_files: media_files
      }

      IO.puts("🔥 Transformed section: #{transformed.title} (#{transformed.section_type}) - #{map_size(transformed.content)} content fields")

      transformed
    end)
  end
  defp transform_sections_for_display(_) do
    IO.puts("🔥 NO SECTIONS TO TRANSFORM")
    []
  end

  # 🔥 CRITICAL: Transform media files to expected format
  defp transform_media_files_for_display(portfolio_media) when is_list(portfolio_media) do
    Enum.map(portfolio_media, fn media ->
      %{
        id: media.id,
        title: media.title || "Untitled",
        description: media.description,
        media_type: normalize_media_type(media.media_type),
        file_path: media.file_path,
        file_size: media.file_size,
        mime_type: media.mime_type,
        url: get_media_url_safe(media)
      }
    end)
  end
  defp transform_media_files_for_display(_), do: []

  # 🔥 Normalize section types consistently
  defp normalize_section_type(section_type) when is_atom(section_type), do: section_type
  defp normalize_section_type(section_type) when is_binary(section_type) do
    case section_type do
      "intro" -> :intro
      "experience" -> :experience
      "education" -> :education
      "skills" -> :skills
      "projects" -> :projects
      "featured_project" -> :featured_project
      "case_study" -> :case_study
      "achievements" -> :achievements
      "testimonial" -> :testimonial
      "media_showcase" -> :media_showcase
      "contact" -> :contact
      _ -> :custom
    end
  end
  defp normalize_section_type(_), do: :custom

  # 🔥 Normalize media types consistently
  defp normalize_media_type(media_type) when is_binary(media_type) do
    case media_type do
      "image" -> :image
      "video" -> :video
      "audio" -> :audio
      "document" -> :document
      _ -> :document
    end
  end
  defp normalize_media_type(media_type) when is_atom(media_type), do: media_type
  defp normalize_media_type(_), do: :document

  # 🔥 Safe media URL helper
  def get_media_url_safe(media) do
    try do
      get_media_url(media)
    rescue
      _ -> "/images/placeholder.jpg"
    end
  end

  # 🔥 Enhanced media URL helpers
  def get_media_url(%{file_path: file_path}) when not is_nil(file_path) do
    try do
      Frestyl.Storage.LocalStorage.to_url_path(file_path)
    rescue
      _ -> "/uploads/#{Path.basename(file_path)}"
    end
  end
  def get_media_url(%{filename: filename}) when not is_nil(filename) do
    "/uploads/#{filename}"
  end
  def get_media_url(_), do: "/images/placeholder.jpg"

  def attach_media_to_section(section_id, media_id) do
    try do
      # First check if both section and media exist
      section = get_section!(section_id)
      media = get_media!(media_id)

      # Update the media to be associated with the section
      case update_media(media, %{section_id: section_id}) do
        {:ok, updated_media} ->
          {:ok, updated_media}
        {:error, changeset} ->
          {:error, changeset}
      end
    rescue
      Ecto.NoResultsError ->
        {:error, :not_found}
      error ->
        {:error, Exception.message(error)}
    end
  end

  def detach_media_from_section(media_id) do
    try do
      media = get_media!(media_id)

      case update_media(media, %{section_id: nil}) do
        {:ok, updated_media} ->
          {:ok, updated_media}
        {:error, changeset} ->
          {:error, changeset}
      end
    rescue
      Ecto.NoResultsError ->
        {:error, :not_found}
      error ->
        {:error, Exception.message(error)}
    end
  end

  def list_unattached_portfolio_media(portfolio_id) do
    from(m in PortfolioMedia,
      where: m.portfolio_id == ^portfolio_id and is_nil(m.section_id),
      order_by: [asc: m.inserted_at])
    |> Repo.all()
  end

  def get_video_thumbnail(%{id: id}) do
    "/uploads/thumbnails/video_#{id}.jpg"
  end
  def get_video_thumbnail(%{file_path: file_path}) when not is_nil(file_path) do
    base_name = Path.basename(file_path, Path.extname(file_path))
    "/uploads/thumbnails/#{base_name}.jpg"
  end
  def get_video_thumbnail(_), do: "/images/video-thumbnail.jpg"

  # Portfolio CRUD operations (keeping existing functions)
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
    Repo.get_by(Portfolio, slug: slug)
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

  def list_portfolio_sections_ordered(portfolio_id) do
    from(s in PortfolioSection,
      where: s.portfolio_id == ^portfolio_id and s.visible == true,
      order_by: [asc: s.position, asc: s.id]
    )
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

  def create_media(attrs) do
    %PortfolioMedia{}
    |> PortfolioMedia.changeset(attrs)
    |> Repo.insert()
  end

  def update_media(media, attrs) do
    media
    |> PortfolioMedia.changeset(attrs)
    |> Repo.update()
  end

  def delete_media(media) do
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

  def create_portfolio_share(portfolio_id, attrs \\ %{}) do
    attrs = Map.put(attrs, :portfolio_id, portfolio_id)
    create_share(attrs)
  end

  def update_share(%PortfolioShare{} = share, attrs) do
    share
    |> PortfolioShare.changeset(attrs)
    |> Repo.update()
  end

  def delete_share(%PortfolioShare{} = share) do
    Repo.delete(share)
  end

  def increment_share_view_count(token) do
    from(s in PortfolioShare, where: s.token == ^token)
    |> Repo.update_all(inc: [view_count: 1])
  end

  # Portfolio Visit operations
  def create_visit(attrs \\ %{}) do
    %PortfolioVisit{}
    |> PortfolioVisit.changeset(attrs)
    |> Repo.insert()
  end

  def create_portfolio_visit(attrs \\ %{}) do
    create_visit(attrs)
  end

  def get_total_visits(portfolio_id) do
    from(v in PortfolioVisit,
      where: v.portfolio_id == ^portfolio_id,
      select: count(v.id)
    )
    |> Repo.one()
  end

  def get_unique_visits(portfolio_id) do
    from(v in PortfolioVisit,
      where: v.portfolio_id == ^portfolio_id,
      distinct: v.ip_address,
      select: count(v.id)
    )
    |> Repo.one()
  end

  def get_weekly_visits(portfolio_id) do
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 60 * 60, :second)

    from(v in PortfolioVisit,
      where: v.portfolio_id == ^portfolio_id,
      where: v.inserted_at >= ^seven_days_ago,
      select: count(v.id)
    )
    |> Repo.one()
  end

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

  def get_portfolio_stats(portfolio_id) do
    %{
      total_visits: get_total_visits(portfolio_id),
      weekly_visits: get_weekly_visits(portfolio_id),
      daily_visits: get_daily_visits(portfolio_id),
      unique_visits: get_unique_visits(portfolio_id)
    }
  end

  # Portfolio analytics and statistics
  def get_portfolio_analytics(portfolio_id, user_id) do
    try do
      portfolio = get_portfolio!(portfolio_id)
      unless portfolio.user_id == user_id do
        raise "Unauthorized access"
      end

      total_visits = get_total_visits(portfolio_id)
      weekly_visits = get_weekly_visits(portfolio_id)
      share_stats = get_share_stats(portfolio_id)

      %{
        views: total_visits,
        weekly_visits: weekly_visits,
        shares: share_stats.total_shares,
        active_shares: share_stats.active_shares,
        last_updated: portfolio.updated_at,
        created_at: portfolio.inserted_at
      }
    rescue
      _ ->
        %{
          views: 0,
          weekly_visits: 0,
          shares: 0,
          active_shares: 0,
          last_updated: nil,
          created_at: nil
        }
    end
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

  # Utility functions for portfolio management
  def portfolio_public?(portfolio) do
    portfolio.visibility in [:public, :link_only]
  end

  def can_create_portfolio?(%User{} = user) do
    case user.subscription_tier do
      "free" ->
        portfolio_count =
          Portfolio
          |> where([p], p.user_id == ^user.id)
          |> Repo.aggregate(:count, :id)

        portfolio_count < 2

      _ -> true
    end
  end

  def get_portfolio_limits(%User{} = user) do
    case user.subscription_tier do
      "free" -> %{
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
      "basic" -> %{
        max_portfolios: 5,
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
        max_portfolios: 15,
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
        max_portfolios: -1,
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

  # Helper functions for portfolio creation and management
  def create_default_portfolio(user_id, attrs \\ %{}) do
    title = Map.get(attrs, :title, "My Professional Portfolio")
    slug = case Map.get(attrs, :slug) do
      nil -> generate_unique_slug(title)
      existing_slug -> existing_slug
    end

    theme = Map.get(attrs, :theme, "executive")

    portfolio_attrs = %{
      title: title,
      slug: slug,
      description: Map.get(attrs, :description, "Welcome to my professional portfolio"),
      theme: theme,
      customization: Map.get(attrs, :customization, %{}),
      visibility: Map.get(attrs, :visibility, :link_only),
      user_id: user_id
    }

    case create_portfolio(user_id, portfolio_attrs) do
      {:ok, portfolio} ->
        create_default_sections(portfolio, theme)
        {:ok, portfolio}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def get_user_portfolio_overview(user_id) do
    try do
      # Get basic portfolio stats
      portfolios = list_user_portfolios(user_id)
      portfolio_count = length(portfolios)

      # Calculate total views across all portfolios
      total_views = portfolios
      |> Enum.map(fn portfolio ->
        get_total_visits(portfolio.id)
      end)
      |> Enum.sum()

      # Calculate total shares
      total_shares = portfolios
      |> Enum.map(fn portfolio ->
        get_share_stats(portfolio.id).total_shares
      end)
      |> Enum.sum()

      # Get public portfolio count
      public_portfolios = portfolios
      |> Enum.count(fn portfolio -> portfolio.visibility == :public end)

      # Calculate growth metrics (last 30 days vs previous 30 days)
      thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30 * 24 * 60 * 60, :second)
      sixty_days_ago = DateTime.utc_now() |> DateTime.add(-60 * 24 * 60 * 60, :second)

      recent_views = get_visits_in_period(portfolios, thirty_days_ago, DateTime.utc_now())
      previous_views = get_visits_in_period(portfolios, sixty_days_ago, thirty_days_ago)

      growth_percentage = if previous_views > 0 do
        ((recent_views - previous_views) / previous_views * 100) |> Float.round(1)
      else
        0.0
      end

      %{
        total_portfolios: portfolio_count,
        total_views: total_views,
        total_shares: total_shares,
        public_portfolios: public_portfolios,
        recent_views: recent_views,
        growth_percentage: growth_percentage,
        last_updated: get_last_portfolio_update(portfolios)
      }
    rescue
      _ ->
        # Return safe defaults if anything fails
        %{
          total_portfolios: 0,
          total_views: 0,
          total_shares: 0,
          public_portfolios: 0,
          recent_views: 0,
          growth_percentage: 0.0,
          last_updated: nil
        }
    end
  end

  # Helper functions for the overview
  defp get_visits_in_period(portfolios, start_time, end_time) do
    portfolio_ids = Enum.map(portfolios, & &1.id)

    if length(portfolio_ids) == 0 do
      0
    else
      from(v in PortfolioVisit,
        where: v.portfolio_id in ^portfolio_ids,
        where: v.inserted_at >= ^start_time,
        where: v.inserted_at <= ^end_time,
        select: count(v.id)
      )
      |> Repo.one() || 0
    end
  end

  defp get_last_portfolio_update(portfolios) do
    case portfolios do
      [] -> nil
      portfolios ->
        portfolios
        |> Enum.map(& &1.updated_at)
        |> Enum.max(DateTime, fn -> nil end)
    end
  end

  # Also add this enhanced analytics function that was referenced
  def get_portfolio_analytics(portfolio_id, user_id) do
    try do
      portfolio = get_portfolio!(portfolio_id)

      # Verify ownership
      unless portfolio.user_id == user_id do
        raise "Unauthorized access"
      end

      # Get visit stats
      total_visits = get_total_visits(portfolio_id)
      unique_visitors = get_unique_visits(portfolio_id)
      weekly_visits = get_weekly_visits(portfolio_id)

      # Get last visit
      last_visit = from(v in PortfolioVisit,
        where: v.portfolio_id == ^portfolio_id,
        order_by: [desc: v.inserted_at],
        limit: 1,
        select: v.inserted_at
      ) |> Repo.one()

      %{
        total_visits: total_visits,
        unique_visitors: unique_visitors,
        weekly_visits: weekly_visits,
        last_visit: last_visit,
        created_at: portfolio.inserted_at,
        updated_at: portfolio.updated_at
      }
    rescue
      error ->
        IO.puts("Error getting portfolio analytics: #{inspect(error)}")
        %{
          total_visits: 0,
          unique_visitors: 0,
          weekly_visits: 0,
          last_visit: nil,
          created_at: nil,
          updated_at: nil
        }
    end
  end

  defp create_default_sections(portfolio, template) do
    sections = get_default_sections_for_template(template)

    Enum.each(sections, fn section_attrs ->
      section_attrs = Map.put(section_attrs, :portfolio_id, portfolio.id)
      case create_section(section_attrs) do
        {:ok, _section} -> :ok
        {:error, error} ->
          IO.puts("Warning: Failed to create section #{section_attrs.title}: #{inspect(error)}")
      end
    end)
  end

  defp get_default_sections_for_template(_template) do
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

  def generate_unique_slug(title, portfolio_id \\ nil) do
    base_slug = title
      |> String.downcase()
      |> String.replace(~r/[^\w\s-]/, "")
      |> String.replace(~r/\s+/, "-")
      |> String.slice(0, 50)

    if slug_available?(base_slug, portfolio_id) do
      base_slug
    else
      1..100
      |> Enum.find_value(fn i ->
        candidate = "#{base_slug}-#{i}"
        if slug_available?(candidate, portfolio_id), do: candidate
      end) || "#{base_slug}-#{System.unique_integer([:positive])}"
    end
  end

  def slug_available?(slug, portfolio_id \\ nil) do
    query = from(p in Portfolio, where: p.slug == ^slug)

    query = if portfolio_id do
      from(p in query, where: p.id != ^portfolio_id)
    else
      query
    end

    !Repo.exists?(query)
  end

  # Change functions for compatibility
  def change_portfolio(%Portfolio{} = portfolio, attrs \\ %{}) do
    Portfolio.changeset(portfolio, attrs)
  end

  def change_share(%PortfolioShare{} = share, attrs \\ %{}) do
    PortfolioShare.changeset(share, attrs)
  end
end
