defmodule Frestyl.Portfolios.CompletionTracker do
  @moduledoc """
  Tracks portfolio enhancement completions and calculates completion metrics
  """

  alias Frestyl.{Repo, Portfolios}
  import Ecto.Query

  @doc """
  Get comprehensive completion data for a portfolio
  """
  def get_portfolio_completion_data(portfolio_id) do
    completions = get_enhancement_completions(portfolio_id)

    %{
      voice_completion: get_completion_percentage_by_type(completions, "voice_over"),
      writing_completion: get_completion_percentage_by_type(completions, "writing"),
      design_completion: get_completion_percentage_by_type(completions, "design"),
      music_completion: get_completion_percentage_by_type(completions, "music"),
      overall_completion: calculate_overall_completion(completions),
      last_enhancement: get_last_enhancement_date(completions),
      total_enhancements: length(completions),
      enhancement_streak: calculate_enhancement_streak(portfolio_id),
      quality_trajectory: calculate_quality_trajectory(portfolio_id),
      collaboration_score: calculate_collaboration_score(completions)
    }
  end

  defp get_completion_percentage_by_type(completions, enhancement_type) do
    completion = Enum.find(completions, &(&1.enhancement_type == enhancement_type))

    if completion do
      get_completion_percentage(completion)
    else
      0
    end
  end

  defp get_enhancement_completions(portfolio_id) do
    # Query enhancement completion records
    from(ec in "enhancement_completions",
      where: ec.portfolio_id == ^portfolio_id,
      order_by: [desc: ec.completed_at]
    )
    |> Repo.all()
  end

  defp get_completion_percentage(completions, enhancement_type) do
    completion = Enum.find(completions, &(&1.enhancement_type == enhancement_type))
    if completion, do: completion.completion_percentage || 100, else: 0
  end

  defp calculate_overall_completion(completions) do
    if length(completions) > 0 do
      total_completion = Enum.sum(Enum.map(completions, & &1.completion_percentage || 0))
      (total_completion / (length(completions) * 100) * 100) |> Float.round(1)
    else
      0
    end
  end

  defp calculate_enhancement_streak(portfolio_id) do
    # Calculate consecutive days with enhancement activity
    enhancement_dates = get_recent_enhancement_dates(portfolio_id, 30)

    enhancement_dates
    |> Enum.sort(Date, :desc)
    |> calculate_consecutive_days()
  end

  defp calculate_quality_trajectory(portfolio_id) do
    # Get quality scores over time to show improvement trend
    quality_history = get_quality_score_history(portfolio_id)

    if length(quality_history) >= 2 do
      first_score = List.first(quality_history)
      last_score = List.last(quality_history)
      improvement = last_score.score - first_score.score

      trend = cond do
        improvement > 0 -> :improving
        improvement < 0 -> :declining
        true -> :stable
      end

      %{
        trend: trend,
        improvement_points: improvement,
        improvement_percentage: (improvement / first_score.score * 100) |> Float.round(1)
      }
    else
      %{trend: :new, improvement_points: 0, improvement_percentage: 0}
    end
  end

    @doc """
  Calculate collaboration score based on completions
  """
  defp calculate_collaboration_score(completions) do
    if length(completions) == 0 do
      0
    else
      # Score based on number of collaborative completions
      collaborative_completions = Enum.count(completions, fn completion ->
        # Check if completion involved collaboration
        collaborator_count = get_collaborator_count(completion)
        collaborator_count > 1
      end)

      # Calculate percentage of collaborative work
      collaboration_rate = collaborative_completions / length(completions)

      # Score out of 100
      (collaboration_rate * 100) |> Float.round(1)
    end
  end

  @doc """
  Get the last enhancement date from completions
  """
  defp get_last_enhancement_date(completions) do
    case Enum.max_by(completions, & &1.completed_at, Date, fn -> nil end) do
      nil -> nil
      completion -> completion.completed_at
    end
  end

  @doc """
  Get recent enhancement dates for streak calculation
  """
  defp get_recent_enhancement_dates(portfolio_id, days) do
    cutoff_date = Date.utc_today() |> Date.add(-days)

    # Mock implementation - replace with actual query
    # In real implementation, query enhancement_completions table:
    # from(ec in "enhancement_completions",
    #   where: ec.portfolio_id == ^portfolio_id,
    #   where: ec.completed_at >= ^cutoff_date,
    #   select: ec.completed_at,
    #   order_by: [desc: ec.completed_at]
    # )
    # |> Repo.all()

    # Mock data for now
    generate_mock_enhancement_dates(portfolio_id, days)
  end

  @doc """
  Calculate consecutive days with enhancement activity
  """
  defp calculate_consecutive_days(dates) do
    if length(dates) == 0 do
      0
    else
      dates
      |> Enum.sort(Date, :desc)
      |> Enum.reduce_while({0, nil}, fn date, {streak, last_date} ->
        case last_date do
          nil ->
            {:cont, {1, date}}
          prev_date ->
            days_diff = Date.diff(prev_date, date)
            if days_diff <= 1 do
              {:cont, {streak + 1, date}}
            else
              {:halt, {streak, date}}
            end
        end
      end)
      |> elem(0)
    end
  end

  @doc """
  Get quality score history for trajectory calculation
  """
  defp get_quality_score_history(portfolio_id) do
    # Mock implementation - replace with actual query
    # In real implementation, query quality_score_history table:
    # from(qsh in "portfolio_quality_history",
    #   where: qsh.portfolio_id == ^portfolio_id,
    #   order_by: [asc: qsh.recorded_at],
    #   select: %{score: qsh.quality_score, recorded_at: qsh.recorded_at}
    # )
    # |> Repo.all()

    # Mock data for now
    generate_mock_quality_history(portfolio_id)
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_collaborator_count(completion) do
    case completion do
      %{collaborators: collaborators} when is_list(collaborators) ->
        length(collaborators)
      %{collaborator_count: count} when is_integer(count) ->
        count
      _ ->
        1 # Default to single user if no collaboration data
    end
  end

  defp generate_mock_enhancement_dates(portfolio_id, days) do
    # Generate some mock enhancement dates for testing
    today = Date.utc_today()

    # Generate 2-5 random dates within the period
    count = :rand.uniform(4) + 1

    for i <- 1..count do
      days_ago = :rand.uniform(days)
      Date.add(today, -days_ago)
    end
    |> Enum.sort(Date, :desc)
  end

  defp generate_mock_quality_history(portfolio_id) do
    # Generate mock quality score progression
    today = Date.utc_today()

    # Generate 3-7 quality score entries over time
    entries = for i <- 0..6 do
      days_ago = i * 7 # Weekly entries
      date = Date.add(today, -days_ago)

      # Simulate improving quality over time
      base_score = 40 + (6 - i) * 5 + :rand.uniform(10)
      score = min(base_score, 95)

      %{
        score: score,
        recorded_at: date
      }
    end

    Enum.reverse(entries) # Oldest first
  end

  # ============================================================================
  # ADDITIONAL HELPER FUNCTIONS FOR COMPLETION DATA
  # ============================================================================

  defp calculate_overall_completion(completions) do
    if length(completions) > 0 do
      total_completion = Enum.sum(Enum.map(completions, fn completion ->
        get_completion_percentage(completion)
      end))

      # Calculate average completion across all enhancements
      (total_completion / length(completions)) |> Float.round(1)
    else
      0
    end
  end

  defp get_completion_percentage(completion) do
    case completion do
      %{completion_percentage: percentage} when is_number(percentage) ->
        percentage
      %{status: "completed"} ->
        100
      %{status: "in_progress", progress: progress} when is_number(progress) ->
        progress
      _ ->
        0
    end
  end

  # ============================================================================
  # MOCK DATA GENERATORS (replace with real queries when ready)
  # ============================================================================

  defp get_enhancement_completions(portfolio_id) do
    # Mock implementation - replace with actual query
    # from(ec in "enhancement_completions",
    #   where: ec.portfolio_id == ^portfolio_id,
    #   order_by: [desc: ec.completed_at]
    # )
    # |> Repo.all()

    # Generate mock completion data
    generate_mock_completions(portfolio_id)
  end

  defp generate_mock_completions(portfolio_id) do
    enhancement_types = ["voice_over", "writing", "design", "music"]

    for enhancement_type <- enhancement_types do
      # Random chance this enhancement is completed
      if :rand.uniform() > 0.4 do
        %{
          id: System.unique_integer([:positive]),
          portfolio_id: portfolio_id,
          enhancement_type: enhancement_type,
          completion_percentage: :rand.uniform(40) + 60, # 60-100%
          completed_at: Date.add(Date.utc_today(), -:rand.uniform(30)),
          collaborators: generate_mock_collaborators(),
          status: if(:rand.uniform() > 0.3, do: "completed", else: "in_progress")
        }
      end
    end
    |> Enum.filter(& &1) # Remove nils
  end

  defp generate_mock_collaborators() do
    # Generate 0-3 mock collaborators
    count = :rand.uniform(4) - 1 # 0-3

    for i <- 1..count do
      %{
        user_id: 1000 + i,
        role: Enum.random(["peer", "mentor", "expert"]),
        contribution: Enum.random(["feedback", "editing", "review"])
      }
    end
  end

  # ============================================================================
  # QUALITY TRAJECTORY CALCULATION
  # ============================================================================

  defp calculate_quality_trajectory(portfolio_id) do
    quality_history = get_quality_score_history(portfolio_id)

    if length(quality_history) >= 2 do
      first_score = List.first(quality_history)
      last_score = List.last(quality_history)
      improvement = last_score.score - first_score.score

      trend = cond do
        improvement > 5 -> :improving
        improvement < -5 -> :declining
        true -> :stable
      end

      improvement_percentage = if first_score.score > 0 do
        (improvement / first_score.score * 100) |> Float.round(1)
      else
        0
      end

      %{
        trend: trend,
        improvement_points: improvement,
        improvement_percentage: improvement_percentage,
        score_history: quality_history
      }
    else
      %{
        trend: :new,
        improvement_points: 0,
        improvement_percentage: 0,
        score_history: quality_history
      }
    end
  end

end
