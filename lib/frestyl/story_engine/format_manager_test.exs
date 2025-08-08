# test/frestyl/story_engine/format_manager_test.exs
defmodule Frestyl.StoryEngine.FormatManagerTest do
  use Frestyl.DataCase

  alias Frestyl.StoryEngine.FormatManager

  describe "format management" do
    test "get_format_config returns correct configuration" do
      config = FormatManager.get_format_config("biography")

      assert config.name == "Biography"
      assert config.description =~ "life story"
      assert config.required_tier == "personal"
      assert config.icon == "📖"
    end

    test "get_format_config returns nil for unknown format" do
      config = FormatManager.get_format_config("unknown_format")
      assert config == nil
    end

    test "get_all_formats returns all available formats" do
      all_formats = FormatManager.get_all_formats()

      assert Map.has_key?(all_formats, "biography")
      assert Map.has_key?(all_formats, "novel")
      assert Map.has_key?(all_formats, "case_study")
      assert Map.has_key?(all_formats, "live_story")
    end

    test "get_formats_for_tier filters by user tier" do
      personal_formats = FormatManager.get_formats_for_tier("personal")
      professional_formats = FormatManager.get_formats_for_tier("professional")

      # Personal tier should have basic formats
      assert Map.has_key?(personal_formats, "biography")
      assert Map.has_key?(personal_formats, "article")

      # Professional tier should have all formats
      assert Map.has_key?(professional_formats, "biography")
      assert Map.has_key?(professional_formats, "live_story")
      assert Map.has_key?(professional_formats, "narrative_beats")

      # Personal tier should not have professional-only formats
      refute Map.has_key?(personal_formats, "live_story")
    end

    test "get_beta_formats returns only beta formats" do
      beta_formats = FormatManager.get_beta_formats()

      # Should include experimental formats marked as beta
      assert Map.has_key?(beta_formats, "live_story")
      assert Map.has_key?(beta_formats, "voice_sketch")
      assert Map.has_key?(beta_formats, "narrative_beats")

      # Should not include stable formats
      refute Map.has_key?(beta_formats, "biography")
      refute Map.has_key?(beta_formats, "article")
    end

    test "estimate_completion_time adjusts for user experience" do
      beginner_time = FormatManager.estimate_completion_time("biography", :beginner)
      expert_time = FormatManager.estimate_completion_time("biography", :expert)

      assert beginner_time =~ "first time"
      assert expert_time =~ "experienced user"
    end

    test "estimate_completion_time handles unknown format" do
      time = FormatManager.estimate_completion_time("unknown_format")
      assert time == "Unknown"
    end

    test "get_recommended_collaboration_type returns appropriate type" do
      # Test with user preferences
      user_prefs = %{"collaboration_style" => "small_team"}
      collab_type = FormatManager.get_recommended_collaboration_type("novel", user_prefs)

      assert collab_type == "small_team"
    end

    test "get_recommended_collaboration_type falls back to first available" do
      # Test without matching preferences
      user_prefs = %{"collaboration_style" => "enterprise"}
      collab_type = FormatManager.get_recommended_collaboration_type("biography", user_prefs)

      # Should fall back to first available collaboration type
      config = FormatManager.get_format_config("biography")
      assert collab_type == hd(config.collaboration_types)
    end

    test "format configurations include all required fields" do
      config = FormatManager.get_format_config("novel")

      assert Map.has_key?(config, :name)
      assert Map.has_key?(config, :description)
      assert Map.has_key?(config, :icon)
      assert Map.has_key?(config, :gradient)
      assert Map.has_key?(config, :required_tier)
      assert Map.has_key?(config, :estimated_time)
      assert Map.has_key?(config, :collaboration_types)
      assert Map.has_key?(config, :features)
      assert Map.has_key?(config, :ai_assistance)
    end
  end
end
