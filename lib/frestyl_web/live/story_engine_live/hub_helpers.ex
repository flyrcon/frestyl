# lib/frestyl_web/live/story_engine_live/hub_helpers.ex - Additional Helper Functions
defmodule FrestylWeb.StoryEngineLive.HubHelpers do
  @moduledoc """
  Helper functions for the Story Engine Hub
  """

  def format_time_ago(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      seconds when seconds < 60 -> "just now"
      seconds when seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds when seconds < 86400 -> "#{div(seconds, 3600)}h ago"
      seconds when seconds < 604800 -> "#{div(seconds, 86400)}d ago"
      _ -> "#{div(DateTime.diff(DateTime.utc_now(), datetime, :second), 604800)}w ago"
    end
  end

  def format_word_count(count) when count < 1000, do: "#{count}"
  def format_word_count(count) when count < 1000000, do: "#{Float.round(count / 1000, 1)}K"
  def format_word_count(count), do: "#{Float.round(count / 1000000, 1)}M"

  def completion_color(percentage) when percentage < 25, do: "text-red-600"
  def completion_color(percentage) when percentage < 50, do: "text-yellow-600"
  def completion_color(percentage) when percentage < 75, do: "text-blue-600"
  def completion_color(_), do: "text-green-600"

  def story_status_badge(status) do
    case status do
      "completed" -> %{class: "bg-green-100 text-green-800", text: "Complete"}
      "in_progress" -> %{class: "bg-blue-100 text-blue-800", text: "In Progress"}
      "collaborative" -> %{class: "bg-purple-100 text-purple-800", text: "Collaborative"}
      "draft" -> %{class: "bg-gray-100 text-gray-800", text: "Draft"}
    end
  end

  def tier_badge_class(tier) do
    case tier do
      "personal" -> "bg-gray-100 text-gray-800"
      "creator" -> "bg-blue-100 text-blue-800"
      "professional" -> "bg-purple-100 text-purple-800"
      "enterprise" -> "bg-indigo-100 text-indigo-800"
    end
  end

  def format_icon(format) do
    case format do
      "novel" -> "📚"
      "screenplay" -> "🎬"
      "case_study" -> "📊"
      "article" -> "📝"
      "memoir" -> "📖"
      "poetry" -> "📜"
      "live_story" -> "🎭"
      "data_story" -> "📈"
      "comic_book" -> "📱"
      "song" -> "🎵"
      _ -> "📄"
    end
  end

  def intent_description(intent) do
    case intent do
      "personal_professional" -> "Share your expertise and build your professional brand"
      "business_growth" -> "Drive business results with data-driven storytelling"
      "creative_expression" -> "Explore artistic storytelling and creative writing"
      "experimental" -> "Push boundaries with innovative narrative formats"
      _ -> "Tell your story your way"
    end
  end

  def estimated_time_badge(time) do
    case time do
      time when is_binary(time) and byte_size(time) < 20 -> time
      _ -> "Varies"
    end
  end

  def collaboration_type_description(type) do
    case type do
      "solo" -> "Work independently on your story"
      "small_team" -> "Collaborate with 2-5 people"
      "writing_group" -> "Join a writing community (5-10 members)"
      "department" -> "Department-wide collaboration"
      "community" -> "Open community collaboration"
      _ -> "Custom collaboration setup"
    end
  end
end
