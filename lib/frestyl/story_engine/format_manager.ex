# lib/frestyl/story_engine/format_manager.ex
defmodule Frestyl.StoryEngine.FormatManager do
  @moduledoc """
  Manages story format configurations and access controls.
  """

  @format_configs %{
    # Personal & Professional Formats
    "biography" => %{
      name: "Biography",
      description: "Share your life story with rich media and timeline integration",
      icon: "📖",
      gradient: "from-green-400 to-blue-500",
      required_tier: "personal",
      estimated_time: "2-4 hours",
      collaboration_types: ["solo", "family"],
      features: ["timeline", "photos", "audio_recording", "family_tree"],
      ai_assistance: ["memory_prompts", "structure_suggestions", "style_improvement"]
    },

    "professional_portfolio" => %{
      name: "Professional Portfolio",
      description: "Showcase your skills and experience professionally",
      icon: "💼",
      gradient: "from-blue-500 to-indigo-500",
      required_tier: "personal",
      estimated_time: "1-2 hours",
      collaboration_types: ["solo", "team"],
      features: ["skill_matrix", "project_showcase", "testimonials", "resume_export"],
      ai_assistance: ["skill_optimization", "achievement_highlighting", "industry_alignment"]
    },

    "article" => %{
      name: "Article & Blog",
      description: "Write and publish content with CMS integration",
      icon: "📝",
      gradient: "from-purple-400 to-pink-500",
      required_tier: "personal",
      estimated_time: "30min-2 hours",
      collaboration_types: ["solo", "editorial"],
      features: ["seo_optimization", "publishing_platforms", "analytics", "social_sharing"],
      ai_assistance: ["topic_research", "outline_generation", "style_enhancement"]
    },

    # Business & Growth Formats
    "case_study" => %{
      name: "Case Study",
      description: "Document business outcomes with data and insights",
      icon: "📊",
      gradient: "from-emerald-400 to-teal-500",
      required_tier: "creator",
      estimated_time: "2-4 hours",
      collaboration_types: ["team", "client"],
      features: ["data_visualization", "metrics_tracking", "stakeholder_input", "executive_summary"],
      ai_assistance: ["impact_analysis", "story_structure", "data_interpretation"]
    },

    "data_story" => %{
      name: "Data Story",
      description: "Transform data into compelling narratives with visualizations",
      icon: "📈",
      gradient: "from-blue-400 to-cyan-500",
      required_tier: "creator",
      estimated_time: "1-3 hours",
      collaboration_types: ["team", "department"],
      features: ["chart_integration", "interactive_visualizations", "data_import", "real_time_updates"],
      ai_assistance: ["pattern_recognition", "insight_generation", "narrative_flow"]
    },

    # Creative Expression Formats
    "novel" => %{
      name: "Novel",
      description: "Long-form fiction with character and world development",
      icon: "📚",
      gradient: "from-purple-500 to-indigo-600",
      required_tier: "creator",
      estimated_time: "Months to years",
      collaboration_types: ["solo", "writing_group", "editor"],
      features: ["character_development", "world_building", "chapter_management", "manuscript_export"],
      ai_assistance: ["plot_development", "character_arcs", "dialogue_enhancement", "pacing_analysis"]
    },

    "screenplay" => %{
      name: "Screenplay",
      description: "Film and TV scripts with industry-standard formatting",
      icon: "🎬",
      gradient: "from-orange-500 to-red-500",
      required_tier: "creator",
      estimated_time: "Weeks to months",
      collaboration_types: ["solo", "production_team", "script_doctor"],
      features: ["industry_formatting", "scene_breakdown", "character_sheets", "production_notes"],
      ai_assistance: ["dialogue_polishing", "scene_pacing", "character_voice", "format_checking"]
    },

    # Experimental Formats
    "live_story" => %{
      name: "Live Story",
      description: "Real-time collaborative storytelling with audience interaction",
      icon: "🎪",
      gradient: "from-purple-500 to-pink-600",
      required_tier: "professional",
      estimated_time: "30min-2 hours per session",
      collaboration_types: ["community", "audience"],
      features: ["live_streaming", "audience_voting", "real_time_branching", "session_recording"],
      ai_assistance: ["story_suggestions", "audience_engagement", "plot_branching"],
      beta: true
    },

    "voice_sketch" => %{
      name: "Voice-Sketch",
      description: "Voice narration synchronized with live drawing",
      icon: "🎨🎙️",
      gradient: "from-indigo-500 to-purple-600",
      required_tier: "professional",
      estimated_time: "1-3 hours",
      collaboration_types: ["solo", "artist_narrator"],
      features: ["voice_recording", "drawing_tools", "timeline_sync", "export_video"],
      ai_assistance: ["narration_coaching", "visual_suggestions", "timing_optimization"],
      beta: true
    },

    "narrative_beats" => %{
      name: "Narrative Beats",
      description: "Musical composition driven by story structure",
      icon: "🎵📖",
      gradient: "from-pink-500 to-orange-500",
      required_tier: "professional",
      estimated_time: "2-8 hours",
      collaboration_types: ["band", "producer", "songwriter"],
      features: ["story_to_music_mapping", "character_instruments", "emotional_scoring", "music_production"],
      ai_assistance: ["chord_suggestions", "tempo_matching", "character_themes"],
      beta: true
    }
  }

  def get_all_formats, do: @format_configs

  def get_format_config(format_key), do: Map.get(@format_configs, format_key)

  def get_formats_for_tier(user_tier) do
    @format_configs
    |> Enum.filter(fn {_key, config} ->
      Frestyl.Features.TierManager.has_tier_access?(user_tier, config.required_tier)
    end)
    |> Enum.into(%{})
  end

  def get_beta_formats do
    @format_configs
    |> Enum.filter(fn {_key, config} -> Map.get(config, :beta, false) end)
    |> Enum.into(%{})
  end

  def estimate_completion_time(format_key, user_experience_level \\ :beginner) do
    config = get_format_config(format_key)

    if config == nil do
      "Unknown"
    else
      base_time = config.estimated_time

      case user_experience_level do
        :expert -> "#{base_time} (experienced user)"
        :intermediate -> "#{base_time} (some experience)"
        :beginner -> "#{base_time} (first time)"
      end
    end
  end

  def get_recommended_collaboration_type(format_key, user_preferences \\ %{}) do
    config = get_format_config(format_key)

    if config == nil do
      "solo"
    else
      preferred_style = Map.get(user_preferences, "collaboration_style", "solo")

      if preferred_style in config.collaboration_types do
        preferred_style
      else
        hd(config.collaboration_types)
      end
    end
  end
end
