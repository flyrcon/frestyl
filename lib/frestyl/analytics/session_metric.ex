defmodule Frestyl.Analytics.SessionMetric do
  @moduledoc """
  Schema for storing session-specific metrics, including streaming performance metrics.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "session_metrics" do
    field :session_id, :binary_id
    field :channel_id, :binary_id
    field :concurrent_viewers, :integer, default: 0
    field :peak_viewers, :integer, default: 0
    field :average_watch_time, :float, default: 0.0

    # Streaming performance metrics
    field :buffer_count, :integer, default: 0
    field :average_bitrate, :float
    field :dropped_frames, :integer, default: 0
    field :latency, :float
    field :resolution, :string
    field :cdn_provider, :string

    field :recorded_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(session_metric, attrs) do
    session_metric
    |> cast(attrs, [:session_id, :channel_id, :concurrent_viewers, :peak_viewers,
                   :average_watch_time, :buffer_count, :average_bitrate,
                   :dropped_frames, :latency, :resolution, :cdn_provider,
                   :recorded_at])
    |> validate_required([:session_id, :channel_id, :recorded_at])
  end
end
