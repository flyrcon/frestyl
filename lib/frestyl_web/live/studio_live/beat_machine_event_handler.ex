defmodule FrestylWeb.StudioLive.BeatMachineEventHandler do
  @moduledoc """
  Handles beat machine events for the Studio LiveView.
  """

  import Phoenix.LiveView
  import Phoenix.Component
  require Logger

  alias Phoenix.PubSub

  # Permission helpers
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

  @doc """
  Handles pattern creation events
  """
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

  @doc """
  Handles step sequencer updates with enhanced OT support
  """
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

  @doc """
  Handles pattern playback controls
  """
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

  def handle_event("beat_pause_pattern", _params, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.pause_pattern(session_id) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to pause pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @doc """
  Handles kit and global settings
  """
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

  @doc """
  Handles pattern manipulation operations
  """
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

  def handle_event("beat_copy_pattern", %{"source_pattern_id" => source_id, "target_pattern_id" => target_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.copy_pattern(session_id, source_id, target_id) do
        :ok ->
          {:noreply, socket |> add_notification("Pattern copied", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to copy pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @doc """
  Handles advanced pattern editing
  """
  def handle_event("beat_shift_pattern", %{"pattern_id" => pattern_id, "direction" => direction, "steps" => steps}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      steps = String.to_integer(steps)

      case BeatMachine.shift_pattern(session_id, pattern_id, direction, steps) do
        :ok ->
          {:noreply, socket |> add_notification("Pattern shifted #{direction}", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to shift pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("beat_reverse_pattern", %{"pattern_id" => pattern_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.reverse_pattern(session_id, pattern_id) do
        :ok ->
          {:noreply, socket |> add_notification("Pattern reversed", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to reverse pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("beat_quantize_pattern", %{"pattern_id" => pattern_id, "grid_size" => grid_size}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      grid_size = String.to_integer(grid_size)

      case BeatMachine.quantize_pattern(session_id, pattern_id, grid_size) do
        :ok ->
          {:noreply, socket |> add_notification("Pattern quantized to 1/#{grid_size}", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to quantize pattern: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @doc """
  Handles instrument-specific controls
  """
  def handle_event("beat_mute_instrument", %{"pattern_id" => pattern_id, "instrument" => instrument, "muted" => muted}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.mute_instrument(session_id, pattern_id, instrument, muted) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to mute instrument: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("beat_solo_instrument", %{"pattern_id" => pattern_id, "instrument" => instrument, "solo" => solo}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.solo_instrument(session_id, pattern_id, instrument, solo) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to solo instrument: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("beat_set_instrument_volume", %{"pattern_id" => pattern_id, "instrument" => instrument, "volume" => volume}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      volume = String.to_float(volume)

      case BeatMachine.set_instrument_volume(session_id, pattern_id, instrument, volume) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to set instrument volume: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @doc """
  Handles pattern chaining and arrangement
  """
  def handle_event("beat_chain_patterns", %{"pattern_ids" => pattern_ids, "chain_name" => chain_name}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.create_pattern_chain(session_id, pattern_ids, chain_name) do
        {:ok, chain} ->
          {:noreply, socket |> add_notification("Created pattern chain: #{chain.name}", :success)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to create pattern chain: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("beat_play_chain", %{"chain_id" => chain_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.play_pattern_chain(session_id, chain_id) do
        :ok -> {:noreply, socket}
        {:error, reason} -> {:noreply, socket |> put_flash(:error, "Failed to play pattern chain: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  @doc """
  Handles real-time step recording
  """
  def handle_event("beat_start_step_recording", %{"pattern_id" => pattern_id, "instrument" => instrument}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.start_step_recording(session_id, pattern_id, instrument) do
        :ok ->
          {:noreply, socket |> add_notification("Step recording started for #{instrument}", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to start step recording: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("beat_stop_step_recording", %{"pattern_id" => pattern_id}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      case BeatMachine.stop_step_recording(session_id, pattern_id) do
        :ok ->
          {:noreply, socket |> add_notification("Step recording stopped", :info)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to stop step recording: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  # Helper Functions

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

end
