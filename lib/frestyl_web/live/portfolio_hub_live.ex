# lib/frestyl_web/live/portfolio_hub_live.ex
defmodule FrestylWeb.PortfolioHubLive do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    portfolios = Portfolios.list_user_portfolios(user.id)
    limits = Portfolios.get_portfolio_limits(user)

    # Get user overview and activity
    overview = Portfolios.get_user_portfolio_overview(user.id)
    recent_activity = get_recent_activity(user.id)
    collaboration_requests = get_collaboration_requests(user.id)

    # Portfolio stats with collaboration data
    portfolio_stats = Enum.map(portfolios, fn portfolio ->
      stats = Portfolios.get_portfolio_analytics(portfolio.id, user.id)
      collaborations = get_portfolio_collaborations(portfolio.id)
      comments = get_portfolio_comments(portfolio.id)

      {portfolio.id, %{
        stats: stats,
        collaborations: collaborations,
        comments: comments,
        needs_feedback: length(comments) == 0 && created_recently?(portfolio)
      }}
    end) |> Enum.into(%{})

    socket =
      socket
      |> assign(:page_title, "Portfolio Hub")
      |> assign(:portfolios, portfolios)
      |> assign(:limits, limits)
      |> assign(:overview, overview)
      |> assign(:portfolio_stats, portfolio_stats)
      |> assign(:recent_activity, recent_activity)
      |> assign(:collaboration_requests, collaboration_requests)
      |> assign(:view_mode, "grid") # grid, list, featured
      |> assign(:filter_status, "all") # all, published, draft, collaborative
      |> assign(:show_create_modal, false)
      |> assign(:show_collaboration_panel, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  @impl true
  def handle_event("filter_portfolios", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, status)}
  end

  @impl true
  def handle_event("show_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  @impl true
  def handle_event("hide_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  @impl true
  def handle_event("toggle_collaboration_panel", _params, socket) do
    current_state = socket.assigns.show_collaboration_panel
    {:noreply, assign(socket, :show_collaboration_panel, !current_state)}
  end

  @impl true
  def handle_event("request_feedback", %{"portfolio_id" => portfolio_id}, socket) do
    # Logic to request feedback on a portfolio
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    # Send feedback request (implement your feedback request logic)
    # This could create a notification, send emails, etc.

    {:noreply,
     socket
     |> put_flash(:info, "Feedback request sent for '#{portfolio.title}'!")
     |> assign(:show_collaboration_panel, true)}
  end

  @impl true
  def handle_event("start_collaboration", %{"portfolio_id" => portfolio_id}, socket) do
    # Redirect to Studio collaboration for this portfolio
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    {:noreply,
     socket
     |> put_flash(:info, "Starting collaboration session...")
     |> push_navigate(to: "/studio/collaborate/#{portfolio.slug}")}
  end

  # Import helper modules
  import FrestylWeb.PortfolioHubLive.Helpers
  alias FrestylWeb.PortfolioHubLive.Components

  # Helper functions for collaboration features
  defp get_recent_activity(user_id) do
    FrestylWeb.PortfolioHubLive.Helpers.get_recent_activity(user_id, 5)
  end

  defp get_collaboration_requests(user_id) do
    FrestylWeb.PortfolioHubLive.Helpers.get_collaboration_requests(user_id, 10)
  end

  defp get_portfolio_collaborations(portfolio_id) do
    FrestylWeb.PortfolioHubLive.Helpers.get_portfolio_collaborations(portfolio_id)
  end

  defp get_portfolio_comments(portfolio_id) do
    FrestylWeb.PortfolioHubLive.Helpers.get_portfolio_comments(portfolio_id)
  end

  defp created_recently?(portfolio) do
    FrestylWeb.PortfolioHubLive.Helpers.created_recently?(portfolio)
  end

  defp get_filtered_portfolios(portfolios, filter_status) do
    FrestylWeb.PortfolioHubLive.Helpers.get_filtered_portfolios(portfolios, filter_status)
  end

  defp has_collaborations?(portfolio) do
    FrestylWeb.PortfolioHubLive.Helpers.has_collaborations?(portfolio)
  end
end
