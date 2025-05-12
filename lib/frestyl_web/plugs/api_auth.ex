# lib/frestyl_web/plugs/api_auth.ex
defmodule FrestylWeb.Plugs.ApiAuth do
  @moduledoc """
  Plug to authenticate API requests using tokens.
  Can accept tokens via Authorization header or query parameter.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Frestyl.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    # If user is already assigned (from session), no need to check token
    if conn.assigns[:current_user] do
      conn
    else
      # Try to get token from header or query param
      token = get_token_from_header(conn) || get_token_from_query(conn)

      if token do
        case Accounts.get_user_by_session_token(token) do
          %Frestyl.Accounts.User{} = user ->
            # Assign current user to connection
            assign(conn, :current_user, user)

          nil ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "invalid_token", message: "Invalid or expired token"})
            |> halt()
        end
      else
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "missing_token", message: "Authentication token missing"})
        |> halt()
      end
    end
  end

  defp get_token_from_header(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp get_token_from_query(conn) do
    conn.params["token"]
  end
end
