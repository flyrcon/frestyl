# Create lib/frestyl_web/live/broadcast_live/show.ex
defmodule FrestylWeb.BroadcastLive.Show do
  use FrestylWeb, :live_view
  alias Frestyl.Sessions

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    broadcast_id = String.to_integer(id)
    broadcast = Sessions.get_session_with_details!(broadcast_id)
    current_user = socket.assigns.current_user

    is_host = broadcast.host_id == current_user.id

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "broadcast:#{broadcast_id}")

      # Track presence
      if function_exported?(Frestyl.Presence, :track_user, 4) do
        Frestyl.Presence.track_user(self(), "broadcast:#{broadcast_id}", current_user.id, %{
          online_at: DateTime.utc_now(),
          role: if(is_host, do: "host", else: "viewer")
        })
      end
    end

    participants = Sessions.list_session_participants(broadcast_id)
    participant_count = length(participants)

    # Initial statistics
    waiting_count = Enum.count(participants, &(&1.joined_at == nil))
    active_count = Enum.count(participants, &(&1.joined_at != nil && &1.left_at == nil))
    left_count = Enum.count(participants, &(&1.left_at != nil))

    audience_stats = %{
      waiting: waiting_count,
      active: active_count,
      left: left_count,
      total: participant_count
    }

    socket = socket
      |> assign(:broadcast, broadcast)
      |> assign(:is_host, is_host)
      |> assign(:participant_count, participant_count)
      |> assign(:audience_stats, audience_stats)
      |> assign(:current_tab, "stream")
      |> assign(:stream_started, broadcast.status == "active")
      |> assign(:chat_enabled, true)
      |> assign(:reactions_enabled, true)
      |> assign(:muted_users, [])
      |> assign(:blocked_users, [])
      |> assign(:current_quality, "auto")
      |> assign(:audio_only, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_stream", _params, socket) do
    if socket.assigns.is_host do
      broadcast_id = socket.assigns.broadcast.id

      case Sessions.update_session(socket.assigns.broadcast, %{status: "active"}) do
        {:ok, updated_broadcast} ->
          # Broadcast stream start event
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "broadcast:#{broadcast_id}",
            {:stream_started}
          )

          {:noreply,
           socket
           |> assign(:broadcast, updated_broadcast)
           |> assign(:stream_started, true)}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to start the stream")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("end_stream", _params, socket) do
    if socket.assigns.is_host do
      broadcast_id = socket.assigns.broadcast.id

      case Sessions.update_session(socket.assigns.broadcast, %{
        status: "ended",
        ended_at: DateTime.utc_now()
      }) do
        {:ok, updated_broadcast} ->
          # Broadcast stream end event
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "broadcast:#{broadcast_id}",
            {:stream_ended}
          )

          {:noreply,
           socket
           |> assign(:broadcast, updated_broadcast)
           |> assign(:stream_started, false)}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to end the stream")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :current_tab, tab)}
  end

  @impl true
  def handle_event("set_quality", %{"quality" => quality}, socket) do
    {:noreply, assign(socket, :current_quality, quality)}
  end

  @impl true
  def handle_event("toggle_audio_only", _params, socket) do
    {:noreply, assign(socket, :audio_only, !socket.assigns.audio_only)}
  end

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    if socket.assigns.is_host do
      new_state = !socket.assigns.chat_enabled

      # Broadcast the chat state change to all participants
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "broadcast:#{socket.assigns.broadcast.id}",
        {:chat_state_changed, new_state}
      )

      {:noreply, assign(socket, :chat_enabled, new_state)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_reactions", _params, socket) do
    if socket.assigns.is_host do
      new_state = !socket.assigns.reactions_enabled

      # Broadcast the reactions state change to all participants
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "broadcast:#{socket.assigns.broadcast.id}",
        {:reactions_state_changed, new_state}
      )

      {:noreply, assign(socket, :reactions_enabled, new_state)}
    else
      {:noreply, socket}
    end
  end

  # Also add this to handle tab changes if not already present:
  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :current_tab, tab)}
  end

  # And make sure you have these handle_info handlers for chat events:
  @impl true
  def handle_info({:chat_state_changed, enabled}, socket) do
    {:noreply, assign(socket, :chat_enabled, enabled)}
  end

  @impl true
  def handle_info({:reactions_state_changed, enabled}, socket) do
    {:noreply, assign(socket, :reactions_enabled, enabled)}
  end

  @impl true
  def handle_info({:stream_started}, socket) do
    {:noreply, assign(socket, :stream_started, true)}
  end

  @impl true
  def handle_info({:stream_ended}, socket) do
    {:noreply, assign(socket, :stream_started, false)}
  end

  @impl true
  def handle_info({:user_joined, user_id}, socket) do
    # Update audience stats
    stats = socket.assigns.audience_stats
    new_stats = %{stats | active: stats.active + 1, waiting: stats.waiting - 1}

    {:noreply, assign(socket, :audience_stats, new_stats)}
  end

  @impl true
  def handle_info({:user_left, user_id}, socket) do
    # Update audience stats
    stats = socket.assigns.audience_stats
    new_stats = %{stats | active: stats.active - 1, left: stats.left + 1}

    {:noreply, assign(socket, :audience_stats, new_stats)}
  end

  @impl true
  def handle_info({:chat_state_changed, enabled}, socket) do
    {:noreply, assign(socket, :chat_enabled, enabled)}
  end

  @impl true
  def handle_info({:reactions_state_changed, enabled}, socket) do
    {:noreply, assign(socket, :reactions_enabled, enabled)}
  end

  @impl true
  def handle_info({:user_muted, user_id}, socket) do
    {:noreply, assign(socket, :muted_users, [user_id | socket.assigns.muted_users])}
  end

  @impl true
  def handle_info({:user_unmuted, user_id}, socket) do
    muted_users = Enum.reject(socket.assigns.muted_users, &(&1 == user_id))
    {:noreply, assign(socket, :muted_users, muted_users)}
  end

  @impl true
  def handle_info({:user_blocked, user_id}, socket) do
    {:noreply, assign(socket, :blocked_users, [user_id | socket.assigns.blocked_users])}
  end

  @impl true
  def handle_info({:user_unblocked, user_id}, socket) do
    blocked_users = Enum.reject(socket.assigns.blocked_users, &(&1 == user_id))
    {:noreply, assign(socket, :blocked_users, blocked_users)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    broadcast_id = socket.assigns.broadcast.id

    # Get current audience statistics
    participants = Sessions.list_session_participants(broadcast_id)
    participant_count = length(participants)

    # Updated statistics
    waiting_count = Enum.count(participants, &(&1.joined_at == nil))
    active_count = Enum.count(participants, &(&1.joined_at != nil && &1.left_at == nil))
    left_count = Enum.count(participants, &(&1.left_at != nil))

    audience_stats = %{
      waiting: waiting_count,
      active: active_count,
      left: left_count,
      total: participant_count
    }

    {:noreply,
     socket
     |> assign(:participant_count, participant_count)
     |> assign(:audience_stats, audience_stats)}
  end

  @impl true
  def handle_info({:chat_state_changed, enabled}, socket) do
    {:noreply, assign(socket, :chat_enabled, enabled)}
  end

  @impl true
  def handle_info({:reactions_state_changed, enabled}, socket) do
    {:noreply, assign(socket, :reactions_enabled, enabled)}
  end

  # ... existing functions (mount, handle_event, handle_info) ...

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen bg-gray-900 text-white flex flex-col">
      <!-- Top Navigation Bar -->
      <div class="bg-gray-800 border-b border-gray-700 px-4 py-3">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <!-- Back to Channel Button -->
            <.link
              navigate={~p"/channels/#{@broadcast.channel_id}"}
              class="text-gray-400 hover:text-white"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
            </.link>

            <!-- Broadcast Info -->
            <div>
              <h1 class="text-lg font-semibold"><%= @broadcast.title %></h1>
              <div class="flex items-center space-x-2 text-sm text-gray-400">
                <span class={[
                  "flex items-center",
                  @stream_started && "text-green-400" || "text-yellow-400"
                ]}>
                  <div class={[
                    "w-2 h-2 rounded-full mr-2",
                    @stream_started && "bg-green-400" || "bg-yellow-400"
                  ]}></div>
                  <%= if @stream_started, do: "LIVE", else: "WAITING" %>
                </span>
                <span>•</span>
                <span><%= @participant_count %> viewers</span>
              </div>
            </div>
          </div>

          <!-- Host Controls -->
          <%= if @is_host do %>
            <div class="flex items-center space-x-3">
              <%= if @stream_started do %>
                <button
                  phx-click="end_stream"
                  class="bg-red-600 hover:bg-red-700 px-4 py-2 rounded-md text-sm font-medium"
                >
                  End Stream
                </button>
              <% else %>
                <button
                  phx-click="start_stream"
                  class="bg-green-600 hover:bg-green-700 px-4 py-2 rounded-md text-sm font-medium"
                >
                  Start Stream
                </button>
              <% end %>

              <!-- Settings Button -->
              <button class="text-gray-400 hover:text-white">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <div class="flex-1 flex">
        <!-- Main Content Area -->
        <div class="flex-1 flex flex-col">
          <!-- Tab Navigation -->
          <div class="bg-gray-800 border-b border-gray-700">
            <nav class="flex space-x-8 px-4" aria-label="Tabs">
              <button
                phx-click="change_tab"
                phx-value-tab="stream"
                class={[
                  "py-2 px-1 border-b-2 font-medium text-sm",
                  @current_tab == "stream" && "border-indigo-500 text-indigo-400" || "border-transparent text-gray-400 hover:text-gray-300"
                ]}
              >
                Stream
              </button>
              <button
                phx-click="change_tab"
                phx-value-tab="chat"
                class={[
                  "py-2 px-1 border-b-2 font-medium text-sm",
                  @current_tab == "chat" && "border-indigo-500 text-indigo-400" || "border-transparent text-gray-400 hover:text-gray-300"
                ]}
              >
                Chat
              </button>
              <%= if @is_host do %>
                <button
                  phx-click="change_tab"
                  phx-value-tab="audience"
                  class={[
                    "py-2 px-1 border-b-2 font-medium text-sm",
                    @current_tab == "audience" && "border-indigo-500 text-indigo-400" || "border-transparent text-gray-400 hover:text-gray-300"
                  ]}
                >
                  Audience
                </button>
              <% end %>
            </nav>
          </div>

          <!-- Tab Content -->
          <div class="flex-1 p-4">
            <%= case @current_tab do %>
              <% "stream" -> %>
                <div class="h-full">
                  <%= if @stream_started do %>
                    <!-- Video/Audio Stream Area -->
                    <div class="bg-black rounded-lg aspect-video w-full max-w-4xl mx-auto">
                      <div class="h-full flex items-center justify-center">
                        <!-- This would be replaced with actual video stream -->
                        <div class="text-center">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-gray-600 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                          </svg>
                          <p class="text-gray-400">Stream Active</p>
                        </div>
                      </div>
                    </div>

                    <!-- Stream Controls -->
                    <div class="mt-4 bg-gray-800 rounded-lg p-4">
                      <div class="flex items-center justify-between">
                        <div class="flex items-center space-x-4">
                          <!-- Quality Selector -->
                          <div class="flex items-center space-x-2">
                            <label class="text-sm text-gray-400">Quality:</label>
                            <select
                              phx-change="set_quality"
                              class="bg-gray-700 border border-gray-600 rounded px-2 py-1 text-sm"
                            >
                              <option value="auto" selected={@current_quality == "auto"}>Auto</option>
                              <option value="1080p" selected={@current_quality == "1080p"}>1080p</option>
                              <option value="720p" selected={@current_quality == "720p"}>720p</option>
                              <option value="480p" selected={@current_quality == "480p"}>480p</option>
                            </select>
                          </div>

                          <!-- Audio Only Toggle -->
                          <button
                            phx-click="toggle_audio_only"
                            class={[
                              "flex items-center space-x-2 px-3 py-1 rounded text-sm",
                              @audio_only && "bg-indigo-600 text-white" || "bg-gray-700 text-gray-300 hover:bg-gray-600"
                            ]}
                          >
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                            </svg>
                            <span>Audio Only</span>
                          </button>
                        </div>

                        <!-- Volume Control -->
                        <div class="flex items-center space-x-2">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5 12V8.5a1.5 1.5 0 011.5-1.5H8l4-4v11l-4-4H6.5A1.5 1.5 0 015 15.5V12z" />
                          </svg>
                          <input type="range" min="0" max="100" value="80" class="w-20 h-2 bg-gray-700 rounded-lg appearance-none cursor-pointer">
                        </div>
                      </div>
                    </div>
                  <% else %>
                    <!-- Stream Not Started -->
                    <div class="h-full bg-gray-800 rounded-lg flex items-center justify-center">
                      <div class="text-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-gray-600 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                        </svg>
                        <h3 class="text-lg font-medium mb-2">Waiting for Stream to Start</h3>
                        <p class="text-gray-400 mb-4">The host will begin the broadcast shortly.</p>
                        <div class="flex items-center justify-center space-x-1">
                          <div class="w-2 h-2 bg-gray-500 rounded-full animate-pulse"></div>
                          <div class="w-2 h-2 bg-gray-500 rounded-full animate-pulse" style="animation-delay: 0.1s"></div>
                          <div class="w-2 h-2 bg-gray-500 rounded-full animate-pulse" style="animation-delay: 0.2s"></div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>

              <% "chat" -> %>
                <!-- Chat Component -->
                <div class="h-full bg-gray-800 rounded-lg">
                  <%= if @chat_enabled do %>
                    <.live_component
                      module={FrestylWeb.ChatLive.ChatComponent}
                      id="broadcast-chat"
                      broadcast_id={@broadcast.id}
                      current_user={assigns[:current_user]}
                      muted_users={@muted_users}
                    />
                  <% else %>
                    <div class="h-full flex items-center justify-center">
                      <div class="text-center text-gray-400">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10m0 0V6a2 2 0 00-2-2H9a2 2 0 00-2 2v2m10 0v10a2 2 0 01-2 2H9a2 2 0 01-2-2V8m0 0V6a2 2 0 012-2h6a2 2 0 012 2v2" />
                        </svg>
                        <p>Chat has been disabled by the host</p>
                      </div>
                    </div>
                  <% end %>
                </div>

              <% "audience" -> %>
                <!-- Audience Controls (Host Only) -->
                <%= if @is_host do %>
                  <.live_component
                    module={FrestylWeb.BroadcastLive.AudienceControlsComponent}
                    id="audience-controls"
                    broadcast={@broadcast}
                    broadcast_id={@broadcast.id}
                    audience_stats={@audience_stats}
                    muted_users={@muted_users}
                    blocked_users={@blocked_users}
                  />
                <% end %>
            <% end %>
          </div>
        </div>

        <!-- Sidebar (Audience Stats) -->
        <div class="w-80 bg-gray-800 border-l border-gray-700">
          <div class="p-4">
            <h3 class="text-lg font-semibold mb-4">Audience</h3>

            <!-- Stats Grid -->
            <div class="grid grid-cols-2 gap-3 mb-6">
              <div class="bg-gray-900 rounded-lg p-3 text-center">
                <div class="text-2xl font-bold text-green-400"><%= @audience_stats.active %></div>
                <div class="text-xs text-gray-400">Active</div>
              </div>
              <div class="bg-gray-900 rounded-lg p-3 text-center">
                <div class="text-2xl font-bold text-yellow-400"><%= @audience_stats.waiting %></div>
                <div class="text-xs text-gray-400">Waiting</div>
              </div>
              <div class="bg-gray-900 rounded-lg p-3 text-center">
                <div class="text-2xl font-bold text-blue-400"><%= @audience_stats.total %></div>
                <div class="text-xs text-gray-400">Total</div>
              </div>
              <div class="bg-gray-900 rounded-lg p-3 text-center">
                <div class="text-2xl font-bold text-gray-400"><%= @audience_stats.left %></div>
                <div class="text-xs text-gray-400">Left</div>
              </div>
            </div>

            <!-- Recent Activity -->
            <h4 class="text-sm font-medium text-gray-400 mb-3">Recent Activity</h4>
            <div class="space-y-2">
              <div class="text-sm text-gray-400">
                <span class="text-green-400">•</span> User joined
              </div>
              <div class="text-sm text-gray-400">
                <span class="text-yellow-400">•</span> Message sent
              </div>
              <div class="text-sm text-gray-400">
                <span class="text-red-400">•</span> User left
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
