# File: lib/frestyl/data_campaigns/peer_review.ex

defmodule Frestyl.DataCampaigns.PeerReview do
  @moduledoc """
  Peer review system that integrates with channels for quality improvement.
  """

  alias Frestyl.Channels
  alias Frestyl.DataCampaigns.AdvancedTracker
  alias Phoenix.PubSub

  @doc """
  Creates or gets the peer review channel for a campaign.
  """
  def setup_campaign_review_channel(campaign_id, campaign_creator) do
    case get_existing_review_channel(campaign_id) do
      nil ->
        create_campaign_review_channel(campaign_id, campaign_creator)

      channel ->
        {:ok, channel}
    end
  end

  @doc """
  Submits a contribution for peer review with specific criteria.
  """
  def submit_for_review(campaign_id, user_id, submission_data) do
    campaign = Frestyl.DataCampaigns.get_campaign!(campaign_id)

    # Get or create review channel
    {:ok, review_channel} = setup_campaign_review_channel(campaign_id, campaign.creator)

    # Create review request
    review_request = %{
      id: Ecto.UUID.generate(),
      campaign_id: campaign_id,
      contributor_id: user_id,
      submission_type: submission_data.type,
      content_preview: generate_content_preview(submission_data),
      review_criteria: get_review_criteria_for_type(submission_data.type),
      requested_at: DateTime.utc_now(),
      reviewers_needed: determine_reviewers_needed(submission_data.type),
      status: :pending,
      reviews: []
    }

    # Store review request
    store_review_request(review_request)

    # Post to review channel
    post_review_request_to_channel(review_channel.id, review_request)

    # Notify potential reviewers
    notify_potential_reviewers(campaign_id, review_request)

    {:ok, review_request}
  end

  @doc """
  Processes a peer review submission.
  """
  def submit_review(review_request_id, reviewer_id, review_data) do
    review_request = get_review_request!(review_request_id)

    # Validate reviewer eligibility
    case validate_reviewer(review_request.campaign_id, reviewer_id) do
      {:ok, :eligible} ->
        process_review_submission(review_request, reviewer_id, review_data)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_review_submission(review_request, reviewer_id, review_data) do
    review = %{
      id: Ecto.UUID.generate(),
      reviewer_id: reviewer_id,
      overall_score: review_data.overall_score,
      criteria_scores: review_data.criteria_scores,
      feedback: review_data.feedback,
      suggestions: review_data.suggestions || [],
      completed_at: DateTime.utc_now()
    }

    # Add review to request
    updated_reviews = [review | review_request.reviews]
    updated_request = %{review_request | reviews: updated_reviews}

    # Check if enough reviews collected
    if length(updated_reviews) >= review_request.reviewers_needed do
      complete_review_process(updated_request)
    else
      # Store partial review and continue
      store_review_request(updated_request)

      # Notify contributor of partial progress
      notify_review_progress(updated_request)

      {:ok, :review_submitted, :awaiting_more_reviews}
    end
  end

  defp complete_review_process(review_request) do
    # Calculate aggregate scores
    aggregate_score = calculate_aggregate_score(review_request.reviews)
    criteria_averages = calculate_criteria_averages(review_request.reviews)

    # Update campaign tracker with peer review results
    AdvancedTracker.update_peer_review_score(
      review_request.campaign_id,
      review_request.contributor_id,
      aggregate_score
    )

    # Check if review passes quality gates
    gate_result = evaluate_review_against_gates(
      review_request.campaign_id,
      review_request.contributor_id,
      aggregate_score,
      criteria_averages
    )

    # Handle gate result
    case gate_result do
      {:passed, _score} ->
        complete_successful_review(review_request, aggregate_score)

      {:failed, score, reason} ->
        trigger_improvement_from_review(review_request, score, reason)

      {:improvement_needed, areas} ->
        suggest_targeted_improvements(review_request, areas)
    end

    # Notify all parties
    notify_review_completion(review_request, aggregate_score, gate_result)

    {:ok, :review_completed, aggregate_score}
  end

  # Helper functions for review criteria
  defp get_review_criteria_for_type(:content_contribution) do
    [
      %{name: "Clarity & Readability", weight: 0.25, description: "Is the content clear and easy to understand?"},
      %{name: "Relevance", weight: 0.25, description: "Does it fit the campaign objectives?"},
      %{name: "Quality & Accuracy", weight: 0.25, description: "Is the information accurate and well-researched?"},
      %{name: "Originality", weight: 0.25, description: "Does it add unique value to the campaign?"}
    ]
  end

  defp get_review_criteria_for_type(:audio_contribution) do
    [
      %{name: "Audio Quality", weight: 0.3, description: "Clear sound, no distortion or noise"},
      %{name: "Content Quality", weight: 0.3, description: "Relevant and engaging content"},
      %{name: "Technical Execution", weight: 0.2, description: "Proper levels, timing, and editing"},
      %{name: "Fit with Campaign", weight: 0.2, description: "Matches campaign style and objectives"}
    ]
  end

  defp get_review_criteria_for_type(_default) do
    [
      %{name: "Overall Quality", weight: 0.4, description: "General quality of the contribution"},
      %{name: "Campaign Relevance", weight: 0.3, description: "How well it fits campaign goals"},
      %{name: "Execution", weight: 0.3, description: "Technical and creative execution"}
    ]
  end

  defp determine_reviewers_needed(:audio_contribution), do: 2
  defp determine_reviewers_needed(:content_contribution), do: 2
  defp determine_reviewers_needed(_), do: 2

  defp calculate_aggregate_score(reviews) do
    total_score = reviews |> Enum.map(& &1.overall_score) |> Enum.sum()
    Float.round(total_score / length(reviews), 2)
  end

  defp calculate_criteria_averages(reviews) do
    # Calculate average score for each criteria across all reviews
    all_criteria = reviews |> Enum.flat_map(& &1.criteria_scores) |> Enum.group_by(& &1.name)

    Enum.reduce(all_criteria, %{}, fn {criteria_name, scores}, acc ->
      avg_score = scores |> Enum.map(& &1.score) |> Enum.sum() |> Kernel./(length(scores))
      Map.put(acc, criteria_name, Float.round(avg_score, 2))
    end)
  end

  # Channel integration functions
  defp create_campaign_review_channel(campaign_id, creator) do
    channel_attrs = %{
      name: "Campaign #{campaign_id} - Peer Review",
      description: "Peer review and quality feedback for campaign contributions",
      channel_type: "campaign_review",
      visibility: :private,
      metadata: %{
        campaign_id: campaign_id,
        purpose: "peer_review",
        auto_generated: true
      }
    }

    Frestyl.Channels.create_channel(channel_attrs, creator)
  end

  defp post_review_request_to_channel(channel_id, review_request) do
    message_content = """
    🔍 **Peer Review Request**

    **Type:** #{String.capitalize(to_string(review_request.submission_type))}
    **Preview:** #{review_request.content_preview}
    **Reviewers Needed:** #{review_request.reviewers_needed}

    **Review Criteria:**
    #{format_review_criteria(review_request.review_criteria)}

    React with 👀 to become a reviewer!
    """

    Frestyl.Channels.create_message(channel_id, %{
      content: message_content,
      message_type: :peer_review_request,
      metadata: %{review_request_id: review_request.id}
    })
  end

  # Storage and utility functions
  defp store_review_request(review_request) do
    :ets.insert(:peer_review_requests, {review_request.id, review_request})
  end

  defp get_review_request!(review_request_id) do
    case :ets.lookup(:peer_review_requests, review_request_id) do
      [{^review_request_id, review_request}] -> review_request
      [] -> raise "Review request not found"
    end
  end

  defp get_existing_review_channel(campaign_id) do
    # Would query database for existing campaign review channel
    nil
  end

  defp generate_content_preview(submission_data) do
    case submission_data.type do
      :content_contribution ->
        content = submission_data.content || ""
        if String.length(content) > 100 do
          String.slice(content, 0, 100) <> "..."
        else
          content
        end

      :audio_contribution ->
        "Audio track: #{submission_data.duration_seconds}s, #{submission_data.track_type}"

      _ ->
        "#{submission_data.type} contribution"
    end
  end

  defp validate_reviewer(campaign_id, reviewer_id) do
    # Validate that reviewer is eligible (contributor to campaign, not reviewing own work, etc.)
    {:ok, :eligible}
  end

  defp notify_potential_reviewers(_campaign_id, _review_request), do: :ok
  defp notify_review_progress(_review_request), do: :ok
  defp notify_review_completion(_review_request, _score, _gate_result), do: :ok
  defp complete_successful_review(_review_request, _score), do: :ok
  defp trigger_improvement_from_review(_review_request, _score, _reason), do: :ok
  defp suggest_targeted_improvements(_review_request, _areas), do: :ok
  defp evaluate_review_against_gates(_campaign_id, _user_id, _score, _averages), do: {:passed, 0}

  defp format_review_criteria(criteria) do
    criteria
    |> Enum.map(fn criterion ->
      "• **#{criterion.name}** (#{trunc(criterion.weight * 100)}%): #{criterion.description}"
    end)
    |> Enum.join("\n")
  end
end
