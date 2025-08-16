# priv/repo/migrations/20250815000009_add_session_analytics.exs
defmodule Frestyl.Repo.Migrations.AddSessionAnalytics do
  use Ecto.Migration

  def change do
    # Session analytics for tracking usage and performance
    create table(:session_analytics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :event_type, :string, null: false # session_start, session_end, participant_join, feature_used, etc.
      add :event_data, :map, default: %{}
      add :timestamp, :utc_datetime, null: false
      add :session_duration, :integer # seconds
      add :participant_count, :integer
      add :feature_usage, :map, default: %{}
      add :performance_metrics, :map, default: %{}

      timestamps()
    end

    create index(:session_analytics, [:session_id])
    create index(:session_analytics, [:user_id])
    create index(:session_analytics, [:event_type])
    create index(:session_analytics, [:timestamp])
  end
end
