# lib/frestyl/narrative_beats.ex
defmodule Frestyl.NarrativeBeats do
  @moduledoc """
  Context for Narrative Beats - musical composition driven by story structure.

  This context handles the business logic for mapping narrative elements to musical elements,
  managing collaborative composition, and integrating with the existing audio engine.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo

  alias Frestyl.NarrativeBeats.{
    Session,
    StoryMusicMapping,
    CharacterInstrument,
    EmotionalProgression,
    MusicalSection,
    CollaborationTrack,
    AIMusicSuggestion,
    NarrativeBeatPattern
  }

  alias Frestyl.Accounts.User
  alias Frestyl.Studio.AudioEngine
  alias Phoenix.PubSub

  # ============================================================================
  # SESSION MANAGEMENT
  # ============================================================================

  @doc """
  Creates a new Narrative Beats session.
  """
  def create_session(attrs, %User{} = user, studio_session_id) do
    session_attrs = Map.merge(attrs, %{
      "session_id" => studio_session_id,
      "created_by_id" => user.id,
      "story_structure" => initialize_story_structure(),
      "musical_structure" => initialize_musical_structure(),
      "collaboration_settings" => initialize_collaboration_settings()
    })

    case %Session{}
         |> Session.changeset(session_attrs)
         |> Repo.insert() do
      {:ok, session} ->
        # Initialize default character instruments and emotional progressions
        initialize_default_mappings(session)

        # Broadcast session created
        broadcast_session_event(session, :session_created)

        {:ok, session}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a Narrative Beats session by ID.
  """
  def get_session!(id) do
    Session
    |> preload([
      :story_music_mappings,
      :character_instruments,
      :emotional_progressions,
      :musical_sections,
      :collaboration_tracks,
      :ai_music_suggestions,
      :narrative_beat_patterns
    ])
    |> Repo.get!(id)
  end

  @doc """
  Gets a session by studio session ID.
  """
  def get_session_by_studio_session(studio_session_id) do
    Session
    |> Session.for_session(studio_session_id)
    |> preload([
      :story_music_mappings,
      :character_instruments,
      :emotional_progressions,
      :musical_sections,
      :collaboration_tracks
    ])
    |> Repo.one()
  end

  @doc """
  Updates a Narrative Beats session.
  """
  def update_session(%Session{} = session, attrs) do
    case session
         |> Session.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_session} ->
        broadcast_session_event(updated_session, :session_updated)
        {:ok, updated_session}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists sessions for a user.
  """
  def list_user_sessions(user_id) do
    Session
    |> Session.for_user(user_id)
    |> order_by([s], desc: s.updated_at)
    |> Repo.all()
  end

  # ============================================================================
  # STORY-TO-MUSIC MAPPING
  # ============================================================================

  @doc """
  Maps a story element to a musical element.
  """
  def create_story_music_mapping(session_id, attrs) do
    attrs = Map.put(attrs, "narrative_beats_session_id", session_id)

    case %StoryMusicMapping{}
         |> StoryMusicMapping.changeset(attrs)
         |> Repo.insert() do
      {:ok, mapping} ->
        # Update musical structure based on new mapping
        update_musical_structure_from_mapping(session_id, mapping)

        broadcast_session_event(session_id, {:mapping_created, mapping})
        {:ok, mapping}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets AI suggestions for chord progressions based on story emotions.
  """
  def suggest_chord_progressions(session_id, emotion, context \\ %{}) do
    # Basic chord progression suggestions based on emotion
    suggestions = case emotion do
      "happy" -> [["C", "Am", "F", "G"], ["G", "Em", "C", "D"]]
      "sad" -> [["Am", "F", "C", "G"], ["Dm", "Bb", "F", "C"]]
      "tense" -> [["F#dim", "G", "Am", "Bb"], ["B7", "Em", "Am", "D"]]
      "triumphant" -> [["C", "F", "Am", "G"], ["D", "G", "Em", "A"]]
      "mysterious" -> [["Am", "Bb", "F", "Dm"], ["Em", "F#dim", "G", "Am"]]
      _ -> [["C", "Am", "F", "G"]] # Default progression
    end

    # Create AI suggestion records
    Enum.map(suggestions, fn progression ->
      create_ai_music_suggestion(session_id, %{
        "suggestion_type" => "chord_progression",
        "context" => Map.merge(context, %{"emotion" => emotion}),
        "suggestion_data" => %{"progression" => progression},
        "confidence_score" => 0.8
      })
    end)
  end

  # ============================================================================
  # CHARACTER INSTRUMENTS
  # ============================================================================

  @doc """
  Assigns an instrument to a character.
  """
  def assign_character_instrument(session_id, attrs) do
    attrs = Map.put(attrs, "narrative_beats_session_id", session_id)

    case %CharacterInstrument{}
         |> CharacterInstrument.changeset(attrs)
         |> Repo.insert() do
      {:ok, character_instrument} ->
        # Create corresponding audio track in audio engine
        create_audio_track_for_character(session_id, character_instrument)

        broadcast_session_event(session_id, {:character_instrument_assigned, character_instrument})
        {:ok, character_instrument}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a character instrument assignment.
  """
  def update_character_instrument(%CharacterInstrument{} = character_instrument, attrs) do
    case character_instrument
         |> CharacterInstrument.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_instrument} ->
        broadcast_session_event(
          updated_instrument.narrative_beats_session_id,
          {:character_instrument_updated, updated_instrument}
        )
        {:ok, updated_instrument}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists all character instruments for a session.
  """
  def list_character_instruments(session_id) do
    CharacterInstrument
    |> where([ci], ci.narrative_beats_session_id == ^session_id)
    |> order_by([ci], ci.track_number)
    |> Repo.all()
  end

  # ============================================================================
  # EMOTIONAL PROGRESSIONS
  # ============================================================================

  @doc """
  Creates an emotional progression mapping.
  """
  def create_emotional_progression(session_id, attrs) do
    attrs = Map.put(attrs, "narrative_beats_session_id", session_id)

    case %EmotionalProgression{}
         |> EmotionalProgression.changeset(attrs)
         |> Repo.insert() do
      {:ok, progression} ->
        broadcast_session_event(session_id, {:emotional_progression_created, progression})
        {:ok, progression}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates an emotional progression.
  """
  def update_emotional_progression(%EmotionalProgression{} = progression, attrs) do
    case progression
         |> EmotionalProgression.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_progression} ->
        broadcast_session_event(
          updated_progression.narrative_beats_session_id,
          {:emotional_progression_updated, updated_progression}
        )
        {:ok, updated_progression}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists emotional progressions for a session.
  """
  def list_emotional_progressions(session_id) do
    EmotionalProgression
    |> where([ep], ep.narrative_beats_session_id == ^session_id)
    |> order_by([ep], ep.emotion_name)
    |> Repo.all()
  end

  # ============================================================================
  # MUSICAL SECTIONS
  # ============================================================================

  @doc """
  Creates a musical section.
  """
  def create_musical_section(session_id, attrs) do
    attrs = Map.put(attrs, "narrative_beats_session_id", session_id)

    case %MusicalSection{}
         |> MusicalSection.changeset(attrs)
         |> Repo.insert() do
      {:ok, section} ->
        broadcast_session_event(session_id, {:musical_section_created, section})
        {:ok, section}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a musical section.
  """
  def update_musical_section(%MusicalSection{} = section, attrs) do
    case section
         |> MusicalSection.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_section} ->
        broadcast_session_event(
          updated_section.narrative_beats_session_id,
          {:musical_section_updated, updated_section}
        )
        {:ok, updated_section}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists musical sections for a session in order.
  """
  def list_musical_sections(session_id) do
    MusicalSection
    |> where([ms], ms.narrative_beats_session_id == ^session_id)
    |> order_by([ms], ms.order_index)
    |> Repo.all()
  end

  @doc """
  Reorders musical sections.
  """
  def reorder_musical_sections(session_id, section_ids) do
    Repo.transaction(fn ->
      section_ids
      |> Enum.with_index()
      |> Enum.each(fn {section_id, index} ->
        from(ms in MusicalSection,
          where: ms.id == ^section_id and ms.narrative_beats_session_id == ^session_id
        )
        |> Repo.update_all(set: [order_index: index])
      end)
    end)

    broadcast_session_event(session_id, {:sections_reordered, section_ids})
    :ok
  end

  # ============================================================================
  # COLLABORATION
  # ============================================================================

  @doc """
  Adds a collaborator to a Narrative Beats session.
  """
  def add_collaborator(session_id, user_id, role, permissions \\ %{}) do
    attrs = %{
      "narrative_beats_session_id" => session_id,
      "user_id" => user_id,
      "role" => role,
      "permissions" => permissions,
      "last_activity_at" => DateTime.utc_now()
    }

    case %CollaborationTrack{}
         |> CollaborationTrack.changeset(attrs)
         |> Repo.insert() do
      {:ok, track} ->
        broadcast_session_event(session_id, {:collaborator_added, track})
        {:ok, track}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates collaborator permissions.
  """
  def update_collaborator_permissions(session_id, user_id, permissions) do
    case get_collaboration_track(session_id, user_id) do
      nil ->
        {:error, :not_found}

      track ->
        update_collaboration_track(track, %{
          "permissions" => permissions,
          "last_activity_at" => DateTime.utc_now()
        })
    end
  end

  @doc """
  Gets collaboration track for a user in a session.
  """
  def get_collaboration_track(session_id, user_id) do
    CollaborationTrack
    |> where([ct], ct.narrative_beats_session_id == ^session_id and ct.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Lists all collaborators for a session.
  """
  def list_collaborators(session_id) do
    CollaborationTrack
    |> where([ct], ct.narrative_beats_session_id == ^session_id)
    |> preload(:user)
    |> order_by([ct], ct.inserted_at)
    |> Repo.all()
  end

  # ============================================================================
  # AI MUSIC SUGGESTIONS
  # ============================================================================

  @doc """
  Creates an AI music suggestion.
  """
  def create_ai_music_suggestion(session_id, attrs) do
    attrs = Map.put(attrs, "narrative_beats_session_id", session_id)

    case %AIMusicSuggestion{}
         |> AIMusicSuggestion.changeset(attrs)
         |> Repo.insert() do
      {:ok, suggestion} ->
        broadcast_session_event(session_id, {:ai_suggestion_created, suggestion})
        {:ok, suggestion}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Accepts an AI music suggestion.
  """
  def accept_ai_suggestion(suggestion_id, user_feedback \\ nil) do
    suggestion = Repo.get!(AIMusicSuggestion, suggestion_id)

    case update_ai_suggestion(suggestion, %{
           "status" => "accepted",
           "feedback" => user_feedback
         }) do
      {:ok, updated_suggestion} ->
        # Apply the suggestion to the session
        apply_ai_suggestion(updated_suggestion)
        {:ok, updated_suggestion}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Rejects an AI music suggestion.
  """
  def reject_ai_suggestion(suggestion_id, user_feedback \\ nil) do
    suggestion = Repo.get!(AIMusicSuggestion, suggestion_id)

    update_ai_suggestion(suggestion, %{
      "status" => "rejected",
      "feedback" => user_feedback
    })
  end

  # ============================================================================
  # BEAT MACHINE INTEGRATION
  # ============================================================================

  @doc """
  Creates a narrative beat pattern.
  """
  def create_narrative_beat_pattern(session_id, attrs) do
    attrs = Map.put(attrs, "narrative_beats_session_id", session_id)

    case %NarrativeBeatPattern{}
         |> NarrativeBeatPattern.changeset(attrs)
         |> Repo.insert() do
      {:ok, pattern} ->
        broadcast_session_event(session_id, {:beat_pattern_created, pattern})
        {:ok, pattern}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Activates a narrative beat pattern.
  """
  def activate_beat_pattern(pattern_id) do
    pattern = Repo.get!(NarrativeBeatPattern, pattern_id)
    session_id = pattern.narrative_beats_session_id

    # Deactivate other patterns first
    from(nbp in NarrativeBeatPattern,
      where: nbp.narrative_beats_session_id == ^session_id
    )
    |> Repo.update_all(set: [is_active: false])

    # Activate this pattern
    case update_narrative_beat_pattern(pattern, %{"is_active" => true}) do
      {:ok, updated_pattern} ->
        # Send pattern to beat machine
        send_pattern_to_beat_machine(session_id, updated_pattern)
        {:ok, updated_pattern}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # ============================================================================
  # EXPORT AND INTEGRATION
  # ============================================================================

  @doc """
  Exports a Narrative Beats session to audio file.
  """
  def export_session(session_id, export_format \\ "wav") do
    session = get_session!(session_id)

    # Generate timeline from musical sections
    timeline = generate_export_timeline(session)

    # Render audio using audio engine
    case AudioEngine.render_timeline(session.session_id, timeline, export_format) do
      {:ok, audio_file_path} ->
        # Update session with export info
        update_session(session, %{
          "export_settings" => Map.put(session.export_settings, "last_export", %{
            "format" => export_format,
            "exported_at" => DateTime.utc_now(),
            "file_path" => audio_file_path
          })
        })

        {:ok, audio_file_path}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Syncs Narrative Beats session with story timeline.
  """
  def sync_with_story_timeline(session_id, story_data) do
    session = get_session!(session_id)

    # Update story structure
    updated_story_structure = merge_story_data(session.story_structure, story_data)

    # Regenerate musical mappings based on updated story
    regenerate_musical_mappings(session_id, updated_story_structure)

    # Update session
    update_session(session, %{"story_structure" => updated_story_structure})
  end

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp initialize_story_structure do
    %{
      "characters" => [],
      "plot_points" => [],
      "emotional_arc" => [],
      "themes" => [],
      "setting" => %{}
    }
  end

  defp initialize_musical_structure do
    %{
      "sections" => [],
      "key_changes" => [],
      "tempo_changes" => [],
      "instrumentation" => %{},
      "arrangement" => %{}
    }
  end

  defp initialize_collaboration_settings do
    %{
      "real_time_editing" => true,
      "permission_model" => "role_based",
      "notifications" => true,
      "version_control" => true
    }
  end

  defp initialize_default_mappings(%Session{} = session) do
    # Create default emotional progressions
    default_emotions = [
      %{emotion: "happy", progression: ["C", "Am", "F", "G"], type: "major"},
      %{emotion: "sad", progression: ["Am", "F", "C", "G"], type: "minor"},
      %{emotion: "tense", progression: ["F#dim", "G", "Am", "Bb"], type: "diminished"},
      %{emotion: "peaceful", progression: ["C", "F", "Am", "G"], type: "major"}
    ]

    Enum.each(default_emotions, fn emotion_data ->
      create_emotional_progression(session.id, %{
        "emotion_name" => emotion_data.emotion,
        "chord_progression" => emotion_data.progression,
        "progression_type" => emotion_data.type,
        "tension_level" => case emotion_data.emotion do
          "tense" -> 0.8
          "sad" -> 0.6
          "happy" -> 0.3
          "peaceful" -> 0.1
        end
      })
    end)
  end

  defp update_musical_structure_from_mapping(_session_id, _mapping) do
    # TODO: Implement logic to update musical structure when mappings change
    :ok
  end

  defp create_audio_track_for_character(session_id, character_instrument) do
    # Get the studio session ID
    session = Repo.get!(Session, character_instrument.narrative_beats_session_id)

    # Create audio track in audio engine
    track_params = %{
      name: "#{character_instrument.character_name} (#{character_instrument.instrument_type})",
      instrument_type: character_instrument.instrument_type,
      track_number: character_instrument.track_number,
      character_data: character_instrument.character_data
    }

    AudioEngine.add_track(session.session_id, :narrative_beats, track_params)
  end

  defp update_collaboration_track(%CollaborationTrack{} = track, attrs) do
    case track
         |> CollaborationTrack.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_track} ->
        broadcast_session_event(
          updated_track.narrative_beats_session_id,
          {:collaboration_track_updated, updated_track}
        )
        {:ok, updated_track}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp update_ai_suggestion(%AIMusicSuggestion{} = suggestion, attrs) do
    suggestion
    |> AIMusicSuggestion.changeset(attrs)
    |> Repo.update()
  end

  defp apply_ai_suggestion(%AIMusicSuggestion{} = suggestion) do
    case suggestion.suggestion_type do
      "chord_progression" ->
        apply_chord_progression_suggestion(suggestion)

      "melody" ->
        apply_melody_suggestion(suggestion)

      "rhythm" ->
        apply_rhythm_suggestion(suggestion)

      "arrangement" ->
        apply_arrangement_suggestion(suggestion)

      _ ->
        :ok
    end
  end

  defp apply_chord_progression_suggestion(suggestion) do
    # Create emotional progression from AI suggestion
    create_emotional_progression(suggestion.narrative_beats_session_id, %{
      "emotion_name" => get_in(suggestion.context, ["emotion"]) || "ai_suggested",
      "chord_progression" => get_in(suggestion.suggestion_data, ["progression"]),
      "progression_type" => "ai_generated",
      "tension_level" => suggestion.confidence_score
    })
  end

  defp apply_melody_suggestion(_suggestion) do
    # TODO: Implement melody application
    :ok
  end

  defp apply_rhythm_suggestion(_suggestion) do
    # TODO: Implement rhythm application
    :ok
  end

  defp apply_arrangement_suggestion(_suggestion) do
    # TODO: Implement arrangement application
    :ok
  end

  defp update_narrative_beat_pattern(%NarrativeBeatPattern{} = pattern, attrs) do
    pattern
    |> NarrativeBeatPattern.changeset(attrs)
    |> Repo.update()
  end

  defp send_pattern_to_beat_machine(session_id, pattern) do
    # Get the studio session
    session = get_session_by_studio_session(session_id)

    if session do
      # Send pattern data to beat machine
      Frestyl.Studio.BeatMachine.load_narrative_pattern(
        session.session_id,
        pattern.pattern_data
      )
    end
  end

  defp generate_export_timeline(session) do
    sections = list_musical_sections(session.id)

    Enum.map(sections, fn section ->
      %{
        start_time: section.start_time,
        duration: section.duration,
        content: section.musical_content,
        arrangement: section.arrangement
      }
    end)
  end

  defp merge_story_data(current_structure, new_story_data) do
    Map.merge(current_structure, new_story_data)
  end

  defp regenerate_musical_mappings(_session_id, _updated_story_structure) do
    # TODO: Implement logic to regenerate mappings when story changes
    :ok
  end

  defp broadcast_session_event(session_id, event) when is_binary(session_id) do
    PubSub.broadcast(Frestyl.PubSub, "narrative_beats:#{session_id}", event)
  end

  defp broadcast_session_event(%Session{} = session, event) do
    broadcast_session_event(session.id, event)
  end
end
