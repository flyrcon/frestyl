# lib/frestyl_web/channels/room_channel.ex

defmodule FrestylWeb.RoomChannel do
  use Phoenix.Channel
  alias Frestyl.Presence
  alias Frestyl.PubSub
  alias Frestyl.Streaming

  def join("room:" <> room_id, _params, socket) do
    if authorized?(socket, room_id) do
      send(self(), :after_join)
      {:ok, assign(socket, :room_id, room_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:after_join, socket) do
    Presence.track(socket, socket.assigns.user_id, %{
      online_at: :os.system_time(:millisecond),
      typing: false
    })

    push(socket, "presence_state", Presence.list(socket))

    # Fetch and send room history
    room_id = socket.assigns.room_id
    messages = Streaming.get_recent_messages(room_id, 50)
    push(socket, "history", %{messages: messages})

    {:noreply, socket}
  end

  def handle_in("message", %{"content" => content}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    # Store message
    {:ok, message} = Streaming.create_message(%{
      room_id: room_id,
      user_id: user_id,
      content: content,
      timestamp: :os.system_time(:millisecond)
    })

    # Broadcast to all room members
    broadcast!(socket, "message", %{
      id: message.id,
      user_id: user_id,
      content: content,
      timestamp: message.timestamp
    })

    {:reply, :ok, socket}
  end

  def handle_in("typing", %{"typing" => typing}, socket) do
    user_id = socket.assigns.user_id

    {:ok, _} = Presence.update(socket, user_id, fn meta ->
      Map.put(meta, :typing, typing)
    end)

    {:reply, :ok, socket}
  end

  # Private functions
  defp authorized?(socket, room_id) do
    # Add your authorization logic here
    true
  end
end
