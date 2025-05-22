# lib/frestyl_web/live/portfolio_live/share_live.ex
defmodule FrestylWeb.PortfolioLive.ShareLive do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioShare
  import Phoenix.Component
  import Phoenix.VerifiedRoutes

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    portfolio = Portfolios.get_portfolio!(id)
    shares = Portfolios.list_portfolio_shares(portfolio.id)

    # Ensure user owns this portfolio
    if portfolio.user_id != socket.assigns.current_user.id do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this portfolio.")
       |> push_navigate(to: "/portfolios")}
    else
      changeset = PortfolioShare.changeset(%PortfolioShare{}, %{})

      socket =
        socket
        |> assign(:page_title, "Share Portfolio")
        |> assign(:portfolio, portfolio)
        |> assign(:shares, shares)
        |> assign(:changeset, changeset)
        |> assign(:share_url, nil)

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"portfolio_share" => share_params}, socket) do
    changeset =
      %PortfolioShare{}
      |> PortfolioShare.changeset(share_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("create_share", %{"portfolio_share" => share_params}, socket) do
    portfolio = socket.assigns.portfolio

    # Add portfolio_id to params
    share_params = Map.put(share_params, "portfolio_id", portfolio.id)

    case Portfolios.create_share(share_params) do
      {:ok, share} ->
        shares = Portfolios.list_portfolio_shares(portfolio.id)
        changeset = PortfolioShare.changeset(%PortfolioShare{}, %{})

        # Generate share URL
        share_url = portfolio_url(share.token)

        {:noreply,
         socket
         |> assign(:shares, shares)
         |> assign(:changeset, changeset)
         |> assign(:share_url, share_url)
         |> put_flash(:info, "Portfolio shared successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("delete_share", %{"id" => id}, socket) do
    share = Portfolios.get_share!(id)

    # Verify share belongs to the current portfolio
    if share.portfolio_id == socket.assigns.portfolio.id do
      case Portfolios.delete_share(share) do
        {:ok, _} ->
          shares = Portfolios.list_portfolio_shares(socket.assigns.portfolio.id)

          {:noreply,
           socket
           |> assign(:shares, shares)
           |> put_flash(:info, "Share deleted successfully.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete share.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

  @impl true
  def handle_event("toggle_approval", %{"id" => id}, socket) do
    share = Portfolios.get_share!(id)

    # Verify share belongs to the current portfolio
    if share.portfolio_id == socket.assigns.portfolio.id do
      case Portfolios.update_share(share, %{approved: !share.approved}) do
        {:ok, _} ->
          shares = Portfolios.list_portfolio_shares(socket.assigns.portfolio.id)

          {:noreply,
           socket
           |> assign(:shares, shares)
           |> put_flash(:info, "Share updated successfully.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update share.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

  @impl true
  def handle_event("copy_share_link", %{"url" => url}, socket) do
    # Just confirm the copy action. The actual copying happens client-side.
    {:noreply, put_flash(socket, :info, "Link copied to clipboard.")}
  end

  # Helper function to generate portfolio URLs
  defp portfolio_url(slug_or_token) do
    unverified_url(FrestylWeb.Endpoint, ~p"/p/#{slug_or_token}")
  end
end
