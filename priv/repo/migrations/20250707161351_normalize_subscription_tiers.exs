# priv/repo/migrations/xxxx_normalize_subscription_tiers.exs
defmodule Frestyl.Repo.Migrations.NormalizeSubscriptionTiers do
  use Ecto.Migration

  alias Frestyl.Features.TierManager

  def up do
    # Update accounts table to normalize subscription tiers
    execute """
    UPDATE accounts
    SET subscription_tier = CASE subscription_tier
      WHEN 'free' THEN 'personal'
      WHEN 'basic' THEN 'personal'
      WHEN 'premium' THEN 'professional'
      WHEN 'pro' THEN 'creator'
      WHEN 'storyteller' THEN 'creator'
      WHEN 'business' THEN 'enterprise'
      WHEN 'personal' THEN 'personal'
      WHEN 'creator' THEN 'creator'
      WHEN 'professional' THEN 'professional'
      WHEN 'enterprise' THEN 'enterprise'
      ELSE 'personal'
    END
    WHERE subscription_tier IS NOT NULL;
    """

    # Update any users table if it has subscription_tier
    execute """
    UPDATE users
    SET subscription_tier = CASE subscription_tier
      WHEN 'free' THEN 'personal'
      WHEN 'basic' THEN 'personal'
      WHEN 'premium' THEN 'professional'
      WHEN 'pro' THEN 'creator'
      WHEN 'storyteller' THEN 'creator'
      WHEN 'business' THEN 'enterprise'
      WHEN 'personal' THEN 'personal'
      WHEN 'creator' THEN 'creator'
      WHEN 'professional' THEN 'professional'
      WHEN 'enterprise' THEN 'enterprise'
      ELSE 'personal'
    END
    WHERE subscription_tier IS NOT NULL;
    """

    # Set default tier for any NULL values
    execute "UPDATE accounts SET subscription_tier = 'personal' WHERE subscription_tier IS NULL;"
    execute "UPDATE users SET subscription_tier = 'personal' WHERE subscription_tier IS NULL AND subscription_tier IS NOT NULL;"
  end

  def down do
    # Rollback is not recommended as it would lose information
    # about which legacy tier each account originally had
    raise "Rollback not supported for tier normalization"
  end
end
