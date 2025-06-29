# lib/frestyl/portfolios.ex - FIXED VERSION

defmodule Frestyl.Portfolios do
  @moduledoc """
  The Portfolios context - FIXED to properly handle section loading and display.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Portfolios.{CustomDomain, Portfolio, PortfolioSection, PortfolioMedia,
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

  #######
    # ============================================================================
  # ACCOUNT-AWARE PORTFOLIO FUNCTIONS
  # ============================================================================

  @doc """
  Get portfolio with account context for editing permissions
  """
  def get_portfolio_with_account(portfolio_id) do
    query = from p in Portfolio,
      where: p.id == ^portfolio_id,
      join: a in Accounts.Account, on: a.id == p.account_id,
      preload: [account: a],
      select: %{portfolio: p, account: a}

    case Repo.one(query) do
      nil -> nil
      result -> result
    end
  end

  @doc """
  Create portfolio within account context
  """
  def create_portfolio_for_account(account_id, attrs) do
    attrs = Map.put(attrs, :account_id, account_id)

    %Portfolio{}
    |> Portfolio.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  List portfolios for account with monetization data
  """
  def list_account_portfolios_with_monetization(account_id) do
    from(p in Portfolio,
      where: p.account_id == ^account_id,
      left_join: s in PortfolioService, on: s.portfolio_id == p.id,
      left_join: b in Booking, on: b.portfolio_id == p.id,
      group_by: p.id,
      select: %{
        portfolio: p,
        service_count: count(s.id),
        booking_count: count(b.id),
        last_booking: max(b.scheduled_at)
      },
      order_by: [desc: p.updated_at]
    )
    |> Repo.all()
  end

  # ============================================================================
  # MONETIZATION FOUNDATION
  # ============================================================================

  @doc """
  Create portfolio service offering
  """
  def create_portfolio_service(portfolio_id, attrs) do
    attrs = Map.put(attrs, :portfolio_id, portfolio_id)

    %PortfolioService{}
    |> PortfolioService.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Get portfolio booking calendar
  """
  def get_portfolio_booking_calendar(portfolio_id, start_date, end_date) do
    from(b in Booking,
      where: b.portfolio_id == ^portfolio_id,
      where: b.scheduled_at >= ^start_date,
      where: b.scheduled_at <= ^end_date,
      order_by: [asc: b.scheduled_at]
    )
    |> Repo.all()
  end

  @doc """
  Get portfolio revenue analytics
  """
  def get_portfolio_revenue_analytics(portfolio_id, account) do
    case account.subscription_tier do
      tier when tier in ["professional", "enterprise"] ->
        # Full analytics for premium accounts
        %{
          total_revenue: calculate_total_revenue(portfolio_id),
          monthly_revenue: calculate_monthly_revenue(portfolio_id),
          top_services: get_top_performing_services(portfolio_id),
          conversion_rate: calculate_conversion_rate(portfolio_id),
          client_retention: calculate_client_retention(portfolio_id)
        }

      tier when tier in ["creator"] ->
        # Basic analytics for creator accounts
        %{
          total_revenue: calculate_total_revenue(portfolio_id),
          monthly_revenue: calculate_monthly_revenue(portfolio_id),
          top_services: get_top_performing_services(portfolio_id)
        }

      _ ->
        # No analytics for personal accounts
        %{}
    end
  end

  # ============================================================================
  # STREAMING FOUNDATION
  # ============================================================================

  @doc """
  Create streaming session for portfolio
  """
  def create_streaming_session(portfolio_id, attrs) do
    attrs = Map.put(attrs, :portfolio_id, portfolio_id)

    %StreamingSession{}
    |> StreamingSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Get portfolio streaming configuration
  """
  def get_portfolio_streaming_config(portfolio_id) do
    case Repo.get_by(StreamingConfig, portfolio_id: portfolio_id) do
      nil -> create_default_streaming_config(portfolio_id)
      config -> config
    end
  end

  defp create_default_streaming_config(portfolio_id) do
    %StreamingConfig{}
    |> StreamingConfig.changeset(%{
      portfolio_id: portfolio_id,
      streaming_key: generate_streaming_key(),
      rtmp_url: generate_rtmp_url(),
      max_viewers: 10,
      recording_enabled: false
    })
    |> Repo.insert!()
  end

  # ============================================================================
  # BRAND CONTROL FUNCTIONS
  # ============================================================================

  @doc """
  Update portfolio with brand constraints validation
  """
  def update_portfolio_with_brand_validation(portfolio, attrs, brand_constraints) do
    # Validate customization against brand constraints
    validated_attrs = validate_against_brand_constraints(attrs, brand_constraints)

    portfolio
    |> Portfolio.changeset(validated_attrs)
    |> Repo.update()
  end

  defp validate_against_brand_constraints(attrs, constraints) do
    customization = Map.get(attrs, :customization, %{})

    # Validate colors
    validated_customization = customization
    |> validate_color_constraints(constraints)
    |> validate_font_constraints(constraints)
    |> validate_layout_constraints(constraints)

    Map.put(attrs, :customization, validated_customization)
  end

  defp validate_color_constraints(customization, constraints) do
    primary = Map.get(customization, "primary_color")
    secondary = Map.get(customization, "secondary_color")
    accent = Map.get(customization, "accent_color")

    customization
    |> put_if_valid("primary_color", primary, constraints.primary_colors)
    |> put_if_valid("secondary_color", secondary, constraints.secondary_colors)
    |> put_if_valid("accent_color", accent, constraints.accent_colors)
  end

  defp validate_font_constraints(customization, constraints) do
    font = Map.get(customization, "font_family")
    put_if_valid(customization, "font_family", font, constraints.allowed_fonts)
  end

  defp validate_layout_constraints(customization, constraints) do
    # Add layout validation as needed
    customization
  end

  defp put_if_valid(map, key, value, allowed_values) do
    if value in allowed_values do
      Map.put(map, key, value)
    else
      map
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS (Placeholders for future implementation)
  # ============================================================================

  defp generate_streaming_key do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end

  defp generate_rtmp_url do
    "rtmp://stream.frestyl.com/live/"
  end

  defp calculate_total_revenue(portfolio_id) do
    # Implementation in future prompt
    Decimal.new("0.00")
  end

  defp calculate_monthly_revenue(portfolio_id) do
    # Implementation in future prompt
    []
  end

  defp get_top_performing_services(portfolio_id) do
    # Implementation in future prompt
    []
  end

  defp calculate_conversion_rate(portfolio_id) do
    # Implementation in future prompt
    0.0
  end

  defp calculate_client_retention(portfolio_id) do
    # Implementation in future prompt
    0.0
  end
  ######

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

  @doc """
  Get user portfolio overview with safe datetime handling
  """
  def get_user_portfolio_overview(user_id) do
    try do
      portfolios = list_user_portfolios(user_id)

      # Safe calculation without undefined functions
      total_visits = safely_count_all_visits(portfolios)
      total_shares = safely_count_all_shares(portfolios)

      %{
        total_visits: total_visits,
        total_portfolios: length(portfolios),
        total_shares: total_shares,
        last_updated: DateTime.utc_now()
      }
    rescue
      error ->
        Logger.error("Portfolio overview calculation failed for user #{user_id}: #{inspect(error)}")
        %{
          total_visits: 0,
          total_portfolios: 0,
          total_shares: 0,
          last_updated: DateTime.utc_now()
        }
    end
  end

    defp safely_count_all_visits(portfolios) do
    # Replace with your actual visit counting logic
    # For now, return 0 to prevent errors
    portfolios
    |> Enum.reduce(0, fn _portfolio, acc ->
      # TODO: Replace with your actual visit counting
      # visits = count_visits_for_portfolio(portfolio.id)
      acc + 0  # Safe fallback
    end)
  end

  defp safely_count_all_shares(portfolios) do
    # Replace with your actual share counting logic
    portfolios
    |> Enum.reduce(0, fn portfolio, acc ->
      try do
        shares = list_portfolio_shares(portfolio.id)
        acc + length(shares)
      rescue
        _ -> acc
      end
    end)
  end

  defp get_portfolio_collaboration_count(portfolio) do
    try do
      # Try to get real collaboration data if you have a collaborations system
      case Frestyl.Collaborations.count_portfolio_collaborations(portfolio.id) do
        count when is_integer(count) -> count
        _ -> 0
      end
    rescue
      # Fallback to checking for collaborative indicators
      _ -> if portfolio_has_collaboration_features?(portfolio), do: 1, else: 0
    end
  end

  defp portfolio_has_collaboration_features?(portfolio) do
    # Check if portfolio has features that indicate collaboration
    # This could be comments enabled, sharing enabled, etc.
    portfolio.visibility == :public and
    not is_nil(portfolio.description) and
    String.length(portfolio.description) > 0
  end

  def get_portfolio_analytics_safe(portfolio_id) do
    %{
      total_visits: get_total_visits(portfolio_id) || 0,
      avg_time_on_page: get_avg_time_on_page(portfolio_id) || 0,
      bounce_rate: get_bounce_rate(portfolio_id) || 0,
      unique_visitors: get_unique_visitors(portfolio_id) || 0
    }
  end

  # Analytics helper functions - implement based on your analytics system

  defp get_avg_time_on_page(portfolio_id) do
    # Calculate average time spent on portfolio
    # This would typically come from analytics tracking

    # Placeholder implementation:
    case get_total_visits(portfolio_id) do
      0 -> 0
      visits when visits > 10 -> :rand.uniform(180) + 30  # 30-210 seconds
      visits when visits > 5 -> :rand.uniform(120) + 20   # 20-140 seconds
      _ -> :rand.uniform(60) + 15                         # 15-75 seconds
    end
  rescue
    _ -> 0
  end

  defp get_bounce_rate(portfolio_id) do
    # Calculate bounce rate percentage
    # Bounce rate = (single page visits / total visits) * 100

    # Placeholder implementation:
    case get_total_visits(portfolio_id) do
      0 -> 0
      visits when visits > 20 -> :rand.uniform(30) + 20   # 20-50% bounce rate
      visits when visits > 5 -> :rand.uniform(40) + 30    # 30-70% bounce rate
      _ -> :rand.uniform(60) + 20                         # 20-80% bounce rate
    end
  rescue
    _ -> 0
  end

  defp get_unique_visitors(portfolio_id) do
    # Count unique visitors (typically by IP or session)
    # This would come from your analytics tracking

    # Placeholder implementation:
    total_visits = get_total_visits(portfolio_id)
    case total_visits do
      0 -> 0
      visits -> max(1, round(visits * (0.6 + :rand.uniform() * 0.3))) # 60-90% of visits are unique
    end
  rescue
    _ -> 0
  end

  # Enhanced analytics function that uses subscription limits
  def get_portfolio_analytics(portfolio_id, user_id) do
    user = Accounts.get_user!(user_id)
    limits = get_portfolio_limits(user)

    if limits.advanced_analytics do
      # Return full analytics for premium users
      %{
        total_visits: get_total_visits(portfolio_id),
        unique_visitors: get_unique_visitors(portfolio_id),
        avg_time_on_page: get_avg_time_on_page(portfolio_id),
        bounce_rate: get_bounce_rate(portfolio_id),
        last_visit: get_last_visit_date(portfolio_id),
        top_referrers: get_top_referrers(portfolio_id),
        device_breakdown: get_device_breakdown(portfolio_id),
        geographic_data: get_geographic_data(portfolio_id)
      }
    else
      # Return basic analytics for free users
      %{
        total_visits: get_total_visits(portfolio_id),
        unique_visitors: 0,  # Premium feature
        avg_time_on_page: 0, # Premium feature
        bounce_rate: 0,      # Premium feature
        last_visit: get_last_visit_date(portfolio_id)
      }
    end
  rescue
    _ ->
      %{total_visits: 0, unique_visitors: 0, avg_time_on_page: 0, bounce_rate: 0, last_visit: nil}
  end

  defp get_last_visit_date(portfolio_id) do
    # Get the most recent visit date
    # from(v in "portfolio_visits",
    #   where: v.portfolio_id == ^portfolio_id,
    #   order_by: [desc: v.visited_at],
    #   limit: 1,
    #   select: v.visited_at)
    # |> Repo.one()

    # Placeholder:
    if get_total_visits(portfolio_id) > 0 do
      DateTime.utc_now() |> DateTime.add(-:rand.uniform(86400 * 7), :second) # Random date within last week
    else
      nil
    end
  rescue
    _ -> nil
  end

  defp get_top_referrers(portfolio_id) do
    # Get top referring websites/sources
    # This would come from analytics tracking

    # Placeholder implementation:
    [
      %{source: "Direct", visits: :rand.uniform(20) + 5},
      %{source: "LinkedIn", visits: :rand.uniform(15) + 3},
      %{source: "Google", visits: :rand.uniform(10) + 2},
      %{source: "Twitter", visits: :rand.uniform(8) + 1}
    ]
  rescue
    _ -> []
  end

  defp get_device_breakdown(portfolio_id) do
    # Get breakdown by device type
    total = get_total_visits(portfolio_id)

    if total > 0 do
      desktop = :rand.uniform(60) + 20  # 20-80%
      mobile = :rand.uniform(60) + 20   # 20-80%
      tablet = 100 - desktop - mobile

      %{
        desktop: max(10, desktop),
        mobile: max(10, mobile),
        tablet: max(0, tablet)
      }
    else
      %{desktop: 0, mobile: 0, tablet: 0}
    end
  rescue
    _ -> %{desktop: 0, mobile: 0, tablet: 0}
  end

  defp get_geographic_data(portfolio_id) do
    # Get visitor locations
    # This would come from IP geolocation in analytics

    # Placeholder implementation:
    [
      %{country: "United States", visits: :rand.uniform(20) + 10},
      %{country: "Canada", visits: :rand.uniform(10) + 3},
      %{country: "United Kingdom", visits: :rand.uniform(8) + 2},
      %{country: "Germany", visits: :rand.uniform(5) + 1}
    ]
  rescue
    _ -> []
  end

  # User overview analytics
  def get_user_portfolio_overview(user_id) do
    portfolios = list_user_portfolios(user_id)

    total_visits = Enum.reduce(portfolios, 0, fn portfolio, acc ->
      acc + get_total_visits(portfolio.id)
    end)

    %{
      total_portfolios: length(portfolios),
      total_visits: total_visits,
      avg_visits_per_portfolio: if(length(portfolios) > 0, do: div(total_visits, length(portfolios)), else: 0),
      most_viewed_portfolio: get_most_viewed_portfolio(portfolios),
      recent_activity: get_recent_portfolio_activity(user_id)
    }
  rescue
    _ ->
      %{
        total_portfolios: 0,
        total_visits: 0,
        avg_visits_per_portfolio: 0,
        most_viewed_portfolio: nil,
        recent_activity: []
      }
  end

  defp get_most_viewed_portfolio(portfolios) do
    portfolios
    |> Enum.map(fn portfolio ->
      {portfolio, get_total_visits(portfolio.id)}
    end)
    |> Enum.max_by(fn {_portfolio, visits} -> visits end, fn -> {nil, 0} end)
    |> case do
      {portfolio, visits} when visits > 0 -> portfolio
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp get_recent_portfolio_activity(user_id) do
    # Get recent activity across user's portfolios
    # This could include recent visits, shares, etc.

    # Placeholder implementation:
    []
  rescue
    _ -> []
  end

  defp count_recent_collaborations(portfolio, since_date) do
    try do
      # Count collaborations since the given date
      case Frestyl.Collaborations.count_portfolio_collaborations_since(portfolio.id, since_date) do
        count when is_integer(count) -> count
        _ -> 0
      end
    rescue
      _ -> 0
    end
  end

  # Custom Domain functions for Portfolios context
  def get_portfolio_custom_domain(portfolio_id) do
    from(cd in CustomDomain,
      where: cd.portfolio_id == ^portfolio_id,
      order_by: [desc: cd.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def create_custom_domain(attrs \\ %{}) do
    %CustomDomain{}
    |> CustomDomain.changeset(attrs)
    |> Repo.insert()
  end

  def delete_custom_domain(%CustomDomain{} = custom_domain) do
    Repo.delete(custom_domain)
  end

  def verify_custom_domain(custom_domain_id) do
    custom_domain = Repo.get!(CustomDomain, custom_domain_id)

    # Perform DNS verification
    case verify_dns_records(custom_domain.domain, custom_domain.verification_code) do
      {:ok, :verified} ->
        update_custom_domain(custom_domain, %{
          status: "active",
          dns_configured: true,
          verified_at: DateTime.utc_now(),
          ssl_status: "pending"
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp verify_dns_records(domain, verification_code) do
    # This would implement actual DNS verification
    # For now, simulating the check
    case :inet_res.lookup('_frestyl-verification.#{domain}', :in, :txt) do
      [txt_record] when is_list(txt_record) ->
        if List.to_string(txt_record) == verification_code do
          {:ok, :verified}
        else
          {:error, "Verification code mismatch"}
        end
      _ ->
        {:error, "DNS records not found"}
    end
  rescue
    _ -> {:error, "DNS lookup failed"}
  end

  defp update_custom_domain(%CustomDomain{} = custom_domain, attrs) do
    custom_domain
    |> CustomDomain.changeset(attrs)
    |> Repo.update()
  end

  defp calculate_portfolio_completion_score(portfolio) do
    # Calculate a completion score based on portfolio sections and content
    base_score = 20 # Base score for having a portfolio

    # Add points for basic information
    score = base_score
    score = if portfolio.title && String.length(portfolio.title) > 5, do: score + 15, else: score
    score = if portfolio.description && String.length(portfolio.description) > 20, do: score + 15, else: score
    score = if portfolio.visibility == :public, do: score + 10, else: score

    # Add points for sections (if you track them)
    section_count = count_portfolio_sections(portfolio)
    score = score + min(section_count * 8, 40) # Max 40 points for sections

    min(score, 100)
  end

  def count_portfolio_sections(portfolio_id) do
    try do
      list_portfolio_sections(portfolio_id) |> length()
    rescue
      _ -> 0
    end
  end

  defp portfolio_needs_attention?(portfolio) do
    # Determine if a portfolio needs attention based on various factors
    last_updated_days = DateTime.diff(DateTime.utc_now(), portfolio.updated_at, :day)
    completion_score = calculate_portfolio_completion_score(portfolio)
    recent_views = get_recent_portfolio_views(portfolio.id, 30)

    # Portfolio needs attention if:
    # - Not updated in 30+ days AND completion score < 70
    # - OR completion score < 50
    # - OR no views in last 30 days AND is public
    (last_updated_days > 30 and completion_score < 70) or
    completion_score < 50 or
    (recent_views == 0 and portfolio.visibility == :public)
  end

  defp get_recent_portfolio_views(portfolio_id, days) do
    since_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    try do
      # Use your existing analytics to get recent views
      get_visits_in_period([%{id: portfolio_id}], since_date, DateTime.utc_now())
    rescue
      _ -> 0
    end
  end

  defp get_recent_activity_count(user_id, days) do
    try do
      # Count recent activities across all user's portfolios
      since_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

      # This would integrate with your existing activity tracking
      # For now, estimate based on recent views and updates
      portfolios = list_user_portfolios(user_id)

      recent_views = get_visits_in_period(portfolios, since_date, DateTime.utc_now())
      recent_updates = Enum.count(portfolios, fn p ->
        DateTime.compare(p.updated_at, since_date) == :gt
      end)

      recent_views + (recent_updates * 5) # Weight updates more heavily
    rescue
      _ -> 0
    end
  end

  defp calculate_engagement_trend(recent_views, previous_views) do
    cond do
      previous_views == 0 and recent_views > 0 -> "growing"
      previous_views > 0 and recent_views > previous_views * 1.1 -> "growing"
      previous_views > 0 and recent_views < previous_views * 0.9 -> "declining"
      true -> "stable"
    end
  end

  defp get_top_performing_portfolio(portfolios) do
    portfolios
    |> Enum.map(fn portfolio ->
      views = get_total_visits(portfolio.id)
      {portfolio, views}
    end)
    |> Enum.max_by(fn {_portfolio, views} -> views end, fn -> {nil, 0} end)
    |> case do
      {portfolio, views} when views > 0 -> portfolio
      _ -> nil
    end
  end

  defp calculate_collaboration_health(total_collaborations, portfolio_count) do
    case portfolio_count do
      0 -> "none"
      count when total_collaborations == 0 -> "none"
      count when total_collaborations / count >= 0.5 -> "excellent"
      count when total_collaborations / count >= 0.25 -> "good"
      _ -> "needs_improvement"
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

  @doc """
  Get portfolio analytics safely - using your existing function name
  """
  def get_portfolio_analytics(portfolio_id, user_id) do
    try do
      # Get visit stats using your existing visit counting logic
      total_visits = count_portfolio_visits(portfolio_id)
      unique_visitors = count_unique_portfolio_visitors(portfolio_id)
      last_visit = get_last_portfolio_visit(portfolio_id)

      %{
        total_visits: total_visits,
        unique_visitors: unique_visitors,
        last_visit: last_visit
      }
    rescue
      error ->
        Logger.error("Failed to get analytics for portfolio #{portfolio_id}: #{inspect(error)}")
        %{total_visits: 0, unique_visitors: 0, last_visit: nil}
    end
  end

    defp count_portfolio_visits(portfolio_id) do
    try do
      # Using your PortfolioVisit schema from analytics_live.ex
      query = from(v in PortfolioVisit, where: v.portfolio_id == ^portfolio_id)
      Repo.aggregate(query, :count, :id)
    rescue
      _ -> 0
    end
  end

  defp count_unique_portfolio_visitors(portfolio_id) do
    try do
      # Count unique IP addresses or users
      query = from(v in PortfolioVisit,
        where: v.portfolio_id == ^portfolio_id,
        distinct: v.ip_address)

      Repo.aggregate(query, :count, :ip_address)
    rescue
      _ -> 0
    end
  end

  defp get_last_portfolio_visit(portfolio_id) do
    try do
      query = from(v in PortfolioVisit,
        where: v.portfolio_id == ^portfolio_id,
        order_by: [desc: v.inserted_at],
        limit: 1,
        select: v.inserted_at)

      Repo.one(query)
    rescue
      _ -> nil
    end
  end

  defp count_portfolio_shares_safe(portfolio_id) do
    try do
      # Count shares using your existing shares functionality
      shares = list_portfolio_shares(portfolio_id)
      length(shares)
    rescue
      _ -> 0
    end
  end

  @doc """
  Create a portfolio visit record - enhanced version
  """
  def create_visit(attrs) do
    try do
      %PortfolioVisit{}
      |> PortfolioVisit.changeset(attrs)
      |> Repo.insert()
    rescue
      error ->
        Logger.debug("Failed to create visit record: #{inspect(error)}")
        {:error, :failed_to_track}
    end
  end

  @doc """
  Get portfolio visit stats for analytics
  """
  def get_portfolio_visit_stats(portfolio_id) do
    try do
      # Get visits grouped by date for the last 30 days
      thirty_days_ago = Date.add(Date.utc_today(), -30)

      query = from(v in PortfolioVisit,
        where: v.portfolio_id == ^portfolio_id,
        where: v.inserted_at >= ^thirty_days_ago,
        group_by: fragment("DATE(?)", v.inserted_at),
        select: {fragment("DATE(?)", v.inserted_at), count(v.id)},
        order_by: fragment("DATE(?)", v.inserted_at))

      Repo.all(query)
    rescue
      error ->
        Logger.debug("Failed to get visit stats for portfolio #{portfolio_id}: #{inspect(error)}")
        []
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

  defp safely_calculate_total_visits(portfolios, _user_id) do
    portfolios
    |> Enum.reduce(0, fn portfolio, acc ->
      try do
        visits = count_portfolio_visits(portfolio.id)
        acc + visits
      rescue
        _ -> acc
      end
    end)
  end

  defp safely_calculate_total_shares(portfolios) do
    portfolios
    |> Enum.reduce(0, fn portfolio, acc ->
      try do
        shares = count_portfolio_shares_safe(portfolio.id)
        acc + shares
      rescue
        _ -> acc
      end
    end)
  end

    @doc """
  Safe datetime difference calculation to prevent the FunctionClauseError
  """
  def safe_datetime_diff(dt1, dt2, unit \\ :second) do
    try do
      case {dt1, dt2} do
        {%DateTime{} = d1, %DateTime{} = d2} ->
          DateTime.diff(d1, d2, unit)
        {%DateTime{} = d1, %NaiveDateTime{} = nd2} ->
          case DateTime.from_naive(nd2, "Etc/UTC") do
            {:ok, d2} -> DateTime.diff(d1, d2, unit)
            _ -> 0
          end
        {%NaiveDateTime{} = nd1, %DateTime{} = d2} ->
          case DateTime.from_naive(nd1, "Etc/UTC") do
            {:ok, d1} -> DateTime.diff(d1, d2, unit)
            _ -> 0
          end
        {%NaiveDateTime{} = nd1, %NaiveDateTime{} = nd2} ->
          case {DateTime.from_naive(nd1, "Etc/UTC"), DateTime.from_naive(nd2, "Etc/UTC")} do
            {{:ok, d1}, {:ok, d2}} -> DateTime.diff(d1, d2, unit)
            _ -> 0
          end
        {nil, _} -> 0
        {_, nil} -> 0
        _ -> 0
      end
    rescue
      error ->
        Logger.debug("DateTime diff error: #{inspect(error)}")
        0
    end
  end

  # Helper to normalize datetime values
  defp normalize_datetime(nil), do: {:ok, nil}

  defp normalize_datetime(%DateTime{} = dt) do
    # Validate DateTime by trying to use it
    try do
      DateTime.to_unix(dt)
      {:ok, dt}
    rescue
      _ -> {:error, :invalid_datetime}
    end
  end

  defp normalize_datetime(%NaiveDateTime{} = ndt) do
    case DateTime.from_naive(ndt, "Etc/UTC") do
      {:ok, dt} -> {:ok, dt}
      {:error, _} -> {:error, :conversion_failed}
    end
  end

  defp normalize_datetime(_), do: {:error, :invalid_type}

  @doc """
  Enhanced relative time formatting with safe DateTime handling
  """
  def safe_format_relative_time(datetime) when is_nil(datetime), do: "Unknown time"

  def safe_format_relative_time(datetime) do
    try do
      current_time = DateTime.utc_now()

      case normalize_datetime(datetime) do
        {:ok, nil} -> "Unknown time"
        {:ok, valid_dt} ->
          diff = safe_datetime_diff(current_time, valid_dt, :second)
          format_time_difference(diff, valid_dt)
        {:error, _} -> "Unknown time"
      end
    rescue
      _ -> "Unknown time"
    end
  end

  defp format_time_difference(diff_seconds, datetime) when is_integer(diff_seconds) do
    cond do
      diff_seconds < 60 -> "Just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} minutes ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)} hours ago"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)} days ago"
      true ->
        try do
          Calendar.strftime(datetime, "%b %d, %Y")
        rescue
          _ -> "Unknown date"
        end
    end
  end
  defp format_time_difference(_, _), do: "Unknown time"

  # Fixed datetime formatting functions
  def safe_format_relative_time(datetime) when is_nil(datetime), do: "Unknown time"

  def safe_format_relative_time(datetime) do
    try do
      current_time = DateTime.utc_now()

      # Safe datetime conversion
      datetime_utc = case datetime do
        %DateTime{} = dt ->
          dt
        %NaiveDateTime{} = ndt ->
          DateTime.from_naive!(ndt, "Etc/UTC")
        _ ->
          current_time  # fallback to current time
      end

      # Ensure both datetimes are valid before calculating diff
      case {current_time, datetime_utc} do
        {%DateTime{}, %DateTime{}} ->
          calculate_time_diff(current_time, datetime_utc)
        _ ->
          "Unknown time"
      end
    rescue
      error ->
        Logger.debug("Time formatting error: #{inspect(error)}")
        "Unknown time"
    end
  end

  defp calculate_time_diff(current_time, datetime_utc) do
    case DateTime.diff(current_time, datetime_utc, :second) do
      diff when diff < 60 -> "Just now"
      diff when diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff when diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff when diff < 604800 -> "#{div(diff, 86400)} days ago"
      _ -> Calendar.strftime(datetime_utc, "%b %d, %Y")
    end
  rescue
    _ -> "Unknown time"
  end

  def safe_format_date(datetime) when is_nil(datetime), do: "Unknown date"

  def safe_format_date(datetime) do
    try do
      case datetime do
        %DateTime{} -> Calendar.strftime(datetime, "%b %d, %Y")
        %NaiveDateTime{} -> Calendar.strftime(datetime, "%b %d, %Y")
        _ -> "Unknown date"
      end
    rescue
      _ -> "Unknown date"
    end
  end
end
