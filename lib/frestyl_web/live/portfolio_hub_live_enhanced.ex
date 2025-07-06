# lib/frestyl_web/live/portfolio_hub_live_enhanced.ex

defmodule FrestylWeb.PortfolioHubLiveEnhanced do
  @moduledoc """
  Enhanced Portfolio Hub with integrated contextual chat system
  """

  use FrestylWeb, :live_view
  alias Frestyl.{Chat, Notifications}
  alias FrestylWeb.{ChatWidgetComponent, NotificationCenterComponent}

  @impl true
  def mount(params, session, socket) do
    # Call original mount function
    {:ok, socket} = FrestylWeb.PortfolioHubLive.mount(params, session, socket)

    # Add chat-specific assignments
    socket = socket
    |> assign(:show_chat_widget, true)
    |> assign(:chat_conversations, [])
    |> assign(:active_chat_conversation, nil)
    |> assign(:chat_context, determine_initial_chat_context(params))
    |> assign(:unread_chat_count, 0)
    |> assign(:notifications, [])
    |> assign(:show_notification_center, false)

    # Load initial chat data
    if connected?(socket) do
      setup_chat_subscriptions(socket.assigns.current_user.id)
      load_initial_chat_data(socket)
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, uri, socket) do
    # Call original handle_params
    {:noreply, socket} = FrestylWeb.PortfolioHubLive.handle_params(params, uri, socket)

    # Update chat context based on new route
    new_chat_context = determine_chat_context_from_params(params)

    socket = if new_chat_context != socket.assigns.chat_context do
      load_contextual_conversations(socket, new_chat_context)
    else
      socket
    end

    {:noreply, assign(socket, :chat_context, new_chat_context)}
  end

  @impl true
  def handle_event("toggle_chat_widget", _params, socket) do
    {:noreply, assign(socket, :show_chat_widget, !socket.assigns.show_chat_widget)}
  end

  @impl true
  def handle_event("open_chat_conversation", %{"conversation_id" => conversation_id}, socket) do
    conversation = Enum.find(socket.assigns.chat_conversations, &(&1.id == conversation_id))

    socket = socket
    |> assign(:active_chat_conversation, conversation)
    |> assign(:show_chat_widget, true)

    # Mark conversation as read
    if conversation do
      Chat.mark_conversation_read(conversation.id, socket.assigns.current_user.id)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_portfolio_feedback_chat", %{"portfolio_id" => portfolio_id}, socket) do
    case Chat.create_portfolio_feedback_conversation(
      portfolio_id,
      socket.assigns.current_user.id,
      socket.assigns.current_user.id  # For now, same user - in real app this would be an expert
    ) do
      {:ok, conversation} ->
        updated_conversations = [conversation | socket.assigns.chat_conversations]

        {:noreply, socket
         |> assign(:chat_conversations, updated_conversations)
         |> assign(:active_chat_conversation, conversation)
         |> assign(:show_chat_widget, true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start feedback conversation")}
    end
  end

  @impl true
  def handle_event("start_collaboration_request", %{"portfolio_id" => portfolio_id}, socket) do
    # This would typically be called when viewing someone else's portfolio
    portfolio = socket.assigns.portfolios |> Enum.find(&(&1.id == portfolio_id))

    if portfolio && portfolio.user_id != socket.assigns.current_user.id do
      case Chat.find_or_create_conversation(
        [socket.assigns.current_user.id, portfolio.user_id],
        :portfolio,
        portfolio_id,
        %{title: "Collaboration Request", metadata: %{type: "collaboration_request"}}
      ) do
        {:ok, conversation} ->
          # Send initial collaboration request message
          Chat.send_message(
            conversation.id,
            socket.assigns.current_user.id,
            "Hi! I'd love to collaborate on your portfolio project. Let me know if you're interested!"
          )

          # Notify portfolio owner
          Notifications.notify_collaboration_request(portfolio.user_id, socket.assigns.current_user, portfolio)

          updated_conversations = [conversation | socket.assigns.chat_conversations]

          {:noreply, socket
           |> assign(:chat_conversations, updated_conversations)
           |> assign(:active_chat_conversation, conversation)
           |> assign(:show_chat_widget, true)
           |> put_flash(:info, "Collaboration request sent!")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to send collaboration request")}
      end
    else
      {:noreply, put_flash(socket, :error, "Cannot collaborate with yourself")}
    end
  end

  @impl true
  def handle_event("quick_chat_reply", %{"conversation_id" => conversation_id, "message" => message}, socket) do
    case Chat.send_message(conversation_id, socket.assigns.current_user.id, message) do
      {:ok, _message} ->
        # Update conversation in local state
        updated_conversations = refresh_conversation_in_list(socket.assigns.chat_conversations, conversation_id)

        {:noreply, assign(socket, :chat_conversations, updated_conversations)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  # Handle chat widget events by delegating to the component
  @impl true
  def handle_event("chat_" <> _event = full_event, params, socket) do
    # Extract the actual event name
    event = String.replace_prefix(full_event, "chat_", "")

    # Send to chat widget component
    send_update(ChatWidgetComponent, id: "main-chat-widget", event: event, params: params)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:open_chat_conversation, conversation_id}, socket) do
    # Handle opening chat from notification center
    conversation = Enum.find(socket.assigns.chat_conversations, &(&1.id == conversation_id))

    socket = socket
    |> assign(:active_chat_conversation, conversation)
    |> assign(:show_chat_widget, true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    # Update conversation list with new message
    updated_conversations = update_conversation_with_message(socket.assigns.chat_conversations, message)
    unread_count = calculate_total_unread_count(updated_conversations)

    {:noreply, socket
     |> assign(:chat_conversations, updated_conversations)
     |> assign(:unread_chat_count, unread_count)}
  end

  @impl true
  def handle_info({:conversation_updated, conversation}, socket) do
    # Update specific conversation in the list
    updated_conversations = update_conversation_in_list(socket.assigns.chat_conversations, conversation)

    {:noreply, assign(socket, :chat_conversations, updated_conversations)}
  end

  # Delegate other events to the original PortfolioHubLive
  @impl true
  def handle_event(event, params, socket) do
    FrestylWeb.PortfolioHubLive.handle_event(event, params, socket)
  end

  @impl true
  def handle_info(message, socket) do
    FrestylWeb.PortfolioHubLive.handle_info(message, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Enhanced Navigation with Chat Integration -->
      <nav class="bg-white shadow-sm border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between h-16">
            <!-- Left side - existing navigation -->
            <div class="flex items-center">
              <!-- Your existing navigation items -->
            </div>

            <!-- Right side - enhanced with chat notifications -->
            <div class="flex items-center gap-4">
              <!-- Notification Center -->
              <.live_component
                module={NotificationCenterComponent}
                id="notification-center"
                current_user={@current_user}
              />

              <!-- Chat Status Indicator -->
              <div class="relative">
                <button
                  phx-click="toggle_chat_widget"
                  class="p-2 text-gray-600 hover:text-gray-900 transition-colors relative"
                  title="Toggle chat"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                          d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                  </svg>

                  <%= if @unread_chat_count > 0 do %>
                    <div class="absolute -top-1 -right-1 bg-blue-500 text-white text-xs rounded-full h-4 w-4 flex items-center justify-center">
                      <%= @unread_chat_count %>
                    </div>
                  <% end %>

                  <!-- Context indicator -->
                  <div class={[
                    "absolute -bottom-1 -left-1 w-2 h-2 rounded-full border border-white",
                    chat_context_color(@chat_context)
                  ]}></div>
                </button>
              </div>

              <!-- User menu -->
              <!-- Your existing user menu -->
            </div>
          </div>
        </div>
      </nav>

      <!-- Main Content with Chat Integration -->
      <main class="relative">
        <!-- Original Portfolio Hub Content -->
        <%= FrestylWeb.PortfolioHubLive.render(assigns) %>

        <!-- Context-Aware Chat Actions -->
        <div class="fixed bottom-20 left-6 z-40">
          <%= render_contextual_chat_actions(assigns) %>
        </div>

        <!-- Chat Widget -->
        <%= if @show_chat_widget do %>
          <.live_component
            module={ChatWidgetComponent}
            id="main-chat-widget"
            current_user={@current_user}
            conversations={@chat_conversations}
            active_conversation={@active_chat_conversation}
            chat_context={@chat_context}
            active_section={@active_section}
            portfolio={assigns[:portfolio]}
            session={assigns[:session]}
            channel={assigns[:channel]}
          />
        <% end %>
      </main>
    </div>
    """
  end

  # Context-aware chat action buttons
  defp render_contextual_chat_actions(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= case @active_section do %>
        <% "portfolio_studio" -> %>
          <%= if @portfolio do %>
            <button
              phx-click="start_portfolio_feedback_chat"
              phx-value-portfolio_id={@portfolio.id}
              class="bg-orange-500 hover:bg-orange-600 text-white p-3 rounded-full shadow-lg transition-all duration-300 flex items-center gap-2"
              title="Get portfolio feedback"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10m0 0V6a2 2 0 00-2-2H9a2 2 0 00-2 2v2m10 0v10a2 2 0 01-2 2H9a2 2 0 01-2-2V8m10 0H7m4 10.93l-3.72-3.72a.75.75 0 00-1.06 0L4 17.44" />
              </svg>
              <span class="text-sm hidden lg:block">Get Feedback</span>
            </button>

            <button
              phx-click="start_collaboration_request"
              phx-value-portfolio_id={@portfolio.id}
              class="bg-green-500 hover:bg-green-600 text-white p-3 rounded-full shadow-lg transition-all duration-300 flex items-center gap-2"
              title="Request collaboration"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
              <span class="text-sm hidden lg:block">Collaborate</span>
            </button>
          <% end %>

        <% "service_dashboard" -> %>
          <button
            phx-click="open_service_support_chat"
            class="bg-purple-500 hover:bg-purple-600 text-white p-3 rounded-full shadow-lg transition-all duration-300 flex items-center gap-2"
            title="Contact support"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192L5.636 18.364M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z" />
            </svg>
            <span class="text-sm hidden lg:block">Support</span>
          </button>

        <% "creator_lab" -> %>
          <button
            phx-click="open_ai_assistant_chat"
            class="bg-pink-500 hover:bg-pink-600 text-white p-3 rounded-full shadow-lg transition-all duration-300 flex items-center gap-2"
            title="AI Assistant"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
            </svg>
            <span class="text-sm hidden lg:block">AI Assistant</span>
          </button>

        <% "community_channels" -> %>
          <button
            phx-click="join_community_discussion"
            class="bg-indigo-500 hover:bg-indigo-600 text-white p-3 rounded-full shadow-lg transition-all duration-300 flex items-center gap-2"
            title="Join discussion"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a1.994 1.994 0 01-1.414-.586m0 0L11 14h4a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2v4l.586-.586z" />
            </svg>
            <span class="text-sm hidden lg:block">Join Chat</span>
          </button>

        <% _ -> %>
          <!-- Default action - open general chat -->
          <button
            phx-click="toggle_chat_widget"
            class="bg-blue-500 hover:bg-blue-600 text-white p-3 rounded-full shadow-lg transition-all duration-300 flex items-center gap-2"
            title="Open chat"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
            <span class="text-sm hidden lg:block">Chat</span>
          </button>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp determine_initial_chat_context(params) do
    cond do
      Map.has_key?(params, "portfolio_id") -> :portfolio
      Map.has_key?(params, "session_id") -> :collaboration
      Map.has_key?(params, "channel_id") -> :channel
      true -> :general
    end
  end

  defp determine_chat_context_from_params(params) do
    cond do
      Map.get(params, "section") == "service_dashboard" -> :service
      Map.get(params, "section") == "creator_lab" -> :lab
      Map.get(params, "section") == "community_channels" -> :channel
      Map.get(params, "section") == "collaboration_hub" -> :collaboration
      Map.has_key?(params, "portfolio_id") -> :portfolio
      true -> :general
    end
  end

  defp setup_chat_subscriptions(user_id) do
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{user_id}:chat")
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{user_id}:notifications")
  end

  defp load_initial_chat_data(socket) do
    user_id = socket.assigns.current_user.id
    context = socket.assigns.chat_context

    # Load conversations for current context
    conversations = Chat.get_contextual_conversations(user_id, context)
    unread_count = calculate_total_unread_count(conversations)

    {:ok, socket
     |> assign(:chat_conversations, conversations)
     |> assign(:unread_chat_count, unread_count)}
  end

  defp load_contextual_conversations(socket, new_context) do
    user_id = socket.assigns.current_user.id
    conversations = Chat.get_contextual_conversations(user_id, new_context)
    unread_count = calculate_total_unread_count(conversations)

    socket
    |> assign(:chat_conversations, conversations)
    |> assign(:unread_chat_count, unread_count)
    |> assign(:active_chat_conversation, nil)  # Clear active conversation when switching contexts
  end

  defp calculate_total_unread_count(conversations) do
    conversations
    |> Enum.map(& &1.unread_count || 0)
    |> Enum.sum()
  end

  defp update_conversation_with_message(conversations, message) do
    Enum.map(conversations, fn conversation ->
      if conversation.id == message.conversation_id do
        # Update last message and potentially unread count
        %{conversation |
          last_message: message,
          last_message_at: message.inserted_at,
          unread_count: if(message.user_id != conversation.current_user_id, do: (conversation.unread_count || 0) + 1, else: conversation.unread_count || 0)
        }
      else
        conversation
      end
    end)
  end

  defp update_conversation_in_list(conversations, updated_conversation) do
    Enum.map(conversations, fn conversation ->
      if conversation.id == updated_conversation.id do
        updated_conversation
      else
        conversation
      end
    end)
  end

  defp refresh_conversation_in_list(conversations, conversation_id) do
    # In a real implementation, you might want to refetch the conversation from the database
    # For now, just return the existing list
    conversations
  end

  defp chat_context_color(:portfolio), do: "bg-orange-500"
  defp chat_context_color(:collaboration), do: "bg-green-500"
  defp chat_context_color(:service), do: "bg-purple-500"
  defp chat_context_color(:channel), do: "bg-indigo-500"
  defp chat_context_color(:lab), do: "bg-pink-500"
  defp chat_context_color(_), do: "bg-blue-500"
end


# ============================================================================


# lib/frestyl_web/live/components/chat_moderation_component.ex

defmodule FrestylWeb.ChatModerationComponent do
  @moduledoc """
  Chat moderation features for different contexts
  """

  use FrestylWeb, :live_component
  alias Frestyl.Chat.Moderation

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      moderation_enabled: true,
      content_filters: [],
      user_restrictions: %{},
      reported_messages: []
    )}
  end

  @impl true
  def update(assigns, socket) do
    # Load moderation settings based on context
    moderation_settings = load_moderation_settings(assigns.chat_context, assigns.current_user)

    {:ok, socket
     |> assign(assigns)
     |> assign(:moderation_settings, moderation_settings)}
  end

  @impl true
  def handle_event("report_message", %{"message_id" => message_id, "reason" => reason}, socket) do
    case Moderation.report_message(message_id, socket.assigns.current_user.id, reason) do
      {:ok, report} ->
        {:noreply, socket
         |> put_flash(:info, "Message reported successfully")
         |> assign(:reported_messages, [report | socket.assigns.reported_messages])}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to report message")}
    end
  end

  @impl true
  def handle_event("block_user", %{"user_id" => user_id}, socket) do
    case Moderation.block_user(socket.assigns.current_user.id, user_id) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "User blocked successfully")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to block user")}
    end
  end

  @impl true
  def handle_event("mute_conversation", %{"conversation_id" => conversation_id}, socket) do
    case Moderation.mute_conversation(conversation_id, socket.assigns.current_user.id) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Conversation muted")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to mute conversation")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chat-moderation-controls">
      <!-- Moderation controls would be rendered here -->
      <!-- This component would be integrated into message displays -->
    </div>
    """
  end

  defp load_moderation_settings(context, user) do
    # Load context-specific moderation settings
    %{
      auto_moderation: context in [:service, :lab],
      profanity_filter: true,
      spam_detection: true,
      user_reporting: true,
      admin_controls: user_has_admin_privileges?(user, context)
    }
  end

  defp user_has_admin_privileges?(user, context) do
    # Check if user has moderation privileges in this context
    case context do
      :service -> user.subscription_tier in ["creator", "pro"]
      :lab -> user.subscription_tier in ["creator", "pro"]
      _ -> false
    end
  end
end


# ============================================================================


# lib/frestyl/chat/moderation.ex

defmodule Frestyl.Chat.Moderation do
  @moduledoc """
  Chat moderation functionality
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Chat.{MessageReport, UserBlock, ConversationMute}

  @doc """
  Reports a message for moderation review
  """
  def report_message(message_id, reporter_id, reason) do
    %MessageReport{}
    |> MessageReport.changeset(%{
      message_id: message_id,
      reporter_id: reporter_id,
      reason: reason,
      status: "pending"
    })
    |> Repo.insert()
  end

  @doc """
  Blocks a user from contacting another user
  """
  def block_user(blocker_id, blocked_id) do
    %UserBlock{}
    |> UserBlock.changeset(%{
      blocker_id: blocker_id,
      blocked_id: blocked_id
    })
    |> Repo.insert()
  end

  @doc """
  Mutes a conversation for a specific user
  """
  def mute_conversation(conversation_id, user_id) do
    %ConversationMute{}
    |> ConversationMute.changeset(%{
      conversation_id: conversation_id,
      user_id: user_id,
      muted_until: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second)  # 24 hours default
    })
    |> Repo.insert()
  end

  @doc """
  Checks if content should be filtered
  """
  def moderate_content(content, context \\ :general) do
    with :ok <- check_profanity(content),
         :ok <- check_spam(content),
         :ok <- check_context_rules(content, context) do
      {:ok, content}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_profanity(content) do
    # Simple profanity check - in production, use a proper service
    prohibited_words = ["spam", "scam", "fake"]  # Example list

    if Enum.any?(prohibited_words, &String.contains?(String.downcase(content), &1)) do
      {:error, "Content contains prohibited language"}
    else
      :ok
    end
  end

  defp check_spam(content) do
    # Basic spam detection
    cond do
      String.length(content) > 2000 -> {:error, "Message too long"}
      Regex.match?(~r/http[s]?:\/\/.*\..*/, content) -> check_link_safety(content)
      true -> :ok
    end
  end

  defp check_link_safety(content) do
    # In production, verify links against safe domains
    :ok
  end

  defp check_context_rules(content, context) do
    case context do
      :service -> check_professional_language(content)
      :lab -> check_technical_appropriateness(content)
      _ -> :ok
    end
  end

  defp check_professional_language(_content) do
    # Check for professional communication standards
    :ok
  end

  defp check_technical_appropriateness(_content) do
    # Check for appropriate technical discussion
    :ok
  end
end
