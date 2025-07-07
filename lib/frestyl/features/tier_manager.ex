defmodule Frestyl.Features.TierManager do
  @moduledoc """
  Unified tier management system for Frestyl.

  This module provides a single source of truth for all subscription tier logic,
  replacing the inconsistent tier systems across the application.

  Target Unified System:
  - "personal"     # 2 portfolios, basic features
  - "creator"      # 10 portfolios, monetization features
  - "professional" # unlimited portfolios, advanced analytics
  - "enterprise"   # unlimited, white-label, API access
  """

  # ============================================================================
  # TIER DEFINITIONS
  # ============================================================================

  @valid_tiers ["personal", "creator", "professional", "enterprise"]
  @tier_atoms [:personal, :creator, :professional, :enterprise]

  @doc """
  Get all valid tier names as strings
  """
  def valid_tiers, do: @valid_tiers

  @doc """
  Get all valid tier names as atoms
  """
  def valid_tier_atoms, do: @tier_atoms

  @doc """
  Normalize any tier input to the unified string format
  """
  def normalize_tier(tier) when is_atom(tier) do
    case tier do
      :personal -> "personal"
      :creator -> "creator"
      :professional -> "professional"
      :enterprise -> "enterprise"
      # Legacy atom mappings
      :free -> "personal"
      :basic -> "personal"
      :premium -> "professional"
      :pro -> "creator"
      :storyteller -> "creator"
      :business -> "enterprise"
      _ -> "personal"  # Default fallback
    end
  end

  def normalize_tier(tier) when is_binary(tier) do
    case String.downcase(tier) do
      "personal" -> "personal"
      "creator" -> "creator"
      "professional" -> "professional"
      "enterprise" -> "enterprise"
      # Legacy string mappings
      "free" -> "personal"
      "basic" -> "personal"
      "premium" -> "professional"
      "pro" -> "creator"
      "storyteller" -> "creator"
      "business" -> "enterprise"
      _ -> "personal"  # Default fallback
    end
  end

  def normalize_tier(_), do: "personal"  # Fallback for nil or other types

  @doc """
  Normalize tier to atom format for internal use
  """
  def normalize_tier_atom(tier) do
    tier
    |> normalize_tier()
    |> String.to_atom()
  end

  @doc """
  Get user's normalized tier from user struct or account
  """
  def get_user_tier(user) do
    tier = cond do
      # Check if user has subscription_tier directly
      Map.has_key?(user, :subscription_tier) && user.subscription_tier ->
        user.subscription_tier

      # Check if user has account with subscription_tier
      Map.has_key?(user, :account) && user.account && Map.has_key?(user.account, :subscription_tier) ->
        user.account.subscription_tier

      # Check if user has accounts list (get first account's tier)
      Map.has_key?(user, :accounts) && is_list(user.accounts) && length(user.accounts) > 0 ->
        hd(user.accounts).subscription_tier

      # Default fallback
      true ->
        "personal"
    end

    normalize_tier(tier)
  end

  @doc """
  Get account's normalized tier
  """
  def get_account_tier(account) when is_map(account) do
    tier = Map.get(account, :subscription_tier, "personal")
    normalize_tier(tier)
  end

  def get_account_tier(_), do: "personal"

  # ============================================================================
  # TIER HIERARCHY & COMPARISONS
  # ============================================================================

  @doc """
  Get tier hierarchy for upgrade logic
  """
  def tier_hierarchy, do: ["personal", "creator", "professional", "enterprise"]

  @doc """
  Get tier priority for comparison (higher number = higher tier)
  """
  def tier_priority(tier) do
    normalized = normalize_tier(tier)
    case normalized do
      "personal" -> 0
      "creator" -> 1
      "professional" -> 2
      "enterprise" -> 3
      _ -> 0
    end
  end

  @doc """
  Check if target tier is an upgrade from current tier
  """
  def is_tier_upgrade?(current_tier, target_tier) do
    tier_priority(target_tier) > tier_priority(current_tier)
  end

  @doc """
  Check if user has access to required tier level
  """
  def has_tier_access?(user_tier, required_tier) do
    tier_priority(user_tier) >= tier_priority(required_tier)
  end

  @doc """
  Get the highest tier from a list of tiers
  """
  def highest_tier(tiers) when is_list(tiers) do
    tiers
    |> Enum.map(&normalize_tier/1)
    |> Enum.max_by(&tier_priority/1, fn -> "personal" end)
  end

  # ============================================================================
  # TIER LIMITS & FEATURES
  # ============================================================================

  @doc """
  Get limits for a given tier
  """
  def get_tier_limits(tier) do
    normalized = normalize_tier(tier)

    case normalized do
      "personal" -> personal_limits()
      "creator" -> creator_limits()
      "professional" -> professional_limits()
      "enterprise" -> enterprise_limits()
      _ -> personal_limits()
    end
  end

  defp personal_limits do
    %{
      max_portfolios: 2,
      max_stories: 3,
      storage_quota_gb: 1,
      max_collaborators: 1,
      video_recording_minutes: 30,
      story_type_access: ["personal_narrative"],
      real_time_collaboration: false,
      custom_branding: false,
      analytics_depth: :basic,
      cross_account_sharing: :limited,
      service_booking_enabled: false,
      api_access: false,
      white_label: false,
      custom_domains: false,
      priority_support: false
    }
  end

  defp creator_limits do
    %{
      max_portfolios: 10,
      max_stories: 25,
      storage_quota_gb: 10,
      max_collaborators: 5,
      video_recording_minutes: 120,
      story_type_access: ["personal_narrative", "creative_showcase", "service_provider"],
      real_time_collaboration: true,
      custom_branding: false,
      analytics_depth: :intermediate,
      cross_account_sharing: :enabled,
      service_booking_enabled: true,
      api_access: false,
      white_label: false,
      custom_domains: false,
      priority_support: false
    }
  end

  defp professional_limits do
    %{
      max_portfolios: :unlimited,
      max_stories: :unlimited,
      storage_quota_gb: 100,
      max_collaborators: 25,
      video_recording_minutes: 300,
      story_type_access: :all,
      real_time_collaboration: true,
      custom_branding: true,
      analytics_depth: :advanced,
      cross_account_sharing: :enabled,
      service_booking_enabled: true,
      api_access: true,
      white_label: false,
      custom_domains: true,
      priority_support: true
    }
  end

  defp enterprise_limits do
    %{
      max_portfolios: :unlimited,
      max_stories: :unlimited,
      storage_quota_gb: :unlimited,
      max_collaborators: :unlimited,
      video_recording_minutes: :unlimited,
      story_type_access: :all,
      real_time_collaboration: true,
      custom_branding: true,
      analytics_depth: :enterprise,
      cross_account_sharing: :enabled,
      service_booking_enabled: true,
      api_access: true,
      white_label: true,
      custom_domains: true,
      priority_support: true
    }
  end

  @doc """
  Check if a feature is available for a given tier
  """
  def feature_available?(tier, feature) do
    limits = get_tier_limits(tier)

    case feature do
      :real_time_collaboration -> Map.get(limits, :real_time_collaboration, false)
      :custom_branding -> Map.get(limits, :custom_branding, false)
      :advanced_analytics -> Map.get(limits, :analytics_depth) in [:advanced, :enterprise]
      :service_booking -> Map.get(limits, :service_booking_enabled, false)
      :api_access -> Map.get(limits, :api_access, false)
      :white_label -> Map.get(limits, :white_label, false)
      :custom_domains -> Map.get(limits, :custom_domains, false)
      :priority_support -> Map.get(limits, :priority_support, false)
      _ -> false
    end
  end

  @doc """
  Get all available features for a tier
  """
  def list_tier_features(tier) do
    limits = get_tier_limits(tier)

    [
      {:portfolios, format_limit(limits.max_portfolios)},
      {:stories, format_limit(limits.max_stories)},
      {:storage, "#{format_limit(limits.storage_quota_gb)} GB"},
      {:collaborators, format_limit(limits.max_collaborators)},
      {:video_recording, "#{format_limit(limits.video_recording_minutes)} min"},
      {:real_time_collaboration, limits.real_time_collaboration},
      {:custom_branding, limits.custom_branding},
      {:analytics, limits.analytics_depth},
      {:service_booking, limits.service_booking_enabled},
      {:api_access, limits.api_access},
      {:white_label, limits.white_label},
      {:custom_domains, limits.custom_domains},
      {:priority_support, limits.priority_support}
    ]
  end

  defp format_limit(:unlimited), do: "Unlimited"
  defp format_limit(value) when is_integer(value), do: to_string(value)
  defp format_limit(value), do: to_string(value)

  # ============================================================================
  # TIER DISPLAY & UI HELPERS
  # ============================================================================

  @doc """
  Get display name for tier
  """
  def get_tier_display_name(tier) do
    normalized = normalize_tier(tier)

    case normalized do
      "personal" -> "Personal"
      "creator" -> "Creator"
      "professional" -> "Professional"
      "enterprise" -> "Enterprise"
      _ -> "Personal"
    end
  end

  @doc """
  Get tier color for UI
  """
  def get_tier_color(tier) do
    normalized = normalize_tier(tier)

    case normalized do
      "personal" -> "from-gray-600 to-gray-800"
      "creator" -> "from-purple-500 to-indigo-500"
      "professional" -> "from-blue-500 to-cyan-500"
      "enterprise" -> "from-green-500 to-emerald-500"
      _ -> "from-gray-500 to-gray-700"
    end
  end

  @doc """
  Get tier pricing info
  """
  def get_tier_pricing(tier) do
    normalized = normalize_tier(tier)

    case normalized do
      "personal" -> %{monthly: 0, annual: 0, currency: "USD"}
      "creator" -> %{monthly: 19, annual: 190, currency: "USD"}
      "professional" -> %{monthly: 49, annual: 490, currency: "USD"}
      "enterprise" -> %{monthly: nil, annual: nil, currency: "USD", contact_sales: true}
      _ -> %{monthly: 0, annual: 0, currency: "USD"}
    end
  end

  @doc """
  Get upgrade suggestion for a failed feature access
  """
  def get_upgrade_suggestion(current_tier, failed_feature) do
    current_normalized = normalize_tier(current_tier)

    case {current_normalized, failed_feature} do
      {"personal", :real_time_collaboration} ->
        %{
          suggested_tier: "creator",
          title: "Upgrade to Creator",
          reason: "Real-time collaboration requires Creator tier or higher",
          benefits: ["10 portfolios", "Real-time editing", "Advanced templates", "10GB storage"],
          price: "$19/month"
        }

      {"personal", :service_booking} ->
        %{
          suggested_tier: "creator",
          title: "Unlock Service Booking",
          reason: "Service booking requires Creator tier or higher",
          benefits: ["Client booking system", "Payment processing", "Calendar integration"],
          price: "$19/month"
        }

      {"creator", :unlimited_portfolios} ->
        %{
          suggested_tier: "professional",
          title: "Go Unlimited",
          reason: "Professional tier offers unlimited portfolios and advanced features",
          benefits: ["Unlimited portfolios", "Advanced analytics", "Custom branding", "API access"],
          price: "$49/month"
        }

      {"creator", :advanced_analytics} ->
        %{
          suggested_tier: "professional",
          title: "Advanced Analytics",
          reason: "Detailed analytics require Professional tier",
          benefits: ["Advanced engagement metrics", "Audience insights", "Performance tracking"],
          price: "$49/month"
        }

      {_, :white_label} ->
        %{
          suggested_tier: "enterprise",
          title: "Enterprise Features",
          reason: "White-label options are available with Enterprise",
          benefits: ["White-label branding", "Unlimited everything", "Priority support"],
          price: "Contact Sales"
        }

      _ ->
        nil
    end
  end

  # ============================================================================
  # COLLABORATION BILLING HELPERS
  # ============================================================================

  @doc """
  Determine billing responsibility for collaboration features
  """
  def determine_collaboration_billing(host_tier, guest_tier, feature) do
    host_normalized = normalize_tier(host_tier)
    guest_normalized = normalize_tier(guest_tier)

    cond do
      feature_available?(host_normalized, feature) ->
        {:host_pays, host_normalized}

      feature_available?(guest_normalized, feature) ->
        {:guest_pays, guest_normalized}

      true ->
        {:feature_unavailable, nil}
    end
  end

  @doc """
  Get collaboration limits for a tier
  """
  def get_collaboration_limits(tier, limit_type) do
    normalized = normalize_tier(tier)
    limits = get_tier_limits(normalized)

    case {normalized, limit_type} do
      {_, :max_guests} -> Map.get(limits, :max_collaborators, 0)
      {"personal", :max_duration} -> 3600      # 1 hour
      {"creator", :max_duration} -> 14400      # 4 hours
      {"professional", :max_duration} -> 28800  # 8 hours
      {"enterprise", :max_duration} -> 86400   # 24 hours
      {_, _} -> 0
    end
  end

  @doc """
  Get session rate for billing
  """
  def get_session_rate(tier) do
    normalized = normalize_tier(tier)

    case normalized do
      "personal" -> 0.0
      "creator" -> 0.10     # $0.10 per hour
      "professional" -> 0.0  # Included in subscription
      "enterprise" -> 0.0   # Included in subscription
      _ -> 0.0
    end
  end

  # ============================================================================
  # TEMPLATE ACCESS CONTROL
  # ============================================================================

  @doc """
  Check if tier can access a template
  """
  def can_access_template?(user_tier, required_tier) do
    user_normalized = normalize_tier(user_tier)
    required_normalized = normalize_tier(required_tier)

    has_tier_access?(user_normalized, required_normalized)
  end

  @doc """
  Get template access for UI
  """
  def get_template_access_info(user_tier, required_tier) do
    user_normalized = normalize_tier(user_tier)
    required_normalized = normalize_tier(required_tier)

    if has_tier_access?(user_normalized, required_normalized) do
      %{accessible: true, upgrade_needed: false}
    else
      %{
        accessible: false,
        upgrade_needed: true,
        required_tier: required_normalized,
        upgrade_message: get_upgrade_message(user_normalized, required_normalized)
      }
    end
  end

  defp get_upgrade_message(current_tier, required_tier) do
    case {current_tier, required_tier} do
      {"personal", "creator"} ->
        "Upgrade to Creator to unlock advanced monetization blocks and content metrics."
      {"personal", "professional"} ->
        "Upgrade to Professional to access enterprise features and brand partnerships."
      {"creator", "professional"} ->
        "Upgrade to Professional for advanced analytics and brand control."
      {_, "enterprise"} ->
        "Contact sales for enterprise features and custom brand control."
      _ ->
        "Upgrade your account to access more layout options."
    end
  end
end
