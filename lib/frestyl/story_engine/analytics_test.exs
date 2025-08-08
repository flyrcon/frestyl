# test/frestyl/story_engine/analytics_test.exs
defmodule Frestyl.StoryEngine.AnalyticsTest do
  use Frestyl.DataCase

  alias Frestyl.StoryEngine.Analytics
  import Frestyl.AccountsFixtures
  import Frestyl.StoriesFixtures

  describe "story analytics" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "get_user_story_stats returns comprehensive statistics", %{user: user} do
      # Create some test stories
      _story1 = story_fixture(%{created_by_id: user.id, completion_percentage: 90.0, current_word_count: 1000})
      _story2 = story_fixture(%{created_by_id: user.id, completion_percentage: 50.0, current_word_count: 500})
      _story3 = story_fixture(%{created_by_id: user.id, completion_percentage: 100.0, current_word_count: 2000, collaboration_mode: "active"})

      stats = Analytics.get_user_story_stats(user.id)

      assert stats.total_stories == 3
      assert stats.completed_stories == 2  # Stories with >=90% completion
      assert stats.active_collaborations == 1
      assert stats.words_written == 3500
      assert length(stats.favorite_formats) <= 3
      assert is_float(stats.completion_rate)
      assert is_float(stats.collaboration_rate)
    end

    test "get_platform_stats returns platform-wide statistics" do
      user1 = user_fixture()
      user2 = user_fixture()

      # Create stories from different users
      _story1 = story_fixture(%{created_by_id: user1.id, story_type: "novel", completion_percentage: 80.0})
      _story2 = story_fixture(%{created_by_id: user2.id, story_type: "case_study", completion_percentage: 90.0, collaboration_mode: "active"})

      stats = Analytics.get_platform_stats()

      assert is_number(stats.total_stories_created)
      assert is_list(stats.most_popular_formats)
      assert is_float(stats.average_completion_rate)
      assert is_float(stats.collaboration_percentage)
      assert is_map(stats.format_growth_trends)
    end

    test "favorite formats are correctly calculated", %{user: user} do
      # Create multiple stories of the same type
      _story1 = story_fixture(%{created_by_id: user.id, story_type: "novel"})
      _story2 = story_fixture(%{created_by_id: user.id, story_type: "novel"})
      _story3 = story_fixture(%{created_by_id: user.id, story_type: "case_study"})

      stats = Analytics.get_user_story_stats(user.id)

      # Novel should be the top format (2 stories)
      assert length(stats.favorite_formats) >= 1
      {top_format, count} = hd(stats.favorite_formats)
      assert top_format == "novel"
      assert count == 2
    end

    test "completion rate calculation handles edge cases", %{user: user} do
      # Test with no stories
      empty_stats = Analytics.get_user_story_stats(user.id)
      assert empty_stats.completion_rate == 0.0

      # Test with one complete story
      _story = story_fixture(%{created_by_id: user.id, completion_percentage: 100.0})
      single_stats = Analytics.get_user_story_stats(user.id)
      assert single_stats.completion_rate == 100.0
    end

    test "collaboration rate calculation works correctly", %{user: user} do
      # Create mix of collaborative and solo stories
      _solo_story = story_fixture(%{created_by_id: user.id, collaboration_mode: "owner_only"})
      _collab_story = story_fixture(%{created_by_id: user.id, collaboration_mode: "active"})

      stats = Analytics.get_user_story_stats(user.id)

      # Should be 50% collaboration rate (1 of 2 stories)
      assert stats.collaboration_rate == 50.0
    end

    test "format growth trends include time series data" do
      user = user_fixture()

      # Create stories (these will be recent, affecting trends)
      _story1 = story_fixture(%{created_by_id: user.id, story_type: "novel"})
      _story2 = story_fixture(%{created_by_id: user.id, story_type: "case_study"})

      trends = Analytics.get_format_trends()

      # Should be grouped by format
      assert is_map(trends)

      # Each format should have time series data
      if Map.has_key?(trends, "novel") do
        novel_data = trends["novel"]
        assert is_list(novel_data)
      end
    end

    test "popular formats reflect recent activity" do
      user = user_fixture()

      # Create recent stories
      _story1 = story_fixture(%{created_by_id: user.id, story_type: "biography"})
      _story2 = story_fixture(%{created_by_id: user.id, story_type: "biography"})

      popular_formats = Analytics.get_popular_formats()

      assert is_list(popular_formats)
      # Should include format and count tuples
      if length(popular_formats) > 0 do
        {format, count} = hd(popular_formats)
        assert is_binary(format)
        assert is_number(count)
      end
    end
  end
end
