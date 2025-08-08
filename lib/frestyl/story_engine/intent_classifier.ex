# lib/frestyl/story_engine/intent_classifier.ex
defmodule Frestyl.StoryEngine.IntentClassifier do
  @moduledoc """
  Classifies user intents and maps them to appropriate story formats.
  """

  @intents %{
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
      formats: ["case_study", "marketing_story", "data_story", "customer_journey", "white_paper"],
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
      formats: ["novel", "screenplay", "comic_book", "song", "audiobook", "poetry"],
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
      Frestyl.Features.TierManager.has_tier_access?(user_tier, intent.tier_required)
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
        Frestyl.Features.TierManager.has_tier_access?(user_tier, format_config.required_tier || "personal")
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
end
