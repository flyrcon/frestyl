# lib/frestyl/story_engine/analytics.ex
defmodule Frestyl.StoryEngine.Analytics do
  @moduledoc """
  Analytics and insights for Story Engine usage.
  """

  import Ecto.Query
  alias Frestyl.Repo
  alias Frestyl.Stories.EnhancedStoryStructure

  def get_user_story_stats(user_id) do
    base_query = from s in EnhancedStoryStructure,
      where: s.created_by_id == ^user_id

    %{
      total_stories: get_total_stories(base_query),
      completed_stories: get_completed_stories(base_query),
      active_collaborations: get_active_collaborations(base_query),
      words_written: get_total_words(base_query),
      favorite_formats: get_favorite_formats(user_id),
      completion_rate: calculate_completion_rate(base_query),
      collaboration_rate: calculate_collaboration_rate(base_query)
    }
  end

  def get_platform_stats do
    %{
      total_stories_created: get_total_platform_stories(),
      most_popular_formats: get_popular_formats(),
      average_completion_rate: get_platform_completion_rate(),
      collaboration_percentage: get_platform_collaboration_rate(),
      format_growth_trends: get_format_trends()
    }
  end

  # Private analytics functions
  defp get_total_stories(query) do
    Repo.aggregate(query, :count)
  end

  defp get_completed_stories(query) do
    query
    |> where([s], s.completion_percentage >= 90.0)
    |> Repo.aggregate(:count)
  end

  defp get_active_collaborations(query) do
    query
    |> where([s], s.collaboration_mode in ["active", "open"])
    |> Repo.aggregate(:count)
  end

  defp get_total_words(query) do
    query
    |> select([s], sum(s.current_word_count))
    |> Repo.one() || 0
  end

  defp get_favorite_formats(user_id) do
    # Get user's most used story types
    from(s in EnhancedStoryStructure,
      where: s.created_by_id == ^user_id,
      group_by: s.story_type,
      select: {s.story_type, count(s.id)},
      order_by: [desc: count(s.id)],
      limit: 3
    )
    |> Repo.all()
  end

  defp calculate_completion_rate(query) do
    case Repo.aggregate(query, :avg, :completion_percentage) do
      nil -> 0.0
      rate -> Float.round(rate, 1)
    end
  end

  defp calculate_collaboration_rate(query) do
    total = get_total_stories(query)
    collaborative = get_active_collaborations(query)

    case total do
      0 -> 0.0
      _ -> Float.round(collaborative / total * 100, 1)
    end
  end

  defp get_total_platform_stories do
    Repo.aggregate(EnhancedStoryStructure, :count)
  end

  defp get_popular_formats do
    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)

    from(s in EnhancedStoryStructure,
      where: s.inserted_at >= ^thirty_days_ago,
      group_by: s.story_type,
      select: {s.story_type, count(s.id)},
      order_by: [desc: count(s.id)],
      limit: 5
    )
    |> Repo.all()
  end

  defp get_platform_completion_rate do
    case Repo.aggregate(EnhancedStoryStructure, :avg, :completion_percentage) do
      nil -> 0.0
      rate -> Float.round(rate, 1)
    end
  end

  defp get_platform_collaboration_rate do
    total = get_total_platform_stories()

    collaborative_query = from(s in EnhancedStoryStructure,
      where: s.collaboration_mode in ["active", "open"])

    collaborative = Repo.aggregate(collaborative_query, :count)

    case total do
      0 -> 0.0
      _ -> Float.round(collaborative / total * 100, 1)
    end
  end

  defp get_format_trends do
    # Get format usage over last 6 months
    six_months_ago = DateTime.add(DateTime.utc_now(), -180, :day)

    from(s in EnhancedStoryStructure,
      where: s.inserted_at >= ^six_months_ago,
      group_by: [s.story_type, fragment("date_trunc('month', ?)", s.inserted_at)],
      select: {s.story_type, fragment("date_trunc('month', ?)", s.inserted_at), count(s.id)},
      order_by: [asc: fragment("date_trunc('month', ?)", s.inserted_at)]
    )
    |> Repo.all()
    |> Enum.group_by(fn {format, _month, _count} -> format end)
  end
end
