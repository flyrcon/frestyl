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
  alias Frestyl.Studio.{AudioEngine, BeatMachine, RecordingEngine}
  alias Phoenix.PubSub
  alias FrestylWeb.StudioLive.RecordingComponent
  alias Frestyl.Collaboration.AudioOTIntegration
  alias Frestyl.UserPreferences
  alias FrestylWeb.StudioLive.AudioEnhancements

  # Collaboration mode configurations
  @collaboration_modes %{
    "collaborative_writing" => %{
      description: "Real-time writing together",
      primary_tools: ["editor", "chat"],
      secondary_tools: ["recorder", "mixer", "effects"],
      default_layout: %{
        left_dock: ["editor"],
        right_dock: ["chat"],
        bottom_dock: [],
        floating: [],
        minimized: ["recorder", "mixer", "effects"]
      },
      workspace_type: "text"
    },

    "audio_production" => %{
      description: "Creating/mixing audio together",
      primary_tools: ["recorder", "mixer", "effects"],
      secondary_tools: ["editor", "chat"],
      default_layout: %{
        left_dock: ["mixer"],
        right_dock: ["chat"],
        bottom_dock: ["recorder", "effects"],
        floating: [],
        minimized: ["editor"]
      },
      workspace_type: "audio"
    },

    "social_listening" => %{
      description: "Listen/watch together + discuss",
      primary_tools: ["chat"],
      secondary_tools: ["editor", "recorder"],
      default_layout: %{
        left_dock: [],
        right_dock: ["chat"],
        bottom_dock: [],
        floating: [],
        minimized: ["editor", "recorder"]
      },
      workspace_type: "audio"
    },

    "content_review" => %{
      description: "Review/critique existing content",
      primary_tools: ["chat", "editor"],
      secondary_tools: ["recorder", "mixer"],
      default_layout: %{
        left_dock: ["editor"],
        right_dock: ["chat"],
        bottom_dock: [],
        floating: [],
        minimized: ["recorder", "mixer"]
      },
      workspace_type: "text"
    },

    "live_session" => %{
      description: "One presents, others participate",
      primary_tools: ["recorder", "chat"],
      secondary_tools: ["editor", "mixer", "effects"],
      default_layout: %{
        left_dock: ["recorder"],
        right_dock: ["chat"],
        bottom_dock: [],
        floating: [],
        minimized: ["editor", "mixer", "effects"]
      },
      workspace_type: "audio"
    },

    "multimedia_creation" => %{
      description: "Text + audio + media together",
      primary_tools: ["editor", "recorder", "mixer"],
      secondary_tools: ["effects", "chat"],
      default_layout: %{
        left_dock: ["editor"],
        right_dock: ["chat"],
        bottom_dock: ["recorder", "mixer"],
        floating: [],
        minimized: ["effects"]
      },
      workspace_type: "hybrid"
    }
  }

  # Enhanced default workspace state with OT support
  @default_workspace_state %{
    tracks: [],
    effects: [],
    master_settings: %{
    volume: 0.8,
    pan: 0.0
    },
    ot_version: 0,
    pending_operations: [],
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
    },
    tool_layout: %{
      left_dock: [],
      right_dock: ["chat"],  # Chat starts docked right
      bottom_dock: [],
      floating: [],
      minimized: []
    },
    collaboration_mode: "audio_production",  # Default mode
    user_tool_preferences: %{},
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
  def mount(%{"slug" => channel_slug, "session_id" => session_id} = params, session, socket) do
    current_user = session["user_token"] && Accounts.get_user_by_session_token(session["user_token"])

    if current_user do
      channel = Channels.get_channel_by_slug(channel_slug)

      if channel do
        session_data = Sessions.get_session(session_id)

        if session_data do
          # NOW we can use session_data
          collaboration_mode = get_session_collaboration_mode(session_data)
          IO.inspect(collaboration_mode, label: "Collaboration Mode")

          available_tools = get_available_tools_for_mode(collaboration_mode)
          IO.inspect(available_tools, label: "Available Tools")

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
          workspace_state = ensure_workspace_state_structure(workspace_state)
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

          # In your mount function, after the available_tools assignment:
          IO.inspect(available_tools, label: "Available Tools Structure")

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
            |> assign(:chat_messages, chat_messages || [])
            |> assign(:message_input, "")
            |> assign(:show_invite_modal, false)
            |> assign(:show_settings_modal, false)
            |> assign(:show_export_modal, false)
            |> assign(:media_items, list_media_items(session_id))
            |> assign(:tools, get_available_tools(session_data.session_type, permissions))
            |> assign(:rtc_token, generate_rtc_token(current_user.id, session_id))
            |> assign(:connection_status, "connecting")
            |> assign(:notifications, [])
            |> assign(:recorded_chunks, [])
            |> assign(:show_end_session_modal, false)
            |> assign(:collaboration_mode, get_session_collaboration_mode(session_data))
            |> assign(:available_tools, get_available_tools_for_mode(get_session_collaboration_mode(session_data)))
            |> assign(:tool_layout, get_user_tool_layout(current_user.id, get_session_collaboration_mode(session_data)))
            |> assign(:dock_visibility, %{left: true, right: true, bottom: true})
            |> assign(:mobile_tool_drawer_open, false)
            # OT-specific assigns
            |> assign(:typing_users, MapSet.new())
            |> assign(:pending_operations, [])
            |> assign(:operation_conflicts, [])
            |> assign(:ot_debug_mode, false)
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
            |> assign(:mobile_active_tool, nil)
            |> assign(:mobile_layout, get_mobile_layout_for_mode(get_session_collaboration_mode(session_data)))
            |> assign(:touch_gestures_enabled, is_mobile)  # Fixed: removed @
            |> assign(:show_more_mobile_tools, false)
            |> assign(:show_mobile_tool_modal, false)
            |> assign(:mobile_modal_tool, nil)

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
    # Try different possible locations for tracks
    tracks = case workspace_state do
      %{tracks: tracks} when is_list(tracks) -> tracks
      %{audio_settings: %{tracks: tracks}} when is_list(tracks) -> tracks
      %{audio: %{tracks: tracks}} when is_list(tracks) -> tracks
      _ -> []
    end

    case tracks do
      [first_track | _] when is_map(first_track) ->
        Map.get(first_track, :id, 1)
      [first_track | _] when is_integer(first_track) ->
        first_track
      _ ->
        1  # Default track ID
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
  def handle_event("toggle_more_mobile_tools", _, socket) do
    new_state = !socket.assigns.show_more_mobile_tools
    {:noreply, socket
      |> assign(show_more_mobile_tools: new_state)
      |> push_event("toggle_more_tools", %{show: new_state})}
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

  # Tool Panel Management Events
  @impl true
  def handle_event("change_collaboration_mode", %{"mode" => mode}, socket) do
    if Map.has_key?(@collaboration_modes, mode) do
      mode_config = @collaboration_modes[mode]

      # Apply default layout for the new mode
      new_layout = apply_user_layout_preferences(
        mode_config.default_layout,
        socket.assigns.current_user.id
      )

      workspace_state = socket.assigns.workspace_state
      new_workspace_state = %{workspace_state |
        tool_layout: new_layout,
        collaboration_mode: mode
      }

      # Update active tool based on workspace type
      new_active_tool = case mode_config.workspace_type do
        "audio" -> "audio"
        "text" -> "text"
        "hybrid" -> socket.assigns.active_tool
        _ -> "audio"
      end

      # Broadcast mode change to other users
      PubSub.broadcast(
        Frestyl.PubSub,
        "studio:#{socket.assigns.session.id}",
        {:collaboration_mode_changed, mode, socket.assigns.current_user.id}
      )

      {:noreply, socket
        |> assign(workspace_state: new_workspace_state)
        |> assign(collaboration_mode: mode)
        |> assign(active_tool: new_active_tool)
        |> add_notification("Switched to #{mode_config.description}", :info)}
    else
      {:noreply, socket |> put_flash(:error, "Invalid collaboration mode")}
    end
  end

  @impl true
  def handle_event("move_tool_to_dock", %{"tool_id" => tool_id, "dock_area" => dock_area}, socket) do
    workspace_state = socket.assigns.workspace_state
    current_layout = workspace_state.tool_layout

    # Remove tool from all dock areas
    cleaned_layout = %{
      left_dock: List.delete(current_layout.left_dock, tool_id),
      right_dock: List.delete(current_layout.right_dock, tool_id),
      bottom_dock: List.delete(current_layout.bottom_dock, tool_id),
      floating: List.delete(current_layout.floating, tool_id),
      minimized: List.delete(current_layout.minimized, tool_id)
    }

    # Add tool to new dock area
    new_layout = case dock_area do
      "left_dock" -> %{cleaned_layout | left_dock: [tool_id | cleaned_layout.left_dock]}
      "right_dock" -> %{cleaned_layout | right_dock: [tool_id | cleaned_layout.right_dock]}
      "bottom_dock" -> %{cleaned_layout | bottom_dock: [tool_id | cleaned_layout.bottom_dock]}
      "floating" -> %{cleaned_layout | floating: [tool_id | cleaned_layout.floating]}
      "minimized" -> %{cleaned_layout | minimized: [tool_id | cleaned_layout.minimized]}
      _ -> cleaned_layout
    end

    new_workspace_state = %{workspace_state | tool_layout: new_layout}

    # Save user preference
    save_user_tool_layout_preference(socket.assigns.current_user.id, new_layout)

    {:noreply, socket
      |> assign(workspace_state: new_workspace_state)
      |> push_event("tool_moved", %{tool_id: tool_id, dock_area: dock_area})}
  end

  @impl true
  def handle_event("toggle_tool_panel", %{"tool_id" => tool_id}, socket) do
    workspace_state = socket.assigns.workspace_state
    current_layout = workspace_state.tool_layout

    # If tool is minimized, restore to its preferred location
    new_layout = if tool_id in current_layout.minimized do
      preferred_dock = get_tool_preferred_dock(tool_id, socket.assigns.collaboration_mode)

      %{current_layout |
        minimized: List.delete(current_layout.minimized, tool_id),
        "#{preferred_dock}": [tool_id | Map.get(current_layout, String.to_atom(preferred_dock), [])]
      }
    else
      # Minimize the tool
      cleaned_layout = %{
        left_dock: List.delete(current_layout.left_dock, tool_id),
        right_dock: List.delete(current_layout.right_dock, tool_id),
        bottom_dock: List.delete(current_layout.bottom_dock, tool_id),
        floating: List.delete(current_layout.floating, tool_id),
        minimized: current_layout.minimized
      }

      %{cleaned_layout | minimized: [tool_id | cleaned_layout.minimized]}
    end

    new_workspace_state = %{workspace_state | tool_layout: new_layout}

    {:noreply, socket
      |> assign(workspace_state: new_workspace_state)
      |> push_event("tool_toggled", %{tool_id: tool_id, minimized: tool_id in new_layout.minimized})}
  end

  @impl true
  def handle_event("reset_tool_layout", _, socket) do
    mode = socket.assigns.workspace_state.collaboration_mode
    mode_config = @collaboration_modes[mode]

    new_workspace_state = %{socket.assigns.workspace_state |
      tool_layout: mode_config.default_layout
    }

    # Clear user preferences
    clear_user_tool_layout_preferences(socket.assigns.current_user.id)

    {:noreply, socket
      |> assign(workspace_state: new_workspace_state)
      |> add_notification("Tool layout reset to default", :info)}
  end

  # Mobile Tool Management Events
  @impl true
  def handle_event("toggle_mobile_drawer", _, socket) do
    new_state = !socket.assigns.mobile_tool_drawer_open

    {:noreply, socket
      |> assign(mobile_tool_drawer_open: new_state)
      |> push_event("mobile_drawer_toggled", %{open: new_state})}
  end

  @impl true
  def handle_event("activate_mobile_tool", %{"tool_id" => tool_id}, socket) do
    # On mobile, we show tools in a modal overlay instead of docked panels
    case tool_id do
      "chat" ->
        {:noreply, socket
          |> assign(mobile_tool_drawer_open: false)
          |> assign(mobile_active_tool: "chat")
          |> push_event("show_mobile_tool_modal", %{tool_id: "chat"})}

      "editor" ->
        {:noreply, socket
          |> assign(mobile_tool_drawer_open: false)
          |> assign(mobile_active_tool: "editor")
          |> assign(active_tool: "text")  # Switch main workspace to text
          |> push_event("show_mobile_tool_modal", %{tool_id: "editor"})}

      "recorder" ->
        if can_record_audio?(socket.assigns.permissions) do
          {:noreply, socket
            |> assign(mobile_tool_drawer_open: false)
            |> assign(mobile_active_tool: "recorder")
            |> push_event("show_mobile_recording_interface", %{})}
        else
          {:noreply, socket
            |> assign(mobile_tool_drawer_open: false)
            |> put_flash(:error, "You don't have permission to record")}
        end

      "mixer" ->
        {:noreply, socket
          |> assign(mobile_tool_drawer_open: false)
          |> assign(mobile_active_tool: "mixer")
          |> push_event("show_mobile_mixer", %{tracks: socket.assigns.workspace_state.audio.tracks})}

      "effects" ->
        {:noreply, socket
          |> assign(mobile_tool_drawer_open: false)
          |> assign(mobile_active_tool: "effects")
          |> push_event("show_mobile_effects_rack", %{})}

      _ ->
        {:noreply, socket
          |> assign(mobile_tool_drawer_open: false)
          |> add_notification("Tool #{tool_id} not yet implemented on mobile", :info)}
    end
  end

  @impl true
  def handle_event("close_mobile_tool", _, socket) do
    {:noreply, socket
      |> assign(mobile_active_tool: nil)
      |> push_event("hide_mobile_tool_modal", %{})}
  end

  @impl true
  def handle_event("mobile_tool_action", %{"action" => action, "tool_id" => tool_id} = params, socket) do
    case {tool_id, action} do
      {"chat", "send_message"} ->
        # Reuse existing chat functionality
        handle_event("send_session_message", %{"message" => params["message"]}, socket)

      {"recorder", "start_recording"} ->
        track_id = params["track_id"] || "mobile_track_1"
        handle_event("mobile_start_recording", %{"track_index" => 0}, socket)

      {"recorder", "stop_recording"} ->
        handle_event("mobile_stop_recording", %{"track_index" => 0}, socket)

      {"mixer", "update_volume"} ->
        track_id = params["track_id"]
        volume = params["volume"]
        handle_event("mobile_track_volume_change", %{
          "track_index" => get_track_index_by_id(socket, track_id),
          "volume" => volume
        }, socket)

      {"effects", "toggle_effect"} ->
        track_id = params["track_id"]
        effect_type = params["effect_type"]
        handle_event("mobile_toggle_effect", %{
          "track_index" => get_track_index_by_id(socket, track_id),
          "effect_type" => effect_type
        }, socket)

      _ ->
        {:noreply, socket |> add_notification("Action #{action} not supported", :warning)}
    end
  end

  # Mobile Tool Modal Events
  @impl true
  def handle_event("show_mobile_tool_modal", %{"tool_id" => tool_id}, socket) do
    {:noreply, socket
      |> assign(show_mobile_tool_modal: true)
      |> assign(mobile_modal_tool: tool_id)
      |> push_event("mobile_tool_modal_opened", %{tool_id: tool_id})}
  end

  @impl true
  def handle_event("hide_mobile_tool_modal", _, socket) do
    {:noreply, socket
      |> assign(show_mobile_tool_modal: false)
      |> assign(mobile_modal_tool: nil)}
  end

  # Mobile gesture handlers
  @impl true
  def handle_event("mobile_swipe", %{"direction" => direction}, socket) do
    case direction do
      "up" when not socket.assigns.mobile_tool_drawer_open ->
        # Swipe up to open tool drawer
        {:noreply, assign(socket, mobile_tool_drawer_open: true)}

      "down" when socket.assigns.mobile_tool_drawer_open ->
        # Swipe down to close tool drawer
        {:noreply, assign(socket, mobile_tool_drawer_open: false)}

      "left" ->
        # Swipe left to cycle through primary tools
        cycle_mobile_primary_tool(socket, :next)

      "right" ->
        # Swipe right to cycle through primary tools
        cycle_mobile_primary_tool(socket, :previous)

      _ ->
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

    # ENHANCED: Real-time effect parameter updates
  def handle_event("audio_effect_parameter_update", %{
    "track_id" => track_id,
    "effect_id" => effect_id,
    "parameter" => parameter,
    "value" => value
  }, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id

      # Use enhanced audio integration for real-time parameter updates
      operation = AudioOTIntegration.update_effect_parameter_realtime(
        session_id, user_id, track_id, effect_id, parameter, value
      )

      # Apply to workspace state with enhanced OT
      new_workspace_state = AudioOTIntegration.apply_enhanced_operation(
        socket.assigns.workspace_state, operation, session_id
      )

      {:noreply, socket
        |> assign(workspace_state: new_workspace_state)
        |> push_event("effect_parameter_updated", %{
          track_id: track_id,
          effect_id: effect_id,
          parameter: parameter,
          value: value
        })}
    else
      {:noreply, socket}
    end
  end

  # ENHANCED: Beat machine pattern editing with real-time sync
  def handle_event("beat_update_step_enhanced", %{
    "pattern_id" => pattern_id,
    "instrument" => instrument,
    "step" => step,
    "velocity" => velocity,
    "modifier_keys" => modifier_keys
  }, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id
      step = String.to_integer(step)
      velocity = String.to_integer(velocity)

      # Enhanced beat machine operation with conflict resolution
      pattern_data = %{
        pattern_id: pattern_id,
        instrument: instrument,
        step: step,
        velocity: velocity,
        modifier_keys: modifier_keys,
        timestamp: System.system_time(:microsecond)
      }

      operation = AudioOTIntegration.sync_beat_machine_operation(
        session_id, user_id, :update_step, pattern_data
      )

      # Update workspace state
      new_workspace_state = update_beat_machine_workspace(
        socket.assigns.workspace_state, operation
      )

      {:noreply, socket
        |> assign(workspace_state: new_workspace_state)
        |> push_event("beat_step_synced", %{
          pattern_id: pattern_id,
          step: step,
          velocity: velocity,
          sync_id: operation.data.operation_id
        })}
    else
      {:noreply, socket}
    end
  end

  # ENHANCED: Coordinated recording operations
  def handle_event("audio_start_recording_coordinated", %{
    "track_id" => track_id,
    "recording_options" => recording_options
  }, socket) do
    if can_record_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id

      recording_data = %{
        track_id: track_id,
        user_id: user_id,
        options: recording_options,
        timestamp: System.system_time(:microsecond)
      }

      case AudioOTIntegration.coordinate_recording_operation(
        session_id, user_id, :start_recording, recording_data
      ) do
        {:ok, operation} ->
          # Update presence to show coordinated recording
          update_presence(session_id, user_id, %{
            is_recording: true,
            active_audio_track: track_id,
            recording_coordinated: true,
            last_activity: DateTime.utc_now()
          })

          {:noreply, socket
            |> assign(:recording_track, track_id)
            |> add_notification("Recording started (coordinated)", :success)}

        {:error, :recording_limit_exceeded} ->
          {:noreply, socket |> put_flash(:error, "Recording limit exceeded for your tier")}

        {:error, :track_conflict} ->
          {:noreply, socket |> put_flash(:error, "Another user is already recording on this track")}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to start recording: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  # ENHANCED: Track property updates with conflict resolution
  def handle_event("audio_update_track_property_enhanced", %{
    "track_id" => track_id,
    "property" => property,
    "value" => value,
    "interaction_id" => interaction_id
  }, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id
      workspace_state = socket.assigns.workspace_state

      # Create enhanced operation with conflict resolution
      property_atom = String.to_existing_atom(property)

      operation = AudioOTIntegration.create_enhanced_audio_operation(
        :update_track_property,
        %{
          track_id: track_id,
          property: property_atom,
          value: value,
          interaction_id: interaction_id,
          previous_value: get_current_track_property(workspace_state, track_id, property_atom)
        },
        user_id,
        session_id,
        track_id: track_id
      )

      # Apply with enhanced transformation
      new_workspace_state = AudioOTIntegration.apply_enhanced_operation(
        workspace_state, operation, session_id
      )

      # Add to pending operations for conflict tracking
      pending_ops = [operation | socket.assigns.pending_operations]

      # Broadcast enhanced operation
      PubSub.broadcast(
        Frestyl.PubSub,
        "studio:#{session_id}:operations",
        {:enhanced_audio_operation, operation}
      )

      {:noreply, socket
        |> assign(workspace_state: new_workspace_state)
        |> assign(pending_operations: pending_ops)
        |> push_event("track_property_updated_enhanced", %{
          track_id: track_id,
          property: property,
          value: value,
          operation_id: operation.data.operation_id
        })}
    else
      {:noreply, socket}
    end
  end

  # ENHANCED: Audio clip manipulation with timing resolution
  def handle_event("audio_move_clip_enhanced", %{
    "clip_id" => clip_id,
    "new_track_id" => new_track_id,
    "new_start_time" => new_start_time,
    "snap_to_grid" => snap_to_grid
  }, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id

      # Enhanced clip movement with conflict resolution
      clip_data = %{
        clip_id: clip_id,
        track_id: new_track_id,
        start_time: String.to_float(new_start_time),
        snap_to_grid: snap_to_grid,
        movement_timestamp: System.system_time(:microsecond)
      }

      operation = AudioOTIntegration.create_enhanced_audio_operation(
        :move_clip,
        clip_data,
        user_id,
        session_id,
        clip_id: clip_id,
        track_id: new_track_id
      )

      # Get session context for conflict resolution
      session_context = %{
        grid_settings: get_grid_settings(socket.assigns.workspace_state),
        clip_conflict_strategy: get_user_clip_conflict_preference(user_id)
      }

      # Apply with context-aware transformation
      new_workspace_state = apply_clip_operation_with_context(
        socket.assigns.workspace_state, operation, session_context
      )

      {:noreply, socket
        |> assign(workspace_state: new_workspace_state)
        |> push_event("clip_moved_enhanced", %{
          clip_id: clip_id,
          new_track_id: new_track_id,
          new_start_time: new_start_time,
          operation_id: operation.data.operation_id
        })}
    else
      {:noreply, socket}
    end
  end

  # ENHANCED: Automation curve editing
  def handle_event("audio_update_automation", %{
    "track_id" => track_id,
    "parameter" => parameter,
    "automation_points" => points,
    "curve_type" => curve_type
  }, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id

      automation_data = %{
        track_id: track_id,
        parameter: parameter,
        automation_points: parse_automation_points(points),
        curve_type: curve_type,
        update_timestamp: System.system_time(:microsecond)
      }

      operation = AudioOTIntegration.create_enhanced_audio_operation(
        :update_automation,
        automation_data,
        user_id,
        session_id,
        track_id: track_id
      )

      # Apply automation with smooth interpolation
      new_workspace_state = AudioOTIntegration.apply_enhanced_operation(
        socket.assigns.workspace_state, operation, session_id
      )

      {:noreply, socket
        |> assign(workspace_state: new_workspace_state)
        |> push_event("automation_updated", %{
          track_id: track_id,
          parameter: parameter,
          points: points
        })}
    else
      {:noreply, socket}
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

  @impl true
  def handle_event("beat_update_step_enhanced", %{
    "pattern_id" => pattern_id,
    "instrument" => instrument,
    "step" => step,
    "velocity" => velocity,
    "modifier_keys" => modifier_keys
  }, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id
      step = String.to_integer(step)
      velocity = String.to_integer(velocity)

      # Use your existing BeatMachine call but with enhanced metadata
      case BeatMachine.update_pattern_step(session_id, pattern_id, instrument, step, velocity) do
        :ok ->
          {:noreply, socket |> push_event("beat_step_synced", %{
            pattern_id: pattern_id,
            step: step,
            velocity: velocity,
            modifier_keys: modifier_keys
          })}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to update step: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("audio_update_track_property_enhanced", %{
    "track_id" => track_id,
    "property" => property,
    "value" => value,
    "interaction_id" => interaction_id
  }, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id

      # Convert string values to appropriate types
      typed_value = case property do
        "volume" -> String.to_float(value)
        "pan" -> String.to_float(value)
        "muted" -> value == "true"
        "solo" -> value == "true"
        _ -> value
      end

      # Use your existing audio update logic but with enhanced tracking
      case AudioEngine.update_track_property(session_id, track_id, String.to_atom(property), typed_value) do
        :ok ->
          # Broadcast enhanced update
          PubSub.broadcast(
            Frestyl.PubSub,
            "studio:#{session_id}",
            {:track_property_updated_enhanced, %{
              track_id: track_id,
              property: property,
              value: typed_value,
              user_id: user_id,
              interaction_id: interaction_id
            }}
          )

          {:noreply, socket}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to update #{property}: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("audio_effect_parameter_update", %{
    "track_id" => track_id,
    "effect_id" => effect_id,
    "parameter" => parameter,
    "value" => value
  }, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      typed_value = String.to_float(value)

      # Apply effect parameter update
      case AudioEngine.update_effect_parameter(session_id, track_id, effect_id, parameter, typed_value) do
        :ok ->
          {:noreply, socket |> push_event("effect_parameter_updated", %{
            track_id: track_id,
            effect_id: effect_id,
            parameter: parameter,
            value: typed_value
          })}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to update effect: #{reason}")}
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

    # ENHANCED: Handle enhanced audio operations from other users
  def handle_info({:enhanced_audio_operation, remote_operation}, socket) do
    # Don't process our own operations
    if remote_operation.user_id != socket.assigns.current_user.id do
      current_workspace = socket.assigns.workspace_state
      pending_ops = socket.assigns.pending_operations

      # Enhanced transformation with audio context
      session_context = %{
        beat_machine_state: socket.assigns.beat_machine_state,
        audio_engine_state: socket.assigns.audio_engine_state,
        recording_state: get_recording_state(socket)
      }

      # Transform against pending operations with enhanced logic
      {transformed_remote_op, transformed_local_ops} =
        transform_enhanced_audio_operations(remote_operation, pending_ops, session_context)

      # Apply transformed remote operation
      new_workspace_state = AudioOTIntegration.apply_enhanced_operation(
        current_workspace, transformed_remote_op, socket.assigns.session.id
      )

      # Check for enhanced conflicts
      conflicts = detect_enhanced_audio_conflicts(transformed_remote_op, transformed_local_ops)

      socket = socket
        |> assign(workspace_state: new_workspace_state)
        |> assign(pending_operations: transformed_local_ops)

      # Enhanced notification with audio context
      username = get_username_from_collaborators(remote_operation.user_id, socket.assigns.collaborators)
      message = format_enhanced_audio_operation_message(transformed_remote_op, username)

      socket = if message do
        add_notification(socket, message, :info)
      else
        socket
      end

      # Handle enhanced conflicts with audio-specific resolution
      socket = if length(conflicts) > 0 do
        socket
        |> assign(operation_conflicts: conflicts)
        |> handle_enhanced_audio_conflicts(conflicts)
      else
        socket
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # ENHANCED: Handle beat machine synchronization
  def handle_info({:beat_machine_sync, {operation, sync_timestamp}}, socket) do
    if operation.user_id != socket.assigns.current_user.id do
      # Calculate sync latency
      current_time = System.system_time(:microsecond)
      latency = current_time - sync_timestamp

      # Apply beat operation with latency compensation
      new_workspace_state = apply_beat_operation_with_sync(
        socket.assigns.workspace_state, operation, latency
      )

      {:noreply, socket
        |> assign(workspace_state: new_workspace_state)
        |> push_event("beat_synced", %{
          operation_id: operation.data.operation_id,
          latency: latency
        })}
    else
      {:noreply, socket}
    end
  end

  # ENHANCED: Handle recording coordination events
  def handle_info({:recording_coordinated, operation, result}, socket) do
    if operation.user_id != socket.assigns.current_user.id do
      username = get_username_from_collaborators(operation.user_id, socket.assigns.collaborators)

      case {operation.action, result} do
        {:start_recording, {:ok, _}} ->
          message = "#{username} started recording on track #{operation.data.track_id}"
          {:noreply, socket |> add_notification(message, :info)}

        {:start_recording, {:error, :conflict}} ->
          message = "#{username}'s recording was blocked due to conflict"
          {:noreply, socket |> add_notification(message, :warning)}

        {:stop_recording, {:ok, clip_data}} ->
          message = "#{username} finished recording (#{clip_data.duration}s)"
          {:noreply, socket |> add_notification(message, :success)}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # ENHANCED: Handle audio collaboration state updates
  def handle_info({:operation_applied, operation, timestamp}, socket) do
    # Update collaboration metrics
    collaboration_metrics = socket.assigns[:collaboration_metrics] || %{}

    new_metrics = collaboration_metrics
    |> Map.update(:total_operations, 1, &(&1 + 1))
    |> Map.update(:audio_operations, 1, &(&1 + 1))
    |> Map.put(:last_operation_time, timestamp)

    {:noreply, assign(socket, collaboration_metrics: new_metrics)}
  end

  @impl true
  def handle_event("toggle_dock_visibility", %{"dock" => dock}, socket) do
    current_visibility = Map.get(socket.assigns, :dock_visibility, %{
      left: true,
      right: true,
      bottom: true
    })

    new_visibility = Map.put(current_visibility, String.to_atom(dock), !current_visibility[String.to_atom(dock)])

    {:noreply, socket
      |> assign(dock_visibility: new_visibility)
      |> push_event("dock_toggled", %{dock: dock, visible: new_visibility[String.to_atom(dock)]})}
  end

  defp assign_defaults(assigns) do
    defaults = %{
      recording_track: nil,
      chat_messages: [],
      message_input: "",
      typing_users: MapSet.new(),
      show_mobile_tool_modal: false,
      mobile_modal_tool: nil,
      mobile_active_tool: nil,
      show_more_mobile_tools: false
    }

    Map.merge(defaults, assigns)
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

    defp update_beat_machine_workspace(workspace_state, operation) do
    beat_state = workspace_state.beat_machine

    case operation.data.action do
      :update_step ->
        patterns = Map.get(beat_state, :patterns, %{})
        pattern_id = operation.data.pattern_id

        if Map.has_key?(patterns, pattern_id) do
          pattern = patterns[pattern_id]
          updated_pattern = update_pattern_step(pattern, operation.data)
          updated_patterns = Map.put(patterns, pattern_id, updated_pattern)

          new_beat_state = %{beat_state | patterns: updated_patterns, version: beat_state.version + 1}
          %{workspace_state | beat_machine: new_beat_state}
        else
          workspace_state
        end

      _ ->
        workspace_state
    end
  end

  defp update_pattern_step(pattern, step_data) do
    tracks = Map.get(pattern, :tracks, %{})
    instrument = step_data.instrument
    step = step_data.step
    velocity = step_data.velocity

    instrument_track = Map.get(tracks, instrument, [])
    updated_track = List.replace_at(instrument_track, step - 1, velocity)
    updated_tracks = Map.put(tracks, instrument, updated_track)

    %{pattern | tracks: updated_tracks}
  end

  defp ensure_workspace_state_structure(workspace_state) do
    # Ensure all required keys exist with defaults
    Map.merge(@default_workspace_state, workspace_state)
    |> ensure_ot_state()
  end

  defp get_current_track_property(workspace_state, track_id, property) do
    case Enum.find(workspace_state.audio.tracks, &(&1.id == track_id)) do
      nil -> nil
      track -> Map.get(track, property)
    end
  end

  defp get_grid_settings(workspace_state) do
    Map.get(workspace_state.audio, :grid_settings, %{snap_enabled: true, grid_size: 1000})
  end

  defp get_user_clip_conflict_preference(_user_id) do
    # Could be stored in user preferences
    :auto_adjust
  end

  defp apply_clip_operation_with_context(workspace_state, operation, session_context) do
    # Apply clip operation considering session context like grid settings
    AudioOTIntegration.apply_enhanced_operation(workspace_state, operation, session_context.session_id)
  end

  defp parse_automation_points(points) when is_list(points) do
    Enum.map(points, fn point ->
      %{
        time: point["time"],
        value: point["value"],
        curve_type: point["curve_type"] || "linear"
      }
    end)
  end

  defp parse_automation_points(_), do: []

  defp get_recording_state(socket) do
    %{
      recording_track: socket.assigns.recording_track,
      recording_mode: socket.assigns.recording_mode,
      active_recordings: get_active_session_recordings(socket.assigns.session.id)
    }
  end

  defp get_active_session_recordings(session_id) do
    # Get currently active recordings from presence or engine state
    case RecordingEngine.get_recording_state(session_id) do
      {:ok, state} -> state.active_recordings
      _ -> %{}
    end
  end

  defp transform_enhanced_audio_operations(remote_op, pending_ops, session_context) do
    Enum.reduce(pending_ops, {remote_op, []}, fn local_op, {current_remote, transformed_locals} ->
      # Use enhanced transformation with audio context
      {transformed_remote, transformed_local} =
        AudioOTIntegration.transform_with_audio_context(current_remote, local_op, :right, session_context)

      {transformed_remote, [transformed_local | transformed_locals]}
    end)
  end

  defp detect_enhanced_audio_conflicts(remote_op, local_ops) do
    Enum.reduce(local_ops, [], fn local_op, conflicts ->
      case detect_specific_audio_conflict(remote_op, local_op) do
        nil -> conflicts
        conflict -> [conflict | conflicts]
      end
    end)
  end

  defp detect_specific_audio_conflict(remote_op, local_op) do
    case {remote_op.action, local_op.action} do
      {:start_recording, :start_recording} ->
        if remote_op.data.track_id == local_op.data.track_id do
          %{
            type: :recording_conflict,
            track_id: remote_op.data.track_id,
            remote_user: remote_op.user_id,
            local_user: local_op.user_id,
            description: "Multiple users attempting to record on the same track"
          }
        else
          nil
        end

      {:update_beat_pattern, :update_beat_pattern} ->
        if remote_op.data.pattern_id == local_op.data.pattern_id and
           remote_op.data.step == local_op.data.step do
          %{
            type: :beat_pattern_conflict,
            pattern_id: remote_op.data.pattern_id,
            step: remote_op.data.step,
            description: "Multiple users editing the same beat pattern step"
          }
        else
          nil
        end

      _ -> nil
    end
  end

  # Add these helper functions to your StudioLive module

  defp list_media_items(session_id) do
    Media.list_session_media_items(session_id)
  end

  defp get_audio_engine_state(session_id) do
    # Return default audio engine state
    %{
      tracks: [],
      effects: [],
      master_volume: 0.8,
      monitoring: false,
      recording: false
    }
  end

  defp get_beat_machine_state(session_id) do
    # Return default beat machine state
    %{
      bpm: 120,
      pattern: [],
      playing: false,
      current_step: 0
    }
  end

  defp get_user_export_credits(user) do
    # Return export credits based on user tier
    case Frestyl.Studio.AudioEngineConfig.get_user_tier(user) do
      :enterprise -> 1000
      :pro -> 100
      :premium -> 50
      :free -> 10
    end
  end

  defp get_first_track_id(workspace_state) do
    case workspace_state do
      %{tracks: [first_track | _]} when is_map(first_track) ->
        Map.get(first_track, :id, 1)
      _ ->
        1
    end
  end

  defp start_audio_engine(session_id, is_mobile) do
    # Start audio engine based on device type
    if is_mobile do
      # Mobile-optimized audio engine
      send(self(), {:start_mobile_audio_engine, session_id})
    else
      # Desktop audio engine
      send(self(), {:start_desktop_audio_engine, session_id})
    end
  end

  defp ensure_ot_state(workspace_state) do
    # Ensure workspace state has operational transformation fields
    Map.merge(workspace_state, %{
      ot_version: Map.get(workspace_state, :ot_version, 0),
      pending_operations: Map.get(workspace_state, :pending_operations, [])
    })
  end

  defp list_collaborators(session_id) do
    # Get list of session collaborators
    Sessions.list_session_participants(session_id)
  rescue
    _ -> []  # Return empty list if function doesn't exist
  end

  defp determine_user_role(session_data, current_user) do
    cond do
      session_data.creator_id == current_user.id -> :creator
      session_data.host_id == current_user.id -> :host
      true -> :participant
    end
  end

  defp get_permissions_for_role(role, session_type) do
    base_permissions = %{
      can_edit: role in [:creator, :host],
      can_record: true,  # Always allow recording for audio tools
      can_chat: true,
      can_invite: role in [:creator, :host],
      can_end_session: role in [:creator, :host],
      can_use_audio_tools: true  # Add this for all roles
    }

    # Adjust permissions based on session type
    case session_type do
      "audio" -> Map.put(base_permissions, :can_use_audio_tools, true)
      "text" -> Map.put(base_permissions, :can_edit_text, true)
      "regular" -> Map.put(base_permissions, :can_use_audio_tools, true)  # Add this
      _ -> Map.put(base_permissions, :can_use_audio_tools, true)  # Default to audio tools
    end
  end

  defp generate_rtc_token(user_id, session_id) do
    # Generate a simple token - implement proper token generation
    Base.encode64("#{user_id}:#{session_id}:#{System.system_time(:second)}")
  end

  defp handle_enhanced_audio_conflicts(socket, conflicts) do
    # Add audio-specific conflict resolution UI hints
    conflict_messages = Enum.map(conflicts, fn conflict ->
      case conflict.type do
        :recording_conflict ->
          "Recording conflict on track #{conflict.track_id} - automatic resolution applied"

        :beat_pattern_conflict ->
          "Beat pattern step #{conflict.step} had conflicting edits - changes merged"

        _ ->
          "Audio operation conflict resolved automatically"
      end
    end)

    Enum.reduce(conflict_messages, socket, fn message, acc_socket ->
      add_notification(acc_socket, message, :warning)
    end)
  end

  defp format_enhanced_audio_operation_message(operation, username) do
    case operation.action do
      :start_recording ->
        "#{username} started recording on track #{operation.data.track_id}"

      :update_effect_parameter ->
        effect_name = get_effect_name(operation.data.effect_id)
        "#{username} adjusted #{effect_name} #{operation.data.parameter}"

      :update_beat_pattern ->
        "#{username} updated beat pattern step #{operation.data.step}"

      :move_clip ->
        "#{username} moved an audio clip"

      :update_automation ->
        "#{username} updated automation for #{operation.data.parameter}"

      _ ->
        nil
    end
  end

  defp get_effect_name(effect_id) do
    # Could look up from a registry of effects
    "effect"
  end

  defp apply_beat_operation_with_sync(workspace_state, operation, latency) do
    # Apply beat operation with latency compensation for tight sync
    # For now, just apply normally - could add timing adjustments
    AudioOTIntegration.apply_enhanced_operation(workspace_state, operation, operation.session_id)
  end

  defp get_tool_class(tool) do
    base_class = "tool-item"
    active_class = if Map.get(tool, :active, false), do: " active", else: ""
    enabled_class = if Map.get(tool, :enabled, true), do: "", else: " disabled"

    base_class <> active_class <> enabled_class
  end

  defp get_tool_badge(tool) do
    case Map.get(tool, :badge_count, 0) do
      0 -> ""
      count when count > 99 -> "99+"
      count -> to_string(count)
    end
  end

  defp render_tool_status(tool) do
    case Map.get(tool, :status, "ready") do
      "active" -> "🟢"
      "busy" -> "🟡"
      "error" -> "🔴"
      _ -> ""
    end
  end

  defp get_session_collaboration_mode(session_data) do
    case session_data.session_type do
      "audio" -> "audio_production"
      "text" -> "collaborative_writing"
      "visual" -> "multimedia_creation"
      _ -> "audio_production"  # This catches "regular" and any other types
    end
  end

  defp get_user_tool_layout(user_id, collaboration_mode) do
    mode_config = @collaboration_modes[collaboration_mode]
    apply_user_layout_preferences(mode_config.default_layout, user_id)
  end

  # Tool Icon Component
  defp tool_icon(assigns) do
    ~H"""
    <%= case @icon do %>
      <% "chat-bubble-left-ellipsis" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
        </svg>
      <% "document-text" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      <% "microphone" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
        </svg>
      <% "adjustments-horizontal" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
        </svg>
      <% "sparkles" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
        </svg>
      <% _ -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
        </svg>
    <% end %>
    """
  end

  # Tool Panel Renderer Component
  defp render_tool_panel(assigns) do
    ~H"""
    <div class="h-full flex flex-col" data-tool-id={@tool_id} data-dock={@dock_position}>
      <!-- Tool Header -->
      <div class="flex items-center justify-between p-3 border-b border-gray-800 bg-gray-800 bg-opacity-50">
        <div class="flex items-center space-x-2">
          <.tool_icon icon={get_tool_icon_class(@tool_id)} class="w-4 h-4 text-white" />
          <h3 class="text-white text-sm font-medium"><%= get_tool_display_name(@tool_id) %></h3>
        </div>

        <div class="flex items-center space-x-1">
          <!-- Minimize/Restore Button -->
          <button
            phx-click="toggle_tool_panel"
            phx-value-tool-id={@tool_id}
            class="text-gray-400 hover:text-white p-1"
            aria-label="Minimize tool"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4" />
            </svg>
          </button>

          <!-- Move Tool Button (Desktop only) -->
          <button
            class="hidden lg:block text-gray-400 hover:text-white p-1"
            data-drag-handle
            aria-label="Move tool"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
            </svg>
          </button>
        </div>
      </div>

      <!-- Modal Content -->
      <div class="flex-1 overflow-hidden">
        <%= case Map.get(assigns, :mobile_modal_tool) do %>
          <% "chat" -> %>
            <.render_mobile_chat_modal
              chat_messages={Map.get(assigns, :chat_messages, [])}
              message_input={Map.get(assigns, :message_input, "")}
              current_user={@current_user}
              typing_users={Map.get(assigns, :typing_users, MapSet.new())}
            />

          <% "editor" -> %>
            <.render_mobile_editor_modal
              workspace_state={@workspace_state}
              permissions={@permissions}
              current_user={@current_user}
            />

          <% "recorder" -> %>
            <.render_mobile_recorder_modal
              workspace_state={@workspace_state}
              permissions={@permissions}
              recording_track={Map.get(assigns, :recording_track)}
              current_user={@current_user}
            />

          <% "mixer" -> %>
            <.render_mobile_mixer_modal
              workspace_state={@workspace_state}
              permissions={@permissions}
            />

          <% "effects" -> %>
            <.render_mobile_effects_modal
              workspace_state={@workspace_state}
              permissions={@permissions}
            />

          <% _ -> %>
            <div class="p-4 text-center">
              <p class="text-gray-400">Mobile interface for <%= Map.get(assigns, :mobile_modal_tool, "tool") %> coming soon</p>
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Individual Tool Panel Components
  defp render_chat_panel(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Chat messages -->
      <div class="flex-1 overflow-y-auto p-3" id="tool-chat-messages">
        <%= if length(@chat_messages) == 0 do %>
          <div class="text-center text-gray-500 text-sm my-4">
            No messages yet
          </div>
        <% end %>

        <%= for message <- @chat_messages do %>
          <div class={[
            "flex mb-3",
            message.user_id == @current_user.id && "justify-end" || "justify-start"
          ]}>
            <%= if message.user_id != @current_user.id do %>
              <div class="flex-shrink-0 mr-2">
                <div class="h-6 w-6 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-medium text-xs">
                  <%= String.at(message.username, 0) %>
                </div>
              </div>
            <% end %>

            <div class={[
              "rounded-lg px-3 py-2 max-w-xs text-sm",
              message.user_id == @current_user.id && "bg-indigo-500 text-white" || "bg-gray-700 text-white"
            ]}>
              <%= if message.user_id != @current_user.id do %>
                <p class="text-xs font-medium text-gray-300 mb-1"><%= message.username %></p>
              <% end %>
              <p><%= message.content %></p>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Chat input -->
      <div class="p-3 border-t border-gray-700">
        <form phx-submit="send_session_message" class="flex">
          <input
            type="text"
            name="message"
            value={@message_input}
            phx-keyup="update_message_input"
            placeholder="Type a message..."
            class="flex-1 bg-gray-700 border-gray-600 rounded-l-md text-white text-sm focus:border-indigo-500"
          />
          <button
            type="submit"
            class="bg-indigo-500 hover:bg-indigo-600 text-white rounded-r-md px-3"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          </button>
        </form>
      </div>
    </div>
    """
  end

  defp render_editor_panel(assigns) do
    ~H"""
    <div class="h-full flex flex-col p-3">
      <div class="mb-2">
        <div class="text-xs text-gray-400 mb-1">Document Type</div>
        <select class="w-full bg-gray-700 border-gray-600 rounded text-white text-sm">
          <option>Plain Text</option>
          <option>Lyrics</option>
          <option>Script</option>
          <option>Article</option>
        </select>
      </div>

      <div class="flex-1">
        <textarea
          class="w-full h-full bg-gray-700 border-gray-600 rounded text-white text-sm resize-none"
          placeholder="Start writing..."
        ><%= @workspace_state.text.content %></textarea>
      </div>
    </div>
    """
  end

  defp render_recorder_panel(assigns) do
    ~H"""
    <div class="h-full flex flex-col p-3">
      <div class="mb-4">
        <div class="text-xs text-gray-400 mb-2">Recording</div>
        <%= if Map.get(assigns, :recording_track) do %>
          <div class="flex items-center space-x-2 text-red-400">
            <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
            <span class="text-sm">Recording to Track <%= Map.get(assigns, :recording_track) %></span>
          </div>
        <% else %>
          <div class="text-sm text-gray-500">Ready to record</div>
        <% end %>
      </div>

      <div class="space-y-3">
        <button
          phx-click={if Map.get(assigns, :recording_track), do: "audio_stop_recording", else: "audio_start_recording"}
          phx-value-track-id="track-1"
          class={[
            "w-full py-2 px-3 rounded font-medium text-sm",
            Map.get(assigns, :recording_track) && "bg-red-600 hover:bg-red-700 text-white" || "bg-indigo-600 hover:bg-indigo-700 text-white"
          ]}
        >
          <%= if Map.get(assigns, :recording_track), do: "Stop Recording", else: "Start Recording" %>
        </button>

        <div class="text-xs text-gray-400">
          Input Level
        </div>
        <div class="w-full bg-gray-700 rounded-full h-2">
          <div class="bg-green-500 h-2 rounded-full" style="width: 45%"></div>
        </div>
      </div>
    </div>
    """
  end

  defp render_mixer_panel(assigns) do
    ~H"""
    <div class="h-full overflow-y-auto p-3">
      <div class="text-xs text-gray-400 mb-3">Track Mixer</div>

      <%= if length(@workspace_state.audio.tracks) == 0 do %>
        <div class="text-center text-gray-500 text-sm py-8">
          No tracks available
        </div>
      <% else %>
        <div class="space-y-3">
          <%= for track <- @workspace_state.audio.tracks do %>
            <div class="bg-gray-700 rounded p-2">
              <div class="text-white text-sm font-medium mb-2"><%= track.name %></div>

              <div class="space-y-2">
                <!-- Volume -->
                <div>
                  <div class="text-xs text-gray-400 mb-1">Volume</div>
                  <input
                    type="range"
                    min="0"
                    max="1"
                    step="0.01"
                    value={track.volume}
                    phx-change="audio_update_track_volume"
                    phx-value-track-id={track.id}
                    class="w-full"
                  />
                </div>

                <!-- Mute/Solo -->
                <div class="flex space-x-2">
                  <button
                    phx-click="audio_mute_track"
                    phx-value-track-id={track.id}
                    phx-value-muted={!track.muted}
                    class={[
                      "flex-1 py-1 px-2 rounded text-xs font-medium",
                      track.muted && "bg-red-600 text-white" || "bg-gray-600 text-gray-300"
                    ]}
                  >
                    <%= if track.muted, do: "Unmute", else: "Mute" %>
                  </button>

                  <button
                    phx-click="audio_solo_track"
                    phx-value-track-id={track.id}
                    phx-value-solo={!track.solo}
                    class={[
                      "flex-1 py-1 px-2 rounded text-xs font-medium",
                      track.solo && "bg-yellow-600 text-white" || "bg-gray-600 text-gray-300"
                    ]}
                  >
                    <%= if track.solo, do: "Unsolo", else: "Solo" %>
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_effects_panel(assigns) do
    ~H"""
    <div class="h-full overflow-y-auto p-3">
      <div class="text-xs text-gray-400 mb-3">Effects Rack</div>

      <div class="space-y-3">
        <!-- Effect Categories -->
        <div class="grid grid-cols-2 gap-2">
          <button class="bg-gray-700 hover:bg-gray-600 rounded p-2 text-xs text-white">
            Reverb
          </button>
          <button class="bg-gray-700 hover:bg-gray-600 rounded p-2 text-xs text-white">
            Delay
          </button>
          <button class="bg-gray-700 hover:bg-gray-600 rounded p-2 text-xs text-white">
            EQ
          </button>
          <button class="bg-gray-700 hover:bg-gray-600 rounded p-2 text-xs text-white">
            Compressor
          </button>
        </div>

        <!-- Active Effects -->
        <div class="mt-4">
          <div class="text-xs text-gray-400 mb-2">Active Effects</div>
          <div class="text-sm text-gray-500 text-center py-4">
            No effects applied
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Mobile Tool Modal Components
  defp render_mobile_chat_modal(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Chat Messages -->
      <div class="flex-1 overflow-y-auto p-4 space-y-3">
        <%= if length(@chat_messages) == 0 do %>
          <div class="text-center text-gray-500 py-8">
            <svg class="w-12 h-12 mx-auto mb-3 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
            <p class="text-sm">No messages yet</p>
            <p class="text-xs text-gray-600 mt-1">Start the conversation!</p>
          </div>
        <% end %>

        <%= for message <- @chat_messages do %>
          <div class={[
            "flex",
            message.user_id == @current_user.id && "justify-end" || "justify-start"
          ]}>
            <%= if message.user_id != @current_user.id do %>
              <div class="flex-shrink-0 mr-3">
                <div class="h-8 w-8 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-medium text-sm">
                  <%= String.at(message.username, 0) %>
                </div>
              </div>
            <% end %>

            <div class="max-w-xs">
              <%= if message.user_id != @current_user.id do %>
                <p class="text-xs text-gray-400 mb-1 ml-1"><%= message.username %></p>
              <% end %>
              <div class={[
                "rounded-2xl px-4 py-2",
                message.user_id == @current_user.id && "bg-indigo-600 text-white rounded-br-md" || "bg-gray-700 text-white rounded-bl-md"
              ]}>
                <p class="text-sm"><%= message.content %></p>
                <p class="text-xs mt-1 opacity-70">
                  <%= Calendar.strftime(message.inserted_at, "%H:%M") %>
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Typing Indicator -->
      <%= if MapSet.size(@typing_users) > 0 do %>
        <div class="px-4 py-2 text-xs text-gray-400">
          Someone is typing...
        </div>
      <% end %>

      <!-- Chat Input -->
      <div class="p-4 border-t border-gray-700">
        <form phx-submit="send_session_message">
          <div class="flex space-x-2">
            <input
              type="text"
              name="message"
              value={@message_input}
              phx-keyup="update_message_input"
              phx-focus="typing_start"
              phx-blur="typing_stop"
              placeholder="Type your message..."
              class="flex-1 bg-gray-800 border-gray-600 rounded-full px-4 py-2 text-white text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            />
            <button
              type="submit"
              class="bg-indigo-600 hover:bg-indigo-700 text-white rounded-full p-2 transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
              </svg>
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp render_mobile_editor_modal(assigns) do
    ~H"""
    <div class="h-full flex flex-col p-4">
      <!-- Document Type Selector -->
      <div class="mb-4">
        <label class="block text-xs text-gray-400 mb-2">Document Type</label>
        <select class="w-full bg-gray-800 border-gray-600 rounded-lg px-3 py-2 text-white text-sm">
          <option>Plain Text</option>
          <option>Song Lyrics</option>
          <option>Script/Dialogue</option>
          <option>Article/Blog</option>
          <option>Book Chapter</option>
        </select>
      </div>

      <!-- Formatting Toolbar -->
      <div class="flex space-x-2 mb-4 p-2 bg-gray-800 rounded-lg">
        <button class="p-2 text-gray-400 hover:text-white rounded">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 4h8a4 4 0 014 4 4 4 0 01-4 4H6z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 12h9" />
          </svg>
        </button>
        <button class="p-2 text-gray-400 hover:text-white rounded">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V8a2 2 0 00-2-2h-5m-4 0V4a2 2 0 114 0v2m-4 0a2 2 0 104 0m-5 8a2 2 0 100-4 2 2 0 000 4zm0 0c1.306 0 2.417.835 2.83 2M9 14a3.001 3.001 0 00-2.83 2M15 11h3m-3 4h2" />
          </svg>
        </button>
      </div>

      <!-- Text Editor -->
      <div class="flex-1">
        <textarea
          id="mobile-text-editor"
          phx-hook="MobileTextEditor"
          phx-blur="text_update"
          phx-keyup="text_update"
          class="w-full h-full bg-gray-800 border-gray-600 rounded-lg p-3 text-white text-sm resize-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
          placeholder="Start writing your masterpiece..."
        ><%= @workspace_state.text.content %></textarea>
      </div>

      <!-- Word Count & Status -->
      <div class="mt-3 flex justify-between items-center text-xs text-gray-500">
        <span><%= String.length(@workspace_state.text.content) %> characters</span>
        <span>Auto-saved</span>
      </div>
    </div>
    """
  end

  defp render_mobile_recorder_modal(assigns) do
    ~H"""
    <div class="h-full flex flex-col p-4">
      <!-- Recording Status -->
      <div class="text-center mb-6">
        <%= if Map.get(assigns, :recording_track) do %>
          <div class="mb-4">
            <div class="w-20 h-20 mx-auto bg-red-600 rounded-full flex items-center justify-center animate-pulse">
              <svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="8" />
              </svg>
            </div>
            <p class="text-red-400 font-medium mt-2">Recording...</p>
            <p class="text-gray-400 text-sm">Track <%= Map.get(assigns, :recording_track) %></p>
          </div>
        <% else %>
          <div class="mb-4">
            <div class="w-20 h-20 mx-auto bg-gray-700 rounded-full flex items-center justify-center">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
              </svg>
            </div>
            <p class="text-gray-400 font-medium mt-2">Ready to Record</p>
          </div>
        <% end %>
      </div>

      <!-- Input Level Meter -->
      <div class="mb-6">
        <label class="block text-sm text-gray-400 mb-2">Input Level</label>
        <div class="w-full h-4 bg-gray-800 rounded-full overflow-hidden">
          <div class="h-full bg-gradient-to-r from-green-500 via-yellow-500 to-red-500 rounded-full transition-all duration-150" style="width: 45%"></div>
        </div>
        <div class="flex justify-between text-xs text-gray-500 mt-1">
          <span>Low</span>
          <span>Good</span>
          <span>Clip</span>
        </div>
      </div>

      <!-- Recording Controls -->
      <div class="space-y-4">
        <button
          phx-click="mobile_tool_action"
          phx-value-action={if Map.get(assigns, :recording_track), do: "stop_recording", else: "start_recording"}
          phx-value-tool-id="recorder"
          phx-value-track-id="mobile_track_1"
          class={[
            "w-full py-4 rounded-xl font-semibold text-lg transition-colors",
            Map.get(assigns, :recording_track) && "bg-red-600 hover:bg-red-700 text-white" || "bg-indigo-600 hover:bg-indigo-700 text-white"
          ]}
        >
          <%= if Map.get(assigns, :recording_track) do %>
            <!-- stop recording content -->
          <% else %>
            <!-- start recording content -->
          <% end %>
        </button>

        <!-- Quick Actions -->
        <div class="grid grid-cols-2 gap-3">
          <button class="bg-gray-700 hover:bg-gray-600 text-white py-2 rounded-lg text-sm">
            Playback
          </button>
          <button class="bg-gray-700 hover:bg-gray-600 text-white py-2 rounded-lg text-sm">
            Settings
          </button>
        </div>
      </div>

      <!-- Recording Tips -->
      <div class="mt-6 p-3 bg-gray-800 rounded-lg">
        <h4 class="text-white text-sm font-medium mb-2">💡 Recording Tips</h4>
        <ul class="text-xs text-gray-400 space-y-1">
          <li>• Keep device close for best quality</li>
          <li>• Find a quiet environment</li>
          <li>• Watch the input level meter</li>
        </ul>
      </div>
    </div>
    """
  end

  defp render_mobile_mixer_modal(assigns) do
    ~H"""
    <div class="h-full overflow-y-auto p-4">
      <!-- Master Controls -->
      <div class="mb-6 p-4 bg-gray-800 rounded-lg">
        <h3 class="text-white font-medium mb-3">Master Mix</h3>
        <div class="space-y-3">
          <div>
            <label class="block text-xs text-gray-400 mb-1">Master Volume</label>
            <input type="range" min="0" max="1" step="0.01" value="0.8" class="w-full" />
          </div>
          <div class="flex space-x-2">
            <button class="flex-1 bg-red-600 hover:bg-red-700 text-white py-2 rounded text-sm">
              Mute All
            </button>
            <button class="flex-1 bg-yellow-600 hover:bg-yellow-700 text-white py-2 rounded text-sm">
              Solo Clear
            </button>
          </div>
        </div>
      </div>

      <!-- Individual Tracks -->
      <%= if length(@workspace_state.audio.tracks) == 0 do %>
        <div class="text-center py-8">
          <svg class="w-12 h-12 mx-auto mb-3 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
          </svg>
          <p class="text-gray-500">No tracks to mix</p>
          <p class="text-xs text-gray-600 mt-1">Add some tracks to get started!</p>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for {track, index} <- Enum.with_index(@workspace_state.audio.tracks) do %>
            <div class="bg-gray-800 rounded-lg p-4">
              <div class="flex items-center justify-between mb-3">
                <h4 class="text-white font-medium"><%= track.name %></h4>
                <span class="text-xs text-gray-400">Track <%= index + 1 %></span>
              </div>

              <!-- Volume Fader -->
              <div class="mb-3">
                <div class="flex justify-between items-center mb-1">
                  <label class="text-xs text-gray-400">Volume</label>
                  <span class="text-xs text-gray-300"><%= round(track.volume * 100) %>%</span>
                </div>
                <input
                  type="range"
                  min="0"
                  max="1"
                  step="0.01"
                  value={track.volume}
                  phx-change="mobile_tool_action"
                  phx-value-action="update_volume"
                  phx-value-tool-id="mixer"
                  phx-value-track-id={track.id}
                  class="w-full"
                />
              </div>

              <!-- Pan Control -->
              <div class="mb-3">
                <div class="flex justify-between items-center mb-1">
                  <label class="text-xs text-gray-400">Pan</label>
                  <span class="text-xs text-gray-300">
                    <%= cond do %>
                      <% track.pan < -0.1 -> %>L<%= abs(round(track.pan * 100)) %>
                      <% track.pan > 0.1 -> %>R<%= round(track.pan * 100) %>
                      <% true -> %>Center
                    <% end %>
                  </span>
                </div>
                <input type="range" min="-1" max="1" step="0.01" value={track.pan} class="w-full" />
              </div>

              <!-- Mute/Solo Buttons -->
              <div class="flex space-x-2">
                <button
                  phx-click="mobile_tool_action"
                  phx-value-action="toggle_mute"
                  phx-value-tool-id="mixer"
                  phx-value-track-id={track.id}
                  class={[
                    "flex-1 py-2 rounded text-xs font-medium transition-colors",
                    track.muted && "bg-red-600 text-white" || "bg-gray-700 text-gray-300"
                  ]}
                >
                  <%= if track.muted, do: "Unmute", else: "Mute" %>
                </button>

                <button
                  phx-click="mobile_tool_action"
                  phx-value-action="toggle_solo"
                  phx-value-tool-id="mixer"
                  phx-value-track-id={track.id}
                  class={[
                    "flex-1 py-2 rounded text-xs font-medium transition-colors",
                    track.solo && "bg-yellow-600 text-white" || "bg-gray-700 text-gray-300"
                  ]}
                >
                  <%= if track.solo, do: "Unsolo", else: "Solo" %>
                </button>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_mobile_effects_modal(assigns) do
    ~H"""
    <div class="h-full overflow-y-auto p-4">
      <!-- Track Selector -->
      <div class="mb-4">
        <label class="block text-xs text-gray-400 mb-2">Apply Effects To</label>
        <select class="w-full bg-gray-800 border-gray-600 rounded-lg px-3 py-2 text-white text-sm">
          <option>Master Bus</option>
          <%= for track <- @workspace_state.audio.tracks do %>
            <option value={track.id}><%= track.name %></option>
          <% end %>
        </select>
      </div>

      <!-- Effect Categories -->
      <div class="space-y-4">
        <!-- EQ Section -->
        <div class="bg-gray-800 rounded-lg p-4">
          <h3 class="text-white font-medium mb-3">EQ</h3>
          <div class="space-y-3">
            <div>
              <label class="block text-xs text-gray-400 mb-1">Low</label>
              <input type="range" min="-12" max="12" step="0.1" value="0" class="w-full" />
            </div>
            <div>
              <label class="block text-xs text-gray-400 mb-1">Mid</label>
              <input type="range" min="-12" max="12" step="0.1" value="0" class="w-full" />
            </div>
            <div>
              <label class="block text-xs text-gray-400 mb-1">High</label>
              <input type="range" min="-12" max="12" step="0.1" value="0" class="w-full" />
            </div>
          </div>
        </div>

        <!-- Reverb Section -->
        <div class="bg-gray-800 rounded-lg p-4">
          <h3 class="text-white font-medium mb-3">Reverb</h3>
          <div class="space-y-3">
            <div>
              <label class="block text-xs text-gray-400 mb-1">Room Size</label>
              <input type="range" min="0" max="1" step="0.01" value="0.3" class="w-full" />
            </div>
            <div>
              <label class="block text-xs text-gray-400 mb-1">Wet/Dry</label>
              <input type="range" min="0" max="1" step="0.01" value="0.2" class="w-full" />
            </div>
          </div>
        </div>

        <!-- Compression Section -->
        <div class="bg-gray-800 rounded-lg p-4">
          <h3 class="text-white font-medium mb-3">Compressor</h3>
          <div class="space-y-3">
            <div>
              <label class="block text-xs text-gray-400 mb-1">Threshold</label>
              <input type="range" min="-40" max="0" step="0.1" value="-12" class="w-full" />
            </div>
            <div>
              <label class="block text-xs text-gray-400 mb-1">Ratio</label>
              <input type="range" min="1" max="20" step="0.1" value="4" class="w-full" />
            </div>
          </div>
        </div>

        <!-- Quick Effect Buttons -->
        <div class="grid grid-cols-2 gap-3">
          <button
            phx-click="mobile_tool_action"
            phx-value-action="toggle_effect"
            phx-value-tool-id="effects"
            phx-value-effect-type="reverb"
            class="bg-purple-600 hover:bg-purple-700 text-white py-3 rounded-lg text-sm font-medium"
          >
            🎵 Add Reverb
          </button>
          <button
            phx-click="mobile_tool_action"
            phx-value-action="toggle_effect"
            phx-value-tool-id="effects"
            phx-value-effect-type="delay"
            class="bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-lg text-sm font-medium"
          >
            🔄 Add Delay
          </button>
          <button
            phx-click="mobile_tool_action"
            phx-value-action="toggle_effect"
            phx-value-tool-id="effects"
            phx-value-effect-type="distortion"
            class="bg-red-600 hover:bg-red-700 text-white py-3 rounded-lg text-sm font-medium"
          >
            🔥 Distortion
          </button>
          <button class="bg-gray-700 hover:bg-gray-600 text-white py-3 rounded-lg text-sm font-medium">
            🧹 Clear All
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Add this to your mount/3 function to initialize enhanced audio collaboration.
  """
  def initialize_enhanced_audio_collaboration(socket, session_id) do
    # Initialize enhanced audio collaboration
    AudioOTIntegration.initialize_session(session_id)

    # Subscribe to enhanced audio events
    PubSub.subscribe(Frestyl.PubSub, "studio:#{session_id}:audio_collaboration")
    PubSub.subscribe(Frestyl.PubSub, "studio:#{session_id}:beat_sync")
    PubSub.subscribe(Frestyl.PubSub, "studio:#{session_id}:recording_coordination")

    # Add enhanced audio assigns
    socket
    |> assign(:enhanced_audio_enabled, true)
    |> assign(:collaboration_metrics, %{total_operations: 0, audio_operations: 0})
    |> assign(:audio_conflict_resolution, :automatic)
  end

  defp save_user_tool_layout_preference(user_id, layout) do
    case UserPreferences.update_tool_layout(user_id, layout) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end

  defp get_user_tool_layout_preferences(user_id) do
    case UserPreferences.get_or_create_tool_preferences(user_id) do
      {:ok, preferences} -> preferences.tool_layout
      {:error, _} -> nil
    end
  end

  defp clear_user_tool_layout_preferences(user_id) do
    save_user_tool_layout_preference(user_id, %{})
  end

  @doc """
  Add this to handle termination for cleanup.
  """
  def cleanup_enhanced_audio_collaboration(session_id) do
    AudioOTIntegration.cleanup_session(session_id)
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
  @impl true
  def handle_info({:track_property_updated_enhanced, data}, socket) do
    if data.user_id != socket.assigns.current_user.id do
      username = get_username_from_collaborators(data.user_id, socket.assigns.collaborators)
      property_name = String.replace(data.property, "_", " ")
      message = "#{username} updated #{property_name}"

      {:noreply, socket
        |> add_notification(message, :info)
        |> push_event("track_property_updated_enhanced", data)}
    else
      {:noreply, socket}
    end
  end

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

  # Mobile-specific helper functions
  defp cycle_mobile_primary_tool(socket, direction) do
    mode_config = @collaboration_modes[socket.assigns.collaboration_mode]
    primary_tools = mode_config.primary_tools
    current_tool = socket.assigns[:mobile_active_tool]

    current_index = case Enum.find_index(primary_tools, &(&1 == current_tool)) do
      nil -> 0
      index -> index
    end

    new_index = case direction do
      :next -> rem(current_index + 1, length(primary_tools))
      :previous -> rem(current_index - 1 + length(primary_tools), length(primary_tools))
    end

    new_tool = Enum.at(primary_tools, new_index)

    {:noreply, socket
      |> assign(mobile_active_tool: new_tool)
      |> push_event("mobile_tool_cycled", %{tool_id: new_tool, direction: direction})}
  end

  defp get_track_index_by_id(socket, track_id) do
    tracks = socket.assigns.workspace_state.audio.tracks
    case Enum.find_index(tracks, &(&1.id == track_id)) do
      nil -> 0
      index -> index
    end
  end

  defp get_mobile_tool_priority(tool_id, collaboration_mode) do
    mode_config = @collaboration_modes[collaboration_mode]

    cond do
      tool_id in mode_config.primary_tools -> 1
      tool_id in mode_config.secondary_tools -> 2
      true -> 3
    end
  end

  defp get_mobile_layout_for_mode(collaboration_mode) do
    mode_config = @collaboration_modes[collaboration_mode]

    %{
      primary_tools: mode_config.primary_tools,
      quick_access: Enum.take(mode_config.secondary_tools, 2),
      hidden_tools: Enum.drop(mode_config.secondary_tools, 2)
    }
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

  defp get_available_tools(session_type, permissions) do
    tools = []

    tools = if permissions.can_chat do
      tools ++ [%{id: "chat", name: "Chat", description: "Send messages", icon: "document-text", active: false, enabled: true, badge_count: 0}]
    else
      tools
    end

    tools = if permissions.can_edit do
      tools ++ [%{id: "editor", name: "Editor", description: "Edit content", icon: "pencil", active: false, enabled: true, badge_count: 0}]
    else
      tools
    end

    # Add audio tools if permitted
    tools = if Map.get(permissions, :can_use_audio_tools, false) or permissions.can_record do
      tools ++ [
        %{id: "recorder", name: "Recorder", description: "Record audio", icon: "microphone", active: false, enabled: true, badge_count: 0},
        %{id: "mixer", name: "Audio Mixer", description: "Mix tracks", icon: "adjustments-horizontal", active: false, enabled: true, badge_count: 0},
        %{id: "effects", name: "Effects", description: "Audio effects", icon: "sparkles", active: false, enabled: true, badge_count: 0}
      ]
    else
      tools
    end

    tools
  end

  # Tool Panel Helper Functions
  defp apply_user_layout_preferences(default_layout, user_id) do
    case get_user_tool_layout_preferences(user_id) do
      nil -> default_layout
      user_prefs -> Map.merge(default_layout, user_prefs)
    end
  end

  defp get_tool_preferred_dock(tool_id, collaboration_mode) do
    mode_config = @collaboration_modes[collaboration_mode]

    cond do
      tool_id in mode_config.primary_tools ->
        case tool_id do
          "chat" -> "right_dock"
          "editor" -> "left_dock"
          "recorder" -> "bottom_dock"
          "mixer" -> "left_dock"
          "effects" -> "bottom_dock"
          _ -> "left_dock"
        end
      true -> "minimized"
    end
  end

  defp get_available_tools_for_mode(collaboration_mode) do
    # Define collaboration modes as a local variable instead of module attribute
    collaboration_modes = %{
      "collaborative_writing" => %{
        description: "Real-time writing together",
        primary_tools: ["editor", "chat"],
        secondary_tools: ["recorder", "mixer", "effects"]
      },

      "audio_production" => %{
        description: "Creating/mixing audio together",
        primary_tools: ["recorder", "mixer", "effects"],
        secondary_tools: ["editor", "chat"]
      },

      "social_listening" => %{
        description: "Listen/watch together + discuss",
        primary_tools: ["chat"],
        secondary_tools: ["editor", "recorder"]
      },

      "content_review" => %{
        description: "Review/critique existing content",
        primary_tools: ["chat", "editor"],
        secondary_tools: ["recorder", "mixer"]
      },

      "live_session" => %{
        description: "One presents, others participate",
        primary_tools: ["recorder", "chat"],
        secondary_tools: ["editor", "mixer", "effects"]
      },

      "multimedia_creation" => %{
        description: "Text + audio + media together",
        primary_tools: ["editor", "recorder", "mixer"],
        secondary_tools: ["effects", "chat"]
      }
    }

    mode_config = Map.get(collaboration_modes, collaboration_mode)

    if mode_config do
      all_tools = mode_config.primary_tools ++ mode_config.secondary_tools

      Enum.map(all_tools, fn tool_id ->
        %{
          id: tool_id,
          name: get_tool_display_name(tool_id),
          description: get_tool_description(tool_id),
          icon: get_tool_icon_class(tool_id),
          is_primary: tool_id in mode_config.primary_tools,
          enabled: true
        }
      end)
    else
      # Fallback if collaboration mode not found
      [
        %{id: "chat", name: "Chat", description: "Send messages", icon: "chat-bubble-left-ellipsis", is_primary: true, enabled: true},
        %{id: "mixer", name: "Audio Mixer", description: "Mix tracks", icon: "adjustments-horizontal", is_primary: true, enabled: true},
        %{id: "recorder", name: "Recorder", description: "Record audio", icon: "microphone", is_primary: true, enabled: true}
      ]
    end
  end

  defp get_tool_display_name(tool_id) do
    case tool_id do
      "chat" -> "Chat"
      "editor" -> "Editor"
      "recorder" -> "Recorder"
      "mixer" -> "Audio Mixer"
      "effects" -> "Effects"
      _ -> String.capitalize(tool_id)
    end
  end

  defp get_tool_description(tool_id) do
    case tool_id do
      "chat" -> "Real-time messaging"
      "editor" -> "Collaborative text editing"
      "recorder" -> "Audio recording"
      "mixer" -> "Track mixing controls"
      "effects" -> "Audio effects rack"
      _ -> "Collaboration tool"
    end
  end

  defp get_tool_icon_class(tool_id) do
    case tool_id do
      "chat" -> "chat-bubble-left-ellipsis"
      "editor" -> "document-text"
      "recorder" -> "microphone"
      "mixer" -> "adjustments-horizontal"
      "effects" -> "sparkles"
      _ -> "squares-2x2"
    end
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
    # Temporary debug
    if not Map.has_key?(assigns, :mobile_modal_tool) do
      IO.puts("ERROR: mobile_modal_tool missing from assigns!")
      IO.inspect(Map.keys(assigns), label: "Available assigns")
    end
    # Safe access to all assigns with defaults
    show_mobile_tool_modal = Map.get(assigns, :show_mobile_tool_modal, false)
    mobile_modal_tool = Map.get(assigns, :mobile_modal_tool)
    mobile_tool_drawer_open = Map.get(assigns, :mobile_tool_drawer_open, false)
    tool_layout = Map.get(assigns, :tool_layout, %{left_dock: [], right_dock: ["chat"], bottom_dock: [], floating: [], minimized: []})
    available_tools = Map.get(assigns, :available_tools, [])
    mobile_layout = Map.get(assigns, :mobile_layout, %{primary_tools: [], quick_access: [], hidden_tools: []})

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

      <!-- Main content area with dockable panels -->
      <div class="flex flex-1 overflow-hidden" id="main-content" phx-hook="ToolDragDrop">

        <!-- Left sidebar - Tools -->
        <div class="w-16 bg-gray-900 bg-opacity-70 flex flex-col items-center py-4 space-y-4 border-r border-gray-800">
          <%= for tool <- @available_tools do %>
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
              title={tool.name}
            >
              <.tool_icon icon={tool.icon} class="w-6 h-6" />
            </button>
          <% end %>
        </div>
      <!-- Left Dock Panel -->
      <%= if length(@tool_layout.left_dock) > 0 and Map.get(@dock_visibility || %{left: true}, :left, true) do %>
        <div class="w-80 bg-gray-900 bg-opacity-70 flex flex-col border-r border-gray-800" id="left-dock">
          <div class="flex items-center justify-between p-3 border-b border-gray-800">
            <h3 class="text-white text-sm font-medium">Tools</h3>
            <button
              phx-click="toggle_dock_visibility"
              phx-value-dock="left"
              class="text-gray-400 hover:text-white"
              aria-label="Toggle left panel"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
            </button>
          </div>

          <div class="flex-1 overflow-hidden">
            <%= for tool_id <- @tool_layout.left_dock do %>
              <.render_tool_panel
                tool_id={tool_id}
                dock_position="left"
                collaboration_mode={@collaboration_mode}
                current_user={@current_user}
                session={@session}
                workspace_state={@workspace_state}
                permissions={@permissions}
                recording_track={Map.get(assigns, :recording_track)}
                chat_messages={Map.get(assigns, :chat_messages, [])}
                message_input={Map.get(assigns, :message_input, "")}
                typing_users={Map.get(assigns, :typing_users, MapSet.new())}
              />
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Collapsed Left Dock (show toggle button when hidden) -->
      <%= if length(@tool_layout.left_dock) > 0 and not Map.get(@dock_visibility || %{left: true}, :left, true) do %>
        <div class="w-8 bg-gray-900 bg-opacity-70 flex flex-col items-center py-4 border-r border-gray-800" id="left-dock-collapsed">
          <button
            phx-click="toggle_dock_visibility"
            phx-value-dock="left"
            class="text-gray-400 hover:text-white p-2 rounded"
            aria-label="Show left panel"
            title="Show Tools"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>
      <% end %>

        <!-- Mobile Tool Drawer Button -->
        <button
          phx-click="toggle_mobile_drawer"
          class="lg:hidden fixed top-20 left-4 z-40 w-12 h-12 bg-indigo-600 hover:bg-indigo-700 rounded-full shadow-lg flex items-center justify-center"
          aria-label="Open tools"
        >
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>

        <!-- Mobile Tool Bottom Sheet -->
        <div
          class={[
            "lg:hidden fixed inset-x-0 bottom-0 z-30 transform transition-transform duration-300 ease-out",
            @mobile_tool_drawer_open && "translate-y-0" || "translate-y-full"
          ]}
          id="mobile-tool-bottom-sheet"
          phx-hook="MobileGestures"
        >
          <!-- Bottom Sheet Handle -->
          <div class="bg-gray-800 rounded-t-xl shadow-2xl">
            <div class="flex justify-center py-2">
              <div class="w-12 h-1 bg-gray-600 rounded-full"></div>
            </div>

            <!-- Tool Header -->
            <div class="px-4 pb-3 border-b border-gray-700">
              <div class="flex items-center justify-between">
                <h3 class="text-white font-semibold">Collaboration Tools</h3>
                <div class="flex items-center space-x-2">
                  <!-- Mode indicator -->
                  <span class="text-xs text-gray-400 bg-gray-700 px-2 py-1 rounded">
                    <%= String.replace(@collaboration_mode, "_", " ") |> String.capitalize() %>
                  </span>
                  <button
                    phx-click="toggle_mobile_drawer"
                    class="text-gray-400 hover:text-white p-1"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                </div>
              </div>
            </div>

            <!-- Primary Tools (Always Visible) -->
            <div class="px-4 py-3">
              <div class="text-xs text-gray-400 uppercase tracking-wider mb-2">Primary Tools</div>
              <div class="grid grid-cols-3 gap-3">
                <%= for tool_id <- @mobile_layout.primary_tools do %>
                  <% tool = Enum.find(@available_tools, &(&1.id == tool_id)) %>
                  <button
                    phx-click="activate_mobile_tool"
                    phx-value-tool-id={tool_id}
                    class={[
                      "flex flex-col items-center p-3 rounded-lg transition-all duration-200",
                      @mobile_active_tool == tool_id && "bg-indigo-600 scale-105" || "bg-gray-700 hover:bg-gray-600"
                    ]}
                  >
                    <div class="w-8 h-8 mb-2 flex items-center justify-center">
                      <.tool_icon icon={tool.icon} class="w-6 h-6 text-white" />
                    </div>
                    <span class="text-white text-xs font-medium"><%= tool.name %></span>
                  </button>
                <% end %>
              </div>
            </div>

            <!-- Quick Access Tools -->
            <%= if length(@mobile_layout.quick_access) > 0 do %>
              <div class="px-4 py-3 border-t border-gray-700">
                <div class="text-xs text-gray-400 uppercase tracking-wider mb-2">Quick Access</div>
                <div class="flex space-x-3 overflow-x-auto">
                  <%= for tool_id <- @mobile_layout.quick_access do %>
                    <% tool = Enum.find(@available_tools, &(&1.id == tool_id)) %>
                    <button
                      phx-click="activate_mobile_tool"
                      phx-value-tool-id={tool_id}
                      class="flex-shrink-0 flex items-center space-x-2 bg-gray-700 hover:bg-gray-600 px-3 py-2 rounded-lg"
                    >
                      <.tool_icon icon={tool.icon} class="w-4 h-4 text-white" />
                      <span class="text-white text-sm"><%= tool.name %></span>
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- More Tools (Collapsible) -->
            <%= if length(@mobile_layout.hidden_tools) > 0 do %>
              <div class="px-4 py-3 border-t border-gray-700">
                <button
                  phx-click="toggle_more_mobile_tools"
                  class="flex items-center justify-between w-full text-left"
                >
                  <span class="text-xs text-gray-400 uppercase tracking-wider">More Tools</span>
                  <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                  </svg>
                </button>

                <div class="mt-2 space-y-2" id="mobile-more-tools" style="display: none;">
                  <%= for tool_id <- @mobile_layout.hidden_tools do %>
                    <% tool = Enum.find(@available_tools, &(&1.id == tool_id)) %>
                    <button
                      phx-click="activate_mobile_tool"
                      phx-value-tool-id={tool_id}
                      class="w-full flex items-center space-x-3 p-2 text-left bg-gray-700 hover:bg-gray-600 rounded"
                    >
                      <.tool_icon icon={tool.icon} class="w-4 h-4 text-white" />
                      <div>
                        <div class="text-white text-sm"><%= tool.name %></div>
                        <div class="text-gray-400 text-xs"><%= tool.description %></div>
                      </div>
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Mobile Drawer Overlay -->
        <%= if @mobile_tool_drawer_open do %>
          <div
            class="lg:hidden fixed inset-0 bg-black bg-opacity-50 z-20"
            phx-click="toggle_mobile_drawer"
          ></div>
        <% end %>

        <!-- Mobile Tool Trigger Button (Floating) -->
        <button
          phx-click="toggle_mobile_drawer"
          class={[
            "lg:hidden fixed bottom-6 right-6 z-40 w-14 h-14 rounded-full shadow-lg flex items-center justify-center transition-all duration-300",
            @mobile_tool_drawer_open && "bg-gray-600 rotate-45" || "bg-indigo-600 hover:bg-indigo-700"
          ]}
          aria-label="Toggle collaboration tools"
        >
          <%= if @mobile_tool_drawer_open do %>
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          <% else %>
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h8m-8 6h16" />
            </svg>
          <% end %>
        </button>

        <!-- Main Workspace Area -->
        <div class="flex-1 flex flex-col overflow-hidden">
          <!-- Your existing workspace content stays here -->
          <%= case @active_tool do %>
            <% "audio" -> %>
              <!-- Your existing audio workspace -->
              <div class="h-full flex flex-col bg-gray-900 bg-opacity-50">
                <!-- Keep your existing audio workspace content -->
              </div>
            <% "text" -> %>
              <!-- Your existing text workspace -->
              <div class="h-full flex flex-col bg-gray-900 bg-opacity-50">
                <!-- Keep your existing text workspace content -->
              </div>
            <% _ -> %>
              <div class="h-full flex items-center justify-center">
                <p class="text-white">Workspace for <%= @active_tool %></p>
              </div>
          <% end %>

          <!-- Bottom Dock Panel -->
          <%= if length(@tool_layout.bottom_dock) > 0 do %>
            <div class="h-48 bg-gray-900 bg-opacity-70 border-t border-gray-800 flex" id="bottom-dock">
              <%= for tool_id <- @tool_layout.bottom_dock do %>
                <div class="flex-1 border-r border-gray-800 last:border-r-0">
                  <.render_tool_panel
                    tool_id={tool_id}
                    socket={@socket}
                    dock_position="bottom"
                    collaboration_mode={@collaboration_mode}
                    current_user={@current_user}
                    session={@session}
                    workspace_state={@workspace_state}
                    permissions={@permissions}
                  />
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

      <!-- Right Dock Panel (Enhanced Chat + Other Tools) -->
      <%= if Map.get(@dock_visibility || %{right: true}, :right, true) do %>
        <div class="w-80 bg-gray-900 bg-opacity-70 flex flex-col border-l border-gray-800" id="right-dock">
          <div class="flex items-center justify-between p-2 border-b border-gray-800">
            <h3 class="text-white text-sm font-medium">Chat</h3>
            <button
              phx-click="toggle_dock_visibility"
              phx-value-dock="right"
              class="text-gray-400 hover:text-white p-1"
              aria-label="Toggle right panel"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>
          <!-- Tool Tabs -->
          <%= if length(@tool_layout.right_dock) > 1 do %>
            <div class="flex border-b border-gray-800">
              <%= for tool_id <- @tool_layout.right_dock do %>
                <button
                  phx-click="set_active_right_tool"
                  phx-value-tool-id={tool_id}
                  class={[
                    "flex-1 py-3 text-center text-sm font-medium transition-colors",
                    "text-white bg-indigo-500 bg-opacity-20" # Adjust based on active state
                  ]}
                >
                  <%= get_tool_display_name(tool_id) %>
                </button>
              <% end %>
            </div>
          <% end %>

          <!-- Tool Content -->
          <div class="flex-1 overflow-hidden">
            <%= for tool_id <- @tool_layout.right_dock do %>
              <.render_tool_panel
                tool_id={tool_id}
                socket={@socket}
                dock_position="right"
                collaboration_mode={@collaboration_mode}
                current_user={@current_user}
                session={@session}
                workspace_state={@workspace_state}
                permissions={@permissions}
              />
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Collapsed Right Dock -->
      <%= if not Map.get(@dock_visibility || %{right: true}, :right, true) do %>
        <div class="w-8 bg-gray-900 bg-opacity-70 flex flex-col items-center py-4 border-l border-gray-800">
          <button
            phx-click="toggle_dock_visibility"
            phx-value-dock="right"
            class="text-gray-400 hover:text-white p-2 rounded"
            aria-label="Show right panel"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 5l-7 7 7 7" />
            </svg>
          </button>
        </div>
      <% end %>
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
      <!-- Mobile Tool Modals -->
      <%= if Map.get(assigns, :show_mobile_tool_modal, false) do %>
        <div class="lg:hidden fixed inset-0 z-50 bg-black bg-opacity-75 flex items-center justify-center p-4">
          <!-- Modal Container -->
          <div class="w-full max-w-sm bg-gray-900 rounded-xl shadow-2xl max-h-[80vh] flex flex-col">
            <!-- Modal Header -->
            <div class="flex items-center justify-between p-4 border-b border-gray-700">
              <div class="flex items-center space-x-2">
                <.tool_icon icon={get_tool_icon_class(Map.get(assigns, :mobile_modal_tool, "chat"))} class="w-5 h-5 text-white" />
                <h3 class="text-white font-semibold"><%= get_tool_display_name(Map.get(assigns, :mobile_modal_tool, "chat")) %></h3>
              </div>
              <button
                phx-click="hide_mobile_tool_modal"
                class="text-gray-400 hover:text-white p-1"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <!-- Modal Content -->
            <div class="flex-1 overflow-hidden">
              <%= case Map.get(assigns, :mobile_modal_tool) do %>
                <% "chat" -> %>
                  <.render_mobile_chat_modal
                    chat_messages={Map.get(assigns, :chat_messages, [])}
                    message_input={Map.get(assigns, :message_input, "")}
                    current_user={@current_user}
                    typing_users={Map.get(assigns, :typing_users, MapSet.new())}
                  />

                <% "editor" -> %>
                  <.render_mobile_editor_modal
                    workspace_state={@workspace_state}
                    permissions={@permissions}
                    current_user={@current_user}
                  />

                <% "recorder" -> %>
                  <.render_mobile_recorder_modal
                    workspace_state={@workspace_state}
                    permissions={@permissions}
                    recording_track={Map.get(assigns, :recording_track)}
                    current_user={@current_user}
                  />

                <% "mixer" -> %>
                  <.render_mobile_mixer_modal
                    workspace_state={@workspace_state}
                    permissions={@permissions}
                  />

                <% "effects" -> %>
                  <.render_mobile_effects_modal
                    workspace_state={@workspace_state}
                    permissions={@permissions}
                  />

                <% _ -> %>
                  <div class="p-4 text-center">
                    <p class="text-gray-400">Mobile interface for <%= Map.get(assigns, :mobile_modal_tool, "tool") %> coming soon</p>
                  </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
