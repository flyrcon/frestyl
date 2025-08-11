# lib/frestyl/story_engine/collaboration_modes.ex
defmodule Frestyl.StoryEngine.CollaborationModes do
  @moduledoc """
  Enhanced collaboration modes supporting Frestyl Originals and traditional story types
  """

  @collaboration_modes %{
    # Traditional Story Types
    "narrative_workshop" => %{
      description: "Collaborative novel/screenplay development",
      story_types: ["novel", "screenplay", "short_story"],
      primary_tools: ["story_editor", "character_sheets", "plot_tracker", "chat"],
      secondary_tools: ["voice_notes", "timeline", "world_building"],
      audio_features: ["voice_notes", "narration_sync", "character_voices"],
      mobile_optimized: true,
      session_type: "story_development",
      default_layout: %{
        desktop: %{
          left_dock: ["story_editor"],
          right_dock: ["chat", "character_sheets"],
          bottom_dock: ["voice_notes"],
          floating: [],
          minimized: ["plot_tracker", "world_building"]
        },
        mobile: %{
          primary_view: "story_editor",
          quick_access: ["voice_notes", "chat", "character_sheets"],
          bottom_sheet: ["plot_tracker"]
        }
      }
    },

    "business_workflow" => %{
      description: "Professional case study and report collaboration",
      story_types: ["case_study", "data_story", "report", "white_paper"],
      primary_tools: ["document_editor", "data_panels", "stakeholder_chat"],
      secondary_tools: ["voice_notes", "presentation_mode", "version_control"],
      audio_features: ["executive_summaries", "voice_annotations"],
      mobile_optimized: true,
      session_type: "business_collaboration",
      default_layout: %{
        desktop: %{
          left_dock: ["document_editor"],
          right_dock: ["stakeholder_chat", "data_panels"],
          bottom_dock: ["voice_notes"],
          floating: [],
          minimized: ["presentation_mode"]
        },
        mobile: %{
          primary_view: "document_editor",
          quick_access: ["voice_notes", "stakeholder_chat"],
          bottom_sheet: ["data_panels"]
        }
      }
    },

    # Frestyl Originals - Audio-Enhanced Story Types
    "live_story_session" => %{
      description: "Real-time collaborative storytelling with live audience",
      story_types: ["live_story"],
      primary_tools: ["live_editor", "audience_interaction", "story_branching"],
      secondary_tools: ["chat", "voting_system", "narrator_tools"],
      audio_features: ["live_narration", "audience_audio", "story_soundtrack"],
      mobile_optimized: true,
      session_type: "live_performance",
      special_features: ["audience_voting", "real_time_branching", "live_streaming"],
      default_layout: %{
        desktop: %{
          left_dock: ["live_editor", "story_branching"],
          right_dock: ["audience_interaction", "chat"],
          bottom_dock: ["narrator_tools"],
          floating: ["voting_system"],
          minimized: []
        },
        mobile: %{
          primary_view: "live_editor",
          quick_access: ["narrator_tools", "audience_interaction"],
          bottom_sheet: ["story_branching", "voting_system"]
        }
      }
    },

    "voice_sketch_studio" => %{
      description: "Voice narration with synchronized drawing/sketching",
      story_types: ["voice_sketch"],
      primary_tools: ["sketch_canvas", "voice_recorder", "timeline_sync"],
      secondary_tools: ["drawing_tools", "audio_effects", "export_tools"],
      audio_features: ["voice_sync", "background_music", "audio_effects"],
      mobile_optimized: true,
      session_type: "multimedia_creation",
      special_features: ["audio_visual_sync", "gesture_recording", "sketch_timeline"],
      default_layout: %{
        desktop: %{
          left_dock: ["sketch_canvas"],
          right_dock: ["voice_recorder", "drawing_tools"],
          bottom_dock: ["timeline_sync"],
          floating: [],
          minimized: ["audio_effects", "export_tools"]
        },
        mobile: %{
          primary_view: "sketch_canvas",
          quick_access: ["voice_recorder", "drawing_tools"],
          bottom_sheet: ["timeline_sync"]
        }
      }
    },

    "audio_portfolio_builder" => %{
      description: "Interactive audio-first portfolio creation",
      story_types: ["audio_portfolio"],
      primary_tools: ["spatial_audio_editor", "portfolio_navigator", "audio_mixer"],
      secondary_tools: ["chat", "visitor_analytics", "export_tools"],
      audio_features: ["spatial_audio", "ambient_soundscapes", "voice_guides"],
      mobile_optimized: true,
      session_type: "portfolio_development",
      special_features: ["3d_audio_navigation", "visitor_tracking", "audio_analytics"],
      default_layout: %{
        desktop: %{
          left_dock: ["spatial_audio_editor"],
          right_dock: ["portfolio_navigator", "visitor_analytics"],
          bottom_dock: ["audio_mixer"],
          floating: [],
          minimized: ["chat", "export_tools"]
        },
        mobile: %{
          primary_view: "spatial_audio_editor",
          quick_access: ["audio_mixer", "portfolio_navigator"],
          bottom_sheet: ["visitor_analytics"]
        }
      }
    },

    "data_jam_session" => %{
      description: "Collaborative data storytelling with live analysis",
      story_types: ["data_jam"],
      primary_tools: ["data_visualizer", "collaborative_editor", "insight_tracker"],
      secondary_tools: ["chat", "data_sources", "presentation_mode"],
      audio_features: ["insight_narration", "data_sonification"],
      mobile_optimized: true,
      session_type: "data_collaboration",
      special_features: ["real_time_analysis", "collaborative_insights", "data_sonification"],
      default_layout: %{
        desktop: %{
          left_dock: ["data_visualizer"],
          right_dock: ["chat", "insight_tracker"],
          bottom_dock: ["collaborative_editor"],
          floating: [],
          minimized: ["data_sources", "presentation_mode"]
        },
        mobile: %{
          primary_view: "data_visualizer",
          quick_access: ["chat", "insight_tracker"],
          bottom_sheet: ["collaborative_editor"]
        }
      }
    },

    "story_remix_lab" => %{
      description: "Transform stories across different mediums",
      story_types: ["story_remix"],
      primary_tools: ["format_converter", "media_editor", "template_library"],
      secondary_tools: ["chat", "version_control", "ai_assistant"],
      audio_features: ["voice_conversion", "soundtrack_generation"],
      mobile_optimized: true,
      session_type: "format_transformation",
      special_features: ["cross_media_conversion", "ai_assistance", "template_matching"],
      default_layout: %{
        desktop: %{
          left_dock: ["format_converter", "media_editor"],
          right_dock: ["template_library", "ai_assistant"],
          bottom_dock: ["chat"],
          floating: [],
          minimized: ["version_control"]
        },
        mobile: %{
          primary_view: "format_converter",
          quick_access: ["template_library", "ai_assistant"],
          bottom_sheet: ["media_editor"]
        }
      }
    },

    "narrative_beats_studio" => %{
      description: "Music production driven by story structure",
      story_types: ["narrative_beats"],
      primary_tools: ["beat_machine", "story_structure", "audio_mixer"],
      secondary_tools: ["chat", "timeline", "instrument_library"],
      audio_features: ["narrative_sync", "story_beats", "musical_themes"],
      mobile_optimized: true,
      session_type: "musical_storytelling",
      special_features: ["story_beat_sync", "narrative_composition", "musical_storytelling"],
      default_layout: %{
        desktop: %{
          left_dock: ["story_structure"],
          right_dock: ["beat_machine", "instrument_library"],
          bottom_dock: ["audio_mixer", "timeline"],
          floating: [],
          minimized: ["chat"]
        },
        mobile: %{
          primary_view: "beat_machine",
          quick_access: ["story_structure", "audio_mixer"],
          bottom_sheet: ["timeline", "instrument_library"]
        }
      }
    }
  }

  @doc """
  Gets collaboration mode configuration for a story type.
  """
  def get_collaboration_mode(story_type, collaboration_preference \\ :auto) do
    mode = case {story_type, collaboration_preference} do
      # Auto-detect based on story type
      {type, :auto} when type in ["novel", "screenplay", "short_story"] ->
        "narrative_workshop"

      {type, :auto} when type in ["case_study", "data_story", "report", "white_paper"] ->
        "business_workflow"

      {"live_story", _} -> "live_story_session"
      {"voice_sketch", _} -> "voice_sketch_studio"
      {"audio_portfolio", _} -> "audio_portfolio_builder"
      {"data_jam", _} -> "data_jam_session"
      {"story_remix", _} -> "story_remix_lab"
      {"narrative_beats", _} -> "narrative_beats_studio"

      # Explicit preference
      {_, mode} when is_binary(mode) and is_map_key(@collaboration_modes, mode) ->
        mode

      # Fallback
      _ -> "narrative_workshop"
    end

    Map.get(@collaboration_modes, mode)
  end

  @doc """
  Gets mobile-optimized layout for collaboration mode.
  """
  def get_mobile_layout(collaboration_mode) do
    case Map.get(@collaboration_modes, collaboration_mode) do
      %{default_layout: %{mobile: mobile_layout}} -> mobile_layout
      _ -> default_mobile_layout()
    end
  end

  @doc """
  Gets audio features available for collaboration mode.
  """
  def get_audio_features(collaboration_mode) do
    case Map.get(@collaboration_modes, collaboration_mode) do
      %{audio_features: features} -> features
      _ -> ["voice_notes"]
    end
  end

  @doc """
  Determines if story type needs session creation for collaboration.
  """
  def requires_active_session?(story_type, requested_features \\ []) do
    collaboration_mode = get_collaboration_mode(story_type)

    # Always need session for Frestyl Originals
    frestyl_originals = ["live_story", "voice_sketch", "audio_portfolio", "data_jam", "story_remix", "narrative_beats"]

    cond do
      story_type in frestyl_originals -> true
      "audio" in requested_features -> true
      "collaboration" in requested_features -> true
      "real_time_editing" in requested_features -> true
      true -> false
    end
  end

  defp default_mobile_layout do
    %{
      primary_view: "story_editor",
      quick_access: ["voice_notes", "chat"],
      bottom_sheet: ["tools"]
    }
  end
end
