# lib/frestyl_web/channels/signaling_channel.ex

defmodule FrestylWeb.SignalingChannel do
  use Phoenix.Channel
  alias Frestyl.Presence

  def join("signaling:lobby", _payload, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def join("signaling:" <> room_id, _payload, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :room_id, room_id)}
  end

  def handle_info(:after_join, socket) do
    room_id = socket.assigns[:room_id] || "lobby"
    {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
      online_at: :os.system_time(:millisecond),
      room_id: room_id
    })
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in("signal", %{"to" => to_user_id, "signal" => signal}, socket) do
    broadcast_from!(socket, "signal", %{
      from: socket.assigns.user_id,
      signal: signal
    })
    {:noreply, socket}
  end

  def handle_in("ice_candidate", %{"to" => to_user_id, "candidate" => candidate}, socket) do
    broadcast_from!(socket, "ice_candidate", %{
      from: socket.assigns.user_id,
      candidate: candidate
    })
    {:noreply, socket}
  end
end
