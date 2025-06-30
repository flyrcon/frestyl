# lib/frestyl/portfolios/streaming_config.ex
defmodule Frestyl.Portfolios.StreamingConfig do
  use Ecto.Schema
  import Ecto.Changeset

  schema "streaming_configs" do
    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :account, Frestyl.Accounts.Account

    # Streaming Keys and Configuration
    field :streaming_key, :string
    field :rtmp_url, :string
    field :stream_title, :string
    field :stream_description, :string

    # Streaming Settings
    field :max_viewers, :integer, default: 50
    field :allow_chat, :boolean, default: true
    field :allow_donations, :boolean, default: false
    field :allow_subscriber_only, :boolean, default: false
    field :auto_record, :boolean, default: false
    field :auto_publish_recording, :boolean, default: false

    # Monetization Settings
    field :donation_enabled, :boolean, default: false
    field :subscription_enabled, :boolean, default: false
    field :min_donation_amount, :integer, default: 100 # cents
    field :suggested_donation_amounts, {:array, :integer}, default: [500, 1000, 2500]

    # Stream Schedule
    field :scheduled_streams, :map, default: %{}
    field :recurring_schedule, :map, default: %{}
    field :timezone, :string, default: "UTC"

    # Analytics and Metrics
    field :total_streams, :integer, default: 0
    field :total_stream_hours, :float, default: 0.0
    field :total_viewers, :integer, default: 0
    field :average_concurrent_viewers, :float, default: 0.0
    field :peak_concurrent_viewers, :integer, default: 0
    field :total_donations_cents, :integer, default: 0

    # Stream Quality Settings
    field :max_bitrate, :integer, default: 2500
    field :max_resolution, :string, default: "1080p"
    field :max_fps, :integer, default: 30

    # Status
    field :is_live, :boolean, default: false
    field :current_stream_id, :string
    field :stream_started_at, :utc_datetime
    field :last_stream_ended_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(streaming_config, attrs) do
    streaming_config
    |> cast(attrs, [
      :portfolio_id, :account_id, :streaming_key, :rtmp_url, :stream_title, :stream_description,
      :max_viewers, :allow_chat, :allow_donations, :allow_subscriber_only, :auto_record, :auto_publish_recording,
      :donation_enabled, :subscription_enabled, :min_donation_amount, :suggested_donation_amounts,
      :scheduled_streams, :recurring_schedule, :timezone,
      :total_streams, :total_stream_hours, :total_viewers, :average_concurrent_viewers, :peak_concurrent_viewers, :total_donations_cents,
      :max_bitrate, :max_resolution, :max_fps,
      :is_live, :current_stream_id, :stream_started_at, :last_stream_ended_at
    ])
    |> validate_required([:portfolio_id, :account_id])
    |> validate_inclusion(:max_resolution, ["720p", "1080p", "1440p", "4K"])
    |> validate_number(:max_bitrate, greater_than: 500, less_than: 10000)
    |> validate_number(:max_fps, greater_than: 15, less_than_or_equal_to: 60)
    |> validate_number(:min_donation_amount, greater_than_or_equal_to: 50)
    |> unique_constraint([:portfolio_id])
    |> foreign_key_constraint(:portfolio_id)
    |> foreign_key_constraint(:account_id)
  end

  def generate_streaming_key do
    "frest_" <> (:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower))
  end

  def get_rtmp_url(streaming_config) do
    base_url = Application.get_env(:frestyl, :streaming)[:rtmp_base_url] || "rtmp://stream.frestyl.com/live"
    "#{base_url}/#{streaming_config.streaming_key}"
  end
end
