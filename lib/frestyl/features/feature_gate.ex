defmodule Frestyl.Features.FeatureGate do
  @moduledoc "Dynamic feature access based on account subscription"

  alias Frestyl.Accounts
  alias Frestyl.Billing.UsageTracker
  alias Frestyl.Features.TierManager
  require Logger


  def can_access_feature?(account, feature, context \\ %{}) do
    # Get normalized tier and limits using TierManager
    user_tier = TierManager.get_account_tier(account)
    limits = TierManager.get_tier_limits(user_tier)
    current_usage = get_current_usage(account)

    case feature do
      :create_story ->
        check_story_limit(limits, current_usage)

      :real_time_collaboration ->
        TierManager.feature_available?(user_tier, :real_time_collaboration)

      :advanced_analytics ->
        TierManager.feature_available?(user_tier, :advanced_analytics)

      :custom_branding ->
        TierManager.feature_available?(user_tier, :custom_branding)

      :video_recording ->
        check_video_limit(limits, current_usage, context)

      :live_broadcast ->
        check_live_broadcast_access(user_tier, current_usage)

      :cross_account_sharing ->
        limits.cross_account_sharing != :disabled

      {:story_type, type} ->
        check_story_type_access(limits, type)

      {:storage_upload, size_mb} ->
        check_storage_limit(limits, current_usage, size_mb)

      {:collaborator_invite, count} ->
        check_collaborator_limit(limits, current_usage, count)

      :calendar_view ->
        # Everyone can view calendar - but content is filtered by tier
        true

      :calendar_create_event ->
        check_calendar_create_access(user_tier, current_usage)

      :calendar_edit_event ->
        check_calendar_edit_access(user_tier, context)

      :calendar_delete_event ->
        check_calendar_delete_access(user_tier, context)

      :calendar_external_integration ->
        check_calendar_integration_access(user_tier, current_usage)

      :calendar_sync ->
        TierManager.feature_available?(user_tier, :calendar_sync)

      :calendar_analytics ->
        TierManager.feature_available?(user_tier, :calendar_analytics)

      {:calendar_attendee_limit, count} ->
        check_calendar_attendee_limit(user_tier, count)

      {:calendar_event_visibility, visibility} ->
        check_calendar_visibility_access(user_tier, visibility)

      {:calendar_integration_count, count} ->
        check_calendar_integration_limit(user_tier, count)

      :calendar_recurring_events ->
        check_calendar_recurring_access(user_tier)

      :calendar_booking_payments ->
        check_calendar_payment_access(user_tier)

      :calendar_meeting_links ->
        check_calendar_meeting_access(user_tier)

      :service_booking ->
        TierManager.feature_available?(user_tier, :service_booking)

      :service_creation ->
        check_service_limit(limits, current_usage)

      {:service_booking_payment, amount_cents} ->
        check_service_booking_payment_limit(limits, current_usage, amount_cents)

      :service_calendar_integration ->
        check_service_calendar_access(user_tier)

      :service_analytics ->
        check_service_analytics_access(user_tier)

      :api_access ->
        TierManager.feature_available?(user_tier, :api_access)

      :content_campaigns ->
        TierManager.feature_available?(user_tier, :content_campaigns)

      :advanced_campaign_analytics ->
        TierManager.feature_available?(user_tier, :advanced_campaign_analytics)

      :custom_revenue_splits ->
        TierManager.feature_available?(user_tier, :custom_revenue_splits)

      :white_label ->
        TierManager.feature_available?(user_tier, :white_label)

      :custom_domains ->
        TierManager.feature_available?(user_tier, :custom_domains)

      :priority_support ->
        TierManager.feature_available?(user_tier, :priority_support)

      :story_lab ->
        true  # Available to all tiers

      :story_lab_advanced ->
        TierManager.feature_available?(user_tier, :story_lab_advanced)

      :unlimited_stories ->
        TierManager.feature_available?(user_tier, :unlimited_stories)

      :unlimited_recording ->
        TierManager.feature_available?(user_tier, :unlimited_recording)

      :beat_detection ->
        TierManager.feature_available?(user_tier, :beat_detection)

      :story_collaboration ->
        TierManager.feature_available?(user_tier, :story_collaboration)

      :teleprompter_mode ->
        TierManager.feature_available?(user_tier, :teleprompter_mode)

      :ai_story_suggestions ->
        TierManager.feature_available?(user_tier, :ai_story_suggestions)

      :creator_lab ->
        TierManager.feature_available?(user_tier, :creator_lab)

      _ ->
        false
    end
  end

  defp check_service_calendar_access(user_tier) do
    case TierManager.normalize_tier(user_tier) do
      tier when tier in ["creator", "professional", "enterprise"] -> true
      _ -> false
    end
  end

  defp check_service_analytics_access(user_tier) do
    case TierManager.normalize_tier(user_tier) do
      tier when tier in ["creator", "professional", "enterprise"] -> true
      _ -> false
    end
  end

  defp check_live_broadcast_access(user_tier, _current_usage) do
    case TierManager.normalize_tier(user_tier) do
      tier when tier in ["creator", "professional", "enterprise"] -> true
      _ -> false
    end
  end

  # ============================================================================
  # Template Access Control Functions
  # ============================================================================

  @doc """
  Check if a user can access a specific template based on their subscription tier
  """
  def can_access_template?(user, template_key) do
    template_config = get_template_config_safe(template_key)
    required_tier = Map.get(template_config, :subscription_tier, "personal")
    user_tier = TierManager.get_user_tier(user)

    TierManager.can_access_template?(user_tier, required_tier)
  end

  @doc """
  Get template access summary for a user, grouped by accessible/locked
  """
  def get_template_access_summary(user) do
    all_templates = get_all_templates_safe()
    user_tier = get_user_tier(user)

    Enum.group_by(all_templates, fn {template_key, _config} ->
      if can_access_template?(user, template_key), do: :accessible, else: :locked
    end)
  end

  @doc """
  Get templates by category with access information for a user
  """
  def get_templates_by_category_with_access(user) do
    all_templates = get_all_templates_safe()
    user_tier = get_user_tier(user)

    all_templates
    |> Enum.group_by(fn {_key, config} ->
      Map.get(config, :category, "general")
    end)
    |> Enum.map(fn {category, templates} ->
      accessible_templates = Enum.filter(templates, fn {key, _config} ->
        can_access_template?(user, key)
      end)

      locked_templates = Enum.filter(templates, fn {key, _config} ->
        !can_access_template?(user, key)
      end)

      {category, %{
        accessible: accessible_templates,
        locked: locked_templates,
        total_count: length(templates),
        accessible_count: length(accessible_templates),
        locked_count: length(locked_templates)
      }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Get upgrade suggestion when user tries to access a locked template
  """
  def get_template_upgrade_suggestion(user, template_key) do
    if can_access_template?(user, template_key) do
      nil
    else
      template_config = get_template_config_safe(template_key)
      required_tier = Map.get(template_config, :subscription_tier, "personal")
      user_tier = TierManager.get_user_tier(user)
      template_name = Map.get(template_config, :name, String.capitalize(to_string(template_key)))

      # Use TierManager's upgrade suggestion logic
      base_suggestion = TierManager.get_upgrade_suggestion(user_tier, :template_access)

      if base_suggestion do
        %{base_suggestion |
          reason: "The '#{template_name}' template requires #{TierManager.get_tier_display_name(required_tier)} tier"
        }
      else
        %{
          suggested_tier: required_tier,
          title: "Template Access Restricted",
          reason: "The '#{template_name}' template requires #{TierManager.get_tier_display_name(required_tier)} tier",
          benefits: ["Access to premium templates", "Advanced features", "Priority support"],
          price: "Upgrade required"
        }
      end
    end
  end

  @doc """
  Check if user can access a specific template feature
  """
  def can_access_template_feature?(user, template_key, feature_name) do
    # First check if user can access the template at all
    unless can_access_template?(user, template_key) do
      false
    else
      # Then check feature-specific access using TierManager
      user_tier = TierManager.get_user_tier(user)

      # Check tier-based feature access
      tier_allows_feature = case TierManager.normalize_tier_atom(user_tier) do
        :enterprise ->
          true

        :professional ->
          feature_name in [
            "service_booking", "client_portal", "advanced_analytics",
            "social_metrics", "custom_branding", "api_access"
          ]

        :creator ->
          feature_name in [
            "waveform_player", "lightbox_gallery", "social_integration",
            "track_listing", "masonry_layout", "episode_grid"
          ]

        :personal ->
          feature_name in [
            "basic_gallery", "contact_form", "basic_player", "text_content"
          ]

        _ ->
          false
      end

      # Also check template's feature list
      template_config = get_template_config_safe(template_key)
      template_features = Map.get(template_config, :features, [])

      tier_allows_feature || feature_name in template_features
    end
  end

  # ============================================================================
  # CALENDAR FEATURE CHECKS
  # ============================================================================

  defp check_calendar_create_access(user_tier, current_usage) do
    case user_tier do
      "personal" ->
        # Free tier cannot create events
        false

      "creator" ->
        # Creator can create events with limits
        monthly_events = Map.get(current_usage, :monthly_calendar_events, 0)
        monthly_events < 50 # 50 events per month

      tier when tier in ["professional", "enterprise"] ->
        # Unlimited event creation
        true

      _ ->
        false
    end
  end

  defp check_calendar_edit_access(user_tier, context) do
    event = Map.get(context, :event)
    user_id = Map.get(context, :user_id)

    case user_tier do
      "personal" ->
        # Can only edit channel events they're organizer of
        event && event.creator_id == user_id && event.event_type == "channel_event"

      "creator" ->
        # Can edit own events and events in their account
        event && (event.creator_id == user_id || is_account_member?(event, user_id))

      tier when tier in ["professional", "enterprise"] ->
        # Can edit events in their account or events they organize
        event && (event.creator_id == user_id || is_account_admin?(event, user_id))

      _ ->
        false
    end
  end

  defp check_calendar_delete_access(user_tier, context) do
    event = Map.get(context, :event)
    user_id = Map.get(context, :user_id)

    case user_tier do
      "personal" ->
        # Cannot delete events (read-only for free tier)
        false

      "creator" ->
        # Can only delete own events
        event && event.creator_id == user_id

      tier when tier in ["professional", "enterprise"] ->
        # Can delete own events or account events if admin
        event && (event.creator_id == user_id || is_account_admin?(event, user_id))

      _ ->
        false
    end
  end

  defp check_calendar_integration_access(user_tier, current_usage) do
    case user_tier do
      "personal" ->
        false

      "creator" ->
        # Up to 3 integrations
        integration_count = Map.get(current_usage, :calendar_integrations, 0)
        integration_count < 3

      tier when tier in ["professional", "enterprise"] ->
        # Unlimited integrations
        true

      _ ->
        false
    end
  end

  defp check_calendar_attendee_limit(user_tier, attendee_count) do
    limits = get_calendar_limits(user_tier)
    max_attendees = Map.get(limits, :max_attendees_per_event, 0)

    case max_attendees do
      :unlimited -> true
      0 -> false
      limit -> attendee_count <= limit
    end
  end

  defp check_calendar_visibility_access(user_tier, visibility) do
    allowed_visibilities = get_calendar_visibility_options(user_tier)
    visibility in allowed_visibilities
  end

  defp check_calendar_integration_limit(user_tier, count) do
    limits = get_calendar_limits(user_tier)
    max_integrations = Map.get(limits, :max_integrations, 0)

    case max_integrations do
      :unlimited -> true
      0 -> false
      limit -> count <= limit
    end
  end

  defp check_calendar_recurring_access(user_tier) do
    case user_tier do
      "personal" -> false
      _ -> true
    end
  end

  defp check_calendar_payment_access(user_tier) do
    case user_tier do
      "personal" -> false
      _ -> true
    end
  end

  defp check_calendar_meeting_access(user_tier) do
    case user_tier do
      "personal" -> false
      _ -> true
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  @doc """
  Get user's subscription tier from user struct or account
  """
  defp get_user_tier(user) do
    TierManager.get_user_tier(user)
  end

  @doc """
  Safely get template configuration with fallback
  """
  defp get_template_config_safe(template_key) do
    try do
      case Code.ensure_loaded(Frestyl.Portfolios.PortfolioTemplates) do
        {:module, _} ->
          Frestyl.Portfolios.PortfolioTemplates.get_template_config(template_key)
        _ ->
          get_fallback_template_config(template_key)
      end
    rescue
      _ -> get_fallback_template_config(template_key)
    end
  end

  @doc """
  Safely get all templates with fallback
  """
  defp get_all_templates_safe() do
    try do
      case Code.ensure_loaded(Frestyl.Portfolios.PortfolioTemplates) do
        {:module, _} ->
          Frestyl.Portfolios.PortfolioTemplates.available_templates()
        _ ->
          get_fallback_templates()
      end
    rescue
      _ -> get_fallback_templates()
    end
  end

  @doc """
  Fallback template configuration when PortfolioTemplates module isn't available
  """
  defp get_fallback_template_config(template_key) do
    fallback_templates = get_fallback_templates()
    case Map.get(fallback_templates, template_key) do
      nil -> %{
        name: String.capitalize(to_string(template_key)),
        category: "general",
        subscription_tier: :personal,
        features: []
      }
      config -> config
    end
  end

  @doc """
  Fallback templates when PortfolioTemplates module isn't available
  """
  defp get_fallback_templates() do
    %{
      # Personal tier templates
      "executive" => %{
        name: "Executive",
        category: "professional",
        subscription_tier: :personal,
        features: ["contact_form", "text_content"]
      },
      "minimalist" => %{
        name: "Minimalist",
        category: "minimal",
        subscription_tier: :personal,
        features: ["basic_gallery", "text_content"]
      },

      # Creator tier templates
      "audio_producer" => %{
        name: "Audio Producer",
        category: "audio",
        subscription_tier: :creator,
        features: ["waveform_player", "track_listing", "social_integration"]
      },
      "photographer_portrait" => %{
        name: "Portrait Photographer",
        category: "gallery",
        subscription_tier: :creator,
        features: ["lightbox_gallery", "masonry_layout", "client_gallery"]
      },

      # Professional tier templates
      "life_coach" => %{
        name: "Life Coach",
        category: "service",
        subscription_tier: :professional,
        features: ["service_booking", "testimonial_carousel", "client_portal"]
      },
      "content_creator" => %{
        name: "Content Creator",
        category: "social",
        subscription_tier: :professional,
        features: ["social_metrics", "engagement_tracking", "brand_partnerships"]
      }
    }
  end

  @doc """
  Get readable tier name for display
  """
  def get_tier_display_name(tier) do
    TierManager.get_tier_display_name(tier)
  end

  @doc """
  Get tier hierarchy for upgrade suggestions
  """
  def get_tier_hierarchy() do
    TierManager.tier_hierarchy() |> Enum.map(&String.to_atom/1)
  end

  @doc """
  Check if target tier is an upgrade from current tier
  """
  def is_tier_upgrade?(current_tier, target_tier) do
    TierManager.is_tier_upgrade?(current_tier, target_tier)
  end

  def get_upgrade_suggestion(account, failed_feature, context \\ %{}) do
    current_tier = TierManager.get_account_tier(account)
    TierManager.get_upgrade_suggestion(current_tier, failed_feature)
  end

  defp get_current_usage(account) do
    # Return default usage since User struct doesn't have current_usage field
    %{
      story_count: 0,
      storage_used_gb: 0,
      video_minutes_used: 0,
      collaboration_time: 0,
      active_collaborators: 0,
      monthly_calendar_events: 0,
      calendar_integrations: 0
    }
  end

  def check_feature_availability(tier, feature_name, current_usage) do
    feature_config = get_feature_config(feature_name)
    tier_config = Map.get(feature_config, :tiers, %{})

    case Map.get(tier_config, String.to_atom(tier)) do
      nil -> {:error, :feature_not_available}
      false -> {:error, :feature_not_available}
      true -> {:ok, :available}
      quota when is_map(quota) -> {:ok, :quota_limited}
      _ -> {:error, :feature_not_available}
    end
  end

  def check_feature_quota(account, feature_name) do
    feature_config = get_feature_config(feature_name)
    tier = Map.get(account, :subscription_tier, "free")
    quota_config = get_in(feature_config, [:tiers, String.to_atom(tier)])

    if is_map(quota_config) do
      usage_type = Map.get(quota_config, :usage_type)
      limit = Map.get(quota_config, :limit, 0)
      current_usage = UsageTracker.get_current_usage_for_type(account, usage_type)

      current_usage < limit
    else
      true
    end
  end

  defp count_active_collaborators(_account) do
    0  # Return 0 since User doesn't track this
  end

  defp check_story_limit(limits, usage) do
    case limits.max_stories do
      :unlimited -> true
      max_count -> usage.story_count < max_count
    end
  end

  defp check_video_limit(limits, usage, context) do
    case limits.video_recording_minutes do
      :unlimited -> true
      max_minutes ->
        requested_minutes = Map.get(context, :duration_minutes, 5)
        (usage.video_minutes_used + requested_minutes) <= max_minutes
    end
  end

  defp check_storage_limit(limits, usage, size_mb) do
    case limits.storage_quota_gb do
      :unlimited -> true
      max_gb -> (usage.storage_used_gb + size_mb/1024) <= max_gb
    end
  end

  defp check_story_type_access(limits, story_type) do
    case limits.story_type_access do
      [:all] -> true
      allowed_types -> story_type in allowed_types
    end
  end

  defp check_collaborator_limit(limits, usage, additional_count) do
    case limits.max_collaborators do
      :unlimited -> true
      max_count -> (usage.active_collaborators + additional_count) <= max_count
    end
  end

  def get_account_limits(account) do
    user_tier = TierManager.get_account_tier(account)
    TierManager.get_tier_limits(user_tier)
  end

  # ============================================================================
  # Feature Configuration
  # ============================================================================

  def get_feature_config(feature_name) do
    case feature_name do
      :real_time_collaboration ->
        %{
          name: "Real-time Collaboration",
          description: "Collaborate with others in real-time",
          tiers: %{
            personal: false,
            creator: true,
            professional: true,
            enterprise: true
          }
        }

      :advanced_analytics ->
        %{
          name: "Advanced Analytics",
          description: "Detailed analytics and insights",
          tiers: %{
            personal: false,
            creator: %{usage_type: :analytics_views, limit: 100},
            professional: true,
            enterprise: true
          }
        }

      :premium_export ->
        %{
          name: "Premium Export",
          description: "Export in high-quality formats",
          tiers: %{
            personal: %{usage_type: :exports, limit: 5},
            creator: %{usage_type: :exports, limit: 50},
            professional: true,
            enterprise: true
          }
        }

      :custom_domains ->
        %{
          name: "Custom Domains",
          description: "Use your own domain for portfolios",
          tiers: %{
            personal: false,
            creator: %{usage_type: :custom_domains, limit: 1},
            professional: %{usage_type: :custom_domains, limit: 5},
            enterprise: true
          }
        }

      :live_broadcast ->
        %{
          name: "Live Broadcasting",
          description: "Host live portfolio showcases and presentations",
          tiers: %{
            personal: false,
            creator: %{usage_type: :broadcasts, limit: 1},
            professional: %{usage_type: :broadcasts, limit: 5},
            enterprise: true
          }
        }

      :service_booking ->
        %{
          name: "Service Booking",
          description: "Allow clients to book your services",
          tiers: %{
            personal: false,
            creator: %{usage_type: :services, limit: 10},
            professional: true,
            enterprise: true
          }
        }

      :service_analytics ->
        %{
          name: "Service Analytics",
          description: "Detailed booking and revenue analytics",
          tiers: %{
            personal: false,
            creator: %{usage_type: :analytics_views, limit: 50},
            professional: true,
            enterprise: true
          }
        }

      :api_access ->
        %{
          name: "API Access",
          description: "Programmatic access to your data",
          tiers: %{
            personal: false,
            creator: false,
            professional: true,
            enterprise: true
          }
        }

      :content_campaigns ->
        %{
          name: "Content Campaigns",
          description: "Create and participate in collaborative content campaigns with revenue sharing",
          tiers: %{
            personal: false,
            creator: true,
            professional: true,
            enterprise: true
          }
        }

      :advanced_campaign_analytics ->
        %{
          name: "Advanced Campaign Analytics",
          description: "Advanced analytics and reporting for content campaigns",
          tiers: %{
            personal: false,
            creator: false,
            professional: true,
            enterprise: true
          }
        }

      :custom_revenue_splits ->
        %{
          name: "Custom Revenue Splits",
          description: "Custom revenue split configurations and contracts",
          tiers: %{
            personal: false,
            creator: false,
            professional: true,
            enterprise: true
          }
        }

      :white_label ->
        %{
          name: "White Label",
          description: "Remove Frestyl branding",
          tiers: %{
            personal: false,
            creator: false,
            professional: false,
            enterprise: true
          }
        }

      _ ->
        %{
          name: "Unknown Feature",
          description: "Feature not configured",
          tiers: %{
            personal: false,
            creator: false,
            professional: false,
            enterprise: false
          }
        }
    end
  end

  # ============================================================================
  # Feature Usage Tracking
  # ============================================================================

  def track_feature_usage(account, feature_name, amount \\ 1) do
    feature_config = get_feature_config(feature_name)
    tier = Map.get(account, :subscription_tier, "free")
    tier_config = get_in(feature_config, [:tiers, String.to_atom(tier)])

    if is_map(tier_config) && Map.has_key?(tier_config, :usage_type) do
      usage_type = Map.get(tier_config, :usage_type)
      UsageTracker.track_usage(account, usage_type, amount, %{feature: feature_name})
    else
      # Feature doesn't track usage or is unlimited
      :ok
    end
  end

  def get_feature_usage_status(account, feature_name) do
    if can_access_feature?(account, feature_name) do
      feature_config = get_feature_config(feature_name)
      tier = Map.get(account, :subscription_tier, "free")
      tier_config = get_in(feature_config, [:tiers, String.to_atom(tier)])

      case tier_config do
        true ->
          {:ok, :unlimited}

        false ->
          {:error, :not_available}

        quota when is_map(quota) ->
          usage_type = Map.get(quota, :usage_type)
          limit = Map.get(quota, :limit)
          current = UsageTracker.get_current_usage_for_type(account, usage_type)

          {:ok, %{
            current: current,
            limit: limit,
            remaining: max(0, limit - current),
            percentage: if(limit > 0, do: (current / limit * 100), else: 0)
          }}

        _ ->
          {:error, :unknown_configuration}
      end
    else
      {:error, :access_denied}
    end
  end

  # ============================================================================
  # Feature Lists and Comparisons
  # ============================================================================

  def list_available_features(account) do
    all_features = [
      :real_time_collaboration,
      :advanced_analytics,
      :premium_export,
      :custom_domains,
      :ai_optimization,
      :priority_support,
      :collaboration_history,
      :guest_access_enabled
    ]

    Enum.filter(all_features, fn feature ->
      can_access_feature?(account, feature)
    end)
  end

  def compare_tier_features(tier_from, tier_to) do
    all_features = [
      :real_time_collaboration,
      :advanced_analytics,
      :premium_export,
      :custom_domains,
      :ai_optimization,
      :priority_support,
      :collaboration_history,
      :guest_access_enabled
    ]

    comparison = Enum.map(all_features, fn feature ->
      config = get_feature_config(feature)
      from_access = get_in(config, [:tiers, String.to_atom(tier_from)])
      to_access = get_in(config, [:tiers, String.to_atom(tier_to)])

      {feature, %{
        current: format_feature_access(from_access),
        upgraded: format_feature_access(to_access),
        improved: is_feature_improved?(from_access, to_access)
      }}
    end)

    Enum.into(comparison, %{})
  end

  # ============================================================================
  # CALENDAR LIMITS CONFIGURATION
  # ============================================================================

  defp get_calendar_limits(user_tier) do
    case user_tier do
      "personal" ->
        %{
          max_events_per_month: 0,
          max_attendees_per_event: 0,
          max_integrations: 0,
          can_create_paid_events: false,
          can_set_meeting_links: false,
          can_create_recurring: false,
          allowed_event_types: ["channel_event"],
          allowed_visibilities: ["channel"]
        }

      "creator" ->
        %{
          max_events_per_month: 50,
          max_attendees_per_event: 25,
          max_integrations: 3,
          can_create_paid_events: true,
          can_set_meeting_links: true,
          can_create_recurring: true,
          allowed_event_types: ["personal", "service_booking", "broadcast", "channel_event"],
          allowed_visibilities: ["private", "channel", "account"]
        }

      "professional" ->
        %{
          max_events_per_month: :unlimited,
          max_attendees_per_event: 100,
          max_integrations: :unlimited,
          can_create_paid_events: true,
          can_set_meeting_links: true,
          can_create_recurring: true,
          allowed_event_types: ["personal", "service_booking", "broadcast", "channel_event", "collaboration"],
          allowed_visibilities: ["private", "channel", "account", "public"]
        }

      "enterprise" ->
        %{
          max_events_per_month: :unlimited,
          max_attendees_per_event: :unlimited,
          max_integrations: :unlimited,
          can_create_paid_events: true,
          can_set_meeting_links: true,
          can_create_recurring: true,
          allowed_event_types: ["personal", "service_booking", "broadcast", "channel_event", "collaboration"],
          allowed_visibilities: ["private", "channel", "account", "public"]
        }

      _ ->
        get_calendar_limits("personal")
    end
  end

  defp get_calendar_visibility_options(user_tier) do
    limits = get_calendar_limits(user_tier)
    Map.get(limits, :allowed_visibilities, ["channel"])
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp format_feature_access(access) do
    case access do
      true -> "Unlimited"
      false -> "Not Available"
      %{limit: limit} -> "Up to #{limit}"
      nil -> "Not Available"
      _ -> "Unknown"
    end
  end

  defp is_feature_improved?(from_access, to_access) do
    case {from_access, to_access} do
      {false, true} -> true
      {false, %{}} -> true
      {%{limit: from_limit}, %{limit: to_limit}} when to_limit > from_limit -> true
      {%{}, true} -> true
      _ -> false
    end
  end

  defp check_service_limit(limits, usage) do
    case limits.max_services do
      :unlimited -> true
      max_count -> usage.service_count < max_count
    end
  end

  defp check_service_booking_payment_limit(limits, usage, amount_cents) do
    case limits.max_booking_amount_cents do
      :unlimited -> true
      max_amount -> amount_cents <= max_amount
    end
  end

  defp track_enhancement_start(portfolio_id, enhancement_type) do
    # Get the portfolio to access user account
    case Portfolios.get_portfolio(portfolio_id) do
      nil ->
        # Portfolio not found - log error but don't crash
        IO.puts("Warning: Portfolio #{portfolio_id} not found for enhancement tracking")
        :ok

      portfolio ->
        # Check if portfolio has user and account
        case get_portfolio_account(portfolio) do
          nil ->
            IO.puts("Warning: No account found for portfolio #{portfolio_id}")
            :ok

          account ->
            # Track the usage
            Billing.UsageTracker.track_usage(
              account,
              :enhancement_session_start,
              1,
              %{
                portfolio_id: portfolio_id,
                enhancement_type: enhancement_type,
                started_at: DateTime.utc_now()
              }
            )
        end
    end
  end

  # Helper function to safely get account from portfolio
  defp get_portfolio_account(portfolio) do
    cond do
      portfolio.user && portfolio.user.account ->
        portfolio.user.account

      portfolio.user_id ->
        # If user not preloaded, get it
        case Accounts.get_user(portfolio.user_id) do
          nil -> nil
          user -> user.account
        end

      true ->
        nil
    end
  end


  defp calculate_session_duration(channel) do
    started_at = get_in(channel.metadata, ["started_at"])
    if started_at do
      DateTime.diff(DateTime.utc_now(), started_at, :minute)
    else
      0
    end
  end

  defp is_account_member?(_event, _user_id) do
    # Check if user is a member of the account that owns the event
    # This would integrate with your existing account membership system
    false # Placeholder implementation
  end

  defp is_account_admin?(_event, _user_id) do
    # Check if user is an admin of the account that owns the event
    # This would integrate with your existing account permissions system
    false # Placeholder implementation
  end

    # ============================================================================
  # USAGE TRACKING FOR CALENDAR FEATURES
  # ============================================================================

  def track_calendar_usage(account, usage_type, amount \\ 1, metadata \\ %{}) do
    UsageTracker.track_usage(account, usage_type, amount, metadata)
  end

  def get_calendar_usage_status(account, feature) do
    user_tier = TierManager.get_account_tier(account)
    limits = get_calendar_limits(user_tier)
    current_usage = get_current_usage(account)

    case feature do
      :monthly_events ->
        max_events = Map.get(limits, :max_events_per_month, 0)
        used_events = Map.get(current_usage, :monthly_calendar_events, 0)

        %{
          used: used_events,
          limit: max_events,
          percentage: calculate_usage_percentage(used_events, max_events),
          can_create_more: can_create_more_events?(used_events, max_events)
        }

      :integrations ->
        max_integrations = Map.get(limits, :max_integrations, 0)
        used_integrations = Map.get(current_usage, :calendar_integrations, 0)

        %{
          used: used_integrations,
          limit: max_integrations,
          percentage: calculate_usage_percentage(used_integrations, max_integrations),
          can_add_more: can_add_more_integrations?(used_integrations, max_integrations)
        }

      _ ->
        %{used: 0, limit: 0, percentage: 0, can_use: false}
    end
  end

  defp calculate_usage_percentage(used, :unlimited), do: 0
  defp calculate_usage_percentage(used, limit) when limit > 0 do
    min(round(used / limit * 100), 100)
  end
  defp calculate_usage_percentage(_, _), do: 100

  defp can_create_more_events?(used, :unlimited), do: true
  defp can_create_more_events?(used, limit) when is_integer(limit) do
    used < limit
  end
  defp can_create_more_events?(_, _), do: false

  defp can_add_more_integrations?(used, :unlimited), do: true
  defp can_add_more_integrations?(used, limit) when is_integer(limit) do
    used < limit
  end
  defp can_add_more_integrations?(_, _), do: false

  # ============================================================================
  # CALENDAR FEATURE UPGRADE SUGGESTIONS
  # ============================================================================

  def get_calendar_upgrade_suggestion(current_tier, failed_feature) do
    current_normalized = TierManager.normalize_tier(current_tier)

    case {current_normalized, failed_feature} do
      {"personal", :calendar_create_event} ->
        %{
          suggested_tier: "creator",
          title: "Upgrade to Creator",
          reason: "Create and manage calendar events with Creator tier",
          benefits: [
            "Create up to 50 events per month",
            "Service booking integration",
            "External calendar sync",
            "Meeting link generation"
          ],
          price: "$19/month"
        }

      {"personal", :calendar_external_integration} ->
        %{
          suggested_tier: "creator",
          title: "Unlock Calendar Sync",
          reason: "Connect external calendars with Creator tier",
          benefits: [
            "Google Calendar integration",
            "Outlook Calendar sync",
            "Automatic event sync",
            "Up to 3 calendar connections"
          ],
          price: "$19/month"
        }

      {"creator", :calendar_unlimited_events} ->
        %{
          suggested_tier: "professional",
          title: "Go Unlimited",
          reason: "Professional tier offers unlimited calendar events",
          benefits: [
            "Unlimited calendar events",
            "Up to 100 attendees per event",
            "Advanced calendar analytics",
            "Public event visibility"
          ],
          price: "$49/month"
        }

      {"creator", :calendar_advanced_features} ->
        %{
          suggested_tier: "professional",
          title: "Advanced Calendar Features",
          reason: "Professional tier includes advanced calendar management",
          benefits: [
            "Unlimited external integrations",
            "Advanced attendee management",
            "Calendar analytics dashboard",
            "Custom meeting room booking"
          ],
          price: "$49/month"
        }

      {_, :calendar_white_label} ->
        %{
          suggested_tier: "enterprise",
          title: "Enterprise Calendar",
          reason: "White-label calendar features available with Enterprise",
          benefits: [
            "Branded calendar interface",
            "Unlimited everything",
            "Advanced security controls",
            "Dedicated support"
          ],
          price: "Contact Sales"
        }

      _ ->
        nil
    end
  end
end
