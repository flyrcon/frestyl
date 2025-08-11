# lib/frestyl/calendar/intelligence_engine.ex
defmodule Frestyl.Calendar.IntelligenceEngine do
  @moduledoc """
  Main orchestrator for content calendar intelligence.
  Aggregates events from multiple sources and applies smart prioritization.
  """

  import Ecto.Query
  alias Frestyl.{Repo, Calendar, Portfolios}
  alias Frestyl.Calendar.{Event, ContentSuggestion, PortfolioHealthAnalyzer}
  alias Frestyl.Features.TierManager

  def generate_intelligent_calendar(user, account, date_range) do
    start_date = date_range.start_date
    end_date = date_range.end_date

    # Get base calendar events
    base_events = Calendar.get_user_visible_events(user, account,
      start_date: start_date,
      end_date: end_date
    )

    # Generate intelligent suggestions and events
    enhanced_events = base_events
    |> add_portfolio_health_events(user, account)
    |> add_industry_opportunity_events(user, account)
    |> add_revenue_optimization_events(user, account)
    |> add_skill_development_events(user, account)
    |> add_competitive_intelligence_events(user, account)
    |> prioritize_and_rank_events(user, account)
    |> generate_workflow_suggestions(user, account)

    %{
      events: enhanced_events,
      suggestions: get_pending_suggestions(user.id),
      health_summary: get_portfolio_health_summary(user.id),
      recommended_actions: get_recommended_actions(user, account),
      calendar_stats: generate_calendar_stats(enhanced_events)
    }
  end

  def add_portfolio_health_events(events, user, account) do
    user_portfolios = Portfolios.list_user_portfolios(user.id)

    health_events = Enum.flat_map(user_portfolios, fn portfolio ->
      analysis = PortfolioHealthAnalyzer.analyze_portfolio_health(portfolio)
      convert_health_suggestions_to_events(analysis.suggestions, portfolio, user, account)
    end)

    events ++ health_events
  end

  def add_industry_opportunity_events(events, user, _account) do
    # Mock industry events - would integrate with external APIs
    industry_events = [
      create_industry_event("Web Dev Conference Registration Deadline", user,
        DateTime.add(DateTime.utc_now(), 14 * 24 * 60 * 60, :second)),
      create_industry_event("React 19 Release - Update Skills Section", user,
        DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60, :second)),
      create_industry_event("Design System Trends Webinar", user,
        DateTime.add(DateTime.utc_now(), 3 * 24 * 60 * 60, :second))
    ]

    events ++ industry_events
  end

  def add_revenue_optimization_events(events, user, account) do
    # Analyze revenue patterns and suggest optimization opportunities
    revenue_events = []

    # Check if user should consider rate increases
    revenue_events = if should_suggest_rate_increase?(user, account) do
      rate_event = create_revenue_event(
        "Review and Update Service Rates",
        "Your portfolio views have increased 40% - consider updating your rates",
        user,
        DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60, :second),
        "rate_review"
      )
      [rate_event | revenue_events]
    else
      revenue_events
    end

    # Check for service expansion opportunities
    revenue_events = if should_suggest_service_expansion?(user, account) do
      service_event = create_revenue_event(
        "Consider Adding New Service Offering",
        "Based on your skills, consider offering React consulting",
        user,
        DateTime.add(DateTime.utc_now(), 14 * 24 * 60 * 60, :second),
        "service_expansion"
      )
      [service_event | revenue_events]
    else
      revenue_events
    end

    events ++ revenue_events
  end

  def add_skill_development_events(events, user, _account) do
    # Analyze user's current skills and suggest trending skills to learn
    skill_events = []

    # Get user's current skills from portfolios
    current_skills = get_user_current_skills(user.id)
    trending_skills = get_trending_skills_for_user(current_skills)

    skill_events = Enum.map(trending_skills, fn skill ->
      create_skill_event(skill, user)
    end)

    events ++ skill_events
  end

  def add_competitive_intelligence_events(events, user, _account) do
    # Mock competitive intelligence - would integrate with market analysis
    competitive_events = [
      create_competitive_event(
        "Competitor Analysis: Check Similar Portfolios",
        "Monthly review of portfolios in your field",
        user,
        DateTime.add(DateTime.utc_now(), 30 * 24 * 60 * 60, :second)
      )
    ]

    events ++ competitive_events
  end

  def prioritize_and_rank_events(events, user, account) do
    user_tier = TierManager.get_user_tier(user)

    events
    |> Enum.map(&calculate_event_priority(&1, user, account))
    |> Enum.sort_by(&get_sort_weight/1, :desc)
  end

  def generate_workflow_suggestions(events, user, account) do
    # Group related events into workflows
    workflow_events = Enum.filter(events, &has_workflow_potential?/1)

    workflows = group_events_into_workflows(workflow_events, user, account)

    # Add workflow metadata to events
    Enum.map(events, fn event ->
      case find_event_workflow(event, workflows) do
        nil -> event
        workflow -> Map.put(event, :suggested_workflow, workflow)
      end
    end)
  end

  # Helper Functions for Event Creation
  defp convert_health_suggestions_to_events(suggestions, portfolio, user, account) do
    Enum.map(suggestions, fn suggestion ->
      due_date = DateTime.add(DateTime.utc_now(),
        (suggestion.due_in_days || 7) * 24 * 60 * 60, :second)

      %Event{
        id: Ecto.UUID.generate(),
        title: suggestion.title,
        description: suggestion.description,
        starts_at: due_date,
        ends_at: DateTime.add(due_date, suggestion.estimated_time * 60, :second),
        content_type: suggestion.type,
        priority_level: suggestion.priority,
        ownership_type: "suggested",
        completion_status: "pending",
        auto_generated: true,
        estimated_time_minutes: suggestion.estimated_time,
        revenue_impact: map_suggestion_to_revenue_impact(suggestion),
        portfolio_section_affected: Map.get(suggestion, :section),
        workflow_template: suggest_workflow_template(suggestion.type),
        creator_id: user.id,
        account_id: account.id,
        portfolio_id: portfolio.id,
        metadata: %{
          suggestion_source: "portfolio_health",
          rationale: suggestion.description
        }
      }
    end)
  end

  defp create_industry_event(title, user, due_date) do
    %Event{
      id: Ecto.UUID.generate(),
      title: title,
      description: "Industry opportunity - stay competitive",
      starts_at: due_date,
      ends_at: DateTime.add(due_date, 30 * 60, :second),
      content_type: "industry_event",
      priority_level: "medium",
      ownership_type: "fyi",
      completion_status: "pending",
      auto_generated: true,
      estimated_time_minutes: 30,
      revenue_impact: "low",
      external_source: "industry_feed",
      industry_relevance_score: Decimal.new("0.75"),
      creator_id: user.id,
      metadata: %{
        source: "industry_intelligence",
        category: "learning_opportunity"
      }
    }
  end

  defp create_revenue_event(title, description, user, due_date, revenue_type) do
    %Event{
      id: Ecto.UUID.generate(),
      title: title,
      description: description,
      starts_at: due_date,
      ends_at: DateTime.add(due_date, 45 * 60, :second),
      content_type: "revenue_review",
      priority_level: "high",
      ownership_type: "suggested",
      completion_status: "pending",
      auto_generated: true,
      estimated_time_minutes: 45,
      revenue_impact: "high",
      workflow_template: "revenue_optimization",
      creator_id: user.id,
      metadata: %{
        revenue_type: revenue_type,
        source: "revenue_intelligence"
      }
    }
  end

  defp create_skill_event(skill, user) do
    due_date = DateTime.add(DateTime.utc_now(), 21 * 24 * 60 * 60, :second)

    %Event{
      id: Ecto.UUID.generate(),
      title: "Learn #{skill.name}",
      description: "#{skill.name} is trending in your field (+#{skill.growth_percentage}%)",
      starts_at: due_date,
      ends_at: DateTime.add(due_date, 60 * 60, :second),
      content_type: "skill_showcase",
      priority_level: skill.priority,
      ownership_type: "suggested",
      completion_status: "pending",
      auto_generated: true,
      estimated_time_minutes: 60,
      revenue_impact: skill.revenue_impact,
      workflow_template: "skill_development",
      creator_id: user.id,
      metadata: %{
        skill_name: skill.name,
        trend_data: skill.trend_data,
        source: "skill_intelligence"
      }
    }
  end

  defp create_competitive_event(title, description, user, due_date) do
    %Event{
      id: Ecto.UUID.generate(),
      title: title,
      description: description,
      starts_at: due_date,
      ends_at: DateTime.add(due_date, 30 * 60, :second),
      content_type: "general",
      priority_level: "low",
      ownership_type: "suggested",
      completion_status: "pending",
      auto_generated: true,
      estimated_time_minutes: 30,
      revenue_impact: "medium",
      creator_id: user.id,
      metadata: %{
        source: "competitive_intelligence"
      }
    }
  end

  # Priority Calculation
  defp calculate_event_priority(event, user, account) do
    base_priority = Event.get_priority_weight(event.priority_level)

    # Adjust priority based on various factors
    priority_adjustments = []

    # Revenue impact adjustment
    priority_adjustments = case event.revenue_impact do
      "critical" -> [3.0 | priority_adjustments]
      "high" -> [2.0 | priority_adjustments]
      "medium" -> [1.5 | priority_adjustments]
      _ -> [1.0 | priority_adjustments]
    end

    # Overdue adjustment
    priority_adjustments = if is_overdue?(event) do
      [2.0 | priority_adjustments]
    else
      [1.0 | priority_adjustments]
    end

    # Portfolio health urgency
    priority_adjustments = if is_portfolio_health_critical?(event, user) do
      [1.8 | priority_adjustments]
    else
      [1.0 | priority_adjustments]
    end

    # Account tier bonus for certain events
    priority_adjustments = if should_boost_for_tier?(event, account) do
      [1.3 | priority_adjustments]
    else
      [1.0 | priority_adjustments]
    end

    final_priority = Enum.reduce(priority_adjustments, base_priority, &*/2)

    Map.put(event, :calculated_priority, final_priority)
  end

  defp get_sort_weight(event) do
    base_weight = Map.get(event, :calculated_priority, 0)

    # Time urgency weight
    time_weight = case time_until_due(event) do
      days when days < 1 -> 10.0
      days when days < 3 -> 5.0
      days when days < 7 -> 2.0
      _ -> 1.0
    end

    base_weight * time_weight
  end

  # Workflow Organization
  defp has_workflow_potential?(event) do
    event.workflow_template != nil ||
    event.content_type in ["portfolio_update", "skill_showcase", "revenue_review"]
  end

  defp group_events_into_workflows(events, _user, _account) do
    events
    |> Enum.group_by(&(&1.workflow_template || &1.content_type))
    |> Enum.map(fn {template, template_events} ->
      %{
        template: template,
        events: template_events,
        total_time: Enum.sum(Enum.map(template_events, &(&1.estimated_time_minutes || 0))),
        priority: calculate_workflow_priority(template_events)
      }
    end)
    |> Enum.filter(&(length(&1.events) > 1))  # Only suggest workflows with multiple events
  end

  defp find_event_workflow(event, workflows) do
    Enum.find(workflows, fn workflow ->
      Enum.any?(workflow.events, &(&1.id == event.id))
    end)
  end

  defp calculate_workflow_priority(events) do
    priorities = Enum.map(events, &Event.get_priority_weight(&1.priority_level))
    Enum.max(priorities)
  end

  # Supporting Functions
  defp get_pending_suggestions(user_id) do
    from(s in ContentSuggestion,
      where: s.user_id == ^user_id and s.status == "pending",
      order_by: [desc: s.priority_score, desc: s.inserted_at],
      limit: 10
    )
    |> Repo.all()
  end

  defp get_portfolio_health_summary(user_id) do
    user_portfolios = Portfolios.list_user_portfolios(user_id)

    if Enum.empty?(user_portfolios) do
      %{
        overall_score: 0,
        portfolios_analyzed: 0,
        critical_issues: 0,
        recommendations: []
      }
    else
      analyses = Enum.map(user_portfolios, &PortfolioHealthAnalyzer.analyze_portfolio_health/1)

      %{
        overall_score: calculate_average_health_score(analyses),
        portfolios_analyzed: length(analyses),
        critical_issues: count_critical_issues(analyses),
        recommendations: get_top_recommendations(analyses, 3)
      }
    end
  end

  defp get_recommended_actions(user, account) do
    # Generate personalized action recommendations
    tier = TierManager.get_user_tier(user)

    base_actions = [
      %{
        title: "Review Portfolio Health",
        description: "Check for outdated content and missing elements",
        priority: "medium",
        estimated_time: 15
      }
    ]

    # Add tier-specific recommendations
    tier_actions = case tier do
      "personal" ->
        [%{
          title: "Consider Upgrading to Creator",
          description: "Unlock calendar features and portfolio tools",
          priority: "low",
          estimated_time: 5
        }]
      "creator" ->
        [%{
          title: "Optimize for Revenue",
          description: "Review pricing and service offerings",
          priority: "medium",
          estimated_time: 30
        }]
      _ -> []
    end

    base_actions ++ tier_actions
  end

  defp generate_calendar_stats(events) do
    now = DateTime.utc_now()

    %{
      total_events: length(events),
      overdue_events: Enum.count(events, &is_overdue?/1),
      this_week_events: Enum.count(events, &is_this_week?(&1, now)),
      auto_generated_events: Enum.count(events, &(&1.auto_generated)),
      high_priority_events: Enum.count(events, &(&1.priority_level in ["critical", "high"])),
      revenue_impacting_events: Enum.count(events, &(&1.revenue_impact in ["critical", "high", "medium"])),
      completion_rate: calculate_completion_rate(events)
    }
  end

  # Utility Functions
  defp map_suggestion_to_revenue_impact(suggestion) do
    case suggestion.type do
      "project_addition" -> "high"
      "testimonial_request" -> "medium"
      "skill_showcase" -> "medium"
      "portfolio_update" -> "low"
      _ -> "none"
    end
  end

  defp suggest_workflow_template(suggestion_type) do
    case suggestion_type do
      "portfolio_update" -> "portfolio_quarterly_update"
      "skill_showcase" -> "skill_development"
      "project_addition" -> "project_showcase_workflow"
      "testimonial_request" -> "testimonial_collection"
      _ -> nil
    end
  end

  defp should_suggest_rate_increase?(user, _account) do
    # Mock logic - would analyze actual portfolio metrics
    :rand.uniform() > 0.7  # 30% chance for demo
  end

  defp should_suggest_service_expansion?(user, _account) do
    # Mock logic - would analyze user skills and market demand
    :rand.uniform() > 0.8  # 20% chance for demo
  end

  defp get_user_current_skills(user_id) do
    # Mock implementation - would extract from portfolio skills sections
    ["React", "JavaScript", "CSS", "Node.js"]
  end

  defp get_trending_skills_for_user(current_skills) do
    # Mock trending skills data
    [
      %{
        name: "Next.js",
        growth_percentage: 45,
        priority: "high",
        revenue_impact: "high",
        trend_data: %{demand_increase: "45%", avg_rate_increase: "25%"}
      },
      %{
        name: "TypeScript",
        growth_percentage: 30,
        priority: "medium",
        revenue_impact: "medium",
        trend_data: %{demand_increase: "30%", avg_rate_increase: "15%"}
      }
    ]
  end

  defp is_overdue?(event) do
    case event.starts_at do
      nil -> false
      start_time -> DateTime.compare(DateTime.utc_now(), start_time) == :gt
    end
  end

  defp is_this_week?(event, now) do
    case event.starts_at do
      nil -> false
      start_time ->
        days_diff = DateTime.diff(start_time, now, :day)
        days_diff >= 0 && days_diff <= 7
    end
  end

  defp time_until_due(event) do
    case event.starts_at do
      nil -> 999
      start_time -> DateTime.diff(start_time, DateTime.utc_now(), :day)
    end
  end

  defp is_portfolio_health_critical?(event, user) do
    event.content_type in ["portfolio_update", "skill_showcase"] &&
    event.priority_level == "critical"
  end

  defp should_boost_for_tier?(event, account) do
    tier = TierManager.get_account_tier(account)

    case {tier, event.content_type} do
      {"professional", "revenue_review"} -> true
      {"enterprise", _} -> true
      _ -> false
    end
  end

  defp calculate_average_health_score(analyses) do
    if Enum.empty?(analyses) do
      0
    else
      scores = Enum.map(analyses, & &1.overall_score)
      Enum.sum(scores) / length(scores) |> Float.round(2)
    end
  end

  defp count_critical_issues(analyses) do
    Enum.reduce(analyses, 0, fn analysis, acc ->
      critical_suggestions = Enum.count(analysis.suggestions, &(&1.priority == "critical"))
      acc + critical_suggestions
    end)
  end

  defp get_top_recommendations(analyses, limit) do
    all_suggestions = Enum.flat_map(analyses, & &1.suggestions)

    all_suggestions
    |> Enum.filter(&(&1.priority in ["critical", "high"]))
    |> Enum.sort_by(&priority_score/1, :desc)
    |> Enum.take(limit)
    |> Enum.map(&format_recommendation/1)
  end

  defp priority_score(suggestion) do
    case suggestion.priority do
      "critical" -> 4
      "high" -> 3
      "medium" -> 2
      "low" -> 1
      _ -> 0
    end
  end

  defp format_recommendation(suggestion) do
    %{
      title: suggestion.title,
      description: suggestion.description,
      estimated_time: suggestion.estimated_time,
      priority: suggestion.priority
    }
  end

  defp calculate_completion_rate(events) do
    if Enum.empty?(events) do
      0
    else
      completed = Enum.count(events, &(&1.completion_status == "completed"))
      (completed / length(events) * 100) |> Float.round(1)
    end
  end
end
