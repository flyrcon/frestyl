defmodule FrestylWeb.UserAuth do

  import Plug.Conn
  import Phoenix.Controller
  require Phoenix.LiveView
  require Logger

  alias Frestyl.Accounts

  @session_key :user_token
  @remember_me_cookie "_frestyl_web_user_remember_me"
  @remember_me_options [sign: true, max_age: 60 * 60 * 24 * 60, same_site: "Lax"]

  # Plug protocol implementation
  def init(opts), do: opts

  def call(conn, :ensure_authenticated) do
    Logger.info("UserAuth.call: Using :ensure_authenticated plug")
    require_authenticated_user(conn, [])
  end

  def call(conn, _) do
    conn
  end

  # User session management
  def fetch_current_user(conn, _opts) do
    Logger.info("FETCH_CURRENT_USER Plug: Starting for path: #{conn.request_path}")
    {user_token, conn} = ensure_user_token(conn)
    Logger.info("FETCH_CURRENT_USER Plug: Session token obtained: #{inspect user_token}")

    # Add logging before calling Accounts function
    Logger.info("FETCH_CURRENT_USER Plug: Calling Accounts.get_user_by_session_token with token: #{inspect user_token}")
    user = user_token && Accounts.get_user_by_session_token(user_token)
    # Add logging after calling Accounts function
    Logger.info("FETCH_CURRENT_USER Plug: Result from Accounts.get_user_by_session_token: #{inspect user && user.email}")


    if user do
      Logger.info("FETCH_CURRENT_USER Plug: Found user #{user.email} from token")
    else
      Logger.info("FETCH_CURRENT_USER Plug: No user found for token or no token present")
    end

    assigned_conn = assign(conn, :current_user, user)
    Logger.info("FETCH_CURRENT_USER Plug: User assigned to conn: #{inspect assigned_conn.assigns[:current_user] && assigned_conn.assigns[:current_user].email}")
    assigned_conn
  end

  defp ensure_user_token(conn) do
    Logger.info("ensure_user_token: Checking session for token")
    if user_token = get_session(conn, @session_key) do
      Logger.info("ensure_user_token: Token found in session")
      {user_token, conn}
    else
      Logger.info("ensure_user_token: Token not in session, checking cookies")
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if user_token = conn.cookies[@remember_me_cookie] do
        Logger.info("ensure_user_token: Token found in remember_me cookie, putting in session")
        {user_token, put_session(conn, @session_key, user_token)}
      else
        Logger.info("ensure_user_token: Token not found in session or cookies")
        {nil, conn}
      end
    end
  end

  # LiveView auth hooks
  # lib/frestyl_web/user_auth.ex

  # Replace your on_mount(:ensure_authenticated) function with this fixed version:

  def on_mount(:ensure_authenticated, _params, session, socket) do
    Logger.info("DashboardLive on_mount(:ensure_authenticated): Hook started")
    # Check assigns first
    user = socket.assigns[:current_user]
    Logger.info("DashboardLive on_mount(:ensure_authenticated): User from socket assigns: #{inspect user && user.email}")

    if user do
      Logger.info("DashboardLive on_mount(:ensure_authenticated): User authenticated via assigns, continuing mount")
      # User is already assigned by the plug, no need to re-assign unless you want to refresh it
      {:cont, socket}
    else
      # Fallback: If user not in assigns, fetch from session
      Logger.info("DashboardLive on_mount(:ensure_authenticated): User not in assigns, checking session...")

      # Get user token from session
      user_token = session["user_token"]

      # Fetch user if token exists
      user = user_token && Accounts.get_user_by_session_token(user_token)
      Logger.info("DashboardLive on_mount(:ensure_authenticated): User fetched from session: #{inspect user && user.email}")

      if user do
        Logger.info("DashboardLive on_mount(:ensure_authenticated): User authenticated via session, assigning and continuing mount")
        socket = Phoenix.Component.assign(socket, current_user: user)
        {:cont, socket}
      else
        Logger.info("DashboardLive on_mount(:ensure_authenticated): Auth failed. Redirecting to login.")
        {:halt, Phoenix.LiveView.redirect(socket, to: "/users/log_in")}
      end
    end
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    Logger.info("LiveView on_mount(:mount_current_user): Hook started")
    # Check assigns first
    user = socket.assigns[:current_user]
    Logger.info("LiveView on_mount(:mount_current_user): User from socket assigns: #{inspect user && user.email}")

    if user do
       Logger.info("LiveView on_mount(:mount_current_user): User found in assigns.")
       {:cont, socket}
    else
      # Fallback: Get user from session
      Logger.info("LiveView on_mount(:mount_current_user): User not in assigns, checking session...")
      user_token = session["user_token"]
      user = user_token && Accounts.get_user_by_session_token(user_token)

      Logger.info("LiveView on_mount(:mount_current_user): User fetched from session: #{inspect user && user.email}")

      socket = Phoenix.Component.assign(socket, current_user: user)
      {:cont, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    Logger.info("LiveView on_mount(:redirect_if_user_is_authenticated): Hook started")
    # Prioritize checking assigns first
    user = socket.assigns[:current_user]
    Logger.info("LiveView on_mount(:redirect_if_user_is_authenticated): User from socket assigns: #{inspect user && user.email}")


    if user do
      Logger.info("LiveView on_mount(:redirect_if_user_is_authenticated): User authenticated via assigns, redirecting to dashboard")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/dashboard")}
    else
      # Fallback: Get user from session
      Logger.info("LiveView on_mount(:redirect_if_user_is_authenticated): User not in assigns, checking session...")
      user_token = session["user_token"]
      user = user_token && Accounts.get_user_by_session_token(user_token)

      Logger.info("LiveView on_mount(:redirect_if_user_is_authenticated): User fetched from session: #{inspect user && user.email}")

      if user do
         Logger.info("LiveView on_mount(:redirect_if_user_is_authenticated): User authenticated via session, redirecting to dashboard")
         {:halt, Phoenix.LiveView.redirect(socket, to: "/dashboard")}
      else
        Logger.info("LiveView on_mount(:redirect_if_user_is_authenticated): User not authenticated, continuing")
        {:cont, socket}
      end
    end
  end

  def redirect_if_user_is_authenticated(conn, _opts) do
    Logger.info("REDIRECT_IF_AUTH Plug: Starting for Path #{conn.request_path}")
    Logger.info("REDIRECT_IF_AUTH Plug: User assigned: #{inspect(conn.assigns[:current_user] && conn.assigns[:current_user].email)}")

    if conn.assigns[:current_user] do
      Logger.info("REDIRECT_IF_AUTH Plug: User authenticated - redirecting to dashboard")
      conn
      |> put_flash(:info, "You are already logged in.")
      |> redirect(to: "/dashboard")
      |> halt()
    else
      Logger.info("REDIRECT_IF_AUTH Plug: User not authenticated - allowing continuation")
      conn
    end
  end

  def require_authenticated_user(conn, _opts) do
    Logger.info("REQUIRE_AUTH Plug: Starting for Path #{conn.request_path}")
    Logger.info("REQUIRE_AUTH Plug: User assigned: #{inspect(conn.assigns[:current_user] && conn.assigns[:current_user].email)}")

    if conn.assigns[:current_user] do
      Logger.info("REQUIRE_AUTH Plug: User authenticated - allowing continuation")
      conn
    else
      Logger.info("REQUIRE_AUTH Plug: User not authenticated - redirecting to login")
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/users/log_in")
      |> halt()
    end
  end

  # User login/logout
  # Modified: This function now only sets the session and cookie, it does NOT redirect.
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)

    Logger.info("Log_in_user: Setting session for user #{user.email}")
    Logger.info("Log_in_user: Generated token: #{inspect token}")

    conn
    |> renew_session() # Renew and clear existing session
    |> put_session(@session_key, token) # Set the new session token
    |> maybe_write_remember_me_cookie(token, params) # Handle remember me cookie
    # Removed the redirect call here
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    Logger.info("maybe_write_remember_me_cookie: Writing remember_me cookie")
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    Logger.info("maybe_write_remember_me_cookie: Not writing remember_me cookie")
    conn
  end

  # Helper function to renew and clear session
  defp renew_session(conn) do
    Logger.info("renew_session: Renewing and clearing session")
    conn
    |> configure_session(renew: true)
    |> clear_session() # Clears all session data, including user_return_to
  end

  def log_out_user(conn) do
    Logger.info("Log_out_user: Starting logout process")
    user_token = get_session(conn, @session_key)
    Logger.info("Log_out_user: Token from session before deletion: #{inspect user_token}")
    user_token && Accounts.delete_session_token(user_token)
    Logger.info("Log_out_user: Called Accounts.delete_session_token")


    if live_socket_id = get_session(conn, :live_socket_id) do
      Logger.info("Log_out_user: Broadcasting disconnect to LiveView socket #{live_socket_id}")
      FrestylWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: "/")
  end
end
