# Migration 5: Subscription Tier Template Access Control
# priv/repo/migrations/20250627_005_template_access_control.exs

defmodule Frestyl.Repo.Migrations.TemplateAccessControl do
  use Ecto.Migration

  def change do
    # Template subscription requirements
    create table(:template_subscription_requirements) do
      add :template_theme, :string, null: false
      add :template_category, :string, null: false
      add :minimum_tier, :string, null: false, comment: "personal, creator, professional, enterprise"
      add :premium_features, {:array, :string}, default: [], comment: "Features locked behind higher tiers"
      add :feature_limits, :map, default: %{}, comment: "Tier-specific feature limitations"
      add :is_active, :boolean, default: true

      timestamps()
    end

    # User template access tracking
    create table(:user_template_access) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :template_theme, :string, null: false
      add :access_granted_at, :utc_datetime, null: false
      add :access_tier, :string, null: false
      add :usage_count, :integer, default: 0
      add :last_used_at, :utc_datetime

      timestamps()
    end

    # Template usage analytics for business insights
    create table(:template_usage_stats) do
      add :template_theme, :string, null: false
      add :template_category, :string, null: false
      add :subscription_tier, :string, null: false
      add :usage_count, :integer, default: 0
      add :unique_users, :integer, default: 0
      add :conversion_rate, :decimal, precision: 5, scale: 2, default: 0.0
      add :tracked_month, :date, null: false

      timestamps()
    end

    # Indexes
    create unique_index(:template_subscription_requirements, [:template_theme])
    create unique_index(:user_template_access, [:user_id, :template_theme])
    create index(:user_template_access, [:template_theme])
    create index(:user_template_access, [:access_tier])
    create unique_index(:template_usage_stats, [:template_theme, :subscription_tier, :tracked_month])
  end
end
