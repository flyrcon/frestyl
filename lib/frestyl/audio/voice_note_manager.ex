# lib/frestyl/audio/voice_note_manager.ex
defmodule Frestyl.Audio.VoiceNoteManager do
  @moduledoc """
  Manages voice notes for story development including recording, transcription,
  organization, and integration with story content.
  """

  require Logger
  import Ecto.Query, warn: false
  alias Frestyl.{Stories, Repo}
  alias Frestyl.Audio.{Transcription, AudioProcessor}
  alias Phoenix.PubSub

  @doc """
  Processes a recorded voice note from the frontend.
  """
  def process_voice_note(audio_data, context) do
    with {:ok, audio_file_path} <- save_audio_file(audio_data, context),
         {:ok, voice_note} <- create_voice_note_record(audio_file_path, context),
         :ok <- start_transcription_async(voice_note) do

      # Broadcast voice note creation
      broadcast_voice_note_event(voice_note, :created)

      {:ok, voice_note}
    else
      {:error, reason} ->
        Logger.error("Failed to process voice note: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Saves audio data to file system or cloud storage.
  """
  def save_audio_file(base64_audio_data, context) do
    try do
      # Decode base64 audio data
      audio_binary = Base.decode64!(base64_audio_data)

      # Generate unique filename
      file_extension = get_file_extension(context["mime_type"])
      filename = generate_audio_filename(context, file_extension)

      # Determine storage path
      storage_path = get_audio_storage_path()
      file_path = Path.join(storage_path, filename)

      # Ensure directory exists
      File.mkdir_p!(storage_path)

      # Write audio file
      case File.write(file_path, audio_binary) do
        :ok ->
          Logger.info("Audio file saved: #{file_path}")
          {:ok, file_path}
        {:error, reason} ->
          {:error, "Failed to save audio file: #{reason}"}
      end

    rescue
      error ->
        Logger.error("Error saving audio file: #{inspect(error)}")
        {:error, "Audio file processing failed"}
    end
  end

  @doc """
  Creates a voice note database record.
  """
  def create_voice_note_record(audio_file_path, context) do
    voice_note_params = %{
      id: Ecto.UUID.generate(),
      story_id: context["story_id"],
      section_id: context["section_id"],
      user_id: context["user_id"],
      audio_file_path: audio_file_path,
      duration_seconds: round(context["duration"] || 0),
      processing_status: "pending",
      metadata: %{
        mime_type: context["mime_type"],
        file_size: context["file_size"],
        recorded_at: context["timestamp"],
        device_type: get_device_type(context)
      },
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    # For now, store in story metadata (would use proper Ecto schema in production)
    case Stories.get_enhanced_story(context["story_id"]) do
      nil -> {:error, "Story not found"}
      story ->
        current_voice_notes = Map.get(story, :voice_notes_data, [])
        updated_voice_notes = [voice_note_params | current_voice_notes]

        case Stories.update_enhanced_story(story, %{"voice_notes_data" => updated_voice_notes}) do
          {:ok, _updated_story} -> {:ok, voice_note_params}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Starts asynchronous transcription of voice note.
  """
  def start_transcription_async(voice_note) do
    # Start transcription task
    Task.start(fn ->
      case transcribe_voice_note(voice_note) do
        {:ok, transcription} ->
          update_voice_note_transcription(voice_note.id, transcription)
          broadcast_voice_note_event(voice_note, :transcribed, %{transcription: transcription})

        {:error, reason} ->
          Logger.error("Transcription failed for voice note #{voice_note.id}: #{reason}")
          update_voice_note_status(voice_note.id, "transcription_failed")
      end
    end)

    :ok
  end

  @doc """
  Transcribes audio using speech-to-text service.
  """
  def transcribe_voice_note(voice_note) do
    audio_file_path = voice_note.audio_file_path

    case File.exists?(audio_file_path) do
      true ->
        case Transcription.transcribe_audio_file(audio_file_path) do
          {:ok, transcription_text} ->
            {:ok, clean_transcription(transcription_text)}

          {:error, reason} ->
            {:error, "Transcription service error: #{reason}"}
        end

      false ->
        {:error, "Audio file not found: #{audio_file_path}"}
    end
  end

  @doc """
  Updates voice note with transcription results.
  """
  def update_voice_note_transcription(voice_note_id, transcription) do
    # Find and update the voice note in story data
    case find_voice_note_by_id(voice_note_id) do
      {story, voice_note} ->
        updated_voice_note = %{voice_note |
          transcription: transcription,
          processing_status: "completed",
          updated_at: DateTime.utc_now()
        }

        updated_voice_notes = update_voice_note_in_list(
          story.voice_notes_data,
          voice_note_id,
          updated_voice_note
        )

        Stories.update_enhanced_story(story, %{"voice_notes_data" => updated_voice_notes})

      nil ->
        Logger.error("Voice note not found: #{voice_note_id}")
        {:error, "Voice note not found"}
    end
  end

  @doc """
  Organizes voice notes by story section.
  """
  def organize_voice_notes_by_section(story_id) do
    case Stories.get_enhanced_story(story_id) do
      nil -> {:error, "Story not found"}
      story ->
        voice_notes = Map.get(story, :voice_notes_data, [])

        organized_notes = voice_notes
        |> Enum.group_by(& &1.section_id)
        |> Enum.map(fn {section_id, notes} ->
          %{
            section_id: section_id,
            section_title: get_section_title(story, section_id),
            voice_notes: Enum.sort_by(notes, & &1.created_at, {:desc, DateTime})
          }
        end)

        {:ok, organized_notes}
    end
  end

  @doc """
  Adds voice note transcription to story content.
  """
  def add_voice_note_to_story_content(voice_note_id, section_id, insertion_mode \\ :append) do
    case find_voice_note_by_id(voice_note_id) do
      {story, voice_note} ->
        case voice_note.transcription do
          nil -> {:error, "Voice note not yet transcribed"}
          transcription ->
            case get_section_by_id(story, section_id) do
              nil -> {:error, "Section not found"}
              section ->
                updated_content = insert_transcription_into_content(
                  section.content,
                  transcription,
                  insertion_mode
                )

                case Stories.update_section_content(section_id, updated_content) do
                  {:ok, updated_section} ->
                    # Mark voice note as integrated
                    mark_voice_note_integrated(voice_note_id)
                    {:ok, updated_section}

                  {:error, reason} -> {:error, reason}
                end
            end
        end

      nil -> {:error, "Voice note not found"}
    end
  end

  @doc """
  Gets voice notes for a specific story section.
  """
  def get_section_voice_notes(story_id, section_id) do
    case Stories.get_enhanced_story(story_id) do
      nil -> {:error, "Story not found"}
      story ->
        voice_notes = Map.get(story, :voice_notes_data, [])

        section_notes = voice_notes
        |> Enum.filter(& &1.section_id == section_id)
        |> Enum.sort_by(& &1.created_at, {:desc, DateTime})

        {:ok, section_notes}
    end
  end

  @doc """
  Generates audio summary/narration for a story section.
  """
  def generate_section_narration(story_id, section_id, narrator_voice \\ "default") do
    case get_section_by_id_from_story(story_id, section_id) do
      nil -> {:error, "Section not found"}
      section ->
        # Use text-to-speech to generate narration
        case AudioProcessor.text_to_speech(section.content, narrator_voice) do
          {:ok, audio_file_path} ->
            # Create narration voice note
            narration_params = %{
              story_id: story_id,
              section_id: section_id,
              user_id: nil, # System generated
              audio_file_path: audio_file_path,
              transcription: section.content,
              processing_status: "completed",
              metadata: %{
                type: "narration",
                narrator_voice: narrator_voice,
                generated_at: DateTime.utc_now()
              }
            }

            create_voice_note_record(audio_file_path, narration_params)

          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Syncs offline voice notes from mobile devices.
  """
  def sync_offline_voice_note(offline_voice_note_data) do
    context = %{
      "story_id" => offline_voice_note_data["context"]["story_id"],
      "section_id" => offline_voice_note_data["context"]["section_id"],
      "user_id" => offline_voice_note_data["context"]["user_id"],
      "duration" => offline_voice_note_data["duration"],
      "mime_type" => offline_voice_note_data["mime_type"],
      "file_size" => offline_voice_note_data["file_size"],
      "timestamp" => offline_voice_note_data["timestamp"]
    }

    case process_voice_note(offline_voice_note_data["audio_data"], context) do
      {:ok, voice_note} ->
        # Notify successful sync
        broadcast_offline_sync_event(voice_note, offline_voice_note_data["offline_id"])
        {:ok, voice_note}

      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes a voice note and its associated audio file.
  """
  def delete_voice_note(voice_note_id) do
    case find_voice_note_by_id(voice_note_id) do
      {story, voice_note} ->
        # Delete audio file
        if File.exists?(voice_note.audio_file_path) do
          File.rm(voice_note.audio_file_path)
        end

        # Remove from story data
        updated_voice_notes = Enum.reject(story.voice_notes_data, & &1.id == voice_note_id)

        case Stories.update_enhanced_story(story, %{"voice_notes_data" => updated_voice_notes}) do
          {:ok, _updated_story} ->
            broadcast_voice_note_event(voice_note, :deleted)
            {:ok, voice_note}

          {:error, reason} -> {:error, reason}
        end

      nil -> {:error, "Voice note not found"}
    end
  end

  @doc """
  Gets all voice notes for a story.
  """
  def get_story_voice_notes(story_id) do
    case Stories.get_enhanced_story(story_id) do
      nil -> {:error, "Story not found"}
      story ->
        voice_notes = Map.get(story, :voice_notes_data, [])
        sorted_notes = Enum.sort_by(voice_notes, & &1.created_at, {:desc, DateTime})
        {:ok, sorted_notes}
    end
  end

  @doc """
  Searches voice notes by transcription content.
  """
  def search_voice_notes(story_id, search_term) do
    case get_story_voice_notes(story_id) do
      {:ok, voice_notes} ->
        matching_notes = voice_notes
        |> Enum.filter(fn note ->
          note.transcription &&
          String.contains?(String.downcase(note.transcription), String.downcase(search_term))
        end)

        {:ok, matching_notes}

      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets voice note statistics for a story.
  """
  def get_voice_note_stats(story_id) do
    case get_story_voice_notes(story_id) do
      {:ok, voice_notes} ->
        total_count = length(voice_notes)
        total_duration = Enum.sum(Enum.map(voice_notes, & &1.duration_seconds))
        transcribed_count = Enum.count(voice_notes, & &1.transcription != nil)

        stats = %{
          total_count: total_count,
          total_duration_seconds: total_duration,
          total_duration_formatted: format_duration(total_duration),
          transcribed_count: transcribed_count,
          transcription_percentage: if(total_count > 0, do: round(transcribed_count / total_count * 100), else: 0)
        }

        {:ok, stats}

      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp get_file_extension(mime_type) do
    case mime_type do
      "audio/webm" -> ".webm"
      "audio/mp4" -> ".m4a"
      "audio/ogg" -> ".ogg"
      "audio/wav" -> ".wav"
      _ -> ".webm" # Default
    end
  end

  defp generate_audio_filename(context, extension) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    story_id = String.slice(context["story_id"] || "unknown", 0, 8)
    user_id = String.slice(context["user_id"] || "unknown", 0, 8)

    "voice_note_#{story_id}_#{user_id}_#{timestamp}#{extension}"
  end

  defp get_audio_storage_path do
    # Configure based on environment
    case Application.get_env(:frestyl, :audio_storage) do
      %{type: :local, path: path} -> path
      %{type: :s3} -> "/tmp/voice_notes" # Temporary local storage before S3 upload
      _ -> "/tmp/voice_notes" # Default
    end
  end

  defp get_device_type(context) do
    cond do
      context["is_mobile"] -> "mobile"
      context["device_type"] -> context["device_type"]
      true -> "unknown"
    end
  end

  defp clean_transcription(raw_transcription) do
    raw_transcription
    |> String.trim()
    |> String.replace(~r/\s+/, " ") # Normalize whitespace
    |> String.capitalize() # Capitalize first letter
  end

  defp find_voice_note_by_id(voice_note_id) do
    # Search through all stories to find the voice note
    # In production, this would be a proper database query
    # For now, implement a simple search through stories with voice notes

    # Note: This is a temporary implementation using JSON queries
    # Replace with proper VoiceNotes schema when implemented
    try do
      query = from(s in "enhanced_story_structures",
                   where: not is_nil(s.voice_notes_data),
                   select: s)

      stories = Repo.all(query)

      Enum.find_value(stories, fn story ->
        case Enum.find(story.voice_notes_data || [], & &1.id == voice_note_id) do
          nil -> nil
          voice_note -> {story, voice_note}
        end
      end)
    rescue
      error ->
        Logger.error("Error finding voice note: #{inspect(error)}")
        nil
    end
  end

  defp update_voice_note_in_list(voice_notes_list, voice_note_id, updated_voice_note) do
    Enum.map(voice_notes_list, fn voice_note ->
      if voice_note.id == voice_note_id do
        updated_voice_note
      else
        voice_note
      end
    end)
  end

  defp get_section_title(story, section_id) do
    case get_section_by_id(story, section_id) do
      nil -> "Unknown Section"
      section -> section.title
    end
  end

  defp get_section_by_id(story, section_id) do
    Enum.find(story.sections || [], & &1.id == section_id)
  end

  defp get_section_by_id_from_story(story_id, section_id) do
    case Stories.get_enhanced_story(story_id) do
      nil -> nil
      story -> get_section_by_id(story, section_id)
    end
  end

  defp insert_transcription_into_content(existing_content, transcription, insertion_mode) do
    case insertion_mode do
      :append ->
        if String.trim(existing_content) == "" do
          transcription
        else
          existing_content <> "\n\n" <> transcription
        end

      :prepend ->
        if String.trim(existing_content) == "" do
          transcription
        else
          transcription <> "\n\n" <> existing_content
        end

      :replace ->
        transcription
    end
  end

  defp mark_voice_note_integrated(voice_note_id) do
    case find_voice_note_by_id(voice_note_id) do
      {story, voice_note} ->
        updated_voice_note = %{voice_note |
          metadata: Map.put(voice_note.metadata, "integrated_at", DateTime.utc_now())
        }

        updated_voice_notes = update_voice_note_in_list(
          story.voice_notes_data,
          voice_note_id,
          updated_voice_note
        )

        Stories.update_enhanced_story(story, %{"voice_notes_data" => updated_voice_notes})

      nil -> {:error, "Voice note not found"}
    end
  end

  defp update_voice_note_status(voice_note_id, status) do
    case find_voice_note_by_id(voice_note_id) do
      {story, voice_note} ->
        updated_voice_note = %{voice_note |
          processing_status: status,
          updated_at: DateTime.utc_now()
        }

        updated_voice_notes = update_voice_note_in_list(
          story.voice_notes_data,
          voice_note_id,
          updated_voice_note
        )

        Stories.update_enhanced_story(story, %{"voice_notes_data" => updated_voice_notes})

      nil -> {:error, "Voice note not found"}
    end
  end

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end

  defp broadcast_voice_note_event(voice_note, event_type, extra_data \\ %{}) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "story:#{voice_note.story_id}",
      {String.to_atom("voice_note_#{event_type}"), voice_note, extra_data}
    )

    # Also broadcast to story collaboration channel if exists
    PubSub.broadcast(
      Frestyl.PubSub,
      "story_collaboration:#{voice_note.story_id}",
      {String.to_atom("voice_note_#{event_type}"), voice_note, extra_data}
    )
  end

  defp broadcast_offline_sync_event(voice_note, offline_id) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "user:#{voice_note.user_id}",
      {:offline_voice_note_synced, offline_id, voice_note}
    )
  end
end
