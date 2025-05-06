defmodule FrestylWeb.AuthRedirectController do
  use FrestylWeb, :controller

  def login_redirect(conn, %{"user_id" => user_id}) do
    conn
    |> put_session(:user_id, user_id)
    |> redirect(to: "/")
  end
end
