defmodule FrestylWeb.ChannelLive.ChatComponent do
  use Phoenix.LiveComponent

  import Phoenix.HTML, only: [raw: 1]

  alias Frestyl.Chat
  alias Phoenix.LiveView.JS


  @impl true
  def update(assigns, socket) do
    # Just assign the assigns - NO upload configuration here
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("typing", _params, socket) do
    if connected?(socket) do
      user_id = socket.assigns.current_user.id
      chat_id = socket.assigns.id

      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "chat:#{chat_id}",
        {:user_typing, user_id}
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("handle-key", %{"key" => "Enter", "shiftKey" => false}, socket) do
    send(self(), :submit_message_form)
    {:noreply, socket}
  end

  @impl true
  def handle_event("handle-key", _key_info, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    socket = assign(socket, :loading_messages, true)

    oldest_message_id =
      case socket.assigns.messages do
        [first | _] -> first.id
        _ -> nil
      end

    case load_earlier_messages(socket.assigns.conversation_id, oldest_message_id) do
      {:ok, earlier_messages} ->
        {:noreply,
        socket
        |> assign(:messages, earlier_messages ++ socket.assigns.messages)
        |> assign(:loading_messages, false)
        |> assign(:has_more, length(earlier_messages) >= 20)}

      {:error, _reason} ->
        {:noreply, assign(socket, :loading_messages, false)}
    end
  end

  @impl true
  def handle_event("delete_message", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    message = Enum.find(socket.assigns.messages, fn m -> m.id == message_id end)

    if message && message.user_id == socket.assigns.current_user.id do
      case delete_message(message_id) do
        {:ok, _} ->
          updated_messages = Enum.reject(socket.assigns.messages, fn m -> m.id == message_id end)
          {:noreply, assign(socket, :messages, updated_messages)}

        {:error, _reason} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle-reaction", %{"message-id" => message_id, "emoji" => emoji}, socket) do
    message_id = String.to_integer(message_id)
    user_id = socket.assigns.current_user.id

    current_reactions = Map.get(socket.assigns.emoji_reactions, message_id, %{})
    current_users = Map.get(current_reactions, emoji, [])

    updated_users =
      if user_id in current_users do
        List.delete(current_users, user_id)
      else
        [user_id | current_users]
      end

    updated_message_reactions =
      if Enum.empty?(updated_users) do
        Map.delete(current_reactions, emoji)
      else
        Map.put(current_reactions, emoji, updated_users)
      end

    updated_reactions =
      if Enum.empty?(updated_message_reactions) do
        Map.delete(socket.assigns.emoji_reactions, message_id)
      else
        Map.put(socket.assigns.emoji_reactions, message_id, updated_message_reactions)
      end

    save_reaction(message_id, user_id, emoji, user_id in current_users)

    {:noreply, assign(socket, :emoji_reactions, updated_reactions)}
  end

  @impl true
  def handle_event("toggle-custom-reaction", %{"message-id" => message_id, "text" => text}, socket) do
    message_id = String.to_integer(message_id)
    user_id = socket.assigns.current_user.id

    current_reactions = Map.get(socket.assigns.custom_reactions, message_id, %{})
    current_users = Map.get(current_reactions, text, [])

    updated_users =
      if user_id in current_users do
        List.delete(current_users, user_id)
      else
        [user_id | current_users]
      end

    updated_message_reactions =
      if Enum.empty?(updated_users) do
        Map.delete(current_reactions, text)
      else
        Map.put(current_reactions, text, updated_users)
      end

    updated_reactions =
      if Enum.empty?(updated_message_reactions) do
        Map.delete(socket.assigns.custom_reactions, message_id)
      else
        Map.put(socket.assigns.custom_reactions, message_id, updated_message_reactions)
      end

    save_custom_reaction(message_id, user_id, text, user_id in current_users)

    {:noreply, assign(socket, :custom_reactions, updated_reactions)}
  end

  @impl true
  def handle_event("add-reaction", %{"message-id" => message_id, "emoji" => emoji}, socket) do
    message_id = String.to_integer(message_id)
    user_id = socket.assigns.current_user.id

    current_reactions = Map.get(socket.assigns.emoji_reactions, message_id, %{})
    current_users = Map.get(current_reactions, emoji, [])

    unless user_id in current_users do
      updated_users = [user_id | current_users]
      updated_message_reactions = Map.put(current_reactions, emoji, updated_users)
      updated_reactions = Map.put(socket.assigns.emoji_reactions, message_id, updated_message_reactions)

      save_reaction(message_id, user_id, emoji, false)

      {:noreply, assign(socket, :emoji_reactions, updated_reactions)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add-custom-reaction", %{"message-id" => message_id, "text" => text}, socket) do
    message_id = String.to_integer(message_id)
    user_id = socket.assigns.current_user.id

    current_reactions = Map.get(socket.assigns.custom_reactions, message_id, %{})
    current_users = Map.get(current_reactions, text, [])

    unless user_id in current_users do
      updated_users = [user_id | current_users]
      updated_message_reactions = Map.put(current_reactions, text, updated_users)
      updated_reactions = Map.put(socket.assigns.custom_reactions, message_id, updated_message_reactions)

      save_custom_reaction(message_id, user_id, text, false)

      {:noreply, assign(socket, :custom_reactions, updated_reactions)}
    else
      {:noreply, socket}
    end
  end

  # Helper functions

  def get_message_user(message, users_map) do
    Map.get(users_map, message.user_id, %{
      name: "Unknown User",
      email: "unknown@example.com"
    })
  end

  def format_message_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d at %H:%M")
    end
  end

  def format_file_size(size) when is_nil(size), do: "Unknown size"
  def format_file_size(size) when size < 1024, do: "#{size} B"
  def format_file_size(size) when size < 1024 * 1024, do: "#{Float.round(size / 1024, 1)} KB"
  def format_file_size(size), do: "#{Float.round(size / 1024 / 1024, 1)} MB"

  def error_to_string(:too_large), do: "File is too large"
  def error_to_string(:too_many_files), do: "Too many files"
  def error_to_string(:not_accepted), do: "File type not accepted"
  def error_to_string(_), do: "Upload error"

  def typing_indicator_text(typing_users, current_user, users_map) do
    other_users = MapSet.to_list(typing_users)
      |> Enum.reject(&(&1 == current_user.id))

    case length(other_users) do
      0 -> ""
      1 ->
        user = Map.get(users_map, to_string(hd(other_users)), %{name: "Someone"})
        "#{user.name || "Someone"} is typing..."
      2 ->
        names = other_users
          |> Enum.take(2)
          |> Enum.map(&(Map.get(users_map, to_string(&1), %{name: "Someone"}).name || "Someone"))
        "#{Enum.join(names, " and ")} are typing..."
      _ -> "Several people are typing..."
    end
  end

  # Private functions

  defp create_message(socket, params) do
    case Frestyl.Chat.create_message(params) do
      {:ok, message} ->
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "conversation:#{params["conversation_id"]}",
          {:new_message, message}
        )

        {:ok, message, socket}

      {:error, changeset} ->
        {:error, changeset, socket}
    end
  end

  defp load_earlier_messages(conversation_id, before_message_id) do
    try do
      messages = Frestyl.Chat.list_messages_for_conversation(
        conversation_id,
        before: before_message_id,
        limit: 20,
        preload: [:user, :attachments]
      )

      {:ok, messages}
    rescue
      _ -> {:error, "Failed to load messages"}
    end
  end

  defp delete_message(message_id) do
    Frestyl.Chat.delete_message(message_id)
  end

  defp save_reaction(message_id, user_id, emoji, remove) do
    if remove do
      Frestyl.Chat.remove_reaction(message_id, user_id, emoji)
    else
      Frestyl.Chat.add_reaction(message_id, user_id, emoji)
    end
  end

  defp save_custom_reaction(message_id, user_id, text, remove) do
    if remove do
      Frestyl.Chat.remove_custom_reaction(message_id, user_id, text)
    else
      Frestyl.Chat.add_custom_reaction(message_id, user_id, text)
    end
  end
end
