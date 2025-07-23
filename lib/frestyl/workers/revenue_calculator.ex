# lib/frestyl/workers/revenue_calculator.ex
defmodule Frestyl.Workers.RevenueCalculator do
  @moduledoc """
  Calculate and distribute revenue from syndicated content
  """

  use Oban.Worker, queue: :revenue

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Content.{Syndication, Document}
  alias Frestyl.Billing.RevenueDistribution

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"syndication_id" => syndication_id}}) do
    with {:ok, syndication} <- get_syndication_with_document(syndication_id),
         {:ok, revenue} <- calculate_revenue(syndication),
         {:ok, distributions} <- calculate_distributions(syndication, revenue) do

      update_revenue_attribution(syndication, revenue, distributions)
      process_revenue_distributions(distributions)

      :ok
    end
  end

  defp calculate_revenue(syndication) do
    # Platform-specific revenue calculation
    case syndication.platform do
      "medium" -> calculate_medium_revenue(syndication.platform_metrics)
      "linkedin" -> calculate_linkedin_revenue(syndication.platform_metrics)
      _ -> {:ok, Decimal.new("0.00")}
    end
  end

  defp calculate_medium_revenue(metrics) do
    # Medium Partner Program revenue calculation
    # This would integrate with actual Medium API data
    claps = Map.get(metrics, "claps", 0)
    reading_time = Map.get(metrics, "reading_time", 0)

    # Simplified calculation - actual would be more complex
    revenue = (claps * 0.01) + (reading_time * 0.02)
    {:ok, Decimal.new(to_string(revenue))}
  end

  defp calculate_distributions(syndication, total_revenue) do
    splits = syndication.collaboration_revenue_splits || %{}

    distributions = Enum.map(splits, fn {user_id, split_config} ->
      percentage = split_config["percentage"] || 0
      amount = Decimal.mult(total_revenue, Decimal.div(Decimal.new(percentage), Decimal.new(100)))

      %{
        user_id: String.to_integer(user_id),
        amount: amount,
        percentage: percentage,
        syndication_id: syndication.id
      }
    end)

    {:ok, distributions}
  end

  defp get_syndication_with_document(syndication_id) do
    case Frestyl.Repo.get(Syndication, syndication_id) do
      nil -> {:error, :not_found}
      syndication ->
        syndication = Frestyl.Repo.preload(syndication, [:document, :account])
        {:ok, syndication}
    end
  end

  defp calculate_linkedin_revenue(metrics) do
    # LinkedIn revenue calculation (simplified)
    views = Map.get(metrics, "views", 0)
    likes = Map.get(metrics, "likes", 0)
    comments = Map.get(metrics, "comments", 0)

    # Simple calculation - you can make this more sophisticated
    revenue = (views * 0.001) + (likes * 0.05) + (comments * 0.10)
    {:ok, Decimal.new(to_string(revenue))}
  end

  defp update_revenue_attribution(syndication, revenue, distributions) do
    # Update the syndication record with revenue and splits
    attrs = %{
      revenue_attribution: revenue,
      collaboration_revenue_splits: format_revenue_splits(distributions),
      last_metrics_update: DateTime.utc_now()
    }

    syndication
    |> Syndication.changeset(attrs)
    |> Frestyl.Repo.update()
  end

  defp process_revenue_distributions(distributions) do
    # Process each revenue distribution
    Enum.each(distributions, fn distribution ->
      # Here you would typically:
      # 1. Create payment records
      # 2. Update user balances
      # 3. Send notifications
      # 4. Log transactions

      # For now, just log the distribution
      require Logger
      Logger.info("Revenue distribution: User #{distribution.user_id} earned $#{distribution.amount}")

      # You could also store this in a revenue_distributions table
      create_revenue_distribution_record(distribution)
    end)
  end

  defp format_revenue_splits(distributions) do
    distributions
    |> Enum.map(fn dist ->
      {to_string(dist.user_id), %{
        "amount" => to_string(dist.amount),
        "percentage" => dist.percentage,
        "processed_at" => DateTime.utc_now()
      }}
    end)
    |> Map.new()
  end

  defp create_revenue_distribution_record(distribution) do
    # Create a record of the revenue distribution
    # You might want to create a RevenueDistribution schema for this
    attrs = %{
      user_id: distribution.user_id,
      syndication_id: distribution.syndication_id,
      amount: distribution.amount,
      percentage: distribution.percentage,
      processed_at: DateTime.utc_now(),
      status: "processed"
    }

    # For now, just return :ok
    # In a real implementation, you'd insert this into a revenue_distributions table
    :ok
  end
end
