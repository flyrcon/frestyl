defmodule FrestylWeb.ChatLive.Show do
  use FrestylWeb, :live_view
  require Logger

  alias Frestyl.Chat
  alias Frestyl.Channels
  alias Frestyl.Accounts
  import FrestylWeb.Navigation

  @impl true
  def mount(params, _session, socket) do
    Logger.info("ChatLive.Show: Mounting with params=#{inspect(params)}")

    socket = assign(socket,
      # UI State
      search_query: "",
      active_tab: "all", # "all", "channels", "direct"
      selected_conversation: nil,
      selected_channel: nil,

      # Data
      conversations: [],
      channels: [],
      messages: [],
      users_map: %{},
      online_users: [],

      # Message input
      message_text: "",
      typing_users: MapSet.new(),

      # Media & reactions
      emoji_reactions: %{},
      custom_reactions: %{},
      pinned_messages: [],
      shared_files: [],

      # Real-time state
      has_more_messages: true,
      loading_messages: false,
      error_message: nil
    )

    if connected?(socket) do
      # Load initial data
      socket = load_initial_data(socket)

      # Handle specific conversation/channel from URL
      socket = case params do
        %{"type" => "channel", "id" => channel_id} ->
          load_channel_chat(socket, channel_id)
        %{"type" => "conversation", "id" => conversation_id} ->
          load_conversation_chat(socket, conversation_id)
        %{"id" => id} ->
          auto_detect_and_load(socket, id)
        _ ->
          socket
      end

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = case params do
      %{"type" => "channel", "id" => channel_id} ->
        load_channel_chat(socket, channel_id)
      %{"type" => "conversation", "id" => conversation_id} ->
        load_conversation_chat(socket, conversation_id)
      %{"id" => id} ->
        auto_detect_and_load(socket, id)
      _ ->
        assign(socket, selected_conversation: nil, selected_channel: nil)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    # Simple filtering for now
    filtered_conversations = filter_conversations(socket.assigns.conversations, query)
    filtered_channels = filter_channels(socket.assigns.channels, query)

    {:noreply, assign(socket,
      search_query: query,
      conversations: filtered_conversations,
      channels: filtered_channels
    )}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def handle_event("select_conversation", %{"id" => conversation_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/chat/conversation/#{conversation_id}")}
  end

  @impl true
  def handle_event("select_channel", %{"id" => channel_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/chat/channel/#{channel_id}")}
  end

  @impl true
  def handle_event("send_message", %{"message" => message_content}, socket) when message_content != "" do
    user = socket.assigns.current_user

    result = cond do
      socket.assigns.selected_channel ->
        Chat.create_channel_message(
          %{"content" => message_content, "message_type" => "text"},
          user,
          socket.assigns.selected_channel
        )

      socket.assigns.selected_conversation ->
        Chat.create_message(
          %{"content" => message_content},
          user,
          socket.assigns.selected_conversation
        )

      true ->
        {:error, "No active conversation"}
    end

    case result do
      {:ok, _message} ->
        {:noreply, assign(socket, message_text: "")}
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("typing", %{"value" => value}, socket) do
    user_id = socket.assigns.current_user.id
    typing = value != ""

    # Broadcast typing status (simplified for now)
    if socket.assigns.selected_channel do
      Chat.broadcast_typing_status(socket.assigns.selected_channel.id, user_id, typing)
    end

    {:noreply, assign(socket, message_text: value)}
  end

  @impl true
  def handle_event("show_new_conversation_modal", _params, socket) do
    # For now, just show a simple flash
    {:noreply, put_flash(socket, :info, "New conversation feature coming soon!")}
  end

  # Private helper functions
  defp load_initial_data(socket) do
    user = socket.assigns.current_user

    # Load conversations and channels
    conversations = Chat.list_user_conversations(user.id)
    channels = Channels.list_user_channels(user)

    # Create users map for quick lookup
    all_users = Accounts.list_users() # You might want to optimize this
    users_map = Map.new(all_users, fn user -> {user.id, user} end)

    assign(socket,
      conversations: conversations,
      channels: channels,
      users_map: users_map
    )
  end

  defp load_channel_chat(socket, channel_id) do
    try do
      channel = Channels.get_channel!(channel_id)

      # Subscribe to channel updates
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel_id}")

      # Load messages
      messages = Chat.list_recent_channel_messages(channel_id, 50)

      assign(socket,
        selected_channel: channel,
        selected_conversation: nil,
        messages: messages
      )
    rescue
      Ecto.NoResultsError ->
        socket
        |> put_flash(:error, "Channel not found")
        |> push_patch(to: ~p"/chat")
    end
  end

  defp load_conversation_chat(socket, conversation_id) do
    try do
      conversation = Chat.get_conversation!(conversation_id)

      # Subscribe to conversation updates
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "conversation:#{conversation_id}")

      # Load messages
      messages = Chat.list_messages_for_conversation(conversation_id, preload: [:user])

      assign(socket,
        selected_conversation: conversation,
        selected_channel: nil,
        messages: messages
      )
    rescue
      Ecto.NoResultsError ->
        socket
        |> put_flash(:error, "Conversation not found")
        |> push_patch(to: ~p"/chat")
    end
  end

  defp auto_detect_and_load(socket, id) do
    # Try to find as channel first, then conversation
    case Channels.get_channel(id) do
      %Channels.Channel{} = _channel ->
        load_channel_chat(socket, id)
      nil ->
        case Chat.get_conversation(id) do
          %Chat.Conversation{} = _conversation ->
            load_conversation_chat(socket, id)
          nil ->
            socket
            |> put_flash(:error, "Chat not found")
            |> push_patch(to: ~p"/chat")
        end
    end
  end

  defp filter_conversations(conversations, query) do
    if query == "" do
      conversations
    else
      Enum.filter(conversations, fn conv ->
        String.contains?(String.downcase(conv.title || ""), String.downcase(query))
      end)
    end
  end

  defp filter_channels(channels, query) do
    if query == "" do
      channels
    else
      Enum.filter(channels, fn channel ->
        String.contains?(String.downcase(channel.name), String.downcase(query))
      end)
    end
  end

  # Helper functions for the template
  def format_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  def time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end

  def get_user_name(user_id, users_map) do
    case Map.get(users_map, user_id) do
      %{name: name} when not is_nil(name) -> name
      %{email: email} -> email
      _ -> "Unknown User"
    end
  end

  def message_reactions(message_id, emoji_reactions, custom_reactions) do
    emoji_reactions = Map.get(emoji_reactions, message_id, %{})
    custom_reactions = Map.get(custom_reactions, message_id, %{})

    %{
      emoji: emoji_reactions,
      custom: custom_reactions
    }
  end
end
