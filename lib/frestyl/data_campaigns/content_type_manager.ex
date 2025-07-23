# File: lib/frestyl/data_campaigns/content_type_manager.ex

defmodule Frestyl.DataCampaigns.ContentTypeManager do
  @moduledoc """
  Manages different content types with specialized tracking, quality gates,
  and revenue models for blogs, videos, data stories, and more.
  """

  alias Frestyl.DataCampaigns.{Campaign, AdvancedTracker}
  alias Frestyl.Stories
  alias Frestyl.Studio.RecordingEngine
  alias Frestyl.Content

  # ============================================================================
  # BLOG POST CAMPAIGNS WITH CMS INTEGRATION
  # ============================================================================

  @doc """
  Creates blog post campaign with multi-platform publishing capabilities.
  """
  def create_blog_campaign(campaign_params, creator) do
    enhanced_params = Map.merge(campaign_params, %{
      "content_type" => :blog_post,
      "platform_integrations" => %{
        "publishing_platforms" => ["medium", "linkedin", "ghost", "wordpress"],
        "seo_optimization" => true,
        "cross_posting" => true,
        "analytics_tracking" => true
      },
      "minimum_contribution_threshold" => %{
        "word_count" => 1500,
        "unique_insights" => 2,
        "seo_score" => 70
      }
    })

    case Frestyl.DataCampaigns.create_campaign(enhanced_params, creator) do
      {:ok, campaign} ->
        # Setup blog-specific tracking
        initialize_blog_tracking(campaign.id)

        # Create CMS integration
        setup_blog_cms_integration(campaign.id, enhanced_params["platform_integrations"])

        {:ok, campaign}

      error -> error
    end
  end

  @doc """
  Tracks blog content contributions with SEO and readability analysis.
  """
  def track_blog_contribution(campaign_id, user_id, content_changes) do
    # Analyze content quality
    content_analysis = analyze_blog_content(content_changes)

    contribution_data = %{
      type: :blog_contribution,
      word_count_delta: content_analysis.word_count_delta,
      readability_score: content_analysis.readability_score,
      seo_score: content_analysis.seo_score,
      unique_insights: content_analysis.unique_insights,
      research_links: content_analysis.research_links,
      content_quality: content_analysis.overall_quality,
      timestamp: DateTime.utc_now()
    }

    # Update campaign tracker
    AdvancedTracker.track_content_contribution(campaign_id, user_id, contribution_data)

    # Check blog-specific quality gates
    check_blog_quality_gates(campaign_id, user_id, content_analysis)

    # Update syndication readiness
    update_syndication_readiness(campaign_id, content_analysis)

    {:ok, contribution_data}
  end

  @doc """
  Publishes blog to multiple platforms with revenue tracking.
  """
  def publish_blog_to_platforms(campaign_id, platforms) do
    campaign = Frestyl.DataCampaigns.get_campaign!(campaign_id)
    content = get_campaign_blog_content(campaign_id)

    publication_results = Enum.map(platforms, fn platform ->
      publish_to_platform(platform, content, campaign)
    end)

    # Track publication success
    successful_publications = Enum.count(publication_results, fn
      {:ok, _} -> true
      _ -> false
    end)

    # Update campaign with publication data
    update_campaign_publication_status(campaign_id, publication_results)

    # Trigger revenue tracking for published content
    if successful_publications > 0 do
      initialize_blog_revenue_tracking(campaign_id, publication_results)
    end

    {:ok, publication_results}
  end

  # ============================================================================
  # VIDEO CONTENT CAMPAIGNS
  # ============================================================================

  @doc """
  Creates video content campaign with timeline and role-based collaboration.
  """
  def create_video_campaign(campaign_params, creator) do
    enhanced_params = Map.merge(campaign_params, %{
      "content_type" => :video_content,
      "video_specifications" => %{
        "duration_range" => %{"min" => 300, "max" => 3600}, # 5-60 minutes
        "resolution" => "1080p",
        "formats" => ["mp4", "webm"],
        "aspect_ratio" => "16:9"
      },
      "production_roles" => %{
        "director" => %{"max_contributors" => 1, "revenue_weight" => 0.25},
        "editor" => %{"max_contributors" => 2, "revenue_weight" => 0.20},
        "content_creator" => %{"max_contributors" => 3, "revenue_weight" => 0.35},
        "researcher" => %{"max_contributors" => 2, "revenue_weight" => 0.10},
        "producer" => %{"max_contributors" => 1, "revenue_weight" => 0.10}
      },
      "minimum_contribution_threshold" => %{
        "video_minutes" => 5,
        "production_role_fulfillment" => 0.8,
        "quality_score" => 3.5
      }
    })

    case Frestyl.DataCampaigns.create_campaign(enhanced_params, creator) do
      {:ok, campaign} ->
        # Setup video production pipeline
        initialize_video_production_pipeline(campaign.id)

        # Create role assignments
        setup_video_role_assignments(campaign.id, enhanced_params["production_roles"])

        {:ok, campaign}

      error -> error
    end
  end

  @doc """
  Tracks video production contributions across different roles.
  """
  def track_video_contribution(campaign_id, user_id, contribution_data) do
    role_contribution = %{
      type: :video_contribution,
      production_role: contribution_data.role,
      contribution_type: contribution_data.type, # editing, filming, research, etc.
      duration_contributed: contribution_data.duration || 0,
      quality_metrics: analyze_video_quality(contribution_data),
      asset_contributions: contribution_data.assets || [],
      timestamp: DateTime.utc_now()
    }

    # Update campaign tracker with role-specific weighting
    AdvancedTracker.track_video_contribution(campaign_id, user_id, role_contribution)

    # Check role completion and pipeline progress
    update_video_production_pipeline(campaign_id, user_id, role_contribution)

    # Check video quality gates
    check_video_quality_gates(campaign_id, user_id, role_contribution)

    {:ok, role_contribution}
  end

  # ============================================================================
  # DATA STORY CAMPAIGNS WITH ANALYTICS INTEGRATION
  # ============================================================================

  @doc """
  Creates data story campaign with research and visualization requirements.
  """
  def create_data_story_campaign(campaign_params, creator) do
    enhanced_params = Map.merge(campaign_params, %{
      "content_type" => :data_story,
      "data_requirements" => %{
        "minimum_datasets" => 2,
        "minimum_visualizations" => 3,
        "research_citations" => 5,
        "statistical_analysis" => true
      },
      "research_phases" => %{
        "data_collection" => %{"duration_days" => 7, "weight" => 0.25},
        "analysis" => %{"duration_days" => 10, "weight" => 0.30},
        "visualization" => %{"duration_days" => 5, "weight" => 0.25},
        "narrative" => %{"duration_days" => 3, "weight" => 0.20}
      },
      "minimum_contribution_threshold" => %{
        "research_insights" => 3,
        "data_visualizations" => 1,
        "narrative_quality" => 0.75,
        "citation_accuracy" => 0.9
      }
    })

    case Frestyl.DataCampaigns.create_campaign(enhanced_params, creator) do
      {:ok, campaign} ->
        # Setup data story tracking
        initialize_data_story_tracking(campaign.id)

        # Integrate with Stories system for narrative structure
        create_data_story_structure(campaign.id, enhanced_params)

        {:ok, campaign}

      error -> error
    end
  end

  @doc """
  Tracks data research and visualization contributions.
  """
  def track_data_story_contribution(campaign_id, user_id, research_data) do
    data_contribution = %{
      type: :data_story_contribution,
      research_phase: research_data.phase,
      datasets_added: research_data.datasets || [],
      visualizations_created: research_data.visualizations || [],
      insights_generated: research_data.insights || [],
      citations_added: research_data.citations || [],
      analysis_quality: analyze_research_quality(research_data),
      timestamp: DateTime.utc_now()
    }

    # Update campaign tracker with research weighting
    AdvancedTracker.track_research_contribution(campaign_id, user_id, data_contribution)

    # Update story structure with new insights
    update_data_story_structure(campaign_id, user_id, data_contribution)

    # Check data quality gates
    check_data_story_quality_gates(campaign_id, user_id, data_contribution)

    {:ok, data_contribution}
  end

  # ============================================================================
  # NEWSLETTER/EMAIL CAMPAIGNS
  # ============================================================================

  @doc """
  Creates newsletter campaign with subscriber growth tracking.
  """
  def create_newsletter_campaign(campaign_params, creator) do
    enhanced_params = Map.merge(campaign_params, %{
      "content_type" => :newsletter,
      "email_specifications" => %{
        "frequency" => "weekly", # daily, weekly, monthly
        "subscriber_targets" => %{
          "launch_goal" => 1000,
          "growth_rate_monthly" => 0.15,
          "engagement_rate_target" => 0.25
        },
        "content_sections" => ["intro", "main_content", "insights", "call_to_action"]
      },
      "monetization_model" => %{
        "subscription_based" => true,
        "sponsor_integration" => true,
        "affiliate_marketing" => false,
        "premium_tiers" => true
      },
      "minimum_contribution_threshold" => %{
        "content_sections" => 2,
        "subscriber_engagement" => 0.20,
        "content_quality" => 3.5
      }
    })

    case Frestyl.DataCampaigns.create_campaign(enhanced_params, creator) do
      {:ok, campaign} ->
        # Setup newsletter tracking
        initialize_newsletter_tracking(campaign.id)

        # Setup email platform integration
        setup_email_platform_integration(campaign.id, enhanced_params)

        {:ok, campaign}

      error -> error
    end
  end

  # ============================================================================
  # PODCAST SERIES CAMPAIGNS (ENHANCED)
  # ============================================================================

  @doc """
  Enhanced podcast campaign with episode-based tracking.
  """
  def create_podcast_series_campaign(campaign_params, creator) do
    enhanced_params = Map.merge(campaign_params, %{
      "content_type" => :podcast_series,
      "series_specifications" => %{
        "episode_count" => campaign_params["episode_count"] || 10,
        "episode_duration_target" => campaign_params["duration"] || 30, # minutes
        "release_schedule" => "weekly",
        "format" => "interview" # interview, solo, panel, storytelling
      },
      "audio_requirements" => %{
        "quality_standard" => "broadcast",
        "noise_floor" => -60, # dB
        "dynamic_range" => 20,
        "format" => "wav"
      },
      "role_distribution" => %{
        "host" => %{"max_contributors" => 2, "revenue_weight" => 0.40},
        "producer" => %{"max_contributors" => 1, "revenue_weight" => 0.20},
        "editor" => %{"max_contributors" => 2, "revenue_weight" => 0.25},
        "researcher" => %{"max_contributors" => 3, "revenue_weight" => 0.15}
      }
    })

    case Frestyl.DataCampaigns.create_campaign(enhanced_params, creator) do
      {:ok, campaign} ->
        # Setup podcast series tracking
        initialize_podcast_series_tracking(campaign.id)

        # Create episode structure
        create_podcast_episode_structure(campaign.id, enhanced_params)

        # Setup audio integration with recording engine
        setup_podcast_recording_integration(campaign.id)

        {:ok, campaign}

      error -> error
    end
  end

  # ============================================================================
  # CONTENT ANALYSIS HELPERS
  # ============================================================================

  defp analyze_blog_content(content_changes) do
    content = content_changes["content"] || ""

    %{
      word_count_delta: count_words(content),
      readability_score: calculate_readability_score(content),
      seo_score: analyze_seo_factors(content),
      unique_insights: count_unique_insights(content),
      research_links: count_research_links(content),
      overall_quality: calculate_content_quality_score(content)
    }
  end

  defp analyze_video_quality(contribution_data) do
    %{
      technical_quality: analyze_technical_video_quality(contribution_data),
      content_quality: analyze_video_content_quality(contribution_data),
      production_value: assess_production_value(contribution_data),
      role_fulfillment: calculate_role_fulfillment(contribution_data)
    }
  end

  defp analyze_research_quality(research_data) do
    %{
      data_accuracy: validate_data_accuracy(research_data),
      source_credibility: assess_source_credibility(research_data),
      analysis_depth: evaluate_analysis_depth(research_data),
      visualization_clarity: assess_visualization_quality(research_data)
    }
  end

  # Content quality calculation helpers
  defp count_words(text) when is_binary(text) do
    text |> String.split(~r/\s+/, trim: true) |> length()
  end
  defp count_words(_), do: 0

  defp calculate_readability_score(text) do
    # Simplified Flesch Reading Ease calculation
    words = count_words(text)
    sentences = length(String.split(text, ~r/[.!?]+/, trim: true))
    syllables = estimate_syllables(text)

    if sentences > 0 and words > 0 do
      flesch = 206.835 - (1.015 * (words / sentences)) - (84.6 * (syllables / words))
      max(0, min(100, flesch)) / 100 # Normalize to 0-1
    else
      0.0
    end
  end

  defp estimate_syllables(text) do
    # Simple syllable estimation
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z]/, "")
    |> String.graphemes()
    |> Enum.count(&(&1 in ["a", "e", "i", "o", "u"]))
  end

  defp analyze_seo_factors(content) do
    # Basic SEO analysis
    word_count = count_words(content)
    has_headers = String.contains?(content, ["#", "##", "###"])
    has_links = String.contains?(content, ["http", "www"])

    base_score = 0.5
    score = base_score +
            (if word_count > 1500, do: 0.2, else: 0) +
            (if has_headers, do: 0.15, else: 0) +
            (if has_links, do: 0.15, else: 0)

    min(1.0, score)
  end

  defp count_unique_insights(content) do
    # Count insight indicators
    insight_patterns = [
      ~r/research shows/i,
      ~r/studies indicate/i,
      ~r/data reveals/i,
      ~r/analysis suggests/i,
      ~r/findings show/i
    ]

    Enum.reduce(insight_patterns, 0, fn pattern, acc ->
      matches = Regex.scan(pattern, content)
      acc + length(matches)
    end)
  end

  defp count_research_links(content) do
    # Count research links and citations
    link_patterns = [
      ~r/https?:\/\/[^\s]+/,
      ~r/\[[^\]]+\]\([^\)]+\)/, # Markdown links
      ~r/\([^\)]*\d{4}[^\)]*\)/ # Citation patterns
    ]

    Enum.reduce(link_patterns, 0, fn pattern, acc ->
      matches = Regex.scan(pattern, content)
      acc + length(matches)
    end)
  end

  defp calculate_content_quality_score(content) do
    # Aggregate quality score
    readability = calculate_readability_score(content)
    word_count_score = min(1.0, count_words(content) / 2000)
    structure_score = if String.contains?(content, ["#", "##"]), do: 0.2, else: 0

    (readability * 0.4 + word_count_score * 0.4 + structure_score * 0.2)
  end

  # Video quality analysis helpers
  defp analyze_technical_video_quality(contribution_data) do
    # Mock technical analysis - would integrate with video processing
    base_score = 0.8

    case contribution_data.type do
      "raw_footage" -> base_score * 0.9
      "edited_sequence" -> base_score * 1.0
      "final_export" -> base_score * 1.1
      _ -> base_score
    end
  end

  defp analyze_video_content_quality(contribution_data) do
    # Content quality based on role and contribution type
    0.75 # Simplified scoring
  end

  defp assess_production_value(contribution_data) do
    # Production value assessment
    0.8 # Simplified scoring
  end

  defp calculate_role_fulfillment(contribution_data) do
    # How well the contribution fulfills the assigned role
    0.85 # Simplified scoring
  end

  # Research quality analysis helpers
  defp validate_data_accuracy(research_data) do
    # Data accuracy validation
    datasets = research_data.datasets || []
    if length(datasets) > 0, do: 0.9, else: 0.5
  end

  defp assess_source_credibility(research_data) do
    # Source credibility assessment
    citations = research_data.citations || []
    credible_sources = Enum.count(citations, &is_credible_source?/1)

    if length(citations) > 0 do
      credible_sources / length(citations)
    else
      0.5
    end
  end

  defp is_credible_source?(citation) do
    # Check if source is from credible domains
    credible_domains = [
      ".edu", ".gov", ".org", "nature.com", "science.org",
      "pnas.org", "ieee.org", "acm.org"
    ]

    citation_text = citation["url"] || citation["source"] || ""
    Enum.any?(credible_domains, &String.contains?(citation_text, &1))
  end

  defp evaluate_analysis_depth(research_data) do
    # Analysis depth evaluation
    insights = research_data.insights || []
    if length(insights) >= 3, do: 0.9, else: length(insights) * 0.3
  end

  defp assess_visualization_quality(research_data) do
    # Visualization quality assessment
    visualizations = research_data.visualizations || []
    if length(visualizations) > 0, do: 0.85, else: 0.3
  end

  # ============================================================================
  # PLATFORM INTEGRATION HELPERS
  # ============================================================================

  defp publish_to_platform("medium", content, campaign) do
    # Medium API integration
    publication_data = %{
      title: campaign.title,
      content: format_content_for_medium(content),
      tags: extract_tags_from_content(content),
      canonical_url: generate_canonical_url(campaign.id)
    }

    # Mock successful publication
    {:ok, %{platform: "medium", url: "https://medium.com/@user/article", id: "medium_123"}}
  end

  defp publish_to_platform("linkedin", content, campaign) do
    # LinkedIn API integration
    publication_data = %{
      title: campaign.title,
      content: format_content_for_linkedin(content),
      visibility: "PUBLIC"
    }

    # Mock successful publication
    {:ok, %{platform: "linkedin", url: "https://linkedin.com/pulse/article", id: "linkedin_456"}}
  end

  defp publish_to_platform("ghost", content, campaign) do
    # Ghost CMS integration
    publication_data = %{
      title: campaign.title,
      html: format_content_for_ghost(content),
      status: "published",
      featured: false
    }

    # Mock successful publication
    {:ok, %{platform: "ghost", url: "https://blog.example.com/article", id: "ghost_789"}}
  end

  defp publish_to_platform(platform, _content, _campaign) do
    {:error, "Platform #{platform} not supported"}
  end

  # Content formatting helpers
  defp format_content_for_medium(content), do: content
  defp format_content_for_linkedin(content) do
    # LinkedIn has shorter content preferences
    if String.length(content) > 3000 do
      String.slice(content, 0, 2900) <> "... [Read more]"
    else
      content
    end
  end
  defp format_content_for_ghost(content) do
    # Convert to HTML if needed
    content |> String.replace("\n", "<br>")
  end

  defp extract_tags_from_content(content) do
    # Extract relevant tags from content
    common_tech_terms = [
      "javascript", "python", "react", "node", "ai", "machine learning",
      "data science", "web development", "startup", "productivity"
    ]

    content_lower = String.downcase(content)
    Enum.filter(common_tech_terms, fn term ->
      String.contains?(content_lower, term)
    end)
    |> Enum.take(5) # Limit to 5 tags
  end

  defp generate_canonical_url(campaign_id) do
    "https://frestyl.com/campaigns/#{campaign_id}/article"
  end

  # ============================================================================
  # INITIALIZATION HELPERS
  # ============================================================================

  defp initialize_blog_tracking(campaign_id) do
    # Initialize blog-specific metrics tracking
    blog_metrics = %{
      total_word_count: 0,
      readability_scores: %{},
      seo_scores: %{},
      publication_readiness: false,
      syndication_platforms: []
    }

    :ets.insert(:blog_campaign_metrics, {campaign_id, blog_metrics})
  end

  defp setup_blog_cms_integration(campaign_id, platform_config) do
    # Setup CMS integration for multi-platform publishing
    cms_config = %{
      enabled_platforms: platform_config["publishing_platforms"],
      auto_publish: false,
      seo_optimization: platform_config["seo_optimization"],
      cross_posting: platform_config["cross_posting"]
    }

    :ets.insert(:cms_integrations, {campaign_id, cms_config})
  end

  defp initialize_video_production_pipeline(campaign_id) do
    # Initialize video production tracking
    pipeline_state = %{
      current_phase: :pre_production,
      phases: %{
        pre_production: %{status: :active, progress: 0},
        production: %{status: :pending, progress: 0},
        post_production: %{status: :pending, progress: 0},
        distribution: %{status: :pending, progress: 0}
      },
      role_assignments: %{},
      asset_inventory: []
    }

    :ets.insert(:video_production_pipelines, {campaign_id, pipeline_state})
  end

  defp setup_video_role_assignments(campaign_id, roles_config) do
    # Setup role-based collaboration for video production
    role_assignments = Enum.reduce(roles_config, %{}, fn {role, config}, acc ->
      Map.put(acc, role, %{
        max_contributors: config["max_contributors"],
        current_contributors: [],
        revenue_weight: config["revenue_weight"],
        responsibilities: get_role_responsibilities(role)
      })
    end)

    :ets.insert(:video_role_assignments, {campaign_id, role_assignments})
  end

  defp get_role_responsibilities("director") do
    ["Creative vision", "Shot planning", "Talent direction", "Final approval"]
  end
  defp get_role_responsibilities("editor") do
    ["Video editing", "Color correction", "Audio mixing", "Final export"]
  end
  defp get_role_responsibilities("content_creator") do
    ["Script writing", "On-camera performance", "Content research"]
  end
  defp get_role_responsibilities("researcher") do
    ["Topic research", "Fact checking", "Source verification"]
  end
  defp get_role_responsibilities("producer") do
    ["Project management", "Resource coordination", "Timeline management"]
  end
  defp get_role_responsibilities(_), do: []

  defp initialize_data_story_tracking(campaign_id) do
    # Initialize data story research tracking
    research_state = %{
      current_phase: :data_collection,
      phases: %{
        data_collection: %{progress: 0, datasets: []},
        analysis: %{progress: 0, insights: []},
        visualization: %{progress: 0, charts: []},
        narrative: %{progress: 0, story_structure: nil}
      },
      research_quality: %{
        data_accuracy: 0,
        source_credibility: 0,
        analysis_depth: 0
      }
    }

    :ets.insert(:data_story_research, {campaign_id, research_state})
  end

  defp create_data_story_structure(campaign_id, params) do
    # Create story structure for data narrative
    story_params = %{
      title: "Data Story: " <> (params["title"] || "Untitled"),
      story_type: "data_story",
      collaboration_enabled: true,
      campaign_id: campaign_id
    }

    # This would create the story structure in the Stories system
    # Stories.create_data_story_structure(story_params)
    :ok
  end

  defp initialize_newsletter_tracking(campaign_id) do
    # Initialize newsletter campaign tracking
    newsletter_state = %{
      subscriber_count: 0,
      engagement_metrics: %{
        open_rate: 0,
        click_rate: 0,
        unsubscribe_rate: 0
      },
      content_schedule: [],
      revenue_streams: %{
        subscriptions: 0,
        sponsorships: 0,
        affiliates: 0
      }
    }

    :ets.insert(:newsletter_campaigns, {campaign_id, newsletter_state})
  end

  defp setup_email_platform_integration(campaign_id, params) do
    # Setup email platform integration (Mailchimp, ConvertKit, etc.)
    email_config = %{
      platform: "mailchimp", # or other email platforms
      list_id: generate_list_id(campaign_id),
      automation_enabled: true,
      analytics_tracking: true
    }

    :ets.insert(:email_integrations, {campaign_id, email_config})
  end

  defp initialize_podcast_series_tracking(campaign_id) do
    # Initialize podcast series tracking
    podcast_state = %{
      series_progress: 0,
      episodes: %{},
      audio_quality_metrics: %{},
      distribution_status: %{},
      listener_analytics: %{
        downloads: 0,
        retention_rate: 0,
        subscriber_growth: 0
      }
    }

    :ets.insert(:podcast_series, {campaign_id, podcast_state})
  end

  defp create_podcast_episode_structure(campaign_id, params) do
    # Create episode structure for podcast series
    episode_count = params["series_specifications"]["episode_count"]

    episodes = Enum.reduce(1..episode_count, %{}, fn episode_num, acc ->
      Map.put(acc, episode_num, %{
        title: "Episode #{episode_num}",
        status: :planned,
        duration_target: params["series_specifications"]["episode_duration_target"],
        contributors: %{},
        audio_files: [],
        quality_score: 0
      })
    end)

    :ets.insert(:podcast_episodes, {campaign_id, episodes})
  end

  defp setup_podcast_recording_integration(campaign_id) do
    # Setup integration with RecordingEngine for podcast recording
    recording_config = %{
      audio_quality: "broadcast",
      multi_track_enabled: true,
      real_time_collaboration: true,
      automatic_mixing: false
    }

    :ets.insert(:podcast_recording_configs, {campaign_id, recording_config})
  end

  # ============================================================================
  # QUALITY GATE IMPLEMENTATIONS
  # ============================================================================

  defp check_blog_quality_gates(campaign_id, user_id, content_analysis) do
    gates = [
      %{name: :minimum_word_count, threshold: 1500, current: content_analysis.word_count_delta},
      %{name: :readability_score, threshold: 0.6, current: content_analysis.readability_score},
      %{name: :seo_score, threshold: 0.7, current: content_analysis.seo_score},
      %{name: :unique_insights, threshold: 2, current: content_analysis.unique_insights}
    ]

    Enum.each(gates, fn gate ->
      AdvancedTracker.check_individual_quality_gate(campaign_id, user_id, gate, :blog_contribution)
    end)
  end

  defp check_video_quality_gates(campaign_id, user_id, role_contribution) do
    gates = [
      %{name: :technical_quality, threshold: 0.8, current: role_contribution.quality_metrics.technical_quality},
      %{name: :role_fulfillment, threshold: 0.85, current: role_contribution.quality_metrics.role_fulfillment},
      %{name: :production_value, threshold: 0.75, current: role_contribution.quality_metrics.production_value}
    ]

    Enum.each(gates, fn gate ->
      AdvancedTracker.check_individual_quality_gate(campaign_id, user_id, gate, :video_contribution)
    end)
  end

  defp check_data_story_quality_gates(campaign_id, user_id, data_contribution) do
    gates = [
      %{name: :research_insights, threshold: 3, current: length(data_contribution.insights_generated)},
      %{name: :data_accuracy, threshold: 0.9, current: data_contribution.analysis_quality.data_accuracy},
      %{name: :source_credibility, threshold: 0.8, current: data_contribution.analysis_quality.source_credibility},
      %{name: :visualization_quality, threshold: 0.75, current: data_contribution.analysis_quality.visualization_clarity}
    ]

    Enum.each(gates, fn gate ->
      AdvancedTracker.check_individual_quality_gate(campaign_id, user_id, gate, :data_story_contribution)
    end)
  end

  # ============================================================================
  # UPDATE FUNCTIONS
  # ============================================================================

  defp update_syndication_readiness(campaign_id, content_analysis) do
    readiness_score = calculate_syndication_readiness(content_analysis)

    case :ets.lookup(:blog_campaign_metrics, campaign_id) do
      [{^campaign_id, metrics}] ->
        updated_metrics = %{metrics |
          publication_readiness: readiness_score > 0.8,
          syndication_platforms: if readiness_score > 0.8 do
            ["medium", "linkedin", "ghost"]
          else
            []
          end
        }
        :ets.insert(:blog_campaign_metrics, {campaign_id, updated_metrics})
      [] -> :ok
    end
  end

  defp calculate_syndication_readiness(content_analysis) do
    weights = %{
      word_count: 0.3,
      readability: 0.25,
      seo: 0.25,
      insights: 0.2
    }

    scores = %{
      word_count: min(1.0, content_analysis.word_count_delta / 2000),
      readability: content_analysis.readability_score,
      seo: content_analysis.seo_score,
      insights: min(1.0, content_analysis.unique_insights / 3)
    }

    Enum.reduce(weights, 0, fn {metric, weight}, acc ->
      acc + (scores[metric] * weight)
    end)
  end

  defp update_campaign_publication_status(campaign_id, publication_results) do
    publication_status = %{
      total_platforms: length(publication_results),
      successful_publications: Enum.count(publication_results, fn {status, _} -> status == :ok end),
      failed_publications: Enum.count(publication_results, fn {status, _} -> status == :error end),
      publication_urls: extract_publication_urls(publication_results),
      published_at: DateTime.utc_now()
    }

    :ets.insert(:campaign_publications, {campaign_id, publication_status})
  end

  defp extract_publication_urls(publication_results) do
    publication_results
    |> Enum.filter(fn {status, _} -> status == :ok end)
    |> Enum.map(fn {:ok, result} -> result.url end)
  end

  defp initialize_blog_revenue_tracking(campaign_id, publication_results) do
    # Initialize revenue tracking for published blog content
    revenue_tracking = %{
      revenue_sources: %{
        direct_monetization: 0,
        affiliate_earnings: 0,
        sponsored_content: 0,
        platform_earnings: %{}
      },
      analytics: %{
        total_views: 0,
        engagement_rate: 0,
        conversion_rate: 0
      },
      publication_performance: format_publication_performance(publication_results)
    }

    :ets.insert(:blog_revenue_tracking, {campaign_id, revenue_tracking})
  end

  defp format_publication_performance(publication_results) do
    publication_results
    |> Enum.filter(fn {status, _} -> status == :ok end)
    |> Enum.reduce(%{}, fn {:ok, result}, acc ->
      Map.put(acc, result.platform, %{
        url: result.url,
        published_at: DateTime.utc_now(),
        views: 0,
        engagement: 0
      })
    end)
  end

  defp update_video_production_pipeline(campaign_id, user_id, role_contribution) do
    case :ets.lookup(:video_production_pipelines, campaign_id) do
      [{^campaign_id, pipeline}] ->
        # Update pipeline progress based on contribution
        updated_pipeline = advance_pipeline_phase(pipeline, role_contribution)
        :ets.insert(:video_production_pipelines, {campaign_id, updated_pipeline})
      [] -> :ok
    end
  end

  defp advance_pipeline_phase(pipeline, role_contribution) do
    current_phase = pipeline.current_phase

    # Calculate progress based on role contribution
    progress_increment = calculate_progress_increment(role_contribution)

    updated_phases = Map.update!(pipeline.phases, current_phase, fn phase ->
      new_progress = min(100, phase.progress + progress_increment)
      %{phase | progress: new_progress}
    end)

    # Check if phase is complete and advance to next
    current_phase_progress = updated_phases[current_phase].progress

    next_phase = if current_phase_progress >= 100 do
      get_next_pipeline_phase(current_phase)
    else
      current_phase
    end

    %{pipeline |
      phases: updated_phases,
      current_phase: next_phase
    }
  end

  defp calculate_progress_increment(role_contribution) do
    base_increment = 15

    # Adjust based on role and quality
    role_multiplier = case role_contribution.production_role do
      "director" -> 1.2
      "editor" -> 1.1
      "content_creator" -> 1.0
      "producer" -> 1.1
      _ -> 0.8
    end

    quality_multiplier = role_contribution.quality_metrics.role_fulfillment

    round(base_increment * role_multiplier * quality_multiplier)
  end

  defp get_next_pipeline_phase(:pre_production), do: :production
  defp get_next_pipeline_phase(:production), do: :post_production
  defp get_next_pipeline_phase(:post_production), do: :distribution
  defp get_next_pipeline_phase(:distribution), do: :distribution # Final phase

  defp update_data_story_structure(campaign_id, user_id, data_contribution) do
    case :ets.lookup(:data_story_research, campaign_id) do
      [{^campaign_id, research_state}] ->
        # Update research state with new contribution
        updated_state = incorporate_research_contribution(research_state, data_contribution)
        :ets.insert(:data_story_research, {campaign_id, updated_state})
      [] -> :ok
    end
  end

  defp incorporate_research_contribution(research_state, data_contribution) do
    phase = data_contribution.research_phase

    updated_phases = Map.update!(research_state.phases, phase, fn phase_data ->
      case data_contribution.research_phase do
        :data_collection ->
          %{phase_data |
            datasets: phase_data.datasets ++ data_contribution.datasets_added,
            progress: min(100, phase_data.progress + 25)
          }

        :analysis ->
          %{phase_data |
            insights: phase_data.insights ++ data_contribution.insights_generated,
            progress: min(100, phase_data.progress + 20)
          }

        :visualization ->
          %{phase_data |
            charts: phase_data.charts ++ data_contribution.visualizations_created,
            progress: min(100, phase_data.progress + 30)
          }

        :narrative ->
          %{phase_data |
            progress: min(100, phase_data.progress + 15)
          }
      end
    end)

    # Update overall research quality
    updated_quality = %{research_state.research_quality |
      data_accuracy: calculate_weighted_average(
        research_state.research_quality.data_accuracy,
        data_contribution.analysis_quality.data_accuracy
      ),
      source_credibility: calculate_weighted_average(
        research_state.research_quality.source_credibility,
        data_contribution.analysis_quality.source_credibility
      ),
      analysis_depth: calculate_weighted_average(
        research_state.research_quality.analysis_depth,
        data_contribution.analysis_quality.analysis_depth
      )
    }

    %{research_state |
      phases: updated_phases,
      research_quality: updated_quality
    }
  end

  defp calculate_weighted_average(current_avg, new_value) do
    # Simple weighted average with more weight on recent contributions
    (current_avg * 0.7) + (new_value * 0.3)
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp get_campaign_blog_content(campaign_id) do
    # Get compiled blog content from campaign
    case :ets.lookup(:blog_campaign_metrics, campaign_id) do
      [{^campaign_id, metrics}] ->
        # This would compile all contributor content into final blog post
        "Compiled blog content for campaign #{campaign_id}"
      [] ->
        "Default blog content"
    end
  end

  defp generate_list_id(campaign_id) do
    "campaign_#{campaign_id}_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  # Placeholder functions for external integrations
  defp get_campaign!(id), do: %{id: id, title: "Campaign #{id}"}
end
