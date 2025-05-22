# lib/frestyl_web/live/portfolio_live/view_live.ex
defmodule FrestylWeb.PortfolioLive.ViewLive do
  use FrestylWeb, :live_view
  import Ecto.Query

  alias Frestyl.Portfolios
  alias Frestyl.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    # First try to find it as a share token
    case Portfolios.get_share_by_token(token) do
      %Frestyl.Portfolios.PortfolioShare{} = share ->
        # It's a share token
        handle_shared_portfolio(share, socket)

      nil ->
        # Not a share token, try to find it as a portfolio slug
        # Assume it's in the format "title-slug" and try to find the portfolio
        case find_portfolio_by_slug(token) do
          %Frestyl.Portfolios.Portfolio{} = portfolio ->
            handle_public_portfolio(portfolio, socket)

          nil ->
            # Neither share token nor portfolio slug found
            {:ok,
             socket
             |> put_flash(:error, "Portfolio not found.")
             |> push_navigate(to: "/")}
        end
    end
  end

  # For public portfolios with username/slug format
  def mount(%{"username" => username, "slug" => slug}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      %Frestyl.Accounts.User{} = user ->
        case Portfolios.get_portfolio_by_slug!(user.id, slug) do
          %Frestyl.Portfolios.Portfolio{} = portfolio ->
            handle_public_portfolio(portfolio, socket)

          nil ->
            {:ok,
             socket
             |> put_flash(:error, "Portfolio not found.")
             |> push_navigate(to: "/")}
        end

      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found.")
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    # This handles the new /:slug route for direct portfolio access
    case find_portfolio_by_slug(slug) do
      %Frestyl.Portfolios.Portfolio{} = portfolio ->
        handle_public_portfolio(portfolio, socket)

      nil ->
        {:ok,
        socket
        |> put_flash(:error, "Portfolio not found.")
        |> push_navigate(to: "/")}
    end
  end

  defp handle_shared_portfolio(share, socket) do
    portfolio = Portfolios.get_portfolio!(share.portfolio_id)

    # Check if approval is required and share is not approved
    if portfolio.approval_required && !share.approved do
      {:ok,
       socket
       |> put_flash(:error, "This portfolio requires approval for viewing. Please contact the owner.")
       |> push_navigate(to: "/")}
    else
      # Track share access
      Portfolios.track_share_access(share)

      # Track visit
      create_visit(socket, portfolio.id, share.id)

      # Load sections
      sections = Portfolios.list_portfolio_sections(portfolio.id)

      # Get owner info (but limit personal details)
      owner = Accounts.get_user!(portfolio.user_id)
      safe_owner = %{
        name: owner.name,
        username: owner.username
      }

      socket =
        socket
        |> assign(:page_title, portfolio.title)
        |> assign(:portfolio, portfolio)
        |> assign(:sections, sections)
        |> assign(:owner, safe_owner)
        |> assign(:share, share)
        |> assign(:is_shared_view, true)

      {:ok, socket}
    end
  end

  defp handle_public_portfolio(portfolio, socket) do
    # Only allow access to public portfolios this way
    if portfolio.visibility == :public do
      # Track visit
      create_visit(socket, portfolio.id, nil)

      # Load sections
      sections = Portfolios.list_portfolio_sections(portfolio.id)

      # Get owner info
      owner = Accounts.get_user!(portfolio.user_id)
      safe_owner = %{
        name: owner.name,
        username: owner.username
      }

      socket =
        socket
        |> assign(:page_title, portfolio.title)
        |> assign(:portfolio, portfolio)
        |> assign(:sections, sections)
        |> assign(:owner, safe_owner)
        |> assign(:share, nil)
        |> assign(:is_shared_view, false)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "This portfolio is not publicly available.")
       |> push_navigate(to: "/")}
    end
  end

  defp find_portfolio_by_slug(slug) do
    # Try to find a portfolio with this slug
    # Since we don't have the user_id, we need to search across all portfolios
    # This is a simplified approach - you might want to add user lookup logic
    Frestyl.Repo.one(
      from p in Frestyl.Portfolios.Portfolio,
      where: p.slug == ^slug and p.visibility == :public,
      limit: 1
    )
  end

  defp create_visit(socket, portfolio_id, share_id) do
    # Get client IP and user agent from connection if available
    conn = socket.private[:conn]

    ip_address = if conn do
      conn.remote_ip
      |> Tuple.to_list()
      |> Enum.join(".")
    else
      "0.0.0.0"
    end

    user_agent = if conn do
      case Plug.Conn.get_req_header(conn, "user-agent") do
        [ua | _] -> ua
        [] -> nil
      end
    else
      nil
    end

    referrer = if conn do
      case Plug.Conn.get_req_header(conn, "referer") do
        [ref | _] -> ref
        [] -> nil
      end
    else
      nil
    end

    # Create visit record
    Portfolios.create_visit(%{
      portfolio_id: portfolio_id,
      share_id: share_id,
      ip_address: ip_address,
      user_agent: user_agent,
      referrer: referrer
    })
  end
end
