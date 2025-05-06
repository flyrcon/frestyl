# lib/frestyl_web/plugs/authenticate_user.ex
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
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: Routes.session_path(conn, :new))
      |> halt()
    end
  end
end
