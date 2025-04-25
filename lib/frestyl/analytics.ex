# lib/frestyl/analytics.ex
defmodule Frestyl.Analytics do
  @moduledoc """
  The Analytics context: provides functions for generating and retrieving revenue reports.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Payments.{RevenueReport, TicketPurchase, UserSubscription}
  alias Frestyl.Events.Event
  alias Frestyl.Accounts.User

  @doc """
  Generates revenue report for a specific date.
  Usually called by a scheduled job each day.
  """
  def generate_daily_report(date \\ Date.utc_today()) do
    # Get previous day if not provided
    date = date || Date.add(Date.utc_today(), -1)
    start_datetime = DateTime.new!(date, ~T[00:00:00.000], "Etc/UTC")
    end_datetime = DateTime.new!(date, ~T[23:59:59.999], "Etc/UTC")

    # Calculate ticket sales metrics
    ticket_sales_query = from p in TicketPurchase,
                          where: p.payment_status == "completed" and
                                 p.purchase_date >= ^start_datetime and
                                 p.purchase_date <= ^end_datetime,
                          select: %{
                            total_amount: sum(p.total_amount_cents),
                            total_fees: sum(p.platform_fee_cents),
                            count: count(p.id)
                          }
    ticket_metrics = Repo.one(ticket_sales_query) || %{total_amount: 0, total_fees: 0, count: 0}

    # Calculate subscription metrics
    subscription_query = from s in UserSubscription,
                          where: s.inserted_at >= ^start_datetime and
                                 s.inserted_at <= ^end_datetime and
                                 s.status == "active",
                          join: p in assoc(s, :subscription_plan),
                          select: %{
                            total_amount: sum(
                              fragment("CASE WHEN ? THEN ? ELSE ? END",
                                      s.is_yearly,
                                      p.price_yearly_cents,
                                      p.price_monthly_cents)
                            ),
                            count: count(s.id)
                          }
    subscription_metrics = Repo.one(subscription_query) || %{total_amount: 0, count: 0}

    # Calculate cancellations
    cancellations_query = from s in UserSubscription,
                           where: s.canceled_at >= ^start_datetime and
                                  s.canceled_at <= ^end_datetime,
                           select: count(s.id)
    cancellations = Repo.one(cancellations_query) || 0

    # Get daily active users (unique users who performed any action)
    # This query would depend on your activity tracking implementation
    active_users_count = 0  # Placeholder - implement based on your app's activity tracking

    # Get events created
    events_created_query = from e in Event,
                            where: e.inserted_at >= ^start_datetime and
                                   e.inserted_at <= ^end_datetime,
                            select: count(e.id)
    events_created = Repo.one(events_created_query) || 0

    # Create or update the revenue report
    attrs = %{
      report_date: date,
      total_ticket_sales_cents: ticket_metrics.total_amount,
      total_subscription_revenue_cents: subscription_metrics.total_amount,
      total_platform_fees_cents: ticket_metrics.total_fees,
      total_payouts_cents: ticket_metrics.total_amount - ticket_metrics.total_fees,
      new_subscribers_count: subscription_metrics.count,
      canceled_subscribers_count: cancellations,
      daily_active_users: active_users_count,
      total_events_created: events_created,
      total_tickets_sold: ticket_metrics.count
    }

    # Create or update the report
    case Repo.get_by(RevenueReport, report_date: date) do
      nil -> %RevenueReport{} |> RevenueReport.changeset(attrs) |> Repo.insert()
      report -> report |> RevenueReport.changeset(attrs) |> Repo.update()
    end
  end

  @doc """
  Retrieves revenue reports for a date range.
  """
  def get_revenue_reports(start_date, end_date) do
    Repo.all(
      from r in RevenueReport,
      where: r.report_date >= ^start_date and r.report_date <= ^end_date,
      order_by: [desc: r.report_date]
    )
  end

  @doc """
  Generates a summary report for a date range.
  """
  def get_revenue_summary(start_date, end_date) do
    query = from r in RevenueReport,
            where: r.report_date >= ^start_date and r.report_date <= ^end_date,
            select: %{
              total_ticket_sales: sum(r.total_ticket_sales_cents),
              total_subscription_revenue: sum(r.total_subscription_revenue_cents),
              total_platform_fees: sum(r.total_platform_fees_cents),
              total_payouts: sum(r.total_payouts_cents),
              new_subscribers: sum(r.new_subscribers_count),
              canceled_subscribers: sum(r.canceled_subscribers_count),
              total_events_created: sum(r.total_events_created),
              total_tickets_sold: sum(r.total_tickets_sold)
            }

    Repo.one(query) || %{
      total_ticket_sales: 0,
      total_subscription_revenue: 0,
      total_platform_fees: 0,
      total_payouts: 0,
      new_subscribers: 0,
      canceled_subscribers: 0,
      total_events_created: 0,
      total_tickets_sold: 0
    }
  end

  @doc """
  Gets user growth metrics.
  """
  def get_user_growth_metrics(period \\ :month) do
    current_date = Date.utc_today()

    {start_date, interval} = case period do
      :week -> {Date.add(current_date, -7), "day"}
      :month -> {Date.add(current_date, -30), "day"}
      :quarter -> {Date.add(current_date, -90), "week"}
      :year -> {Date.add(current_date, -365), "month"}
    end

    query = from u in User,
            where: u.inserted_at >= ^DateTime.new!(start_date, ~T[00:00:00.000], "Etc/UTC"),
            group_by: fragment("date_trunc(?, ?)", ^interval, u.inserted_at),
            order_by: fragment("date_trunc(?, ?)", ^interval, u.inserted_at),
            select: %{
              period: fragment("date_trunc(?, ?)", ^interval, u.inserted_at),
              count: count(u.id)
            }

    Repo.all(query)
  end

  @doc """
  Gets revenue trends over time.
  """
  def get_revenue_trends(period \\ :month) do
    current_date = Date.utc_today()

    {start_date, group_by} = case period do
      :week -> {Date.add(current_date, -7), "day"}
      :month -> {Date.add(current_date, -30), "day"}
      :quarter -> {Date.add(current_date, -90), "week"}
      :year -> {Date.add(current_date, -365), "month"}
    end

    query = from r in RevenueReport,
            where: r.report_date >= ^start_date,
            group_by: fragment("date_trunc(?, ?::timestamp)", ^group_by, r.report_date),
            order_by: fragment("date_trunc(?, ?::timestamp)", ^group_by, r.report_date),
            select: %{
              period: fragment("date_trunc(?, ?::timestamp)", ^group_by, r.report_date),
              ticket_sales: sum(r.total_ticket_sales_cents),
              subscription_revenue: sum(r.total_subscription_revenue_cents),
              platform_fees: sum(r.total_platform_fees_cents)
            }

    Repo.all(query)
  end

  @doc """
  Gets most popular events by ticket sales.
  """
  def get_top_events(limit \\ 10) do
    query = from p in TicketPurchase,
            where: p.payment_status == "completed",
            join: e in Event, on: p.event_id == e.id,
            group_by: [e.id, e.title],
            order_by: [desc: sum(p.total_amount_cents)],
            limit: ^limit,
            select: %{
              event_id: e.id,
              title: e.title,
              total_sales: sum(p.total_amount_cents),
              tickets_sold: sum(p.quantity)
            }

    Repo.all(query)
  end

  @doc """
  Gets conversion rate data for events.
  """
  def get_event_conversion_rates do
    # This would normally query your views/pageviews tracking
    # For now, we'll return a placeholder implementation
    []
  end
end
