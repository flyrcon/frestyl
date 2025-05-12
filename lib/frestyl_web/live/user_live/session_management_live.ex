# lib/frestyl_web/live/user_live/session_management_live.ex
defmodule FrestylWeb.UserLive.SessionManagementLive do
  use FrestylWeb, :live_view
  alias Frestyl.Accounts

  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    # Get token from connect params or session (passed from LiveView hooks)
    current_token = get_connect_param(socket, "user_token") || session["user_token"]

    sessions = Accounts.list_user_sessions(user.id)
    |> Enum.map(fn user_session ->
      active = user_session.token == current_token
      Map.put(user_session, :current, active)
    end)

    {:ok, assign(socket, sessions: sessions)}
  end

  # Use get_connect_param to safely get connect params
  defp get_connect_param(socket, key) do
    connect_params = get_connect_params(socket)
    if connect_params, do: connect_params[key], else: nil
  end

  def handle_event("revoke_session", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Accounts.revoke_session(id, user_id) do
      {1, _} ->
        # Re-fetch sessions after revoking
        current_token = get_connect_param(socket, "user_token") || socket.assigns[:user_token]

        sessions = Accounts.list_user_sessions(user_id)
        |> Enum.map(fn user_session ->
          active = user_session.token == current_token
          Map.put(user_session, :current, active)
        end)

        socket =
          socket
          |> put_flash(:info, "Session successfully revoked")
          |> assign(:sessions, sessions)

        {:noreply, socket}

      {0, _} ->
        socket =
          socket
          |> put_flash(:error, "Error revoking session")

        {:noreply, socket}
    end
  end

  def handle_event("revoke_all_other_sessions", _, socket) do
    user_id = socket.assigns.current_user.id
    current_token = get_connect_param(socket, "user_token") || socket.assigns[:user_token]

    case Accounts.revoke_all_sessions_except_current(current_token, user_id) do
      {count, _} when count > 0 ->
        sessions = [%{
          id: nil,
          token: current_token,
          inserted_at: nil,
          user_agent: nil,
          ip: nil,
          current: true
        }]

        socket =
          socket
          |> put_flash(:info, "Successfully signed out from all other devices")
          |> assign(:sessions, sessions)

        {:noreply, socket}

      {0, _} ->
        socket =
          socket
          |> put_flash(:info, "No other active sessions found")

        {:noreply, socket}
    end
  end
end
