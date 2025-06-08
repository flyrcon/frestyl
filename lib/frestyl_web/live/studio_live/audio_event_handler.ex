defmodule FrestylWeb.StudioLive.AudioEventHandler do
  @moduledoc """
  Handles audio-related events for the Studio LiveView.
  """

  import Phoenix.LiveView
  import Phoenix.Component
  require Logger

  alias Phoenix.PubSub

  # Permission helpers
  defp can_edit_audio?(permissions), do: Map.get(permissions, :can_edit_audio, false)
  defp can_record_audio?(permissions), do: Map.get(permissions, :can_record_audio, false)

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

  # Audio Track Management Events
  def handle_event("audio_add_track", params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id
      track_name = Map.get(params, "name", "New Track")

      case AudioEngine.add_track(session_id, user_id, %{name: track_name}) do
        {:ok, track} ->
          {:noreply, socket |> add_notification("Added #{track.name}", :success)}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to add track: #{reason}")}
      end
    else
      {:noreply, socket |> LiveView.put_flash(:error, "You don't have permission to add tracks")}
    end
  end

  def handle_event("audio_delete_track", %{"track_id" => track_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.delete_track(session_id, track_id) do
        :ok ->
          {:noreply, socket |> add_notification("Track deleted", :info)}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to delete track: #{reason}")}
      end
    else
      {:noreply, socket |> LiveView.put_flash(:error, "You don't have permission to delete tracks")}
    end
  end

  def handle_event("audio_update_track_volume", %{"track_id" => track_id, "volume" => volume}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.update_track_volume(session_id, track_id, String.to_float(volume)) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to update volume: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_mute_track", %{"track_id" => track_id, "muted" => muted}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.mute_track(session_id, track_id, muted) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to mute track: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_solo_track", %{"track_id" => track_id, "solo" => solo}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.solo_track(session_id, track_id, solo) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to solo track: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_toggle_track_mute", %{"track_id" => track_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      toggle_track_property(socket, track_id, :muted, "mute")
    else
      {:noreply, socket |> LiveView.put_flash(:error, "You don't have permission to modify tracks")}
    end
  end

  def handle_event("audio_toggle_track_solo", %{"track_id" => track_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      toggle_track_property(socket, track_id, :solo, "solo")
    else
      {:noreply, socket |> LiveView.put_flash(:error, "You don't have permission to modify tracks")}
    end
  end

  # Recording Events
  def handle_event("audio_start_recording", %{"track_id" => track_id}, socket) do
    if can_record_audio?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id

      case AudioEngine.start_recording(session_id, track_id, user_id) do
        {:ok, _} ->
          update_recording_presence(socket, track_id, true)
          {:noreply, socket |> LiveView.assign(:recording_track, track_id)}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to start recording: #{reason}")}
      end
    else
      {:noreply, socket |> LiveView.put_flash(:error, "You don't have permission to record")}
    end
  end

  def handle_event("audio_stop_recording", _params, socket) do
    user_id = socket.assigns.current_user.id
    session_id = socket.assigns.session.id

    case AudioEngine.stop_recording(session_id, user_id) do
      {:ok, _clip} ->
        update_recording_presence(socket, nil, false)
        {:noreply, socket |> LiveView.assign(:recording_track, nil)}
      {:error, reason} ->
        {:noreply, socket |> LiveView.put_flash(:error, "Failed to stop recording: #{reason}")}
    end
  end

  def handle_event("toggle_recording_mode", _params, socket) do
    new_recording_mode = !Map.get(socket.assigns, :recording_mode, false)

    if new_recording_mode do
      case start_recording_engine(socket.assigns.session.id) do
        :ok ->
          {:noreply, LiveView.assign(socket, recording_mode: true)}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to start recording: #{reason}")}
      end
    else
      {:noreply, LiveView.assign(socket, recording_mode: false)}
    end
  end

  # Transport Controls
  def handle_event("audio_start_playback", %{"position" => position}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      position = String.to_float(position || "0")

      case AudioEngine.start_playback(session_id, position) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to start playback: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_stop_playback", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.stop_playback(session_id) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to stop playback: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  # Effects Management
  def handle_event("audio_apply_effect", %{"track_id" => track_id, "effect_type" => effect_type, "params" => params}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.apply_effect(session_id, track_id, effect_type, params) do
        {:ok, _effect} ->
          {:noreply, socket |> add_notification("#{String.capitalize(effect_type)} applied", :success)}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to apply effect: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_remove_effect", %{"track_id" => track_id, "effect_id" => effect_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case AudioEngine.remove_effect(session_id, track_id, effect_id) do
        :ok ->
          {:noreply, socket |> add_notification("Effect removed", :info)}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to remove effect: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("audio_effect_parameter_update", %{
    "track_id" => track_id,
    "effect_id" => effect_id,
    "parameter" => parameter,
    "value" => value
  }, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      typed_value = String.to_float(value)

      case AudioEngine.update_effect_parameter(session_id, track_id, effect_id, parameter, typed_value) do
        :ok ->
          {:noreply, socket |> LiveView.push_event("effect_parameter_updated", %{
            track_id: track_id,
            effect_id: effect_id,
            parameter: parameter,
            value: typed_value
          })}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to update effect: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  # Beat Machine Events
  def handle_beat_event("beat_create_pattern", %{"name" => name, "steps" => steps}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      steps = String.to_integer(steps || "16")

      case BeatMachine.create_pattern(session_id, name, steps) do
        {:ok, pattern} ->
          {:noreply, socket |> add_notification("Created pattern: #{pattern.name}", :success)}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to create pattern: #{reason}")}
      end
    else
      {:noreply, socket |> LiveView.put_flash(:error, "You don't have permission to create patterns")}
    end
  end

  def handle_beat_event("beat_update_step", %{"pattern_id" => pattern_id, "instrument" => instrument, "step" => step, "velocity" => velocity}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      step = String.to_integer(step)
      velocity = String.to_integer(velocity)

      case BeatMachine.update_pattern_step(session_id, pattern_id, instrument, step, velocity) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to update step: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_beat_event("beat_play_pattern", %{"pattern_id" => pattern_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.play_pattern(session_id, pattern_id) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to play pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_beat_event("beat_stop_pattern", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.stop_pattern(session_id) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to stop pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_beat_event("beat_change_kit", %{"kit_name" => kit_name}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.change_kit(session_id, kit_name) do
        :ok ->
          {:noreply, socket |> add_notification("Changed to #{kit_name} kit", :info)}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to change kit: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_beat_event("beat_set_bpm", %{"bpm" => bpm}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      bpm = String.to_integer(bpm)

      case BeatMachine.set_bpm(session_id, bpm) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> LiveView.put_flash(:error, "Failed to set BPM: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  # Audio Engine Message Handlers
  def handle_info({:track_added, track, user_id}, socket) do
    username = get_username_from_collaborators(user_id, socket.assigns.collaborators)
    message = "#{username} added track: #{track.name}"

    {:noreply, socket |> add_notification(message, :info)}
  end

  def handle_info({:track_volume_changed, track_id, volume}, socket) do
    {:noreply, socket |> LiveView.push_event("track_volume_updated", %{track_id: track_id, volume: volume})}
  end

  def handle_info({:track_muted, track_id, muted}, socket) do
    {:noreply, socket |> LiveView.push_event("track_mute_updated", %{track_id: track_id, muted: muted})}
  end

  def handle_info({:track_solo_changed, track_id, solo}, socket) do
    {:noreply, socket |> LiveView.push_event("track_solo_updated", %{track_id: track_id, solo: solo})}
  end

  def handle_info({:playback_started, position}, socket) do
    {:noreply, socket |> LiveView.push_event("audio_playback_started", %{position: position})}
  end

  def handle_info({:playback_stopped, position}, socket) do
    {:noreply, socket |> LiveView.push_event("audio_playback_stopped", %{position: position})}
  end

  def handle_info({:playback_position, position}, socket) do
    {:noreply, socket |> LiveView.push_event("audio_playback_position", %{position: position})}
  end

  def handle_info({:clip_added, clip}, socket) do
    username = get_username_from_collaborators(clip.user_id, socket.assigns.collaborators)
    message = "#{username} recorded audio clip"

    {:noreply, socket |> add_notification(message, :success)}
  end

  # Beat Machine Message Handlers
  def handle_info({:beat_machine, {:pattern_created, pattern}}, socket) do
    username = get_username_from_collaborators(pattern.created_by, socket.assigns.collaborators)
    message = "#{username} created pattern: #{pattern.name}"

    {:noreply, socket
      |> add_notification(message, :success)
      |> LiveView.push_event("beat_pattern_created", %{pattern: pattern})}
  end

  def handle_info({:beat_machine, {:step_updated, pattern_id, instrument, step, velocity}}, socket) do
    {:noreply, socket |> LiveView.push_event("beat_step_updated", %{
      pattern_id: pattern_id,
      instrument: instrument,
      step: step,
      velocity: velocity
    })}
  end

  def handle_info({:beat_machine, {:pattern_started, pattern_id}}, socket) do
    {:noreply, socket |> LiveView.push_event("beat_pattern_started", %{pattern_id: pattern_id})}
  end

  def handle_info({:beat_machine, {:pattern_stopped}}, socket) do
    {:noreply, socket |> LiveView.push_event("beat_pattern_stopped", %{})}
  end

  def handle_info({:beat_machine, {:step_triggered, step, instruments}}, socket) do
    {:noreply, socket |> LiveView.push_event("beat_step_triggered", %{
      step: step,
      instruments: instruments
    })}
  end

  def handle_info({:beat_machine, {:kit_changed, kit_name, kit}}, socket) do
    username = get_username_from_collaborators("system", socket.assigns.collaborators)
    message = "Drum kit changed to #{kit_name}"

    {:noreply, socket
      |> add_notification(message, :info)
      |> LiveView.push_event("beat_kit_changed", %{kit_name: kit_name, kit: kit})}
  end

  # Input Level Monitoring
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

  # Private Helper Functions

  defp toggle_track_property(socket, track_id, property, property_name) do
    user_id = socket.assigns.current_user.id
    session_id = socket.assigns.session.id
    workspace_state = socket.assigns.workspace_state

    # Find the track and toggle the property
    track = Enum.find(workspace_state.audio.tracks, &(&1.id == track_id))

    if track do
      current_value = Map.get(track, property, false)
      new_value = !current_value

      case AudioEngine.update_track_property(session_id, track_id, property, new_value) do
        :ok ->
          action_text = if new_value, do: "#{String.capitalize(property_name)}d", else: "Un#{property_name}d"
          {:noreply, socket |> add_notification("#{action_text} #{track.name}", :info)}
        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to update track: #{reason}")}
      end
    else
      {:noreply, socket |> LiveView.put_flash(:error, "Track not found")}
    end
  end

  defp update_recording_presence(socket, track_id, is_recording) do
    user_id = socket.assigns.current_user.id
    session_id = socket.assigns.session.id

    update_presence(session_id, user_id, %{
      is_recording: is_recording,
      active_audio_track: track_id,
      last_activity: DateTime.utc_now()
    })
  end

  defp update_presence(session_id, user_id, updates) do
    case Frestyl.Presence.get_by_key("studio:#{session_id}", to_string(user_id)) do
      %{metas: [meta | _]} ->
        new_meta = Map.merge(meta, updates)
        Frestyl.Presence.update(self(), "studio:#{session_id}", to_string(user_id), new_meta)
      _ -> nil
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

  defp get_username_from_collaborators(user_id, collaborators) do
    case Enum.find(collaborators, fn c -> c.user_id == user_id end) do
      %{username: username} -> username
      _ -> "Someone"
    end
  end
end
