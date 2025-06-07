# lib/frestyl/studio/audio_text_sync.ex
defmodule Frestyl.Studio.AudioTextSync do
  @moduledoc """
  Handles synchronization between audio timeline and text content
  for lyrics writing and audiobook recording workflows.
  """

  use GenServer
  require Logger
  alias Phoenix.PubSub

  defstruct [
    :session_id,
    :mode,
    :text_blocks,
    :sync_points,
    :current_position,
    :current_block,
    :beat_detection,
    :auto_scroll,
    :subscribers
  ]

  # Client API

  # FIXED: Handle both tuple and separate arguments for compatibility
  def start_link({session_id, mode}) do
    GenServer.start_link(__MODULE__, {session_id, mode}, name: via_tuple(session_id))
  end

  def start_link(session_id, mode \\ "lyrics_with_audio") do
    GenServer.start_link(__MODULE__, {session_id, mode}, name: via_tuple(session_id))
  end

  def set_mode(session_id, mode) when mode in ["lyrics_with_audio", "audio_with_script"] do
    GenServer.call(via_tuple(session_id), {:set_mode, mode})
  end

  def sync_text_block(session_id, block_id, start_time, end_time \\ nil) do
    GenServer.call(via_tuple(session_id), {:sync_text_block, block_id, start_time, end_time})
  end

  def update_audio_position(session_id, position) do
    GenServer.cast(via_tuple(session_id), {:update_position, position})
  end

  def add_text_block(session_id, block) do
    GenServer.call(via_tuple(session_id), {:add_text_block, block})
  end

  def update_text_block(session_id, block_id, content) do
    GenServer.call(via_tuple(session_id), {:update_text_block, block_id, content})
  end

  def get_current_block(session_id) do
    GenServer.call(via_tuple(session_id), :get_current_block)
  end

  def get_sync_state(session_id) do
    GenServer.call(via_tuple(session_id), :get_sync_state)
  end

  def detect_beats(session_id, audio_data, options \\ %{}) do
    GenServer.call(via_tuple(session_id), {:detect_beats, audio_data, options})
  end

  def auto_align_lyrics(session_id, lyrics, beat_data) do
    GenServer.call(via_tuple(session_id), {:auto_align_lyrics, lyrics, beat_data})
  end

  # GenServer Implementation

  @impl true
  def init({session_id, mode}) do
    state = %__MODULE__{
      session_id: session_id,
      mode: mode,
      text_blocks: [],
      sync_points: [],
      current_position: 0.0,
      current_block: nil,
      beat_detection: %{enabled: false, bpm: 120, beats: []},
      auto_scroll: true,
      subscribers: MapSet.new()
    }

    # Subscribe to audio engine events
    PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")
    PubSub.subscribe(Frestyl.PubSub, "studio:#{session_id}")

    Logger.info("AudioTextSync started for session #{session_id} in #{mode} mode")
    {:ok, state}
  end

  @impl true
  def handle_call({:set_mode, mode}, _from, state) do
    new_state = %{state | mode: mode}
    broadcast_sync_event(state.session_id, {:mode_changed, mode})
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:sync_text_block, block_id, start_time, end_time}, _from, state) do
    sync_point = %{
      block_id: block_id,
      start_time: start_time,
      end_time: end_time,
      created_at: DateTime.utc_now()
    }

    new_sync_points = [sync_point | state.sync_points]
    new_state = %{state | sync_points: new_sync_points}

    # Update current block if this sync point is active
    new_state = update_current_block_from_position(new_state)

    broadcast_sync_event(state.session_id, {:text_synced, sync_point})
    {:reply, {:ok, sync_point}, new_state}
  end

  @impl true
  def handle_call({:add_text_block, block}, _from, state) do
    block_with_id = Map.put_new(block, :id, generate_block_id())
    new_blocks = [block_with_id | state.text_blocks]
    new_state = %{state | text_blocks: new_blocks}

    broadcast_sync_event(state.session_id, {:text_block_added, block_with_id})
    {:reply, {:ok, block_with_id}, new_state}
  end

  @impl true
  def handle_call({:update_text_block, block_id, content}, _from, state) do
    new_blocks = Enum.map(state.text_blocks, fn block ->
      if block.id == block_id do
        %{block | content: content, updated_at: DateTime.utc_now()}
      else
        block
      end
    end)

    new_state = %{state | text_blocks: new_blocks}

    broadcast_sync_event(state.session_id, {:text_block_updated, block_id, content})
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_current_block, _from, state) do
    current_block = case state.current_block do
      nil -> nil
      block_id -> Enum.find(state.text_blocks, &(&1.id == block_id))
    end

    {:reply, current_block, state}
  end

  @impl true
  def handle_call(:get_sync_state, _from, state) do
    sync_state = %{
      mode: state.mode,
      current_position: state.current_position,
      current_block: state.current_block,
      text_blocks: state.text_blocks,
      sync_points: state.sync_points,
      beat_detection: state.beat_detection
    }

    {:reply, sync_state, state}
  end

  @impl true
  def handle_call({:detect_beats, audio_data, options}, _from, state) do
    case analyze_beats(audio_data, options) do
      {:ok, beat_data} ->
        new_beat_detection = %{
          enabled: true,
          bpm: beat_data.bpm,
          beats: beat_data.beats,
          confidence: beat_data.confidence,
          detected_at: DateTime.utc_now()
        }

        new_state = %{state | beat_detection: new_beat_detection}
        broadcast_sync_event(state.session_id, {:beats_detected, beat_data})

        {:reply, {:ok, beat_data}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:auto_align_lyrics, lyrics, beat_data}, _from, state) do
    case align_lyrics_to_beats(lyrics, beat_data) do
      {:ok, aligned_blocks} ->
        # Create sync points for each aligned block
        sync_points = Enum.map(aligned_blocks, fn block ->
          %{
            block_id: block.id,
            start_time: block.start_time,
            end_time: block.end_time,
            auto_aligned: true,
            confidence: block.confidence
          }
        end)

        new_state = %{state |
          text_blocks: aligned_blocks,
          sync_points: sync_points
        }

        broadcast_sync_event(state.session_id, {:lyrics_auto_aligned, aligned_blocks})
        {:reply, {:ok, aligned_blocks}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:update_position, position}, state) do
    new_state = %{state | current_position: position}
    new_state = update_current_block_from_position(new_state)

    # Broadcast position update if current block changed
    if new_state.current_block != state.current_block do
      broadcast_sync_event(state.session_id, {:current_block_changed, new_state.current_block})
    end

    {:noreply, new_state}
  end

  # Handle audio engine events
  @impl true
  def handle_info({:playback_position, position}, state) do
    # Convert position to our format and update
    handle_cast({:update_position, position}, state)
  end

  @impl true
  def handle_info({:playback_started, position}, state) do
    broadcast_sync_event(state.session_id, {:sync_playback_started, position})
    {:noreply, %{state | current_position: position}}
  end

  @impl true
  def handle_info({:playback_stopped, position}, state) do
    broadcast_sync_event(state.session_id, {:sync_playback_stopped, position})
    {:noreply, %{state | current_position: position}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # Private Functions

  defp via_tuple(session_id) do
    {:via, Registry, {Frestyl.Studio.AudioTextSyncRegistry, session_id}}
  end

  defp generate_block_id do
    "block_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp update_current_block_from_position(state) do
    current_block = find_current_block_by_position(state.sync_points, state.current_position)
    %{state | current_block: current_block}
  end

  defp find_current_block_by_position(sync_points, position) do
    Enum.find_value(sync_points, fn sync_point ->
      start_time = sync_point.start_time
      end_time = sync_point.end_time || (start_time + 5000) # Default 5 second blocks

      if position >= start_time and position < end_time do
        sync_point.block_id
      end
    end)
  end

  defp analyze_beats(audio_data, options) do
    # Simplified beat detection - in production you'd use actual audio analysis
    # This could integrate with libraries like aubio or custom ML models

    bpm = options[:expected_bpm] || 120
    confidence = 0.8 # Mock confidence

    # Generate mock beat positions based on BPM
    beat_interval = 60_000 / bpm # milliseconds per beat
    duration = byte_size(audio_data) / 1000 # rough duration estimate

    beats = 0..trunc(duration / beat_interval)
    |> Enum.map(fn beat_num -> beat_num * beat_interval end)

    {:ok, %{
      bpm: bpm,
      beats: beats,
      confidence: confidence,
      beat_interval: beat_interval
    }}
  end

  defp align_lyrics_to_beats(lyrics, beat_data) do
    # Simple alignment algorithm - in production this would be more sophisticated
    words = String.split(lyrics, ~r/\s+/)
    beats = beat_data.beats

    # Distribute words across beats
    words_per_beat = max(1, length(words) / length(beats))

    aligned_blocks = words
    |> Enum.chunk_every(trunc(words_per_beat))
    |> Enum.with_index()
    |> Enum.map(fn {word_chunk, index} ->
      start_time = Enum.at(beats, index, 0)
      end_time = Enum.at(beats, index + 1, start_time + beat_data.beat_interval)

      %{
        id: generate_block_id(),
        content: Enum.join(word_chunk, " "),
        start_time: start_time,
        end_time: end_time,
        confidence: 0.7,
        type: "lyric_line"
      }
    end)

    {:ok, aligned_blocks}
  end

  defp broadcast_sync_event(session_id, event) do
    PubSub.broadcast(Frestyl.PubSub, "audio_text_sync:#{session_id}", event)
    PubSub.broadcast(Frestyl.PubSub, "studio:#{session_id}", {:audio_text_sync, event})
  end
end
