# lib/frestyl_web/components/chat_widget.ex
defmodule FrestylWeb.Components.ChatWidget do
  use FrestylWeb, :live_component

  alias Frestyl.Chat
  alias Frestyl.Channels

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :tab, "messages")}
  end

  @impl true
  def update(assigns, socket) do
    user = assigns.current_user
    recent_conversations = Chat.list_user_conversations(user.id) |> Enum.take(3)
    unread_count = Chat.count_unread_messages(user.id)
    recent_channels = Channels.list_user_channels(user) |> Enum.take(3)

    {:ok,
     socket
     |> assign(:recent_conversations, recent_conversations)
     |> assign(:unread_count, unread_count)
     |> assign(:current_user, user)
     |> assign(:recent_channels, recent_channels)}
  end

  @impl true
  def handle_event("tab_select", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold text-gray-900">Communication</h3>
        <.link navigate="/chat" class="text-sm text-primary-600 hover:text-primary-700">
          View all
        </.link>
      </div>

      <!-- Tabs for Direct Messages and Channels -->
      <div class="border-b border-gray-200 mb-4">
        <nav class="flex space-x-8">
          <button
            phx-click="tab_select"
            phx-value-tab="messages"
            phx-target={@myself}
            class={[
              "py-4 px-1 border-b-2 font-medium text-sm",
              if(assigns[:tab] == "messages", do: "border-[#DD1155] text-[#DD1155]", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
            ]}
          >
            Messages
          </button>
          <button
            phx-click="tab_select"
            phx-value-tab="channels"
            phx-target={@myself}
            class={[
              "py-4 px-1 border-b-2 font-medium text-sm",
              if(assigns[:tab] == "channels", do: "border-[#DD1155] text-[#DD1155]", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
            ]}
          >
            Channels
          </button>
        </nav>
      </div>

      <%= if @unread_count > 0 do %>
        <div class="mb-4 rounded-lg bg-primary-50 border border-primary-200 p-3">
          <p class="text-sm text-primary-700">
            You have <%= @unread_count %> unread <%= Elixir.Inflex.inflect("message", @unread_count) %>
          </p>
        </div>
      <% end %>

      <div class="space-y-3">
        <%= if assigns[:tab] == "messages" do %>
          <%= if Enum.empty?(@recent_conversations) do %>
            <p class="text-sm text-gray-500 text-center py-4">No recent conversations</p>
          <% else %>
            <%= for conversation <- @recent_conversations do %>
              <.link
                navigate={"/chat/#{conversation.id}"}
                class="block hover:bg-gray-50 rounded-lg p-3 transition-colors"
              >
                <div class="flex items-center">
                  <div class="h-8 w-8 rounded-full bg-primary-500 flex items-center justify-center text-white text-sm">
                    <%= String.first(conversation.title || "U") %>
                  </div>
                  <div class="ml-3 flex-1 min-w-0">
                    <p class="text-sm font-medium text-gray-900 truncate">
                      <%= conversation.title || "Unnamed" %>
                    </p>
                    <%= if conversation.last_message do %>
                      <p class="text-sm text-gray-500 truncate">
                        <%= String.slice(conversation.last_message.content, 0..30) %>
                      </p>
                    <% end %>
                  </div>
                </div>
              </.link>
            <% end %>
          <% end %>
        <% else %>
          <%= if Enum.empty?(@recent_channels) do %>
            <p class="text-sm text-gray-500 text-center py-4">No recent channels</p>
          <% else %>
            <%= for channel <- @recent_channels do %>
              <.link
                navigate={"/channels/#{channel.id}"}
                class="block hover:bg-gray-50 rounded-lg p-3 transition-colors"
              >
                <div class="flex items-center">
                  <div class="h-8 w-8 rounded-full bg-[#DD1155] flex items-center justify-center text-white text-sm">
                    #
                  </div>
                  <div class="ml-3 flex-1 min-w-0">
                    <p class="text-sm font-medium text-gray-900 truncate">
                      # <%= channel.name %>
                    </p>
                    <p class="text-sm text-gray-500 truncate">
                      <%= String.slice(channel.description || "", 0..30) %>
                    </p>
                  </div>
                </div>
              </.link>
            <% end %>
          <% end %>
        <% end %>
      </div>

      <div class="mt-6 flex space-x-2">
        <.button navigate="/chat" class="flex-1 bg-primary-500 text-white">
          Open Chat
        </.button>
        <.button navigate="/channels" class="flex-1 bg-[#DD1155] text-white">
          Channels
        </.button>
      </div>
    </div>
    """
  end
end
