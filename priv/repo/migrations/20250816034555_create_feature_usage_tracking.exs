# priv/repo/migrations/20250815000012_create_feature_usage_tracking.exs
defmodule Frestyl.Repo.Migrations.CreateFeatureUsageTracking do
  use Ecto.Migration

  def change do
    # Feature usage tracking for tier management and analytics
    create table(:feature_usage, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :feature_name, :string, null: false
      add :session_id, references(:sessions, on_delete: :nilify_all)
      add :usage_count, :integer, default: 1
      add :usage_data, :map, default: %{}
      add :tier_at_usage, :string
      add :feature_available, :boolean, null: false
      add :blocked_reason, :string # tier_insufficient, limit_exceeded, etc.
      add :timestamp, :utc_datetime, null: false
      add :billing_period, :date # For monthly limits tracking

      timestamps()
    end

    create index(:feature_usage, [:user_id])
    create index(:feature_usage, [:feature_name])
    create index(:feature_usage, [:session_id])
    create index(:feature_usage, [:timestamp])
    create index(:feature_usage, [:billing_period])
    create index(:feature_usage, [:feature_available])
  end
end
