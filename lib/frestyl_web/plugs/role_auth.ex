# lib/frestyl_web/plugs/role_auth.ex
defmodule FrestylWeb.Plugs.RoleAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias Frestyl.Accounts
  alias FrestylWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, roles) when is_list(roles) do
    user = conn.assigns[:current_user]

    cond do
      # No user is signed in
      is_nil(user) ->
        conn
        |> put_flash(:error, "You must sign in to access this page.")
        |> redirect(to: Routes.user_session_path(conn, :new))
        |> halt()

      # User doesn't have the required role
      user.role not in roles ->
        conn
        |> put_flash(:error, "You don't have permission to access this page.")
        |> redirect(to: Routes.page_path(conn, :index))
        |> halt()

      # User has the required role
      true ->
        conn
    end
  end

  def call(conn, permission) when is_atom(permission) do
    user = conn.assigns[:current_user]

    cond do
      # No user is signed in
      is_nil(user) ->
        conn
        |> put_flash(:error, "You must sign in to access this page.")
        |> redirect(to: Routes.user_session_path(conn, :new))
        |> halt()

      # User doesn't have the required permission
      not Accounts.has_permission?(user, permission) ->
        conn
        |> put_flash(:error, "You don't have permission to access this page.")
        |> redirect(to: Routes.page_path(conn, :index))
        |> halt()

      # User has the required permission
      true ->
        conn
    end
  end
end
