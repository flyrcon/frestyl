# lib/frestyl_web/live/portfolio_live/analytics.ex
defmodule FrestylWeb.PortfolioLive.AnalyticsLive do
  use FrestylWeb, :live_view

  # Add these imports
  import Ecto.Query, warn: false

  alias Frestyl.Repo
  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioVisit

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    portfolio = Portfolios.get_portfolio!(id)
    limits = Portfolios.get_portfolio_limits(socket.assigns.current_user)

    # Ensure user owns this portfolio
    if portfolio.user_id != socket.assigns.current_user.id do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this portfolio.")
       |> push_navigate(to: "/portfolios")}
    else
      # Get shares
      shares = Portfolios.list_portfolio_shares(portfolio.id)

      # Get visit stats
      visit_stats = get_visit_stats(portfolio.id, limits.advanced_analytics)

      socket =
        socket
        |> assign(:page_title, "Portfolio Analytics")
        |> assign(:portfolio, portfolio)
        |> assign(:shares, shares)
        |> assign(:visit_stats, visit_stats)
        |> assign(:limits, limits)
        |> assign(:advanced_analytics, limits.advanced_analytics)

      {:ok, socket}
    end
  end

  defp get_visit_stats(portfolio_id, advanced_analytics) do
    # For free tier, provide just basic statistics
    if advanced_analytics do
      stats = Portfolios.get_portfolio_visit_stats(portfolio_id)

      # Transform the data for the chart
      chart_data =
        stats
        |> Enum.map(fn {date, count} ->
          %{
            date: Date.to_string(date),
            views: count
          }
        end)

      # Calculate additional metrics
      total_views = Enum.reduce(stats, 0, fn {_, count}, acc -> acc + count end)
      unique_visitors = length(Enum.uniq_by(stats, fn {date, _} -> date end))

      %{
        chart_data: chart_data,
        total_views: total_views,
        unique_visitors: unique_visitors
      }
    else
      # Basic stats for free tier - using a fixed query to avoid complex Ecto syntax
      # Fix: Properly use Ecto query syntax with imported modules
      query = from(v in PortfolioVisit, where: v.portfolio_id == ^portfolio_id)
      total_views = Repo.aggregate(query, :count, :id)

      %{
        chart_data: [],
        total_views: total_views,
        unique_visitors: 0
      }
    end
  end
end
