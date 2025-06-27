defmodule Frestyl.Features.FeatureGate do
  @moduledoc "Dynamic feature access based on account subscription"

  alias Frestyl.Accounts
  alias Frestyl.Billing.UsageTracker
  require Logger


  def can_access_feature?(account, feature, context \\ %{}) do
    limits = get_account_limits(account)
    current_usage = get_current_usage(account)

    case feature do
      :create_story ->
        check_story_limit(limits, current_usage)

      :real_time_collaboration ->
        limits.real_time_collaboration != false

      :advanced_analytics ->
        limits.analytics_depth in [:advanced, :enterprise]

      :custom_branding ->
        limits.custom_branding != false

      :video_recording ->
        check_video_limit(limits, current_usage, context)

      :cross_account_sharing ->
        limits.cross_account_sharing != :disabled

      {:story_type, type} ->
        check_story_type_access(limits, type)

      {:storage_upload, size_mb} ->
        check_storage_limit(limits, current_usage, size_mb)

      {:collaborator_invite, count} ->
        check_collaborator_limit(limits, current_usage, count)

          :service_booking ->
      limits.service_booking_enabled

      :service_creation ->
        check_service_limit(limits, current_usage)

      {:service_booking_payment, amount_cents} ->
        check_service_booking_payment_limit(limits, current_usage, amount_cents)

      :service_calendar_integration ->
        limits.service_calendar_integration

      :service_analytics ->
        limits.service_analytics_enabled

      _ ->
        false
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
    required_tier = Map.get(template_config, :subscription_tier, :personal)
    user_tier = get_user_tier(user)

    # Check access based on tier hierarchy
    case user_tier do
      :enterprise -> true  # Enterprise can access everything
      :professional -> required_tier in [:professional, :creator, :personal]
      :creator -> required_tier in [:creator, :personal]
      :personal -> required_tier == :personal
      _ -> false
    end
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
      required_tier = Map.get(template_config, :subscription_tier, :personal)
      user_tier = get_user_tier(user)
      template_name = Map.get(template_config, :name, String.capitalize(to_string(template_key)))

      case {user_tier, required_tier} do
        {:personal, :creator} ->
          %{
            suggested_tier: :creator,
            title: "Upgrade to Creator",
            reason: "The '#{template_name}' template requires Creator tier or higher",
            benefits: [
              "Access to all Audio-First templates",
              "Access to all Gallery templates",
              "Advanced customization options",
              "10GB storage"
            ],
            price: "$19/month",
            cta: "Upgrade to Creator"
          }

        {:personal, :professional} ->
          %{
            suggested_tier: :professional,
            title: "Upgrade to Professional",
            reason: "The '#{template_name}' template requires Professional tier",
            benefits: [
              "Access to all template categories",
              "Service booking integration",
              "Advanced analytics",
              "Custom branding options"
            ],
            price: "$49/month",
            cta: "Go Professional"
          }

        {:creator, :professional} ->
          %{
            suggested_tier: :professional,
            title: "Upgrade to Professional",
            reason: "The '#{template_name}' template includes professional features",
            benefits: [
              "Service Provider templates",
              "Social-First templates with metrics",
              "Advanced dashboard templates",
              "Client portal access"
            ],
            price: "$49/month",
            cta: "Unlock Professional Features"
          }

        _ ->
          %{
            suggested_tier: :professional,
            title: "Template Access Restricted",
            reason: "This template requires a higher subscription tier",
            benefits: ["Access to all premium templates", "Advanced features", "Priority support"],
            price: "Starting at $19/month",
            cta: "View Plans"
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
      # Then check feature-specific access
      template_config = get_template_config_safe(template_key)
      template_features = Map.get(template_config, :features, [])
      user_tier = get_user_tier(user)

      # Check tier-based feature access
      tier_allows_feature = case user_tier do
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

      # Check if feature is in template's feature list or tier allows it
      tier_allows_feature || feature_name in template_features
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  @doc """
  Get user's subscription tier from user struct or account
  """
  defp get_user_tier(user) do
    cond do
      # Check if user has subscription_tier directly
      Map.has_key?(user, :subscription_tier) && user.subscription_tier ->
        user.subscription_tier

      # Check if user has account with subscription_tier
      Map.has_key?(user, :account) && user.account && Map.has_key?(user.account, :subscription_tier) ->
        user.account.subscription_tier

      # Check if user has accounts list (get first account's tier)
      Map.has_key?(user, :accounts) && is_list(user.accounts) && length(user.accounts) > 0 ->
        user.accounts |> List.first() |> Map.get(:subscription_tier, :personal)

      # Default to personal tier
      true ->
        :personal
    end
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
    case tier do
      :personal -> "Personal"
      :creator -> "Creator"
      :professional -> "Professional"
      :enterprise -> "Enterprise"
      _ -> "Unknown"
    end
  end

  @doc """
  Get tier hierarchy for upgrade suggestions
  """
  def get_tier_hierarchy() do
    [:personal, :creator, :professional, :enterprise]
  end

  @doc """
  Check if target tier is an upgrade from current tier
  """
  def is_tier_upgrade?(current_tier, target_tier) do
    hierarchy = get_tier_hierarchy()
    current_index = Enum.find_index(hierarchy, &(&1 == current_tier)) || 0
    target_index = Enum.find_index(hierarchy, &(&1 == target_tier)) || 0
    target_index > current_index
  end

  def get_upgrade_suggestion(account, failed_feature, context \\ %{}) do
    current_tier = account.subscription_tier

    case {current_tier, failed_feature} do
      {:personal, :real_time_collaboration} ->
        %{
          suggested_tier: :creator,
          title: "Upgrade to Creator",
          reason: "Real-time collaboration requires Creator tier or higher",
          benefits: ["10 collaborators", "Real-time editing", "Advanced templates", "10GB storage"],
          price: "$19/month",
          cta: "Upgrade to Creator"
        }

      {:personal, :create_story} ->
        %{
          suggested_tier: :creator,
          title: "Story Limit Reached",
          reason: "Personal accounts are limited to 3 stories",
          benefits: ["25 stories", "All story types", "Advanced sharing", "Priority support"],
          price: "$19/month",
          cta: "Upgrade for More Stories"
        }

      {:creator, :unlimited_stories} ->
        %{
          suggested_tier: :professional,
          title: "Upgrade to Professional",
          reason: "Professional tier offers unlimited stories and team features",
          benefits: ["Unlimited stories", "Team accounts", "Advanced analytics", "Custom branding"],
          price: "$49/month",
          cta: "Go Professional"
        }

      {:creator, :advanced_analytics} ->
        %{
          suggested_tier: :professional,
          title: "Analytics Upgrade",
          reason: "Advanced analytics require Professional tier",
          benefits: ["Detailed engagement metrics", "Audience insights", "Performance tracking"],
          price: "$49/month",
          cta: "Unlock Analytics"
        }

      _ ->
        nil
    end
  end

  defp get_current_usage(account) do
    usage = account.current_usage || %{}

    %{
      story_count: Map.get(usage, "story_count", 0),
      storage_used_gb: Map.get(usage, "storage_used_gb", 0),
      video_minutes_used: Map.get(usage, "video_minutes_used", 0),
      collaboration_time: Map.get(usage, "collaboration_time", 0),
      active_collaborators: count_active_collaborators(account)
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

    defp count_active_collaborators(account) do
    # Simple implementation - replace with actual query
    Map.get(account.current_usage || %{}, "active_collaborators", 0)
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

  defp get_account_limits(account) do
    case account.subscription_tier do
      :personal -> personal_limits()
      :creator -> creator_limits()
      :professional -> professional_limits()
      :enterprise -> enterprise_limits()
    end
  end

  defp personal_limits do
    %{
      max_stories: 3,
      storage_quota_gb: 1,
      max_collaborators: 2,
      video_recording_minutes: 30,
      story_type_access: [:personal_narrative, :professional_showcase],
      real_time_collaboration: false,
      custom_branding: false,
      analytics_depth: :basic,
      cross_account_sharing: :view_only
    }
  end

  defp creator_limits do
    %{
      max_stories: 25,
      storage_quota_gb: 10,
      max_collaborators: 10,
      video_recording_minutes: 300,
      story_type_access: [:all],
      real_time_collaboration: :limited,
      custom_branding: :basic,
      analytics_depth: :standard,
      cross_account_sharing: :comment_and_suggest
    }
  end

  defp professional_limits do
    %{
      max_stories: :unlimited,
      storage_quota_gb: 100,
      max_collaborators: :unlimited,
      video_recording_minutes: :unlimited,
      story_type_access: [:all],
      real_time_collaboration: :full,
      custom_branding: :full,
      analytics_depth: :advanced,
      cross_account_sharing: :full_edit
    }
  end

  defp enterprise_limits do
    professional_limits()
    |> Map.merge(%{
      storage_quota_gb: :unlimited,
      custom_branding: :white_label,
      analytics_depth: :enterprise,
      sso_enabled: true,
      api_access: true
    })
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
            free: false,
            pro: true,
            premium: true,
            enterprise: true
          }
        }

      :advanced_analytics ->
        %{
          name: "Advanced Analytics",
          description: "Detailed analytics and insights",
          tiers: %{
            free: false,
            pro: %{usage_type: :analytics_views, limit: 100},
            premium: true,
            enterprise: true
          }
        }

      :premium_export ->
        %{
          name: "Premium Export",
          description: "Export in high-quality formats",
          tiers: %{
            free: %{usage_type: :exports, limit: 5},
            pro: %{usage_type: :exports, limit: 50},
            premium: true,
            enterprise: true
          }
        }

      :custom_domains ->
        %{
          name: "Custom Domains",
          description: "Use your own domain for portfolios",
          tiers: %{
            free: false,
            pro: %{usage_type: :custom_domains, limit: 1},
            premium: %{usage_type: :custom_domains, limit: 5},
            enterprise: true
          }
        }

      :ai_optimization ->
        %{
          name: "AI Optimization",
          description: "AI-powered content optimization",
          tiers: %{
            free: false,
            pro: %{usage_type: :ai_operations, limit: 20},
            premium: %{usage_type: :ai_operations, limit: 200},
            enterprise: true
          }
        }

      :priority_support ->
        %{
          name: "Priority Support",
          description: "Priority customer support",
          tiers: %{
            free: false,
            pro: true,
            premium: true,
            enterprise: true
          }
        }

      :collaboration_history ->
        %{
          name: "Collaboration History",
          description: "Extended collaboration history",
          tiers: %{
            free: %{usage_type: :history_days, limit: 7},
            pro: %{usage_type: :history_days, limit: 30},
            premium: %{usage_type: :history_days, limit: 365},
            enterprise: true
          }
        }

      :guest_access_enabled ->
        %{
          name: "Guest Access",
          description: "Allow guest collaborators",
          tiers: %{
            free: %{usage_type: :guest_sessions, limit: 5},
            pro: %{usage_type: :guest_sessions, limit: 25},
            premium: %{usage_type: :guest_sessions, limit: 100},
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

      :service_calendar_integration ->
        %{
          name: "Calendar Integration",
          description: "Sync bookings with external calendars",
          tiers: %{
            personal: false,
            creator: true,
            professional: true,
            enterprise: true
          }
        }

      _ ->
        %{
          name: "Unknown Feature",
          description: "Feature not configured",
          tiers: %{
            free: false,
            pro: false,
            premium: false,
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

end
