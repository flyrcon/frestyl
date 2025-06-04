# priv/repo/migrations/002_add_user_subscription_fields.exs
defmodule Frestyl.Repo.Migrations.AddUserSubscriptionFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists :subscription_tier, :string, default: "free"
      add_if_not_exists :subscription_expires_at, :utc_datetime
      add_if_not_exists :subscription_features, :map, default: %{}
      add_if_not_exists :export_credits_used_this_month, :integer, default: 0
      add_if_not_exists :last_credit_reset, :utc_datetime
    end

    create_if_not_exists index(:users, [:subscription_tier])
    create index(:users, [:subscription_expires_at])
    create index(:users, [:last_credit_reset])
  end

  def down do
    alter table(:users) do
      remove :subscription_tier
      remove :subscription_expires_at
      remove :subscription_features
      remove :export_credits_used_this_month
      remove :last_credit_reset
    end
  end
end
