defmodule Frestyl.CareerJourney.TimelineManager do
  def get_timeline_features(subscription_tier) do
    base_features = %{
      basic_timeline: true,
      standard_templates: 3,
      export_formats: [:pdf]
    }

    case subscription_tier do
      :personal -> base_features

      :professional -> Map.merge(base_features, %{
        advanced_analytics: true,
        custom_milestones: true,
        team_portfolio_management: true,
        advanced_templates: 10,
        career_insights: true,
        goal_tracking: true
      })

      :enterprise -> Map.merge(base_features, %{
        recruitment_integration: true,
        candidate_tracking: true,
        bulk_career_analysis: true,
        custom_integrations: true,
        advanced_reporting: true,
        team_analytics: true,
        api_access: true
      })
    end
  end
end
