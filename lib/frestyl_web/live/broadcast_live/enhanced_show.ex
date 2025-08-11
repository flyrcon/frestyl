# lib/frestyl_web/live/broadcast_live/enhanced_show.ex
defmodule FrestylWeb.BroadcastLive.EnhancedShow do
  @moduledoc """
  Enhanced broadcast LiveView with complete WebRTC video streaming support.
  Integrates with existing audio engine and adds professional video broadcasting.
  """

  use FrestylWeb, :live_view
  alias Frestyl.{Sessions, Accounts}
  alias Frestyl.Streaming.{WebRTCManager, Engine}
  alias Frestyl.Studio.AudioEngine
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => broadcast_id, "slug" => channel_slug}, _session, socket) do
    # Get broadcast and channel info (keeping existing logic)
    broadcast = Sessions.get_session!(broadcast_id)
    channel = Sessions.get_channel_by_slug!(channel_slug)
    current_user = socket.assigns.current_user

    # Check permissions
    is_host = broadcast.created_by_id == current_user.id
    is_organizer = channel.created_by_id == current_user.id

    # Get user registration for this broadcast
    current_user_registration = if current_user do
      Sessions.get_user_registration(broadcast.id, current_user.id)
    else
      nil
    end

    # Subscribe to broadcast events
    if connected?(socket) do
      PubSub.subscribe(Frestyl.PubSub, "broadcast:#{broadcast_id}")
      PubSub.subscribe(Frestyl.PubSub, "webrtc:#{broadcast_id}")
      if current_user do
        PubSub.subscribe(Frestyl.PubSub, "user:#{current_user.id}")
      end
    end

    # Initialize WebRTC manager if host is starting stream
    if is_host and broadcast.status == "active" and connected?(socket) do
      case WebRTCManager.start_link(broadcast_id) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        error ->
          Logger.error("Failed to start WebRTC manager: #{inspect(error)}")
      end
    end

    socket = socket
    |> assign(:broadcast, broadcast)
    |> assign(:channel, channel)
    |> assign(:is_host, is_host)
    |> assign(:is_organizer, is_organizer)
    |> assign(:current_user_registration, current_user_registration)
    |> assign(:stream_started, broadcast.status == "active")
    |> assign(:audio_engine_active, false)
    |> assign(:webrtc_active, false)
    |> assign(:viewer_count, 0)
    |> assign(:stream_quality, "720p")
    |> assign(:connection_status, "disconnected")
    |> assign(:local_stream_ready, false)
    |> assign(:remote_viewers, [])
    |> assign(:stream_stats, %{})
    |> assign(:viewing_mode, determine_viewing_mode(broadcast, current_user_registration, is_organizer))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    viewing_mode = case params["mode"] do
      "live" when socket.assigns.stream_started -> "live"
      _ -> "preview"
    end

    {:noreply, assign(socket, :viewing_mode, viewing_mode)}
  end

  # WebRTC Event Handlers

  @impl true
  def handle_event("start_video_stream", _params, socket) do
    if socket.assigns.is_host do
      broadcast_id = socket.assigns.broadcast.id

      # Start WebRTC manager
      case WebRTCManager.join_broadcast(broadcast_id, socket.assigns.current_user.id, true) do
        {:ok, :host} ->
          # Update broadcast status
          case Sessions.update_session(socket.assigns.broadcast, %{status: "active"}) do
            {:ok, updated_broadcast} ->
              # Initialize audio engine
              initialize_audio_engine(broadcast_id)

              {:noreply,
               socket
               |> assign(:broadcast, updated_broadcast)
               |> assign(:stream_started, true)
               |> assign(:webrtc_active, true)
               |> push_event("start_video_stream", %{})}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to start stream")}
          end

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to initialize video: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stop_video_stream", _params, socket) do
    if socket.assigns.is_host do
      broadcast_id = socket.assigns.broadcast.id

      # Stop WebRTC manager
      WebRTCManager.leave_broadcast(broadcast_id, socket.assigns.current_user.id)
      WebRTCManager.stop_broadcast(broadcast_id)

      # Stop audio engine
      case AudioEngine.get_engine_state(broadcast_id) do
        {:ok, _state} -> AudioEngine.stop_playback(broadcast_id)
        _ -> :ok
      end

      # Update broadcast status
      case Sessions.update_session(socket.assigns.broadcast, %{
        status: "ended",
        ended_at: DateTime.utc_now()
      }) do
        {:ok, updated_broadcast} ->
          {:noreply,
           socket
           |> assign(:broadcast, updated_broadcast)
           |> assign(:stream_started, false)
           |> assign(:webrtc_active, false)
           |> assign(:audio_engine_active, false)
           |> push_event("stop_video_stream", %{})}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to end stream")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("join_as_viewer", _params, socket) do
    if socket.assigns.current_user_registration and socket.assigns.stream_started do
      broadcast_id = socket.assigns.broadcast.id
      user_id = socket.assigns.current_user.id

      case WebRTCManager.join_broadcast(broadcast_id, user_id, false) do
        {:ok, :viewer} ->
          {:noreply,
           socket
           |> assign(:connection_status, "connecting")
           |> push_event("join_as_viewer", %{})}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to join stream: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Must register for broadcast to view")}
    end
  end

  @impl true
  def handle_event("leave_stream", _params, socket) do
    if socket.assigns.current_user do
      broadcast_id = socket.assigns.broadcast.id
      user_id = socket.assigns.current_user.id

      WebRTCManager.leave_broadcast(broadcast_id, user_id)

      {:noreply,
       socket
       |> assign(:connection_status, "disconnected")
       |> push_event("leave_stream", %{})}
    else
      {:noreply, socket}
    end
  end

  # WebRTC Signaling Events (from JavaScript)

  @impl true
  def handle_event("local_stream_ready", %{"hasVideo" => has_video, "hasAudio" => has_audio}, socket) do
    {:noreply,
     socket
     |> assign(:local_stream_ready, true)
     |> put_flash(:info, "Camera and microphone ready")}
  end

  @impl true
  def handle_event("video_stream_started", %{"streamConfig" => stream_config}, socket) do
    # Log stream configuration
    Logger.info("Video stream started with config: #{inspect(stream_config)}")

    {:noreply,
     socket
     |> assign(:stream_stats, stream_config)
     |> put_flash(:info, "Live stream active!")}
  end

  @impl true
  def handle_event("request_to_join_broadcast", %{"broadcastId" => broadcast_id, "userId" => user_id}, socket) do
    # This comes from JavaScript, forward to WebRTC manager
    WebRTCManager.join_broadcast(broadcast_id, user_id, false)
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_webrtc_offer", %{"target_user_id" => target_user_id, "offer" => offer}, socket) do
    broadcast_id = socket.assigns.broadcast.id
    from_user_id = socket.assigns.current_user.id

    WebRTCManager.send_offer(broadcast_id, from_user_id, target_user_id, offer)
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_webrtc_answer", %{"target_user_id" => target_user_id, "answer" => answer}, socket) do
    broadcast_id = socket.assigns.broadcast.id
    from_user_id = socket.assigns.current_user.id

    WebRTCManager.send_answer(broadcast_id, from_user_id, target_user_id, answer)
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_ice_candidate", %{"target_user_id" => target_user_id, "candidate" => candidate}, socket) do
    broadcast_id = socket.assigns.broadcast.id
    from_user_id = socket.assigns.current_user.id

    WebRTCManager.send_ice_candidate(broadcast_id, from_user_id, target_user_id, candidate)
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_stream_quality", %{"quality" => quality}, socket) do
    if socket.assigns.is_host do
      broadcast_id = socket.assigns.broadcast.id
      WebRTCManager.update_stream_quality(broadcast_id, quality)

      {:noreply,
       socket
       |> assign(:stream_quality, quality)
       |> push_event("stream_quality_change", %{quality: quality})}
    else
      {:noreply, socket}
    end
  end

  # Handle messages from WebRTC Manager and other processes

  @impl true
  def handle_info({:viewer_joined, viewer_id}, socket) do
    # Update viewer count and list
    current_viewers = socket.assigns.remote_viewers
    new_viewers = [viewer_id | current_viewers] |> Enum.uniq()

    {:noreply,
     socket
     |> assign(:remote_viewers, new_viewers)
     |> assign(:viewer_count, length(new_viewers))
     |> push_event("viewer_joined", %{viewer_id: viewer_id})}
  end

  @impl true
  def handle_info({:viewer_left, viewer_id}, socket) do
    current_viewers = socket.assigns.remote_viewers
    new_viewers = List.delete(current_viewers, viewer_id)

    {:noreply,
     socket
     |> assign(:remote_viewers, new_viewers)
     |> assign(:viewer_count, length(new_viewers))
     |> push_event("viewer_left", %{viewer_id: viewer_id})}
  end

  @impl true
  def handle_info({:webrtc_offer, from_user_id, offer}, socket) do
    {:noreply, push_event(socket, "webrtc_offer", %{from_user_id: from_user_id, offer: offer})}
  end

  @impl true
  def handle_info({:webrtc_answer, from_user_id, answer}, socket) do
    {:noreply, push_event(socket, "webrtc_answer", %{from_user_id: from_user_id, answer: answer})}
  end

  @impl true
  def handle_info({:webrtc_ice_candidate, from_user_id, candidate}, socket) do
    {:noreply, push_event(socket, "webrtc_ice_candidate", %{from_user_id: from_user_id, candidate: candidate})}
  end

  @impl true
  def handle_info({:stream_quality_change, quality}, socket) do
    {:noreply,
     socket
     |> assign(:stream_quality, quality)
     |> push_event("stream_quality_change", %{quality: quality})}
  end

  @impl true
  def handle_info({:broadcast_ended}, socket) do
    {:noreply,
     socket
     |> assign(:stream_started, false)
     |> assign(:webrtc_active, false)
     |> assign(:connection_status, "disconnected")
     |> put_flash(:info, "Broadcast has ended")
     |> push_event("stream_ended", %{})}
  end

  # Keep existing broadcast event handlers for compatibility
  @impl true
  def handle_info({:stream_started}, socket) do
    {:noreply,
     socket
     |> assign(:stream_started, true)
     |> put_flash(:info, "Stream is now live!")}
  end

  @impl true
  def handle_info({:stream_ended}, socket) do
    {:noreply,
     socket
     |> assign(:stream_started, false)
     |> put_flash(:info, "Stream has ended")}
  end

  # Audio Engine Integration (Enhanced)

  defp initialize_audio_engine(broadcast_id) do
    case AudioEngine.get_engine_state(broadcast_id) do
      {:ok, _state} ->
        Logger.info("Audio engine already active for broadcast #{broadcast_id}")
        :ok
      {:error, :not_found} ->
        case AudioEngine.start_link(broadcast_id) do
          {:ok, _pid} ->
            Logger.info("Audio engine started for broadcast #{broadcast_id}")
            :ok
          {:error, {:already_started, _pid}} ->
            :ok
          error ->
            Logger.error("Failed to start audio engine: #{inspect(error)}")
            error
        end
    end
  end

  # Helper Functions

  defp determine_viewing_mode(broadcast, user_registration, is_organizer) do
    cond do
      broadcast.status == "active" and (user_registration or is_organizer) -> "live"
      broadcast.status == "active" -> "preview_live"
      true -> "preview"
    end
  end

  # Render Function

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900">
      <%= if @viewing_mode == "live" do %>
        <!-- LIVE STREAMING INTERFACE -->
        <div class="h-screen flex flex-col">
          <!-- Stream Header -->
          <div class="bg-black/20 backdrop-blur-md border-b border-white/10 px-6 py-4">
            <div class="flex items-center justify-between text-white">
              <div class="flex items-center space-x-4">
                <div class="flex items-center space-x-2">
                  <%= if @stream_started do %>
                    <div class="w-3 h-3 bg-red-500 rounded-full animate-pulse"></div>
                    <span class="font-semibold text-red-400">LIVE</span>
                  <% else %>
                    <div class="w-3 h-3 bg-gray-500 rounded-full"></div>
                    <span class="font-semibold text-gray-400">OFFLINE</span>
                  <% end %>
                </div>
                <h1 class="text-xl font-bold"><%= @broadcast.title %></h1>
                <span class="text-purple-300">• <%= @viewer_count %> viewers</span>
              </div>

              <div class="flex items-center space-x-4">
                <%= if @is_host do %>
                  <!-- Host Controls -->
                  <div class="flex items-center space-x-2">
                    <select phx-change="change_stream_quality"
                            class="bg-white/10 border border-white/20 rounded-lg px-3 py-1 text-sm">
                      <option value="480p" selected={@stream_quality == "480p"}>480p</option>
                      <option value="720p" selected={@stream_quality == "720p"}>720p</option>
                      <option value="1080p" selected={@stream_quality == "1080p"}>1080p</option>
                      <option value="4K" selected={@stream_quality == "4K"}>4K</option>
                    </select>

                    <%= if @stream_started do %>
                      <button phx-click="stop_video_stream"
                              class="bg-red-600 hover:bg-red-700 px-4 py-2 rounded-lg font-medium transition-colors">
                        End Stream
                      </button>
                    <% else %>
                      <button phx-click="start_video_stream"
                              class="bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700 px-4 py-2 rounded-lg font-medium transition-all">
                        Go Live
                      </button>
                    <% end %>
                  </div>
                <% else %>
                  <!-- Viewer Controls -->
                  <%= if @connection_status == "disconnected" and @stream_started do %>
                    <button phx-click="join_as_viewer"
                            class="bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700 px-4 py-2 rounded-lg font-medium transition-all">
                      Join Stream
                    </button>
                  <% else %>
                    <button phx-click="leave_stream"
                            class="bg-gray-600 hover:bg-gray-700 px-4 py-2 rounded-lg font-medium transition-colors">
                      Leave Stream
                    </button>
                  <% end %>
                <% end %>

                <.link navigate={~p"/channels/#{@channel.slug}/broadcasts/#{@broadcast.id}"}
                      class="text-gray-300 hover:text-white">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </.link>
              </div>
            </div>
          </div>

          <!-- Video Stream Area -->
          <div class="flex-1 flex">
            <!-- Main Video Area -->
            <div class="flex-1 bg-black relative"
                 phx-hook="WebRTCVideo"
                 id="webrtc-video-container"
                 data-broadcast-id={@broadcast.id}
                 data-user-id={@current_user.id}
                 data-is-host={@is_host}>

              <!-- Local Video (Host) -->
              <%= if @is_host do %>
                <div id="local-video-container" class="w-full h-full relative">
                  <!-- Video element will be injected by JS hook -->
                  <%= if not @local_stream_ready do %>
                    <div class="absolute inset-0 flex items-center justify-center bg-gray-900">
                      <div class="text-center text-white">
                        <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-500 mx-auto mb-4"></div>
                        <p>Initializing camera...</p>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <!-- Remote Video (Viewer) -->
                <div id="remote-videos-container" class="w-full h-full">
                  <%= if @connection_status == "disconnected" do %>
                    <div class="absolute inset-0 flex items-center justify-center bg-gray-900">
                      <div class="text-center text-white">
                        <svg class="w-16 h-16 mx-auto mb-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                        </svg>
                        <p class="text-lg">Stream not connected</p>
                        <p class="text-gray-400">Click "Join Stream" to watch</p>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <!-- Stream Info Overlay -->
              <div class="absolute bottom-4 left-4 bg-black/50 backdrop-blur-md rounded-lg px-4 py-2 text-white">
                <div class="flex items-center space-x-3 text-sm">
                  <span>Quality: <%= @stream_quality %></span>
                  <span>•</span>
                  <span>Status: <%= String.capitalize(@connection_status) %></span>
                  <%= if @stream_stats != %{} do %>
                    <span>•</span>
                    <span>FPS: <%= Map.get(@stream_stats, "frameRate", "N/A") %></span>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Sidebar (Chat, Controls, etc.) -->
            <div class="w-80 bg-black/20 backdrop-blur-md border-l border-white/10">
              <!-- Chat and interaction components would go here -->
              <div class="p-4 text-white">
                <h3 class="font-semibold mb-4">Live Chat</h3>
                <div class="space-y-2 text-sm text-gray-300">
                  <p>Chat integration coming soon...</p>
                </div>
              </div>
            </div>
          </div>
        </div>

      <% else %>
        <!-- PREVIEW/REGISTRATION INTERFACE (keep existing) -->
        <div class="min-h-screen text-white">
          <!-- Existing preview interface code here -->
          <div class="max-w-4xl mx-auto px-6 py-8">
            <div class="bg-white/10 backdrop-blur-md rounded-2xl p-8">
              <h1 class="text-3xl font-bold mb-4"><%= @broadcast.title %></h1>
              <p class="text-purple-200 mb-6"><%= @broadcast.description %></p>

              <%= if @current_user_registration do %>
                <.link navigate={~p"/channels/#{@channel.slug}/broadcasts/#{@broadcast.id}/live"}
                      class="bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700 px-6 py-3 rounded-lg font-medium transition-all inline-block">
                  <%= if @stream_started, do: "Join Live Stream", else: "Enter Broadcast Room" %>
                </.link>
              <% else %>
                <button phx-click="register_for_broadcast"
                        class="bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700 px-6 py-3 rounded-lg font-medium transition-all">
                  Register for Broadcast
                </button>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Keep existing event handlers for registration, etc.
  @impl true
  def handle_event("register_for_broadcast", _params, socket) do
    %{broadcast: broadcast, current_user: current_user, channel: channel} = socket.assigns

    case Sessions.register_for_broadcast(broadcast.id, current_user.id) do
      {:ok, :join_now, participant} ->
        {:noreply,
        socket
        |> put_flash(:info, "Registered! Joining live broadcast now...")
        |> redirect(to: ~p"/channels/#{channel.slug}/broadcasts/#{broadcast.id}/live")}

      {:ok, :registered, participant} ->
        {:noreply,
        socket
        |> assign(:current_user_registration, participant)
        |> put_flash(:info, "Successfully registered for the broadcast!")}

      {:error, :already_registered} ->
        registration = Sessions.get_user_registration(broadcast.id, current_user.id)
        {:noreply,
        socket
        |> assign(:current_user_registration, registration)
        |> put_flash(:info, "You're already registered for this broadcast")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to register: #{inspect(reason)}")}
    end
  end
end
