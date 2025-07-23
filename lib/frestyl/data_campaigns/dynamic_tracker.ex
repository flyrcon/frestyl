# File: lib/frestyl/data_campaigns/dynamic_tracker.ex

defmodule Frestyl.DataCampaigns.DynamicTracker do
  @moduledoc """
  Real-time dynamic contribution metrics for revenue sharing calculation.
  """

  defstruct [
    :campaign_id,
    :contribution_metrics,
    :dynamic_revenue_weights,
    :last_updated,
    :version
  ]

  @doc """
  Real-time dynamic contribution metrics structure
  """
  def new(campaign_id) do
    %__MODULE__{
      campaign_id: campaign_id,
      contribution_metrics: %{
        word_count_by_user: %{},
        chapter_ownership: %{},
        media_contributions: %{},
        peer_review_scores: %{},
        narrative_contribution_score: %{},
        quality_gates_passed: %{}
      },
      dynamic_revenue_weights: %{},
      last_updated: DateTime.utc_now(),
      version: 0
    }
  end

  @doc """
  Updates contribution metrics for a specific user and metric type.
  """
  def update_metric(%__MODULE__{} = tracker, user_id, metric_type, value) do
    updated_metrics = put_in(
      tracker.contribution_metrics,
      [metric_type, user_id],
      value
    )

    %{tracker |
      contribution_metrics: updated_metrics,
      last_updated: DateTime.utc_now(),
      version: tracker.version + 1
    }
  end

  @doc """
  Calculates dynamic revenue split based on current metrics.
  """
  def calculate_revenue_split(%__MODULE__{} = tracker) do
    metrics = tracker.contribution_metrics

    # Get all contributing users
    users = get_contributing_users(metrics)

    # Calculate weighted scores for each user
    user_scores = Enum.reduce(users, %{}, fn user_id, acc ->
      content_score = calculate_content_score(metrics, user_id)
      narrative_score = calculate_narrative_score(metrics, user_id)
      quality_score = calculate_quality_score(metrics, user_id)
      unique_score = calculate_unique_value_score(metrics, user_id)

      # Apply weights: 40% content, 30% narrative, 20% quality, 10% unique
      total_score =
        content_score * 0.4 +
        narrative_score * 0.3 +
        quality_score * 0.2 +
        unique_score * 0.1

      Map.put(acc, user_id, total_score)
    end)

    # Normalize to percentages
    total_score = user_scores |> Map.values() |> Enum.sum()

    revenue_weights = if total_score > 0 do
      Enum.reduce(user_scores, %{}, fn {user_id, score}, acc ->
        percentage = (score / total_score * 100) |> Float.round(2)
        Map.put(acc, user_id, percentage)
      end)
    else
      %{}
    end

    # Filter minimum viable contributions (5% threshold)
    filtered_weights = Enum.filter(revenue_weights, fn {_user_id, percentage} ->
      percentage >= 5.0
    end) |> Enum.into(%{})

    %{tracker | dynamic_revenue_weights: filtered_weights}
  end

  # Private calculation functions
  defp get_contributing_users(metrics) do
    metrics
    |> Map.values()
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq()
  end

  defp calculate_content_score(metrics, user_id) do
    word_count = get_in(metrics, [:word_count_by_user, user_id]) || 0
    media_count = get_in(metrics, [:media_contributions, user_id]) || 0

    # Normalize: 1 point per 100 words, 10 points per media item
    (word_count / 100) + (media_count * 10)
  end

  defp calculate_narrative_score(metrics, user_id) do
    get_in(metrics, [:narrative_contribution_score, user_id]) || 0.0
  end

  defp calculate_quality_score(metrics, user_id) do
    get_in(metrics, [:peer_review_scores, user_id]) || 0.0
  end

  defp calculate_unique_value_score(metrics, user_id) do
    # Calculate based on unique contributions that can't be replaced
    gates_passed = get_in(metrics, [:quality_gates_passed, user_id]) || 0
    gates_passed * 5  # 5 points per quality gate passed
  end
end
