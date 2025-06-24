defmodule Frestyl.Stories.CollaborationBilling do
  @moduledoc """
  Handles billing and feature management for story collaboration sessions.
  """

  # Add these imports/aliases:
  alias Frestyl.Accounts
  alias Frestyl.Stories
  alias Frestyl.Billing
  alias Frestyl.Repo
  import Ecto.Query
  require Logger

  # ============================================================================
  # Account Management
  # ============================================================================

  @doc """
  Gets the account associated with a user for a specific story context.
  """
  def get_user_account_for_story(user, story) do
    # Placeholder implementation - replace with actual logic
    case Accounts.get_user_account(user.id) do
      nil ->
        # Create a default account if none exists
        %{
          id: user.id,
          subscription_tier: "free",
          features: ["basic_collaboration"],
          collaboration_limits: %{max_guests: 2, max_duration: 3600}
        }
      account -> account
    end
  end

  # ============================================================================
  # Validation Functions
  # ============================================================================

  @doc """
  Validates if the account can start a collaboration with the given number of guests.
  """
  def validate_collaboration_limits(account, guest_count) do
    max_guests = get_collaboration_limit(account, :max_guests)

    if guest_count <= max_guests do
      :ok
    else
      {:error, "Collaboration limit exceeded. Maximum #{max_guests} guests allowed."}
    end
  end

  @doc """
  Validates if guest users have proper access permissions.
  """
  def validate_guest_access_permissions(account, guest_users) do
    # Placeholder implementation
    if feature_available?(account, :guest_collaboration) do
      # Check if all guests are valid users
      valid_guests = Enum.all?(guest_users, fn user ->
        user.id && user.email
      end)

      if valid_guests do
        :ok
      else
        {:error, "Invalid guest users"}
      end
    else
      {:error, "Guest collaboration not available on current plan"}
    end
  end

  # ============================================================================
  # Participant Management
  # ============================================================================

  @doc """
  Builds the participant list for a collaboration session.
  """
  def build_participant_list(host_user, guest_users) do
    host_participant = %{
      user_id: host_user.id,
      username: host_user.username || host_user.email,
      role: :host,
      permissions: %{
        can_edit: true,
        can_invite: true,
        can_manage_session: true
      }
    }

    guest_participants = Enum.map(guest_users, fn guest ->
      %{
        user_id: guest.id,
        username: guest.username || guest.email,
        role: :guest,
        permissions: %{
          can_edit: true,
          can_invite: false,
          can_manage_session: false
        }
      }
    end)

    [host_participant | guest_participants]
  end

  # ============================================================================
  # Feature Management
  # ============================================================================

  @doc """
  Checks if a specific feature is available for the account.
  """
  def feature_available?(account, feature_name) do
    tier = Map.get(account, :subscription_tier, "free")

    case {tier, feature_name} do
      # Free tier features
      {"free", :basic_collaboration} -> true
      {"free", :real_time_collaboration} -> false
      {"free", :advanced_analytics} -> false
      {"free", :premium_export} -> false

      # Pro tier features
      {"pro", :basic_collaboration} -> true
      {"pro", :real_time_collaboration} -> true
      {"pro", :advanced_analytics} -> false
      {"pro", :premium_export} -> false

      # Premium tier features
      {"premium", _} -> true

      # Enterprise tier features
      {"enterprise", _} -> true

      # Default case
      {_, _} -> false
    end
  end

  @doc """
  Determines available features for collaboration based on host and guest accounts.
  """
  def determine_available_features(host_account, guest_users) do
    # Get all accounts involved
    all_accounts = [host_account | get_guest_accounts(guest_users)]

    # Determine available features based on highest tier
    highest_tier = determine_highest_tier(all_accounts)

    base_features = [:basic_collaboration]

    additional_features = case highest_tier do
      tier when tier in ["pro", "premium", "enterprise"] ->
        [:real_time_collaboration, :advanced_analytics]
      _ ->
        []
    end

    premium_features = case highest_tier do
      tier when tier in ["premium", "enterprise"] ->
        [:premium_export, :advanced_permissions]
      _ ->
        []
    end

    base_features ++ additional_features ++ premium_features
  end

  # ============================================================================
  # Billing Context
  # ============================================================================

  @doc """
  Determines billing context and responsibility for the collaboration.
  """
  def determine_billing_context(host_account, guest_users) do
    guest_accounts = get_guest_accounts(guest_users)
    all_accounts = [host_account | guest_accounts]

    # Find account with highest tier that will handle billing
    billing_account = Enum.max_by(all_accounts, fn account ->
      tier_priority(Map.get(account, :subscription_tier, "free"))
    end)

    %{
      billing_account_id: billing_account.id,
      session_rate: get_session_rate(billing_account),
      features_included: determine_available_features(host_account, guest_users),
      cost_sharing: determine_cost_sharing(all_accounts)
    }
  end

  @doc """
  Determines billing responsibility between host and guest accounts.
  """
  def determine_billing_responsibility(host_account, guest_account, feature) do
    host_tier = Map.get(host_account, :subscription_tier, "free")
    guest_tier = Map.get(guest_account, :subscription_tier, "free")

    cond do
      # Real-time collaboration feature
      feature == :real_time_collaboration ->
        if feature_available?(host_account, :real_time_collaboration) do
          {:host_pays, host_account}
        else
          {:guest_pays, guest_account}
        end

      # Advanced analytics feature
      feature == :advanced_analytics ->
        if feature_available?(host_account, :advanced_analytics) or
           feature_available?(guest_account, :advanced_analytics) do
          highest_tier_pays = if tier_priority(host_tier) >= tier_priority(guest_tier) do
            {:host_pays, host_account}
          else
            {:guest_pays, guest_account}
          end
          highest_tier_pays
        else
          {:feature_unavailable, nil}
        end

      # Premium export feature
      feature == :premium_export ->
        if feature_available?(host_account, :premium_export) or
           feature_available?(guest_account, :premium_export) do
          highest_tier_pays = if tier_priority(host_tier) >= tier_priority(guest_tier) do
            {:host_pays, host_account}
          else
            {:guest_pays, guest_account}
          end
          highest_tier_pays
        else
          {:feature_unavailable, nil}
        end

      # Default case
      true ->
        {:host_pays, host_account}
    end
  end

  # ============================================================================
  # Session Management
  # ============================================================================

  @doc """
  Calculates when a collaboration session should expire.
  """
  def calculate_session_expiry(account) do
    tier = Map.get(account, :subscription_tier, "free")

    duration_hours = case tier do
      "free" -> 1      # 1 hour
      "pro" -> 4       # 4 hours
      "premium" -> 8   # 8 hours
      "enterprise" -> 24 # 24 hours
      _ -> 1
    end

    DateTime.add(DateTime.utc_now(), duration_hours * 3600, :second)
  end

  @doc """
  Tracks the start of a collaboration session for billing purposes.
  """
  def track_collaboration_start(account, session) do
    # Placeholder implementation - replace with actual tracking logic
    Logger.info("Tracking collaboration start for account #{account.id}, session #{session.id}")

    # Here you would typically:
    # 1. Create a billing record
    # 2. Start usage tracking
    # 3. Update account metrics

    {:ok, %{
      tracking_id: System.unique_integer([:positive]),
      started_at: DateTime.utc_now(),
      account_id: account.id,
      session_id: session.id
    }}
  end

  # ============================================================================
  # Tier Management
  # ============================================================================

  @doc """
  Returns the priority level of a subscription tier.
  Higher numbers indicate higher tiers.
  """
  def tier_priority(tier) do
    case tier do
      "free" -> 0
      "pro" -> 1
      "premium" -> 2
      "enterprise" -> 3
      _ -> 0
    end
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp get_guest_accounts(guest_users) do
    Enum.map(guest_users, fn user ->
      get_user_account_for_story(user, nil)
    end)
  end

  defp determine_highest_tier(accounts) do
    accounts
    |> Enum.map(fn account -> Map.get(account, :subscription_tier, "free") end)
    |> Enum.max_by(&tier_priority/1)
  end

  defp get_collaboration_limit(account, limit_type) do
    tier = Map.get(account, :subscription_tier, "free")

    case {tier, limit_type} do
      {"free", :max_guests} -> 2
      {"pro", :max_guests} -> 10
      {"premium", :max_guests} -> 50
      {"enterprise", :max_guests} -> 200

      {"free", :max_duration} -> 3600      # 1 hour
      {"pro", :max_duration} -> 14400      # 4 hours
      {"premium", :max_duration} -> 28800   # 8 hours
      {"enterprise", :max_duration} -> 86400 # 24 hours

      {_, _} -> 0
    end
  end

  defp get_session_rate(account) do
    tier = Map.get(account, :subscription_tier, "free")

    case tier do
      "free" -> 0.0
      "pro" -> 0.10     # $0.10 per hour
      "premium" -> 0.0  # Included in subscription
      "enterprise" -> 0.0 # Included in subscription
      _ -> 0.0
    end
  end

  defp determine_cost_sharing(accounts) do
    # Simple implementation - highest tier pays
    # In a real implementation, you might have more complex cost sharing rules
    billing_account = Enum.max_by(accounts, fn account ->
      tier_priority(Map.get(account, :subscription_tier, "free"))
    end)

    %{
      strategy: :highest_tier_pays,
      paying_account_id: billing_account.id,
      split_percentage: 100
    }
  end
end
