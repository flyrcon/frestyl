# lib/frestyl/calendar/portfolio_health_analyzer.ex
defmodule Frestyl.Calendar.PortfolioHealthAnalyzer do
  @moduledoc """
  Analyzes portfolio health and generates intelligent content suggestions
  for the calendar system.
  """

  import Ecto.Query
  alias Frestyl.{Repo, Portfolios}
  alias Frestyl.Calendar.{ContentSuggestion, HealthMetric}

  # Health scoring thresholds
  @freshness_thresholds %{
    excellent: 7,    # Updated within 7 days
    good: 30,        # Updated within 30 days
    fair: 90,        # Updated within 90 days
    poor: 180        # Updated more than 180 days ago
  }

  @completeness_weights %{
    hero_section: 0.20,
    about_section: 0.15,
    skills_section: 0.15,
    projects_section: 0.25,
    testimonials_section: 0.10,
    contact_section: 0.10,
    social_links: 0.05
  }

  def analyze_portfolio_health(portfolio) do
    health_metrics = %{
      completeness_score: calculate_completeness_score(portfolio),
      freshness_score: calculate_freshness_score(portfolio),
      engagement_score: calculate_engagement_score(portfolio),
      seo_score: calculate_seo_score(portfolio),
      stale_sections: identify_stale_sections(portfolio),
      missing_elements: identify_missing_elements(portfolio),
      optimization_opportunities: identify_optimization_opportunities(portfolio)
    }

    # Generate calendar suggestions based on health analysis
    suggestions = generate_health_based_suggestions(portfolio, health_metrics)

    # Store or update health metrics
    store_health_metrics(portfolio, health_metrics)

    %{
      health_metrics: health_metrics,
      suggestions: suggestions,
      overall_score: calculate_overall_score(health_metrics),
      next_review_date: calculate_next_review_date(health_metrics)
    }
  end

  def analyze_user_portfolios(user_id) do
    portfolios = Portfolios.list_user_portfolios(user_id)

    portfolio_analyses = Enum.map(portfolios, &analyze_portfolio_health/1)

    %{
      portfolio_count: length(portfolios),
      analyses: portfolio_analyses,
      overall_health: calculate_user_overall_health(portfolio_analyses),
      priority_suggestions: get_priority_suggestions(portfolio_analyses),
      recommended_schedule: generate_maintenance_schedule(portfolio_analyses)
    }
  end

  # Completeness Analysis
  defp calculate_completeness_score(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    section_scores = Enum.map(@completeness_weights, fn {section_type, weight} ->
      section = Enum.find(sections, &(&1.section_type == to_string(section_type)))
      section_completeness = calculate_section_completeness(section, section_type)
      section_completeness * weight
    end)

    Enum.sum(section_scores) * 100 |> Float.round(2)
  end

  defp calculate_section_completeness(nil, _section_type), do: 0.0
  defp calculate_section_completeness(section, section_type) do
    case section_type do
      :hero_section -> calculate_hero_completeness(section)
      :about_section -> calculate_about_completeness(section)
      :skills_section -> calculate_skills_completeness(section)
      :projects_section -> calculate_projects_completeness(section)
      :testimonials_section -> calculate_testimonials_completeness(section)
      :contact_section -> calculate_contact_completeness(section)
      :social_links -> calculate_social_completeness(section)
      _ -> 0.5  # Default 50% for unknown sections
    end
  end

  defp calculate_hero_completeness(section) do
    content = section.content || %{}

    checks = [
      has_value?(content["title"]),
      has_value?(content["subtitle"]),
      has_value?(content["hero_image"]) || has_value?(content["avatar"]),
      has_value?(content["cta_text"]),
      has_value?(content["background_image"])
    ]

    Enum.count(checks, & &1) / length(checks)
  end

  defp calculate_about_completeness(section) do
    content = section.content || %{}

    checks = [
      has_value?(content["bio"]) && String.length(content["bio"]) > 100,
      has_value?(content["mission"]),
      has_value?(content["experience_years"]),
      has_value?(content["education"]),
      has_value?(content["certifications"])
    ]

    Enum.count(checks, & &1) / length(checks)
  end

  defp calculate_skills_completeness(section) do
    content = section.content || %{}
    skills = content["skills"] || []

    skill_count = length(skills)
    has_categories = Enum.any?(skills, &has_value?(&1["category"]))
    has_levels = Enum.any?(skills, &has_value?(&1["level"]))

    cond do
      skill_count >= 10 && has_categories && has_levels -> 1.0
      skill_count >= 5 && has_categories -> 0.8
      skill_count >= 3 -> 0.6
      skill_count >= 1 -> 0.4
      true -> 0.0
    end
  end

  defp calculate_projects_completeness(section) do
    content = section.content || %{}
    projects = content["projects"] || []

    project_count = length(projects)
    complete_projects = Enum.count(projects, &is_project_complete?/1)

    cond do
      project_count >= 5 && complete_projects >= 3 -> 1.0
      project_count >= 3 && complete_projects >= 2 -> 0.8
      project_count >= 2 && complete_projects >= 1 -> 0.6
      project_count >= 1 -> 0.4
      true -> 0.0
    end
  end

  defp calculate_testimonials_completeness(section) do
    content = section.content || %{}
    testimonials = content["testimonials"] || []

    testimonial_count = length(testimonials)
    recent_testimonials = Enum.count(testimonials, &is_testimonial_recent?/1)

    cond do
      testimonial_count >= 5 && recent_testimonials >= 2 -> 1.0
      testimonial_count >= 3 && recent_testimonials >= 1 -> 0.8
      testimonial_count >= 2 -> 0.6
      testimonial_count >= 1 -> 0.4
      true -> 0.0
    end
  end

  defp calculate_contact_completeness(section) do
    content = section.content || %{}

    checks = [
      has_value?(content["email"]),
      has_value?(content["phone"]) || has_value?(content["calendar_link"]),
      has_value?(content["location"]),
      has_value?(content["availability"])
    ]

    Enum.count(checks, & &1) / length(checks)
  end

  defp calculate_social_completeness(section) do
    content = section.content || %{}
    social_links = content["social_links"] || %{}

    link_count = map_size(social_links)

    cond do
      link_count >= 4 -> 1.0
      link_count >= 3 -> 0.8
      link_count >= 2 -> 0.6
      link_count >= 1 -> 0.4
      true -> 0.0
    end
  end

  # Freshness Analysis
  defp calculate_freshness_score(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)
    now = DateTime.utc_now()

    section_scores = Enum.map(sections, fn section ->
      days_since_update = DateTime.diff(now, section.updated_at, :day)
      calculate_freshness_for_days(days_since_update)
    end)

    if Enum.empty?(section_scores) do
      0.0
    else
      Enum.sum(section_scores) / length(section_scores) * 100 |> Float.round(2)
    end
  end

  defp calculate_freshness_for_days(days) do
    cond do
      days <= @freshness_thresholds.excellent -> 1.0
      days <= @freshness_thresholds.good -> 0.8
      days <= @freshness_thresholds.fair -> 0.6
      days <= @freshness_thresholds.poor -> 0.4
      true -> 0.2
    end
  end

  # Engagement Analysis (mock implementation - replace with real analytics)
  defp calculate_engagement_score(portfolio) do
    # This would integrate with your analytics system
    # For now, return a mock score based on portfolio completeness
    base_score = if portfolio.visibility == :public, do: 70, else: 30

    # Add randomization for demo purposes
    variation = :rand.uniform(30) - 15
    max(0, min(100, base_score + variation)) |> Float.round(2)
  end

  # SEO Analysis
  defp calculate_seo_score(portfolio) do
    checks = [
      has_value?(portfolio.title) && String.length(portfolio.title) < 60,
      has_value?(portfolio.description) && String.length(portfolio.description) < 160,
      has_value?(portfolio.slug),
      portfolio.visibility in [:public, :link_only],
      has_custom_domain?(portfolio)
    ]

    Enum.count(checks, & &1) / length(checks) * 100 |> Float.round(2)
  end

  # Identification Functions
  defp identify_stale_sections(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)
    now = DateTime.utc_now()
    stale_threshold = @freshness_thresholds.fair

    sections
    |> Enum.filter(fn section ->
      DateTime.diff(now, section.updated_at, :day) > stale_threshold
    end)
    |> Enum.map(& &1.section_type)
  end

  defp identify_missing_elements(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)
    existing_types = Enum.map(sections, & &1.section_type)

    required_sections = ["hero", "about", "skills", "projects", "contact"]
    missing_sections = required_sections -- existing_types

    missing_content = []
    |> check_missing_hero_elements(sections)
    |> check_missing_project_elements(sections)
    |> check_missing_testimonials(sections)

    missing_sections ++ missing_content
  end

  defp identify_optimization_opportunities(portfolio) do
    opportunities = []

    # Check for image optimization opportunities
    opportunities = if needs_image_optimization?(portfolio) do
      [%{type: "image_optimization", priority: "medium", estimated_impact: "seo"}] ++ opportunities
    else
      opportunities
    end

    # Check for content expansion opportunities
    opportunities = if needs_content_expansion?(portfolio) do
      [%{type: "content_expansion", priority: "high", estimated_impact: "engagement"}] ++ opportunities
    else
      opportunities
    end

    # Check for testimonial opportunities
    opportunities = if needs_testimonials?(portfolio) do
      [%{type: "testimonial_collection", priority: "high", estimated_impact: "conversion"}] ++ opportunities
    else
      opportunities
    end

    opportunities
  end

  # Suggestion Generation
  defp generate_health_based_suggestions(portfolio, health_metrics) do
    suggestions = []

    # Critical completeness issues
    suggestions = if health_metrics.completeness_score < 50 do
      critical_suggestions = generate_completeness_suggestions(portfolio, health_metrics)
      suggestions ++ critical_suggestions
    else
      suggestions
    end

    # Freshness issues
    suggestions = if health_metrics.freshness_score < 60 do
      freshness_suggestions = generate_freshness_suggestions(portfolio, health_metrics)
      suggestions ++ freshness_suggestions
    else
      suggestions
    end

    # SEO opportunities
    suggestions = if health_metrics.seo_score < 80 do
      seo_suggestions = generate_seo_suggestions(portfolio, health_metrics)
      suggestions ++ seo_suggestions
    else
      suggestions
    end

    # Engagement opportunities
    suggestions = if health_metrics.engagement_score < 70 do
      engagement_suggestions = generate_engagement_suggestions(portfolio, health_metrics)
      suggestions ++ engagement_suggestions
    else
      suggestions
    end

    suggestions
  end

  defp generate_completeness_suggestions(portfolio, health_metrics) do
    suggestions = []

    Enum.reduce(health_metrics.missing_elements, suggestions, fn missing, acc ->
      suggestion = case missing do
        "hero" ->
          %{
            type: "portfolio_update",
            title: "Complete Hero Section",
            description: "Add a compelling hero section with title, subtitle, and image",
            priority: "high",
            estimated_time: 30,
            due_in_days: 3
          }

        "projects" ->
          %{
            type: "project_addition",
            title: "Add Project Showcase",
            description: "Add at least 3 completed projects to showcase your work",
            priority: "critical",
            estimated_time: 60,
            due_in_days: 7
          }

        "testimonials" ->
          %{
            type: "testimonial_request",
            title: "Collect Client Testimonials",
            description: "Reach out to recent clients for testimonials",
            priority: "high",
            estimated_time: 45,
            due_in_days: 14
          }

        _ ->
          %{
            type: "portfolio_update",
            title: "Complete #{String.capitalize(missing)} Section",
            description: "Add missing content to improve portfolio completeness",
            priority: "medium",
            estimated_time: 20,
            due_in_days: 7
          }
      end

      [suggestion | acc]
    end)
  end

  defp generate_freshness_suggestions(portfolio, health_metrics) do
    stale_sections = health_metrics.stale_sections

    Enum.map(stale_sections, fn section ->
      %{
        type: "content_refresh",
        title: "Update #{String.capitalize(section)} Section",
        description: "This section hasn't been updated in over 3 months",
        priority: "medium",
        estimated_time: 15,
        due_in_days: 7,
        section: section
      }
    end)
  end

  defp generate_seo_suggestions(portfolio, _health_metrics) do
    suggestions = []

    suggestions = if !has_value?(portfolio.description) || String.length(portfolio.description) > 160 do
      [%{
        type: "seo_optimization",
        title: "Optimize Meta Description",
        description: "Write a compelling 150-character description for search engines",
        priority: "medium",
        estimated_time: 10,
        due_in_days: 3
      } | suggestions]
    else
      suggestions
    end

    suggestions = if portfolio.visibility == :private do
      [%{
        type: "visibility_update",
        title: "Make Portfolio Public",
        description: "Consider making your portfolio public for better discoverability",
        priority: "low",
        estimated_time: 5,
        due_in_days: 14
      } | suggestions]
    else
      suggestions
    end

    suggestions
  end

  defp generate_engagement_suggestions(portfolio, _health_metrics) do
    [
      %{
        type: "content_strategy",
        title: "Add Recent Achievements",
        description: "Share recent work or accomplishments to keep content fresh",
        priority: "medium",
        estimated_time: 20,
        due_in_days: 7
      },
      %{
        type: "call_to_action",
        title: "Update Call-to-Action",
        description: "Review and optimize your portfolio's call-to-action buttons",
        priority: "low",
        estimated_time: 15,
        due_in_days: 14
      }
    ]
  end

  # Helper Functions
  defp has_value?(nil), do: false
  defp has_value?(""), do: false
  defp has_value?(value) when is_binary(value), do: String.trim(value) != ""
  defp has_value?(value) when is_list(value), do: length(value) > 0
  defp has_value?(value) when is_map(value), do: map_size(value) > 0
  defp has_value?(_), do: true

  defp is_project_complete?(project) do
    required_fields = ["title", "description", "image"]
    Enum.all?(required_fields, &has_value?(project[&1]))
  end

  defp is_testimonial_recent?(testimonial) do
    case testimonial["date"] do
      nil -> false
      date_string ->
        case Date.from_iso8601(date_string) do
          {:ok, date} -> Date.diff(Date.utc_today(), date) <= 365
          _ -> false
        end
    end
  end

  defp has_custom_domain?(portfolio) do
    # This would check your custom domain system
    false
  end

  defp needs_image_optimization?(portfolio) do
    # Check if portfolio has large unoptimized images
    # This would integrate with your media system
    false
  end

  defp needs_content_expansion?(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)
    total_content_length = Enum.reduce(sections, 0, fn section, acc ->
      content = section.content || %{}
      text_content = extract_text_content(content)
      acc + String.length(text_content)
    end)

    total_content_length < 1000  # Less than 1000 characters total
  end

  defp needs_testimonials?(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)
    testimonial_section = Enum.find(sections, &(&1.section_type == "testimonials"))

    case testimonial_section do
      nil -> true
      section ->
        testimonials = get_in(section.content, ["testimonials"]) || []
        length(testimonials) < 3
    end
  end

  defp extract_text_content(content) when is_map(content) do
    content
    |> Map.values()
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
  end
  defp extract_text_content(_), do: ""

  defp check_missing_hero_elements(missing, sections) do
    hero_section = Enum.find(sections, &(&1.section_type == "hero"))

    case hero_section do
      nil -> ["hero_image", "hero_cta" | missing]
      section ->
        content = section.content || %{}
        elements = []

        elements = if !has_value?(content["hero_image"]), do: ["hero_image" | elements], else: elements
        elements = if !has_value?(content["cta_text"]), do: ["hero_cta" | elements], else: elements

        elements ++ missing
    end
  end

  defp check_missing_project_elements(missing, sections) do
    projects_section = Enum.find(sections, &(&1.section_type == "projects"))

    case projects_section do
      nil -> ["project_showcase" | missing]
      section ->
        projects = get_in(section.content, ["projects"]) || []
        if length(projects) < 3, do: ["more_projects" | missing], else: missing
    end
  end

  defp check_missing_testimonials(missing, sections) do
    testimonials_section = Enum.find(sections, &(&1.section_type == "testimonials"))

    case testimonials_section do
      nil -> ["testimonials" | missing]
      section ->
        testimonials = get_in(section.content, ["testimonials"]) || []
        if length(testimonials) < 2, do: ["more_testimonials" | missing], else: missing
    end
  end

  # Scoring and Storage Functions
  defp calculate_overall_score(health_metrics) do
    weights = %{
      completeness_score: 0.40,
      freshness_score: 0.25,
      engagement_score: 0.20,
      seo_score: 0.15
    }

    weighted_sum = Enum.reduce(weights, 0, fn {metric, weight}, acc ->
      score = Map.get(health_metrics, metric, 0)
      acc + (score * weight)
    end)

    Float.round(weighted_sum, 2)
  end

  defp calculate_next_review_date(health_metrics) do
    # Schedule next review based on overall health
    overall_score = calculate_overall_score(health_metrics)

    days_until_review = cond do
      overall_score >= 90 -> 30  # Monthly for excellent portfolios
      overall_score >= 75 -> 21  # Every 3 weeks for good portfolios
      overall_score >= 60 -> 14  # Bi-weekly for fair portfolios
      true -> 7                  # Weekly for poor portfolios
    end

    Date.add(Date.utc_today(), days_until_review)
  end

  defp calculate_user_overall_health(portfolio_analyses) do
    if Enum.empty?(portfolio_analyses) do
      %{overall_score: 0, health_grade: "F", recommendation: "Create your first portfolio"}
    else
      scores = Enum.map(portfolio_analyses, & &1.overall_score)
      average_score = Enum.sum(scores) / length(scores)

      %{
        overall_score: Float.round(average_score, 2),
        health_grade: score_to_grade(average_score),
        portfolio_count: length(portfolio_analyses),
        best_score: Enum.max(scores),
        worst_score: Enum.min(scores)
      }
    end
  end

  defp get_priority_suggestions(portfolio_analyses) do
    all_suggestions = Enum.flat_map(portfolio_analyses, & &1.suggestions)

    all_suggestions
    |> Enum.filter(&(&1.priority in ["critical", "high"]))
    |> Enum.sort_by(&priority_weight/1, :desc)
    |> Enum.take(5)
  end

  defp generate_maintenance_schedule(portfolio_analyses) do
    # Generate a smart maintenance schedule based on portfolio health
    %{
      daily: generate_daily_tasks(portfolio_analyses),
      weekly: generate_weekly_tasks(portfolio_analyses),
      monthly: generate_monthly_tasks(portfolio_analyses),
      quarterly: generate_quarterly_tasks(portfolio_analyses)
    }
  end

  defp generate_daily_tasks(_portfolio_analyses) do
    [
      "Quick portfolio health check (2 minutes)",
      "Review and respond to any new inquiries",
      "Check for broken links or outdated information"
    ]
  end

  defp generate_weekly_tasks(portfolio_analyses) do
    base_tasks = [
      "Update availability status",
      "Review portfolio analytics",
      "Add any new achievements or projects"
    ]

    # Add specific tasks based on portfolio health
    priority_suggestions = get_priority_suggestions(portfolio_analyses)
    suggestion_tasks = Enum.map(priority_suggestions, & &1.title)

    base_tasks ++ Enum.take(suggestion_tasks, 2)
  end

  defp generate_monthly_tasks(_portfolio_analyses) do
    [
      "Comprehensive portfolio review and update",
      "Reach out to recent clients for testimonials",
      "Update skills and certifications",
      "Review and optimize SEO elements",
      "Analyze portfolio performance metrics"
    ]
  end

  defp generate_quarterly_tasks(_portfolio_analyses) do
    [
      "Complete portfolio redesign review",
      "Update pricing and service offerings",
      "Conduct competitive analysis",
      "Plan content strategy for next quarter",
      "Review and update professional photos"
    ]
  end

  defp store_health_metrics(portfolio, health_metrics) do
    # This would store the metrics in the database
    # For now, we'll just return the metrics
    health_metrics
  end

  # Utility Functions
  defp score_to_grade(score) when score >= 90, do: "A"
  defp score_to_grade(score) when score >= 80, do: "B"
  defp score_to_grade(score) when score >= 70, do: "C"
  defp score_to_grade(score) when score >= 60, do: "D"
  defp score_to_grade(_), do: "F"

  defp priority_weight("critical"), do: 4
  defp priority_weight("high"), do: 3
  defp priority_weight("medium"), do: 2
  defp priority_weight("low"), do: 1
  defp priority_weight(_), do: 0
end
