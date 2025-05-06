defmodule FrestylWeb.UserRegistrationController do
  use FrestylWeb, :controller

  alias Frestyl.Accounts
  alias Frestyl.Accounts.User
  alias FrestylWeb.UserAuth

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Account created successfully!")
        |> UserAuth.log_in_user(user)
        |> redirect(to: "/dashboard")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
