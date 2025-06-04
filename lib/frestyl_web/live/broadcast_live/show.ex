# lib/frestyl_web/live/broadcast_live/show.ex - Enhanced with Audio Integration
defmodule FrestylWeb.BroadcastLive.Show do
  use FrestylWeb, :live_view
  alias Frestyl.Sessions
  alias Frestyl.Channels
  alias Frestyl.Accounts
  alias Frestyl.Studio.AudioEngine
  alias Phoenix.PubSub

  @impl true
  def mount(%{"slug" => channel_slug, "id" => broadcast_id} = params, session, socket) do
    # Get current user from session
    current_user = session["user_token"] && Accounts.get_user_by_session_token(session["user_token"])

    if is_nil(current_user) do
      socket =
        socket
        |> put_flash(:error, "You must be logged in to view broadcasts")
        |> redirect(to: ~p"/login")
      {:ok, socket}
    else
      try do
        # Convert string to integer if needed
        broadcast_id_int = if is_binary(broadcast_id), do: String.to_integer(broadcast_id), else: broadcast_id

        # Get broadcast by ID
        broadcast = Sessions.get_session(broadcast_id_int)

        # Get channel by slug
        channel = Channels.get_channel_by_slug(channel_slug)

        cond do
          is_nil(broadcast) ->
            socket =
              socket
              |> put_flash(:error, "Broadcast not found")
              |> redirect(to: ~p"/channels/#{channel_slug}")
            {:ok, socket}

          is_nil(channel) ->
            socket =
              socket
              |> put_flash(:error, "Channel not found")
              |> redirect(to: ~p"/dashboard")
            {:ok, socket}

          broadcast.channel_id != channel.id ->
            socket =
              socket
              |> put_flash(:error, "Broadcast not found in this channel")
              |> redirect(to: ~p"/channels/#{channel_slug}")
            {:ok, socket}

          true ->
            # Determine user roles
            is_host = broadcast.host_id == current_user.id
            is_creator = broadcast.creator_id == current_user.id
            is_organizer = is_host || is_creator

            # Check if user is registered for this broadcast
            current_user_registration = try do
              Sessions.get_user_registration(broadcast.id, current_user.id)
            rescue
              _ -> nil
            end

            if connected?(socket) do
              # Subscribe to broadcast events
              PubSub.subscribe(Frestyl.PubSub, "broadcast:#{broadcast.id}")
              PubSub.subscribe(Frestyl.PubSub, "broadcast:#{broadcast.id}:participants")
              PubSub.subscribe(Frestyl.PubSub, "broadcast:#{broadcast.id}:chat")
              PubSub.subscribe(Frestyl.PubSub, "broadcast:#{broadcast.id}:audio")

              # Subscribe to channel and user-specific events
              PubSub.subscribe(Frestyl.PubSub, "channel:#{channel.id}")
              PubSub.subscribe(Frestyl.PubSub, "user:#{current_user.id}")

              # Initialize audio engine if host
              if is_host do
                initialize_audio_engine(broadcast.id)
              end
            end

            # Get broadcast stats and participants with error handling
            participants = try do
              Sessions.list_session_participants(broadcast.id) || []
            rescue
              _ -> []
            end

            stats = try do
              Sessions.get_broadcast_stats(broadcast.id)
            rescue
              _ -> %{total: 0, active: 0, waiting: 0}
            end

            # Get host information
            host = if broadcast.host_id do
              Accounts.get_user(broadcast.host_id)
            else
              Accounts.get_user(broadcast.creator_id)
            end

            # Calculate audience stats
            participant_count = length(participants)
            waiting_count = Enum.count(participants, &(&1.joined_at == nil))
            active_count = Enum.count(participants, &(&1.joined_at != nil && &1.left_at == nil))
            left_count = Enum.count(participants, &(&1.left_at != nil))

            audience_stats = %{
              waiting: waiting_count,
              active: active_count,
              left: left_count,
              total: participant_count
            }

            {:ok,
            socket
            |> assign(:current_user, current_user)
            |> assign(:broadcast, broadcast)
            |> assign(:channel, channel)
            |> assign(:host, host)
            |> assign(:participants, participants)
            |> assign(:stats, stats)
            |> assign(:page_title, "#{broadcast.title} - Broadcast")
            |> assign(:is_host, is_host)
            |> assign(:is_creator, is_creator)
            |> assign(:is_organizer, is_organizer)
            |> assign(:participant_count, participant_count)
            |> assign(:audience_stats, audience_stats)
            |> assign(:current_tab, "stream")
            |> assign(:stream_started, broadcast.status == "active")
            |> assign(:current_quality, "auto")
            |> assign(:audio_only, false)
            |> assign(:current_user_registration, current_user_registration)
            |> assign(:viewing_mode, "preview")
            |> assign(:chat_enabled, true)
            |> assign(:reactions_enabled, true)
            |> assign(:muted_users, [])
            |> assign(:blocked_users, [])
            # Audio-specific assignments
            |> assign(:audio_engine_active, false)
            |> assign(:audio_tracks, [])
            |> assign(:master_volume, 0.8)
            |> assign(:recording_active, false)
            |> assign(:audio_stats, %{})
            |> assign(:mobile_audio_mode, "simple")
            |> detect_mobile_device()}
        end
      rescue
        Ecto.NoResultsError ->
          socket =
            socket
            |> put_flash(:error, "Broadcast not found")
            |> redirect(to: ~p"/channels/#{channel_slug}")
          {:ok, socket}
        ArgumentError ->
          socket =
            socket
            |> put_flash(:error, "Invalid broadcast ID")
            |> redirect(to: ~p"/channels/#{channel_slug}")
          {:ok, socket}
      end
    end
  end

  # Audio Engine Integration
  defp initialize_audio_engine(session_id) do
    case AudioEngine.start_link(session_id) do
      {:ok, _pid} ->
        # Subscribe to audio engine events
        PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")
      {:error, {:already_started, _pid}} ->
        # Already running, just subscribe
        PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")
      {:error, reason} ->
        Logger.error("Failed to start audio engine: #{inspect(reason)}")
    end
  end

  # Audio Engine Event Handlers
  @impl true
  def handle_info({:audio_engine_state, state}, socket) do
    {:noreply, assign(socket,
      audio_engine_active: true,
      audio_tracks: state.tracks,
      master_volume: state.master_volume,
      recording_active: state.isRecording,
      audio_stats: %{
        track_count: length(state.tracks),
        active_tracks: Enum.count(state.tracks, & &1.armed),
        cpu_usage: state.cpu_usage || 0
      }
    )}
  end

  @impl true
  def handle_info({:track_added, track, user_id}, socket) do
    if user_id == socket.assigns.current_user.id do
      updated_tracks = [track | socket.assigns.audio_tracks]
      {:noreply, assign(socket, audio_tracks: updated_tracks)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:track_deleted, track_id}, socket) do
    updated_tracks = Enum.reject(socket.assigns.audio_tracks, &(&1.id == track_id))
    {:noreply, assign(socket, audio_tracks: updated_tracks)}
  end

  @impl true
  def handle_info({:master_volume_changed, volume}, socket) do
    {:noreply, assign(socket, master_volume: volume)}
  end

  @impl true
  def handle_info({:recording_started, track_id}, socket) do
    {:noreply, assign(socket, recording_active: true)}
  end

  @impl true
  def handle_info({:recording_stopped, track_id, clip}, socket) do
    # Update the track with new clip
    updated_tracks = Enum.map(socket.assigns.audio_tracks, fn track ->
      if track.id == track_id do
        %{track | clips: [clip | track.clips]}
      else
        track
      end
    end)

    {:noreply, assign(socket,
      audio_tracks: updated_tracks,
      recording_active: false
    )}
  end

  # Audio Control Events
  @impl true
  def handle_event("create_audio_track", track_params, socket) do
    if socket.assigns.is_host do
      case AudioEngine.add_track(socket.assigns.broadcast.id, socket.assigns.current_user.id, track_params) do
        {:ok, track} ->
          {:noreply, put_flash(socket, :info, "Audio track created successfully")}
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to create track: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only hosts can create audio tracks")}
    end
  end

  @impl true
  def handle_event("set_master_volume", %{"volume" => volume}, socket) do
    if socket.assigns.is_host do
      volume_float = String.to_float(volume)
      AudioEngine.set_master_volume(socket.assigns.broadcast.id, volume_float)
      {:noreply, assign(socket, master_volume: volume_float)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_mixer_recording", _params, socket) do
    if socket.assigns.is_host do
      # Start recording on all armed tracks
      Enum.each(socket.assigns.audio_tracks, fn track ->
        if track.armed do
          AudioEngine.start_recording(socket.assigns.broadcast.id, track.id)
        end
      end)
      {:noreply, assign(socket, recording_active: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stop_mixer_recording", _params, socket) do
    if socket.assigns.is_host do
      # Stop recording on all tracks
      Enum.each(socket.assigns.audio_tracks, fn track ->
        AudioEngine.stop_recording(socket.assigns.broadcast.id, track.id)
      end)
      {:noreply, assign(socket, recording_active: false)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_track_property", %{"track_id" => track_id, "property" => property, "value" => value}, socket) do
    if socket.assigns.is_host do
      case property do
        "volume" ->
          AudioEngine.set_track_volume(socket.assigns.broadcast.id, track_id, value)
        "muted" ->
          AudioEngine.mute_track(socket.assigns.broadcast.id, track_id, value)
        "solo" ->
          AudioEngine.solo_track(socket.assigns.broadcast.id, track_id, value)
        "pan" ->
          AudioEngine.set_track_pan(socket.assigns.broadcast.id, track_id, value)
      end
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_track", %{"track_id" => track_id}, socket) do
    if socket.assigns.is_host do
      AudioEngine.delete_track(socket.assigns.broadcast.id, track_id)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_mobile_audio", _params, socket) do
    new_mode = case socket.assigns.mobile_audio_mode do
      "simple" -> "advanced"
      "advanced" -> "mixer"
      "mixer" -> "hidden"
      "hidden" -> "simple"
    end
    {:noreply, assign(socket, mobile_audio_mode: new_mode)}
  end

  # Keep existing event handlers...
  @impl true
  def handle_params(_params, _uri, socket) do
    action = socket.assigns.live_action
    broadcast = socket.assigns.broadcast
    current_user = socket.assigns.current_user
    channel = socket.assigns.channel

    case action do
      :live ->
        cond do
          broadcast.status != "active" ->
            {:noreply,
            socket
            |> put_flash(:info, "This broadcast hasn't started yet.")
            |> redirect(to: ~p"/channels/#{channel.slug}/broadcasts/#{broadcast.id}")}

          is_nil(socket.assigns.current_user_registration) and not socket.assigns.is_organizer ->
            {:noreply,
            socket
            |> put_flash(:error, "You must register for this broadcast before joining.")
            |> redirect(to: ~p"/channels/#{channel.slug}/broadcasts/#{broadcast.id}")}

          true ->
            {:noreply,
            socket
            |> assign(:viewing_mode, "live")
            |> assign(:page_title, "🔴 #{broadcast.title} - Live")}
        end

      :show ->
        {:noreply, assign(socket, :viewing_mode, "preview")}

      _ ->
        {:noreply, assign(socket, :viewing_mode, "preview")}
    end
  end

  # Keep existing broadcast event handlers...
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

  @impl true
  def handle_event("start_stream", _params, socket) do
    if socket.assigns.is_host do
      broadcast_id = socket.assigns.broadcast.id

      case Sessions.update_session(socket.assigns.broadcast, %{status: "active"}) do
        {:ok, updated_broadcast} ->
          # Start audio engine if not already running
          initialize_audio_engine(broadcast_id)

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

      # Stop audio engine
      case AudioEngine.get_engine_state(broadcast_id) do
        {:ok, _state} ->
          GenServer.call({:via, Registry, {Frestyl.Studio.AudioEngineRegistry, broadcast_id}}, :prepare_shutdown)
        _ -> :ok
      end

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
           |> assign(:stream_started, false)
           |> assign(:audio_engine_active, false)}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to end the stream")}
      end
    else
      {:noreply, socket}
    end
  end

  # Keep other existing event handlers...
  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :current_tab, tab)}
  end

  @impl true
  def handle_event("unregister_from_broadcast", _params, socket) do
    %{broadcast: broadcast, current_user: current_user} = socket.assigns

    case Sessions.remove_participant(broadcast.id, current_user.id) do
      {:ok, _} ->
        {:noreply,
        socket
        |> assign(:current_user_registration, nil)
        |> put_flash(:info, "Successfully unregistered from the broadcast")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to unregister: #{inspect(reason)}")}
    end
  end

  # Mobile device detection
  defp detect_mobile_device(socket) do
    # This is a simplified mobile detection - in production you'd check user agent
    assign(socket, :is_mobile, false)
  end

  # Keep all existing handle_info callbacks for broadcast events...
  @impl true
  def handle_info({:broadcast_status_changed, broadcast_id, new_status}, socket) do
    if socket.assigns.broadcast.id == broadcast_id do
      updated_broadcast = %{socket.assigns.broadcast | status: new_status}

      flash_message = if new_status == "active" and socket.assigns.current_user_registration do
        "This broadcast is now live! 🔴"
      else
        nil
      end

      socket =
        socket
        |> assign(:broadcast, updated_broadcast)
        |> assign(:stream_started, new_status == "active")

      socket = if flash_message do
        put_flash(socket, :info, flash_message)
      else
        socket
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Continue with other existing handle_info callbacks...

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @viewing_mode == "preview" do %>
      <!-- BROADCAST DETAIL/REGISTRATION PAGE -->
      <div class="min-h-screen bg-gray-900 text-white">
        <!-- Header -->
        <div class="bg-gray-800 border-b border-gray-700 px-6 py-4">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold"><%= @broadcast.title %></h1>
              <p class="text-gray-400">
                Hosted by <%= @host.username %> •
                <%= if @broadcast.status == "active" do %>
                  <span class="text-red-500 font-semibold">🔴 LIVE NOW</span>
                <% else %>
                  <span class="text-blue-400">
                    <%= Calendar.strftime(@broadcast.scheduled_for, "%B %d, %Y at %I:%M %p") %>
                  </span>
                <% end %>
              </p>
            </div>

            <.link navigate={~p"/channels/#{@channel.slug}"}
                  class="text-gray-400 hover:text-white">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
            </.link>
          </div>
        </div>

        <div class="max-w-4xl mx-auto px-6 py-8">
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <!-- Main Content -->
            <div class="lg:col-span-2">
              <div class="bg-gray-800 rounded-lg p-6 mb-6">
                <h2 class="text-xl font-semibold mb-4">About This Broadcast</h2>
                <%= if @broadcast.description do %>
                  <p class="text-gray-300 leading-relaxed"><%= @broadcast.description %></p>
                <% else %>
                  <p class="text-gray-500 italic">No description provided.</p>
                <% end %>
              </div>

              <!-- Broadcast Details -->
              <div class="bg-gray-800 rounded-lg p-6">
                <h3 class="text-lg font-semibold mb-4">Details</h3>
                <div class="space-y-3">
                  <div class="flex justify-between">
                    <span class="text-gray-400">Type:</span>
                    <span class="capitalize"><%= @broadcast.broadcast_type %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-400">Scheduled:</span>
                    <span><%= Calendar.strftime(@broadcast.scheduled_for, "%B %d, %Y at %I:%M %p") %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-400">Status:</span>
                    <span class={[
                      "capitalize font-medium",
                      @broadcast.status == "active" && "text-red-400",
                      @broadcast.status == "scheduled" && "text-blue-400",
                      @broadcast.status == "ended" && "text-gray-400"
                    ]}>
                      <%= @broadcast.status %>
                    </span>
                  </div>
                  <%= if @audio_engine_active do %>
                    <div class="flex justify-between">
                      <span class="text-gray-400">Audio Tracks:</span>
                      <span class="text-purple-400"><%= length(@audio_tracks) %> active</span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Registration Sidebar -->
            <div class="space-y-6">
              <!-- Registration Card -->
              <div class="bg-gray-800 rounded-lg p-6">
                <%= if @broadcast.status == "active" do %>
                  <!-- Broadcast is LIVE -->
                  <div class="text-center">
                    <div class="flex items-center justify-center mb-4">
                      <div class="w-3 h-3 bg-red-500 rounded-full animate-pulse mr-2"></div>
                      <span class="text-red-400 font-bold text-lg">LIVE NOW</span>
                    </div>

                    <%= if @current_user_registration do %>
                      <.link
                        navigate={~p"/channels/#{@channel.slug}/broadcasts/#{@broadcast.id}/live"}
                        class="w-full bg-red-600 hover:bg-red-700 text-white font-bold py-3 px-6 rounded-lg text-lg transition-colors block mb-3"
                      >
                        🔴 Join Live Broadcast
                      </.link>
                      <p class="text-sm text-green-400">
                        You're registered for this broadcast ✓
                      </p>
                    <% else %>
                      <div class="text-center p-4 bg-gray-700 rounded-lg mb-4">
                        <p class="text-gray-300 mb-3">This broadcast is live, but you need to register first</p>
                        <button
                          phx-click="register_for_broadcast"
                          class="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded w-full"
                        >
                          Register & Join Now
                        </button>
                      </div>
                    <% end %>
                  </div>

                <% else %>
                  <!-- Broadcast is scheduled/not live yet -->
                  <div class="text-center">
                    <h3 class="text-lg font-semibold mb-4">
                      <%= if @broadcast.status == "scheduled", do: "Upcoming Broadcast", else: "Broadcast Registration" %>
                    </h3>

                    <%= if @current_user_registration do %>
                      <div class="space-y-3">
                        <div class="flex items-center justify-center text-green-400 mb-2">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                          </svg>
                          <span class="font-medium">You're registered!</span>
                        </div>

                        <button
                          phx-click="unregister_from_broadcast"
                          class="w-full bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded"
                        >
                          Unregister
                        </button>
                      </div>
                    <% else %>
                      <div class="space-y-3">
                        <button
                          phx-click="register_for_broadcast"
                          class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 px-4 rounded"
                        >
                          Register for Broadcast
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <!-- Stats Card -->
              <div class="bg-gray-800 rounded-lg p-6">
                <h4 class="text-lg font-semibold mb-4">Broadcast Stats</h4>
                <div class="space-y-3">
                  <div class="flex justify-between">
                    <span class="text-gray-400">Registered:</span>
                    <span><%= @stats.total %></span>
                  </div>
                  <%= if @broadcast.status == "active" do %>
                    <div class="flex justify-between">
                      <span class="text-gray-400">Watching:</span>
                      <span class="text-red-400"><%= @stats.active %></span>
                    </div>
                  <% end %>
                  <%= if @broadcast.max_participants do %>
                    <div class="flex justify-between">
                      <span class="text-gray-400">Max Participants:</span>
                      <span><%= @broadcast.max_participants %></span>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Host Info -->
              <div class="bg-gray-800 rounded-lg p-6">
                <h4 class="text-lg font-semibold mb-4">Host</h4>
                <div class="flex items-center">
                  <div class="w-12 h-12 bg-indigo-600 rounded-full flex items-center justify-center mr-3">
                    <span class="text-white font-bold">
                      <%= String.first(@host.username || @host.name || "H") %>
                    </span>
                  </div>
                  <div>
                    <p class="font-medium"><%= @host.username || @host.name %></p>
                    <p class="text-sm text-gray-400"><%= @host.email %></p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

    <% else %>
      <!-- LIVE BROADCAST VIEW WITH ENHANCED AUDIO -->
      <div class="h-screen bg-gray-900 text-white flex flex-col relative">
        <!-- Audio Mixer Integration -->
        <%= if @is_host do %>
          <.live_component
            module={FrestylWeb.BroadcastLive.AudioMixerComponent}
            id="audio-mixer"
            broadcast={@broadcast}
            current_user={@current_user}
            audio_tracks={@audio_tracks}
            master_volume={@master_volume}
            recording_active={@recording_active}
            is_mobile={@is_mobile}
          />
        <% end %>

        <!-- Mobile Audio Controls for Non-Hosts -->
        <%= if @is_mobile and not @is_host and @mobile_audio_mode != "hidden" do %>
          <div class="fixed bottom-20 left-4 right-4 z-30 bg-black/80 backdrop-blur rounded-xl p-3">
            <div class="flex items-center justify-between">
              <span class="text-white/80 text-sm font-medium">Audio Controls</span>
                              <button
                phx-click="toggle_mobile_audio"
                class="text-white/60 hover:text-white"
              >
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <%= case @mobile_audio_mode do %>
              <% "simple" -> %>
                <div class="mt-3 flex items-center gap-3">
                  <div class="flex-1">
                    <div class="h-2 bg-white/20 rounded-full overflow-hidden">
                      <div
                        class="h-full bg-gradient-to-r from-green-500 to-blue-500 transition-all duration-300"
                        style={"width: #{@master_volume * 100}%;"}
                      ></div>
                    </div>
                  </div>
                  <span class="text-white/80 text-sm"><%= round(@master_volume * 100) %>%</span>
                </div>

              <% "advanced" -> %>
                <div class="mt-3 space-y-2">
                  <div class="flex items-center justify-between">
                    <span class="text-white/80 text-sm">Master Volume</span>
                    <span class="text-white/60 text-xs"><%= round(@master_volume * 100) %>%</span>
                  </div>
                  <input
                    type="range"
                    min="0"
                    max="100"
                    value={round(@master_volume * 100)}
                    class="w-full h-2 bg-white/20 rounded-lg appearance-none cursor-pointer"
                    readonly
                  />
                  <%= if @audio_engine_active do %>
                    <div class="text-white/60 text-xs">
                      <%= length(@audio_tracks) %> audio tracks active
                    </div>
                  <% end %>
                </div>
            <% end %>
          </div>
        <% end %>

        <!-- Top Navigation Bar -->
        <div class="bg-gray-800 border-b border-gray-700 px-4 py-3">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-4">
              <!-- Back to Channel Button -->
              <.link
                navigate={~p"/channels/#{@channel.slug}"}
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
                  <%= if @audio_engine_active do %>
                    <span>•</span>
                    <span class="text-purple-400"><%= length(@audio_tracks) %> tracks</span>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Host Controls -->
            <%= if @is_host do %>
              <div class="flex items-center space-x-3">
                <!-- Audio Status Indicator -->
                <%= if @audio_engine_active do %>
                  <div class="flex items-center gap-2 px-3 py-1 bg-purple-600/20 rounded-lg">
                    <div class="w-2 h-2 bg-purple-400 rounded-full animate-pulse"></div>
                    <span class="text-purple-300 text-sm font-medium">Audio Engine</span>
                  </div>
                <% end %>

                <!-- Recording Indicator -->
                <%= if @recording_active do %>
                  <div class="flex items-center gap-2 px-3 py-1 bg-red-600/20 rounded-lg">
                    <div class="w-2 h-2 bg-red-400 rounded-full animate-pulse"></div>
                    <span class="text-red-300 text-sm font-medium">Recording</span>
                  </div>
                <% end %>

                <!-- Stream Controls -->
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
                <button class="text-gray-400 hover:text-white p-2 rounded-md hover:bg-gray-700">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                </button>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Main Content Area -->
        <div class="flex flex-1 overflow-hidden">
          <!-- Stream Area -->
          <div class="flex-1 flex flex-col bg-black">
            <!-- Video Container -->
            <div class="flex-1 relative">
              <%= if @stream_started do %>
                <div id="stream-container" class="w-full h-full flex items-center justify-center">
                  <video
                    id="broadcast-video"
                    class="max-w-full max-h-full"
                    autoplay
                    controls
                    phx-hook="BroadcastVideo"
                    data-broadcast-id={@broadcast.id}
                    data-is-host={@is_host}
                  ></video>
                </div>

                <!-- Stream controls overlay -->
                <div class="absolute bottom-4 right-4 z-10 flex items-center space-x-2">
                  <!-- Quality settings control -->
                  <div class="relative">
                    <button
                      class="flex items-center space-x-1 text-white bg-black bg-opacity-50 hover:bg-opacity-70 px-3 py-1.5 rounded-md text-sm transition-colors"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      </svg>
                      <span>Quality (<%= String.capitalize(@current_quality) %>)</span>
                    </button>
                  </div>

                  <!-- Audio only toggle -->
                  <button
                    phx-click="toggle_audio_only"
                    class={[
                      "flex items-center space-x-1 px-3 py-1.5 rounded-md text-sm transition-colors",
                      @audio_only && "bg-indigo-600 text-white" || "bg-black bg-opacity-50 hover:bg-opacity-70 text-white"
                    ]}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15.536a5 5 0 01-1.414-2.536m-1.414 0a9 9 0 01.268-3.364m1.782 2.828a5 5 0 01-1.414-2.536" />
                    </svg>
                    <span>Audio Only</span>
                  </button>
                </div>
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <%= if @broadcast.status == "scheduled" do %>
                    <!-- Show waiting room -->
                    <div class="text-center">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-20 w-20 mx-auto text-gray-600 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <h2 class="text-2xl font-semibold text-white mb-2">Broadcast hasn't started yet</h2>
                      <p class="text-gray-400 max-w-md mx-auto">
                        The host hasn't started the broadcast yet. You'll automatically join when it begins.
                      </p>
                      <%= if @audio_engine_active do %>
                        <div class="mt-4 text-purple-400">
                          <p class="text-sm">Audio system is ready with <%= length(@audio_tracks) %> tracks</p>
                        </div>
                      <% end %>
                    </div>
                  <% else %>
                    <!-- Show ended message -->
                    <div class="text-center">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-20 w-20 mx-auto text-gray-600 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                      </svg>
                      <h2 class="text-2xl font-semibold text-white mb-2">This broadcast has ended</h2>
                      <p class="text-gray-400 max-w-md mx-auto">
                        The broadcast has concluded. Thank you for watching!
                      </p>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <!-- Tab Navigation for Stream Content -->
            <div class="bg-gray-800 border-t border-gray-700">
              <div class="flex">
                <button
                  phx-click="change_tab"
                  phx-value-tab="chat"
                  class={[
                    "px-4 py-2 text-sm",
                    @current_tab == "chat" && "border-b-2 border-indigo-500 text-white" || "text-gray-400 hover:text-white"
                  ]}
                >
                  Chat
                </button>

                <button
                  phx-click="change_tab"
                  phx-value-tab="participants"
                  class={[
                    "px-4 py-2 text-sm",
                    @current_tab == "participants" && "border-b-2 border-indigo-500 text-white" || "text-gray-400 hover:text-white"
                  ]}
                >
                  Participants
                </button>

                <button
                  phx-click="change_tab"
                  phx-value-tab="about"
                  class={[
                    "px-4 py-2 text-sm",
                    @current_tab == "about" && "border-b-2 border-indigo-500 text-white" || "text-gray-400 hover:text-white"
                  ]}
                >
                  About
                </button>

                <%= if @is_host do %>
                  <button
                    phx-click="change_tab"
                    phx-value-tab="analytics"
                    class={[
                      "px-4 py-2 text-sm",
                      @current_tab == "analytics" && "border-b-2 border-indigo-500 text-white" || "text-gray-400 hover:text-white"
                    ]}
                  >
                    Analytics
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Side panel - dynamic based on current tab -->
          <div class="w-80 border-l border-gray-800 bg-gray-900 flex flex-col">
            <%= case @current_tab do %>
                <% "chat" -> %>
                <div class="flex-1 flex flex-col">
                  <%= if @chat_enabled do %>
                    <.live_component
                      module={FrestylWeb.BroadcastLive.ChatComponent}
                      id="broadcast-chat"
                      broadcast_id={@broadcast.id}
                      current_user={@current_user}
                      chat_enabled={@chat_enabled}
                      reactions_enabled={@reactions_enabled}
                      muted_users={@muted_users}
                      is_host={@is_host}
                    />
                  <% else %>
                    <div class="flex-1 flex items-center justify-center">
                      <div class="text-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto text-gray-600 mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                        </svg>
                        <p class="text-gray-400">Chat is currently disabled</p>
                      </div>
                    </div>
                  <% end %>
                </div>

              <% "participants" -> %>
                <div class="flex-1 flex flex-col">
                  <div class="p-4 border-b border-gray-800">
                    <h3 class="text-white font-medium">Participants (<%= @participant_count %>)</h3>
                  </div>

                  <!-- Audience stats -->
                  <%= if @is_host do %>
                    <div class="p-4 border-b border-gray-800">
                      <div class="grid grid-cols-2 gap-3">
                        <div class="bg-gray-800 p-3 rounded-lg">
                          <div class="text-2xl font-semibold text-indigo-400"><%= @audience_stats.waiting %></div>
                          <div class="text-xs text-gray-400">In Waiting Room</div>
                        </div>
                        <div class="bg-gray-800 p-3 rounded-lg">
                          <div class="text-2xl font-semibold text-green-400"><%= @audience_stats.active %></div>
                          <div class="text-xs text-gray-400">Watching Now</div>
                        </div>
                        <div class="bg-gray-800 p-3 rounded-lg">
                          <div class="text-2xl font-semibold text-red-400"><%= @audience_stats.left %></div>
                          <div class="text-xs text-gray-400">Left Broadcast</div>
                        </div>
                        <div class="bg-gray-800 p-3 rounded-lg">
                          <div class="text-2xl font-semibold text-white"><%= @audience_stats.total %></div>
                          <div class="text-xs text-gray-400">Total Participants</div>
                        </div>
                      </div>
                    </div>
                  <% end %>

                  <div class="flex-1 overflow-y-auto p-4">
                    <div class="text-center text-gray-500 py-20">
                      Participant list will be displayed here
                    </div>
                  </div>
                </div>

              <% "about" -> %>
                <div class="flex-1 overflow-y-auto p-4">
                  <h3 class="text-lg font-medium text-white mb-4">About This Broadcast</h3>

                  <div class="prose prose-sm text-gray-300">
                    <p><%= @broadcast.description %></p>
                  </div>

                  <div class="mt-6">
                    <h4 class="text-sm font-medium text-gray-400 mb-2">Details</h4>

                    <div class="space-y-2">
                      <div class="flex justify-between">
                        <span class="text-gray-500">Started</span>
                        <span class="text-white">
                          <%= if @broadcast.started_at do %>
                            <%= Calendar.strftime(@broadcast.started_at, "%b %d, %Y at %I:%M %p") %>
                          <% else %>
                            Not started yet
                          <% end %>
                        </span>
                      </div>

                      <div class="flex justify-between">
                        <span class="text-gray-500">Type</span>
                        <span class="text-white"><%= String.capitalize(@broadcast.broadcast_type) %></span>
                      </div>

                      <div class="flex justify-between">
                        <span class="text-gray-500">Host</span>
                        <span class="text-white"><%= @host.username %></span>
                      </div>

                      <%= if @audio_engine_active do %>
                        <div class="flex justify-between">
                          <span class="text-gray-500">Audio Tracks</span>
                          <span class="text-purple-400"><%= length(@audio_tracks) %></span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>

              <% "analytics" -> %>
                <%= if @is_host do %>
                  <div class="flex-1 overflow-y-auto p-4">
                    <h3 class="text-lg font-medium text-white mb-4">Analytics</h3>

                    <!-- Audience stats -->
                    <div class="mb-6">
                      <h4 class="text-sm font-medium text-gray-400 mb-2">Audience</h4>

                      <div class="bg-gray-800 p-4 rounded-lg">
                        <div class="flex justify-between items-center mb-4">
                          <span class="text-white">Current Viewers</span>
                          <span class="text-xl font-semibold text-white"><%= @audience_stats.active %></span>
                        </div>

                        <div class="h-32 bg-gray-900 rounded-md flex items-center justify-center">
                          <p class="text-gray-500">Viewer graph will be displayed here</p>
                        </div>

                        <div class="mt-4 grid grid-cols-2 gap-4">
                          <div>
                            <div class="text-sm text-gray-400">Peak Viewers</div>
                            <div class="text-lg text-white"><%= @audience_stats.active %></div>
                          </div>
                          <div>
                            <div class="text-sm text-gray-400">Avg. Watch Time</div>
                            <div class="text-lg text-white">N/A</div>
                          </div>
                        </div>
                      </div>
                    </div>

                    <!-- Audio Analytics -->
                    <%= if @audio_engine_active do %>
                      <div class="mb-6">
                        <h4 class="text-sm font-medium text-gray-400 mb-2">Audio Performance</h4>

                        <div class="bg-gray-800 p-4 rounded-lg">
                          <div class="space-y-3">
                            <div class="flex justify-between">
                              <span class="text-gray-400">Active Tracks</span>
                              <span class="text-purple-400"><%= length(@audio_tracks) %></span>
                            </div>
                            <div class="flex justify-between">
                              <span class="text-gray-400">Master Volume</span>
                              <span class="text-white"><%= round(@master_volume * 100) %>%</span>
                            </div>
                            <div class="flex justify-between">
                              <span class="text-gray-400">Recording</span>
                              <span class={@recording_active && "text-red-400" || "text-gray-500"}>
                                <%= if @recording_active, do: "Active", else: "Inactive" %>
                              </span>
                            </div>
                            <%= if Map.has_key?(@audio_stats, :cpu_usage) do %>
                              <div class="flex justify-between">
                                <span class="text-gray-400">CPU Usage</span>
                                <span class="text-white"><%= @audio_stats.cpu_usage %>%</span>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    <% end %>

                    <!-- Live controls -->
                    <div>
                      <h4 class="text-sm font-medium text-gray-400 mb-2">Live Controls</h4>

                      <div class="space-y-3">
                        <div class="flex items-center justify-between bg-gray-800 p-3 rounded-lg">
                          <div class="text-white">Chat</div>
                          <label class="relative inline-flex items-center cursor-pointer">
                            <input
                              type="checkbox"
                              checked={@chat_enabled}
                              class="sr-only peer"
                              phx-click="toggle_chat"
                            >
                            <div class="w-11 h-6 bg-gray-700 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
                          </label>
                        </div>

                        <div class="flex items-center justify-between bg-gray-800 p-3 rounded-lg">
                          <div class="text-white">Reactions</div>
                          <label class="relative inline-flex items-center cursor-pointer">
                            <input
                              type="checkbox"
                              checked={@reactions_enabled}
                              class="sr-only peer"
                              phx-click="toggle_reactions"
                            >
                            <div class="w-11 h-6 bg-gray-700 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
                          </label>
                        </div>

                        <%= if @audio_engine_active do %>
                          <div class="flex items-center justify-between bg-gray-800 p-3 rounded-lg">
                            <div class="text-white">Audio Recording</div>
                            <label class="relative inline-flex items-center cursor-pointer">
                              <input
                                type="checkbox"
                                checked={@recording_active}
                                class="sr-only peer"
                                phx-click="toggle_recording"
                              >
                              <div class="w-11 h-6 bg-gray-700 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-red-600"></div>
                            </label>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>

              <% _ -> %>
                <div class="flex-1 flex items-center justify-center">
                  <div class="text-center">
                    <p class="text-gray-400">Select a tab to view content</p>
                  </div>
                </div>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
