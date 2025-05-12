# lib/frestyl_web/live/chat_live/show.ex
defmodule FrestylWeb.ChatLive.Show do
  use FrestylWeb, :live_view

  @impl true
  def mount(%{"channel_id" => channel_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to channel updates
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel_id}")
    end

    channel = get_channel(channel_id)

    {:ok,
     socket
     |> assign(:channel, channel)
     |> assign(:message, "")
     |> assign(:messages, list_messages(channel_id))}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    case save_message(socket.assigns.channel.id, socket.assigns.current_user.id, message) do
      {:ok, _message} ->
        # Broadcast new message
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "channel:#{socket.assigns.channel.id}",
          {:new_message, %{content: message, user: socket.assigns.current_user}}
        )

        {:noreply, assign(socket, :message, "")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  # Helper for formatting typing indicator messages
  defp typing_message(typing_users) do
    # Get user information - adjust this to match your app's user retrieval
    typing_usernames = Enum.map(Map.keys(typing_users), fn user_id ->
      case Frestyl.Accounts.get_user(user_id) do
        %{username: username} when not is_nil(username) -> username
        %{email: email} -> email |> String.split("@") |> List.first()
        _ -> "Someone"
      end
    end)

    case length(typing_usernames) do
      1 -> "#{List.first(typing_usernames)} is typing..."
      2 -> "#{List.first(typing_usernames)} and #{List.last(typing_usernames)} are typing..."
      n when n > 2 -> "Several people are typing..."
      _ -> ""
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    messages = [message | socket.assigns.messages]
    {:noreply, assign(socket, :messages, messages)}
  end

  defp get_channel(channel_id) do
    # Implement channel lookup
    %{id: channel_id, name: "Channel #{channel_id}", description: "Channel description"}
  end

  defp list_messages(channel_id) do
    # Implement message fetching
    []
  end

  defp save_message(channel_id, user_id, content) do
    # Implement message saving
    {:ok, %{content: content, user_id: user_id, channel_id: channel_id}}
  end
end
