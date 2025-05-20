defmodule FrestylWeb.BroadcastLive.SoundCheck do
  use FrestylWeb, :live_view
  alias Frestyl.Sessions

  @impl true
  def mount(%{"broadcast_id" => id}, _session, socket) do
    broadcast_id = String.to_integer(id)

    # Get the broadcast
    broadcast = Sessions.get_session(broadcast_id)

    # Manually load host if needed
    if broadcast.host_id do
      host = Frestyl.Accounts.get_user!(broadcast.host_id)
      broadcast = Map.put(broadcast, :host, host)
    else
      creator = Frestyl.Accounts.get_user!(broadcast.creator_id)
      broadcast = Map.put(broadcast, :host, creator)
    end

    current_user = socket.assigns.current_user

    # Determine if user is the host
    is_host = (broadcast.host_id || broadcast.creator_id) == current_user.id

    socket = socket
      |> assign(:broadcast, broadcast)
      |> assign(:current_user, current_user)
      |> assign(:is_host, is_host)
      |> assign(:page_title, "Sound Check - #{broadcast.title}")
      |> assign(:ready_to_join, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"channel_id" => channel_id, "broadcast_id" => broadcast_id}, _uri, socket) do
    # Store channel_id for navigation
    {:noreply, assign(socket, :channel_id, channel_id)}
  end

  @impl true
  def handle_params(%{"broadcast_id" => broadcast_id}, _uri, socket) do
    # Direct broadcast access (no channel context)
    {:noreply, assign(socket, :channel_id, nil)}
  end

  @impl true
  def handle_event("ready_to_join", _params, socket) do
    {:noreply, assign(socket, :ready_to_join, true)}
  end

  @impl true
  def handle_event("skip_sound_check", _params, socket) do
    # Allow users to skip sound check and join directly
    send(self(), {:sound_check_complete, :skipped})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:sound_check_complete, _status}, socket) do
    # Navigate to the next step in the broadcast flow
    broadcast = socket.assigns.broadcast

    # Determine redirect path based on broadcast status
    redirect_path = if broadcast.status == "active" do
      # Broadcast is already live, go directly to live view
      if socket.assigns.channel_id do
        ~p"/channels/#{socket.assigns.channel_id}/broadcasts/#{broadcast.id}/live"
      else
        ~p"/broadcasts/#{broadcast.id}/live"
      end
    else
      # Broadcast hasn't started, go to waiting room
      if socket.assigns.channel_id do
        ~p"/channels/#{socket.assigns.channel_id}/broadcasts/#{broadcast.id}/waiting"
      else
        ~p"/broadcasts/#{broadcast.id}/waiting"
      end
    end

    {:noreply, redirect(socket, to: redirect_path)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-900 to-indigo-900">
      <div class="container mx-auto px-4 py-8">
        <div class="max-w-2xl mx-auto">
          <!-- Header -->
          <div class="text-center mb-8">
            <h1 class="text-3xl font-bold text-white mb-2">Sound Check</h1>
            <p class="text-gray-400">Let's make sure everything is working before you join</p>
            <div class="mt-4 text-lg font-medium text-gray-300">
              Joining: <span class="text-indigo-400"><%= @broadcast.title %></span>
            </div>
          </div>

          <!-- Sound Check Component -->
          <.live_component
            module={FrestylWeb.BroadcastLive.SoundCheckComponent}
            id="sound-check"
            broadcast={@broadcast}
            is_host={Map.get(assigns, :is_host, false)}
            current_user={@current_user}
          />

          <!-- Navigation Buttons -->
          <div class="mt-8 flex justify-center space-x-4">
            <button
              phx-click="skip_sound_check"
              class="px-6 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium transition-colors"
            >
              Skip Sound Check
            </button>

            <button
              phx-click="join_broadcast"
              disabled={!@ready_to_join}
              class={[
                "px-8 py-3 rounded-lg font-medium transition-colors",
                @ready_to_join && "bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700 text-white" ||
                "bg-gray-700 text-gray-400 cursor-not-allowed"
              ]}
            >
              <%= if @ready_to_join, do: "Join Broadcast!", else: "Complete Sound Check" %>
            </button>
          </div>

          <!-- Back to Channel Link -->
          <%= if @channel_id do %>
            <div class="mt-6 text-center">
              <.link
                navigate={~p"/channels/#{@channel_id}"}
                class="text-indigo-400 hover:text-indigo-300 text-sm"
              >
                ← Back to Channel
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
