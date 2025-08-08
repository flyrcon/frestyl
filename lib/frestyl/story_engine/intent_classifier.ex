# lib/frestyl/story_engine/intent_classifier.ex
defmodule Frestyl.StoryEngine.IntentClassifier do
  @moduledoc """
  Enhanced intent classification system that includes Frestyl's proprietary formats
  alongside traditional storytelling intents.
  """

  alias Frestyl.Features.TierManager

  @intents %{
    # ============================================================================
    # EXISTING INTENTS (Enhanced with proprietary formats)
    # ============================================================================

    "personal_professional" => %{
      name: "Share Your Story",
      description: "Personal narratives, professional portfolios, thought leadership",
      formats: ["biography", "professional_portfolio", "article", "thought_leadership", "memoir"],
      icon: "👤",
      gradient: "from-blue-500 to-cyan-500",
      tier_required: "personal",
      primary_tools: ["text_editor", "media_library", "timeline"],
      collaboration_types: ["solo", "small_team"],
      ai_features: ["writing_assistance", "structure_suggestions"]
    },

    "business_growth" => %{
      name: "Drive Business Results",
      description: "Case studies, marketing stories, data-driven narratives",
      formats: ["case_study", "marketing_story", "data_story", "customer_journey", "white_paper", "data_jam"],
      icon: "📈",
      gradient: "from-green-500 to-emerald-500",
      tier_required: "creator",
      primary_tools: ["data_visualization", "analytics", "collaboration"],
      collaboration_types: ["team", "department"],
      ai_features: ["data_insights", "market_analysis", "outcome_prediction"]
    },

    "creative_expression" => %{
      name: "Creative Expression",
      description: "Novels, screenplays, comics, artistic storytelling",
      formats: ["novel", "screenplay", "comic_book", "song", "audiobook", "poetry", "narrative_beats", "story_remix"],
      icon: "🎨",
      gradient: "from-purple-500 to-pink-500",
      tier_required: "creator",
      primary_tools: ["text_editor", "audio_studio", "visual_editor"],
      collaboration_types: ["solo", "creative_team"],
      ai_features: ["character_development", "plot_suggestions", "dialogue_enhancement"]
    },

    "experimental" => %{
      name: "Experimental Lab",
      description: "Unique formats that blend multiple mediums",
      formats: ["live_story", "voice_sketch", "audio_portfolio", "narrative_beats", "story_remix", "data_jam"],
      icon: "🧪",
      gradient: "from-indigo-500 to-purple-600",
      tier_required: "professional",
      primary_tools: ["experimental_suite", "ai_assistant", "multimedia_editor"],
      collaboration_types: ["community", "open"],
      ai_features: ["format_blending", "creative_suggestions", "multimedia_sync"],
      beta: true
    },

    # ============================================================================
    # NEW PROPRIETARY FORMAT INTENTS
    # ============================================================================

    "collaborative_creation" => %{
      name: "Collaborative Content Creation",
      description: "Multi-user creative projects with real-time collaboration",
      formats: ["narrative_beats", "live_story", "collaborative_writing", "team_storytelling"],
      icon: "🤝",
      gradient: "from-cyan-500 to-blue-600",
      tier_required: "creator",
      primary_tools: ["real_time_collaboration", "role_management", "version_control"],
      collaboration_types: ["creative_team", "writing_group", "workshop"],
      ai_features: ["collaboration_suggestions", "conflict_resolution", "workflow_optimization"],
      collaboration_features: [
        "Role-based permissions",
        "Real-time editing",
        "Version control",
        "Comment systems",
        "Approval workflows"
      ]
    },

    "data_storytelling" => %{
      name: "Data-Driven Storytelling",
      description: "Transform data into compelling narratives and insights",
      formats: ["data_jam", "analytics_story", "research_narrative", "performance_report"],
      icon: "📊",
      gradient: "from-emerald-500 to-teal-600",
      tier_required: "professional",
      primary_tools: ["data_integration", "visualization_builder", "insight_generator"],
      collaboration_types: ["analyst_team", "stakeholder_review", "executive_presentation"],
      ai_features: ["data_analysis", "insight_discovery", "narrative_generation"],
      data_features: [
        "API integrations",
        "Real-time data sync",
        "Interactive visualizations",
        "Collaborative analysis",
        "Multi-format export"
      ]
    },

    "live_performance" => %{
      name: "Live & Streaming Content",
      description: "Real-time storytelling with audience engagement",
      formats: ["live_story", "streaming_narrative", "interactive_performance", "audience_participation"],
      icon: "🎭",
      gradient: "from-red-500 to-pink-600",
      tier_required: "creator",
      primary_tools: ["streaming_integration", "audience_interaction", "real_time_collaboration"],
      collaboration_types: ["multi_narrator", "audience_driven", "community"],
      ai_features: ["story_adaptation", "audience_analysis", "real_time_suggestions"],
      live_features: [
        "Real-time streaming",
        "Audience voting",
        "Live chat integration",
        "Session recording",
        "Multi-narrator support"
      ]
    },

    "content_transformation" => %{
      name: "Content Adaptation & Remixing",
      description: "Transform existing content for new formats and audiences",
      formats: ["story_remix", "format_conversion", "audience_adaptation", "platform_optimization"],
      icon: "🔄",
      gradient: "from-orange-500 to-red-600",
      tier_required: "creator",
      primary_tools: ["ai_transformation", "format_converter", "style_adapter"],
      collaboration_types: ["editor_review", "creative_consultation", "quality_assurance"],
      ai_features: ["content_analysis", "smart_transformation", "style_adaptation"],
      transformation_features: [
        "AI-powered analysis",
        "Smart format conversion",
        "Style adaptation",
        "Audience targeting",
        "Platform optimization"
      ]
    },

    "multimedia_experiences" => %{
      name: "Rich Multimedia Storytelling",
      description: "Stories enhanced with music, visuals, and interactive elements",
      formats: ["narrative_beats", "multimedia_story", "interactive_media", "audio_visual_narrative"],
      icon: "🎬",
      gradient: "from-purple-600 to-indigo-700",
      tier_required: "creator",
      primary_tools: ["audio_integration", "visual_sync", "interactive_builder"],
      collaboration_types: ["multimedia_team", "composer_writer", "producer_director"],
      ai_features: ["music_generation", "visual_suggestions", "sync_optimization"],
      multimedia_features: [
        "Audio integration",
        "Visual synchronization",
        "Interactive elements",
        "Multi-sensory experiences",
        "Rich media export"
      ]
    },

    # ============================================================================
    # SPECIALIZED PROFESSIONAL INTENTS
    # ============================================================================

    "academic_research" => %{
      name: "Academic & Research Content",
      description: "Research papers, findings, and academic storytelling",
      formats: ["research_paper", "academic_narrative", "data_jam", "findings_story"],
      icon: "🔬",
      gradient: "from-blue-600 to-indigo-700",
      tier_required: "professional",
      primary_tools: ["research_tools", "citation_manager", "peer_review"],
      collaboration_types: ["research_team", "peer_review", "academic_community"],
      ai_features: ["research_assistance", "citation_checking", "methodology_suggestions"]
    },

    "enterprise_communication" => %{
      name: "Enterprise & Team Communication",
      description: "Large-scale organizational storytelling and communication",
      formats: ["enterprise_story", "organizational_narrative", "change_management_story", "data_jam"],
      icon: "🏢",
      gradient: "from-gray-600 to-blue-700",
      tier_required: "enterprise",
      primary_tools: ["enterprise_collaboration", "stakeholder_management", "change_communication"],
      collaboration_types: ["enterprise_team", "leadership", "cross_department"],
      ai_features: ["stakeholder_analysis", "change_impact_assessment", "communication_optimization"]
    }
  }

  def get_all_intents, do: @intents

  def get_intent(intent_key), do: Map.get(@intents, intent_key)

  def get_formats_for_intent(intent_key) do
    case get_intent(intent_key) do
      nil -> []
      intent -> intent.formats
    end
  end

  def get_intents_for_user_tier(user_tier) do
    @intents
    |> Enum.filter(fn {_key, intent} ->
      TierManager.has_tier_access?(user_tier, intent.tier_required)
    end)
    |> Enum.into(%{})
  end

  def suggest_intent_based_on_history(user_preferences) do
    recent_intents = user_preferences.recent_intents || []

    case recent_intents do
      [] -> "personal_professional"  # Default for new users
      [last_intent | _] -> last_intent
    end
  end

  def get_recommended_formats(user_tier, intent_key, user_history \\ []) do
    intent = get_intent(intent_key)

    if intent == nil do
      []
    else
      # Filter formats by tier access
      accessible_formats = Enum.filter(intent.formats, fn format ->
        format_config = Frestyl.Stories.EnhancedTemplates.get_format_config(format)
        TierManager.has_tier_access?(user_tier, format_config.required_tier || "personal")
      end)

      # Sort by user history and popularity
      sort_formats_by_preference(accessible_formats, user_history)
    end
  end

  defp sort_formats_by_preference(formats, user_history) do
    # Simple sorting: recent usage first, then alphabetical
    Enum.sort_by(formats, fn format ->
      history_index = Enum.find_index(user_history, &(&1 == format))
      {history_index || 999, format}
    end)
  end

  @doc """
  Get intent categories for UI organization
  """
  def get_intent_categories do
    %{
      "core_storytelling" => %{
        title: "Core Storytelling",
        description: "Traditional and personal storytelling formats",
        intents: ["personal_professional", "creative_expression"],
        icon: "📖"
      },

      "business_professional" => %{
        title: "Business & Professional",
        description: "Business-focused content and data storytelling",
        intents: ["business_growth", "data_storytelling", "academic_research", "enterprise_communication"],
        icon: "💼"
      },

      "experimental_creative" => %{
        title: "Experimental & Interactive",
        description: "Cutting-edge storytelling with new technologies",
        intents: ["experimental", "multimedia_experiences", "live_performance"],
        icon: "🚀"
      },

      "collaborative_tools" => %{
        title: "Collaboration & Transformation",
        description: "Multi-user creation and content adaptation",
        intents: ["collaborative_creation", "content_transformation"],
        icon: "🔧"
      }
    }
  end

  @doc """
  Get quick start suggestions based on user tier and recent activity
  """
  def get_quick_start_suggestions(user_tier, recent_activity \\ []) do
    base_suggestions = case user_tier do
      "personal" -> [
        %{
          intent: "personal_professional",
          format: "personal_narrative",
          title: "Share Your Story",
          description: "Tell your personal or professional journey"
        }
      ]

      "creator" -> [
        %{
          intent: "creative_expression",
          format: "novel",
          title: "Write a Novel",
          description: "Start your creative writing journey"
        },
        %{
          intent: "multimedia_experiences",
          format: "narrative_beats",
          title: "Musical Storytelling",
          description: "Create music that tells your story"
        },
        %{
          intent: "live_performance",
          format: "live_story",
          title: "Live Interactive Story",
          description: "Create stories with live audience participation"
        }
      ]

      "professional" -> [
        %{
          intent: "business_growth",
          format: "case_study",
          title: "Business Case Study",
          description: "Document successful projects and outcomes"
        },
        %{
          intent: "data_storytelling",
          format: "data_jam",
          title: "Data Story Session",
          description: "Transform data into compelling narratives"
        }
      ]

      "enterprise" -> [
        %{
          intent: "enterprise_communication",
          format: "organizational_narrative",
          title: "Enterprise Story",
          description: "Large-scale organizational communication"
        },
        %{
          intent: "data_storytelling",
          format: "data_jam",
          title: "Enterprise Analytics",
          description: "Enterprise-scale data storytelling"
        }
      ]

      _ -> []
    end

    # Filter out suggestions for formats the user has used recently
    recent_formats = Enum.map(recent_activity, & &1.format)

    Enum.reject(base_suggestions, fn suggestion ->
      suggestion.format in recent_formats
    end)
  end

  @doc """
  Analyze user behavior to suggest new intents to explore
  """
  def suggest_new_intents(user_tier, user_history, current_favorites) do
    all_accessible_intents = get_intents_for_user_tier(user_tier)
    used_intents = Enum.map(user_history, & &1.intent) |> Enum.uniq()
    unused_intents = Map.keys(all_accessible_intents) -- used_intents

    # Suggest based on tier and usage patterns
    suggestions = case {user_tier, length(used_intents)} do
      {"creator", count} when count >= 2 ->
        # Experienced creator users - suggest experimental formats
        ["multimedia_experiences", "collaborative_creation", "live_performance"]

      {"professional", count} when count >= 1 ->
        # Professional users - suggest data and business formats
        ["data_storytelling", "content_transformation", "academic_research"]

      {"enterprise", _} ->
        # Enterprise users - suggest enterprise-specific formats
        ["enterprise_communication", "data_storytelling"]

      _ ->
        # New users - suggest based on tier capabilities
        case user_tier do
          "creator" -> ["creative_expression", "multimedia_experiences"]
          "professional" -> ["business_growth", "data_storytelling"]
          _ -> ["creative_expression"]
        end
    end

    # Return only unused suggestions that are accessible
    suggestions
    |> Enum.filter(fn intent ->
      intent in unused_intents and Map.has_key?(all_accessible_intents, intent)
    end)
    |> Enum.take(3)
    |> Enum.map(fn intent_key ->
      intent = all_accessible_intents[intent_key]
      %{
        intent_key: intent_key,
        title: intent.name,
        description: intent.description,
        reason: generate_suggestion_reason(intent_key, user_tier, user_history)
      }
    end)
  end

  defp generate_suggestion_reason(intent_key, user_tier, user_history) do
    case intent_key do
      "multimedia_experiences" ->
        "Create rich, immersive stories with music, visuals, and interactive elements"

      "collaborative_creation" ->
        "Work with others on creative projects using real-time collaboration tools"

      "data_storytelling" ->
        "Transform your business data into compelling narratives for stakeholders"

      "content_transformation" ->
        "Adapt your existing content for new formats and audiences with AI assistance"

      "live_performance" ->
        "Engage audiences with live, interactive storytelling experiences"

      "experimental" ->
        "Explore cutting-edge storytelling formats that blend multiple mediums"

      _ ->
        "Expand your storytelling capabilities with this new format"
    end
  end
end
