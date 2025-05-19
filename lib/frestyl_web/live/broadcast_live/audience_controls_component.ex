# Create lib/frestyl_web/live/broadcast_live/audience_controls_component.ex
defmodule FrestylWeb.BroadcastLive.AudienceControlsComponent do
  use FrestylWeb, :live_component

  def mount(socket) do
    socket = assign(socket,
      attendees: [],
      blocked_users: [],
      muted_users: [],
      chat_enabled: true,
      reactions_enabled: true,
      current_view: "attendees",  # attendees, chat, settings
      chat_filter_level: "standard",  # none, standard, strict
      show_confirmation_dialog: false,
      confirmation_target: nil,
      confirmation_action: nil,
      confirmation_message: nil
    )

    {:ok, socket}
  end

  def update(assigns, socket) do
    if socket.assigns[:broadcast_id] != assigns.broadcast_id do
      # New broadcast, re-subscribe
      if socket.assigns[:broadcast_id] do
        Phoenix.PubSub.unsubscribe(Frestyl.PubSub, "broadcast:#{socket.assigns.broadcast_id}")
      end

      Phoenix.PubSub.subscribe(Frestyl.PubSub, "broadcast:#{assigns.broadcast_id}")
    end

    socket = socket
      |> assign(assigns)
      |> assign_attendees()
    {:ok, socket}
  end

  defp assign_attendees(socket) do
    # Fetch attendees for this broadcast
    attendees = Frestyl.Sessions.list_session_participants(socket.assigns.broadcast_id)
      |> Enum.map(fn participant ->
        %{
          id: participant.user_id,
          username: participant.user.username,
          name: participant.user.name,
          role: participant.role,
          joined_at: participant.inserted_at,
          is_blocked: Enum.member?(socket.assigns.blocked_users, participant.user_id),
          is_muted: Enum.member?(socket.assigns.muted_users, participant.user_id)
        }
      end)

    assign(socket, :attendees, attendees)
  end

  @impl true
  def handle_event("set_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :current_view, view)}
  end

  @impl true
  def handle_event("toggle_chat", _, socket) do
    new_state = !socket.assigns.chat_enabled

    # Broadcast the chat state change
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast_id}",
      {:chat_state_changed, new_state}
    )

    {:noreply, assign(socket, :chat_enabled, new_state)}
  end

  @impl true
  def handle_event("toggle_reactions", _, socket) do
    new_state = !socket.assigns.reactions_enabled

    # Broadcast the reactions state change
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast_id}",
      {:reactions_state_changed, new_state}
    )

    {:noreply, assign(socket, :reactions_enabled, new_state)}
  end

  @impl true
  def handle_event("set_chat_filter", %{"level" => level}, socket) do
    # Update chat filter level and broadcast change
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast_id}",
      {:chat_filter_changed, level}
    )

    {:noreply, assign(socket, :chat_filter_level, level)}
  end

  @impl true
  def handle_event("mute_user", %{"id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    muted_users = [user_id | socket.assigns.muted_users]

    # Broadcast that user is muted
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast_id}",
      {:user_muted, user_id}
    )

    {:noreply,
     socket
     |> assign(:muted_users, muted_users)
     |> assign_attendees()}
  end

  @impl true
  def handle_event("unmute_user", %{"id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    muted_users = Enum.reject(socket.assigns.muted_users, &(&1 == user_id))

    # Broadcast that user is unmuted
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast_id}",
      {:user_unmuted, user_id}
    )

    {:noreply,
     socket
     |> assign(:muted_users, muted_users)
     |> assign_attendees()}
  end

  @impl true
  def handle_event("confirm_block_user", %{"id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    username = Enum.find(socket.assigns.attendees, &(&1.id == user_id)).username

    {:noreply,
     socket
     |> assign(:show_confirmation_dialog, true)
     |> assign(:confirmation_action, "block_user")
     |> assign(:confirmation_target, user_id)
     |> assign(:confirmation_message, "Are you sure you want to block #{username}? They will be removed from the broadcast and unable to rejoin.")}
  end

  @impl true
  def handle_event("block_user", %{"id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    blocked_users = [user_id | socket.assigns.blocked_users]

    # Remove from broadcast and add to blocklist
    Frestyl.Sessions.remove_participant(socket.assigns.broadcast_id, user_id)

    # Broadcast that user is blocked
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast_id}",
      {:user_blocked, user_id}
    )

    {:noreply,
     socket
     |> assign(:blocked_users, blocked_users)
     |> assign(:show_confirmation_dialog, false)
     |> assign_attendees()}
  end

  @impl true
  def handle_event("unblock_user", %{"id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    blocked_users = Enum.reject(socket.assigns.blocked_users, &(&1 == user_id))

    # Broadcast that user is unblocked
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast_id}",
      {:user_unblocked, user_id}
    )

    {:noreply,
     socket
     |> assign(:blocked_users, blocked_users)
     |> assign_attendees()}
  end

  @impl true
  def handle_event("cancel_confirmation", _, socket) do
    {:noreply,
     socket
     |> assign(:show_confirmation_dialog, false)
     |> assign(:confirmation_action, nil)
     |> assign(:confirmation_target, nil)
     |> assign(:confirmation_message, nil)}
  end

  @impl true
  def handle_event("confirm_action", _, socket) do
    action = socket.assigns.confirmation_action
    target = socket.assigns.confirmation_target

    # Handle the confirmed action
    case action do
      "block_user" ->
        handle_event("block_user", %{"id" => to_string(target)}, socket)
      _ ->
        {:noreply, assign(socket, :show_confirmation_dialog, false)}
    end
  end

  @impl true
  def handle_info({:user_joined, user_id, username}, socket) do
    # New user joined, update attendees list
    {:noreply, assign_attendees(socket)}
  end

  @impl true
  def handle_info({:user_left, user_id}, socket) do
    # User left, update attendees list
    {:noreply, assign_attendees(socket)}
  end

  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-gray-900 text-white">
      <!-- Top tabs -->
      <div class="flex border-b border-gray-800">
        <button
          phx-click="set_view"
          phx-value-view="attendees"
          phx-target={@myself}
          class={[
            "px-4 py-3 text-sm font-medium",
            @current_view == "attendees" && "border-b-2 border-indigo-500 text-indigo-500" || "text-gray-400 hover:text-white"
          ]}
        >
          Attendees (<%= length(@attendees) %>)
        </button>
        <button
          phx-click="set_view"
          phx-value-view="chat"
          phx-target={@myself}
          class={[
            "px-4 py-3 text-sm font-medium",
            @current_view == "chat" && "border-b-2 border-indigo-500 text-indigo-500" || "text-gray-400 hover:text-white"
          ]}
        >
          Chat Settings
        </button>
        <button
          phx-click="set_view"
          phx-value-view="settings"
          phx-target={@myself}
          class={[
            "px-4 py-3 text-sm font-medium",
            @current_view == "settings" && "border-b-2 border-indigo-500 text-indigo-500" || "text-gray-400 hover:text-white"
          ]}
        >
          Broadcast Settings
        </button>
      </div>

      <!-- Content area -->
      <div class="flex-1 overflow-y-auto p-4">
        <%= case @current_view do %>
          <% "attendees" -> %>
            <div class="space-y-4">
              <!-- Quick stats -->
              <div class="grid grid-cols-3 gap-2">
                <div class="bg-gray-800 rounded-lg p-3 text-center">
                  <div class="text-2xl font-bold"><%= length(@attendees) %></div>
                  <div class="text-xs text-gray-400">Total Viewers</div>
                </div>
                <div class="bg-gray-800 rounded-lg p-3 text-center">
                  <div class="text-2xl font-bold"><%= length(@muted_users) %></div>
                  <div class="text-xs text-gray-400">Muted</div>
                </div>
                <div class="bg-gray-800 rounded-lg p-3 text-center">
                  <div class="text-2xl font-bold"><%= length(@blocked_users) %></div>
                  <div class="text-xs text-gray-400">Blocked</div>
                </div>
              </div>

              <!-- Search and filter -->
              <div class="relative">
                <input
                  type="text"
                  placeholder="Search attendees..."
                  class="w-full bg-gray-800 border border-gray-700 rounded-lg py-2 pl-10 pr-4 text-white text-sm"
                />
                <div class="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-500" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd" />
                  </svg>
                </div>
              </div>

              <!-- Attendee list -->
              <div class="space-y-2">
                <%= for attendee <- @attendees do %>
                  <div class="bg-gray-800 rounded-lg p-3 flex items-center justify-between">
                    <div class="flex items-center">
                      <div class="h-10 w-10 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold">
                        <%= String.first(attendee.username || "") %>
                      </div>
                      <div class="ml-3">
                        <div class="text-sm font-medium flex items-center">
                          <%= attendee.username %>
                          <%= if attendee.role == "host" || attendee.role == "moderator" do %>
                            <span class={[
                              "ml-2 text-xs py-0.5 px-1.5 rounded-full",
                              attendee.role == "host" && "bg-indigo-900 text-indigo-300",
                              attendee.role == "moderator" && "bg-green-900 text-green-300"
                            ]}>
                              <%= String.capitalize(attendee.role) %>
                            </span>
                          <% end %>
                        </div>
                        <div class="text-xs text-gray-400">
                          Joined <%= relative_time(attendee.joined_at) %>
                        </div>
                      </div>
                    </div>

                    <div class="flex space-x-2">
                      <%= if attendee.role != "host" do %>
                        <%= if attendee.is_muted do %>
                          <button
                            phx-click="unmute_user"
                            phx-value-id={attendee.id}
                            phx-target={@myself}
                            class="text-xs py-1 px-2 bg-gray-700 text-gray-300 rounded hover:bg-gray-600"
                            title="Unmute user"
                          >
                            Unmute
                          </button>
                        <% else %>
                          <button
                            phx-click="mute_user"
                            phx-value-id={attendee.id}
                            phx-target={@myself}
                            class="text-xs py-1 px-2 bg-yellow-800 text-yellow-300 rounded hover:bg-yellow-700"
                            title="Mute user"
                          >
                            Mute
                          </button>
                        <% end %>

                        <%= if attendee.is_blocked do %>
                          <button
                            phx-click="unblock_user"
                            phx-value-id={attendee.id}
                            phx-target={@myself}
                            class="text-xs py-1 px-2 bg-gray-700 text-gray-300 rounded hover:bg-gray-600"
                            title="Unblock user"
                          >
                            Unblock
                          </button>
                        <% else %>
                          <button
                            phx-click="confirm_block_user"
                            phx-value-id={attendee.id}
                            phx-target={@myself}
                            class="text-xs py-1 px-2 bg-red-800 text-red-300 rounded hover:bg-red-700"
                            title="Block user"
                          >
                            Block
                          </button>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <%= if @attendees == [] do %>
                  <div class="text-center py-10 text-gray-500">
                    No attendees yet
                  </div>
                <% end %>
              </div>
            </div>

          <% "chat" -> %>
            <div class="space-y-6">
              <!-- Global chat controls -->
              <div class="bg-gray-800 rounded-lg p-4">
                <h3 class="text-lg font-medium mb-4">Chat Controls</h3>

                <div class="space-y-4">
                  <div class="flex items-center justify-between">
                    <div>
                      <div class="font-medium">Enable Chat</div>
                      <div class="text-sm text-gray-400">Allow attendees to send chat messages</div>
                    </div>

                    <label class="relative inline-flex items-center cursor-pointer">
                      <input
                        type="checkbox"
                        checked={@chat_enabled}
                        class="sr-only peer"
                        phx-click="toggle_chat"
                        phx-target={@myself}
                      >
                      <div class="w-11 h-6 bg-gray-700 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
                    </label>
                  </div>

                  <div class="flex items-center justify-between">
                    <div>
                      <div class="font-medium">Enable Reactions</div>
                      <div class="text-sm text-gray-400">Allow attendees to react to messages</div>
                    </div>

                    <label class="relative inline-flex items-center cursor-pointer">
                      <input
                        type="checkbox"
                        checked={@reactions_enabled}
                        class="sr-only peer"
                        phx-click="toggle_reactions"
                        phx-target={@myself}
                      >
                      <div class="w-11 h-6 bg-gray-700 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
                    </label>
                  </div>
                </div>
              </div>

              <!-- Moderation settings -->
              <div class="bg-gray-800 rounded-lg p-4">
                <h3 class="text-lg font-medium mb-4">Message Filtering</h3>

                <div class="space-y-3">
                  <label class="flex items-center">
                    <input
                      type="radio"
                      name="filter_level"
                      value="none"
                      checked={@chat_filter_level == "none"}
                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-600 bg-gray-700"
                      phx-click="set_chat_filter"
                      phx-value-level="none"
                      phx-target={@myself}
                    />
                    <div class="ml-3">
                      <div class="font-medium">No filtering</div>
                      <div class="text-sm text-gray-400">All messages will be shown</div>
                    </div>
                  </label>

                  <label class="flex items-center">
                    <input
                      type="radio"
                      name="filter_level"
                      value="standard"
                      checked={@chat_filter_level == "standard"}
                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-600 bg-gray-700"
                      phx-click="set_chat_filter"
                      phx-value-level="standard"
                      phx-target={@myself}
                    />
                    <div class="ml-3">
                      <div class="font-medium">Standard filtering</div>
                      <div class="text-sm text-gray-400">Filter obvious profanity and harmful content</div>
                    </div>
                  </label>

                  <label class="flex items-center">
                    <input
                      type="radio"
                      name="filter_level"
                      value="strict"
                      checked={@chat_filter_level == "strict"}
                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-600 bg-gray-700"
                      phx-click="set_chat_filter"
                      phx-value-level="strict"
                      phx-target={@myself}
                    />
                    <div class="ml-3">
                      <div class="font-medium">Strict filtering</div>
                      <div class="text-sm text-gray-400">More aggressive content filtering</div>
                    </div>
                  </label>
                </div>
              </div>

              <!-- Blocked and muted users -->
              <div class="bg-gray-800 rounded-lg p-4">
                <h3 class="text-lg font-medium mb-4">Moderated Users</h3>

                <!-- Muted users -->
                <div class="mb-4">
                  <h4 class="text-sm font-medium text-gray-400 mb-2">Muted Users</h4>

                  <div class="max-h-32 overflow-y-auto">
                    <%= if Enum.any?(@attendees, &(&1.is_muted)) do %>
                      <div class="space-y-1">
                        <%= for attendee <- Enum.filter(@attendees, &(&1.is_muted)) do %>
                          <div class="flex justify-between items-center py-1 px-2 rounded bg-gray-700">
                            <div class="text-sm"><%= attendee.username %></div>
                            <button
                              phx-click="unmute_user"
                              phx-value-id={attendee.id}
                              phx-target={@myself}
                              class="text-xs py-0.5 px-1.5 bg-gray-600 text-gray-300 rounded hover:bg-gray-500"
                            >
                              Unmute
                            </button>
                          </div>
                        <% end %>
                      </div>
                    <% else %>
                      <div class="text-sm text-gray-500 text-center py-2">
                        No muted users
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Blocked users -->
                <div>
                  <h4 class="text-sm font-medium text-gray-400 mb-2">Blocked Users</h4>

                  <div class="max-h-32 overflow-y-auto">
                    <%= if Enum.any?(@attendees, &(&1.is_blocked)) do %>
                      <div class="space-y-1">
                        <%= for attendee <- Enum.filter(@attendees, &(&1.is_blocked)) do %>
                          <div class="flex justify-between items-center py-1 px-2 rounded bg-gray-700">
                            <div class="text-sm"><%= attendee.username %></div>
                            <button
                              phx-click="unblock_user"
                              phx-value-id={attendee.id}
                              phx-target={@myself}
                              class="text-xs py-0.5 px-1.5 bg-gray-600 text-gray-300 rounded hover:bg-gray-500"
                            >
                              Unblock
                            </button>
                          </div>
                        <% end %>
                      </div>
                    <% else %>
                      <div class="text-sm text-gray-500 text-center py-2">
                        No blocked users
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

          <% "settings" -> %>
            <div class="space-y-6">
              <!-- Broadcast settings -->
              <div class="bg-gray-800 rounded-lg p-4">
                <h3 class="text-lg font-medium mb-4">Broadcast Settings</h3>

                <div class="space-y-4">
                  <div>
                    <label for="broadcast_title" class="block text-sm font-medium text-gray-400 mb-1">
                      Broadcast Title
                    </label>
                    <input
                      type="text"
                      id="broadcast_title"
                      value={@broadcast.title}
                      class="w-full bg-gray-700 border border-gray-600 rounded-md py-2 px-3 text-white"
                      placeholder="Enter broadcast title"
                    />
                  </div>

                  <div>
                    <label for="broadcast_description" class="block text-sm font-medium text-gray-400 mb-1">
                      Description
                    </label>
                    <textarea
                      id="broadcast_description"
                      rows="3"
                      class="w-full bg-gray-700 border border-gray-600 rounded-md py-2 px-3 text-white"
                      placeholder="Enter broadcast description"
                    ><%= @broadcast.description %></textarea>
                  </div>

                  <div class="flex justify-end">
                    <button class="bg-indigo-600 hover:bg-indigo-700 text-white py-2 px-4 rounded-md text-sm">
                      Update Broadcast
                    </button>
                  </div>
                </div>
              </div>

              <!-- Broadcast actions -->
              <div class="bg-gray-800 rounded-lg p-4">
                <h3 class="text-lg font-medium mb-4">Broadcast Actions</h3>

                <div class="space-y-3">
                  <button class="w-full bg-yellow-600 hover:bg-yellow-700 text-white py-2 px-4 rounded-md text-sm">
                    Pause Broadcast
                  </button>

                  <button class="w-full bg-red-600 hover:bg-red-700 text-white py-2 px-4 rounded-md text-sm">
                    End Broadcast
                  </button>
                </div>
              </div>
            </div>
        <% end %>
      </div>

      <!-- Confirmation Dialog -->
      <%= if @show_confirmation_dialog do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-10">
          <div class="bg-gray-800 rounded-lg p-6 max-w-sm w-full">
            <h3 class="text-lg font-medium mb-4">Confirm Action</h3>
            <p class="text-gray-300 mb-6"><%= @confirmation_message %></p>

            <div class="flex justify-end space-x-3">
              <button
                phx-click="cancel_confirmation"
                phx-target={@myself}
                class="py-2 px-4 bg-gray-700 text-white rounded-md text-sm"
              >
                Cancel
              </button>
              <button
                phx-click="confirm_action"
                phx-target={@myself}
                class="py-2 px-4 bg-red-600 text-white rounded-md text-sm"
              >
                Confirm
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
