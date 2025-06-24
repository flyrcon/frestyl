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

      _ ->
        false
    end
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

end
