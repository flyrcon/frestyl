defmodule Frestyl.Analytics.ChannelMetric do
  @moduledoc """
  Schema for storing channel-level metrics like views, engagement, and retention.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "channel_metrics" do
    field :channel_id, :binary_id
    field :views, :integer, default: 0
    field :unique_viewers, :integer, default: 0
    field :average_watch_time, :float, default: 0.0
    field :engagement_rate, :float, default: 0.0
    field :comments_count, :integer, default: 0
    field :shares_count, :integer, default: 0
    field :likes_count, :integer, default: 0
    field :recorded_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(channel_metric, attrs) do
    channel_metric
    |> cast(attrs, [:channel_id, :views, :unique_viewers, :average_watch_time,
                   :engagement_rate, :comments_count, :shares_count,
                   :likes_count, :recorded_at])
    |> validate_required([:channel_id, :recorded_at])
  end
end
