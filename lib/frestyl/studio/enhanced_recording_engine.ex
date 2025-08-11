# lib/frestyl/studio/enhanced_recording_engine.ex
defmodule Frestyl.Studio.EnhancedRecordingEngine do
  @moduledoc """
  Enhanced recording engine that integrates with audio processing and cloud storage.
  Replaces placeholder implementations with production-ready audio handling.
  """

  use GenServer
  require Logger
  alias Frestyl.Storage.{AudioProcessor, CloudUploader}
  alias Frestyl.{Sessions, Media}
  alias Phoenix.PubSub

  defstruct [
    :session_id,
    :active_recordings,
    :completed_recordings,
    :audio_chunks,
    :tier_config,
    :processing_queue,
    :upload_queue,
    :started_at
  ]

  # Client API

  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via_tuple(session_id))
  end

  def start_recording(session_id, track_id, user_id, opts \\ []) do
    GenServer.call(via_tuple(session_id), {:start_recording, track_id, user_id, opts})
  end

  def stop_recording(session_id, track_id, user_id) do
    GenServer.call(via_tuple(session_id), {:stop_recording, track_id, user_id})
  end

  def add_audio_chunk(session_id, track_id, user_id, chunk_data) do
    GenServer.cast(via_tuple(session_id), {:audio_chunk, track_id, user_id, chunk_data})
  end

  def get_recording_state(session_id) do
    try do
      GenServer.call(via_tuple(session_id), :get_state)
    catch
      :exit, {:noproc, _} -> {:error, :not_found}
    end
  end

  def export_recording(session_id, track_id, format \\ "mp3") do
    GenServer.call(via_tuple(session_id), {:export_recording, track_id, format}, 30_000)
  end

  def list_recordings(session_id) do
    GenServer.call(via_tuple(session_id), :list_recordings)
  end

  # GenServer Callbacks

  @impl true
  def init(session_id) do
    # Get session info for tier limits
    session = Sessions.get_session!(session_id)
    tier_config = get_tier_limits(session.user_id)

    state = %__MODULE__{
      session_id: session_id,
      active_recordings: %{},
      completed_recordings: %{},
      audio_chunks: %{},
      tier_config: tier_config,
      processing_queue: :queue.new(),
      upload_queue: :queue.new(),
      started_at: DateTime.utc_now()
    }

    # Subscribe to session events
    PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}")

    # Start periodic processing tasks
    schedule_chunk_processing()
    schedule_upload_processing()

    Logger.info("Enhanced RecordingEngine started for session #{session_id}")
    {:ok, state}
  end

  @impl true
  def handle_call({:start_recording, track_id, user_id, opts}, _from, state) do
    recording_key = {track_id, user_id}

    # Check if already recording
    if Map.has_key?(state.active_recordings, recording_key) do
      {:reply, {:error, :already_recording}, state}
    else
      # Check tier limits
      current_count = map_size(state.active_recordings)
      max_simultaneous = state.tier_config[:max_simultaneous_tracks] || 4

      if current_count >= max_simultaneous do
        {:reply, {:error, :recording_limit_exceeded}, state}
      else
        # Create recording session
        recording_session = %{
          track_id: track_id,
          user_id: user_id,
          started_at: DateTime.utc_now(),
          quality_settings: determine_quality_settings(state.tier_config, opts),
          format: Keyword.get(opts, :format, "mp3"),
          effects: Keyword.get(opts, :effects, []),
          monitoring: Keyword.get(opts, :monitoring, false),
          auto_upload: Keyword.get(opts, :auto_upload, true)
        }

        # Update state
        new_active_recordings = Map.put(state.active_recordings, recording_key, recording_session)
        new_audio_chunks = Map.put(state.audio_chunks, recording_key, [])
        new_state = %{state |
          active_recordings: new_active_recordings,
          audio_chunks: new_audio_chunks
        }

        # Broadcast recording started
        broadcast_recording_event(state.session_id, {:recording_started, track_id, user_id, recording_session})

        Logger.info("Recording started: session=#{state.session_id}, track=#{track_id}, user=#{user_id}")
        {:reply, {:ok, recording_session}, new_state}
      end
    end
  end

  @impl true
  def handle_call({:stop_recording, track_id, user_id}, _from, state) do
    recording_key = {track_id, user_id}

    case Map.get(state.active_recordings, recording_key) do
      nil ->
        {:reply, {:error, :recording_not_found}, state}

      recording_session ->
        # Get audio chunks for this recording
        audio_chunks = Map.get(state.audio_chunks, recording_key, [])

        # Create recording metadata
        recording_metadata = %{
          session_id: state.session_id,
          track_id: track_id,
          user_id: user_id,
          started_at: recording_session.started_at,
          ended_at: DateTime.utc_now(),
          duration: calculate_duration(recording_session.started_at),
          chunk_count: length(audio_chunks),
          quality_settings: recording_session.quality_settings,
          format: recording_session.format,
          effects: recording_session.effects
        }

        # Queue for processing if we have chunks
        new_state = if length(audio_chunks) > 0 do
          processing_task = %{
            type: :compile_recording,
            recording_key: recording_key,
            audio_chunks: audio_chunks,
            recording_session: recording_session,
            metadata: recording_metadata
          }

          new_processing_queue = :queue.in(processing_task, state.processing_queue)
          %{state | processing_queue: new_processing_queue}
        else
          state
        end

        # Remove from active recordings
        new_active_recordings = Map.delete(new_state.active_recordings, recording_key)
        new_audio_chunks = Map.delete(new_state.audio_chunks, recording_key)

        final_state = %{new_state |
          active_recordings: new_active_recordings,
          audio_chunks: new_audio_chunks
        }

        # Broadcast recording stopped
        broadcast_recording_event(state.session_id, {:recording_stopped, track_id, user_id, recording_metadata})

        Logger.info("Recording stopped: session=#{state.session_id}, track=#{track_id}, user=#{user_id}")
        {:reply, {:ok, recording_metadata}, final_state}
    end
  end

  @impl true
  def handle_call({:export_recording, track_id, format}, _from, state) do
    # Find completed recording
    case find_completed_recording(state.completed_recordings, track_id) do
      nil ->
        {:reply, {:error, :recording_not_found}, state}

      recording ->
        # Check if already in requested format
        if recording.format == format do
          {:reply, {:ok, recording}, state}
        else
          # Queue for format conversion
          conversion_task = %{
            type: :convert_format,
            recording: recording,
            target_format: format,
            requester: self()
          }

          new_processing_queue = :queue.in(conversion_task, state.processing_queue)
          new_state = %{state | processing_queue: new_processing_queue}

          {:reply, {:ok, :processing}, new_state}
        end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    public_state = %{
      session_id: state.session_id,
      active_recordings: map_size(state.active_recordings),
      completed_recordings: map_size(state.completed_recordings),
      processing_queue_size: :queue.len(state.processing_queue),
      upload_queue_size: :queue.len(state.upload_queue),
      tier_limits: state.tier_config
    }
    {:reply, {:ok, public_state}, state}
  end

  @impl true
  def handle_call(:list_recordings, _from, state) do
    recordings = state.completed_recordings
    |> Map.values()
    |> Enum.map(&format_recording_info/1)

    {:reply, {:ok, recordings}, state}
  end

  @impl true
  def handle_cast({:audio_chunk, track_id, user_id, chunk_data}, state) do
    recording_key = {track_id, user_id}

    case Map.get(state.active_recordings, recording_key) do
      nil ->
        # Not recording for this track/user, ignore
        {:noreply, state}

      recording_session ->
        # Validate and process chunk
        case validate_audio_chunk(chunk_data) do
          {:ok, validated_chunk} ->
            # Apply real-time effects if configured
            processed_chunk = if length(recording_session.effects) > 0 do
              case AudioProcessor.apply_real_time_effects(validated_chunk.data, recording_session.effects) do
                {:ok, processed_data} -> %{validated_chunk | data: processed_data}
                {:error, _} -> validated_chunk  # Use original on error
              end
            else
              validated_chunk
            end

            # Add timestamp and sequence
            timestamped_chunk = Map.merge(processed_chunk, %{
              timestamp: DateTime.utc_now(),
              sequence: get_next_sequence(state.audio_chunks, recording_key)
            })

            # Add to chunks
            current_chunks = Map.get(state.audio_chunks, recording_key, [])
            new_chunks = [timestamped_chunk | current_chunks]
            new_audio_chunks = Map.put(state.audio_chunks, recording_key, new_chunks)

            # Broadcast chunk received (for real-time monitoring)
            broadcast_recording_event(state.session_id, {:audio_chunk_received, track_id, user_id, timestamped_chunk})

            {:noreply, %{state | audio_chunks: new_audio_chunks}}

          {:error, reason} ->
            Logger.warning("Invalid audio chunk received: #{reason}")
            {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info(:process_chunks, state) do
    new_state = process_next_chunk(state)
    schedule_chunk_processing()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:process_uploads, state) do
    new_state = process_next_upload(state)
    schedule_upload_processing()
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:processing_complete, recording_key, result}, state) do
    case result do
      {:ok, compiled_recording} ->
        # Add to completed recordings
        new_completed = Map.put(state.completed_recordings, recording_key, compiled_recording)

        # Queue for upload if auto_upload is enabled
        new_state = if compiled_recording.auto_upload do
          upload_task = %{
            type: :upload_recording,
            recording: compiled_recording,
            recording_key: recording_key
          }
          new_upload_queue = :queue.in(upload_task, state.upload_queue)
          %{state | upload_queue: new_upload_queue}
        else
          state
        end

        final_state = %{new_state | completed_recordings: new_completed}

        # Broadcast completion
        broadcast_recording_event(state.session_id, {:recording_compiled, recording_key, compiled_recording})

        Logger.info("Recording compiled successfully: #{inspect(recording_key)}")
        {:noreply, final_state}

      {:error, reason} ->
        Logger.error("Recording compilation failed: #{inspect(recording_key)}, reason: #{reason}")
        broadcast_recording_event(state.session_id, {:recording_compilation_failed, recording_key, reason})
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:upload_complete, recording_key, result}, state) do
    case result do
      {:ok, upload_info} ->
        # Update recording with upload info
        updated_recording = get_in(state.completed_recordings, [recording_key])
        |> Map.put(:upload_info, upload_info)
        |> Map.put(:uploaded_at, DateTime.utc_now())

        new_completed = Map.put(state.completed_recordings, recording_key, updated_recording)
        new_state = %{state | completed_recordings: new_completed}

        # Broadcast upload completion
        broadcast_recording_event(state.session_id, {:recording_uploaded, recording_key, upload_info})

        Logger.info("Recording uploaded successfully: #{inspect(recording_key)}")
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Recording upload failed: #{inspect(recording_key)}, reason: #{reason}")
        broadcast_recording_event(state.session_id, {:recording_upload_failed, recording_key, reason})
        {:noreply, state}
    end
  end

  # Private Functions

  defp via_tuple(session_id) do
    {:via, Registry, {Frestyl.Studio.RecordingEngineRegistry, session_id}}
  end

  defp get_tier_limits(user_id) do
    # Get user's subscription tier and return limits
    # This would integrate with your existing tier system
    %{
      max_simultaneous_tracks: 8,
      max_recording_duration: 3600, # 1 hour
      supported_formats: ["mp3", "wav", "flac"],
      max_quality: "high",
      effects_enabled: true,
      cloud_storage: true
    }
  end

  defp determine_quality_settings(tier_config, opts) do
    requested_quality = Keyword.get(opts, :quality, "medium")
    max_quality = tier_config[:max_quality] || "medium"

    # Ensure requested quality doesn't exceed tier limits
    final_quality = if quality_level(requested_quality) <= quality_level(max_quality) do
      requested_quality
    else
      max_quality
    end

    case final_quality do
      "low" -> %{sample_rate: 22050, bit_depth: 16, channels: 1}
      "medium" -> %{sample_rate: 44100, bit_depth: 16, channels: 2}
      "high" -> %{sample_rate: 48000, bit_depth: 24, channels: 2}
      "ultra" -> %{sample_rate: 96000, bit_depth: 24, channels: 2}
      _ -> %{sample_rate: 44100, bit_depth: 16, channels: 2}
    end
  end

  defp quality_level("low"), do: 1
  defp quality_level("medium"), do: 2
  defp quality_level("high"), do: 3
  defp quality_level("ultra"), do: 4
  defp quality_level(_), do: 2

  defp validate_audio_chunk(chunk_data) do
    # Validate chunk structure and content
    required_keys = [:data, :timestamp]

    if is_map(chunk_data) and Enum.all?(required_keys, &Map.has_key?(chunk_data, &1)) do
      # Additional validation
      data = Map.get(chunk_data, :data)
      if is_binary(data) and byte_size(data) > 0 do
        {:ok, chunk_data}
      else
        {:error, :invalid_audio_data}
      end
    else
      {:error, :invalid_chunk_structure}
    end
  end

  defp get_next_sequence(audio_chunks, recording_key) do
    current_chunks = Map.get(audio_chunks, recording_key, [])
    length(current_chunks) + 1
  end

  defp calculate_duration(started_at) do
    DateTime.diff(DateTime.utc_now(), started_at, :millisecond)
  end

  defp process_next_chunk(state) do
    case :queue.out(state.processing_queue) do
      {{:value, task}, new_queue} ->
        # Process task asynchronously
        spawn_link(fn -> process_recording_task(task) end)
        %{state | processing_queue: new_queue}

      {:empty, _queue} ->
        state
    end
  end

  defp process_next_upload(state) do
    case :queue.out(state.upload_queue) do
      {{:value, task}, new_queue} ->
        # Process upload asynchronously
        spawn_link(fn -> process_upload_task(task) end)
        %{state | upload_queue: new_queue}

      {:empty, _queue} ->
        state
    end
  end

  defp process_recording_task(%{type: :compile_recording} = task) do
    %{
      recording_key: recording_key,
      audio_chunks: audio_chunks,
      recording_session: recording_session,
      metadata: metadata
    } = task

    # Sort chunks by sequence
    sorted_chunks = Enum.sort_by(audio_chunks, & &1.sequence)

    # Process audio with configured quality and format
    processing_options = %{
      format: recording_session.format,
      quality: recording_session.quality_settings,
      normalize: true
    }

    case AudioProcessor.process_audio_chunks(sorted_chunks, processing_options) do
      {:ok, processed_audio} ->
        compiled_recording = Map.merge(metadata, %{
          audio_data: processed_audio,
          processing_completed_at: DateTime.utc_now(),
          auto_upload: recording_session.auto_upload,
          format: recording_session.format,
          file_size: byte_size(processed_audio)
        })

        send(self(), {:processing_complete, recording_key, {:ok, compiled_recording}})

      {:error, reason} ->
        send(self(), {:processing_complete, recording_key, {:error, reason}})
    end
  end

  defp process_upload_task(%{type: :upload_recording} = task) do
    %{recording: recording, recording_key: recording_key} = task

    # Generate filename
    filename = generate_recording_filename(recording)

    # Upload metadata
    upload_metadata = %{
      session_id: recording.session_id,
      user_id: recording.user_id,
      track_id: recording.track_id,
      format: recording.format
    }

    case CloudUploader.upload_audio_data(recording.audio_data, filename, upload_metadata) do
      {:ok, upload_info} ->
        send(self(), {:upload_complete, recording_key, {:ok, upload_info}})

      {:error, reason} ->
        send(self(), {:upload_complete, recording_key, {:error, reason}})
    end
  end

  defp generate_recording_filename(recording) do
    timestamp = DateTime.to_unix(recording.started_at)
    "recording_#{recording.session_id}_#{recording.track_id}_#{timestamp}.#{recording.format}"
  end

  defp find_completed_recording(completed_recordings, track_id) do
    completed_recordings
    |> Map.values()
    |> Enum.find(&(&1.track_id == track_id))
  end

  defp format_recording_info(recording) do
    %{
      track_id: recording.track_id,
      user_id: recording.user_id,
      duration: recording.duration,
      format: recording.format,
      file_size: recording.file_size,
      started_at: recording.started_at,
      url: get_in(recording, [:upload_info, :cdn_url]) || get_in(recording, [:upload_info, :url])
    }
  end

  defp schedule_chunk_processing do
    Process.send_after(self(), :process_chunks, 1000)  # Process every second
  end

  defp schedule_upload_processing do
    Process.send_after(self(), :process_uploads, 2000)  # Process every 2 seconds
  end

  defp broadcast_recording_event(session_id, event) do
    PubSub.broadcast(Frestyl.PubSub, "recording_engine:#{session_id}", event)
    PubSub.broadcast(Frestyl.PubSub, "session:#{session_id}", event)
  end
end
