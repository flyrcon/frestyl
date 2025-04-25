# lib/frestyl_web/channels/user_channel.ex

defmodule FrestylWeb.UserChannel do
  use Phoenix.Channel
  alias Frestyl.Presence
  alias Frestyl.Accounts

  def join("user:" <> user_id, _params, socket) do
    if socket.assigns.user_id == user_id do
      send(self(), :after_join)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id

    # Track user presence
    {:ok, _} = Presence.track(socket, user_id, %{
      online_at: :os.system_time(:millisecond),
      status: "online"
    })

    # Fetch unread notifications and direct messages
    notifications = Accounts.get_user_notifications(user_id, limit: 20)
    push(socket, "notifications", %{notifications: notifications})

    {:noreply, socket}
  end

  def handle_in("status", %{"status" => status}, socket) do
    user_id = socket.assigns.user_id

    # Update presence status
    {:ok, _} = Presence.update(socket, user_id, fn meta ->
      Map.put(meta, :status, status)
    end)

    # Update in database
    Accounts.update_user_status(user_id, status)

    {:reply, :ok, socket}
  end
end
