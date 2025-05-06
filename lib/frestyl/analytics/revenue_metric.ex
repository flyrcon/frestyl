defmodule Frestyl.Analytics.RevenueMetric do
  @moduledoc """
  Schema for storing revenue metrics for channels and events.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "revenue_metrics" do
    field :channel_id, :binary_id
    field :event_id, :binary_id

    # Revenue amounts
    field :total_amount, :decimal
    field :subscription_amount, :decimal, default: 0
    field :donation_amount, :decimal, default: 0
    field :ticket_amount, :decimal, default: 0
    field :merchandise_amount, :decimal, default: 0

    # Transaction counts
    field :subscription_count, :integer, default: 0
    field :donation_count, :integer, default: 0
    field :ticket_count, :integer, default: 0
    field :merchandise_count, :integer, default: 0

    # Currency and date
    field :currency, :string, default: "USD"
    field :date, :date

    timestamps()
  end

  @doc false
  def changeset(revenue_metric, attrs) do
    revenue_metric
    |> cast(attrs, [:channel_id, :event_id, :total_amount, :subscription_amount,
                   :donation_amount, :ticket_amount, :merchandise_amount,
                   :subscription_count, :donation_count, :ticket_count,
                   :merchandise_count, :currency, :date])
    |> validate_required([:channel_id, :total_amount, :date])
  end
end
