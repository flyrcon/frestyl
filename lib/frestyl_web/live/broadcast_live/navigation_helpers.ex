defmodule FrestylWeb.BroadcastLive.NavigationHelpers do
  @moduledoc """
  Navigation helpers for broadcast flow
  """

  def broadcast_path(action, broadcast_id, channel_id \\ nil) do
    case {action, channel_id} do
      {:sound_check, nil} -> "/broadcasts/#{broadcast_id}/sound-check"
      {:sound_check, channel_id} -> "/channels/#{channel_id}/broadcasts/#{broadcast_id}/sound-check"

      {:waiting, nil} -> "/broadcasts/#{broadcast_id}/waiting"
      {:waiting, channel_id} -> "/channels/#{channel_id}/broadcasts/#{broadcast_id}/waiting"

      {:live, nil} -> "/broadcasts/#{broadcast_id}/live"
      {:live, channel_id} -> "/channels/#{channel_id}/broadcasts/#{broadcast_id}/live"

      {:manage, nil} -> "/broadcasts/#{broadcast_id}/manage"
      {:manage, channel_id} -> "/channels/#{channel_id}/broadcasts/#{broadcast_id}/manage"

      _ -> "/broadcasts/#{broadcast_id}/live"
    end
  end

  def redirect_to_broadcast_stage(socket, broadcast) do
    channel_id = socket.assigns[:channel_id]

    case broadcast.status do
      "scheduled" ->
        # Broadcast is scheduled but not started - go to waiting room
        path = broadcast_path(:waiting, broadcast.id, channel_id)
        Phoenix.LiveView.redirect(socket, to: path)

      "active" ->
        # Broadcast is live - go directly to live view
        path = broadcast_path(:live, broadcast.id, channel_id)
        Phoenix.LiveView.redirect(socket, to: path)

      "ended" ->
        # Broadcast has ended - redirect to channel or show ended message
        if channel_id do
          Phoenix.LiveView.redirect(socket, to: "/channels/#{channel_id}")
        else
          socket
          |> Phoenix.LiveView.put_flash(:info, "This broadcast has ended")
          |> Phoenix.LiveView.redirect(to: "/dashboard")
        end

      _ ->
        # Unknown status - go to live view as fallback
        path = broadcast_path(:live, broadcast.id, channel_id)
        Phoenix.LiveView.redirect(socket, to: path)
    end
  end

  def get_next_broadcast_stage(current_stage, broadcast) do
    case {current_stage, broadcast.status} do
      {:sound_check, "scheduled"} -> :waiting
      {:sound_check, "active"} -> :live
      {:waiting, "active"} -> :live
      _ -> :live
    end
  end

  def broadcast_stage_title(stage) do
    case stage do
      :sound_check -> "Sound Check"
      :waiting -> "Waiting Room"
      :live -> "Live Broadcast"
      :manage -> "Broadcast Management"
      _ -> "Broadcast"
    end
  end
end
