defmodule Frestyl.Repo.Migrations.CreateChannelMetrics do
  use Ecto.Migration

  def change do
    create table(:channel_metrics) do
      # Change the channel_id to match the type of your channels table's primary key
      # If your channels table uses UUID, use :binary_id type without references
      add :channel_id, :binary_id, null: false
      add :views, :integer, default: 0
      add :unique_viewers, :integer, default: 0
      add :average_watch_time, :float, default: 0.0
      add :engagement_rate, :float, default: 0.0
      add :comments_count, :integer, default: 0
      add :shares_count, :integer, default: 0
      add :likes_count, :integer, default: 0
      add :recorded_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:channel_metrics, [:channel_id])
    create index(:channel_metrics, [:recorded_at])
    create index(:channel_metrics, [:channel_id, :recorded_at])
  end
end
