# lib/frestyl/stories/collaboration_billing.ex
defmodule Frestyl.Stories.CollaborationBilling do
  @moduledoc """
  Updated collaboration billing using unified tier system
  """

  alias Frestyl.Features.TierManager
  alias Frestyl.Accounts

  @doc """
  Determines available features for collaboration based on host and guest accounts.
  Now uses unified tier system.
  """
  def determine_available_features(host_account, guest_users) do
    # Get all accounts involved
    all_accounts = [host_account | get_guest_accounts(guest_users)]

    # Determine available features based on highest tier
    highest_tier = TierManager.highest_tier(
      Enum.map(all_accounts, &TierManager.get_account_tier/1)
    )

    base_features = [:basic_collaboration]

    additional_features = case highest_tier do
      tier when tier in ["creator", "professional", "enterprise"] ->
        [:real_time_collaboration, :advanced_analytics]
      _ ->
        []
    end

    premium_features = case highest_tier do
      tier when tier in ["professional", "enterprise"] ->
        [:premium_export, :advanced_permissions]
      _ ->
        []
    end

    base_features ++ additional_features ++ premium_features
  end

  @doc """
  Determines billing responsibility using unified tier system
  """
  def determine_billing_responsibility(host_account, guest_account, feature) do
    host_tier = TierManager.get_account_tier(host_account)
    guest_tier = TierManager.get_account_tier(guest_account)

    TierManager.determine_collaboration_billing(host_tier, guest_tier, feature)
  end

  @doc """
  Returns the priority level of a subscription tier using unified system
  """
  def tier_priority(tier) do
    TierManager.tier_priority(tier)
  end

  @doc """
  Calculates session expiry using unified limits
  """
  def calculate_session_expiry(account) do
    tier = TierManager.get_account_tier(account)
    duration_seconds = TierManager.get_collaboration_limits(tier, :max_duration)
    DateTime.add(DateTime.utc_now(), duration_seconds, :second)
  end

  # Private helpers updated to use TierManager
  defp get_guest_accounts(guest_users) do
    Enum.map(guest_users, fn user ->
      get_user_account_for_story(user, nil)
    end)
  end

  defp get_collaboration_limit(account, limit_type) do
    tier = TierManager.get_account_tier(account)
    TierManager.get_collaboration_limits(tier, limit_type)
  end

  defp get_session_rate(account) do
    tier = TierManager.get_account_tier(account)
    TierManager.get_session_rate(tier)
  end

  defp feature_available?(account, feature_name) do
    tier = TierManager.get_account_tier(account)
    TierManager.feature_available?(tier, feature_name)
  end

  def get_user_account_for_story(user, _story_context) do
    cond do
      # If user already has account loaded
      Map.has_key?(user, :account) && user.account ->
        user.account

      # If user has accounts list (get first one)
      Map.has_key?(user, :accounts) && is_list(user.accounts) && length(user.accounts) > 0 ->
        List.first(user.accounts)

      # If user_id is available, fetch the user with account
      Map.has_key?(user, :id) && user.id ->
        case Accounts.get_user_with_account(user.id) do
          %{account: account} when not is_nil(account) -> account
          _ -> create_default_account_for_user(user)
        end

      # Fallback: create a default account structure
      true ->
        create_default_account_for_user(user)
    end
  end

  defp create_default_account_for_user(user) do
    %{
      id: Map.get(user, :id, :system_default),
      user_id: Map.get(user, :id),
      subscription_tier: "personal",  # Default to personal tier
      name: Map.get(user, :email, "Unknown User"),
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end
end
