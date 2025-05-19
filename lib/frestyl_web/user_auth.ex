# lib/frestyl_web/user_auth.ex
defmodule FrestylWeb.UserAuth do

  import Plug.Conn
  import Phoenix.Controller
  require Phoenix.LiveView
  require Logger

  alias Frestyl.Accounts
  alias Phoenix.Component
  alias FrestylWeb.Router.Helpers, as: Routes
  import FrestylWeb, only: [routes: 0]

  @session_key :user_token
  @remember_me_cookie "_frestyl_web_user_remember_me"
  @remember_me_options [sign: true, max_age: 60 * 60 * 24 * 60, same_site: "Lax"]

  # Plug protocol implementation
  def init(opts), do: opts

  def call(conn, :ensure_authenticated) do
    Logger.info("UserAuth.call: Using :ensure_authenticated plug")
    require_authenticated_user(conn, [])
  end

  def call(conn, :fetch_current_user) do
    fetch_current_user(conn, [])
  end

  def call(conn, _) do
    conn
  end

  # User session management - properly gets and assigns user
  def fetch_current_user(conn, _opts) do
    Logger.info("FETCH_CURRENT_USER Plug: Starting for path: #{conn.request_path}")

    # Always try to get a token from session or cookie
    {user_token, conn} = ensure_user_token(conn)
    Logger.info("FETCH_CURRENT_USER Plug: Token: #{inspect user_token}")

    # Only try to get user if we have a token
    user =
      if user_token do
        user = Accounts.get_user_by_session_token(user_token)
        Logger.info("FETCH_CURRENT_USER Plug: User from token: #{inspect user && user.email}")
        user
      else
        Logger.info("FETCH_CURRENT_USER Plug: No token, no user")
        nil
      end

    # Always assign the user (even if nil) and return
    conn = Plug.Conn.assign(conn, :current_user, user)
    Logger.info("FETCH_CURRENT_USER Plug: Assigned user to conn: #{inspect conn.assigns[:current_user] && conn.assigns[:current_user].email}")

    conn
  end

  # Session management helper to ensure token is always preserved
  defp ensure_user_token(conn) do
    Logger.info("ensure_user_token: Checking session for token")

    # Check for token in session first
    session_token = get_session(conn, @session_key)
    Logger.info("ensure_user_token: Session token: #{inspect session_token}")

    if session_token do
      Logger.info("ensure_user_token: Token found in session, returning it")
      {session_token, conn}
    else
      Logger.info("ensure_user_token: Token not in session, checking cookies")
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])
      cookie_token = conn.cookies[@remember_me_cookie]
      Logger.info("ensure_user_token: Cookie token: #{inspect cookie_token}")

      if cookie_token do
        Logger.info("ensure_user_token: Token found in remember_me cookie, putting in session and returning it")
        # IMPORTANT: Always update the session with the token from cookie
        updated_conn = put_session(conn, @session_key, cookie_token)
        {cookie_token, updated_conn}
      else
        Logger.info("ensure_user_token: No token found anywhere")
        {nil, conn}
      end
    end
  end

  # LiveView auth hooks

  def on_mount(:ensure_authenticated, _params, session, socket) do
    Logger.info("DashboardLive on_mount(:ensure_authenticated): Hook started")
    Logger.info("DashboardLive on_mount(:ensure_authenticated): Session: #{inspect session}")

    # Try to get user from session token
    user_token = session[@session_key |> Atom.to_string()] || session["user_token"] || session[:user_token]
    Logger.info("DashboardLive on_mount(:ensure_authenticated): Session token: #{inspect user_token}")

    user =
      if user_token do
        Logger.info("DashboardLive on_mount(:ensure_authenticated): Looking up user by token")
        Accounts.get_user_by_session_token(user_token)
      else
        Logger.info("DashboardLive on_mount(:ensure_authenticated): No token in session")
        nil
      end

    Logger.info("DashboardLive on_mount(:ensure_authenticated): User status: #{inspect user && user.email}")

    # If we found a user, assign to socket and continue the mount
    if user do
      Logger.info("DashboardLive on_mount(:ensure_authenticated): User is authenticated, continuing")
      socket = Phoenix.Component.assign(socket, :current_user, user)
      {:cont, socket}
    else
      # No authenticated user, redirect to login
      Logger.info("DashboardLive on_mount(:ensure_authenticated): No authenticated user found, redirecting")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/users/log_in")}
    end
  end

  # MUST redirect authenticated users to dashboard
  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    Logger.info("LiveView on_mount(:redirect_if_user_is_authenticated): ALWAYS REDIRECT VERSION")

    # Properly assign user to LiveView socket
    user_token = session[@session_key |> Atom.to_string()] || session[@session_key]

    user =
      if user_token do
        Logger.info("redirect_if_user_is_authenticated mount: Found token in session")
        Frestyl.Accounts.get_user_by_session_token(user_token)
      else
        Logger.info("redirect_if_user_is_authenticated mount: No token in session")
        nil
      end

    Logger.info("redirect_if_user_is_authenticated mount: User: #{inspect user && user.email}")

    # If user is authenticated, ALWAYS redirect to dashboard
    if user do
      Logger.info("redirect_if_user_is_authenticated mount: User is authenticated, redirecting to dashboard")
      {:halt, Phoenix.LiveView.redirect(socket, to: "/dashboard")}
    else
      Logger.info("redirect_if_user_is_authenticated mount: User is not authenticated, continuing")
      socket = Phoenix.Component.assign(socket, :current_user, nil)
      {:cont, socket}
    end
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    Logger.info("LiveView on_mount(:mount_current_user): Hook started")

    # Get user from session token
    user_token = session[@session_key |> Atom.to_string()] || session[@session_key]

    user =
      if user_token do
        Logger.info("mount_current_user: Found token in session")
        Frestyl.Accounts.get_user_by_session_token(user_token)
      else
        Logger.info("mount_current_user: No token in session")
        nil
      end

    Logger.info("mount_current_user: User: #{inspect user && user.email}")

    # Assign user to socket
    socket = Phoenix.Component.assign(socket, :current_user, user)
    {:cont, socket}
  end

  # Fixed to not redirect authenticated users
  def require_authenticated_user(conn, _opts) do
    # User is already authenticated, continue
    if conn.assigns[:current_user] do
      Logger.info("require_authenticated_user: User is authenticated, continuing")
      conn
    else
      Logger.info("require_authenticated_user: Not authenticated, redirecting to login")
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/users/log_in")
      |> halt()
    end
  end

  # Simplified to always redirect authenticated users to dashboard
  def redirect_if_user_is_authenticated(conn, _opts) do
    user = conn.assigns[:current_user]
    Logger.info("redirect_if_user_is_authenticated: Current path: #{conn.request_path}, User: #{inspect user && user.email}")

    if user do
      Logger.info("redirect_if_user_is_authenticated: User is authenticated, redirecting to dashboard")
      conn
      |> redirect(to: "/dashboard")
      |> halt()
    else
      Logger.info("redirect_if_user_is_authenticated: User is not authenticated, continuing")
      conn
    end
  end

  # Login function
  def log_in_user(conn, user, params \\ %{}) do
    Logger.info("log_in_user: Logging in user #{user.email}")

    # Check if user has 2FA enabled
    if user.totp_enabled do
      Logger.info("log_in_user: User has 2FA enabled, redirecting to verification")
      # Store user info in session but don't generate token yet
      conn
      |> put_session(:pending_2fa, %{
        "user_id" => user.id,
        "email" => user.email,
        "remember_me" => params["remember_me"]
      })
      |> redirect(to: Routes.user_live_two_factor_verify_path(conn, :index))
    else
      Logger.info("log_in_user: Normal login process")
      # Proceed with normal login
      token = Accounts.generate_user_session_token(user)
      Logger.info("log_in_user: Generated session token: #{inspect token}")

      conn = conn
        |> renew_session()
        |> put_session(@session_key, token)
        |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
        |> maybe_write_remember_me_cookie(token, params)

      # FORCE redirect to dashboard
      Logger.info("log_in_user: Redirecting to dashboard")
      redirect(conn, to: "/dashboard")
    end
  end

  # Add a function to complete login after 2FA verification
  def complete_2fa_login(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)

    conn
    |> renew_session()
    |> put_session(@session_key, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: "/dashboard")
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
