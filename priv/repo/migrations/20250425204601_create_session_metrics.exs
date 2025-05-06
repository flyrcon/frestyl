defmodule Frestyl.Repo.Migrations.CreateSessionMetrics do
  use Ecto.Migration

  def change do
    create table(:session_metrics) do
      # Use :binary_id type for UUID fields
      add :session_id, :binary_id, null: false
      add :channel_id, :binary_id, null: false
      add :concurrent_viewers, :integer, default: 0
      add :peak_viewers, :integer, default: 0
      add :average_watch_time, :float, default: 0.0

      # Streaming performance metrics
      add :buffer_count, :integer, default: 0
      add :average_bitrate, :float
      add :dropped_frames, :integer, default: 0
      add :latency, :float
      add :resolution, :string
      add :cdn_provider, :string

      add :recorded_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:session_metrics, [:session_id])
    create index(:session_metrics, [:channel_id])
    create index(:session_metrics, [:recorded_at])
    create index(:session_metrics, [:session_id, :recorded_at])
  end
end
