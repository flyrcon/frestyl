defmodule FrestylWeb.AuthHelpers do
  @moduledoc """
  Helper functions for authorization in LiveViews.
  """

  def require_supervisor_role(socket) do
    case socket.assigns[:current_user] do
      %{role: role} when role in [:instructor, :supervisor, :admin] ->
        socket

      _ ->
        socket
        |> Phoenix.LiveView.put_flash(:error, "Access denied: Supervisor role required.")
        |> Phoenix.LiveView.redirect(to: "/dashboard")
    end
  end

  def require_team_access(socket, team_id) do
    user = socket.assigns.current_user

    cond do
      user.role in [:supervisor, :admin] ->
        socket

      user.role == :instructor and is_team_supervisor?(team_id, user.id) ->
        socket

      user.role == :student and is_team_member?(team_id, user.id) ->
        socket

      true ->
        socket
        |> Phoenix.LiveView.put_flash(:error, "You don't have access to this team.")
        |> Phoenix.LiveView.redirect(to: "/dashboard")
    end
  end

  defp is_team_supervisor?(team_id, user_id) do
    case Frestyl.Teams.get_team(team_id) do
      %{supervisor_id: ^user_id} -> true
      _ -> false
    end
  end

  defp is_team_member?(team_id, user_id) do
    Frestyl.Teams.is_team_member?(team_id, user_id)
  end
end
