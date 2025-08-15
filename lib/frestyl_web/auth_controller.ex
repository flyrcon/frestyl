defmodule FrestylWeb.AuthController do
  use FrestylWeb, :controller
  alias Frestyl.Accounts

  def login(conn, _params) do
    render(conn, "login.html")
  end

  def create_session(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_session(:current_user_id, user.id)
        |> put_flash(:info, "Welcome back, #{user.first_name}!")
        |> redirect_after_login(user)

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> render("login.html")
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:current_user_id)
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: "/")
  end

  defp redirect_after_login(conn, %{role: role}) do
    case role do
      role when role in [:instructor, :supervisor, :admin] ->
        redirect(conn, to: "/supervisor/teams")

      :student ->
        redirect(conn, to: "/dashboard")

      _ ->
        redirect(conn, to: "/dashboard")
    end
  end
end
