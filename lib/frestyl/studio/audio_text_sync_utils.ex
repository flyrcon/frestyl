# lib/frestyl/studio/audio_text_sync_utils.ex
defmodule Frestyl.Studio.AudioTextSyncUtils do
  @moduledoc """
  Utility functions for audio-text synchronization.
  """

  alias Frestyl.Studio.AudioTextSync

  @doc """
  Get or start an audio-text sync engine for a session.
  """
  def get_or_start_sync_engine(session_id, mode \\ "lyrics_with_audio") do
    case Registry.lookup(Frestyl.Studio.AudioTextSyncRegistry, session_id) do
      [{_pid, _}] ->
        {:ok, :already_running}
      [] ->
        Frestyl.Studio.AudioTextSyncSupervisor.start_sync_engine(session_id, mode)
    end
  end

  @doc """
  Safely get sync state, starting engine if needed.
  """
  def get_sync_state(session_id, mode \\ "lyrics_with_audio") do
    case get_or_start_sync_engine(session_id, mode) do
      {:ok, _} ->
        AudioTextSync.get_sync_state(session_id)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Cleanup sync engine when session ends.
  """
  def cleanup_session(session_id) do
    case Frestyl.Studio.AudioTextSyncSupervisor.stop_sync_engine(session_id) do
      :ok ->
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "audio_text_sync:#{session_id}",
          {:sync_engine_stopped}
        )
        :ok
      {:error, :not_found} ->
        :ok
      error ->
        error
    end
  end

  @doc """
  Convert text blocks to lyrics format for beat alignment.
  """
  def format_blocks_for_alignment(blocks) do
    blocks
    |> Enum.sort_by(& &1.created_at)
    |> Enum.map(fn block ->
      %{
        id: block.id,
        content: block.content,
        type: block.type || "verse",
        word_count: count_words(block.content),
        estimated_duration: estimate_block_duration(block.content, block.type)
      }
    end)
  end

  @doc """
  Auto-detect song structure from lyrics blocks.
  """
  def detect_song_structure(blocks) do
    structure = blocks
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, type_blocks} ->
      %{
        section_type: type,
        count: length(type_blocks),
        average_length: average_block_length(type_blocks),
        positions: Enum.map(type_blocks, & &1.id)
      }
    end)

    %{
      sections: structure,
      total_blocks: length(blocks),
      estimated_song_length: estimate_total_duration(blocks)
    }
  end

  @doc """
  Generate smart sync suggestions based on beat pattern and lyrics.
  """
  def generate_sync_suggestions(blocks, beat_data) do
    case beat_data do
      %{bpm: bpm, beats: beats} when length(beats) > 0 ->
        beat_interval = 60_000 / bpm # milliseconds per beat

        blocks
        |> Enum.with_index()
        |> Enum.map(fn {block, index} ->
          suggested_start = index * beat_interval * 4 # 4 beats per block
          suggested_end = suggested_start + estimate_block_duration(block.content, block.type)

          %{
            block_id: block.id,
            suggested_start_time: suggested_start,
            suggested_end_time: suggested_end,
            confidence: calculate_sync_confidence(block, beat_data),
            beat_alignment: find_nearest_beat(suggested_start, beats)
          }
        end)
      _ ->
        []
    end
  end

  @doc """
  Validate sync point timing against audio constraints.
  """
  def validate_sync_point(sync_point, audio_duration, existing_sync_points \\ []) do
    errors = []

    # Check if sync point is within audio duration
    errors = if sync_point.start_time > audio_duration do
      ["Sync point is beyond audio duration" | errors]
    else
      errors
    end

    # Check for overlapping sync points
    overlapping = Enum.find(existing_sync_points, fn existing ->
      existing.block_id != sync_point.block_id and
      ranges_overlap?(
        {sync_point.start_time, sync_point.end_time},
        {existing.start_time, existing.end_time}
      )
    end)

    errors = if overlapping do
      ["Sync point overlaps with existing sync at #{format_time(overlapping.start_time)}" | errors]
    else
      errors
    end

    case errors do
      [] -> {:ok, sync_point}
      _ -> {:error, errors}
    end
  end

  # Private helper functions

  defp count_words(content) when is_binary(content) do
    content
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end
  defp count_words(_), do: 0

  defp estimate_block_duration(content, type) do
    word_count = count_words(content)
    base_duration = word_count * 500 # 500ms per word baseline

    # Adjust for block type
    multiplier = case type do
      "chorus" -> 0.8  # Choruses often faster
      "verse" -> 1.0   # Normal pace
      "bridge" -> 1.2  # Bridges often slower
      "outro" -> 1.5   # Outros usually slower
      _ -> 1.0
    end

    base_duration * multiplier
  end

  defp average_block_length(blocks) do
    if length(blocks) > 0 do
      total_length = Enum.sum(Enum.map(blocks, &count_words(&1.content)))
      total_length / length(blocks)
    else
      0
    end
  end

  defp estimate_total_duration(blocks) do
    Enum.sum(Enum.map(blocks, &estimate_block_duration(&1.content, &1.type)))
  end

  defp calculate_sync_confidence(block, beat_data) do
    # Simple confidence calculation based on word count and beat regularity
    word_count = count_words(block.content)
    beat_confidence = beat_data.confidence || 0.5

    word_factor = min(1.0, word_count / 10) # Higher confidence with more words

    (beat_confidence + word_factor) / 2
  end

  defp find_nearest_beat(time_ms, beats) do
    beats
    |> Enum.min_by(&abs(&1 - time_ms))
  end

  defp ranges_overlap?({start1, end1}, {start2, end2}) do
    start1 < end2 and start2 < end1
  end

  defp format_time(milliseconds) when is_number(milliseconds) do
    seconds = div(trunc(milliseconds), 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end
  defp format_time(_), do: "00:00"
end
