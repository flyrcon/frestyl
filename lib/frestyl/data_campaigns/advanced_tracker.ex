# File: lib/frestyl/data_campaigns/advanced_tracker.ex

defmodule Frestyl.DataCampaigns.AdvancedTracker do
  @moduledoc """
  Advanced real-time contribution tracking with audio integration,
  peer review system, and quality gates for content campaigns.
  """

  alias Frestyl.DataCampaigns.{Campaign, DynamicTracker}
  alias Frestyl.Studio.RecordingEngine
  alias Frestyl.Stories
  alias Phoenix.PubSub

  # ============================================================================
  # AUDIO CONTRIBUTION TRACKING
  # ============================================================================

  @doc """
  Tracks audio contributions from recording sessions for music/podcast campaigns.
  Integrates with existing RecordingEngine.
  """
  def track_audio_contribution(campaign_id, user_id, recording_data) do
    contribution_data = %{
      type: :audio_contribution,
      audio_duration: recording_data.duration_seconds,
      track_type: recording_data.track_type,  # vocals, instruments, mixing
      quality_metrics: %{
        sample_rate: recording_data.quality_settings.sample_rate,
        bit_depth: recording_data.quality_settings.bit_depth,
        noise_level: calculate_audio_quality(recording_data.audio_data)
      },
      timestamp: DateTime.utc_now()
    }

    case get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        updated_tracker = update_audio_metrics(tracker, user_id, contribution_data)

        # Recalculate revenue splits with audio contributions
        updated_tracker = calculate_dynamic_revenue_split(updated_tracker)

        # Save and broadcast
        save_campaign_tracker(campaign_id, updated_tracker)
        broadcast_metrics_update(campaign_id, updated_tracker)

        # Check quality gates for audio contributions
        check_audio_quality_gates(campaign_id, user_id, contribution_data)

        {:ok, updated_tracker}

      error -> error
    end
  end

  @doc """
  Tracks text/content contributions with detailed analytics.
  """
  def track_content_contribution(campaign_id, user_id, content_changes) do
    contribution_data = %{
      type: :content_contribution,
      word_count_delta: calculate_word_count_delta(content_changes),
      content_quality: analyze_content_quality(content_changes),
      sections_modified: extract_modified_sections(content_changes),
      narrative_impact: calculate_narrative_impact(content_changes),
      timestamp: DateTime.utc_now()
    }

    case get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        updated_tracker = update_content_metrics(tracker, user_id, contribution_data)
        updated_tracker = calculate_dynamic_revenue_split(updated_tracker)

        save_campaign_tracker(campaign_id, updated_tracker)
        broadcast_metrics_update(campaign_id, updated_tracker)

        # Check content quality gates
        check_content_quality_gates(campaign_id, user_id, contribution_data)

        {:ok, updated_tracker}

      error -> error
    end
  end

  # ============================================================================
  # QUALITY GATES SYSTEM
  # ============================================================================

  @doc """
  Comprehensive quality gate system that triggers improvement periods.
  """
  def check_quality_gates(campaign_id, user_id, contribution_type) do
    campaign = Frestyl.DataCampaigns.get_campaign!(campaign_id)

    quality_gates = get_quality_gates_for_content_type(campaign.content_type)

    Enum.each(quality_gates, fn gate ->
      check_individual_quality_gate(campaign_id, user_id, gate, contribution_type)
    end)
  end

  defp check_individual_quality_gate(campaign_id, user_id, gate, contribution_type) do
    case evaluate_quality_gate(campaign_id, user_id, gate) do
      {:passed, score} ->
        record_quality_gate_pass(campaign_id, user_id, gate, score)

      {:failed, score, reason} ->
        trigger_improvement_period(campaign_id, user_id, gate, score, reason)

      {:pending, requirements} ->
        notify_quality_requirements(campaign_id, user_id, gate, requirements)
    end
  end

  # Content-specific quality gates
  defp get_quality_gates_for_content_type(content_type) do
    case content_type do
      :book ->
        [
          %{name: :minimum_word_count, threshold: 5000, weight: 0.2},
          %{name: :chapter_completion, threshold: 0.15, weight: 0.3},
          %{name: :peer_review_score, threshold: 3.5, weight: 0.3},
          %{name: :narrative_coherence, threshold: 0.7, weight: 0.2}
        ]

      :podcast ->
        [
          %{name: :minimum_audio_duration, threshold: 600, weight: 0.25}, # 10 minutes
          %{name: :audio_quality_score, threshold: 0.8, weight: 0.25},
          %{name: :speaking_time_ratio, threshold: 0.20, weight: 0.25},
          %{name: :peer_review_score, threshold: 3.5, weight: 0.25}
        ]

      :music_track ->
        [
          %{name: :track_contribution_ratio, threshold: 0.15, weight: 0.4},
          %{name: :audio_quality_score, threshold: 0.75, weight: 0.3},
          %{name: :mixing_contribution, threshold: 0.10, weight: 0.3}
        ]

      :data_story ->
        [
          %{name: :research_contribution, threshold: 3, weight: 0.4}, # 3 key insights
          %{name: :data_visualization_quality, threshold: 0.7, weight: 0.3},
          %{name: :narrative_clarity, threshold: 0.75, weight: 0.3}
        ]

      :blog_post ->
        [
          %{name: :minimum_word_count, threshold: 1500, weight: 0.3},
          %{name: :unique_insights, threshold: 2, weight: 0.4},
          %{name: :peer_review_score, threshold: 3.0, weight: 0.3}
        ]

      _ ->
        # Default quality gates
        [
          %{name: :minimum_contribution, threshold: 0.05, weight: 0.5},
          %{name: :peer_review_score, threshold: 3.0, weight: 0.5}
        ]
    end
  end

  # CONTENT METRICS

  @doc """
  Updates content metrics for a user's contribution to a campaign.
  """
  defp update_content_metrics(tracker, user_id, contribution_data) do
    current_metrics = Map.get(tracker.content_metrics, user_id, %{})

    # Extract content type and quality data
    content_type = Map.get(contribution_data, :content_type, :general)
    quality_score = Map.get(contribution_data, :quality_score, 0.0)
    word_count = Map.get(contribution_data, :word_count, 0)
    media_count = Map.get(contribution_data, :media_count, 0)
    peer_reviews = Map.get(contribution_data, :peer_reviews, [])

    # Calculate updated metrics
    updated_metrics = %{
      total_contributions: Map.get(current_metrics, :total_contributions, 0) + 1,
      total_word_count: Map.get(current_metrics, :total_word_count, 0) + word_count,
      total_media_count: Map.get(current_metrics, :total_media_count, 0) + media_count,
      quality_scores: [quality_score | Map.get(current_metrics, :quality_scores, [])],
      content_types: update_content_type_counts(current_metrics, content_type),
      peer_review_scores: update_peer_review_scores(current_metrics, peer_reviews),
      last_contribution_at: DateTime.utc_now(),
      average_quality_score: calculate_average_quality(current_metrics, quality_score),
      contribution_streak: calculate_contribution_streak(current_metrics),
      content_diversity_score: calculate_content_diversity(current_metrics, content_type)
    }

    # Update the tracker with new metrics
    %{tracker |
      content_metrics: Map.put(tracker.content_metrics, user_id, updated_metrics)
    }
  end

  @doc """
  Updates content type counts for tracking contribution diversity.
  """
  defp update_content_type_counts(current_metrics, content_type) do
    content_types = Map.get(current_metrics, :content_types, %{})
    current_count = Map.get(content_types, content_type, 0)
    Map.put(content_types, content_type, current_count + 1)
  end

  @doc """
  Updates peer review scores aggregation.
  """
  defp update_peer_review_scores(current_metrics, new_peer_reviews) do
    existing_scores = Map.get(current_metrics, :peer_review_scores, [])
    review_scores = Enum.map(new_peer_reviews, & &1.score)
    existing_scores ++ review_scores
  end

  @doc """
  Calculates running average quality score.
  """
  defp calculate_average_quality(current_metrics, new_quality_score) do
    existing_scores = Map.get(current_metrics, :quality_scores, [])
    all_scores = [new_quality_score | existing_scores]

    if length(all_scores) > 0 do
      Enum.sum(all_scores) / length(all_scores)
    else
      0.0
    end
  end

  @doc """
  Calculates contribution streak (consecutive days with contributions).
  """
  defp calculate_contribution_streak(current_metrics) do
    last_contribution = Map.get(current_metrics, :last_contribution_at)
    current_streak = Map.get(current_metrics, :contribution_streak, 0)

    case last_contribution do
      nil -> 1  # First contribution
      last_date ->
        days_since_last = DateTime.diff(DateTime.utc_now(), last_date, :day)

        cond do
          days_since_last <= 1 -> current_streak + 1  # Continue streak
          days_since_last == 2 -> current_streak       # Same day as yesterday, maintain
          true -> 1                                     # Reset streak
        end
    end
  end

  @doc """
  Calculates content diversity score based on variety of content types.
  """
  defp calculate_content_diversity(current_metrics, new_content_type) do
    content_types = Map.get(current_metrics, :content_types, %{})
    updated_types = update_content_type_counts(current_metrics, new_content_type)

    # Diversity score based on number of different content types
    unique_types = Map.keys(updated_types) |> length()
    total_contributions = Map.values(updated_types) |> Enum.sum()

    if total_contributions > 0 do
      # Score increases with variety, normalized by total contributions
      (unique_types / total_contributions) * 100
    else
      0.0
    end
  end

  # Optional: Add helper function to get user content metrics
  @doc """
  Gets content metrics for a specific user in a campaign.
  """
 defp get_user_campaign_metrics(user_id, campaign_id) do
    # Simple implementation using AdvancedTracker
    case AdvancedTracker.get_user_content_metrics(campaign_id, user_id) do
      {:ok, metrics} -> metrics
      _ -> %{
        total_contributions: 0,
        total_word_count: 0,
        average_quality_score: 0.0,
        peer_reviews_given: 0,
        improvements_made: 0,
        last_contribution_at: nil
      }
    end
  end

  # Optional: Add function to get campaign-wide content analytics
  @doc """
  Gets aggregated content analytics for the entire campaign.
  """
  def get_campaign_content_analytics(campaign_id) do
    case get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        analytics = %{
          total_contributors: Map.size(tracker.content_metrics),
          total_contributions: aggregate_total_contributions(tracker.content_metrics),
          average_quality_score: aggregate_average_quality(tracker.content_metrics),
          content_type_distribution: aggregate_content_types(tracker.content_metrics),
          top_contributors: get_top_contributors_by_metrics(tracker.content_metrics),
          quality_distribution: analyze_quality_distribution(tracker.content_metrics)
        }
        {:ok, analytics}
      error -> error
    end
  end

  # Helper functions for campaign analytics
  defp aggregate_total_contributions(content_metrics) do
    content_metrics
    |> Map.values()
    |> Enum.map(& Map.get(&1, :total_contributions, 0))
    |> Enum.sum()
  end

  defp aggregate_average_quality(content_metrics) do
    quality_scores = content_metrics
    |> Map.values()
    |> Enum.map(& Map.get(&1, :average_quality_score, 0.0))
    |> Enum.filter(& &1 > 0)

    if length(quality_scores) > 0 do
      Enum.sum(quality_scores) / length(quality_scores)
    else
      0.0
    end
  end

  defp aggregate_content_types(content_metrics) do
    content_metrics
    |> Map.values()
    |> Enum.map(& Map.get(&1, :content_types, %{}))
    |> Enum.reduce(%{}, fn types_map, acc ->
      Map.merge(acc, types_map, fn _key, val1, val2 -> val1 + val2 end)
    end)
  end

  defp get_top_contributors_by_metrics(content_metrics, limit \\ 5) do
    content_metrics
    |> Enum.map(fn {user_id, metrics} ->
      {user_id, Map.get(metrics, :total_contributions, 0)}
    end)
    |> Enum.sort_by(fn {_user_id, contributions} -> contributions end, :desc)
    |> Enum.take(limit)
  end

  defp analyze_quality_distribution(content_metrics) do
    all_scores = content_metrics
    |> Map.values()
    |> Enum.flat_map(& Map.get(&1, :quality_scores, []))
    |> Enum.filter(& &1 > 0)

    if length(all_scores) > 0 do
      %{
        count: length(all_scores),
        average: Enum.sum(all_scores) / length(all_scores),
        min: Enum.min(all_scores),
        max: Enum.max(all_scores),
        above_threshold: Enum.count(all_scores, & &1 >= 3.0)
      }
    else
      %{count: 0, average: 0.0, min: 0.0, max: 0.0, above_threshold: 0}
    end
  end

  # ============================================================================
  # IMPROVEMENT PERIOD SYSTEM
  # ============================================================================

  @doc """
  Triggers 30-day improvement period when quality gates fail.
  """
  def trigger_improvement_period(campaign_id, user_id, failed_gate, current_score, reason) do
    improvement_period = %{
      id: Ecto.UUID.generate(),
      campaign_id: campaign_id,
      user_id: user_id,
      gate_name: failed_gate.name,
      current_score: current_score,
      target_score: failed_gate.threshold,
      reason: reason,
      started_at: DateTime.utc_now(),
      expires_at: DateTime.add(DateTime.utc_now(), 30, :day),
      status: :active,
      improvement_plan: generate_improvement_plan(failed_gate, current_score)
    }

    # Store improvement period
    store_improvement_period(improvement_period)

    # Notify user via channels system
    notify_improvement_period_started(improvement_period)

    # Schedule improvement check
    schedule_improvement_check(improvement_period)

    {:ok, improvement_period}
  end

  @doc """
  Generates improvement plan based on failed quality gate.
  """
  defp generate_improvement_plan(failed_gate, current_score) do
    gap = failed_gate.threshold - current_score

    case failed_gate.name do
      :minimum_word_count ->
        words_needed = trunc(gap)
        %{
          title: "Increase Content Length",
          tasks: [
            "Add #{words_needed} more words to your contribution",
            "Expand on existing ideas with examples",
            "Add supporting research or citations",
            "Include detailed explanations where needed"
          ],
          estimated_time: "2-4 hours",
          resources: ["Writing guidelines", "Content examples"]
        }

      :peer_review_score ->
        %{
          title: "Improve Content Quality",
          tasks: [
            "Address feedback from peer reviews",
            "Proofread and edit for clarity",
            "Strengthen arguments with evidence",
            "Improve structure and flow"
          ],
          estimated_time: "3-5 hours",
          resources: ["Peer feedback", "Style guide", "Writing resources"]
        }

      :audio_quality_score ->
        %{
          title: "Enhance Audio Quality",
          tasks: [
            "Re-record sections with audio issues",
            "Reduce background noise",
            "Improve microphone positioning",
            "Apply audio processing filters"
          ],
          estimated_time: "1-3 hours",
          resources: ["Audio editing tools", "Recording tips"]
        }

      :speaking_time_ratio ->
        minutes_needed = trunc(gap * 10) # Assuming 10 min total
        %{
          title: "Increase Speaking Contribution",
          tasks: [
            "Record #{minutes_needed} more minutes of content",
            "Expand on your talking points",
            "Add commentary or analysis",
            "Participate more in discussions"
          ],
          estimated_time: "30-60 minutes",
          resources: ["Recording setup", "Content outline"]
        }

      _ ->
        %{
          title: "General Improvement",
          tasks: [
            "Review contribution requirements",
            "Enhance quality of existing work",
            "Seek feedback from collaborators"
          ],
          estimated_time: "1-2 hours",
          resources: ["Campaign guidelines"]
        }
    end
  end

  # ============================================================================
  # PEER REVIEW INTEGRATION
  # ============================================================================

  @doc """
  Integrates with channels system for peer review and feedback.
  """
  def submit_for_peer_review(campaign_id, user_id, contribution_type) do
    campaign = Frestyl.DataCampaigns.get_campaign!(campaign_id)

    # Create or get existing review channel
    review_channel = get_or_create_review_channel(campaign)

    # Create peer review request
    review_request = %{
      id: Ecto.UUID.generate(),
      campaign_id: campaign_id,
      user_id: user_id,
      contribution_type: contribution_type,
      channel_id: review_channel.id,
      status: :pending,
      requested_at: DateTime.utc_now(),
      reviewers_needed: 2,
      current_reviews: []
    }

    # Store review request
    store_review_request(review_request)

    # Notify potential reviewers via channels
    notify_peer_reviewers(review_channel.id, review_request)

    # Update campaign tracker
    track_peer_review_request(campaign_id, user_id, review_request)

    {:ok, review_request}
  end

  @doc """
  Processes peer review completion and updates quality scores.
  """
  def complete_peer_review(review_request_id, reviewer_id, review_data) do
    review_request = get_review_request!(review_request_id)

    review = %{
      id: Ecto.UUID.generate(),
      reviewer_id: reviewer_id,
      score: review_data.score,  # 1-5 scale
      feedback: review_data.feedback,
      specific_areas: review_data.areas || [],
      completed_at: DateTime.utc_now()
    }

    # Add review to request
    updated_reviews = [review | review_request.current_reviews]
    updated_request = %{review_request | current_reviews: updated_reviews}

    # Check if enough reviews collected
    if length(updated_reviews) >= review_request.reviewers_needed do
      complete_review_process(updated_request)
    else
      store_review_request(updated_request)
      {:ok, :review_pending}
    end
  end

  defp complete_review_process(review_request) do
    # Calculate average score
    total_score = review_request.current_reviews
                  |> Enum.map(& &1.score)
                  |> Enum.sum()

    average_score = total_score / length(review_request.current_reviews)

    # Update campaign tracker with peer review score
    update_peer_review_score(
      review_request.campaign_id,
      review_request.user_id,
      average_score
    )

    # Notify contributor of review completion
    notify_review_completed(review_request, average_score)

    # Check if review triggered improvement period end
    check_improvement_period_completion(
      review_request.campaign_id,
      review_request.user_id,
      average_score
    )

    {:ok, :review_completed, average_score}
  end

  # ============================================================================
  # REAL-TIME NOTIFICATIONS & UPDATES
  # ============================================================================

  @doc """
  Broadcasts real-time updates to campaign participants.
  """
  def broadcast_metrics_update(campaign_id, tracker) do
    # Broadcast to campaign channel
    PubSub.broadcast(
      Frestyl.PubSub,
      "campaign:#{campaign_id}:metrics",
      {:metrics_updated, tracker}
    )

    # Broadcast to individual users
    Enum.each(tracker.dynamic_revenue_weights, fn {user_id, percentage} ->
      PubSub.broadcast(
        Frestyl.PubSub,
        "user:#{user_id}:campaigns",
        {:revenue_split_updated, campaign_id, percentage}
      )
    end)
  end

  @doc """
  Sends improvement period notifications via channels system.
  """
  defp notify_improvement_period_started(improvement_period) do
    # Create notification in user's feed
    notification = %{
      type: :improvement_period_started,
      title: "Quality Improvement Required",
      message: "Your contribution needs improvement to meet campaign standards.",
      campaign_id: improvement_period.campaign_id,
      improvement_plan: improvement_period.improvement_plan,
      expires_at: improvement_period.expires_at
    }

    PubSub.broadcast(
      Frestyl.PubSub,
      "user:#{improvement_period.user_id}",
      {:notification, notification}
    )

    # Also post in campaign channel if exists
    campaign = Frestyl.DataCampaigns.get_campaign!(improvement_period.campaign_id)
    if campaign.channel_id do
      post_improvement_notice_to_channel(campaign.channel_id, improvement_period)
    end
  end

  # ============================================================================
  # REVENUE CALCULATION ENHANCEMENTS
  # ============================================================================

  @doc """
  Enhanced revenue calculation with quality weighting and penalties.
  """
  def calculate_dynamic_revenue_split(%DynamicTracker{} = tracker) do
    metrics = tracker.contribution_metrics
    users = get_contributing_users(metrics)

    # Calculate base scores for each user
    user_scores = Enum.reduce(users, %{}, fn user_id, acc ->
      content_score = calculate_content_score(metrics, user_id)
      narrative_score = calculate_narrative_score(metrics, user_id)
      quality_score = calculate_quality_score(metrics, user_id)
      unique_score = calculate_unique_value_score(metrics, user_id)

      # Apply quality gates as multipliers
      quality_multiplier = get_quality_multiplier(metrics, user_id)

      # Calculate weighted score with quality gates
      weighted_score = (
        content_score * 0.4 +
        narrative_score * 0.3 +
        quality_score * 0.2 +
        unique_score * 0.1
      ) * quality_multiplier

      Map.put(acc, user_id, weighted_score)
    end)

    # Normalize to percentages
    total_score = user_scores |> Map.values() |> Enum.sum()

    revenue_weights = if total_score > 0 do
      user_scores
      |> Enum.reduce(%{}, fn {user_id, score}, acc ->
        percentage = (score / total_score * 100) |> Float.round(2)
        Map.put(acc, user_id, percentage)
      end)
      |> filter_minimum_viable_contributions()
    else
      %{}
    end

    %{tracker | dynamic_revenue_weights: revenue_weights}
  end

  defp get_quality_multiplier(metrics, user_id) do
    # Get quality gates passed for this user
    gates_passed = get_in(metrics, [:quality_gates_passed, user_id]) || []
    gates_failed = get_in(metrics, [:quality_gates_failed, user_id]) || []

    # Calculate multiplier based on quality performance
    base_multiplier = 1.0
    pass_bonus = length(gates_passed) * 0.1  # 10% bonus per gate passed
    fail_penalty = length(gates_failed) * 0.05  # 5% penalty per gate failed

    quality_multiplier = base_multiplier + pass_bonus - fail_penalty

    # Ensure multiplier stays within reasonable bounds
    max(0.5, min(2.0, quality_multiplier))
  end

  # ============================================================================
  # DATA STORAGE & RETRIEVAL
  # ============================================================================

  defp get_campaign_tracker(campaign_id) do
    case :ets.lookup(:campaign_trackers, campaign_id) do
      [{^campaign_id, tracker}] -> {:ok, tracker}
      [] -> {:error, :tracker_not_found}
    end
  end

  defp save_campaign_tracker(campaign_id, tracker) do
    :ets.insert(:campaign_trackers, {campaign_id, tracker})

    # Also persist to database for durability
    persist_tracker_to_database(campaign_id, tracker)
  end

  defp store_improvement_period(improvement_period) do
    # Store in ETS for fast access
    :ets.insert(:improvement_periods, {improvement_period.id, improvement_period})

    # Also persist to database
    persist_improvement_period(improvement_period)
  end

  defp store_review_request(review_request) do
    :ets.insert(:review_requests, {review_request.id, review_request})
    persist_review_request(review_request)
  end

  # ============================================================================
  # AUDIO ANALYSIS HELPERS
  # ============================================================================

  defp calculate_audio_quality(audio_data) do
    # Simplified audio quality analysis
    # In real implementation, this would use audio processing libraries
    case byte_size(audio_data) do
      size when size > 1_000_000 -> 0.9  # High quality
      size when size > 500_000 -> 0.7    # Medium quality
      _ -> 0.5                            # Lower quality
    end
  end

  defp update_audio_metrics(tracker, user_id, contribution_data) do
    audio_contributions = get_in(tracker.contribution_metrics, [:audio_contributions, user_id]) || []
    updated_contributions = [contribution_data | audio_contributions]

    # Calculate total audio duration for user
    total_duration = Enum.reduce(updated_contributions, 0, fn contrib, acc ->
      acc + contrib.audio_duration
    end)

    # Update metrics
    updated_metrics = tracker.contribution_metrics
    |> put_in([:audio_contributions, user_id], updated_contributions)
    |> put_in([:total_audio_duration_by_user, user_id], total_duration)

    %{tracker | contribution_metrics: updated_metrics}
  end

  # ============================================================================
  # CONTENT ANALYSIS HELPERS
  # ============================================================================

  defp calculate_word_count_delta(content_changes) do
    # Calculate the change in word count from content changes
    case content_changes do
      %{"content" => new_content, "previous_content" => old_content} ->
        new_words = count_words(new_content)
        old_words = count_words(old_content)
        new_words - old_words

      %{"content" => new_content} ->
        count_words(new_content)

      _ -> 0
    end
  end

  defp count_words(text) when is_binary(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end
  defp count_words(_), do: 0

  defp analyze_content_quality(content_changes) do
    # Simplified content quality analysis
    # In real implementation, this could use NLP libraries
    case content_changes do
      %{"content" => content} when is_binary(content) ->
        word_count = count_words(content)
        sentence_count = String.split(content, ~r/[.!?]+/, trim: true) |> length()

        avg_sentence_length = if sentence_count > 0, do: word_count / sentence_count, else: 0

        # Quality based on readability metrics
        cond do
          avg_sentence_length > 30 -> 0.4  # Too complex
          avg_sentence_length < 8 -> 0.6   # Too simple
          word_count < 100 -> 0.5          # Too short
          true -> 0.8                      # Good quality
        end

      _ -> 0.5
    end
  end

  defp calculate_narrative_impact(content_changes) do
    # Simplified narrative impact calculation
    # This could analyze story structure, character development, etc.
    case content_changes do
      %{"sections_modified" => sections} when is_list(sections) ->
        critical_sections = ["introduction", "conclusion", "climax", "character_development"]

        critical_edits = Enum.count(sections, fn section ->
          String.contains?(String.downcase(section), critical_sections)
        end)

        min(1.0, critical_edits * 0.3)

      _ -> 0.1
    end
  end

  defp extract_modified_sections(content_changes) do
    Map.get(content_changes, "sections_modified", [])
  end

  # ============================================================================
  # QUALITY GATE EVALUATION
  # ============================================================================

  defp evaluate_quality_gate(campaign_id, user_id, gate) do
    case get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        current_value = get_gate_current_value(tracker, user_id, gate.name)

        cond do
          current_value >= gate.threshold ->
            {:passed, current_value}

          current_value > 0 ->
            reason = generate_failure_reason(gate.name, current_value, gate.threshold)
            {:failed, current_value, reason}

          true ->
            requirements = generate_gate_requirements(gate.name, gate.threshold)
            {:pending, requirements}
        end

      _ -> {:pending, ["Campaign tracker not found"]}
    end
  end

  defp get_gate_current_value(tracker, user_id, gate_name) do
    metrics = tracker.contribution_metrics

    case gate_name do
      :minimum_word_count ->
        get_in(metrics, [:word_count_by_user, user_id]) || 0

      :minimum_audio_duration ->
        get_in(metrics, [:total_audio_duration_by_user, user_id]) || 0

      :peer_review_score ->
        get_in(metrics, [:peer_review_scores, user_id]) || 0.0

      :chapter_completion ->
        chapters = get_in(metrics, [:chapter_ownership, user_id]) || []
        length(chapters) / 10  # Assuming 10 chapters total

      :speaking_time_ratio ->
        total_audio = get_in(metrics, [:total_audio_duration_by_user, user_id]) || 0
        campaign_total = 3600  # Assuming 1 hour total
        total_audio / campaign_total

      :research_contribution ->
        get_in(metrics, [:research_insights, user_id]) || 0

      _ -> 0.0
    end
  end

  defp generate_failure_reason(gate_name, current, threshold) do
    gap = threshold - current

    case gate_name do
      :minimum_word_count ->
        "Need #{trunc(gap)} more words to meet minimum requirement"

      :minimum_audio_duration ->
        minutes = trunc(gap / 60)
        "Need #{minutes} more minutes of audio content"

      :peer_review_score ->
        "Current score #{Float.round(current, 1)}/5.0 needs improvement"

      _ ->
        "Current contribution below minimum threshold"
    end
  end

  # ============================================================================
  # NOTIFICATION HELPERS
  # ============================================================================

  defp notify_peer_reviewers(channel_id, review_request) do
    # Post review request in channel
    Frestyl.Channels.create_channel_message(channel_id, %{
      type: :peer_review_request,
      content: "🔍 Peer review requested for campaign contribution",
      metadata: %{
        review_request_id: review_request.id,
        contribution_type: review_request.contribution_type,
        reviewers_needed: review_request.reviewers_needed
      }
    })
  end

  defp notify_review_completed(review_request, average_score) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "user:#{review_request.user_id}",
      {:review_completed, review_request.id, average_score}
    )
  end

  # ============================================================================
  # INTEGRATION WITH EXISTING SYSTEMS
  # ============================================================================

  defp get_or_create_review_channel(campaign) do
    # Try to get existing review channel
    case Frestyl.Channels.get_campaign_review_channel(campaign.id) do
      nil ->
        # Create new review channel
        Frestyl.Channels.create_channel(%{
          name: "#{campaign.title} - Peer Review",
          description: "Peer review and feedback for campaign contributions",
          channel_type: "campaign_review",
          visibility: "private",
          metadata: %{
            campaign_id: campaign.id,
            purpose: "peer_review"
          }
        }, campaign.creator)

      channel -> {:ok, channel}
    end
  end

  defp post_improvement_notice_to_channel(channel_id, improvement_period) do
    Frestyl.Channels.create_channel_message(channel_id, %{
      type: :improvement_notice,
      content: "📈 Quality improvement period started - let's help improve this contribution!",
      metadata: %{
        improvement_period_id: improvement_period.id,
        expires_at: improvement_period.expires_at
      }
    })
  end

  # Database persistence helpers (simplified - would need actual schema)
  defp persist_tracker_to_database(campaign_id, tracker) do
    # Would save to campaign_metrics table
    :ok
  end

  defp persist_improvement_period(improvement_period) do
    # Would save to improvement_periods table
    :ok
  end

  defp persist_review_request(review_request) do
    # Would save to peer_review_requests table
    :ok
  end

  # Utility functions
  defp get_contributing_users(metrics) do
    metrics
    |> Map.values()
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq()
  end

  defp filter_minimum_viable_contributions(percentages) do
    Enum.filter(percentages, fn {_user_id, percentage} ->
      percentage >= 5.0  # 5% minimum threshold
    end)
    |> Enum.into(%{})
  end

  # Placeholder functions to be implemented
  defp calculate_content_score(_metrics, _user_id), do: 0.0
  defp calculate_narrative_score(_metrics, _user_id), do: 0.0
  defp calculate_quality_score(_metrics, _user_id), do: 0.0
  defp calculate_unique_value_score(_metrics, _user_id), do: 0.0
  defp get_review_request!(_id), do: %{}
  defp update_peer_review_score(_campaign_id, _user_id, _score), do: :ok
  defp check_improvement_period_completion(_campaign_id, _user_id, _score), do: :ok
  defp track_peer_review_request(_campaign_id, _user_id, _request), do: :ok
  defp check_audio_quality_gates(_campaign_id, _user_id, _data), do: :ok
  defp check_content_quality_gates(_campaign_id, _user_id, _data), do: :ok
  defp record_quality_gate_pass(_campaign_id, _user_id, _gate, _score), do: :ok
  defp notify_quality_requirements(_campaign_id, _user_id, _gate, _requirements), do: :ok
  defp schedule_improvement_check(_improvement_period), do: :ok
  defp generate_gate_requirements(_gate_name, _threshold), do: []
end
