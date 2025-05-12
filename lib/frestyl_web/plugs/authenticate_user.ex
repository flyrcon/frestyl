# lib/frestyl_web/plugs/authenticate_user.ex (modified)
defmodule FrestylWeb.Plugs.AuthenticateUser do
  @moduledoc """
  Plug to authenticate the user before accessing certain routes.
  Redirects to login page if the user is not authenticated.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias FrestylWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      # User is authenticated, now check 2FA if needed
      user = conn.assigns.current_user

      if user.totp_enabled && !get_session(conn, :totp_verified) do
        # User has 2FA enabled but hasn't verified for this session
        conn
        |> put_flash(:info, "Please complete two-factor authentication")
        |> redirect(to: Routes.user_two_factor_verify_path(conn, :index))
        |> halt()
      else
        # User is fully authenticated
        conn
      end
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: Routes.session_path(conn, :new))
      |> halt()
    end
  end
end
