# lib/frestyl/story_engine/user_preferences.ex - FIXED
defmodule Frestyl.StoryEngine.UserPreferences do
  @moduledoc """
  Manages user preferences and recommendations for story creation.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  # Use the full module name to avoid confusion
  alias Frestyl.StoryEngine.UserStoryPreferences, as: Preferences

  def get_or_create_preferences(user_id) do
    case Repo.get_by(Preferences, user_id: user_id) do
      nil ->
        %Preferences{user_id: user_id}
        |> Preferences.changeset(%{})
        |> Repo.insert!()

      preferences ->
        preferences
    end
  end

  def track_format_usage(user_id, format, intent) do
    preferences = get_or_create_preferences(user_id)

    # Update recent intents
    recent_intents = [intent | (preferences.recent_intents || [])]
    |> Enum.uniq()
    |> Enum.take(5)

    # Update format usage stats
    current_stats = preferences.format_usage_stats || %{}
    updated_stats = Map.put(current_stats, format,
      Map.get(current_stats, format, 0) + 1)

    # Update quick access formats based on usage
    quick_access = get_most_used_formats(updated_stats, 6)

    changeset = Preferences.changeset(preferences, %{
      recent_intents: recent_intents,
      last_used_intent: intent,
      format_usage_stats: updated_stats,
      quick_access_formats: quick_access
    })

    Repo.update!(changeset)
  end

  def track_story_completion(user_id, completion_percentage) do
    preferences = get_or_create_preferences(user_id)

    # Calculate running average of completion rates
    current_rate = preferences.story_completion_rate || 0.0
    new_rate = (current_rate + completion_percentage) / 2

    changeset = Preferences.changeset(preferences, %{
      story_completion_rate: new_rate
    })

    Repo.update!(changeset)
  end

  def get_recommended_intents(user_id, user_tier) do
    preferences = get_or_create_preferences(user_id)
    available_intents = Frestyl.StoryEngine.IntentClassifier.get_intents_for_user_tier(user_tier)

    # Sort by recent usage and completion rates
    Enum.sort_by(Map.keys(available_intents), fn intent ->
      recent_index = Enum.find_index(preferences.recent_intents || [], &(&1 == intent))
      {recent_index || 999, intent}
    end)
  end

  def get_personalized_dashboard(user_id, user_tier) do
    preferences = get_or_create_preferences(user_id)

    %{
      quick_access_formats: preferences.quick_access_formats || [],
      suggested_intent: preferences.last_used_intent || "personal_professional",
      completion_encouragement: get_completion_encouragement(preferences.story_completion_rate),
      format_recommendations: get_format_recommendations(preferences, user_tier),
      collaboration_suggestions: get_collaboration_suggestions(preferences)
    }
  end

  defp get_most_used_formats(usage_stats, limit) do
    usage_stats
    |> Enum.sort_by(fn {_format, count} -> -count end)
    |> Enum.take(limit)
    |> Enum.map(fn {format, _count} -> format end)
  end

  defp get_completion_encouragement(rate) when rate >= 0.8,
    do: "You're great at finishing stories! Keep up the momentum."
  defp get_completion_encouragement(rate) when rate >= 0.5,
    do: "You're making good progress. Try setting smaller daily goals."
  defp get_completion_encouragement(_rate),
    do: "Every story starts with a single word. Start small and build from there."

  defp get_format_recommendations(preferences, user_tier) do
    # Suggest formats user hasn't tried but has access to
    used_formats = Map.keys(preferences.format_usage_stats || %{})

    Frestyl.StoryEngine.IntentClassifier.get_intents_for_user_tier(user_tier)
    |> Enum.flat_map(fn {_intent, config} -> config.formats end)
    |> Enum.uniq()
    |> Enum.reject(&(&1 in used_formats))
    |> Enum.take(3)
  end

  defp get_collaboration_suggestions(preferences) do
    collab_prefs = preferences.collaboration_preferences || %{}

    case Map.get(collab_prefs, "preferred_style", "solo") do
      "solo" -> ["Try inviting one trusted friend to collaborate"]
      "small_team" -> ["Consider expanding to department-wide collaboration"]
      _ -> ["Explore community collaboration features"]
    end
  end
end
