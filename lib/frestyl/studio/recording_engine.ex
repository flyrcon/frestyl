#frestyl/studio/recording_engine.ex
defmodule Frestyl.Studio.RecordingEngine do
  @moduledoc """
  Enhanced recording engine that integrates with the existing Media system
  for intelligent file storage, metadata extraction, and multi-track collaboration.
  """

  use GenServer
  require Logger
  alias Frestyl.Media
  alias Frestyl.Media.{MediaFile, MusicMetadata, Optimizer}
  alias Frestyl.Sessions
  alias Frestyl.Studio.{AudioEngine, ContentStrategy, CreationProof}
  alias Frestyl.Studio.AudioEngineConfig
  alias Phoenix.PubSub

  defstruct [
    :session_id,
    :recording_tracks,
    :active_recordings,
    :draft_state,
    :tier_config,
    :collaboration_state,
    :audio_chunks,
    :mix_settings,
    :protection_settings
  ]

  # Public API

  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via_tuple(session_id))
  end

  def start_recording(session_id, track_id, user_id, opts \\ []) do
    GenServer.call(via_tuple(session_id), {:start_recording, track_id, user_id, opts})
  end

  def stop_recording(session_id, track_id, user_id) do
    GenServer.call(via_tuple(session_id), {:stop_recording, track_id, user_id})
  end

  def add_audio_chunk(session_id, track_id, user_id, audio_data, timestamp) do
    GenServer.cast(via_tuple(session_id), {:add_audio_chunk, track_id, user_id, audio_data, timestamp})
  end

  def create_draft(session_id, draft_params) do
    GenServer.call(via_tuple(session_id), {:create_draft, draft_params})
  end

  def export_to_media(session_id, export_params, user) do
    GenServer.call(via_tuple(session_id), {:export_to_media, export_params, user})
  end

  def get_recording_state(session_id) do
    GenServer.call(via_tuple(session_id), :get_recording_state)
  end

  def update_mix_settings(session_id, user_id, mix_settings) do
    GenServer.call(via_tuple(session_id), {:update_mix_settings, user_id, mix_settings})
  end

  # GenServer Callbacks

  @impl true
  def init(session_id) do
    # Get tier configuration
    tier = AudioEngineConfig.get_session_tier(session_id)
    tier_config = AudioEngineConfig.get_config(tier)

    state = %__MODULE__{
      session_id: session_id,
      recording_tracks: %{},
      active_recordings: %{},
      draft_state: %{},
      tier_config: tier_config,
      collaboration_state: %{mix_mode: :individual, leader: nil},
      audio_chunks: %{},
      mix_settings: %{},
      protection_settings: ContentStrategy.get_protection_settings(tier)
    }

    # Subscribe to audio engine events
    PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")
    PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}")

    Logger.info("RecordingEngine started for session #{session_id}")
    {:ok, state}
  end

  @impl true
  def handle_call({:start_recording, track_id, user_id, opts}, _from, state) do
    # Check tier limits
    current_recording_count = map_size(state.active_recordings)
    max_simultaneous = state.tier_config[:max_simultaneous_tracks] || 4

    if current_recording_count >= max_simultaneous do
      {:reply, {:error, :recording_limit_exceeded}, state}
    else
      recording_session = %{
        track_id: track_id,
        user_id: user_id,
        started_at: DateTime.utc_now(),
        quality_settings: determine_quality_settings(state.tier_config, opts),
        chunks: [],
        input_monitoring: opts[:monitoring] || false
      }

      new_active_recordings = Map.put(state.active_recordings, {track_id, user_id}, recording_session)
      new_state = %{state | active_recordings: new_active_recordings}

      # Broadcast recording started
      broadcast_recording_event(state.session_id, {:recording_started, track_id, user_id, recording_session})

      # Initialize audio chunks storage
      chunk_key = {track_id, user_id}
      new_audio_chunks = Map.put(state.audio_chunks, chunk_key, [])
      new_state = %{new_state | audio_chunks: new_audio_chunks}

      {:reply, {:ok, recording_session}, new_state}
    end
  end

  @impl true
  def handle_call({:stop_recording, track_id, user_id}, _from, state) do
    recording_key = {track_id, user_id}

    case Map.get(state.active_recordings, recording_key) do
      nil ->
        {:reply, {:error, :recording_not_found}, state}

      recording_session ->
        # Compile audio chunks into track
        audio_chunks = Map.get(state.audio_chunks, recording_key, [])
        compiled_audio = compile_audio_chunks(audio_chunks)

        # Create recording track record
        track_record = %{
          track_id: track_id,
          user_id: user_id,
          session_id: state.session_id,
          started_at: recording_session.started_at,
          ended_at: DateTime.utc_now(),
          duration: calculate_duration(recording_session.started_at),
          audio_data: compiled_audio,
          quality_settings: recording_session.quality_settings,
          watermarked: apply_watermark(compiled_audio, state.protection_settings),
          chunks_count: length(audio_chunks)
        }

        # Store in recording tracks
        new_recording_tracks = Map.put(state.recording_tracks, recording_key, track_record)

        # Remove from active recordings
        new_active_recordings = Map.delete(state.active_recordings, recording_key)
        new_audio_chunks = Map.delete(state.audio_chunks, recording_key)

        new_state = %{state |
          recording_tracks: new_recording_tracks,
          active_recordings: new_active_recordings,
          audio_chunks: new_audio_chunks
        }

        # Save recording to session storage
        Task.start(fn -> save_recording_to_session_storage(track_record) end)

        # Broadcast recording stopped
        broadcast_recording_event(state.session_id, {:recording_stopped, track_id, user_id, track_record})

        # Start background audio analysis
        Task.start(fn -> analyze_recording_async(track_record) end)

        {:reply, {:ok, track_record}, new_state}
    end
  end

  @impl true
  def handle_call({:create_draft, draft_params}, _from, state) do
    # Create draft from current recording tracks
    draft = %{
      id: generate_draft_id(),
      session_id: state.session_id,
      created_at: DateTime.utc_now(),
      title: draft_params[:title] || "Untitled Draft",
      tracks: state.recording_tracks,
      mix_settings: state.mix_settings,
      collaborators: get_session_collaborators(state.session_id),
      protection_level: :draft,
      expires_at: calculate_draft_expiry(state.tier_config)
    }

    # Create creation proof
    proof = CreationProof.create_proof(
      state.session_id,
      state.recording_tracks,
      draft.collaborators
    )

    draft_with_proof = Map.put(draft, :creation_proof, proof)

    # Save draft
    case save_draft(draft_with_proof) do
      {:ok, saved_draft} ->
        new_draft_state = Map.put(state.draft_state, draft.id, saved_draft)
        new_state = %{state | draft_state: new_draft_state}

        # Broadcast draft created
        broadcast_recording_event(state.session_id, {:draft_created, saved_draft})

        {:reply, {:ok, saved_draft}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:export_to_media, export_params, user}, _from, state) do
    draft_id = export_params[:draft_id]

    case Map.get(state.draft_state, draft_id) do
      nil ->
        {:reply, {:error, :draft_not_found}, state}

      draft ->
        # Check export credits/permissions
        case ContentStrategy.check_export_permission(user, export_params, state.tier_config) do
          {:ok, export_settings} ->
            # Process export
            export_result = process_export_to_media(draft, export_params, export_settings, user)

            case export_result do
              {:ok, media_files} ->
                # Deduct export credits if applicable
                ContentStrategy.deduct_export_credits(user, export_settings)

                # Broadcast export completed
                broadcast_recording_event(state.session_id, {:export_completed, draft_id, media_files})

                {:reply, {:ok, media_files}, state}

              {:error, reason} ->
                {:reply, {:error, reason}, state}
            end

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:update_mix_settings, user_id, mix_settings}, _from, state) do
    new_mix_settings = Map.put(state.mix_settings, user_id, mix_settings)
    new_state = %{state | mix_settings: new_mix_settings}

    # Broadcast mix settings updated
    broadcast_recording_event(state.session_id, {:mix_settings_updated, user_id, mix_settings})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_recording_state, _from, state) do
    public_state = %{
      session_id: state.session_id,
      active_recordings: state.active_recordings,
      recording_tracks: map_track_summaries(state.recording_tracks),
      drafts: Map.keys(state.draft_state),
      collaboration_state: state.collaboration_state,
      tier_limits: %{
        max_simultaneous_tracks: state.tier_config[:max_simultaneous_tracks],
        max_recording_hours: state.tier_config[:max_recording_hours],
        current_active: map_size(state.active_recordings)
      }
    }

    {:reply, {:ok, public_state}, state}
  end

  @impl true
  def handle_cast({:add_audio_chunk, track_id, user_id, audio_data, timestamp}, state) do
    chunk_key = {track_id, user_id}

    chunk = %{
      data: audio_data,
      timestamp: timestamp,
      size: byte_size(audio_data),
      received_at: DateTime.utc_now()
    }

    new_chunks = Map.update(state.audio_chunks, chunk_key, [chunk], &[chunk | &1])
    new_state = %{state | audio_chunks: new_chunks}

    # Broadcast chunk received for real-time monitoring
    broadcast_recording_event(state.session_id, {:chunk_received, track_id, user_id, chunk})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:cleanup_expired_drafts}, state) do
    # Clean up expired drafts
    now = DateTime.utc_now()
    active_drafts = Enum.filter(state.draft_state, fn {_id, draft} ->
      DateTime.compare(draft.expires_at, now) == :gt
    end) |> Map.new()

    new_state = %{state | draft_state: active_drafts}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp via_tuple(session_id) do
    {:via, Registry, {Frestyl.Studio.RecordingEngineRegistry, session_id}}
  end

  defp determine_quality_settings(tier_config, opts) do
    base_quality = case tier_config.tier do
      :pro -> %{sample_rate: 48000, bit_depth: 24, channels: 2}
      :premium -> %{sample_rate: 44100, bit_depth: 24, channels: 2}
      :free -> %{sample_rate: 44100, bit_depth: 16, channels: 2}
    end

    # Apply any user overrides (within tier limits)
    Map.merge(base_quality, opts[:quality] || %{})
  end

  defp compile_audio_chunks(chunks) do
    # Sort chunks by timestamp and compile into single audio stream
    sorted_chunks = Enum.sort_by(chunks, & &1.timestamp)
    Enum.map(sorted_chunks, & &1.data) |> Enum.join()
  end

  defp apply_watermark(audio_data, protection_settings) do
    if protection_settings.watermarked do
      # Apply inaudible watermark to audio data
      # This is a simplified version - real implementation would use audio processing
      watermark_metadata = %{
        platform: "frestyl",
        timestamp: DateTime.utc_now(),
        protection_level: protection_settings.level
      }

      # In real implementation, this would embed metadata in audio spectrum
      %{audio: audio_data, watermark: watermark_metadata}
    else
      audio_data
    end
  end

  defp calculate_duration(started_at) do
    DateTime.diff(DateTime.utc_now(), started_at, :second)
  end

  defp generate_draft_id do
    "draft_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp calculate_draft_expiry(tier_config) do
    days = tier_config[:max_draft_days] || 3
    DateTime.utc_now() |> DateTime.add(days * 24 * 60 * 60, :second)
  end

  defp get_session_collaborators(session_id) do
    # Get active collaborators from presence system
    case Sessions.get_session(session_id) do
      nil -> []
      session ->
        presence_list = Frestyl.Presence.list("studio:#{session_id}")
        Enum.map(presence_list, fn {user_id, _meta} -> String.to_integer(user_id) end)
    end
  end

  defp save_draft(draft) do
    # Save draft to session storage with expiry
    storage_path = generate_draft_storage_path(draft.session_id, draft.id)

    try do
      File.mkdir_p!(Path.dirname(storage_path))

      draft_data = %{
        metadata: Map.drop(draft, [:tracks]),
        tracks: serialize_tracks_for_storage(draft.tracks)
      }

      File.write!(storage_path, Jason.encode!(draft_data))
      {:ok, draft}
    rescue
      e -> {:error, "Failed to save draft: #{inspect(e)}"}
    end
  end

  defp save_recording_to_session_storage(track_record) do
    storage_path = generate_recording_storage_path(
      track_record.session_id,
      track_record.track_id,
      track_record.user_id
    )

    File.mkdir_p!(Path.dirname(storage_path))
    File.write!(storage_path, track_record.audio_data)

    Logger.info("Saved recording to #{storage_path}")
  end

  defp analyze_recording_async(track_record) do
    # Background audio analysis
    try do
      analysis = %{
        duration: track_record.duration,
        estimated_bpm: estimate_bpm(track_record.audio_data),
        energy_level: calculate_energy_level(track_record.audio_data),
        peak_levels: calculate_peak_levels(track_record.audio_data),
        spectral_features: extract_spectral_features(track_record.audio_data)
      }

      # Store analysis results
      store_analysis_results(track_record, analysis)

      Logger.info("Completed audio analysis for track #{track_record.track_id}")
    rescue
      e -> Logger.error("Audio analysis failed: #{inspect(e)}")
    end
  end

  defp process_export_to_media(draft, export_params, export_settings, user) do
    try do
      # Compile tracks based on export settings
      compiled_tracks = compile_tracks_for_export(draft.tracks, export_settings)

      # Apply optimization
      optimized_tracks = Enum.map(compiled_tracks, fn track ->
        case Optimizer.optimize(track.audio_data, "audio", export_settings.scenario) do
          {:ok, optimized_path} -> Map.put(track, :optimized_path, optimized_path)
          {:error, _} -> track
        end
      end)

      # Create MediaFiles
      media_files = Enum.map(optimized_tracks, fn track ->
        create_media_file_from_track(track, draft, export_params, user)
      end)

      # Create MediaGroup if multiple tracks
      if length(media_files) > 1 do
        group_params = %{
          title: export_params[:title] || draft.title,
          description: "Recorded session exported from Frestyl",
          user_id: user.id,
          channel_id: export_params[:channel_id],
          collaboration_enabled: true,
          metadata: %{
            source: "recording_session",
            session_id: draft.session_id,
            creation_proof: draft.creation_proof
          }
        }

        Media.create_media_group(group_params, Enum.map(media_files, & &1.id))
      end

      {:ok, media_files}
    rescue
      e -> {:error, "Export failed: #{inspect(e)}"}
    end
  end

  defp create_media_file_from_track(track, draft, export_params, user) do
    # Generate filename
    filename = generate_export_filename(track, draft, export_params)

    # Prepare metadata
    metadata = %{
      source: "frestyl_recording",
      session_id: draft.session_id,
      track_id: track.track_id,
      collaborators: draft.collaborators,
      creation_proof: draft.creation_proof,
      recording_quality: track.quality_settings
    }

    # Create MediaFile
    case Media.create_file(%{
      filename: filename,
      original_filename: filename,
      file_type: "audio",
      user_id: user.id,
      channel_id: export_params[:channel_id],
      metadata: metadata
    }, track.optimized_path || track.audio_data) do
      {:ok, media_file} ->
        # Create music metadata
        create_music_metadata_from_track(media_file, track, draft)
        media_file
      {:error, reason} ->
        Logger.error("Failed to create media file: #{inspect(reason)}")
        nil
    end
  end

  defp create_music_metadata_from_track(media_file, track, draft) do
    # Extract metadata from track analysis and session
    music_metadata_params = %{
      media_file_id: media_file.id,
      collaborators: draft.collaborators,
      creation_session_id: draft.session_id,
      bpm: track.analysis[:estimated_bpm],
      energy_level: track.analysis[:energy_level],
      metadata: %{
        recording_session: draft.session_id,
        creation_proof: draft.creation_proof
      }
    }

    Media.upsert_music_metadata(media_file.id, music_metadata_params)
  end

  defp broadcast_recording_event(session_id, event) do
    PubSub.broadcast(Frestyl.PubSub, "recording_engine:#{session_id}", event)
    PubSub.broadcast(Frestyl.PubSub, "session:#{session_id}", {:recording_event, event})
  end

  defp map_track_summaries(recording_tracks) do
    Enum.map(recording_tracks, fn {{track_id, user_id}, track} ->
      %{
        track_id: track_id,
        user_id: user_id,
        duration: track.duration,
        started_at: track.started_at,
        ended_at: track.ended_at,
        chunks_count: track.chunks_count
      }
    end)
  end

  # Storage path helpers
  defp generate_draft_storage_path(session_id, draft_id) do
    "uploads/sessions/#{session_id}/drafts/#{draft_id}.json"
  end

  defp generate_recording_storage_path(session_id, track_id, user_id) do
    date_path = Date.utc_today() |> Date.to_string()
    "uploads/sessions/#{session_id}/recordings/#{date_path}/#{track_id}_#{user_id}.wav"
  end

  defp generate_export_filename(track, draft, export_params) do
    base_name = export_params[:filename] || draft.title || "Frestyl Recording"
    track_suffix = if Map.get(track, :track_name), do: "_#{track.track_name}", else: ""
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    "#{base_name}#{track_suffix}_#{timestamp}.wav"
  end

  # Audio analysis helpers (simplified versions)
  defp estimate_bpm(_audio_data), do: 120.0 # Placeholder
  defp calculate_energy_level(_audio_data), do: 0.7 # Placeholder
  defp calculate_peak_levels(_audio_data), do: %{left: 0.8, right: 0.75} # Placeholder
  defp extract_spectral_features(_audio_data), do: %{} # Placeholder

  defp store_analysis_results(_track_record, _analysis) do
    # Store analysis results for later use
    :ok
  end

  defp serialize_tracks_for_storage(tracks) do
    # Convert tracks to JSON-serializable format
    Enum.map(tracks, fn {{track_id, user_id}, track} ->
      %{
        track_id: track_id,
        user_id: user_id,
        duration: track.duration,
        started_at: track.started_at,
        ended_at: track.ended_at,
        audio_path: generate_recording_storage_path(track.session_id, track_id, user_id)
      }
    end)
  end

  defp compile_tracks_for_export(tracks, export_settings) do
    # Compile and process tracks based on export settings
    Enum.map(tracks, fn {{track_id, user_id}, track} ->
      %{
        track_id: track_id,
        user_id: user_id,
        audio_data: track.audio_data,
        quality_settings: apply_export_quality(track.quality_settings, export_settings)
      }
    end)
  end

  defp apply_export_quality(original_settings, export_settings) do
    # Apply quality constraints based on tier and export settings
    Map.merge(original_settings, export_settings.quality_overrides || %{})
  end
end
