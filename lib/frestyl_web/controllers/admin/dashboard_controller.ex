# lib/frestyl_web/controllers/admin/dashboard_controller.ex
defmodule FrestylWeb.Admin.DashboardController do
  use FrestylWeb, :controller
  alias Frestyl.Analytics

  def index(conn, _params) do
    # Default to showing last 30 days
    end_date = Date.utc_today()
    start_date = Date.add(end_date, -30)

    # Get summary metrics
    summary = Analytics.get_revenue_summary(start_date, end_date)

    # Get trends
    revenue_trends = Analytics.get_revenue_trends(:month)

    # Get top events
    top_events = Analytics.get_top_events(5)

    # Get user growth
    user_growth = Analytics.get_user_growth_metrics(:month)

    render(conn, :index,
      summary: summary,
      revenue_trends: revenue_trends,
      top_events: top_events,
      user_growth: user_growth,
      start_date: start_date,
      end_date: end_date
    )
  end

  def detailed_report(conn, params) do
    # Parse date range from params or default to last 30 days
    end_date = case params["end_date"] do
      nil -> Date.utc_today()
      date_string -> Date.from_iso8601!(date_string)
    end

    start_date = case params["start_date"] do
      nil -> Date.add(end_date, -30)
      date_string -> Date.from_iso8601!(date_string)
    end

    # Get daily reports
    reports = Analytics.get_revenue_reports(start_date, end_date)

    # Get summary
    summary = Analytics.get_revenue_summary(start_date, end_date)

    render(conn, :detailed_report,
      reports: reports,
      summary: summary,
      start_date: start_date,
      end_date: end_date
    )
  end
end
