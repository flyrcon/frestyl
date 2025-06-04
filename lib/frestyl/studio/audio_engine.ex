# lib/frestyl/studio/audio_engine.ex
defmodule Frestyl.Studio.AudioEngine do
  @moduledoc """
  Enhanced multi-track audio engine that integrates with existing
  WebRTC infrastructure for real-time collaborative audio production.
  """

  use GenServer
  require Logger
  alias Frestyl.Sessions
  alias Frestyl.Media
  alias Phoenix.PubSub

  defstruct [
    :session_id,
    :tracks,
    :recording_state,
    :playback_state,
    :connected_users,
    :master_volume,
    :master_effects,
    :metronome,
    :transport,
    :started_at
  ]

  # Public API

  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via_tuple(session_id))
  end

  def get_engine_state(session_id) do
    try do
      GenServer.call(via_tuple(session_id), :get_state, 5000)
    catch
      :exit, {:noproc, _} -> {:error, :not_found}
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  def add_track(session_id, user_id, track_params) do
    GenServer.call(via_tuple(session_id), {:add_track, user_id, track_params})
  end

  def delete_track(session_id, track_id) do
    GenServer.call(via_tuple(session_id), {:delete_track, track_id})
  end

  def record_to_track(session_id, track_id, user_id, audio_data) do
    GenServer.cast(via_tuple(session_id), {:record_to_track, track_id, user_id, audio_data})
  end

  def start_playback(session_id, position \\ 0) do
    GenServer.call(via_tuple(session_id), {:start_playback, position})
  end

  def stop_playback(session_id) do
    GenServer.call(via_tuple(session_id), :stop_playback)
  end

  def update_track_volume(session_id, track_id, volume) do
    GenServer.call(via_tuple(session_id), {:update_track_volume, track_id, volume})
  end

  def mute_track(session_id, track_id, muted) do
    GenServer.call(via_tuple(session_id), {:mute_track, track_id, muted})
  end

  def solo_track(session_id, track_id, solo) do
    GenServer.call(via_tuple(session_id), {:solo_track, track_id, solo})
  end

  def apply_effect(session_id, track_id, effect_type, params) do
    GenServer.call(via_tuple(session_id), {:apply_effect, track_id, effect_type, params})
  end

  def remove_effect(session_id, track_id, effect_id) do
    GenServer.call(via_tuple(session_id), {:remove_effect, track_id, effect_id})
  end

  def set_master_volume(session_id, volume) do
    GenServer.call(via_tuple(session_id), {:set_master_volume, volume})
  end

  def toggle_metronome(session_id, enabled, bpm \\ 120) do
    GenServer.call(via_tuple(session_id), {:toggle_metronome, enabled, bpm})
  end

  # GenServer Callbacks

  @impl true
  def init(session_id) do
    state = %__MODULE__{
      session_id: session_id,
      tracks: %{},
      recording_state: %{active: false, tracks: []},
      playback_state: %{playing: false, position: 0, start_time: nil},
      connected_users: MapSet.new(),
      master_volume: 0.8,
      master_effects: [],
      metronome: %{enabled: false, bpm: 120, sound: "click"},
      transport: %{playing: false, recording: false, position: 0},
      started_at: DateTime.utc_now()
    }

    # Subscribe to session events
    PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}")
    PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")

    # Load existing workspace state if any
    state = load_existing_workspace_state(state)

    Logger.info("AudioEngine started for session #{session_id}")
    {:ok, state}
  end

  @impl true
  def handle_call(:prepare_shutdown, _from, state) do
    Logger.info("Preparing AudioEngine shutdown for session #{state.session_id}")

    # Save current state before shutdown
    update_workspace_audio_state(state)

    # Stop any active recordings
    if state.recording_state.active do
      # Finalize any in-progress recordings
      broadcast_audio_event(state.session_id, {:recording_stopped, :shutdown})
    end

    # Stop playback
    if state.playback_state.playing do
      broadcast_audio_event(state.session_id, {:playback_stopped, state.playback_state.position})
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:health_check, _from, state) do
    health_status = %{
      session_id: state.session_id,
      tracks: map_size(state.tracks),
      playing: state.playback_state.playing,
      recording: state.recording_state.active,
      connected_users: MapSet.size(state.connected_users),
      uptime: DateTime.diff(DateTime.utc_now(), state.started_at || DateTime.utc_now(), :second)
    }

    {:reply, {:ok, health_status}, state}
  end

  @impl true
  def handle_call({:add_track, user_id, track_params}, _from, state) do
    track_id = generate_track_id()

    track = %{
      id: track_id,
      name: track_params[:name] || "Track #{map_size(state.tracks) + 1}",
      user_id: user_id,
      clips: [],
      volume: 0.8,
      pan: 0.0,
      muted: false,
      solo: false,
      effects: [],
      input_source: track_params[:input_source] || :microphone,
      monitoring: false,
      arm_record: false,
      created_at: DateTime.utc_now(),
      color: track_params[:color] || generate_track_color()
    }

    new_tracks = Map.put(state.tracks, track_id, track)
    new_state = %{state | tracks: new_tracks}

    # Broadcast track added
    broadcast_audio_event(state.session_id, {:track_added, track, user_id})

    # Update workspace state
    update_workspace_audio_state(new_state)

    {:reply, {:ok, track}, new_state}
  end

  @impl true
  def handle_call({:delete_track, track_id}, _from, state) do
    case Map.get(state.tracks, track_id) do
      nil -> {:reply, {:error, :track_not_found}, state}
      track ->
        # Remove track
        new_tracks = Map.delete(state.tracks, track_id)
        new_state = %{state | tracks: new_tracks}

        # Delete associated audio files
        delete_track_files(track)

        # Broadcast track deleted
        broadcast_audio_event(state.session_id, {:track_deleted, track_id})

        # Update workspace state
        update_workspace_audio_state(new_state)

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:start_playback, position}, _from, state) do
    new_playback_state = %{
      playing: true,
      position: position,
      start_time: System.monotonic_time(:millisecond)
    }

    new_transport = %{state.transport | playing: true, position: position}
    new_state = %{state | playback_state: new_playback_state, transport: new_transport}

    # Start playback timer
    schedule_playback_update()

    # Broadcast playback started
    broadcast_audio_event(state.session_id, {:playback_started, position})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:stop_playback, _from, state) do
    new_playback_state = %{state.playback_state | playing: false}
    new_transport = %{state.transport | playing: false}
    new_state = %{state | playback_state: new_playback_state, transport: new_transport}

    # Broadcast playback stopped
    broadcast_audio_event(state.session_id, {:playback_stopped, new_playback_state.position})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:update_track_volume, track_id, volume}, _from, state) do
    case Map.get(state.tracks, track_id) do
      nil -> {:reply, {:error, :track_not_found}, state}
      track ->
        # Validate volume range
        volume = max(0.0, min(1.0, volume))

        updated_track = %{track | volume: volume}
        new_tracks = Map.put(state.tracks, track_id, updated_track)
        new_state = %{state | tracks: new_tracks}

        # Broadcast volume change
        broadcast_audio_event(state.session_id, {:track_volume_changed, track_id, volume})
        update_workspace_audio_state(new_state)

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:mute_track, track_id, muted}, _from, state) do
    case Map.get(state.tracks, track_id) do
      nil -> {:reply, {:error, :track_not_found}, state}
      track ->
        updated_track = %{track | muted: muted}
        new_tracks = Map.put(state.tracks, track_id, updated_track)
        new_state = %{state | tracks: new_tracks}

        # Broadcast mute change
        broadcast_audio_event(state.session_id, {:track_muted, track_id, muted})
        update_workspace_audio_state(new_state)

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:solo_track, track_id, solo}, _from, state) do
    # Handle solo logic - if enabling solo, disable others
    new_tracks = if solo do
      state.tracks
      |> Enum.map(fn {id, track} ->
        if id == track_id do
          {id, %{track | solo: true}}
        else
          {id, %{track | solo: false}}
        end
      end)
      |> Map.new()
    else
      case Map.get(state.tracks, track_id) do
        nil -> state.tracks
        track ->
          Map.put(state.tracks, track_id, %{track | solo: false})
      end
    end

    new_state = %{state | tracks: new_tracks}

    # Broadcast solo change
    broadcast_audio_event(state.session_id, {:track_solo_changed, track_id, solo})
    update_workspace_audio_state(new_state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:apply_effect, track_id, effect_type, params}, _from, state) do
    case Map.get(state.tracks, track_id) do
      nil -> {:reply, {:error, :track_not_found}, state}
      track ->
        effect = %{
          id: generate_effect_id(),
          type: effect_type,
          params: params,
          enabled: true,
          added_at: DateTime.utc_now()
        }

        updated_effects = [effect | track.effects]
        updated_track = %{track | effects: updated_effects}
        new_tracks = Map.put(state.tracks, track_id, updated_track)
        new_state = %{state | tracks: new_tracks}

        # Broadcast effect added
        broadcast_audio_event(state.session_id, {:effect_added, track_id, effect})
        update_workspace_audio_state(new_state)

        {:reply, {:ok, effect}, new_state}
    end
  end

  @impl true
  def handle_call({:remove_effect, track_id, effect_id}, _from, state) do
    case Map.get(state.tracks, track_id) do
      nil -> {:reply, {:error, :track_not_found}, state}
      track ->
        updated_effects = Enum.reject(track.effects, &(&1.id == effect_id))
        updated_track = %{track | effects: updated_effects}
        new_tracks = Map.put(state.tracks, track_id, updated_track)
        new_state = %{state | tracks: new_tracks}

        # Broadcast effect removed
        broadcast_audio_event(state.session_id, {:effect_removed, track_id, effect_id})
        update_workspace_audio_state(new_state)

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:set_master_volume, volume}, _from, state) do
    volume = max(0.0, min(1.0, volume))
    new_state = %{state | master_volume: volume}

    # Broadcast master volume change
    broadcast_audio_event(state.session_id, {:master_volume_changed, volume})
    update_workspace_audio_state(new_state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:toggle_metronome, enabled, bpm}, _from, state) do
    new_metronome = %{state.metronome | enabled: enabled, bpm: bpm}
    new_state = %{state | metronome: new_metronome}

    # Broadcast metronome change
    broadcast_audio_event(state.session_id, {:metronome_changed, new_metronome})
    update_workspace_audio_state(new_state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    public_state = %{
      session_id: state.session_id,
      tracks: state.tracks,
      playback_state: state.playback_state,
      recording_state: state.recording_state,
      transport: state.transport,
      master_volume: state.master_volume,
      metronome: state.metronome,
      connected_users: MapSet.to_list(state.connected_users)
    }

    {:reply, {:ok, public_state}, state}
  end

  @impl true
  def handle_cast({:record_to_track, track_id, user_id, audio_data}, state) do
    case Map.get(state.tracks, track_id) do
      nil ->
        Logger.warn("Attempted to record to non-existent track: #{track_id}")
        {:noreply, state}
      track ->
        # Create audio clip
        clip = %{
          id: generate_clip_id(),
          track_id: track_id,
          user_id: user_id,
          start_time: state.transport.position,
          duration: calculate_clip_duration(audio_data),
          created_at: DateTime.utc_now(),
          file_path: nil # Will be set after saving
        }

        # Add clip to track
        updated_clips = [clip | track.clips]
        updated_track = %{track | clips: updated_clips}
        new_tracks = Map.put(state.tracks, track_id, updated_track)
        new_state = %{state | tracks: new_tracks}

        # Broadcast clip added
        broadcast_audio_event(state.session_id, {:clip_added, clip})
        update_workspace_audio_state(new_state)

        # Save audio data to storage (async)
        Task.start(fn -> save_audio_clip(clip, audio_data) end)

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:playback_update, state) do
    if state.playback_state.playing do
      current_time = System.monotonic_time(:millisecond)
      elapsed = current_time - state.playback_state.start_time
      new_position = state.playback_state.position + elapsed

      new_playback_state = %{state.playback_state | position: new_position}
      new_transport = %{state.transport | position: new_position}
      new_state = %{state | playback_state: new_playback_state, transport: new_transport}

      # Broadcast position update (throttled to avoid spam)
      if rem(trunc(new_position), 100) == 0 do
        broadcast_audio_event(state.session_id, {:playback_position, new_position})
      end

      # Schedule next update
      schedule_playback_update()

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:user_joined, user_id}, state) do
    new_users = MapSet.put(state.connected_users, user_id)
    new_state = %{state | connected_users: new_users}

    # Send current state to new user
    broadcast_to_user(user_id, {:audio_engine_state, get_public_state(new_state)})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:user_left, user_id}, state) do
    new_users = MapSet.delete(state.connected_users, user_id)
    new_state = %{state | connected_users: new_users}

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp via_tuple(session_id) do
    {:via, Registry, {Frestyl.Studio.AudioEngineRegistry, session_id}}
  end

  defp generate_track_id do
    "track_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp generate_clip_id do
    "clip_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp generate_effect_id do
    "fx_" <> (:crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower))
  end

  defp generate_track_color do
    colors = ["#8B5CF6", "#06B6D4", "#10B981", "#F59E0B", "#EF4444", "#EC4899", "#6366F1"]
    Enum.random(colors)
  end

  defp calculate_clip_duration(audio_data) when is_binary(audio_data) do
    # Simplified duration calculation - would use actual audio analysis in production
    byte_size(audio_data) / 1000
  end

  defp calculate_clip_duration(_), do: 0.0

  defp schedule_playback_update do
    Process.send_after(self(), :playback_update, 50) # 20 FPS updates
  end

  defp broadcast_audio_event(session_id, event) do
    PubSub.broadcast(Frestyl.PubSub, "session:#{session_id}", event)
    PubSub.broadcast(Frestyl.PubSub, "audio_engine:#{session_id}", event)
  end

  defp broadcast_to_user(user_id, message) do
    PubSub.broadcast(Frestyl.PubSub, "user:#{user_id}", message)
  end

  defp update_workspace_audio_state(state) do
    # Update the workspace state with current audio state
    audio_state = %{
      tracks: Map.values(state.tracks),
      transport: state.transport,
      master_volume: state.master_volume,
      metronome: state.metronome,
      version: System.unique_integer([:positive])
    }

    # This integrates with your existing workspace state system
    Task.start(fn ->
      case Sessions.get_workspace_state(state.session_id) do
        nil ->
          Sessions.save_workspace_state(state.session_id, %{audio: audio_state})
        current_workspace ->
          updated_workspace = Map.put(current_workspace, :audio, audio_state)
          Sessions.save_workspace_state(state.session_id, updated_workspace)
      end
    end)
  end

  defp load_existing_workspace_state(state) do
    case Sessions.get_workspace_state(state.session_id) do
      nil -> state
      workspace_state ->
        case Map.get(workspace_state, :audio) do
          nil -> state
          audio_state ->
            # Reconstruct tracks from saved state
            tracks = case Map.get(audio_state, :tracks) do
              tracks when is_list(tracks) ->
                tracks
                |> Enum.map(fn track -> {track.id, track} end)
                |> Map.new()
              _ -> %{}
            end

            # Reconstruct transport state
            transport = Map.get(audio_state, :transport, state.transport)

            # Reconstruct other audio settings
            master_volume = Map.get(audio_state, :master_volume, state.master_volume)
            metronome = Map.get(audio_state, :metronome, state.metronome)

            %{state |
              tracks: tracks,
              transport: transport,
              master_volume: master_volume,
              metronome: metronome
            }
        end
    end
  end

  defp save_audio_clip(clip, audio_data) do
    try do
      file_path = generate_clip_file_path(clip)

      # Ensure directory exists
      file_path |> Path.dirname() |> File.mkdir_p!()

      # Write audio data
      File.write!(file_path, audio_data)

      # Create media file record
      Media.create_file(%{
        filename: "#{clip.id}.wav",
        original_filename: "#{clip.id}.wav",
        file_path: file_path,
        file_size: byte_size(audio_data),
        file_type: "audio",
        user_id: clip.user_id,
        metadata: %{
          clip_id: clip.id,
          track_id: clip.track_id,
          start_time: clip.start_time,
          duration: clip.duration,
          audio_engine: true
        }
      })

      Logger.info("Saved audio clip: #{clip.id}")
    rescue
      e ->
        Logger.error("Failed to save audio clip #{clip.id}: #{inspect(e)}")
    end
  end

  defp delete_track_files(track) do
    # Delete audio clips associated with this track
    Task.start(fn ->
      Enum.each(track.clips, fn clip ->
        try do
          file_path = generate_clip_file_path(clip)
          if File.exists?(file_path) do
            File.rm!(file_path)
          end
        rescue
          e -> Logger.warn("Failed to delete clip file: #{inspect(e)}")
        end
      end)
    end)
  end

  defp generate_clip_file_path(clip) do
    date_path = Date.utc_today() |> Date.to_string() |> String.replace("-", "/")
    "uploads/audio/clips/#{date_path}/#{clip.id}.wav"
  end

  defp get_public_state(state) do
    %{
      session_id: state.session_id,
      tracks: state.tracks,
      playback_state: state.playback_state,
      transport: state.transport,
      master_volume: state.master_volume,
      metronome: state.metronome
    }
  end

end
