defmodule Frestyl.Analytics.AudienceInsight do
  @moduledoc """
  Schema for storing audience insights, including demographics and geography.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "audience_insights" do
    field :event_id, :binary_id
    field :channel_id, :binary_id
    field :session_id, :binary_id

    # Demographic information
    field :demographic_group, :string
    field :age_range, :string
    field :gender, :string

    # Geographic information
    field :country, :string
    field :region, :string
    field :city, :string

    # Engagement metrics
    field :watch_time, :float, default: 0.0
    field :engagement_rate, :float, default: 0.0
    field :interaction_count, :integer, default: 0

    # Device information
    field :device_type, :string
    field :browser, :string
    field :os, :string

    # Referral information
    field :referral_source, :string

    # Timestamp
    field :recorded_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(audience_insight, attrs) do
    audience_insight
    |> cast(attrs, [:event_id, :channel_id, :session_id, :demographic_group,
                   :age_range, :gender, :country, :region, :city,
                   :watch_time, :engagement_rate, :interaction_count,
                   :device_type, :browser, :os, :referral_source, :recorded_at])
    |> validate_required([:event_id, :channel_id, :recorded_at])
  end
end
