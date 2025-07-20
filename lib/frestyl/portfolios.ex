defmodule Frestyl.Portfolios do
  @moduledoc """
  Enhanced Portfolios context with social integration and four-tier privacy system.
  Seamlessly integrated with existing functionality.
  """

  use Ecto.Schema
  import Ecto.Changeset

  import Ecto.Query, warn: false
  require Logger  # 🔥 ADD THIS LINE
  alias Ecto.Multi

  alias Frestyl.Repo
  alias Frestyl.Portfolios.{
    CustomDomain, Portfolio, PortfolioSection, PortfolioMedia,
    PortfolioShare, PortfolioVisit, PortfolioService, StreamingConfig
  }

  # 🔥 ADD THESE CONDITIONAL ALIASES - They won't break if models don't exist yet
  alias Frestyl.Accounts.User
  alias Frestyl.Streaming.StreamingSession

  # 🔥 CONDITIONAL: Only alias social models if they exist
  if Code.ensure_loaded?(Frestyl.Portfolios.SocialIntegration) do
    alias Frestyl.Portfolios.{
      SocialIntegration, SocialPost, AccessRequest, SharingAnalytic
    }
    alias Frestyl.Portfolios.Social
  end

    # ============================================================================
  # 🔥 NEW: ENHANCED PORTFOLIO ACCESS CONTROL
  # ============================================================================

  def get_public_portfolios do
    from(p in Portfolio,
      where: p.visibility == :public,
      order_by: [desc: p.updated_at]
    )
    |> Repo.all()
  end

  def get_portfolio_with_access_check(identifier, user \\ nil, access_token \\ nil) do
    cond do
      is_slug?(identifier) ->
        get_portfolio_by_slug_with_privacy_check(identifier, user, access_token)
      is_share_token?(identifier) ->
        get_portfolio_by_share_token_with_privacy_check(identifier, user)
      true ->
        {:error, :invalid_identifier}
    end
  end

  def update_portfolio_visibility(portfolio_id, visibility, user_id) when visibility in ["public", "link_only", "request_only", "private"] do
    portfolio = get_portfolio!(portfolio_id)

    if portfolio.user_id == user_id do
      visibility_atom = String.to_atom(visibility)
      update_portfolio(portfolio, %{visibility: visibility_atom})
    else
      {:error, :unauthorized}
    end
  end

  def list_portfolios_by_visibility(user_id, visibility) when visibility in [:public, :link_only, :request_only, :private] do
    from(p in Portfolio,
      where: p.user_id == ^user_id and p.visibility == ^visibility,
      order_by: [desc: p.updated_at]
    )
    |> Repo.all()
  end

  defp is_slug?(identifier) do
    String.length(identifier) < 64 and String.match?(identifier, ~r/^[a-z0-9-]+$/)
  end

  defp is_share_token?(identifier) do
    String.length(identifier) >= 64
  end

  def get_portfolio_by_slug_with_privacy_check(slug, user, access_token) do
    query = from p in Portfolio,
      where: p.slug == ^slug,
      preload: [
        :user,
        portfolio_sections: [portfolio_media: []],
        social_integrations: [:social_posts],
        access_requests: []
      ]

    case Repo.one(query) do
      nil -> {:error, :not_found}
      portfolio -> check_portfolio_access(portfolio, user, access_token)
    end
  end

  def get_portfolio_by_share_token_with_privacy_check(token, user) do
    query = from s in PortfolioShare,
      where: s.token == ^token,
      join: p in Portfolio, on: p.id == s.portfolio_id,
      preload: [
        portfolio: [
          :user,
          portfolio_sections: [portfolio_media: []],
          social_integrations: [:social_posts]
        ]
      ]

    case Repo.one(query) do
      nil -> {:error, :not_found}
      share -> check_share_access(share.portfolio, share, user)
    end
  end

  def get_portfolio_with_account(portfolio_id) do
    query = from p in Portfolio,
      where: p.id == ^portfolio_id,
      preload: [:user]

    case Repo.one(query) do
      nil ->
        nil
      portfolio ->
        # Try to get accounts safely
        accounts = try do
          Frestyl.Accounts.list_user_accounts(portfolio.user.id)
        rescue
          _ -> []
        end

        account = List.first(accounts) || %{subscription_tier: "personal"}

        %{portfolio: portfolio, account: account}
    end
  end

  def list_user_portfolios(user_id) do
    from(p in Portfolio,
      where: p.user_id == ^user_id,
      preload: [:user],
      order_by: [desc: p.updated_at]
    )
    |> Repo.all()
  end

  defp check_portfolio_access(portfolio, user, access_token) do
    case portfolio.visibility do
      :public ->
        {:ok, portfolio, :public_access}

      :link_only ->
        {:ok, portfolio, :link_access}

      :request_only ->
        check_request_access(portfolio, user, access_token)

      :private ->
        check_private_access(portfolio, user)
    end
  end

  defp check_request_access(portfolio, user, access_token) do
    cond do
      is_portfolio_owner?(portfolio, user) ->
        {:ok, portfolio, :owner_access}

      valid_access_token?(portfolio.id, access_token) ->
        {:ok, portfolio, :token_access}

      true ->
        {:error, :access_request_required, portfolio}
    end
  end

  defp check_private_access(portfolio, user) do
    cond do
      is_portfolio_owner?(portfolio, user) ->
        {:ok, portfolio, :owner_access}

      is_collaborator?(portfolio, user) ->
        {:ok, portfolio, :collaborator_access}

      true ->
        {:error, :access_denied}
    end
  end

  defp check_share_access(portfolio, share, user) do
    cond do
      share_expired?(share) ->
        {:error, :share_expired}

      share.approved or is_portfolio_owner?(portfolio, user) ->
        increment_share_view_count(share.token)
        {:ok, portfolio, :share_access}

      true ->
        {:error, :share_not_approved}
    end
  end

  defp is_portfolio_owner?(portfolio, user) do
    user && portfolio.user_id == user.id
  end

  defp is_collaborator?(portfolio, user) do
    user && portfolio.collaboration_settings &&
    user.id in Map.get(portfolio.collaboration_settings, "collaborator_ids", [])
  end

  defp valid_access_token?(portfolio_id, access_token) do
    case access_token do
      nil -> false
      token ->
        case Social.get_access_request_by_token(token) do
          nil -> false
          request -> request.portfolio_id == portfolio_id
        end
    end
  end

  defp share_expired?(share) do
    share.expires_at && DateTime.compare(DateTime.utc_now(), share.expires_at) == :gt
  end

  # Custom fields

  def create_custom_field_definition(attrs) do
    Frestyl.Portfolios.CustomFieldDefinition.create(attrs)
  end

  def update_custom_field_definition(definition, attrs) do
    Frestyl.Portfolios.CustomFieldDefinition.update(definition, attrs)
  end

  def delete_custom_field_definition(definition) do
    Frestyl.Portfolios.CustomFieldDefinition.delete(definition)
  end

  def list_custom_field_definitions(portfolio_id) do
    Frestyl.Portfolios.CustomFieldDefinition.list_for_portfolio(portfolio_id)
  end

  def get_custom_field_definition!(id) do
    Frestyl.Portfolios.CustomFieldDefinition.get!(id)
  end

  def create_custom_field_value(attrs) do
    Frestyl.Portfolios.CustomFieldValue.create(attrs)
  end

  def update_custom_field_value(value, attrs) do
    Frestyl.Portfolios.CustomFieldValue.update(value, attrs)
  end

  def delete_custom_field_value(value) do
    Frestyl.Portfolios.CustomFieldValue.delete(value)
  end

  def list_custom_field_values(portfolio_id, section_id \\ nil) do
    Frestyl.Portfolios.CustomFieldValue.list_for_portfolio(portfolio_id, section_id)
  end

  def get_custom_field_value!(id) do
    Frestyl.Portfolios.CustomFieldValue.get!(id)
  end

  def apply_field_template(portfolio_id, template_name) do
    Frestyl.Portfolios.CustomFieldDefinition.apply_template(portfolio_id, template_name)
  end

  def validate_custom_field_value(value, definition) do
    Frestyl.Portfolios.CustomFieldValue.validate_against_definition(value, definition)
  end

  defp validate_text_field(value, rules) when is_binary(value) do
    cond do
      Map.get(rules, "min_length") && String.length(value) < rules["min_length"] ->
        {:error, "Text too short (minimum #{rules["min_length"]} characters)"}

      Map.get(rules, "max_length") && String.length(value) > rules["max_length"] ->
        {:error, "Text too long (maximum #{rules["max_length"]} characters)"}

      Map.get(rules, "pattern") && !Regex.match?(~r/#{rules["pattern"]}/, value) ->
        {:error, "Text does not match required pattern"}

      true -> {:ok, value}
    end
  end

  defp validate_number_field(value, rules) when is_number(value) do
    cond do
      Map.get(rules, "min_value") && value < rules["min_value"] ->
        {:error, "Value too small (minimum #{rules["min_value"]})"}

      Map.get(rules, "max_value") && value > rules["max_value"] ->
        {:error, "Value too large (maximum #{rules["max_value"]})"}

      Map.get(rules, "integer_only", false) && !is_integer(value) ->
        {:error, "Value must be an integer"}

      true -> {:ok, value}
    end
  end

  defp validate_list_field(value, rules) when is_list(value) do
    cond do
      Map.get(rules, "min_items") && length(value) < rules["min_items"] ->
        {:error, "Too few items (minimum #{rules["min_items"]})"}

      Map.get(rules, "max_items") && length(value) > rules["max_items"] ->
        {:error, "Too many items (maximum #{rules["max_items"]})"}

      Map.get(rules, "allowed_values") && !Enum.all?(value, &(&1 in rules["allowed_values"])) ->
        {:error, "Contains invalid values"}

      true -> {:ok, value}
    end
  end

  defp validate_date_field(value, _rules) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, _date} -> {:ok, value}
      {:error, _} -> {:error, "Invalid date format"}
    end
  end

  defp validate_url_field(value, _rules) when is_binary(value) do
    if String.match?(value, ~r/^https?:\/\/.+/) do
      {:ok, value}
    else
      {:error, "Invalid URL format"}
    end
  end

  defp validate_email_field(value, _rules) when is_binary(value) do
    if String.match?(value, ~r/^[^\s]+@[^\s]+\.[^\s]+$/) do
      {:ok, value}
    else
      {:error, "Invalid email format"}
    end
  end

  # Fallback for validation errors
  defp validate_text_field(_, _), do: {:error, "Invalid text value"}
  defp validate_number_field(_, _), do: {:error, "Invalid number value"}
  defp validate_list_field(_, _), do: {:error, "Invalid list value"}

  # ============================================================================
  # 🔥 NEW: SOCIAL SECTION CREATION & MANAGEMENT
  # ============================================================================

  def create_social_section(portfolio_id, user_id) do
    case get_social_section(portfolio_id) do
      nil ->
        create_new_social_section(portfolio_id)
      existing_section ->
        {:ok, existing_section}
    end
  end

  defp get_social_section(portfolio_id) do
    PortfolioSection
    |> where([s], s.portfolio_id == ^portfolio_id and s.section_type == "social")
    |> Repo.one()
  end

  defp create_new_social_section(portfolio_id) do
    max_position = get_max_section_position(portfolio_id)

    attrs = %{
      portfolio_id: portfolio_id,
      title: "Social & Professional Profiles",
      section_type: "social",
      position: max_position + 1,
      content: %{
        "layout" => "unified_cards",
        "show_follower_counts" => true,
        "show_recent_posts" => true,
        "auto_refresh" => true,
        "max_posts_per_platform" => 3,
        "display_style" => "modern_cards"
      },
      visible: true
    }

    create_section(attrs)
  end

  def update_social_section_content(section_id, integrations_data) do
    section = get_section!(section_id)

    updated_content = Map.merge(section.content || %{}, %{
      "platforms" => integrations_data,
      "last_updated" => DateTime.utc_now() |> DateTime.to_iso8601()
    })

    update_section(section, %{content: updated_content})
  end

  def refresh_social_section_data(portfolio_id) do
    with social_section when not is_nil(social_section) <- get_social_section(portfolio_id),
         integrations <- Social.list_portfolio_social_integrations(portfolio_id) do

      Enum.each(integrations, &Social.sync_integration_posts/1)

      integrations_data = Enum.map(integrations, fn integration ->
        recent_posts = Social.list_social_posts(integration.id, integration.max_posts)

        %{
          platform: integration.platform,
          username: integration.username,
          display_name: integration.display_name,
          profile_url: integration.profile_url,
          avatar_url: integration.avatar_url,
          follower_count: integration.follower_count,
          bio: integration.bio,
          verified: integration.verified,
          recent_posts: Enum.map(recent_posts, &format_post_for_display/1),
          last_sync_at: integration.last_sync_at,
          public_visibility: integration.public_visibility
        }
      end)

      update_social_section_content(social_section.id, integrations_data)
    else
      nil -> {:error, :social_section_not_found}
      error -> error
    end
  end

  def create_or_update_video_intro_section(attrs) do
    portfolio_id = attrs.portfolio_id

    case get_video_intro_section(portfolio_id) do
      nil ->
        # Create new video intro section
        %PortfolioSection{}
        |> PortfolioSection.changeset(attrs)
        |> Repo.insert()

      existing_section ->
        # Update existing section
        existing_section
        |> PortfolioSection.changeset(attrs)
        |> Repo.update()
    end
  end

  def get_video_intro_section(portfolio_id) do
    from(s in PortfolioSection,
      where: s.portfolio_id == ^portfolio_id and s.section_type == :video_intro,
      limit: 1
    )
    |> Repo.one()
  end

  defp format_post_for_display(post) do
    %{
      id: post.id,
      content: truncate_content(post.content, 150),
      media_urls: post.media_urls || [],
      post_url: post.post_url,
      posted_at: post.posted_at,
      post_type: post.post_type,
      likes_count: post.likes_count,
      comments_count: post.comments_count,
      shares_count: post.shares_count,
      hashtags: post.hashtags || []
    }
  end

  defp truncate_content(content, max_length) when is_binary(content) do
    if String.length(content) > max_length do
      String.slice(content, 0, max_length) <> "..."
    else
      content
    end
  end
  defp truncate_content(content, _), do: content || ""

  # ============================================================================
  # 🔥 NEW: PRIVACY SETTINGS MANAGEMENT
  # ============================================================================

  def update_portfolio_privacy_settings(portfolio_id, privacy_settings, user_id) do
    portfolio = get_portfolio!(portfolio_id)

    if portfolio.user_id == user_id do
      validated_settings = validate_and_merge_privacy_settings(portfolio.privacy_settings, privacy_settings)
      update_portfolio(portfolio, %{privacy_settings: validated_settings})
    else
      {:error, :unauthorized}
    end
  end

  defp validate_and_merge_privacy_settings(current_settings, new_settings) do
    default_settings = %{
      "allow_search_engines" => false,
      "show_in_discovery" => false,
      "require_login_to_view" => false,
      "watermark_images" => false,
      "disable_right_click" => false,
      "track_visitor_analytics" => true,
      "allow_social_sharing" => true,
      "show_contact_info" => true,
      "allow_downloads" => false
    }

    current_settings
    |> Map.merge(default_settings, fn _k, v1, v2 -> v1 || v2 end)
    |> Map.merge(new_settings)
    |> Enum.filter(fn {k, _v} -> k in Map.keys(default_settings) end)
    |> Enum.into(%{})
  end

  def update_portfolio_visibility(portfolio_id, visibility, user_id) do
    portfolio = get_portfolio!(portfolio_id)

    if portfolio.user_id == user_id do
      case visibility do
        vis when vis in [:public, :link_only, :request_only, :private] ->
          update_portfolio(portfolio, %{visibility: visibility})
        _ ->
          {:error, :invalid_visibility}
      end
    else
      {:error, :unauthorized}
    end
  end

  def get_portfolio_privacy_summary(portfolio) do
    settings = portfolio.privacy_settings || %{}

    %{
      visibility: portfolio.visibility,
      searchable: Map.get(settings, "allow_search_engines", false),
      discoverable: Map.get(settings, "show_in_discovery", false),
      requires_login: Map.get(settings, "require_login_to_view", false),
      social_sharing_enabled: Map.get(settings, "allow_social_sharing", true),
      contact_info_visible: Map.get(settings, "show_contact_info", true),
      downloads_allowed: Map.get(settings, "allow_downloads", false),
      analytics_enabled: Map.get(settings, "track_visitor_analytics", true)
    }
  end

  # ============================================================================
  # 🔥 NEW: SHARING & ANALYTICS FUNCTIONS
  # ============================================================================

  def create_portfolio_share_with_analytics(portfolio_id, share_params, user_id) do
    portfolio = get_portfolio!(portfolio_id)

    if portfolio.user_id == user_id do
      case create_share(Map.put(share_params, "portfolio_id", portfolio_id)) do
        {:ok, share} ->
          Social.track_event(portfolio_id, :portfolio_shared, %{
            platform: share_params["platform"] || "direct_link",
            user_id: user_id,
            share_id: share.id
          })
          {:ok, share}
        error ->
          error
      end
    else
      {:error, :unauthorized}
    end
  end

  def track_portfolio_visit_with_analytics(portfolio, visitor_data) do
    visit_attrs = %{
      portfolio_id: portfolio.id,
      ip_address: visitor_data[:ip_address],
      user_agent: visitor_data[:user_agent],
      referrer: visitor_data[:referrer],
      user_id: visitor_data[:user_id]
    }

    create_visit(visit_attrs)

    privacy_settings = portfolio.privacy_settings || %{}
    if Map.get(privacy_settings, "track_visitor_analytics", true) do
      Social.track_event(portfolio.id, :portfolio_viewed, %{
        ip_address: visitor_data[:ip_address],
        user_agent: visitor_data[:user_agent],
        referrer_url: visitor_data[:referrer],
        session_id: visitor_data[:session_id],
        visitor_id: visitor_data[:visitor_id],
        device_type: visitor_data[:device_type],
        browser: visitor_data[:browser],
        country: visitor_data[:country],
        city: visitor_data[:city]
      })
    end
  end

  def track_social_share_click(portfolio_id, platform, visitor_data) do
    Social.track_event(portfolio_id, :social_share_clicked, Map.merge(visitor_data, %{
      platform: platform
    }))
  end

  def track_contact_info_view(portfolio_id, visitor_data) do
    Social.track_event(portfolio_id, :contact_info_viewed, visitor_data)
  end

  def track_section_view(portfolio_id, section_id, visitor_data) do
    Social.track_event(portfolio_id, :section_viewed, Map.merge(visitor_data, %{
      section_id: section_id
    }))
  end

  def get_portfolio_analytics_dashboard(portfolio_id, user_id, date_range \\ 30) do
    portfolio = get_portfolio!(portfolio_id)

    if portfolio.user_id == user_id do
      analytics = Social.get_portfolio_analytics(portfolio_id, date_range)

      portfolio_metrics = %{
        total_sections: count_portfolio_sections(portfolio_id),
        social_integrations: count_social_integrations(portfolio_id),
        active_shares: count_active_shares(portfolio_id),
        pending_access_requests: count_pending_access_requests(portfolio_id)
      }

      Map.merge(analytics, %{portfolio_metrics: portfolio_metrics})
    else
      {:error, :unauthorized}
    end
  end

    # ============================================================================
  # VIDEO BLOCK SUPPORT FUNCTIONS
  # ============================================================================

  @doc """
  Creates a new video hero section
  """
  def create_video_hero_section(portfolio_id, attrs \\ %{}) do
    default_attrs = %{
      portfolio_id: portfolio_id,
      section_type: :video_hero,
      title: "Video Hero",
      content: PortfolioSection.default_content_for_type(:video_hero),
      position: get_next_section_position(portfolio_id),
      visible: true
    }

    attrs = Map.merge(default_attrs, attrs)

    %PortfolioSection{}
    |> PortfolioSection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates external video media record
  """
  def create_external_video_media(portfolio_id, section_id, attrs) do
    %PortfolioMedia{}
    |> PortfolioMedia.external_video_changeset(Map.merge(attrs, %{
      portfolio_id: portfolio_id,
      section_id: section_id
    }))
    |> Repo.insert()
  end

  @doc """
  Updates video metadata for a media record
  """
  def update_video_metadata(media_id, metadata) do
    case get_portfolio_media(media_id) do
      nil -> {:error, :not_found}
      media ->
        media
        |> PortfolioMedia.changeset(%{video_metadata: metadata})
        |> Repo.update()
    end
  end

  @doc """
  Gets all video media for a section
  """
  def list_section_video_media(section_id) do
    PortfolioMedia
    |> where([m], m.section_id == ^section_id)
    |> where([m], like(m.file_type, "video%") or m.is_external_video == true)
    |> order_by([m], m.sort_order)
    |> Repo.all()
  end

  @doc """
  Extracts video ID from YouTube or Vimeo URL
  """
  def extract_video_id(url, platform) do
    case {platform, url} do
      {"youtube", url} ->
        cond do
          String.contains?(url, "youtube.com/watch?v=") ->
            url |> String.split("v=") |> Enum.at(1) |> String.split("&") |> Enum.at(0)
          String.contains?(url, "youtu.be/") ->
            url |> String.split("youtu.be/") |> Enum.at(1) |> String.split("?") |> Enum.at(0)
          true -> nil
        end

      {"vimeo", url} ->
        case Regex.run(~r/vimeo\.com\/(\d+)/, url) do
          [_, video_id] -> video_id
          _ -> nil
        end

      _ -> nil
    end
  end

  @doc """
  Detects video platform from URL
  """
  def detect_video_platform(url) do
    cond do
      String.contains?(url, "youtube.com") or String.contains?(url, "youtu.be") -> "youtube"
      String.contains?(url, "vimeo.com") -> "vimeo"
      true -> nil
    end
  end

  # ============================================================================
  # ENHANCED SECTION MANAGEMENT
  # ============================================================================

  @doc """
  Gets a single section with error handling
  """
  def get_section(id) do
    Repo.get(PortfolioSection, id)
  end

  @doc """
  Safely deletes a section and its associated media
  """
  def delete_section(section) do
    Multi.new()
    |> Multi.delete(:section, section)
    |> Multi.run(:update_positions, fn repo, %{section: deleted_section} ->
      # Update positions of remaining sections
      from(s in PortfolioSection,
        where: s.portfolio_id == ^deleted_section.portfolio_id and s.position > ^deleted_section.position
      )
      |> repo.update_all(inc: [position: -1])

      {:ok, :positions_updated}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{section: section}} -> {:ok, section}
      {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
    end
  end

  # Also fix any other functions using Multi without the alias
  def delete_portfolio_section(section) do
    Multi.new()
    |> Multi.delete(:section, section)
    |> Repo.transaction()
    |> case do
      {:ok, %{section: section}} -> {:ok, section}
      {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Gets next position for a new section
  """
  def get_next_section_position(portfolio_id) do
    PortfolioSection
    |> where([s], s.portfolio_id == ^portfolio_id)
    |> select([s], max(s.position))
    |> Repo.one()
    |> case do
      nil -> 0
      max_pos -> max_pos + 1
    end
  end

  @doc """
  Lists sections organized by layout zones
  """
  def list_sections_by_zones(portfolio_id) do
    sections = list_portfolio_sections(portfolio_id)

    %{
      hero: filter_sections_by_types(sections, [:intro, :video_hero]),
      main_content: filter_sections_by_types(sections, [:experience, :projects, :skills, :achievements]),
      sidebar: filter_sections_by_types(sections, [:contact, :testimonial, :media_showcase]),
      footer: []
    }
  end

  defp filter_sections_by_types(sections, types) do
    Enum.filter(sections, fn section ->
      section.section_type in types
    end)
  end

  # ============================================================================
  # MEDIA MANAGEMENT ENHANCEMENTS
  # ============================================================================

  @doc """
  Gets portfolio media with optional filtering
  """
  def get_portfolio_media(id) do
    Repo.get(PortfolioMedia, id)
  end

  @doc """
  Lists media for a specific section
  """
  def list_section_media(section_id) do
    PortfolioMedia
    |> where([m], m.section_id == ^section_id)
    |> order_by([m], [m.sort_order, m.inserted_at])
    |> Repo.all()
  end

  @doc """
  Updates media sort order
  """
  def update_media_sort_order(media_id, new_order) do
    case get_portfolio_media(media_id) do
      nil -> {:error, :not_found}
      media ->
        media
        |> PortfolioMedia.changeset(%{sort_order: new_order})
        |> Repo.update()
    end
  end

  @doc """
  Attaches existing media to a section
  """
  def attach_media_to_section(media_id, section_id) do
    case get_portfolio_media(media_id) do
      nil -> {:error, :not_found}
      media ->
        media
        |> PortfolioMedia.changeset(%{section_id: section_id})
        |> Repo.update()
    end
  end

  @doc """
  Detaches media from a section
  """
  def detach_media_from_section(media_id) do
    case get_portfolio_media(media_id) do
      nil -> {:error, :not_found}
      media ->
        media
        |> PortfolioMedia.changeset(%{section_id: nil})
        |> Repo.update()
    end
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  @doc """
  Converts sections to dynamic layout zones format
  """
  def sections_to_layout_zones(sections) do
    sections
    |> Enum.group_by(&determine_zone_for_section/1)
    |> Enum.into(%{}, fn {zone, zone_sections} ->
      {zone, Enum.map(zone_sections, &section_to_block_format/1)}
    end)
  end

  defp determine_zone_for_section(section) do
    case section.section_type do
      type when type in [:intro, :video_hero] -> :hero
      type when type in [:experience, :projects, :skills, :achievements, :case_study] -> :main_content
      type when type in [:contact, :testimonial, :media_showcase] -> :sidebar
      _ -> :main_content
    end
  end

  defp section_to_block_format(section) do
    %{
      id: section.id,
      block_type: section.section_type,
      section_type: section.section_type,
      title: section.title,
      content: section.content || %{},
      position: section.position || 0,
      visible: section.visible,
      created_at: section.inserted_at,
      updated_at: section.updated_at
    }
  end

  @doc """
  Validates if a user can create video blocks based on subscription
  """
  def can_create_video_blocks?(user) do
    # This would check subscription tier - for now return true
    # In real implementation, check user.subscription_tier
    case Map.get(user, :subscription_tier, :personal) do
      tier when tier in [:creator, :professional, :enterprise] -> true
      _ -> false
    end
  end

  @doc """
  Gets video usage stats for a portfolio
  """
  def get_video_usage_stats(portfolio_id) do
    video_count = PortfolioMedia
    |> where([m], m.portfolio_id == ^portfolio_id)
    |> where([m], like(m.file_type, "video%") or m.is_external_video == true)
    |> select([m], count(m.id))
    |> Repo.one()

    total_duration = PortfolioMedia
    |> where([m], m.portfolio_id == ^portfolio_id)
    |> where([m], not is_nil(m.video_duration))
    |> select([m], sum(m.video_duration))
    |> Repo.one()

    %{
      video_count: video_count || 0,
      total_duration_seconds: total_duration || 0
    }
  end

  defp count_social_integrations(portfolio_id) do
    SocialIntegration
    |> where([s], s.portfolio_id == ^portfolio_id and s.sync_status == :active)
    |> select([s], count(s.id))
    |> Repo.one()
  end

  defp count_active_shares(portfolio_id) do
    PortfolioShare
    |> where([s], s.portfolio_id == ^portfolio_id and (is_nil(s.expires_at) or s.expires_at > ^DateTime.utc_now()))
    |> select([s], count(s.id))
    |> Repo.one()
  end

  defp count_pending_access_requests(portfolio_id) do
    AccessRequest
    |> where([r], r.portfolio_id == ^portfolio_id and r.status == :pending)
    |> select([r], count(r.id))
    |> Repo.one()
  end

  def get_portfolio_by_slug_with_sections_simple(slug) when is_binary(slug) do
    try do
      case Repo.get_by(Portfolio, slug: slug) do
        nil ->
          Logger.info("No portfolio found with slug: #{slug}")
          {:error, :not_found}

        portfolio ->
          # Preload user
          portfolio = Repo.preload(portfolio, :user)

          # Get sections with error handling
          sections = try do
            PortfolioSection
            |> where([s], s.portfolio_id == ^portfolio.id)
            |> order_by([s], s.position)
            |> Repo.all()
          rescue
            e ->
              Logger.error("Error loading sections for portfolio #{portfolio.id}: #{inspect(e)}")
              []
          end

          # Get media for sections
          section_ids = Enum.map(sections, & &1.id)
          media = if length(section_ids) > 0 do
            try do
              PortfolioMedia
              |> where([pm], pm.section_id in ^section_ids)
              |> order_by([pm], pm.section_id)
              |> Repo.all()
            rescue
              e ->
                Logger.error("Error loading media for sections: #{inspect(e)}")
                []
            end
          else
            []
          end

          # Group media by section and add to sections
          media_by_section = Enum.group_by(media, & &1.section_id)
          sections_with_media = Enum.map(sections, fn section ->
            section_media = Map.get(media_by_section, section.id, [])
            Map.put(section, :portfolio_media, section_media)
          end)

          portfolio_with_sections = Map.put(portfolio, :sections, sections_with_media)
          {:ok, portfolio_with_sections}
      end
    rescue
      e ->
        Logger.error("Critical error in get_portfolio_by_slug_with_sections_simple: #{inspect(e)}")
        {:error, :database_error}
    end
  end

  def get_portfolio_by_slug_with_sections_simple(_), do: {:error, :invalid_slug}

  def get_portfolio_by_share_token_simple(token) do
    IO.puts("🔥 LOADING SHARED PORTFOLIO: #{token}")

    query = from s in PortfolioShare,
      where: s.token == ^token,
      join: p in Portfolio, on: p.id == s.portfolio_id,
      preload: [
        portfolio: [
          :user,
          portfolio_sections: [portfolio_media: []],
          # 🔥 NEW: Include social integrations in shares
          social_integrations: [:social_posts]
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

        normalized_portfolio = %{
          id: portfolio.id,
          title: portfolio.title,
          description: portfolio.description,
          slug: portfolio.slug,
          theme: portfolio.theme,
          customization: portfolio.customization,
          visibility: portfolio.visibility,
          # 🔥 NEW: Include privacy and social settings
          privacy_settings: portfolio.privacy_settings,
          social_integration: portfolio.social_integration,
          contact_info: portfolio.contact_info,
          inserted_at: portfolio.inserted_at,
          updated_at: portfolio.updated_at,
          user: portfolio.user,
          sections: transform_sections_for_display(portfolio.portfolio_sections),
          # 🔥 NEW: Include transformed social integrations
          social_integrations: transform_social_integrations(portfolio.social_integrations || [])
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
  @doc """
  Get portfolio with account information
  """

  @doc """
  URGENT: Clean infinite legacy_backup loops from portfolio customization
  """

  defp get_user_account_safe(user_id) do
    try do
      case Accounts.get_user_with_account(user_id) do
        %{account: account} when not is_nil(account) -> account
        _ -> create_default_account()
      end
    rescue
      _ -> create_default_account()
    end
  end

  defp create_default_account do
    %{
      subscription_tier: "free",
      features: %{
        monetization_enabled: false,
        streaming_enabled: false,
        collaboration_enabled: false,
        advanced_analytics: false
      },
      limits: %{
        max_portfolios: 3,
        max_sections: 10,
        max_media_size_mb: 50
      }
    }
  end


  def get_portfolio_with_account_context(portfolio_id, user_id) do
    try do
      # First get the portfolio
      case get_portfolio_with_sections(portfolio_id) do
        nil -> {:error, :not_found}
        portfolio ->
          # Get the account through the user relationship
          account = get_user_account_safe(portfolio.user_id)
          {:ok, portfolio, account}
      end
    rescue
      e ->
        Logger.error("Error loading portfolio with account context: #{inspect(e)}")
        {:error, :database_error}
    end
  end

  @doc """
  Get portfolio section by ID
  """
  def get_portfolio_section(section_id) when is_integer(section_id) do
    try do
      PortfolioSection |> Repo.get(section_id)
    rescue
      _ -> nil
    end
  end

  def get_portfolio_section(section_id) when is_binary(section_id) do
    case Integer.parse(section_id) do
      {int_id, ""} -> get_portfolio_section(int_id)
      _ -> nil
    end
  end

  @doc """
  Create a new portfolio section
  """
  def create_portfolio_section(attrs) do
    try do
      %PortfolioSection{}
      |> PortfolioSection.changeset(attrs)
      |> Repo.insert()
    rescue
      e ->
        Logger.error("Error creating portfolio section: #{inspect(e)}")
        {:error, "Database error: #{Exception.message(e)}"}
    end
  end

  @doc """
  Delete a portfolio section
  """
  def delete_portfolio_section(section) do
    try do
      Repo.delete(section)
    rescue
      e ->
        Logger.error("Error deleting portfolio section: #{inspect(e)}")
        {:error, "Database error: #{Exception.message(e)}"}
    end
  end

  @doc """
  Get share by token
  """
  def get_share_by_token(token) when is_binary(token) do
    try do
      PortfolioShare
      |> where([s], s.token == ^token)
      |> Repo.one()
    rescue
      _ -> nil
    end
  end

  def get_share_by_token(_), do: nil

  @doc """
  List portfolio content blocks
  """
  def list_portfolio_content_blocks(portfolio_id) do
    try do
      ContentBlock
      |> where([cb], cb.portfolio_id == ^portfolio_id)
      |> order_by([cb], cb.position)
      |> Repo.all()
    rescue
      _ -> []
    end
  end

  def clean_legacy_backup_loops do
    require Logger
    Logger.info("🔧 Starting legacy backup cleanup...")

    # Get all portfolios with customization
    portfolios =
      Portfolio
      |> where([p], not is_nil(p.customization))
      |> Repo.all()

    Enum.each(portfolios, fn portfolio ->
      case clean_portfolio_customization(portfolio) do
        {:ok, _} ->
          Logger.info("✅ Cleaned portfolio #{portfolio.id} (#{portfolio.title})")
        {:error, reason} ->
          Logger.error("❌ Failed to clean portfolio #{portfolio.id}: #{reason}")
      end
    end)

    Logger.info("🔧 Legacy backup cleanup complete!")
  end

  defp clean_portfolio_customization(portfolio) do
    cleaned_customization = remove_recursive_legacy_backup(portfolio.customization)

    portfolio
    |> Portfolio.changeset(%{customization: cleaned_customization})
    |> Repo.update()
  end

  defp remove_recursive_legacy_backup(customization) when is_map(customization) do
    customization
    |> Map.drop(["legacy_backup"])  # Remove ALL legacy_backup keys
    |> Enum.into(%{}, fn {k, v} ->
      {k, remove_recursive_legacy_backup(v)}
    end)
  end

  defp remove_recursive_legacy_backup(value), do: value

  @doc """
  SAFE UPDATE: Update portfolio customization without creating recursive backups
  """
  def safe_update_portfolio_customization(portfolio, new_customization) do
    # Clean any existing legacy backups from new customization
    clean_customization = remove_recursive_legacy_backup(new_customization)

    # Create ONE level of backup (if needed)
    safe_customization =
      if should_create_backup?(portfolio.customization, clean_customization) do
        backup = create_safe_backup(portfolio.customization)
        Map.put(clean_customization, "legacy_backup", backup)
      else
        clean_customization
      end

    portfolio
    |> Portfolio.changeset(%{customization: safe_customization})
    |> Repo.update()
  end

  defp should_create_backup?(old_customization, new_customization) do
    # Only create backup for significant changes (like layout changes)
    layout_changed = Map.get(old_customization || %{}, "layout") != Map.get(new_customization, "layout")
    theme_changed = Map.get(old_customization || %{}, "theme") != Map.get(new_customization, "theme")

    layout_changed or theme_changed
  end

  defp create_safe_backup(customization) when is_map(customization) do
    # Create backup but NEVER include existing legacy_backup
    customization
    |> Map.drop(["legacy_backup"])
    |> Map.take(["layout", "theme", "primary_color", "secondary_color", "typography"])
  end

  defp create_safe_backup(_), do: %{}

  # Update your existing update_portfolio function to use safe update
  def update_portfolio(portfolio, attrs) do
    if Map.has_key?(attrs, :customization) do
      safe_update_portfolio_customization(portfolio, attrs.customization)
    else
      portfolio
      |> Portfolio.changeset(attrs)
      |> Repo.update()
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

  @doc """
  Get portfolio by ID (safe version)
  """
  def get_portfolio(id) when is_binary(id) do
    try do
      case Integer.parse(id) do
        {int_id, ""} -> get_portfolio(int_id)
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  def get_portfolio(id) when is_integer(id) do
    Portfolio
    |> Repo.get(id)
  end

  def get_portfolio(_), do: nil

  @doc """
  Get portfolio by ID (unsafe version - raises if not found)
  """
  def get_portfolio!(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> get_portfolio!(int_id)
      _ -> raise Ecto.NoResultsError, queryable: Portfolio
    end
  end

  def get_portfolio!(id) when is_integer(id) do
    Portfolio |> Repo.get!(id)
  end

  @doc """
  Get portfolio with preloaded sections
  """
  def get_portfolio_with_sections(id) do
    case get_portfolio(id) do
      nil -> nil
      portfolio ->
        portfolio
        |> Repo.preload([
          :user,
          sections: [
            :content_blocks,
            :portfolio_media
          ]
        ])
    end
  end

  @doc """
  Get portfolio by slug (safe version)
  """
  def get_portfolio_by_slug(slug) when is_binary(slug) do
    Portfolio
    |> where([p], p.slug == ^slug)
    |> Repo.one()
  end

  def get_portfolio_by_slug(_), do: nil

  @doc """
  Get portfolio by slug (unsafe version)
  """
  def get_portfolio_by_slug!(slug) when is_binary(slug) do
    Portfolio
    |> where([p], p.slug == ^slug)
    |> Repo.one!()
  end

  @doc """
  List all portfolios for a user
  """
  def list_user_portfolios(user_id) when is_integer(user_id) do
    Portfolio
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], desc: p.updated_at)
    |> Repo.all()
  end

  def list_user_portfolios(user_id) when is_binary(user_id) do
    case Integer.parse(user_id) do
      {int_id, ""} -> list_user_portfolios(int_id)
      _ -> []
    end
  end

  def list_user_portfolios(_), do: []

  @doc """
  Count portfolios for a user
  """
  def count_user_portfolios(user_id) do
    Portfolio
    |> where([p], p.user_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  rescue
    _ -> 0
  end

  @doc """
  Get portfolio limits for a user based on subscription
  """
  def get_portfolio_limits(user) do
    subscription_tier = get_user_subscription_tier(user)

    case subscription_tier do
      "admin" -> %{
        max_portfolios: -1,
        max_media_size_mb: 1000,
        custom_domain: true,
        advanced_analytics: true
      }
      "creator" -> %{
        max_portfolios: 25,
        max_media_size_mb: 500,
        custom_domain: true,
        advanced_analytics: true
      }
      "professional" -> %{
        max_portfolios: 10,
        max_media_size_mb: 250,
        custom_domain: true,
        advanced_analytics: false
      }
      _ -> %{
        max_portfolios: 3,
        max_media_size_mb: 100,
        custom_domain: false,
        advanced_analytics: false
      }
    end
  end

  defp get_user_subscription_tier(user) do
    cond do
      # Check direct subscription_tier field
      Map.has_key?(user, :subscription_tier) && user.subscription_tier ->
        user.subscription_tier

      # Check account association
      Map.has_key?(user, :account) && user.account && Map.has_key?(user.account, :subscription_tier) ->
        user.account.subscription_tier

      # Default to personal
      true ->
        "personal"
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

      # 🔥 NEW: Include social integration data
      social_stats = get_social_integration_stats(portfolio_id)

      %{
        views: total_visits,
        weekly_visits: weekly_visits,
        shares: share_stats.total_shares,
        active_shares: share_stats.active_shares,
        # 🔥 NEW: Social engagement metrics
        social_platforms: social_stats.platform_count,
        social_engagement: social_stats.total_engagement,
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
          social_platforms: 0,
          social_engagement: 0,
          last_updated: nil,
          created_at: nil
        }
    end
  end

  defp get_social_integration_stats(portfolio_id) do
    try do
      integrations = SocialIntegration
      |> where([s], s.portfolio_id == ^portfolio_id and s.sync_status == :active)
      |> Repo.all()

      total_engagement = Enum.reduce(integrations, 0, fn integration, acc ->
        posts = SocialPost
        |> where([p], p.social_integration_id == ^integration.id)
        |> Repo.all()

        post_engagement = Enum.reduce(posts, 0, fn post, post_acc ->
          post_acc + (post.likes_count || 0) + (post.comments_count || 0) + (post.shares_count || 0)
        end)

        acc + post_engagement
      end)

      %{
        platform_count: length(integrations),
        total_engagement: total_engagement
      }
    rescue
      _ -> %{platform_count: 0, total_engagement: 0}
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

  defp get_max_section_position(portfolio_id) do
    PortfolioSection
    |> where([s], s.portfolio_id == ^portfolio_id)
    |> select([s], max(s.position))
    |> Repo.one() || 0
  end

  defp transform_social_integrations(integrations) when is_list(integrations) do
    Enum.map(integrations, fn integration ->
      recent_posts = Enum.take(integration.social_posts || [], integration.max_posts || 3)

      %{
        id: integration.id,
        platform: integration.platform,
        username: integration.username,
        display_name: integration.display_name,
        profile_url: integration.profile_url,
        avatar_url: integration.avatar_url,
        follower_count: integration.follower_count,
        bio: integration.bio,
        verified: integration.verified,
        show_recent_posts: integration.show_recent_posts,
        show_follower_count: integration.show_follower_count,
        show_bio: integration.show_bio,
        public_visibility: integration.public_visibility,
        last_sync_at: integration.last_sync_at,
        sync_status: integration.sync_status,
        recent_posts: Enum.map(recent_posts, &format_post_for_display/1)
      }
    end)
  end
  defp transform_social_integrations(_), do: []

  # 🔥 MISSING: Format social posts for display
  defp format_post_for_display(post) do
    %{
      id: post.id,
      content: truncate_content(post.content, 150),
      media_urls: post.media_urls || [],
      post_url: post.post_url,
      posted_at: post.posted_at,
      post_type: post.post_type,
      likes_count: post.likes_count,
      comments_count: post.comments_count,
      shares_count: post.shares_count,
      hashtags: post.hashtags || []
    }
  end

  # 🔥 MISSING: Truncate content helper
  defp truncate_content(content, max_length) when is_binary(content) do
    if String.length(content) > max_length do
      String.slice(content, 0, max_length) <> "..."
    else
      content
    end
  end
  defp truncate_content(content, _), do: content || ""

  # 🔥 MISSING: Check if any Social models are available
  # Add this check at the top of functions that use Social models
  defp social_models_available? do
    Code.ensure_loaded?(Frestyl.Portfolios.SocialIntegration) and
    Code.ensure_loaded?(Frestyl.Portfolios.SocialPost) and
    Code.ensure_loaded?(Frestyl.Portfolios.AccessRequest) and
    Code.ensure_loaded?(Frestyl.Portfolios.SharingAnalytic)
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
