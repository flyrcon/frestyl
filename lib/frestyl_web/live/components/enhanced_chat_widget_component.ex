

# lib/frestyl_web/live/components/enhanced_chat_widget_component.ex

defmodule FrestylWeb.EnhancedChatWidgetComponent do
  @moduledoc """
  Enhanced chat widget that integrates with your existing Chat system
  and adds contextual awareness for the portfolio hub.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Chat
  alias Frestyl.Chat.ContextManager
  alias Frestyl.Notifications
  alias Phoenix.PubSub

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      widget_state: :minimized,
      active_conversation: nil,
      conversations: [],
      unread_count: 0,
      chat_context: :general,
      message_input: "",
      typing_users: MapSet.new(),
      loading: false,
      show_emoji_picker: false,
      recent_emojis: ["👍", "❤️", "😊", "🎉", "👏"]
    )}
  end

  @impl true
  def update(assigns, socket) do
    chat_context = determine_chat_context(assigns)

    conversations = ContextManager.get_contextual_conversations(
      assigns.current_user.id,
      chat_context,
      extract_context_options(assigns)
    )

    unread_count = ContextManager.get_unread_count_by_context(assigns.current_user.id, chat_context)

    if connected?(socket) do
      setup_chat_subscriptions(assigns.current_user.id, chat_context, assigns)
    end

    {:ok, socket
     |> assign(assigns)
     |> assign(:chat_context, chat_context)
     |> assign(:conversations, conversations)
     |> assign(:unread_count, unread_count)}
  end

  # Event handlers remain similar but use your existing Chat functions

  @impl true
  def handle_event("send_message", %{"message" => content}, socket) do
    if String.trim(content) != "" and socket.assigns.active_conversation do
      conversation = socket.assigns.active_conversation

      # Use your existing create_message function
      case Chat.create_message(
        %{"content" => content},
        socket.assigns.current_user,
        conversation
      ) do
        {:ok, message} ->
          updated_conversations = refresh_conversation_list(socket.assigns.conversations, conversation.id)

          {:noreply, socket
           |> assign(:conversations, updated_conversations)
           |> assign(:message_input, "")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to send message")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_emoji_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    case Chat.add_reaction(message_id, socket.assigns.current_user.id, emoji) do
      {:ok, _reaction} ->
        {:noreply, socket}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add reaction")}
    end
  end

  @impl true
  def handle_event("remove_emoji_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    case Chat.remove_reaction(message_id, socket.assigns.current_user.id, emoji) do
      {:ok, _} ->
        {:noreply, socket}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove reaction")}
    end
  end

  @impl true
  def handle_event("toggle_widget", _params, socket) do
    new_state = case socket.assigns.widget_state do
      :minimized -> :expanded
      :expanded -> :minimized
      :fullscreen -> :expanded
    end

    {:noreply, assign(socket, :widget_state, new_state)}
  end

  @impl true
  def handle_event("open_conversation", %{"conversation_id" => conversation_id}, socket) do
    conversation = find_conversation(socket.assigns.conversations, conversation_id)

    {:noreply, socket
     |> assign(:active_conversation, conversation)
     |> assign(:widget_state, :expanded)}
  end

  @impl true
  def handle_event("start_portfolio_feedback", %{"portfolio_id" => portfolio_id}, socket) do
    case ContextManager.create_portfolio_feedback_conversation(
      portfolio_id,
      socket.assigns.current_user.id,
      socket.assigns.current_user.id  # In real app, this would be an expert's ID
    ) do
      {:ok, conversation} ->
        updated_conversations = [conversation | socket.assigns.conversations]

        {:noreply, socket
         |> assign(:conversations, updated_conversations)
         |> assign(:active_conversation, conversation)
         |> assign(:widget_state, :expanded)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start feedback conversation")}
    end
  end

  # Handle real-time updates from your existing PubSub system
  @impl true
  def handle_info({:new_message, message_id}, socket) do
    # Load the full message using your existing system
    message = Repo.get(Chat.Message, message_id) |> Repo.preload(:user)

    updated_conversations = update_conversation_with_new_message(socket.assigns.conversations, message)
    unread_count = calculate_total_unread_count(updated_conversations)

    {:noreply, socket
     |> assign(:conversations, updated_conversations)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def handle_info({:reactions_updated, message_id}, socket) do
    # Refresh the conversation that contains this message
    if socket.assigns.active_conversation do
      conversation = Chat.get_conversation!(socket.assigns.active_conversation.id)
      {:noreply, assign(socket, :active_conversation, conversation)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed bottom-6 right-6 z-50 chat-widget" id="enhanced-chat-widget">
      <%= case @widget_state do %>
        <% :minimized -> %>
          <%= render_minimized_widget(assigns) %>
        <% :expanded -> %>
          <%= render_expanded_widget(assigns) %>
        <% :fullscreen -> %>
          <%= render_fullscreen_widget(assigns) %>
      <% end %>
    </div>
    """
  end

  # Render functions - enhanced with emoji reactions
  defp render_minimized_widget(assigns) do
    ~H"""
    <button
      phx-click="toggle_widget"
      phx-target={@myself}
      class="relative bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700
             text-white rounded-full p-4 shadow-2xl transition-all duration-300 hover:scale-110"
    >
      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
      </svg>

      <%= if @unread_count > 0 do %>
        <div class="absolute -top-2 -right-2 bg-red-500 text-white text-xs rounded-full h-6 w-6 flex items-center justify-center font-bold">
          <%= if @unread_count > 99, do: "99+", else: @unread_count %>
        </div>
      <% end %>

      <div class={["absolute -bottom-1 -left-1 w-4 h-4 rounded-full border-2 border-white", context_color(@chat_context)]}>
      </div>
    </button>
    """
  end

  defp render_expanded_widget(assigns) do
    ~H"""
    <div class="bg-white/95 backdrop-blur-xl rounded-2xl shadow-2xl border border-gray-200/50
                w-96 h-[500px] flex flex-col overflow-hidden">
      <!-- Header -->
      <div class="bg-gradient-to-r from-blue-600 to-purple-600 text-white p-4 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <h3 class="font-semibold">Chat</h3>
          <div class="text-xs bg-white/20 px-2 py-1 rounded-full">
            <%= format_context_name(@chat_context) %>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <button
            phx-click="toggle_widget"
            phx-target={@myself}
            class="p-1 hover:bg-white/20 rounded-lg transition-colors"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4" />
            </svg>
          </button>
        </div>
      </div>

      <%= if @active_conversation do %>
        <%= render_active_conversation(assigns) %>
      <% else %>
        <%= render_conversation_list(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_active_conversation(assigns) do
    ~H"""
    <!-- Conversation Header -->
    <div class="p-4 border-b border-gray-200 bg-gray-50">
      <div class="flex items-center gap-3">
        <button
          phx-click="open_conversation"
          phx-value-conversation_id=""
          phx-target={@myself}
          class="p-1 hover:bg-gray-200 rounded-lg transition-colors"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
        </button>

        <div>
          <h4 class="font-medium text-gray-900">
            <%= @active_conversation.title %>
          </h4>
          <p class="text-xs text-gray-500">
            <%= format_conversation_participants(@active_conversation) %>
          </p>
        </div>
      </div>
    </div>

    <!-- Messages with Reactions -->
    <div class="flex-1 overflow-y-auto p-4 space-y-4" id="chat-messages">
      <%= for message <- @active_conversation.messages || [] do %>
        <div class={[
          "flex",
          message.user_id == @current_user.id && "justify-end" || "justify-start"
        ]}>
          <div class="max-w-xs lg:max-w-md">
            <!-- Message Bubble -->
            <div class={[
              "px-4 py-2 rounded-2xl",
              message.user_id == @current_user.id && "bg-blue-500 text-white" || "bg-gray-200 text-gray-900"
            ]}>
              <%= if message.user_id != @current_user.id do %>
                <p class="text-xs font-medium mb-1"><%= message.user.username %></p>
              <% end %>
              <p class="text-sm"><%= message.content %></p>
              <p class={[
                "text-xs mt-1",
                message.user_id == @current_user.id && "text-blue-100" || "text-gray-500"
              ]}>
                <%= format_message_time(message.inserted_at) %>
              </p>
            </div>

            <!-- Emoji Reactions -->
            <%= if message.reactions && length(message.reactions) > 0 do %>
              <div class="flex gap-1 mt-1 flex-wrap">
                <%= for reaction <- message.reactions do %>
                  <button
                    phx-click={if reaction.user_id == @current_user.id, do: "remove_emoji_reaction", else: "add_emoji_reaction"}
                    phx-value-message_id={message.id}
                    phx-value-emoji={reaction.emoji}
                    phx-target={@myself}
                    class={[
                      "px-2 py-1 rounded-full text-xs border transition-colors",
                      reaction.user_id == @current_user.id && "bg-blue-100 border-blue-300" || "bg-gray-100 border-gray-300"
                    ]}
                  >
                    <%= reaction.emoji %> <%= reaction.count || 1 %>
                  </button>
                <% end %>
              </div>
            <% end %>

            <!-- Quick Reaction Bar -->
            <div class="mt-1 opacity-0 group-hover:opacity-100 transition-opacity">
              <div class="flex gap-1">
                <%= for emoji <- @recent_emojis do %>
                  <button
                    phx-click="add_emoji_reaction"
                    phx-value-message_id={message.id}
                    phx-value-emoji={emoji}
                    phx-target={@myself}
                    class="p-1 hover:bg-gray-100 rounded text-sm"
                  >
                    <%= emoji %>
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>

    <!-- Message Input -->
    <div class="p-4 border-t border-gray-200">
      <div class="flex items-end gap-2">
        <input
          type="text"
          placeholder="Type a message..."
          value={@message_input}
          phx-keyup="update_message_input"
          phx-key="Enter"
          phx-click="send_message"
          phx-target={@myself}
          class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        />
        <button
          phx-click="send_message"
          phx-target={@myself}
          class="p-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  defp render_conversation_list(assigns) do
    ~H"""
    <div class="flex-1 overflow-y-auto">
      <%= if length(@conversations) == 0 do %>
        <div class="p-8 text-center text-gray-500">
          <svg class="w-12 h-12 mx-auto mb-2 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
          </svg>
          <p class="text-sm">No conversations yet</p>
          <p class="text-xs text-gray-400">
            <%= case @chat_context do %>
              <% :portfolio -> %>"Share your portfolio for feedback to start chatting"
              <% :service -> %>"Book a service to start communicating with providers"
              <% :collaboration -> %>"Join a collaboration session to start chatting"
              <% _ -> %>"Start a conversation to begin chatting"
            <% end %>
          </p>
        </div>
      <% else %>
        <%= for conversation <- @conversations do %>
          <button
            phx-click="open_conversation"
            phx-value-conversation_id={conversation.id}
            phx-target={@myself}
            class="w-full p-3 text-left hover:bg-gray-50 border-b border-gray-100 transition-colors group"
          >
            <%= render_conversation_item(Map.put(assigns, :conversation, conversation)) %>
          </button>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_conversation_item(assigns) do
    ~H"""
    <div class="flex items-start gap-3">
      <div class="flex-shrink-0">
        <div class={[
          "w-8 h-8 rounded-full flex items-center justify-center",
          context_bg_color(@conversation.context_type)
        ]}>
          <%= context_icon(assigns, @conversation.context_type) %>
        </div>
      </div>

      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between mb-1">
          <p class="text-sm font-medium text-gray-900 truncate">
            <%= @conversation.title %>
          </p>
          <%= if @conversation.unread_count > 0 do %>
            <div class="bg-blue-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center">
              <%= @conversation.unread_count %>
            </div>
          <% end %>
        </div>

        <p class="text-xs text-gray-500 truncate">
          <%= @conversation.last_message && @conversation.last_message.content || "No messages yet" %>
        </p>

        <p class="text-xs text-gray-400 mt-1">
          <%= @conversation.last_message && format_message_time(@conversation.last_message.inserted_at) || "" %>
        </p>
      </div>
    </div>
    """
  end

  # Helper functions
  defp determine_chat_context(assigns) do
    cond do
      Map.get(assigns, :active_section) == "service_dashboard" -> :service
      Map.get(assigns, :active_section) == "creator_lab" -> :lab
      Map.get(assigns, :active_section) == "community_channels" -> :channel
      Map.get(assigns, :active_section) == "collaboration_hub" -> :collaboration
      Map.has_key?(assigns, :portfolio) and assigns.portfolio -> :portfolio
      Map.has_key?(assigns, :channel) and assigns.channel -> :channel
      true -> :general
    end
  end

  defp extract_context_options(assigns) do
    [
      portfolio_id: Map.get(assigns, :portfolio, %{}) |> Map.get(:id),
      channel_id: Map.get(assigns, :channel, %{}) |> Map.get(:id),
      session_id: Map.get(assigns, :session, %{}) |> Map.get(:id)
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp setup_chat_subscriptions(user_id, context, assigns) do
    PubSub.subscribe(Frestyl.PubSub, "user:#{user_id}:chat")

    case context do
      :channel ->
        if channel_id = get_in(assigns, [:channel, :id]) do
          PubSub.subscribe(Frestyl.PubSub, "channel:#{channel_id}")
        end
      _ ->
        :ok
    end
  end

  defp find_conversation(conversations, conversation_id) do
    Enum.find(conversations, &(&1.id == conversation_id || to_string(&1.id) == conversation_id))
  end

  defp refresh_conversation_list(conversations, conversation_id) do
# In a real implementation, you'd refresh this specific conversation
    # For now, just return the existing list
    conversations
  end

  defp update_conversation_with_new_message(conversations, message) do
    Enum.map(conversations, fn conversation ->
      if conversation.id == message.conversation_id do
        %{conversation |
          last_message: message,
          last_message_at: message.inserted_at,
          unread_count: (conversation.unread_count || 0) + 1
        }
      else
        conversation
      end
    end)
  end

  defp calculate_total_unread_count(conversations) do
    conversations
    |> Enum.map(& &1.unread_count || 0)
    |> Enum.sum()
  end

  defp context_color(:portfolio), do: "bg-orange-500"
  defp context_color(:collaboration), do: "bg-green-500"
  defp context_color(:service), do: "bg-purple-500"
  defp context_color(:channel), do: "bg-indigo-500"
  defp context_color(:lab), do: "bg-pink-500"
  defp context_color(_), do: "bg-blue-500"

  defp context_bg_color(:portfolio), do: "bg-orange-100"
  defp context_bg_color(:collaboration), do: "bg-green-100"
  defp context_bg_color(:service), do: "bg-purple-100"
  defp context_bg_color(:channel), do: "bg-indigo-100"
  defp context_bg_color(:lab), do: "bg-pink-100"
  defp context_bg_color(_), do: "bg-blue-100"

  defp format_context_name(:portfolio), do: "Portfolio"
  defp format_context_name(:collaboration), do: "Collaboration"
  defp format_context_name(:service), do: "Services"
  defp format_context_name(:channel), do: "Channels"
  defp format_context_name(:lab), do: "Creator Lab"
  defp format_context_name(_), do: "General"

  defp format_conversation_participants(conversation) do
    case conversation.type do
      :channel -> "Community channel"
      _ -> "#{length(conversation.participants || [])} participants"
    end
  end

  defp format_message_time(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      diff when diff < 60 -> "now"
      diff when diff < 3600 -> "#{div(diff, 60)}m"
      diff when diff < 86400 -> "#{div(diff, 3600)}h"
      _ -> Calendar.strftime(datetime, "%m/%d")
    end
  end

  defp get_first_message_timestamp([]), do: nil
  defp get_first_message_timestamp([message | _]), do: message.inserted_at

   defp render_fullscreen_widget(assigns) do
    ~H"""
    <div class="fixed inset-4 bg-white/95 backdrop-blur-xl rounded-2xl shadow-2xl border border-gray-200/50
                flex flex-col overflow-hidden z-50">
      <!-- Header -->
      <div class="bg-gradient-to-r from-blue-600 to-purple-600 text-white p-4 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <h3 class="font-semibold text-lg">Chat Center</h3>
          <div class="text-sm bg-white/20 px-3 py-1 rounded-full">
            <%= format_context_name(@chat_context) %>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <button
            phx-click="toggle_widget"
            phx-target={@myself}
            class="p-2 hover:bg-white/20 rounded-lg transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>

      <!-- Fullscreen Layout: Sidebar + Main Chat -->
      <div class="flex-1 flex overflow-hidden">
        <!-- Conversation Sidebar -->
        <div class="w-80 border-r border-gray-200 flex flex-col">
          <!-- Search -->
          <div class="p-4 border-b border-gray-200">
            <input
              type="text"
              placeholder="Search conversations..."
              class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          <!-- Conversation List -->
          <div class="flex-1 overflow-y-auto">
            <%= render_conversation_list(assigns) %>
          </div>
        </div>

        <!-- Main Chat Area -->
        <div class="flex-1 flex flex-col">
          <%= if @active_conversation do %>
            <%= render_active_conversation(assigns) %>
          <% else %>
            <div class="flex-1 flex items-center justify-center text-gray-500">
              <div class="text-center">
                <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                <p class="text-lg font-medium">Select a conversation</p>
                <p class="text-sm">Choose a conversation from the sidebar to start chatting</p>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp context_icon(assigns, :portfolio) do
    ~H"""
    <svg class="w-4 h-4 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
    </svg>
    """
  end

  defp context_icon(assigns, :service) do
    ~H"""
    <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m8 0H8m8 0v10a2 2 0 01-2 2H10a2 2 0 01-2-2V6h8z" />
    </svg>
    """
  end

  defp context_icon(assigns, :collaboration) do
    ~H"""
    <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
    </svg>
    """
  end

  defp context_icon(assigns, :channel) do
    ~H"""
    <svg class="w-4 h-4 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m-9 4h10m-5 10v-6m-4 6h8a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
    </svg>
    """
  end

  defp context_icon(assigns, :lab) do
    ~H"""
    <svg class="w-4 h-4 text-pink-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
    </svg>
    """
  end

  defp context_icon(assigns, _) do
    ~H"""
    <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
    </svg>
    """
  end
end
