# lib/frestyl_web/controllers/user_profile_controller.ex
defmodule FrestylWeb.UserProfileController do
  use FrestylWeb, :controller

  alias Frestyl.Accounts

  def show(conn, _params) do
    user = conn.assigns.current_user
    render(conn, :show, user: user)

    # Get personalized recommendations for the user
    recommendations =
      case AIAssistant.get_user_recommendations(user.id) do
        {:ok, recs} -> recs
        _ -> []
      end

    render(conn, :show,
      user: user,
      recommendations: recommendations
    )
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
