# priv/repo/migrations/create_streaming_configs.exs
defmodule Frestyl.Repo.Migrations.CreateStreamingConfigs do
  use Ecto.Migration

  def change do
    alter table(:streaming_configs) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false

      # Streaming Keys and Configuration
      add_if_not_exists :streaming_key, :string
      add_if_not_exists :rtmp_url, :string
      add_if_not_exists :stream_title, :string
      add_if_not_exists :stream_description, :text

      # Streaming Settings
      add_if_not_exists :max_viewers, :integer, default: 50
      add_if_not_exists :allow_chat, :boolean, default: true
      add_if_not_exists :allow_donations, :boolean, default: false
      add_if_not_exists :allow_subscriber_only, :boolean, default: false
      add_if_not_exists :auto_record, :boolean, default: false
      add_if_not_exists :auto_publish_recording, :boolean, default: false

      # Monetization Settings
      add :donation_enabled, :boolean, default: false
      add :subscription_enabled, :boolean, default: false
      add :min_donation_amount, :integer, default: 100
      add :suggested_donation_amounts, {:array, :integer}, default: fragment("ARRAY[500, 1000, 2500]")

      # Stream Schedule
      add :scheduled_streams, :map, default: "{}"
      add :recurring_schedule, :map, default: "{}"
      add :timezone, :string, default: "UTC"

      # Analytics and Metrics
      add :total_streams, :integer, default: 0
      add :total_stream_hours, :float, default: 0.0
      add :total_viewers, :integer, default: 0
      add :average_concurrent_viewers, :float, default: 0.0
      add :peak_concurrent_viewers, :integer, default: 0
      add :total_donations_cents, :integer, default: 0

      # Stream Quality Settings
      add :max_bitrate, :integer, default: 2500
      add :max_resolution, :string, default: "1080p"
      add :max_fps, :integer, default: 30

      # Status
      add :is_live, :boolean, default: false
      add :current_stream_id, :string
      add :stream_started_at, :utc_datetime
      add :last_stream_ended_at, :utc_datetime

    end

    create index(:streaming_configs, [:account_id])
    create index(:streaming_configs, [:is_live])
  end
end
