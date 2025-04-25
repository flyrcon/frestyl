# lib/frestyl_web/controllers/auth.ex
defmodule FrestylWeb.Auth do
  import Plug.Conn
  import Phoenix.Controller
  alias FrestylWeb.Router.Helpers, as: Routes

  # ... existing code ...

  def require_admin_user(conn, _opts) do
    if conn.assigns[:current_user] && conn.assigns[:current_user].is_admin do
      conn
    else
      conn
      |> put_flash(:error, "You must be an administrator to access that page.")
      |> redirect(to: Routes.page_path(conn, :index))
      |> halt()
    end
  end

  # Add this to your authentication logic
  def verify_subscription_access(conn, resource_owner_id) do
    user = conn.assigns.current_user

    if user.id == resource_owner_id || user.is_admin do
      conn
    else
      conn
      |> put_flash(:error, "You don't have permission to access that resource.")
      |> redirect(to: Routes.page_path(conn, :index))
      |> halt()
    end
  end
end
