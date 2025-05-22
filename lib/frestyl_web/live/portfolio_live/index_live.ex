defmodule FrestylWeb.PortfolioLive.IndexLive do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Accounts
  import FrestylWeb.Navigation, only: [nav: 1]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    portfolios = Portfolios.list_user_portfolios(user.id)
    limits = Portfolios.get_portfolio_limits(user)
    can_create = Portfolios.can_create_portfolio?(user)

    socket =
      socket
      |> assign(:page_title, "My Portfolios")
      |> assign(:portfolios, portfolios)
      |> assign(:limits, limits)
      |> assign(:can_create, can_create)

    {:ok, socket}
  end

  @impl true
  def handle_event("create_portfolio", _params, socket) do
    user = socket.assigns.current_user

    if socket.assigns.can_create do
      case Portfolios.create_default_portfolio(user.id) do
        {:ok, portfolio} ->
          {:noreply,
           socket
           |> put_flash(:info, "Portfolio created successfully.")
           |> push_navigate(to: "/portfolios/#{portfolio.id}/edit")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to create portfolio.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You've reached your portfolio limit. Upgrade to create more portfolios.")
       |> push_navigate(to: "/account/subscription")}
    end
  end

  @impl true
  def handle_event("delete_portfolio", %{"id" => id}, socket) do
    portfolio = Portfolios.get_portfolio!(id)

    if portfolio.user_id == socket.assigns.current_user.id do
      case Portfolios.delete_portfolio(portfolio) do
        {:ok, _} ->
          portfolios = Portfolios.list_user_portfolios(socket.assigns.current_user.id)
          can_create = Portfolios.can_create_portfolio?(socket.assigns.current_user)

          {:noreply,
           socket
           |> assign(:portfolios, portfolios)
           |> assign(:can_create, can_create)
           |> put_flash(:info, "Portfolio deleted successfully.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete portfolio.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end
end
