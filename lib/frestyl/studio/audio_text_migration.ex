# lib/frestyl/studio/audio_text_migration.ex
defmodule Frestyl.Studio.AudioTextMigration do
  @moduledoc """
  Helper functions for migrating existing sessions to audio-text format.
  """

  alias Frestyl.Sessions
  alias Frestyl.Studio.AudioTextSync

  @doc """
  Migrate an existing session to audio-text format.
  """
  def migrate_session_to_audio_text(session_id, mode \\ "lyrics_with_audio") do
    case Sessions.get_session(session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        # Get existing workspace state
        workspace_state = Sessions.get_workspace_state(session_id) || %{}

        # Add audio-text structure
        audio_text_state = %{
          mode: mode,
          sync_enabled: true,
          current_text_block: nil,
          timeline: %{
            current_position: 0.0,
            duration: get_audio_duration(workspace_state),
            markers: [],
            sync_points: []
          },
          text_sync: %{
            blocks: migrate_existing_text(workspace_state),
            active_block_id: nil,
            scroll_position: 0,
            auto_scroll: true,
            highlight_current: true
          },
          beat_detection: %{
            enabled: false,
            bpm: 120,
            detected_beats: [],
            confidence: 0.0,
            auto_align: false
          },
          script_recording: %{
            enabled: false,
            current_line: 0,
            teleprompter_speed: 1.0,
            auto_advance: true,
            word_highlighting: true
          },
          mobile_config: %{
            simplified_timeline: true,
            gesture_controls: true,
            voice_activation: false,
            large_text_mode: false
          },
          version: 0
        }

        # Update workspace state
        new_workspace_state = Map.put(workspace_state, :audio_text, audio_text_state)

        case Sessions.save_workspace_state(session_id, new_workspace_state) do
          {:ok, _} ->
            # Start audio-text sync engine
            case Frestyl.Studio.AudioTextSyncSupervisor.start_sync_engine(session_id, mode) do
              {:ok, _} -> {:ok, :migrated}
              error -> error
            end

          error ->
            error
        end
    end
  end

  @doc """
  Check if session can be migrated to audio-text format.
  """
  def can_migrate_session?(session_id) do
    case Sessions.get_session(session_id) do
      nil ->
        false

      session ->
        # Check if session has audio or text content
        workspace_state = Sessions.get_workspace_state(session_id)

        has_audio = get_in(workspace_state, [:audio, :tracks]) != []
        has_text = get_in(workspace_state, [:text, :content]) != ""

        has_audio or has_text
    end
  end

  # Private helpers

  defp get_audio_duration(workspace_state) do
    # Try to get duration from audio tracks
    tracks = get_in(workspace_state, [:audio, :tracks]) || []

    case tracks do
      [] -> 0.0
      tracks ->
        # Find longest track duration
        tracks
        |> Enum.map(&get_track_duration/1)
        |> Enum.max(fn -> 0.0 end)
    end
  end

  defp get_track_duration(track) do
    clips = Map.get(track, :clips, [])

    case clips do
      [] -> 0.0
      clips ->
        clips
        |> Enum.map(fn clip ->
          (Map.get(clip, :start_time, 0) + Map.get(clip, :duration, 0))
        end)
        |> Enum.max(fn -> 0.0 end)
    end
  end

  defp migrate_existing_text(workspace_state) do
    # Convert existing text content to blocks
    case get_in(workspace_state, [:text, :content]) do
      nil -> []
      "" -> []
      content ->
        # Split content into paragraphs/blocks
        content
        |> String.split("\n\n", trim: true)
        |> Enum.with_index()
        |> Enum.map(fn {paragraph, index} ->
          %{
            id: "migrated_block_#{index}",
            content: String.trim(paragraph),
            type: detect_block_type(paragraph),
            created_at: DateTime.utc_now(),
            migrated: true
          }
        end)
    end
  end

  defp detect_block_type(content) do
    content_lower = String.downcase(content)

    cond do
      String.contains?(content_lower, ["chorus", "hook"]) -> "chorus"
      String.contains?(content_lower, ["verse"]) -> "verse"
      String.contains?(content_lower, ["bridge"]) -> "bridge"
      String.contains?(content_lower, ["outro", "ending"]) -> "outro"
      String.length(content) < 50 -> "line"
      true -> "paragraph"
    end
  end
end
