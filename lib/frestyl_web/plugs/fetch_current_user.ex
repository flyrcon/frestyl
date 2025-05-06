# lib/frestyl_web/plugs/fetch_current_user.ex
defmodule FrestylWeb.Plugs.FetchCurrentUser do
  @moduledoc """
  Plug to fetch the current user from the session and assign to conn.
  """

  import Plug.Conn

  alias Frestyl.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      case Accounts.get_user(user_id) do
        %Accounts.User{} = user ->
          assign(conn, :current_user, user)

        _ ->
          assign(conn, :current_user, nil)
      end
    else
      assign(conn, :current_user, nil)
    end
  end
end
