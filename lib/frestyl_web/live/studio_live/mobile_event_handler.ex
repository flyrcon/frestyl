defmodule FrestylWeb.StudioLive.MobileEventHandler do
  @moduledoc """
  Handles mobile-specific events for the Studio LiveView.
  """

  import Phoenix.LiveView
  import Phoenix.Component
  require Logger

  alias Phoenix.PubSub

  # Permission helpers
  defp can_edit_audio?(permissions), do: Map.get(permissions, :can_edit_audio, false)
  defp can_edit_text?(permissions), do: Map.get(permissions, :can_edit_text, false)

  # Notification helper
  defp add_notification(socket, message, type \\ :info) do
    notification = %{
      id: System.unique_integer([:positive]),
      type: type,
      message: message,
      timestamp: DateTime.utc_now()
    }
    notifications = [notification | (socket.assigns[:notifications] || [])] |> Enum.take(5)
    assign(socket, notifications: notifications)
  end

  # Mobile Interface Events
  def handle_event("mobile_toggle_drawer", _params, socket) do
    new_state = !socket.assigns.mobile_tool_drawer_open

    {:noreply, socket
      |> LiveView.assign(mobile_tool_drawer_open: new_state)
      |> LiveView.push_event("mobile_drawer_toggled", %{open: new_state})}
  end

  def handle_event("mobile_activate_tool", %{"tool_id" => tool_id}, socket) do
    case tool_id do
      "chat" ->
        {:noreply, socket
          |> LiveView.assign(mobile_tool_drawer_open: false)
          |> LiveView.assign(show_mobile_tool_modal: true)
          |> LiveView.assign(mobile_modal_tool: "chat")}

      "editor" ->
        {:noreply, socket
          |> LiveView.assign(mobile_tool_drawer_open: false)
          |> LiveView.assign(show_mobile_tool_modal: true)
          |> LiveView.assign(mobile_modal_tool: "editor")
          |> LiveView.assign(active_tool: "text")}

      "recorder" ->
        if can_record_audio?(socket.assigns.permissions) do
          {:noreply, socket
            |> LiveView.assign(mobile_tool_drawer_open: false)
            |> LiveView.assign(show_mobile_tool_modal: true)
            |> LiveView.assign(mobile_modal_tool: "recorder")}
        else
          {:noreply, socket
            |> LiveView.assign(mobile_tool_drawer_open: false)
            |> LiveView.put_flash(:error, "You don't have permission to record")}
        end

      "mixer" ->
        {:noreply, socket
          |> LiveView.assign(mobile_tool_drawer_open: false)
          |> LiveView.assign(show_mobile_tool_modal: true)
          |> LiveView.assign(mobile_modal_tool: "mixer")}

      "effects" ->
        {:noreply, socket
          |> LiveView.assign(mobile_tool_drawer_open: false)
          |> LiveView.assign(show_mobile_tool_modal: true)
          |> LiveView.assign(mobile_modal_tool: "effects")}

      _ ->
        {:noreply, socket
          |> LiveView.assign(mobile_tool_drawer_open: false)
          |> add_notification("Tool #{tool_id} not yet implemented on mobile", :info)}
    end
  end

  def handle_event("mobile_close_tool", _params, socket) do
    {:noreply, socket
      |> LiveView.assign(show_mobile_tool_modal: false)
      |> LiveView.assign(mobile_modal_tool: nil)}
  end

  def handle_event("mobile_hide_tool_modal", _params, socket) do
    {:noreply, socket
      |> LiveView.assign(show_mobile_tool_modal: false)
      |> LiveView.assign(mobile_modal_tool: nil)}
  end

  # Mobile Audio Controls
  def handle_event("mobile_audio_initialized", %{"capabilities" => caps, "config" => config}, socket) do
    Logger.info("Mobile audio initialized: #{inspect(caps)}")

    {:noreply, socket
      |> LiveView.assign(:mobile_capabilities, caps)
      |> add_notification("Mobile audio engine ready", :success)}
  end

  def handle_event("mobile_track_volume_change", %{"track_index" => index, "volume" => volume}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      track_id = get_track_id_by_index(socket, index)

      case AudioEngine.update_track_volume(socket.assigns.session.id, track_id, volume) do
        :ok ->
          {:noreply, socket}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to update volume: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("mobile_master_volume_change", %{"volume" => volume}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      case AudioEngine.set_master_volume(socket.assigns.session.id, volume) do
        :ok -> {:noreply, socket}
        {:error, _reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to update master volume")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("mobile_toggle_effect", %{"track_index" => index, "effect_type" => effect_type}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      track_id = get_track_id_by_index(socket, index)
      current_effects = get_track_effects(socket, track_id)

      if Enum.any?(current_effects, &(&1.type == effect_type)) do
        # Remove effect
        effect_id = Enum.find(current_effects, &(&1.type == effect_type)).id
        case AudioEngine.remove_effect(socket.assigns.session.id, track_id, effect_id) do
          :ok -> {:noreply, socket |> add_notification("#{String.capitalize(effect_type)} removed", :info)}
          {:error, _reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to remove effect")}
        end
      else
        # Add effect with mobile-optimized parameters
        mobile_params = get_mobile_effect_params(effect_type)
        case AudioEngine.apply_effect(socket.assigns.session.id, track_id, effect_type, mobile_params) do
          {:ok, _effect} -> {:noreply, socket |> add_notification("#{String.capitalize(effect_type)} applied", :success)}
          {:error, _reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to apply effect")}
        end
      end
    else
      {:noreply, socket}
    end
  end

  # Mobile Recording
  def handle_event("mobile_start_recording", %{"track_index" => index}, socket) do
    if can_record_audio?(socket.assigns.permissions) do
      track_id = get_track_id_by_index(socket, index)
      user_id = socket.assigns.current_user.id

      case AudioEngine.start_recording(socket.assigns.session.id, track_id, user_id) do
        {:ok, _} ->
          {:noreply, socket
            |> LiveView.assign(:recording_track, track_id)
            |> add_notification("Recording started", :success)}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to start recording: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("mobile_stop_recording", %{"track_index" => index}, socket) do
    track_id = get_track_id_by_index(socket, index)
    user_id = socket.assigns.current_user.id

    case AudioEngine.stop_recording(socket.assigns.session.id, track_id, user_id) do
      {:ok, _clip} ->
        {:noreply, socket
          |> LiveView.assign(:recording_track, nil)
          |> add_notification("Recording stopped", :info)}
      {:error, reason} ->
        {:noreply, socket |> LiveView.put_flash(:error, "Failed to stop recording: #{reason}")}
    end
  end

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

  def handle_event("mobile_solo_track", %{"track_index" => index}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      track_id = get_track_id_by_index(socket, index)

      case AudioEngine.solo_track(socket.assigns.session.id, track_id, true) do
        :ok -> {:noreply, socket |> add_notification("Track soloed", :info)}
        {:error, _reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to solo track")}
      end
    else
      {:noreply, socket}
    end
  end

  # Mobile Gestures
  def handle_event("mobile_swipe", %{"direction" => direction}, socket) do
    case direction do
      "up" when not socket.assigns.mobile_tool_drawer_open ->
        # Swipe up to open tool drawer
        {:noreply, LiveView.assign(socket, mobile_tool_drawer_open: true)}

      "down" when socket.assigns.mobile_tool_drawer_open ->
        # Swipe down to close tool drawer
        {:noreply, LiveView.assign(socket, mobile_tool_drawer_open: false)}

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

  # Mobile Tool Actions
  def handle_event("mobile_tool_action", %{"action" => action, "tool_id" => tool_id} = params, socket) do
    case {tool_id, action} do
      {"chat", "send_message"} ->
        # Delegate to collaboration handler
        FrestylWeb.StudioLive.CollaborationEventHandler.handle_chat_message(
          params["message"], socket
        )

      {"recorder", "start_recording"} ->
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

  # Mobile Audio-Text Events
  def handle_event("mobile_audio_text_gesture", %{"gesture" => gesture, "data" => data}, socket) do
    case gesture do
      "swipe_sync" ->
        # Swipe gesture to create sync point
        if data["block_id"] do
          current_position = socket.assigns.workspace_state.audio_text.timeline.current_position
          FrestylWeb.StudioLive.CollaborationEventHandler.handle_event("sync_text_to_audio", %{
            "block_id" => data["block_id"],
            "position" => to_string(current_position)
          }, socket)
        else
          {:noreply, socket}
        end

      "double_tap_record" ->
        # Double tap to toggle recording
        if socket.assigns.recording_track do
          handle_event("mobile_stop_recording", %{"track_index" => 0}, socket)
        else
          handle_event("mobile_audio_text_record", %{"with_script" => true}, socket)
        end

      "long_press_voice" ->
        # Long press for voice commands
        {:noreply, LiveView.assign(socket, :voice_commands_active, true)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("mobile_voice_command", %{"command" => command, "data" => data}, socket) do
    case command do
      "add_verse" ->
        FrestylWeb.StudioLive.CollaborationEventHandler.handle_event("create_text_block", %{
          "content" => data["text"],
          "type" => "verse"
        }, socket)

      "add_chorus" ->
        FrestylWeb.StudioLive.CollaborationEventHandler.handle_event("create_text_block", %{
          "content" => data["text"],
          "type" => "chorus"
        }, socket)

      "sync_now" ->
        if data["block_id"] do
          handle_event("mobile_sync_gesture", %{"block_id" => data["block_id"]}, socket)
        else
          {:noreply, socket |> LiveView.put_flash(:error, "No block selected for sync")}
        end

      "start_recording" ->
        handle_event("mobile_start_recording", %{"track_index" => 0}, socket)

      "stop_recording" ->
        handle_event("mobile_stop_recording", %{"track_index" => 0}, socket)

      _ ->
        {:noreply, socket |> add_notification("Voice command not recognized", :warning)}
    end
  end

  def handle_event("mobile_audio_text_record", %{"with_script" => with_script}, socket) do
    if can_record_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      user_id = socket.assigns.current_user.id

      # Prepare recording with script/lyrics context
      recording_context = %{
        with_script: with_script,
        current_block: socket.assigns.workspace_state.audio_text.current_text_block,
        sync_enabled: socket.assigns.workspace_state.audio_text.sync_enabled
      }

      case AudioEngine.start_recording_with_context(session_id, "mobile_track_1", user_id, recording_context) do
        {:ok, _} ->
          {:noreply, socket
            |> LiveView.assign(:recording_track, "mobile_track_1")
            |> add_notification("Recording with script guidance", :success)
            |> LiveView.push_event("mobile_recording_started", %{with_script: with_script})}

        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to start recording: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  # Unhandled mobile events
  def handle_event(event_name, params, socket) do
    Logger.warn("Unhandled mobile event: #{event_name} with params: #{inspect(params)}")
    {:noreply, socket}
  end

  # Private Helper Functions

  defp get_track_id_by_index(socket, index) do
    tracks = socket.assigns.workspace_state.audio.tracks
    case Enum.at(tracks, index) do
      nil -> nil
      track -> track.id
    end
  end

  defp get_track_index_by_id(socket, track_id) do
    tracks = socket.assigns.workspace_state.audio.tracks
    case Enum.find_index(tracks, &(&1.id == track_id)) do
      nil -> 0
      index -> index
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

  defp cycle_mobile_primary_tool(socket, direction) do
    mode_config = get_collaboration_mode_config(socket.assigns.collaboration_mode)
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
      |> LiveView.assign(mobile_active_tool: new_tool)
      |> LiveView.push_event("mobile_tool_cycled", %{tool_id: new_tool, direction: direction})}
  end

  defp get_collaboration_mode_config(collaboration_mode) do
    # Simplified collaboration mode configs
    case collaboration_mode do
      "audio_production" -> %{primary_tools: ["recorder", "mixer", "effects"]}
      "collaborative_writing" -> %{primary_tools: ["editor", "chat"]}
      "lyrics_creation" -> %{primary_tools: ["editor", "timeline", "recorder"]}
      _ -> %{primary_tools: ["recorder", "mixer", "chat"]}
    end
  end

  defp can_edit_audio?(permissions), do: Map.get(permissions, :can_edit_audio, false)
  defp can_edit_text?(permissions), do: Map.get(permissions, :can_edit_text, false)
  defp can_record_audio?(permissions), do: Map.get(permissions, :can_record_audio, false)
end
