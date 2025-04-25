# lib/frestyl_web/controllers/admin_user_controller.ex
defmodule FrestylWeb.AdminUserController do
  use FrestylWeb, :controller

  alias Frestyl.Accounts

  def index(conn, params) do
    users = Accounts.list_users(
      role: params["role"],
      tier: params["tier"]
    )

    render(conn, :index, users: users)
  end

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, :show, user: user)
  end

  def edit(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    changeset = Accounts.change_user(user)

    render(conn, :edit,
      user: user,
      changeset: changeset,
      roles: ["user", "creator", "host", "channel_owner", "admin"],
      tiers: ["free", "basic", "premium", "pro"]
    )
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Accounts.get_user!(id)

    case Accounts.admin_update_user(user, user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User updated successfully.")
        |> redirect(to: ~p"/admin/users")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit,
          user: user,
          changeset: changeset,
          roles: ["user", "creator", "host", "channel_owner", "admin"],
          tiers: ["free", "basic", "premium", "pro"]
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)

    conn
    |> put_flash(:info, "User deleted successfully.")
    |> redirect(to: ~p"/admin/users")
  end
end
