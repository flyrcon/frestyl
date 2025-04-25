# lib/frestyl_web/controllers/user_profile_controller.ex
defmodule FrestylWeb.UserProfileController do
  use FrestylWeb, :controller

  alias Frestyl.Accounts

  def show(conn, _params) do
    user = conn.assigns.current_user
    render(conn, :show, user: user)
  end

  def edit(conn, _params) do
    user = conn.assigns.current_user
    changeset = Accounts.change_user_profile(user)
    render(conn, :edit, user: user, changeset: changeset)
  end

  def update(conn, %{"user" => user_params}) do
    user = conn.assigns.current_user

    case Accounts.update_profile(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Profile updated successfully.")
        |> redirect(to: ~p"/profile")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, user: user, changeset: changeset)
    end
  end
end
