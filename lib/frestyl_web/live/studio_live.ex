defmodule FrestylWeb.StudioLive do
  use FrestylWeb, :live_view

  alias Frestyl.Accounts
  alias Frestyl.Channels
  alias Frestyl.Media
  alias Frestyl.Sessions
  alias Frestyl.Presence
  alias Frestyl.Chat
  alias Frestyl.Collaboration.OperationalTransform, as: OT
  alias Frestyl.Collaboration.OperationalTransform.{TextOp, AudioOp, VisualOp}
  alias FrestylWeb.AccessibilityComponents, as: A11y
  alias Phoenix.PubSub
  alias Frestyl.Studio.AudioEngine
  alias Frestyl.Studio.BeatMachine
  alias Frestyl.Studio.RecordingEngine
  alias FrestylWeb.StudioLive.RecordingComponent

  # Enhanced default workspace state with OT support
  @default_workspace_state %{
    audio: %{
      tracks: [],
      selected_track: nil,
      recording: false,
      playing: false,
      current_time: 0,
      zoom_level: 1.0,
      track_counter: 0,  # Global counter for unique numbering
      version: 0  # Version for OT
    },
    midi: %{
      notes: [],
      selected_notes: [],
      current_instrument: "piano",
      octave: 4,
      grid_size: 16,
      version: 0
    },
    text: %{
      content: "",
      cursors: %{},
      selection: nil,
      version: 0,  # Critical for OT text operations
      pending_operations: []  # Queue for unacknowledged operations
    },
    visual: %{
      elements: [],
      selected_element: nil,
      tool: "brush",
      brush_size: 5,
      color: "#4f46e5",
      version: 0
    },
    beat_machine: %{
      current_kit: "classic_808",
      patterns: %{},
      active_pattern: nil,
      playing: false,
      current_step: 0,
      bpm: 120,
      swing: 0,
      master_volume: 0.8,
      pattern_counter: 0,
      version: 0
    },
    # OT state management
    ot_state: %{
      user_operations: %{},  # Track operations by user
      operation_queue: [],   # Queue of operations to apply
      acknowledged_ops: MapSet.new(),  # Operations that have been acknowledged
      local_version: 0,      # Local state version
      server_version: 0      # Last known server version
    }
  }

  defp is_mobile_device?(user_agent) do
    mobile_patterns = [
      ~r/Android/i,
      ~r/webOS/i,
      ~r/iPhone/i,
      ~r/iPad/i,
      ~r/iPod/i,
      ~r/BlackBerry/i,
      ~r/IEMobile/i,
      ~r/Opera Mini/i
    ]

    Enum.any?(mobile_patterns, &Regex.match?(&1, user_agent || ""))
  end

  @impl true
  def mount(%{"channel_slug" => channel_slug, "session_id" => session_id} = params, session, socket) do
    current_user = session["user_token"] && Accounts.get_user_by_session_token(session["user_token"])

    if current_user do
      channel = Channels.get_channel_by_slug(channel_slug)

      if channel do
        session_data = Sessions.get_session(session_id)

        if session_data do
          # Get device info early, before the connected? check
          user_agent = if connected?(socket), do: get_connect_info(socket, :user_agent), else: nil
          is_mobile = is_mobile_device?(user_agent)
          device_info = get_device_info(user_agent, socket)

          if connected?(socket) do
            # Subscribe to OT-specific topics
            PubSub.subscribe(Frestyl.PubSub, "studio:#{session_id}")
            PubSub.subscribe(Frestyl.PubSub, "studio:#{session_id}:operations")
            PubSub.subscribe(Frestyl.PubSub, "user:#{current_user.id}")
            PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}:chat")
            PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")
            PubSub.subscribe(Frestyl.PubSub, "beat_machine:#{session_id}")
            # Subscribe to mobile-specific audio events
            PubSub.subscribe(Frestyl.PubSub, "mobile_audio:#{session_id}")

            # Track presence with OT metadata and mobile info
            {:ok, _} = Presence.track(self(), "studio:#{session_id}", current_user.id, %{
              user_id: current_user.id,
              username: current_user.username,
              avatar_url: current_user.avatar_url,
              joined_at: DateTime.utc_now(),
              active_tool: "audio",
              is_typing: false,
              last_activity: DateTime.utc_now(),
              ot_version: 0,  # Track OT version for each user
              is_recording: false,
              input_level: 0,
              active_audio_track: nil,
              audio_monitoring: false,
              # Mobile-specific presence data
              is_mobile: is_mobile,
              device_type: device_info.device_type,
              screen_size: device_info.screen_size,
              supports_audio: device_info.supports_audio,
              battery_optimized: false,
              current_mobile_track: 0
            })

            # Initialize OT state for this user
            send(self(), {:initialize_ot_state})
          end

          # Start appropriate audio engine based on device
          start_audio_engine(session_id, is_mobile)

          role = determine_user_role(session_data, current_user)
          permissions = get_permissions_for_role(role, session_data.session_type)

          workspace_state = get_workspace_state(session_id) || @default_workspace_state
          workspace_state = ensure_ot_state(workspace_state)

          collaborators = list_collaborators(session_id)
          chat_messages = Sessions.list_session_messages(session_id)

          active_tool = case session_data.session_type do
            "audio" -> "audio"
            "text" -> "text"
            "visual" -> "visual"
            "midi" -> "midi"
            _ -> "audio"
          end

          # Get user tier for audio engine configuration
          user_tier = get_user_audio_tier(current_user)
          audio_config = get_audio_engine_config(user_tier, is_mobile)

          socket = socket
            |> assign(:current_user, current_user)
            |> assign(:channel, channel)
            |> assign(:session, session_data)
            |> assign(:role, role)
            |> assign(:permissions, permissions)
            |> assign(:page_title, session_data.title || "Untitled Session")
            |> assign(:workspace_state, workspace_state)
            |> assign(:active_tool, active_tool)
            |> assign(:collaborators, collaborators)
            |> assign(:chat_messages, chat_messages)
            |> assign(:message_input, "")
            |> assign(:show_invite_modal, false)
            |> assign(:show_settings_modal, false)
            |> assign(:show_export_modal, false)
            |> assign(:media_items, list_media_items(session_id))
            |> assign(:tools, get_available_tools(permissions))
            |> assign(:rtc_token, generate_rtc_token(current_user.id, session_id))
            |> assign(:connection_status, "connecting")
            |> assign(:notifications, [])
            |> assign(:recorded_chunks, [])
            |> assign(:show_end_session_modal, false)
            # OT-specific assigns
            |> assign(:pending_operations, [])
            |> assign(:operation_conflicts, [])
            |> assign(:ot_debug_mode, false)
            |> assign(:typing_users, MapSet.new())
            |> assign(:recording_track, nil)
            |> assign(:audio_engine_state, get_audio_engine_state(session_id))
            |> assign(:beat_machine_state, get_beat_machine_state(session_id))
            |> assign(:recording_enabled, true)
            |> assign(:recording_mode, false)
            |> assign(:user_channels, Channels.list_user_channels(current_user.id))
            |> assign(:export_credits, get_user_export_credits(current_user))
            # Mobile-specific assigns
            |> assign(:is_mobile, is_mobile)
            |> assign(:device_info, device_info)
            |> assign(:audio_config, audio_config)
            |> assign(:user_tier, user_tier)
            |> assign(:current_mobile_track, 0)
            |> assign(:mobile_capabilities, %{})
            |> assign(:selected_track_id, get_first_track_id(workspace_state))

          {:ok, socket}
        else
          {:ok, socket
            |> put_flash(:error, "Session not found")
            |> push_redirect(to: ~p"/channels/#{channel_slug}")}
        end
      else
        {:ok, socket
          |> put_flash(:error, "Channel not found")
          |> push_redirect(to: ~p"/dashboard")}
      end
    else
      {:ok, socket
        |> put_flash(:error, "You must be logged in to access this page")
        |> push_redirect(to: ~p"/users/log_in")}
    end
  end

  # Helper functions to add to your StudioLive module

  defp is_mobile_device?(user_agent) when is_binary(user_agent) do
    mobile_patterns = [
      ~r/Android/i,
      ~r/webOS/i,
      ~r/iPhone/i,
      ~r/iPad/i,
      ~r/iPod/i,
      ~r/BlackBerry/i,
      ~r/IEMobile/i,
      ~r/Opera Mini/i,
      ~r/Mobile/i
    ]

    Enum.any?(mobile_patterns, &Regex.match?(&1, user_agent))
  end

  defp get_device_info(user_agent, socket) do
    is_mobile = is_mobile_device?(user_agent)

    device_type = cond do
      is_nil(user_agent) -> "unknown"
      Regex.match?(~r/iPad/i, user_agent) -> "tablet"
      Regex.match?(~r/iPhone|iPod/i, user_agent) -> "phone"
      Regex.match?(~r/Android.*Mobile/i, user_agent) -> "phone"
      Regex.match?(~r/Android/i, user_agent) -> "tablet"
      is_mobile -> "mobile"
      true -> "desktop"
    end

    # Estimate screen size based on device type
    screen_size = case device_type do
      "phone" -> "small"
      "tablet" -> "medium"
      "desktop" -> "large"
      _ -> "unknown"
    end

    # Check for modern audio support
    supports_audio = not Regex.match?(~r/Opera Mini|UC Browser/i, user_agent || "")

    %{
      device_type: device_type,
      screen_size: screen_size,
      supports_audio: supports_audio,
      user_agent: user_agent,
      is_mobile: is_mobile
    }
  end

  defp get_user_audio_tier(user) do
    # Determine user's audio tier based on subscription, etc.
    # This would integrate with your existing subscription system
    case user.subscription_tier do
      "pro" -> :pro
      "premium" -> :premium
      _ -> :free
    end
  end

  defp get_audio_engine_config(user_tier, is_mobile) do
    base_config = case user_tier do
      :pro -> %{
        sample_rate: 48000,
        buffer_size: if(is_mobile, do: 512, else: 256),
        max_tracks: if(is_mobile, do: 4, else: 16),
        effects_enabled: true,
        monitoring_enabled: true,
        quality: "high"
      }
      :premium -> %{
        sample_rate: 44100,
        buffer_size: if(is_mobile, do: 512, else: 256),
        max_tracks: if(is_mobile, do: 4, else: 8),
        effects_enabled: true,
        monitoring_enabled: true,
        quality: "medium"
      }
      :free -> %{
        sample_rate: 44100,
        buffer_size: if(is_mobile, do: 1024, else: 512),
        max_tracks: if(is_mobile, do: 2, else: 4),
        effects_enabled: if(is_mobile, do: false, else: true),
        monitoring_enabled: true,
        quality: "basic"
      }
    end

    # Mobile-specific optimizations
    if is_mobile do
      Map.merge(base_config, %{
        update_frequency: 30, # 30fps instead of 60fps
        battery_optimized: true,
        simplified_effects: true,
        reduced_monitoring: true
      })
    else
      base_config
    end
  end

  defp start_audio_engine(session_id, is_mobile \\ false) do
    # Start appropriate audio engine based on device
    engine_module = if is_mobile, do: Frestyl.Studio.MobileAudioEngine, else: Frestyl.Studio.AudioEngine

    case DynamicSupervisor.start_child(
      Frestyl.Studio.AudioEngineSupervisor,
      {engine_module, session_id}
    ) do
      {:ok, _pid} ->
        # Also start beat machine if not mobile or if user has premium+
        unless is_mobile do
          DynamicSupervisor.start_child(
            Frestyl.Studio.BeatMachineSupervisor,
            {BeatMachine, session_id}
          )
        end
        :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} ->
        Logger.error("Failed to start audio engine: #{inspect(reason)}")
        :error
    end
  end

  defp get_first_track_id(workspace_state) do
    case workspace_state.audio.tracks do
      [first_track | _] -> first_track.id
      [] -> nil
    end
  end

  # Add mobile-specific event handlers

  @impl true
  def handle_event("mobile_audio_initialized", %{"capabilities" => caps, "config" => config}, socket) do
    Logger.info("Mobile audio initialized: #{inspect(caps)}")

    {:noreply, socket
      |> assign(:mobile_capabilities, caps)
      |> add_notification("Mobile audio engine ready", :success)}
  end

  @impl true
  def handle_event("mobile_track_changed", %{"track_index" => index}, socket) do
    # Update current mobile track
    {:noreply, assign(socket, :current_mobile_track, index)}
  end

  @impl true
  def handle_event("mobile_track_volume_change", %{"track_index" => index, "volume" => volume}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      track_id = get_track_id_by_index(socket, index)

      case AudioEngine.update_track_volume(socket.assigns.session.id, track_id, volume) do
        :ok ->
          {:noreply, socket}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to update volume: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mobile_master_volume_change", %{"volume" => volume}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      case AudioEngine.set_master_volume(socket.assigns.session.id, volume) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to update master volume")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mobile_toggle_effect", %{"track_index" => index, "effect_type" => effect_type}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      track_id = get_track_id_by_index(socket, index)

      # Check if effect is already applied, toggle it
      current_effects = get_track_effects(socket, track_id)

      if Enum.any?(current_effects, &(&1.type == effect_type)) do
        # Remove effect
        effect_id = Enum.find(current_effects, &(&1.type == effect_type)).id
        case AudioEngine.remove_effect_from_track(socket.assigns.session.id, track_id, effect_id) do
          :ok -> {:noreply, socket |> add_notification("#{String.capitalize(effect_type)} removed", :info)}
          {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to remove effect")}
        end
      else
        # Add effect with mobile-optimized parameters
        mobile_params = get_mobile_effect_params(effect_type)
        case AudioEngine.apply_effect(socket.assigns.session.id, track_id, effect_type, mobile_params) do
          {:ok, _effect} -> {:noreply, socket |> add_notification("#{String.capitalize(effect_type)} applied", :success)}
          {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to apply effect")}
        end
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mobile_start_recording", %{"track_index" => index}, socket) do
    if can_record_audio?(socket.assigns.permissions) do
      track_id = get_track_id_by_index(socket, index)
      user_id = socket.assigns.current_user.id

      case AudioEngine.start_recording(socket.assigns.session.id, track_id, user_id) do
        {:ok, _} ->
          {:noreply, socket
            |> assign(:recording_track, track_id)
            |> add_notification("Recording started", :success)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to start recording: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mobile_stop_recording", %{"track_index" => index}, socket) do
    track_id = get_track_id_by_index(socket, index)
    user_id = socket.assigns.current_user.id

    case AudioEngine.stop_recording(socket.assigns.session.id, track_id, user_id) do
      {:ok, _clip} ->
        {:noreply, socket
          |> assign(:recording_track, nil)
          |> add_notification("Recording stopped", :info)}
      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to stop recording: #{reason}")}
    end
  end

  @impl true
  def handle_event("mobile_mute_all_tracks", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      # Mute all tracks
      Enum.each(socket.assigns.workspace_state.audio.tracks, fn track ->
        AudioEngine.mute_track(session_id, track.id, true)
      end)

      {:noreply, socket |> add_notification("All tracks muted", :info)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mobile_solo_track", %{"track_index" => index}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      track_id = get_track_id_by_index(socket, index)

      case AudioEngine.solo_track(socket.assigns.session.id, track_id, true) do
        :ok -> {:noreply, socket |> add_notification("Track soloed", :info)}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to solo track")}
      end
    else
      {:noreply, socket}
    end
  end

  # Helper functions for mobile events

  defp get_track_id_by_index(socket, index) do
    tracks = socket.assigns.workspace_state.audio.tracks
    case Enum.at(tracks, index) do
      nil -> nil
      track -> track.id
    end
  end

  defp get_track_effects(socket, track_id) do
    tracks = socket.assigns.workspace_state.audio.tracks
    case Enum.find(tracks, &(&1.id == track_id)) do
      nil -> []
      track -> track.effects || []
    end
  end

  defp get_mobile_effect_params(effect_type) do
    # Mobile-optimized effect parameters for better performance
    case effect_type do
      "reverb" -> %{wet: 0.2, dry: 0.8, room_size: 0.3, decay: 1.5}
      "eq" -> %{low_gain: 0, mid_gain: 0, high_gain: 0}
      "compressor" -> %{threshold: -12, ratio: 4, attack: 0.01, release: 0.1}
      "delay" -> %{time: 0.25, feedback: 0.3, wet: 0.2}
      "distortion" -> %{drive: 3, level: 0.7, amount: 25}
      _ -> %{}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket |> assign(:page_title, "#{socket.assigns.session.title} | Studio")
  end

  defp apply_action(socket, :edit_session, _params) do
    if can_edit_session?(socket.assigns.permissions) do
      socket |> assign(:page_title, "Edit Session | #{socket.assigns.session.title}")
    else
      socket
      |> put_flash(:error, "You don't have permission to edit this session")
      |> push_redirect(to: ~p"/channels/#{socket.assigns.channel.slug}")
    end
  end

  # NEW: Track mute/solo controls with OT
  @impl true
  def handle_event("audio_toggle_track_mute", %{"track_id" => track_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      toggle_track_property(socket, track_id, :muted, "mute")
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to modify tracks")}
    end
  end

  @impl true
  def handle_event("audio_toggle_track_solo", %{"track_id" => track_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      toggle_track_property(socket, track_id, :solo, "solo")
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to modify tracks")}
    end
  end

  # Helper function for toggling track properties
  defp toggle_track_property(socket, track_id, property, property_name) do
    user_id = socket.assigns.current_user.id
    session_id = socket.assigns.session.id
    workspace_state = socket.assigns.workspace_state

    # Find the track and toggle the property
    track = Enum.find(workspace_state.audio.tracks, &(&1.id == track_id))

    if track do
      current_value = Map.get(track, property, false)
      new_value = !current_value

      # Create OT operation for property update
      property_update = %{property => new_value}
      operation = AudioOp.new(:update_track_property, property_update, user_id, track_id: track_id)

      # Apply operation locally
      new_workspace_state = OT.apply_operation(workspace_state, operation)

      # Add to pending operations
      pending_ops = [operation | socket.assigns.pending_operations]

      # Broadcast operation
      PubSub.broadcast(
        Frestyl.PubSub,
        "studio:#{session_id}:operations",
        {:new_operation, operation}
      )

      # Save state
      Task.start(fn ->
        save_workspace_state(session_id, new_workspace_state)
        PubSub.broadcast(
          Frestyl.PubSub,
          "studio:#{session_id}:operations",
          {:operation_acknowledged, operation.timestamp, user_id}
        )
      end)

      action_text = if new_value, do: "#{String.capitalize(property_name)}d", else: "Un#{property_name}d"

      {:noreply, socket
        |> assign(workspace_state: new_workspace_state)
        |> assign(pending_operations: pending_ops)
        |> add_notification("#{action_text} #{track.name}", :info)}
    else
      {:noreply, socket |> put_flash(:error, "Track not found")}
    end
  end

  # NEW: Audio track deletion with OT
  @impl true
  def handle_event("audio_delete_track", %{"track_id" => track_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id
      workspace_state = socket.assigns.workspace_state

      # Find the track to delete
      track_to_delete = Enum.find(workspace_state.audio.tracks, &(&1.id == track_id))

      if track_to_delete do
        # Create OT operation for track deletion
        operation = AudioOp.new(:delete_track, track_to_delete, user_id, track_id: track_id)

        # Apply operation locally (optimistic update)
        new_workspace_state = OT.apply_operation(workspace_state, operation)

        # Add to pending operations
        pending_ops = [operation | socket.assigns.pending_operations]

        # Broadcast operation to other users
        PubSub.broadcast(
          Frestyl.PubSub,
          "studio:#{session_id}:operations",
          {:new_operation, operation}
        )

        # Save state and acknowledge operation
        Task.start(fn ->
          save_workspace_state(session_id, new_workspace_state)
          PubSub.broadcast(
            Frestyl.PubSub,
            "studio:#{session_id}:operations",
            {:operation_acknowledged, operation.timestamp, user_id}
          )
        end)

        {:noreply, socket
          |> assign(workspace_state: new_workspace_state)
          |> assign(pending_operations: pending_ops)
          |> add_notification("Deleted #{track_to_delete.name}", :info)}
      else
        {:noreply, socket |> put_flash(:error, "Track not found")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to delete tracks")}
    end
  end

  # ENHANCED: Audio track addition with OT
  @impl true
  def handle_event("audio_add_track", _, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id
      workspace_state = socket.assigns.workspace_state

      # Get current track counter (thread-safe)
      current_counter = workspace_state.audio.track_counter
      new_track_number = current_counter + 1

      # Create new track
      new_track = %{
        id: "track-#{System.unique_integer([:positive])}",
        number: new_track_number,
        name: "Track #{new_track_number}",
        clips: [],
        muted: false,
        solo: false,
        volume: 0.8,
        pan: 0.0,
        created_by: user_id,
        created_at: DateTime.utc_now()
      }

      # Create OT operation
      operation = AudioOp.new(:add_track, new_track, user_id, track_counter: new_track_number)

      # Apply operation locally (optimistic update)
      new_workspace_state = OT.apply_operation(workspace_state, operation)

      # Add to pending operations
      pending_ops = [operation | socket.assigns.pending_operations]

      # Broadcast operation to other users
      PubSub.broadcast(
        Frestyl.PubSub,
        "studio:#{session_id}:operations",
        {:new_operation, operation}
      )

      # Save state and acknowledge operation
      Task.start(fn ->
        save_workspace_state(session_id, new_workspace_state)
        # Acknowledge operation after save
        PubSub.broadcast(
          Frestyl.PubSub,
          "studio:#{session_id}:operations",
          {:operation_acknowledged, operation.timestamp, user_id}
        )
      end)

      {:noreply, socket
        |> assign(workspace_state: new_workspace_state)
        |> assign(pending_operations: pending_ops)
        |> add_notification("Added Track #{new_track_number}", :success)}
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to add tracks")}
    end
  end

  # Audio track management
  @impl true
  def handle_event("audio_add_track", %{"name" => name}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id

      case AudioEngine.add_track(session_id, user_id, %{name: name}) do
        {:ok, track} ->
          {:noreply, socket |> add_notification("Added #{track.name}", :success)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to add track: #{reason}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to add tracks")}
    end
  end

  @impl true
  def handle_event("toggle_recording_mode", _, socket) do
    new_recording_mode = !socket.assigns.recording_mode

    # Start/stop recording engine if needed
    if new_recording_mode do
      case start_recording_engine(socket.assigns.session.id) do
        :ok ->
          {:noreply, assign(socket, recording_mode: true)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to start recording: #{reason}")}
      end
    else
      {:noreply, assign(socket, recording_mode: false)}
    end
  end

  @impl true
  def handle_event("audio_start_recording", %{"track_id" => track_id}, socket) do
    if can_record_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id

      # Update presence to show recording
      update_presence(session_id, user_id, %{
        is_recording: true,
        active_audio_track: track_id,
        last_activity: DateTime.utc_now()
      })

      {:noreply, socket |> assign(:recording_track, track_id)}
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to record")}
    end
  end

  @impl true
  def handle_event("audio_stop_recording", _params, socket) do
    user_id = socket.assigns.current_user.id
    session_id = socket.assigns.session.id

    # Update presence to stop recording
    update_presence(session_id, user_id, %{
      is_recording: false,
      active_audio_track: nil,
      last_activity: DateTime.utc_now()
    })

    {:noreply, socket |> assign(:recording_track, nil)}
  end

  @impl true
  def handle_event("audio_update_track_volume", %{"track_id" => track_id, "volume" => volume}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.update_track_volume(session_id, track_id, volume) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to update volume: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("audio_mute_track", %{"track_id" => track_id, "muted" => muted}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.mute_track(session_id, track_id, muted) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to mute track: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("audio_solo_track", %{"track_id" => track_id, "solo" => solo}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.solo_track(session_id, track_id, solo) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to solo track: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("audio_delete_track", %{"track_id" => track_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.delete_track(session_id, track_id) do
        :ok ->
          {:noreply, socket |> add_notification("Track deleted", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to delete track: #{reason}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to delete tracks")}
    end
  end

  # Transport controls
  @impl true
  def handle_event("audio_start_playback", %{"position" => position}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      position = String.to_float(position || "0")

      case AudioEngine.start_playback(session_id, position) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to start playback: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("audio_stop_playback", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.stop_playback(session_id) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to stop playback: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  # Beat machine controls
  @impl true
  def handle_event("beat_create_pattern", %{"name" => name, "steps" => steps}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      steps = String.to_integer(steps || "16")

      case BeatMachine.create_pattern(session_id, name, steps) do
        {:ok, pattern} ->
          {:noreply, socket |> add_notification("Created pattern: #{pattern.name}", :success)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to create pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_update_step", %{"pattern_id" => pattern_id, "instrument" => instrument, "step" => step, "velocity" => velocity}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      step = String.to_integer(step)
      velocity = String.to_integer(velocity)

      case BeatMachine.update_pattern_step(session_id, pattern_id, instrument, step, velocity) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to update step: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_play_pattern", %{"pattern_id" => pattern_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.play_pattern(session_id, pattern_id) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to play pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_stop_pattern", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.stop_pattern(session_id) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to stop pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_change_kit", %{"kit_name" => kit_name}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.change_kit(session_id, kit_name) do
        :ok ->
          {:noreply, socket |> add_notification("Changed to #{kit_name} kit", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to change kit: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  # Input level monitoring
  @impl true
  def handle_event("audio_input_level", %{"level" => level}, socket) do
    user_id = socket.assigns.current_user.id
    session_id = socket.assigns.session.id

    # Update presence with input level
    update_presence(session_id, user_id, %{
      input_level: level,
      last_activity: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  # ENHANCED: Text editing with OT
  @impl true
  def handle_event("text_update", %{"content" => new_content, "selection" => selection}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id
      workspace_state = socket.assigns.workspace_state

      current_content = workspace_state.text.content

      # Generate text operations (diff between old and new content)
      text_ops = generate_text_operations(current_content, new_content)

      if length(text_ops) > 0 do
        # Create OT operation
        current_version = workspace_state.text.version
        operation = TextOp.new(text_ops, user_id, current_version)

        # Apply operation locally
        new_workspace_state = OT.apply_operation(workspace_state, operation)

        # Update cursors
        text_state = new_workspace_state.text
        new_cursors = Map.put(text_state.cursors, user_id, selection)
        new_text_state = %{text_state | cursors: new_cursors}
        new_workspace_state = Map.put(new_workspace_state, :text, new_text_state)

        # Add to pending operations
        pending_ops = [operation | socket.assigns.pending_operations]

        # Broadcast operation
        PubSub.broadcast(
          Frestyl.PubSub,
          "studio:#{session_id}:operations",
          {:new_operation, operation}
        )

        # Save state
        Task.start(fn ->
          save_workspace_state(session_id, new_workspace_state)
          PubSub.broadcast(
            Frestyl.PubSub,
            "studio:#{session_id}:operations",
            {:operation_acknowledged, operation.timestamp, user_id}
          )
        end)

        {:noreply, socket
          |> assign(workspace_state: new_workspace_state)
          |> assign(pending_operations: pending_ops)}
      else
        # No text changes, just update cursor
        text_state = workspace_state.text
        new_cursors = Map.put(text_state.cursors, user_id, selection)
        new_text_state = %{text_state | cursors: new_cursors}
        new_workspace_state = Map.put(workspace_state, :text, new_text_state)

        {:noreply, assign(socket, workspace_state: new_workspace_state)}
      end
    else
      {:noreply, socket}
    end
  end

  # Enhanced chat integration using existing chat system
  @impl true
  def handle_event("send_session_message", %{"message" => message}, socket) when message != "" do
    user = socket.assigns.current_user
    session_id = socket.assigns.session.id

    # Create message using existing Sessions context
    message_params = %{
      content: message,
      user_id: user.id,
      session_id: session_id,
      message_type: "text"
    }

    case Sessions.create_message(message_params) do
      {:ok, new_message} ->
        # Broadcast using existing chat pattern
        message_data = %{
          id: new_message.id,
          content: new_message.content,
          user_id: new_message.user_id,
          username: user.username,
          avatar_url: user.avatar_url,
          inserted_at: new_message.inserted_at
        }

        PubSub.broadcast(Frestyl.PubSub, "session:#{session_id}:chat", {:new_message, message_data})

        # Update typing status
        update_presence(session_id, user.id, %{is_typing: false})

        {:noreply, assign(socket, message_input: "")}

      {:error, _changeset} ->
        {:noreply, socket |> put_flash(:error, "Could not send message")}
    end
  end

  # Enhanced typing indicators
  @impl true
  def handle_event("typing_start", _, socket) do
    if socket.assigns.session do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id

      # Broadcast typing status to chat
      PubSub.broadcast(
        Frestyl.PubSub,
        "session:#{session_id}:chat",
        {:user_typing, user_id, true}
      )

      # Update presence
      update_presence(session_id, user_id, %{is_typing: true, last_activity: DateTime.utc_now()})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("typing_stop", _, socket) do
    if socket.assigns.session do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id

      PubSub.broadcast(
        Frestyl.PubSub,
        "session:#{session_id}:chat",
        {:user_typing, user_id, false}
      )

      update_presence(session_id, user_id, %{is_typing: false, last_activity: DateTime.utc_now()})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_message_input", %{"value" => value}, socket) do
    user = socket.assigns.current_user
    session_id = socket.assigns.session.id

    is_typing = value != ""
    update_presence(session_id, user.id, %{is_typing: is_typing, last_activity: DateTime.utc_now()})

    {:noreply, assign(socket, message_input: value)}
  end

  @impl true
  def handle_event("set_active_tool", %{"tool" => tool}, socket) do
    update_presence(socket.assigns.session.id, socket.assigns.current_user.id, %{active_tool: tool})
    {:noreply, assign(socket, active_tool: tool)}
  end

  @impl true
  def handle_event("toggle_invite_modal", _, socket) do
    {:noreply, assign(socket, show_invite_modal: !socket.assigns.show_invite_modal)}
  end

  @impl true
  def handle_event("toggle_settings_modal", _, socket) do
    {:noreply, assign(socket, show_settings_modal: !socket.assigns.show_settings_modal)}
  end

  @impl true
  def handle_event("end_session", _, socket) do
    {:noreply, assign(socket, show_end_session_modal: true)}
  end

  @impl true
  def handle_event("cancel_end_session", _, socket) do
    {:noreply, assign(socket, show_end_session_modal: false)}
  end

  @impl true
  def handle_event("end_session_confirmed", _, socket) do
    session_data = socket.assigns.session

    case Sessions.end_session(session_data.id, socket.assigns.current_user.id) do
      {:ok, _updated_session} ->
        {:noreply, socket
          |> put_flash(:info, "Session ended successfully.")
          |> push_redirect(to: ~p"/channels/#{socket.assigns.channel.slug}")}

      {:error, reason} ->
        {:noreply, socket
          |> assign(show_end_session_modal: false)
          |> put_flash(:error, "Could not end session: #{reason}")}
    end
  end

  # Debug event for OT troubleshooting
  @impl true
  def handle_event("toggle_ot_debug", _, socket) do
    new_debug_mode = !socket.assigns.ot_debug_mode
    {:noreply, assign(socket, ot_debug_mode: new_debug_mode)}
  end

  @impl true
  def handle_event("clear_conflicts", _, socket) do
    {:noreply, assign(socket, operation_conflicts: [])}
  end

  # Beat machine handlers
  @impl true
  def handle_event("beat_create_pattern", %{"name" => name, "steps" => steps}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      steps = String.to_integer(steps || "16")

      case BeatMachine.create_pattern(session_id, name, steps) do
        {:ok, pattern} ->
          {:noreply, socket |> add_notification("Created pattern: #{pattern.name}", :success)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to create pattern: #{reason}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to create patterns")}
    end
  end

  @impl true
  def handle_event("beat_update_step", %{"pattern_id" => pattern_id, "instrument" => instrument, "step" => step, "velocity" => velocity}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      step = String.to_integer(step)
      velocity = String.to_integer(velocity)

      case BeatMachine.update_pattern_step(session_id, pattern_id, instrument, step, velocity) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to update step: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_clear_step", %{"pattern_id" => pattern_id, "instrument" => instrument, "step" => step}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      step = String.to_integer(step)

      case BeatMachine.clear_pattern_step(session_id, pattern_id, instrument, step) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to clear step: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_play_pattern", %{"pattern_id" => pattern_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.play_pattern(session_id, pattern_id) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to play pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_stop_pattern", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.stop_pattern(session_id) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to stop pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_change_kit", %{"kit_name" => kit_name}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.change_kit(session_id, kit_name) do
        :ok ->
          {:noreply, socket |> add_notification("Changed to #{kit_name} kit", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to change kit: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_set_bpm", %{"bpm" => bpm}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      bpm = String.to_integer(bpm)

      case BeatMachine.set_bpm(session_id, bpm) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to set BPM: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_set_swing", %{"swing" => swing}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      swing = String.to_integer(swing)

      case BeatMachine.set_swing(session_id, swing) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to set swing: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_duplicate_pattern", %{"pattern_id" => pattern_id, "new_name" => new_name}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.duplicate_pattern(session_id, pattern_id, new_name) do
        {:ok, pattern} ->
          {:noreply, socket |> add_notification("Duplicated pattern: #{pattern.name}", :success)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to duplicate pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_delete_pattern", %{"pattern_id" => pattern_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.delete_pattern(session_id, pattern_id) do
        :ok ->
          {:noreply, socket |> add_notification("Pattern deleted", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to delete pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_randomize_pattern", %{"pattern_id" => pattern_id} = params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      instruments = Map.get(params, "instruments") # Optional - randomize specific instruments

      case BeatMachine.randomize_pattern(session_id, pattern_id, instruments) do
        :ok ->
          {:noreply, socket |> add_notification("Pattern randomized", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to randomize pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_clear_pattern", %{"pattern_id" => pattern_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.clear_pattern(session_id, pattern_id) do
        :ok ->
          {:noreply, socket |> add_notification("Pattern cleared", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to clear pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("beat_set_master_volume", %{"volume" => volume}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      volume = String.to_float(volume)

      case BeatMachine.set_master_volume(session_id, volume) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to set volume: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  #Beat machine message handlers
  @impl true
  def handle_info({:beat_machine, {:pattern_created, pattern}}, socket) do
    username = get_username_from_collaborators(pattern.created_by, socket.assigns.collaborators)
    message = "#{username} created pattern: #{pattern.name}"

    # Update workspace state with new pattern
    update_beat_workspace_state(socket, "pattern_created", pattern)

    {:noreply, socket
      |> add_notification(message, :success)
      |> push_event("beat_pattern_created", %{pattern: pattern})}
  end

  @impl true
  def handle_info({:beat_machine, {:step_updated, pattern_id, instrument, step, velocity}}, socket) do
    {:noreply, socket |> push_event("beat_step_updated", %{
      pattern_id: pattern_id,
      instrument: instrument,
      step: step,
      velocity: velocity
    })}
  end

  @impl true
  def handle_info({:beat_machine, {:pattern_started, pattern_id}}, socket) do
    {:noreply, socket |> push_event("beat_pattern_started", %{pattern_id: pattern_id})}
  end

  @impl true
  def handle_info({:beat_machine, {:pattern_stopped}}, socket) do
    {:noreply, socket |> push_event("beat_pattern_stopped", %{})}
  end

  @impl true
  def handle_info({:beat_machine, {:step_triggered, step, instruments}}, socket) do
    {:noreply, socket |> push_event("beat_step_triggered", %{
      step: step,
      instruments: instruments
    })}
  end

  @impl true
  def handle_info({:beat_machine, {:kit_changed, kit_name, kit}}, socket) do
    username = get_username_from_collaborators("system", socket.assigns.collaborators) # Handle kit changes
    message = "Drum kit changed to #{kit_name}"

    {:noreply, socket
      |> add_notification(message, :info)
      |> push_event("beat_kit_changed", %{kit_name: kit_name, kit: kit})}
  end

  @impl true
  def handle_info({:beat_machine, {:bpm_changed, bpm}}, socket) do
    {:noreply, socket |> push_event("beat_bpm_changed", %{bpm: bpm})}
  end

  @impl true
  def handle_info({:beat_machine, {:swing_changed, swing}}, socket) do
    {:noreply, socket |> push_event("beat_swing_changed", %{swing: swing})}
  end

  @impl true
  def handle_info({:beat_machine, {:pattern_duplicated, pattern}}, socket) do
    username = get_username_from_collaborators(pattern.created_by, socket.assigns.collaborators)
    message = "#{username} duplicated pattern: #{pattern.name}"

    {:noreply, socket
      |> add_notification(message, :info)
      |> push_event("beat_pattern_duplicated", %{pattern: pattern})}
  end

  @impl true
  def handle_info({:beat_machine, {:pattern_deleted, pattern_id}}, socket) do
    {:noreply, socket |> push_event("beat_pattern_deleted", %{pattern_id: pattern_id})}
  end

  @impl true
  def handle_info({:beat_machine, {:pattern_randomized, pattern_id, sequences}}, socket) do
    {:noreply, socket |> push_event("beat_pattern_randomized", %{
      pattern_id: pattern_id,
      sequences: sequences
    })}
  end

  @impl true
  def handle_info({:beat_machine, {:pattern_cleared, pattern_id}}, socket) do
    {:noreply, socket |> push_event("beat_pattern_cleared", %{pattern_id: pattern_id})}
  end

  @impl true
  def handle_info({:beat_machine, {:master_volume_changed, volume}}, socket) do
    {:noreply, socket |> push_event("beat_master_volume_changed", %{volume: volume})}
  end

  # ENHANCED: Handle incoming operations from other users
  @impl true
  def handle_info({:new_operation, remote_operation}, socket) do
    # Don't process our own operations
    if remote_operation.user_id != socket.assigns.current_user.id do
      current_workspace = socket.assigns.workspace_state
      pending_ops = socket.assigns.pending_operations

      # Transform remote operation against pending local operations
      {transformed_remote_op, transformed_local_ops} =
        transform_against_pending_operations(remote_operation, pending_ops)

      # Apply transformed remote operation
      new_workspace_state = OT.apply_operation(current_workspace, transformed_remote_op)

      # Check for conflicts
      conflicts = detect_conflicts(transformed_remote_op, transformed_local_ops)

      socket = socket
        |> assign(workspace_state: new_workspace_state)
        |> assign(pending_operations: transformed_local_ops)

      # Notify about the update
      username = get_username_from_collaborators(remote_operation.user_id, socket.assigns.collaborators)
      message = format_operation_message(remote_operation, username)

      socket = if message do
        add_notification(socket, message, :info)
      else
        socket
      end

      # Handle conflicts
      socket = if length(conflicts) > 0 do
        socket
        |> assign(operation_conflicts: conflicts)
        |> add_notification("Some changes conflicted and were automatically merged", :warning)
      else
        socket
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Handle operation acknowledgments
  @impl true
  def handle_info({:operation_acknowledged, timestamp, user_id}, socket) do
    if user_id == socket.assigns.current_user.id do
      # Remove acknowledged operation from pending list
      pending_ops = Enum.reject(socket.assigns.pending_operations, fn op ->
        op.timestamp == timestamp
      end)

      {:noreply, assign(socket, pending_operations: pending_ops)}
    else
      {:noreply, socket}
    end
  end

  # Initialize OT state for new user
  @impl true
  def handle_info({:initialize_ot_state}, socket) do
    session_id = socket.assigns.session.id

    # Get current server state version
    current_state = get_workspace_state(session_id)
    server_version = get_state_version(current_state)

    # Update OT state
    workspace_state = socket.assigns.workspace_state
    ot_state = workspace_state.ot_state
    new_ot_state = %{ot_state |
      server_version: server_version,
      local_version: server_version
    }

    new_workspace_state = Map.put(workspace_state, :ot_state, new_ot_state)

    {:noreply, assign(socket, workspace_state: new_workspace_state)}
  end

  # Handle presence diff
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    collaborators = list_collaborators(socket.assigns.session.id)

    notifications = Enum.reduce(Map.get(diff, :joins, %{}), socket.assigns.notifications, fn {user_id, user_data}, acc ->
      if user_id != to_string(socket.assigns.current_user.id) do
        meta_data = List.first(user_data.metas)
        [%{
          id: System.unique_integer([:positive]),
          type: :user_joined,
          message: "#{meta_data.username} joined the session",
          timestamp: DateTime.utc_now()
        } | acc]
      else
        acc
      end
    end)

    notifications = Enum.reduce(Map.get(diff, :leaves, %{}), notifications, fn {user_id, user_data}, acc ->
      if user_id != to_string(socket.assigns.current_user.id) do
        meta_data = List.first(user_data.metas)
        [%{
          id: System.unique_integer([:positive]),
          type: :user_left,
          message: "#{meta_data.username} left the session",
          timestamp: DateTime.utc_now()
        } | acc]
      else
        acc
      end
    end)

    {:noreply, socket
      |> assign(collaborators: collaborators)
      |> assign(notifications: notifications)}
  end

  # Audio engine events
  @impl true
  def handle_info({:track_added, track, user_id}, socket) do
    username = get_username_from_collaborators(user_id, socket.assigns.collaborators)
    message = "#{username} added track: #{track.name}"

    {:noreply, socket |> add_notification(message, :info)}
  end

  @impl true
  def handle_info({:track_volume_changed, track_id, volume}, socket) do
    # Update workspace state with new volume
    # This integrates with your existing workspace state system
    update_audio_workspace_state(socket, "track_volume", %{
      track_id: track_id,
      volume: volume
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:track_muted, track_id, muted}, socket) do
    update_audio_workspace_state(socket, "track_mute", %{
      track_id: track_id,
      muted: muted
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:track_solo_changed, track_id, solo}, socket) do
    update_audio_workspace_state(socket, "track_solo", %{
      track_id: track_id,
      solo: solo
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:playback_started, position}, socket) do
    {:noreply, socket |> push_event("audio_playback_started", %{position: position})}
  end

  @impl true
  def handle_info({:playback_stopped, position}, socket) do
    {:noreply, socket |> push_event("audio_playback_stopped", %{position: position})}
  end

  @impl true
  def handle_info({:playback_position, position}, socket) do
    {:noreply, socket |> push_event("audio_playback_position", %{position: position})}
  end

  @impl true
  def handle_info({:clip_added, clip}, socket) do
    username = get_username_from_collaborators(clip.user_id, socket.assigns.collaborators)
    message = "#{username} recorded audio clip"

    update_audio_workspace_state(socket, "clip_added", clip)

    {:noreply, socket |> add_notification(message, :success)}
  end

  # Beat machine events
  @impl true
  def handle_info({:beat_machine, {:pattern_created, pattern}}, socket) do
    {:noreply, socket |> push_event("beat_pattern_created", %{pattern: pattern})}
  end

  @impl true
  def handle_info({:beat_machine, {:step_updated, pattern_id, instrument, step, velocity}}, socket) do
    {:noreply, socket |> push_event("beat_step_updated", %{
      pattern_id: pattern_id,
      instrument: instrument,
      step: step,
      velocity: velocity
    })}
  end

  @impl true
  def handle_info({:beat_machine, {:pattern_started, pattern_id}}, socket) do
    {:noreply, socket |> push_event("beat_pattern_started", %{pattern_id: pattern_id})}
  end

  @impl true
  def handle_info({:beat_machine, {:pattern_stopped}}, socket) do
    {:noreply, socket |> push_event("beat_pattern_stopped", %{})}
  end

  @impl true
  def handle_info({:beat_machine, {:step_triggered, step, instruments}}, socket) do
    {:noreply, socket |> push_event("beat_step_triggered", %{
      step: step,
      instruments: instruments
    })}
  end

  @impl true
  def handle_info({:beat_machine, {:kit_changed, kit_name, kit}}, socket) do
    {:noreply, socket |> push_event("beat_kit_changed", %{
      kit_name: kit_name,
      kit: kit
    })}
  end

  # Handle chat messages
  @impl true
  def handle_info({:new_message, message}, socket) do
    updated_messages = socket.assigns.chat_messages ++ [message]

    notifications = if message.user_id != socket.assigns.current_user.id do
      [%{
        id: System.unique_integer([:positive]),
        type: :new_message,
        message: "New message from #{message.username}",
        timestamp: DateTime.utc_now()
      } | socket.assigns.notifications]
    else
      socket.assigns.notifications
    end

    {:noreply, socket
      |> assign(chat_messages: updated_messages)
      |> assign(notifications: notifications)}
  end

  # Handle typing status updates
  @impl true
  def handle_info({:user_typing, user_id, typing}, socket) do
    current_user_id = socket.assigns.current_user.id

    if user_id != current_user_id do
      updated_typing_users = if typing do
        MapSet.put(socket.assigns.typing_users || MapSet.new(), user_id)
      else
        MapSet.delete(socket.assigns.typing_users || MapSet.new(), user_id)
      end

      {:noreply, assign(socket, typing_users: updated_typing_users)}
    else
      {:noreply, socket}
    end
  end

  defp update_beat_workspace_state(socket, update_type, data) do
    session_id = socket.assigns.session.id

    # Get current workspace state
    current_state = socket.assigns.workspace_state

    # Update beat machine section
    beat_state = Map.get(current_state, :beat_machine, %{})
    updated_beat = update_beat_state(beat_state, update_type, data)

    # Update full workspace state
    new_workspace_state = Map.put(current_state, :beat_machine, updated_beat)

    # Save to database
    Sessions.save_workspace_state(session_id, new_workspace_state)

    # Broadcast to other users
    PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{session_id}",
      {:workspace_beat_updated, update_type, data}
    )
  end

  defp update_beat_state(beat_state, "pattern_created", pattern) do
    patterns = Map.get(beat_state, :patterns, %{})
    updated_patterns = Map.put(patterns, pattern.id, pattern)
    Map.put(beat_state, :patterns, updated_patterns)
  end

  defp update_beat_state(beat_state, _type, _data), do: beat_state

  # Catch-all for unhandled messages
  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # OT Helper Functions

  # Generate text operations by diffing old and new content
  defp generate_text_operations(old_content, new_content) do
    # Simple diff algorithm - in production you'd use a more sophisticated one
    cond do
      old_content == new_content ->
        []

      String.length(new_content) > String.length(old_content) ->
        # Content was inserted
        insertion_point = find_insertion_point(old_content, new_content)
        inserted_text = String.slice(new_content, insertion_point, String.length(new_content) - String.length(old_content))

        ops = []
        ops = if insertion_point > 0, do: [{:retain, insertion_point} | ops], else: ops
        ops = [{:insert, inserted_text} | ops]
        remaining = String.length(old_content) - insertion_point
        ops = if remaining > 0, do: [{:retain, remaining} | ops], else: ops

        Enum.reverse(ops)

      String.length(new_content) < String.length(old_content) ->
        # Content was deleted
        deletion_point = find_deletion_point(old_content, new_content)
        deleted_length = String.length(old_content) - String.length(new_content)

        ops = []
        ops = if deletion_point > 0, do: [{:retain, deletion_point} | ops], else: ops
        ops = [{:delete, deleted_length} | ops]
        remaining = String.length(new_content) - deletion_point
        ops = if remaining > 0, do: [{:retain, remaining} | ops], else: ops

        Enum.reverse(ops)

      true ->
        # Content was replaced - for simplicity, delete all and insert new
        [
          {:delete, String.length(old_content)},
          {:insert, new_content}
        ]
    end
  end

  # Find where text was inserted
  defp find_insertion_point(old_content, new_content) do
    # Find the first position where they differ
    old_chars = String.graphemes(old_content)
    new_chars = String.graphemes(new_content)

    find_diff_position(old_chars, new_chars, 0)
  end

  # Find where text was deleted
  defp find_deletion_point(old_content, new_content) do
    # Similar to insertion point but for deletion
    old_chars = String.graphemes(old_content)
    new_chars = String.graphemes(new_content)

    find_diff_position(new_chars, old_chars, 0)
  end

  defp find_diff_position([], _, pos), do: pos
  defp find_diff_position(_, [], pos), do: pos
  defp find_diff_position([h | t1], [h | t2], pos) do
    find_diff_position(t1, t2, pos + 1)
  end
  defp find_diff_position(_, _, pos), do: pos

  # Transform remote operation against pending local operations
  defp transform_against_pending_operations(remote_op, pending_ops) do
    Enum.reduce(pending_ops, {remote_op, []}, fn local_op, {current_remote, transformed_locals} ->
      # Transform remote against local
      {transformed_remote, transformed_local} = OT.transform(current_remote, local_op, :right)

      {transformed_remote, [transformed_local | transformed_locals]}
    end)
  end

  # Detect conflicts between operations
  defp detect_conflicts(remote_op, local_ops) do
    # Simple conflict detection - in practice this would be more sophisticated
    Enum.reduce(local_ops, [], fn local_op, conflicts ->
      case {remote_op.type, local_op.type} do
        {:audio, :audio} when remote_op.action == :add_track and local_op.action == :add_track ->
          if remote_op.track_counter == local_op.track_counter do
            [%{type: :track_number_conflict, remote_user: remote_op.user_id, local_user: local_op.user_id} | conflicts]
          else
            conflicts
          end

        {:text, :text} ->
          # Text conflicts are handled by OT automatically
          conflicts

        _ ->
          conflicts
      end
    end)
  end

  # Get username from collaborators list
  defp get_username_from_collaborators(user_id, collaborators) do
    case Enum.find(collaborators, fn c -> c.user_id == user_id end) do
      %{username: username} -> username
      _ -> "Someone"
    end
  end

  # Format operation messages for notifications
  defp format_operation_message(operation, username) do
    case {operation.type, operation.action} do
      {:audio, :add_track} ->
        track_name = operation.data.name || "new track"
        "#{username} added #{track_name}"

      {:audio, :delete_track} ->
        "#{username} deleted a track"

      {:audio, :add_clip} ->
        "#{username} added an audio clip"

      {:text, _} ->
        "#{username} edited the text"

      {:visual, :add_element} ->
        "#{username} added a visual element"

      {:visual, :delete_element} ->
        "#{username} deleted a visual element"

      _ ->
        nil
    end
  end

  # Get state version for OT tracking
  defp get_state_version(workspace_state) do
    max_version = [
      workspace_state.audio.version || 0,
      workspace_state.text.version || 0,
      workspace_state.visual.version || 0,
      workspace_state.midi.version || 0
    ] |> Enum.max()

    max_version
  end

  # Ensure workspace state has proper OT structure
  defp ensure_ot_state(workspace_state) do
    # Add version numbers if missing
    audio_state = Map.put_new(workspace_state.audio, :version, 0)
    audio_state = Map.put_new(audio_state, :track_counter, 0)

    text_state = Map.put_new(workspace_state.text, :version, 0)
    text_state = Map.put_new(text_state, :pending_operations, [])

    visual_state = Map.put_new(workspace_state.visual, :version, 0)
    midi_state = Map.put_new(workspace_state.midi, :version, 0)

    ot_state = Map.get(workspace_state, :ot_state, %{
      user_operations: %{},
      operation_queue: [],
      acknowledged_ops: MapSet.new(),
      local_version: 0,
      server_version: 0
    })

    %{workspace_state |
      audio: audio_state,
      text: text_state,
      visual: visual_state,
      midi: midi_state,
      ot_state: ot_state
    }
  end

  defp get_user_export_credits(user) do
    tier = Frestyl.Studio.AudioEngineConfig.get_user_tier(user)
    requirements = Frestyl.Studio.ContentStrategy.get_export_requirements(tier)

    case requirements.credits_per_month do
      :unlimited -> :unlimited
      credits -> credits  # In real implementation, get actual remaining credits
    end
  end

  defp start_recording_engine(session_id) do
    case DynamicSupervisor.start_child(
      Frestyl.Studio.RecordingEngineSupervisor,
      {RecordingEngine, session_id}
    ) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Enhanced notification helper
  defp add_notification(socket, message, type \\ :info) do
    notification = %{
      id: System.unique_integer([:positive]),
      type: type,
      message: message,
      timestamp: DateTime.utc_now()
    }

    notifications = [notification | socket.assigns.notifications] |> Enum.take(5)
    assign(socket, notifications: notifications)
  end

  # Helper functions from original module
  defp determine_user_role(session_data, current_user) do
    cond do
      session_data.creator_id == current_user.id -> "owner"
      Sessions.is_session_moderator?(session_data.id, current_user.id) -> "moderator"
      Sessions.is_session_participant?(session_data.id, current_user.id) -> "participant"
      true -> "viewer"
    end
  end

  defp get_permissions_for_role(role, session_type) do
    base_permissions = case role do
      "owner" -> [:view, :edit, :delete, :invite, :kick, :edit_audio, :record_audio, :edit_midi, :edit_text, :edit_visual]
      "moderator" -> [:view, :edit, :invite, :edit_audio, :record_audio, :edit_midi, :edit_text, :edit_visual]
      "participant" -> [:view, :edit_audio, :record_audio, :edit_midi, :edit_text, :edit_visual]
      "viewer" -> [:view]
      _ -> []
    end

    type_permissions = case session_type do
      "audio" -> if role in ["owner", "moderator", "participant"], do: [:edit_audio, :record_audio], else: []
      "visual" -> if role in ["owner", "moderator", "participant"], do: [:edit_visual], else: []
      "text" -> if role in ["owner", "moderator", "participant"], do: [:edit_text], else: []
      "midi" -> if role in ["owner", "moderator", "participant"], do: [:edit_midi], else: []
      "mixed" -> []
      _ -> []
    end

    Enum.uniq(base_permissions ++ type_permissions)
  end

  defp can_edit_session?(permissions), do: :edit in permissions
  defp can_invite_users?(permissions), do: :invite in permissions
  defp can_edit_audio?(permissions), do: :edit_audio in permissions
  defp can_record_audio?(permissions), do: :record_audio in permissions
  defp can_edit_midi?(permissions), do: :edit_midi in permissions
  defp can_edit_text?(permissions), do: :edit_text in permissions
  defp can_edit_visual?(permissions), do: :edit_visual in permissions

  defp list_collaborators(session_id) do
    presence_list = Presence.list("studio:#{session_id}")

    Enum.flat_map(presence_list, fn {user_id, %{metas: metas}} ->
      meta = List.first(metas)
      if meta do
        [Map.put_new(meta, :user_id, user_id)]
      else
        []
      end
    end)
  end

  defp update_presence(session_id, user_id, updates) do
    user_data = Presence.get_by_key("studio:#{session_id}", to_string(user_id))

    case user_data do
      nil ->
        default_data = %{
          user_id: user_id,
          username: "Unknown",
          avatar_url: nil,
          joined_at: DateTime.utc_now(),
          active_tool: updates[:active_tool] || "audio",
          is_typing: updates[:is_typing] || false,
          last_activity: DateTime.utc_now()
        }
        Presence.track(self(), "studio:#{session_id}", to_string(user_id), default_data)

      %{metas: [meta | _]} ->
        new_meta = Map.merge(meta, updates)
        Presence.update(self(), "studio:#{session_id}", to_string(user_id), new_meta)

      _ -> nil
    end
  end

  defp get_workspace_state(session_id) do
    case Sessions.get_workspace_state(session_id) do
      nil -> @default_workspace_state
      workspace_state -> normalize_workspace_state(workspace_state)
    end
  end

  defp normalize_workspace_state(workspace_state) when is_map(workspace_state) do
    %{
      audio: normalize_audio_state(Map.get(workspace_state, "audio") || Map.get(workspace_state, :audio) || %{}),
      midi: normalize_midi_state(Map.get(workspace_state, "midi") || Map.get(workspace_state, :midi) || %{}),
      text: normalize_text_state(Map.get(workspace_state, "text") || Map.get(workspace_state, :text) || %{}),
      visual: normalize_visual_state(Map.get(workspace_state, "visual") || Map.get(workspace_state, :visual) || %{}),
      ot_state: Map.get(workspace_state, :ot_state) || @default_workspace_state.ot_state
    }
  end
  defp normalize_workspace_state(_), do: @default_workspace_state

  defp normalize_audio_state(audio_state) when is_map(audio_state) do
    %{
      tracks: normalize_tracks(Map.get(audio_state, "tracks") || Map.get(audio_state, :tracks) || []),
      selected_track: Map.get(audio_state, "selected_track") || Map.get(audio_state, :selected_track),
      recording: Map.get(audio_state, "recording") || Map.get(audio_state, :recording) || false,
      playing: Map.get(audio_state, "playing") || Map.get(audio_state, :playing) || false,
      current_time: Map.get(audio_state, "current_time") || Map.get(audio_state, :current_time) || 0,
      zoom_level: Map.get(audio_state, "zoom_level") || Map.get(audio_state, :zoom_level) || 1.0,
      track_counter: Map.get(audio_state, "track_counter") || Map.get(audio_state, :track_counter) || 0,
      version: Map.get(audio_state, "version") || Map.get(audio_state, :version) || 0
    }
  end
  defp normalize_audio_state(_), do: @default_workspace_state.audio

  defp normalize_tracks(tracks) when is_list(tracks) do
    Enum.map(tracks, fn track when is_map(track) ->
      %{
        id: Map.get(track, "id") || Map.get(track, :id) || "track-#{System.unique_integer([:positive])}",
        number: Map.get(track, "number") || Map.get(track, :number) || 1,
        name: Map.get(track, "name") || Map.get(track, :name) || "Untitled Track",
        clips: Map.get(track, "clips") || Map.get(track, :clips) || [],
        muted: Map.get(track, "muted") || Map.get(track, :muted) || false,
        solo: Map.get(track, "solo") || Map.get(track, :solo) || false,
        volume: Map.get(track, "volume") || Map.get(track, :volume) || 0.8,
        pan: Map.get(track, "pan") || Map.get(track, :pan) || 0.0,
        created_by: Map.get(track, "created_by") || Map.get(track, :created_by),
        created_at: Map.get(track, "created_at") || Map.get(track, :created_at)
      }
    end)
  end
  defp normalize_tracks(_), do: []

  defp normalize_text_state(text_state) when is_map(text_state) do
    %{
      content: Map.get(text_state, "content") || Map.get(text_state, :content) || "",
      cursors: Map.get(text_state, "cursors") || Map.get(text_state, :cursors) || %{},
      selection: Map.get(text_state, "selection") || Map.get(text_state, :selection),
      version: Map.get(text_state, "version") || Map.get(text_state, :version) || 0,
      pending_operations: Map.get(text_state, "pending_operations") || Map.get(text_state, :pending_operations) || []
    }
  end
  defp normalize_text_state(_), do: @default_workspace_state.text

  defp normalize_midi_state(midi_state) when is_map(midi_state) do
    %{
      notes: Map.get(midi_state, "notes") || Map.get(midi_state, :notes) || [],
      selected_notes: Map.get(midi_state, "selected_notes") || Map.get(midi_state, :selected_notes) || [],
      current_instrument: Map.get(midi_state, "current_instrument") || Map.get(midi_state, :current_instrument) || "piano",
      octave: Map.get(midi_state, "octave") || Map.get(midi_state, :octave) || 4,
      grid_size: Map.get(midi_state, "grid_size") || Map.get(midi_state, :grid_size) || 16,
      version: Map.get(midi_state, "version") || Map.get(midi_state, :version) || 0
    }
  end
  defp normalize_midi_state(_), do: @default_workspace_state.midi

  defp normalize_visual_state(visual_state) when is_map(visual_state) do
    %{
      elements: Map.get(visual_state, "elements") || Map.get(visual_state, :elements) || [],
      selected_element: Map.get(visual_state, "selected_element") || Map.get(visual_state, :selected_element),
      tool: Map.get(visual_state, "tool") || Map.get(visual_state, :tool) || "brush",
      brush_size: Map.get(visual_state, "brush_size") || Map.get(visual_state, :brush_size) || 5,
      color: Map.get(visual_state, "color") || Map.get(visual_state, :color) || "#4f46e5",
      version: Map.get(visual_state, "version") || Map.get(visual_state, :version) || 0
    }
  end
  defp normalize_visual_state(_), do: @default_workspace_state.visual

  defp save_workspace_state(session_id, workspace_state) do
    normalized_state = normalize_workspace_state(workspace_state)
    Sessions.save_workspace_state(session_id, normalized_state)
  end

  defp list_media_items(session_id) do
    Media.list_session_media_items(session_id)
  end

  defp get_available_tools(permissions) do
    [
      %{id: "audio", name: "Audio", icon: "microphone", enabled: :edit_audio in permissions},
      %{id: "midi", name: "MIDI", icon: "music-note", enabled: :edit_midi in permissions},
      %{id: "text", name: "Lyrics", icon: "document-text", enabled: :edit_text in permissions},
      %{id: "visual", name: "Visual", icon: "pencil", enabled: :edit_visual in permissions}
    ]
  end

  defp generate_rtc_token(user_id, session_id) do
    Phoenix.Token.sign(FrestylWeb.Endpoint, "user session", %{
      user_id: user_id,
      session_id: session_id,
      timestamp: :os.system_time(:second)
    })
  end

  defp update_audio_workspace_state(socket, update_type, data) do
    session_id = socket.assigns.session.id

    # Get current workspace state
    current_state = socket.assigns.workspace_state

    # Update audio section
    audio_state = Map.get(current_state, :audio, %{})
    updated_audio = update_audio_state(audio_state, update_type, data)

    # Update full workspace state
    new_workspace_state = Map.put(current_state, :audio, updated_audio)

    # Save to database
    Sessions.save_workspace_state(session_id, new_workspace_state)

    # Broadcast to other users
    PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{session_id}",
      {:workspace_audio_updated, update_type, data}
    )
  end

  defp get_audio_engine_state(session_id) do
    case AudioEngine.get_engine_state(session_id) do
      {:ok, state} -> state
      _ -> %{tracks: [], transport: %{playing: false, position: 0}}
    end
  end

  defp get_beat_machine_state(session_id) do
    case BeatMachine.get_beat_machine_state(session_id) do
      {:ok, state} -> state
      _ -> %{patterns: %{}, active_pattern: nil, playing: false}
    end
  end

  defp update_audio_state(audio_state, "track_volume", %{track_id: track_id, volume: volume}) do
    tracks = Map.get(audio_state, :tracks, [])
    updated_tracks = Enum.map(tracks, fn track ->
      if track.id == track_id do
        %{track | volume: volume}
      else
        track
      end
    end)
    Map.put(audio_state, :tracks, updated_tracks)
  end

  defp update_audio_state(audio_state, "track_mute", %{track_id: track_id, muted: muted}) do
    tracks = Map.get(audio_state, :tracks, [])
    updated_tracks = Enum.map(tracks, fn track ->
      if track.id == track_id do
        %{track | muted: muted}
      else
        track
      end
    end)
    Map.put(audio_state, :tracks, updated_tracks)
  end

  defp update_audio_state(audio_state, "track_solo", %{track_id: track_id, solo: solo}) do
    tracks = Map.get(audio_state, :tracks, [])
    updated_tracks = Enum.map(tracks, fn track ->
      if track.id == track_id do
        %{track | solo: solo}
      else
        # If soloing this track, unsolo others
        if solo do
          %{track | solo: false}
        else
          track
        end
      end
    end)
    Map.put(audio_state, :tracks, updated_tracks)
  end

  defp update_audio_state(audio_state, "clip_added", clip) do
    clips = Map.get(audio_state, :clips, [])
    Map.put(audio_state, :clips, [clip | clips])
  end

  defp update_audio_state(audio_state, _type, _data), do: audio_state


  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gradient-to-br from-gray-900 to-indigo-900">
      <A11y.skip_to_content />

      <!-- Enhanced Header with OT Status -->
      <header class="flex items-center justify-between px-4 py-2 bg-gray-900 bg-opacity-70 border-b border-gray-800">
        <div class="flex items-center">
          <div class="mr-4">
            <.link navigate={~p"/channels/#{@channel.slug}"} class="text-white hover:text-indigo-300">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" />
              </svg>
            </.link>
          </div>

          <div class="flex items-center space-x-2">
            <div class="text-sm text-gray-400 uppercase tracking-wider">
              <%= @channel.name %>
            </div>
            <span class="text-gray-600">/</span>
            <input
              type="text"
              value={@session.title || "Untitled Session"}
              phx-blur="update_session_title"
              class={[
                "bg-transparent border-b border-gray-700 focus:border-indigo-500 text-white focus:outline-none",
                !can_edit_session?(@permissions) && "cursor-not-allowed"
              ]}
              readonly={!can_edit_session?(@permissions)}
              aria-label="Session name"
            />
          </div>
        </div>

        <div class="flex items-center space-x-3">
          <!-- OT Status Indicators -->
          <%= if length(@pending_operations) > 0 do %>
            <div class="flex items-center space-x-1 text-yellow-400 text-xs">
              <div class="animate-pulse w-2 h-2 bg-yellow-400 rounded-full"></div>
              <span><%= length(@pending_operations) %> pending</span>
            </div>
          <% end %>

          <%= if length(@operation_conflicts) > 0 do %>
            <div class="flex items-center space-x-1 text-red-400 text-xs cursor-pointer" phx-click="clear_conflicts">
              <div class="w-2 h-2 bg-red-400 rounded-full"></div>
              <span><%= length(@operation_conflicts) %> conflicts</span>
            </div>
          <% end %>

          <!-- Connection status -->
          <span class={[
            "h-2 w-2 rounded-full",
            cond do
              @connection_status == "connected" -> "bg-green-500"
              @connection_status == "connecting" -> "bg-yellow-500"
              true -> "bg-red-500"
            end
          ]} title={String.capitalize(@connection_status)}></span>

          <!-- Members indicator -->
          <div class="relative">
            <div class="flex items-center text-gray-400 hover:text-white">
              <span class="text-sm"><%= length(@collaborators) %></span>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v1h8v-1zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-1a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v1h-3zM4.75 12.094A5.973 5.973 0 004 15v1H1v-1a3 3 0 013.75-2.906z" />
              </svg>
            </div>
          </div>

          <!-- Invite button -->
          <%= if can_invite_users?(@permissions) do %>
            <button
              type="button"
              phx-click="toggle_invite_modal"
              class="p-2 bg-indigo-500 hover:bg-indigo-600 text-white rounded-full shadow-sm"
              aria-label="Invite collaborators"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                <path d="M8 9a3 3 0 100-6 3 3 0 000 6zM8 11a6 6 0 016 6H2a6 6 0 016-6zM16 7a1 1 0 10-2 0v1h-1a1 1 0 100 2h1v1a1 1 0 102 0v-1h1a1 1 0 100-2h-1V7z" />
              </svg>
            </button>
          <% end %>

          <!-- Settings button -->
          <button
            type="button"
            phx-click="toggle_settings_modal"
            class="text-gray-400 hover:text-white"
            aria-label="Settings"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd" />
            </svg>
          </button>

          <!-- OT Debug Toggle (dev only) -->
          <%= if Application.get_env(:frestyl, :environment) == :dev do %>
            <button
              phx-click="toggle_ot_debug"
              class={[
                "text-xs px-2 py-1 rounded",
                @ot_debug_mode && "bg-yellow-600 text-white" || "bg-gray-700 text-gray-300"
              ]}
              title="Toggle OT Debug"
            >
              OT
            </button>
          <% end %>

          <!-- End Session button -->
          <%= if @current_user.id == @session.creator_id || @current_user.id == @session.host_id do %>
            <button
              type="button"
              phx-click="end_session"
              class="bg-red-500 hover:bg-red-600 text-white rounded-md px-3 py-1"
            >
              End
            </button>
          <% end %>
        </div>
      </header>

      <!-- OT Debug Panel (if enabled) -->
      <%= if @ot_debug_mode do %>
        <div class="bg-yellow-900 bg-opacity-50 p-2 text-xs text-yellow-100 border-b border-yellow-800">
          <div class="flex space-x-4">
            <span>Text Version: <%= @workspace_state.text.version %></span>
            <span>Audio Version: <%= @workspace_state.audio.version %></span>
            <span>Pending Ops: <%= length(@pending_operations) %></span>
            <span>Conflicts: <%= length(@operation_conflicts) %></span>
            <span>Track Counter: <%= @workspace_state.audio.track_counter %></span>
          </div>
        </div>
      <% end %>

      <!-- Main content area -->
      <div class="flex flex-1 overflow-hidden" id="main-content">
        <!-- Left sidebar - Tools -->
        <div class="w-16 bg-gray-900 bg-opacity-70 flex flex-col items-center py-4 space-y-4">
          <%= for tool <- @tools do %>
            <button
              type="button"
              phx-click="set_active_tool"
              phx-value-tool={tool.id}
              class={[
                "p-2 rounded-md transition-all duration-200",
                @active_tool == tool.id && "bg-gradient-to-r from-indigo-500 to-purple-600 text-white shadow-md",
                @active_tool != tool.id && "text-gray-400 hover:text-white",
                !tool.enabled && "opacity-50 cursor-not-allowed"
              ]}
              disabled={!tool.enabled}
              aria-label={tool.name}
              aria-pressed={@active_tool == tool.id}
              title={tool.name}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <%= case tool.icon do %>
                  <% "microphone" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                  <% "music-note" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                  <% "document-text" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  <% "pencil" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                <% end %>
              </svg>
            </button>
          <% end %>
        </div>

        <!-- Workspace area -->
        <div class="flex-1 overflow-hidden">
          <%= case @active_tool do %>
            <% "audio" -> %>
              <div class="h-full flex flex-col bg-gray-900 bg-opacity-50">
                <!-- Enhanced Audio Workspace Header -->
                <div class="flex items-center justify-between p-4 border-b border-gray-800">
                  <h2 class="text-white text-lg font-medium flex items-center">
                    Audio Workspace
                    <span class="ml-3 text-sm text-gray-400">
                      (Next: Track <%= @workspace_state.audio.track_counter + 1 %>)
                    </span>

                    <!-- Recording Status Indicator -->
                    <%= if @recording_mode do %>
                      <span class="ml-3 flex items-center text-red-400 text-sm">
                        <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse mr-1"></div>
                        Recording Mode
                      </span>
                    <% end %>
                  </h2>

                  <div class="flex items-center space-x-3">
                    <!-- Export Credits Display -->
                    <%= if @export_credits != :unlimited do %>
                      <div class="text-sm text-gray-400">
                        Export Credits: <%= @export_credits %>
                      </div>
                    <% end %>

                    <!-- Recording Toggle -->
                    <%= if @recording_enabled do %>
                      <button
                        type="button"
                        phx-click="toggle_recording_mode"
                        class={[
                          "px-3 py-1.5 rounded-md text-sm font-medium transition-colors",
                          @recording_mode && "bg-red-600 hover:bg-red-700 text-white" || "bg-gray-600 text-gray-300 hover:bg-gray-500"
                        ]}
                      >
                        <%= if @recording_mode, do: "Exit Recording", else: "Recording Mode" %>
                      </button>
                    <% end %>

                    <!-- Existing add track button -->
                    <%= if can_edit_audio?(@permissions) do %>
                      <button
                        type="button"
                        phx-click="audio_add_track"
                        class="bg-indigo-500 hover:bg-indigo-600 rounded-md p-1.5 text-white relative"
                        aria-label="Add track"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
                        </svg>
                        <!-- Pending operation indicator -->
                        <%= if Enum.any?(@pending_operations, &(&1.type == :audio && &1.action == :add_track)) do %>
                          <div class="absolute -top-1 -right-1 w-3 h-3 bg-yellow-400 rounded-full animate-pulse"></div>
                        <% end %>
                      </button>
                    <% end %>
                  </div>
                </div>

                <!-- Audio Workspace Content -->
                <div class="flex-1 overflow-hidden">
                  <%= if @recording_mode do %>
                    <!-- Recording Interface -->
                    <.live_component
                      module={RecordingComponent}
                      id="recording-workspace"
                      session_id={@session.id}
                      current_user={@current_user}
                      workspace_state={@workspace_state}
                      user_channels={@user_channels}
                      user_tier={@user_tier}
                      permissions={@permissions}
                    />
                  <% else %>
                    <!-- Standard Audio Workspace (your existing content) -->
                    <div class="flex-1 overflow-y-auto p-4">
                      <%= if length(@workspace_state.audio.tracks) == 0 do %>
                        <div class="h-full flex flex-col items-center justify-center text-gray-400">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                          </svg>
                          <p class="text-lg">No audio tracks yet</p>
                          <%= if can_edit_audio?(@permissions) do %>
                            <div class="mt-4 space-y-2">
                              <button
                                phx-click="audio_add_track"
                                class="block px-4 py-2 bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700 text-white rounded-lg shadow-lg"
                              >
                                Add your first track
                              </button>
                              <%= if @recording_enabled do %>
                                <button
                                  phx-click="toggle_recording_mode"
                                  class="block px-4 py-2 bg-gradient-to-r from-red-500 to-red-600 hover:from-red-600 hover:to-red-700 text-white rounded-lg shadow-lg"
                                >
                                  Start Recording Session
                                </button>
                              <% end %>
                            </div>
                          <% else %>
                            <p class="mt-2 text-sm">You don't have permission to add tracks</p>
                          <% end %>
                        </div>
                      <% else %>
                        <!-- Existing track display (your current implementation) -->
                        <div class="space-y-4">
                          <%= for track <- @workspace_state.audio.tracks do %>
                            <div class="bg-gray-800 rounded-lg p-4 relative group">
                              <!-- Your existing track rendering code -->
                              <!-- ... existing track content ... -->
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% "text" -> %>
              <div class="h-full flex flex-col bg-gray-900 bg-opacity-50">
                <div class="p-4 border-b border-gray-800">
                  <h2 class="text-white text-lg font-medium flex items-center">
                    Lyrics Editor
                    <span class="ml-3 text-sm text-gray-400">
                      v<%= @workspace_state.text.version %>
                    </span>
                    <%= if length(@pending_operations) > 0 do %>
                      <span class="ml-2 text-xs text-yellow-400">
                        (<%= length(@pending_operations) %> pending)
                      </span>
                    <% end %>
                  </h2>
                </div>

                <div class="flex-1 overflow-y-auto p-4">
                  <div class="h-full relative">
                    <%= if can_edit_text?(@permissions) do %>
                      <textarea
                        id="text-editor"
                        phx-hook="TextEditorOT"
                        phx-blur="text_update"
                        phx-keyup="text_update"
                        class="w-full h-full bg-gray-800 text-white p-4 rounded-lg border border-gray-700 focus:border-indigo-500 focus:ring-indigo-500 resize-none"
                        placeholder="Start writing lyrics..."
                        aria-label="Lyrics editor"
                      ><%= @workspace_state.text.content %></textarea>

                      <!-- Show cursors of other users -->
                      <%= for {user_id, cursor_pos} <- @workspace_state.text.cursors do %>
                        <%= if user_id != @current_user.id do %>
                          <% username = get_username_from_collaborators(user_id, @collaborators) %>
                          <div
                            class="absolute pointer-events-none z-10"
                            style={"top: #{cursor_pos.line * 20 + 100}px; left: #{cursor_pos.column * 8 + 20}px;"}
                          >
                            <div class="w-0.5 h-5 bg-indigo-500 animate-pulse"></div>
                            <div class="text-xs bg-indigo-500 text-white px-1 rounded mt-1">
                              <%= username %>
                            </div>
                          </div>
                        <% end %>
                      <% end %>
                    <% else %>
                      <div class="w-full h-full bg-gray-800 text-white p-4 rounded-lg border border-gray-700 overflow-auto">
                        <%= if @workspace_state.text.content != "" do %>
                          <pre class="whitespace-pre-wrap font-mono"><%= @workspace_state.text.content %></pre>
                        <% else %>
                          <p class="text-gray-500 italic">No content yet</p>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>

            <% _ -> %>
              <!-- Default/other tools -->
              <div class="h-full flex items-center justify-center">
                <p class="text-white">Tool workspace for <%= @active_tool %></p>
              </div>
          <% end %>
        </div>

        <!-- Enhanced Right sidebar - Chat -->
        <div class="w-80 bg-gray-900 bg-opacity-70 flex flex-col border-l border-gray-800">
          <div class="flex border-b border-gray-800">
            <button class="flex-1 py-3 text-center text-sm font-medium text-white bg-indigo-500 bg-opacity-20">
              Chat
            </button>
            <button class="flex-1 py-3 text-center text-sm font-medium text-gray-400 hover:text-white">
              Files
            </button>
          </div>

          <!-- Chat messages -->
          <div class="flex-1 overflow-y-auto p-4" id="session-chat-messages">
            <%= if length(@chat_messages) == 0 do %>
              <div class="text-center text-gray-500 text-sm my-4">
                No messages yet
              </div>
            <% end %>

            <%= for message <- @chat_messages do %>
              <div class={[
                "flex mb-4",
                message.user_id == @current_user.id && "justify-end" || "justify-start"
              ]}>
                <%= if message.user_id != @current_user.id do %>
                  <div class="flex-shrink-0 mr-3">
                    <%= if Map.get(message, :avatar_url) do %>
                      <img src={message.avatar_url} class="h-8 w-8 rounded-full" alt={message.username} />
                    <% else %>
                      <div class="h-8 w-8 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-medium text-sm">
                        <%= String.at(message.username, 0) %>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <div class={[
                  "rounded-2xl px-4 py-2 max-w-xs",
                  message.user_id == @current_user.id && "bg-indigo-500 text-white rounded-br-md" || "bg-gray-800 text-white rounded-bl-md"
                ]}>
                  <%= if message.user_id != @current_user.id do %>
                    <p class="text-xs font-medium text-gray-300 mb-1"><%= message.username %></p>
                  <% end %>
                  <p class="text-sm whitespace-pre-wrap"><%= message.content %></p>
                  <p class="text-xs text-right mt-1 opacity-60">
                    <%= Calendar.strftime(message.inserted_at, "%H:%M") %>
                  </p>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Chat input -->
          <div class="p-4 border-t border-gray-800">
            <form phx-submit="send_session_message" class="flex">
              <input
                type="text"
                name="message"
                value={@message_input}
                phx-keyup="update_message_input"
                phx-focus="typing_start"
                phx-blur="typing_stop"
                placeholder="Type a message..."
                class="flex-1 bg-gray-800 border-gray-700 rounded-l-md text-white text-sm focus:border-indigo-500 focus:ring-indigo-500"
                aria-label="Chat message"
              />
              <button
                type="submit"
                class="bg-indigo-500 hover:bg-indigo-600 text-white rounded-r-md px-3"
                aria-label="Send message"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" />
                </svg>
              </button>
            </form>
          </div>
        </div>
      </div>

      <!-- Notification toast container -->
      <div class="fixed bottom-4 right-4 space-y-2 z-50">
        <%= for notification <- Enum.take(@notifications, 3) do %>
          <div
            class="bg-gray-900 bg-opacity-90 border border-gray-800 text-white rounded-lg shadow-lg p-4 max-w-xs"
            role="alert"
          >
            <div class="flex items-start">
              <div class="flex-shrink-0 mr-3 mt-0.5">
                <%= case notification.type do %>
                  <% :user_joined -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M8 9a3 3 0 100-6 3 3 0 000 6zM8 11a6 6 0 016 6H2a6 6 0 016-6zM16 7a1 1 0 10-2 0v1h-1a1 1 0 100 2h1v1a1 1 0 102 0v-1h1a1 1 0 100-2h-1V7z" />
                    </svg>
                  <% :user_left -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M11 6a3 3 0 11-6 0 3 3 0 016 0zM14 17a6 6 0 00-12 0h12z" />
                      <path d="M13 8a1 1 0 100 2h4a1 1 0 100-2h-4z" />
                    </svg>
                  <% :new_message -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-indigo-400" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M2 5a2 2 0 012-2h7a2 2 0 012 2v4a2 2 0 01-2 2H9l-3 3v-3H4a2 2 0 01-2-2V5z" />
                      <path d="M15 7v2a4 4 0 01-4 4H9.828l-1.766 1.767c.28.149.599.233.938.233h2l3 3v-3h2a2 2 0 002-2V9a2 2 0 00-2-2h-1z" />
                    </svg>
                  <% :success -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                    </svg>
                  <% :warning -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                  <% _ -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                    </svg>
                <% end %>
              </div>
              <div>
                <p class="text-sm"><%= notification.message %></p>
                <p class="text-xs text-gray-400 mt-1">
                  <%= Calendar.strftime(notification.timestamp, "%I:%M %p") %>
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- End Session Confirmation Modal -->
      <%= if @show_end_session_modal do %>
        <div class="fixed z-50 inset-0 overflow-y-auto" role="dialog" aria-modal="true">
          <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <!-- Background overlay -->
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true"></div>

            <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

            <!-- Modal panel -->
            <div class="inline-block align-bottom bg-white rounded-xl text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
              <div class="bg-gradient-to-r from-red-500 to-red-600 px-4 py-4 sm:px-6 flex items-center justify-between">
                <h3 class="text-lg leading-6 font-medium text-white flex items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                  End Session
                </h3>
                <button
                  type="button"
                  phx-click="cancel_end_session"
                  class="text-white hover:text-gray-200 focus:outline-none"
                >
                  <span class="sr-only">Close</span>
                  <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                  <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
                    <h3 class="text-lg leading-6 font-medium text-gray-900" id="modal-title">
                      Are you sure?
                    </h3>
                    <div class="mt-2">
                      <p class="text-sm text-gray-500">
                        This will end the session for all participants. Your work will be saved to the channel's media library.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <button
                  type="button"
                  phx-click="end_session_confirmed"
                  class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-red-600 text-base font-medium text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  End Session
                </button>
                <button
                  type="button"
                  phx-click="cancel_end_session"
                  class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
