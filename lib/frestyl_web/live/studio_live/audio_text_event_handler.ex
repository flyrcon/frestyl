defmodule FrestylWeb.StudioLive.AudioTextEventHandler do
  @moduledoc """
  Handles audio-text synchronization events for the Studio LiveView.
  """

  import Phoenix.LiveView
  import Phoenix.Component
  require Logger

  alias Phoenix.PubSub

  # Permission helpers
  defp can_edit_text?(permissions), do: Map.get(permissions, :can_edit_text, false)
  defp can_edit_audio?(permissions), do: Map.get(permissions, :can_edit_audio, false)

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

  # Time formatting helper
  defp format_time(milliseconds) when is_number(milliseconds) do
    seconds = div(trunc(milliseconds), 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end
  defp format_time(_), do: "00:00"

  @doc """
  Handles audio-text mode switching
  """
  def handle_event("audio_text_mode_change", %{"mode" => mode}, socket) do
    if mode in ["lyrics_with_audio", "audio_with_script"] do
      session_id = socket.assigns.session.id

      case AudioTextSync.set_mode(session_id, mode) do
        :ok ->
          new_audio_text_state = put_in(socket.assigns.workspace_state.audio_text.mode, mode)
          new_workspace_state = %{socket.assigns.workspace_state | audio_text: new_audio_text_state}

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> add_notification("Switched to #{format_mode_name(mode)}", :info)}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to change mode: #{reason}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "Invalid audio-text mode")}
    end
  end

  @doc """
  Handles text block creation and management
  """
  def handle_event("create_text_block", %{"content" => content, "type" => type}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      block = %{
        content: content,
        type: type,
        created_by: socket.assigns.current_user.id,
        created_at: DateTime.utc_now()
      }

      case AudioTextSync.add_text_block(session_id, block) do
        {:ok, new_block} ->
          {:noreply, socket |> add_notification("Added #{type}", :success)}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to add block: #{reason}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to edit text")}
    end
  end

  def handle_event("audio_text_add_block", %{"type" => type}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      user_id = socket.assigns.current_user.id

      block = %{
        id: "block_#{System.unique_integer([:positive])}",
        content: "",
        type: type,
        created_by: user_id,
        created_at: DateTime.utc_now(),
        sync_point: nil
      }

      case AudioTextSync.add_text_block(session_id, block) do
        {:ok, new_block} ->
          # Update workspace state
          current_blocks = get_in(socket.assigns.workspace_state, [:audio_text, :text_sync, :blocks]) || []
          new_blocks = current_blocks ++ [new_block]

          new_workspace_state = put_in(
            socket.assigns.workspace_state,
            [:audio_text, :text_sync, :blocks],
            new_blocks
          )

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> add_notification("Added #{String.capitalize(type)}", :success)}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to add block: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_text_update_block", %{"block_id" => block_id, "value" => content}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioTextSync.update_text_block(session_id, block_id, content) do
        {:ok, updated_block} ->
          # Update workspace state
          current_blocks = get_in(socket.assigns.workspace_state, [:audio_text, :text_sync, :blocks]) || []
          new_blocks = Enum.map(current_blocks, fn block ->
            if block.id == block_id do
              %{block | content: content}
            else
              block
            end
          end)

          new_workspace_state = put_in(
            socket.assigns.workspace_state,
            [:audio_text, :text_sync, :blocks],
            new_blocks
          )

          {:noreply, assign(socket, workspace_state: new_workspace_state)}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to update block: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_text_select_block", %{"block_id" => block_id}, socket) do
    new_workspace_state = put_in(
      socket.assigns.workspace_state,
      [:audio_text, :current_text_block],
      block_id
    )

    {:noreply, socket
      |> assign(workspace_state: new_workspace_state)
      |> push_event("block_selected", %{block_id: block_id})}
  end

  def handle_event("audio_text_delete_block", %{"block_id" => block_id}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioTextSync.delete_text_block(session_id, block_id) do
        :ok ->
          # Update workspace state
          current_blocks = get_in(socket.assigns.workspace_state, [:audio_text, :text_sync, :blocks]) || []
          new_blocks = Enum.reject(current_blocks, &(&1.id == block_id))

          new_workspace_state = put_in(
            socket.assigns.workspace_state,
            [:audio_text, :text_sync, :blocks],
            new_blocks
          )

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> add_notification("Block deleted", :info)}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to delete block: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @doc """
  Handles text-to-audio synchronization
  """
  def handle_event("sync_text_to_audio", %{"block_id" => block_id, "position" => position}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      position_float = String.to_float(position)

      case AudioTextSync.sync_text_block(session_id, block_id, position_float) do
        {:ok, sync_point} ->
          {:noreply, socket
            |> add_notification("Text synced to #{format_time(position_float)}", :success)
            |> push_event("text_synced", %{block_id: block_id, position: position_float})}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Sync failed: #{reason}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to sync audio")}
    end
  end

  def handle_event("audio_text_sync_block", %{"block_id" => block_id}, socket) do
    current_position = get_in(socket.assigns.workspace_state, [:audio_text, :timeline, :current_position]) || 0

    handle_event("sync_text_to_audio", %{
      "block_id" => block_id,
      "position" => to_string(current_position)
    }, socket)
  end

  def handle_event("audio_text_remove_sync", %{"block_id" => block_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioTextSync.remove_sync_point(session_id, block_id) do
        :ok ->
          {:noreply, socket |> add_notification("Sync point removed", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to remove sync: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @doc """
  Handles beat detection and auto-alignment
  """
  def handle_event("auto_detect_beats", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case get_primary_audio_track(socket.assigns.workspace_state) do
        nil ->
          {:noreply, socket |> put_flash(:error, "No audio track available for beat detection")}

        track ->
          audio_data = get_track_audio_data(track)

          case AudioTextSync.detect_beats(session_id, audio_data) do
            {:ok, beat_data} ->
              # Update workspace state with detected beats
              new_workspace_state = put_in(
                socket.assigns.workspace_state,
                [:audio_text, :beat_detection],
                %{
                  enabled: true,
                  bpm: beat_data.bpm,
                  detected_beats: beat_data.beats,
                  confidence: beat_data.confidence
                }
              )

              {:noreply, socket
                |> assign(workspace_state: new_workspace_state)
                |> add_notification("Detected #{length(beat_data.beats)} beats at #{beat_data.bpm} BPM", :success)
                |> push_event("beats_detected", beat_data)}

            {:error, reason} ->
              {:noreply, socket |> put_flash(:error, "Beat detection failed: #{reason}")}
          end
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_text_detect_beats", _params, socket) do
    handle_event("auto_detect_beats", %{}, socket)
  end

  def handle_event("auto_align_lyrics", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      beat_detection = get_in(socket.assigns.workspace_state, [:audio_text, :beat_detection])

      if beat_detection && beat_detection.enabled do
        text_blocks = get_in(socket.assigns.workspace_state, [:audio_text, :text_sync, :blocks]) || []
        lyrics_text = get_all_text_content(text_blocks)

        case AudioTextSync.auto_align_lyrics(session_id, lyrics_text, beat_detection) do
          {:ok, aligned_blocks} ->
            # Update workspace state with aligned blocks
            new_workspace_state = put_in(
              socket.assigns.workspace_state,
              [:audio_text, :text_sync, :blocks],
              aligned_blocks
            )

            {:noreply, socket
              |> assign(workspace_state: new_workspace_state)
              |> add_notification("Lyrics automatically aligned", :success)
              |> push_event("lyrics_aligned", %{blocks: aligned_blocks})}

          {:error, reason} ->
            {:noreply, socket |> put_flash(:error, "Auto-alignment failed: #{reason}")}
        end
      else
        {:noreply, socket |> put_flash(:error, "Beat detection required for auto-alignment")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_text_auto_align", _params, socket) do
    handle_event("auto_align_lyrics", %{}, socket)
  end

  @doc """
  Handles playback and timeline controls
  """
  def handle_event("audio_text_play", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      current_position = get_in(socket.assigns.workspace_state, [:audio_text, :timeline, :current_position]) || 0

      case AudioTextSync.start_synchronized_playback(session_id, current_position) do
        :ok ->
          new_workspace_state = put_in(
            socket.assigns.workspace_state,
            [:audio_text, :playing],
            true
          )

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> push_event("audio_text_playback_started", %{position: current_position})}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to start playback: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_text_pause", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioTextSync.pause_synchronized_playback(session_id) do
        :ok ->
          new_workspace_state = put_in(
            socket.assigns.workspace_state,
            [:audio_text, :playing],
            false
          )

          {:noreply, assign(socket, workspace_state: new_workspace_state)}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to pause playback: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_text_stop", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioTextSync.stop_synchronized_playback(session_id) do
        :ok ->
          new_workspace_state = socket.assigns.workspace_state
          |> put_in([:audio_text, :playing], false)
          |> put_in([:audio_text, :timeline, :current_position], 0)

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> push_event("audio_text_playback_stopped", %{position: 0})}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to stop playback: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_text_seek", %{"position" => position}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      position_float = String.to_float(position)

      case AudioTextSync.seek_to_position(session_id, position_float) do
        :ok ->
          new_workspace_state = put_in(
            socket.assigns.workspace_state,
            [:audio_text, :timeline, :current_position],
            position_float
          )

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> push_event("timeline_position_changed", %{position: position_float})}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to seek: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @doc """
  Handles recording with script/lyrics synchronization
  """
  def handle_event("audio_text_start_recording", %{"with_script" => with_script}, socket) do
    if can_record_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      user_id = socket.assigns.current_user.id

      recording_context = %{
        with_script: with_script,
        current_block: get_in(socket.assigns.workspace_state, [:audio_text, :current_text_block]),
        sync_enabled: get_in(socket.assigns.workspace_state, [:audio_text, :sync_enabled])
      }

      case AudioEngine.start_recording_with_context(session_id, "audio_text_track", user_id, recording_context) do
        {:ok, _} ->
          {:noreply, socket
            |> assign(:recording_track, "audio_text_track")
            |> add_notification("Recording with script guidance", :success)
            |> push_event("audio_text_recording_started", %{with_script: with_script})}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to start recording: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_text_start_recording", _params, socket) do
    # Default to script recording
    handle_event("audio_text_start_recording", %{"with_script" => true}, socket)
  end

  def handle_event("audio_text_stop_recording", _params, socket) do
    session_id = socket.assigns.session.id
    user_id = socket.assigns.current_user.id

    case AudioEngine.stop_recording(session_id, "audio_text_track", user_id) do
      {:ok, clip} ->
        {:noreply, socket
          |> assign(:recording_track, nil)
          |> add_notification("Recording completed", :success)
          |> push_event("audio_text_recording_stopped", %{clip: clip})}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to stop recording: #{reason}")}
    end
  end

  @doc """
  Handles teleprompter and script features
  """
  def handle_event("audio_text_toggle_teleprompter", _params, socket) do
    current_mode = socket.assigns[:teleprompter_mode] || false
    new_mode = !current_mode

    {:noreply, socket
      |> assign(:teleprompter_mode, new_mode)
      |> push_event("teleprompter_toggled", %{enabled: new_mode})}
  end

  def handle_event("audio_text_set_teleprompter_speed", %{"speed" => speed}, socket) do
    speed_float = String.to_float(speed)

    {:noreply, socket
      |> assign(:teleprompter_speed, speed_float)
      |> push_event("teleprompter_speed_changed", %{speed: speed_float})}
  end

  def handle_event("audio_text_toggle_auto_scroll", _params, socket) do
    current_scroll = get_in(socket.assigns.workspace_state, [:audio_text, :text_sync, :auto_scroll]) || false
    new_scroll = !current_scroll

    new_workspace_state = put_in(
      socket.assigns.workspace_state,
      [:audio_text, :text_sync, :auto_scroll],
      new_scroll
    )

    {:noreply, assign(socket, workspace_state: new_workspace_state)}
  end

  def handle_event("audio_text_toggle_highlight", _params, socket) do
    current_highlight = get_in(socket.assigns.workspace_state, [:audio_text, :text_sync, :highlight_current]) || false
    new_highlight = !current_highlight

    new_workspace_state = put_in(
      socket.assigns.workspace_state,
      [:audio_text, :text_sync, :highlight_current],
      new_highlight
    )

    {:noreply, assign(socket, workspace_state: new_workspace_state)}
  end

  def handle_event("audio_text_toggle_sync", _params, socket) do
    current_sync = get_in(socket.assigns.workspace_state, [:audio_text, :sync_enabled]) || false
    new_sync = !current_sync

    new_workspace_state = put_in(
      socket.assigns.workspace_state,
      [:audio_text, :sync_enabled],
      new_sync
    )

    {:noreply, assign(socket, workspace_state: new_workspace_state)}
  end

  @doc """
  Handles mobile gestures and voice commands
  """
  def handle_event("mobile_audio_text_gesture", %{"gesture" => gesture, "data" => data}, socket) do
    case gesture do
      "swipe_sync" ->
        if data["block_id"] do
          current_position = get_in(socket.assigns.workspace_state, [:audio_text, :timeline, :current_position]) || 0
          handle_event("sync_text_to_audio", %{
            "block_id" => data["block_id"],
            "position" => to_string(current_position)
          }, socket)
        else
          {:noreply, socket}
        end

      "double_tap_record" ->
        if socket.assigns[:recording_track] do
          handle_event("audio_text_stop_recording", %{}, socket)
        else
          handle_event("audio_text_start_recording", %{"with_script" => true}, socket)
        end

      "long_press_voice" ->
        {:noreply, assign(socket, :voice_commands_active, true)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("mobile_voice_command", %{"command" => command, "data" => data}, socket) do
    case command do
      "add_verse" ->
        handle_event("audio_text_add_block", %{"type" => "verse"}, socket)

      "add_chorus" ->
        handle_event("audio_text_add_block", %{"type" => "chorus"}, socket)

      "sync_now" ->
        if data["block_id"] do
          handle_event("audio_text_sync_block", %{"block_id" => data["block_id"]}, socket)
        else
          {:noreply, socket |> put_flash(:error, "No block selected for sync")}
        end

      "start_recording" ->
        handle_event("audio_text_start_recording", %{}, socket)

      "stop_recording" ->
        handle_event("audio_text_stop_recording", %{}, socket)

      "play_audio" ->
        handle_event("audio_text_play", %{}, socket)

      "stop_audio" ->
        handle_event("audio_text_stop", %{}, socket)

      _ ->
        {:noreply, socket |> add_notification("Voice command not recognized", :warning)}
    end
  end

  def handle_event("voice_command_complete", %{"command" => command, "text" => text}, socket) do
    result = handle_event("mobile_voice_command", %{
      "command" => command,
      "data" => %{"text" => text}
    }, socket)

    case result do
      {:noreply, updated_socket} ->
        {:noreply, assign(updated_socket, :voice_commands_active, false)}
    end
  end

  def handle_event("cancel_voice_commands", _params, socket) do
    {:noreply, assign(socket, :voice_commands_active, false)}
  end

  @doc """
  Handles mobile-specific audio-text features
  """
  def handle_event("mobile_sync_gesture", %{"block_id" => block_id}, socket) do
    current_position = get_in(socket.assigns.workspace_state, [:audio_text, :timeline, :current_position]) || 0

    handle_event("sync_text_to_audio", %{
      "block_id" => block_id,
      "position" => to_string(current_position)
    }, socket)
  end

  def handle_event("mobile_audio_text_record", %{"with_script" => with_script}, socket) do
    handle_event("audio_text_start_recording", %{"with_script" => with_script}, socket)
  end

  def handle_event("mobile_simplified_mode_toggle", _params, socket) do
    current_mode = socket.assigns[:mobile_simplified_mode] || false
    new_mode = !current_mode

    {:noreply, socket
      |> assign(:mobile_simplified_mode, new_mode)
      |> push_event("mobile_simplified_mode_toggled", %{enabled: new_mode})}
  end

  def handle_event("mobile_text_size_change", %{"size" => size}, socket) do
    {:noreply, socket
      |> assign(:mobile_text_size, size)
      |> push_event("mobile_text_size_changed", %{size: size})}
  end

  # Helper Functions
  defp format_mode_name(mode) do
    case mode do
      "lyrics_with_audio" -> "Lyrics with Audio"
      "audio_with_script" -> "Audio with Script"
      _ -> String.capitalize(mode)
    end
  end

  defp format_time(milliseconds) when is_number(milliseconds) do
    seconds = div(trunc(milliseconds), 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end
  defp format_time(_), do: "00:00"

  defp get_primary_audio_track(workspace_state) do
    case get_in(workspace_state, [:audio, :tracks]) do
      [first_track | _] -> first_track
      [] -> nil
      _ -> nil
    end
  end

  defp get_track_audio_data(track) do
    # In production, this would load actual audio file data
    <<1, 2, 3, 4, 5, 6, 7, 8>>
  end

  defp get_all_text_content(text_blocks) do
    text_blocks
    |> Enum.map(& &1.content)
    |> Enum.join(" ")
  end

  defp can_edit_text?(permissions), do: Map.get(permissions, :can_edit_text, false)
  defp can_edit_audio?(permissions), do: Map.get(permissions, :can_edit_audio, false)
  defp can_record_audio?(permissions), do: Map.get(permissions, :can_record_audio, false)

end
