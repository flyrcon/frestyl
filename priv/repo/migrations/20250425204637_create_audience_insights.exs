defmodule Frestyl.Repo.Migrations.CreateAudienceInsights do
  use Ecto.Migration

  def change do
    create table(:audience_insights) do
      # Use :binary_id type for UUID fields
      add :event_id, :binary_id, null: false
      add :channel_id, :binary_id, null: false
      add :session_id, :binary_id

      # Demographic information
      add :demographic_group, :string
      add :age_range, :string
      add :gender, :string

      # Geographic information
      add :country, :string
      add :region, :string
      add :city, :string

      # Engagement metrics
      add :watch_time, :float, default: 0.0
      add :engagement_rate, :float, default: 0.0
      add :interaction_count, :integer, default: 0

      # Device information
      add :device_type, :string
      add :browser, :string
      add :os, :string

      # Referral information
      add :referral_source, :string

      # Timestamp
      add :recorded_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:audience_insights, [:event_id])
    create index(:audience_insights, [:channel_id])
    create index(:audience_insights, [:session_id])
    create index(:audience_insights, [:country])
    create index(:audience_insights, [:demographic_group])
    create index(:audience_insights, [:recorded_at])
  end
end
