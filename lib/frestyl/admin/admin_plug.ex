# lib/frestyl/admin/admin_plug.ex
defmodule Frestyl.Admin.AdminPlug do
  @moduledoc """
  Plug for admin authentication and role checking.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  alias Frestyl.Admin.UserManagement

  def init(opts), do: opts

  def call(conn, opts) do
    required_role = Keyword.get(opts, :role, "admin")

    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to access this page")
        |> redirect(to: "/auth/login")
        |> halt()

      user ->
        if has_required_admin_access?(user, required_role) do
          assign(conn, :current_admin_user, user)
        else
          conn
          |> put_flash(:error, "Admin access required")
          |> redirect(to: "/")
          |> halt()
        end
    end
  end

  defp has_required_admin_access?(user, required_role) do
    user_roles = UserManagement.get_user_admin_roles(user.id)

    cond do
      # Super admin can access everything
      "super_admin" in user_roles -> true

      # Check specific role requirements
      required_role == "super_admin" and "super_admin" in user_roles -> true
      required_role == "moderator" and ("moderator" in user_roles or "super_admin" in user_roles) -> true
      required_role == "admin" and length(user_roles) > 0 -> true

      # Fallback to checking is_admin field
      Map.get(user, :is_admin, false) -> true

      true -> false
    end
  end
end
