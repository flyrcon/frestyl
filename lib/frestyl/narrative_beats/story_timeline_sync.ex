# lib/frestyl/narrative_beats/story_timeline_sync.ex
defmodule Frestyl.NarrativeBeats.StoryTimelineSync do
  @moduledoc """
  Handles synchronization between story timeline and musical timeline.
  """

  alias Frestyl.NarrativeBeats
  alias Frestyl.Stories.EnhancedStoryStructure

  @doc """
  Syncs a story's timeline with its Narrative Beats session.
  """
  def sync_story_with_music(story_id, narrative_beats_session_id) do
    with {:ok, story} <- get_story(story_id),
         {:ok, session} <- get_narrative_beats_session(narrative_beats_session_id) do

      # Extract story elements
      story_timeline = extract_story_timeline(story)

      # Create musical mappings based on story structure
      create_musical_mappings(session, story_timeline)

      # Update session with story sync data
      NarrativeBeats.update_session(session, %{
        "story_structure" => Map.merge(session.story_structure, %{
          "synced_story_id" => story_id,
          "last_sync_at" => DateTime.utc_now(),
          "timeline" => story_timeline
        })
      })
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates musical sections based on story plot points.
  """
  def generate_sections_from_plot_points(session_id, plot_points) do
    Enum.with_index(plot_points, fn plot_point, index ->
      section_type = determine_section_type(plot_point, index, length(plot_points))

      NarrativeBeats.create_musical_section(session_id, %{
        "section_name" => plot_point.name || "Section #{index + 1}",
        "section_type" => section_type,
        "plot_point" => plot_point.description,
        "order_index" => index,
        "duration" => calculate_section_duration(plot_point),
        "musical_content" => generate_musical_content_for_plot_point(plot_point)
      })
    end)
  end

  @doc """
  Updates musical intensity based on story tension curve.
  """
  def update_musical_intensity(session_id, tension_curve) do
    # Get all musical sections
    sections = NarrativeBeats.list_musical_sections(session_id)

    # Update each section based on tension curve
    Enum.each(sections, fn section ->
      tension_at_position = get_tension_at_position(tension_curve, section.start_time)

      updated_arrangement = Map.merge(section.arrangement, %{
        "intensity" => tension_at_position,
        "dynamics" => tension_to_dynamics(tension_at_position),
        "instrumentation_density" => tension_to_density(tension_at_position)
      })

      NarrativeBeats.update_musical_section(section, %{
        "arrangement" => updated_arrangement
      })
    end)
  end

  # Private functions

  defp get_story(story_id) do
    case Frestyl.Repo.get(EnhancedStoryStructure, story_id) do
      nil -> {:error, :story_not_found}
      story -> {:ok, story}
    end
  end

  defp get_narrative_beats_session(session_id) do
    case NarrativeBeats.get_session!(session_id) do
      nil -> {:error, :session_not_found}
      session -> {:ok, session}
    end
  end

  defp extract_story_timeline(story) do
    %{
      "characters" => extract_characters(story.character_data),
      "plot_points" => extract_plot_points(story.outline),
      "emotional_arc" => extract_emotional_arc(story.sections),
      "themes" => extract_themes(story.content)
    }
  end

  defp extract_characters(character_data) do
    case character_data do
      %{"characters" => characters} when is_list(characters) ->
        Enum.map(characters, fn character ->
          %{
            "name" => character["name"],
            "role" => character["role"] || "supporting",
            "emotional_range" => character["personality"] || %{},
            "story_importance" => calculate_story_importance(character)
          }
        end)
      _ -> []
    end
  end

  defp extract_plot_points(outline) do
    case outline do
      %{"sections" => sections} when is_list(sections) ->
        Enum.map(sections, fn section ->
          %{
            "name" => section["title"],
            "description" => section["content"] || section["summary"],
            "emotional_weight" => section["emotional_intensity"] || 0.5,
            "tension_level" => section["tension"] || 0.5
          }
        end)
      _ -> []
    end
  end

  defp extract_emotional_arc(sections) do
    case sections do
      sections when is_list(sections) ->
        Enum.map(sections, fn section ->
          %{
            "emotion" => section["mood"] || "neutral",
            "intensity" => section["emotional_intensity"] || 0.5,
            "duration" => section["estimated_duration"] || 1.0
          }
        end)
      _ -> []
    end
  end

  defp extract_themes(content) do
    # Simple theme extraction - in a real implementation this would use NLP
    default_themes = ["adventure", "romance", "conflict", "resolution"]

    case content do
      %{"themes" => themes} when is_list(themes) -> themes
      _ -> default_themes
    end
  end

  defp create_musical_mappings(session, story_timeline) do
    # Create character-to-instrument mappings
    story_timeline["characters"]
    |> Enum.with_index()
    |> Enum.each(fn {character, index} ->
      instrument = assign_instrument_to_character(character, index)

      NarrativeBeats.assign_character_instrument(session.id, %{
        "character_name" => character["name"],
        "instrument_type" => instrument,
        "track_number" => index + 1,
        "character_data" => character,
        "emotional_range" => character["emotional_range"]
      })
    end)

    # Create emotion-to-progression mappings
    story_timeline["emotional_arc"]
    |> Enum.uniq_by(fn emotion -> emotion["emotion"] end)
    |> Enum.each(fn emotion_data ->
      progression = generate_progression_for_emotion(emotion_data["emotion"])

      NarrativeBeats.create_emotional_progression(session.id, %{
        "emotion_name" => emotion_data["emotion"],
        "chord_progression" => progression.chords,
        "progression_type" => progression.type,
        "tension_level" => emotion_data["intensity"]
      })
    end)
  end

  defp determine_section_type(plot_point, index, total_sections) do
    cond do
      index == 0 -> "intro"
      index == total_sections - 1 -> "outro"
      plot_point.tension_level > 0.7 -> "climax"
      rem(index, 2) == 0 -> "verse"
      true -> "bridge"
    end
  end

  defp calculate_section_duration(plot_point) do
    base_duration = 16.0 # bars

    intensity_multiplier = plot_point.emotional_weight || 0.5
    base_duration * (0.5 + intensity_multiplier)
  end

  defp generate_musical_content_for_plot_point(plot_point) do
    %{
      "emotion" => plot_point.emotion || "neutral",
      "energy_level" => plot_point.tension_level || 0.5,
      "recommended_tempo" => tension_to_tempo(plot_point.tension_level || 0.5),
      "key_modulation" => should_modulate_key?(plot_point)
    }
  end

  defp calculate_story_importance(character) do
    # Simple heuristic - main characters get higher importance
    case character["role"] do
      "protagonist" -> 1.0
      "antagonist" -> 0.9
      "supporting" -> 0.6
      "background" -> 0.3
      _ -> 0.5
    end
  end

  defp assign_instrument_to_character(character, index) do
    # Assign instruments based on character role and story importance
    importance = character["story_importance"] || 0.5
    role = character["role"] || "supporting"

    cond do
      role == "protagonist" -> "piano"
      role == "antagonist" -> "synthesizer"
      importance > 0.8 -> "violin"
      importance > 0.6 -> "guitar"
      importance > 0.4 -> "flute"
      true -> "harp"
    end
  end

  defp generate_progression_for_emotion(emotion) do
    case emotion do
      "happy" -> %{chords: ["C", "Am", "F", "G"], type: "major"}
      "sad" -> %{chords: ["Am", "F", "C", "G"], type: "minor"}
      "tense" -> %{chords: ["F#dim", "G", "Am", "Bb"], type: "diminished"}
      "triumphant" -> %{chords: ["C", "F", "Am", "G"], type: "major"}
      "mysterious" -> %{chords: ["Am", "Bb", "F", "Dm"], type: "modal"}
      "peaceful" -> %{chords: ["C", "F", "G", "C"], type: "major"}
      _ -> %{chords: ["C", "Am", "F", "G"], type: "major"}
    end
  end

  defp get_tension_at_position(tension_curve, position) do
    # Interpolate tension value at given position
    case tension_curve do
      points when is_list(points) ->
        # Find the two points that bracket our position
        case find_bracketing_points(points, position) do
          {point1, point2} -> interpolate_tension(point1, point2, position)
          single_point -> single_point.tension || 0.5
        end
      _ -> 0.5 # Default tension
    end
  end

  defp find_bracketing_points(points, position) do
    sorted_points = Enum.sort_by(points, & &1.position)

    case Enum.find_index(sorted_points, fn point -> point.position > position end) do
      nil -> List.last(sorted_points) # Position is after all points
      0 -> List.first(sorted_points) # Position is before all points
      index -> {Enum.at(sorted_points, index - 1), Enum.at(sorted_points, index)}
    end
  end

  defp interpolate_tension(point1, point2, position) do
    # Linear interpolation between two tension points
    ratio = (position - point1.position) / (point2.position - point1.position)
    point1.tension + ratio * (point2.tension - point1.tension)
  end

  defp tension_to_dynamics(tension) do
    cond do
      tension >= 0.9 -> "fff" # Very loud
      tension >= 0.7 -> "ff"  # Loud
      tension >= 0.5 -> "f"   # Medium loud
      tension >= 0.3 -> "mf"  # Medium
      tension >= 0.1 -> "mp"  # Medium soft
      true -> "p"             # Soft
    end
  end

  defp tension_to_density(tension) do
    # Higher tension = more instruments playing
    cond do
      tension >= 0.8 -> "full"     # All instruments
      tension >= 0.6 -> "heavy"    # Most instruments
      tension >= 0.4 -> "medium"   # Some instruments
      tension >= 0.2 -> "light"    # Few instruments
      true -> "minimal"            # Very few instruments
    end
  end

  defp tension_to_tempo(tension) do
    # Higher tension generally means faster tempo
    base_tempo = 120
    tempo_variation = tension * 40 # ±40 BPM based on tension
    round(base_tempo + tempo_variation - 20) # Center around base tempo
  end

  defp should_modulate_key?(plot_point) do
    # Modulate key for high-tension or climactic moments
    (plot_point.tension_level || 0) > 0.7
  end
end
