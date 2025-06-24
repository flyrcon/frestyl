# priv/repo/migrations/001_create_accounts.exs
defmodule Frestyl.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :name, :string, null: false
      add :type, :string, null: false, default: "personal"
      add :subscription_tier, :string, null: false, default: "personal"
      add :subscription_status, :string, null: false, default: "active"

      # Usage tracking
      add :current_usage, :map, default: %{}
      add :billing_cycle_usage, :map, default: %{}

      # Settings
      add :settings, :map, default: %{}
      add :branding_config, :map, default: %{}
      add :feature_flags, :map, default: %{}

      # Relationships
      add :owner_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:accounts, [:owner_id])

    # Add constraints
    create constraint(:accounts, :valid_type,
      check: "type IN ('personal', 'work', 'team')")
    create constraint(:accounts, :valid_subscription_tier,
      check: "subscription_tier IN ('personal', 'creator', 'professional', 'enterprise')")
    create constraint(:accounts, :valid_subscription_status,
      check: "subscription_status IN ('active', 'past_due', 'canceled', 'paused')")
  end
end
