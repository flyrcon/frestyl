# lib/frestyl/payments/revenue_report.ex
defmodule Frestyl.Payments.RevenueReport do
  use Ecto.Schema
  import Ecto.Changeset

  schema "revenue_reports" do
    field :report_date, :date
    field :total_ticket_sales_cents, :integer, default: 0
    field :total_subscription_revenue_cents, :integer, default: 0
    field :total_platform_fees_cents, :integer, default: 0
    field :total_payouts_cents, :integer, default: 0
    field :new_subscribers_count, :integer, default: 0
    field :canceled_subscribers_count, :integer, default: 0
    field :daily_active_users, :integer, default: 0
    field :total_events_created, :integer, default: 0
    field :total_tickets_sold, :integer, default: 0

    timestamps()
  end

  def changeset(revenue_report, attrs) do
    revenue_report
    |> cast(attrs, [
      :report_date, :total_ticket_sales_cents, :total_subscription_revenue_cents,
      :total_platform_fees_cents, :total_payouts_cents, :new_subscribers_count,
      :canceled_subscribers_count, :daily_active_users, :total_events_created,
      :total_tickets_sold
    ])
    |> validate_required([:report_date])
    |> unique_constraint(:report_date)
  end
end
