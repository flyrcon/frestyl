defmodule Frestyl.Achievements.EnhancementAchievements do
  @moduledoc """
  Manages achievements and badges for portfolio enhancements
  """

  @achievements %{
    "first_voice" => %{
      title: "Voice Pioneer",
      description: "Added your first voice introduction",
      icon: "🎤",
      points: 100
    },
    "content_master" => %{
      title: "Content Master",
      description: "Completed 5 writing enhancements",
      icon: "✍️",
      points: 500
    },
    "design_expert" => %{
      title: "Design Expert",
      description: "Achieved 90+ design quality score",
      icon: "🎨",
      points: 300
    },
    "collaboration_champion" => %{
      title: "Collaboration Champion",
      description: "Completed 10 collaborative enhancements",
      icon: "🤝",
      points: 750
    },
    "portfolio_perfectionist" => %{
      title: "Portfolio Perfectionist",
      description: "Achieved 95+ overall quality score",
      icon: "⭐",
      points: 1000
    }
  }

  def check_achievements(user_id, enhancement_type, completion_data) do
    unlocked_achievements = []

    # Check for new achievements
    potential_achievements = get_potential_achievements(enhancement_type)

    Enum.reduce(potential_achievements, unlocked_achievements, fn achievement_key, acc ->
      if achievement_unlocked?(user_id, achievement_key, completion_data) do
        achievement = Map.get(@achievements, achievement_key)
        award_achievement(user_id, achievement_key, achievement)
        [achievement | acc]
      else
        acc
      end
    end)
  end

  defp get_potential_achievements(enhancement_type) do
    case enhancement_type do
      "voice_over" -> ["first_voice", "collaboration_champion"]
      "writing" -> ["content_master", "collaboration_champion"]
      "design" -> ["design_expert", "collaboration_champion"]
      _ -> ["collaboration_champion", "portfolio_perfectionist"]
    end
  end

  defp achievement_unlocked?(user_id, achievement_key, completion_data) do
    case achievement_key do
      "first_voice" ->
        completion_data.enhancement_type == "voice_over" &&
        count_user_completions(user_id, "voice_over") == 1

      "content_master" ->
        count_user_completions(user_id, "writing") >= 5

      "design_expert" ->
        completion_data.final_quality_score >= 90 &&
        completion_data.enhancement_type == "design"

      "collaboration_champion" ->
        count_collaborative_completions(user_id) >= 10

      "portfolio_perfectionist" ->
        completion_data.final_quality_score >= 95

      _ ->
        false
    end
  end

  defp count_user_completions(user_id, enhancement_type) do
    # Mock implementation - replace with actual query
    case enhancement_type do
      "voice_over" -> 1
      "writing" -> 3
      _ -> 0
    end
  end

  defp count_collaborative_completions(user_id) do
    # Mock implementation - replace with actual query
    5
  end

  defp award_achievement(user_id, achievement_key, achievement) do
    # Mock implementation - replace with actual achievement recording
    IO.puts("Achievement unlocked for user #{user_id}: #{achievement.title}")
  end

  # Helper functions for the enhancement system
  defp calculate_estimated_cost(enhancement_type, user) do
    base_costs = %{
      "voice_over" => %{personal: 0, creator: 0, professional: 0},
      "writing" => %{personal: 5, creator: 0, professional: 0},
      "design" => %{personal: 10, creator: 5, professional: 0},
      "music" => %{personal: 15, creator: 10, professional: 5}
    }

    tier = user.account.subscription_tier || :personal
    Map.get(base_costs[enhancement_type], tier, 0)
  end

  defp can_access_enhancement_collaboration?(user, enhancement_type) do
    Features.FeatureGate.can_access_feature?(user.account, :real_time_collaboration) &&
    Features.FeatureGate.can_access_feature?(user.account, String.to_atom(enhancement_type))
  end

  defp generate_channel_name(portfolio, enhancement_type) do
    enhancement_names = %{
      "voice_over" => "Voice Introduction",
      "writing" => "Content Enhancement",
      "design" => "Visual Design",
      "music" => "Background Music",
      "quarterly_update" => "Portfolio Update",
      "feedback" => "Portfolio Review"
    }

    enhancement_name = Map.get(enhancement_names, enhancement_type, "Enhancement")
    "#{portfolio.title} - #{enhancement_name}"
  end

  defp build_featured_content(portfolio, enhancement_type) do
    [%{
      "type" => "portfolio",
      "id" => portfolio.id,
      "enhancement_type" => enhancement_type,
      "started_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }]
  end

  defp build_channel_metadata(portfolio, enhancement_type, user) do
    quality_score = analyze_portfolio_quality(portfolio)

    %{
      "portfolio_id" => portfolio.id,
      "enhancement_type" => enhancement_type,
      "user_id" => user.id,
      "quality_score_at_start" => quality_score,
      "started_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "expected_duration" => get_expected_duration(enhancement_type),
      "milestones" => get_enhancement_milestones(enhancement_type),
      "progress_percentage" => 0,
      "collaborator_count" => 0
    }
  end

  # Helper functions for the enhancement system
  defp calculate_estimated_cost(enhancement_type, user) do
    base_costs = %{
      "voice_over" => %{personal: 0, creator: 0, professional: 0},
      "writing" => %{personal: 5, creator: 0, professional: 0},
      "design" => %{personal: 10, creator: 5, professional: 0},
      "music" => %{personal: 15, creator: 10, professional: 5}
    }

    tier = user.account.subscription_tier || :personal
    Map.get(base_costs[enhancement_type], tier, 0)
  end

  defp can_access_enhancement_collaboration?(user, enhancement_type) do
    Features.FeatureGate.can_access_feature?(user.account, :real_time_collaboration) &&
    Features.FeatureGate.can_access_feature?(user.account, String.to_atom(enhancement_type))
  end

  defp generate_channel_name(portfolio, enhancement_type) do
    enhancement_names = %{
      "voice_over" => "Voice Introduction",
      "writing" => "Content Enhancement",
      "design" => "Visual Design",
      "music" => "Background Music",
      "quarterly_update" => "Portfolio Update",
      "feedback" => "Portfolio Review"
    }

    enhancement_name = Map.get(enhancement_names, enhancement_type, "Enhancement")
    "#{portfolio.title} - #{enhancement_name}"
  end

  defp build_featured_content(portfolio, enhancement_type) do
    [%{
      "type" => "portfolio",
      "id" => portfolio.id,
      "enhancement_type" => enhancement_type,
      "started_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }]
  end

  defp build_channel_metadata(portfolio, enhancement_type, user) do
    # Mock quality score calculation for now
    quality_score = %{total: 65, content: 70, visual: 60, engagement: 65, polish: 60}

    %{
      "portfolio_id" => portfolio.id,
      "enhancement_type" => enhancement_type,
      "user_id" => user.id,
      "quality_score_at_start" => quality_score,
      "started_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "expected_duration" => get_expected_duration(enhancement_type),
      "milestones" => get_enhancement_milestones(enhancement_type),
      "progress_percentage" => 0,
      "collaborator_count" => 0
    }
  end

  defp get_expected_duration(enhancement_type) do
    case enhancement_type do
      "voice_over" -> "30-45 minutes"
      "writing" -> "2-3 hours"
      "design" -> "1-2 hours"
      "music" -> "45-60 minutes"
      _ -> "1-2 hours"
    end
  end

  defp get_enhancement_milestones(enhancement_type) do
    case enhancement_type do
      "voice_over" -> [
        %{name: "Script Preparation", percentage: 25},
        %{name: "Recording Session", percentage: 60},
        %{name: "Audio Editing", percentage: 85},
        %{name: "Integration", percentage: 100}
      ]
      "writing" -> [
        %{name: "Content Audit", percentage: 20},
        %{name: "Outline Creation", percentage: 40},
        %{name: "Writing & Revision", percentage: 80},
        %{name: "Final Polish", percentage: 100}
      ]
      "design" -> [
        %{name: "Design Analysis", percentage: 25},
        %{name: "Concept Development", percentage: 50},
        %{name: "Visual Implementation", percentage: 85},
        %{name: "Final Refinement", percentage: 100}
      ]
      _ -> [
        %{name: "Planning", percentage: 25},
        %{name: "Execution", percentage: 75},
        %{name: "Completion", percentage: 100}
      ]
    end
  end

  # Mock helper functions - replace with actual implementations
  defp get_required_skills_for_enhancement(enhancement_type) do
    case enhancement_type do
      "voice_over" -> ["voice acting", "audio editing", "recording"]
      "writing" -> ["copywriting", "content writing", "editing"]
      "design" -> ["graphic design", "ui design", "visual design"]
      "music" -> ["music production", "audio mixing", "composition"]
      _ -> []
    end
  end

  defp find_reciprocal_matches(enhancement_type, requesting_user) do
    # Mock implementation - replace with actual query
    []
  end

  defp get_reciprocal_enhancement_types(enhancement_type) do
    case enhancement_type do
      "voice_over" -> ["writing", "design"]
      "writing" -> ["voice_over", "design"]
      "design" -> ["voice_over", "writing"]
      "music" -> ["voice_over", "writing", "design"]
      _ -> []
    end
  end

  defp get_user_primary_skills(user_id) do
    # Mock implementation - replace with actual query
    ["writing", "editing"]
  end

    defp analyze_portfolio_quality(portfolio) do
    # Use the same quality analysis as in helpers
    FrestylWeb.PortfolioHubLive.Helpers.calculate_portfolio_quality_score(portfolio)
  end

  # Or if you prefer to keep it separate:
  defp analyze_portfolio_quality_local(portfolio) do
    %{
      total: 75,
      content: 80,
      visual: 70,
      engagement: 75,
      polish: 75,
      breakdown: %{
        has_voice_intro: false,
        content_quality: 70,
        visual_consistency: true,
        professional_media: false,
        engagement_elements: 2
      }
    }
  end
end
