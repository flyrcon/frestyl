# lib/frestyl/workers/metrics_collector.ex
defmodule Frestyl.Workers.MetricsCollector do
  @moduledoc """
  Background job to collect metrics from syndicated platforms
  """

  use Oban.Worker, queue: :metrics

  alias Frestyl.Content.Syndication
  alias Frestyl.HTTP.{MediumClient, LinkedInClient}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"syndication_id" => syndication_id}}) do
    with {:ok, syndication} <- get_syndication(syndication_id),
         {:ok, metrics} <- collect_platform_metrics(syndication) do

      update_syndication_metrics(syndication, metrics)
      schedule_next_collection(syndication)

      :ok
    else
      error ->
        {:error, error}
    end
  end

  defp get_syndication(id) do
    case Frestyl.Repo.get(Syndication, id) do
      nil -> {:error, :not_found}
      syndication -> {:ok, syndication}
    end
  end

  defp collect_platform_metrics(syndication) do
    case syndication.platform do
      "medium" -> MediumClient.get_post_stats(syndication.external_id)
      "linkedin" -> LinkedInClient.get_post_analytics(syndication.external_id)
      "hashnode" -> HashnodeClient.get_post_metrics(syndication.external_id)
      _ -> {:ok, %{}}
    end
  end

  defp update_syndication_metrics(syndication, new_metrics) do
    updated_metrics = Map.merge(syndication.platform_metrics, new_metrics)

    Syndication.changeset(syndication, %{
      platform_metrics: updated_metrics,
      last_metrics_update: DateTime.utc_now()
    })
    |> Frestyl.Repo.update()

    # Broadcast metrics update
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "syndication_metrics:#{syndication.document_id}",
      {:metrics_updated, syndication.id, updated_metrics}
    )
  end

  defp schedule_next_collection(syndication) do
    # Schedule next collection based on content age
    delay_hours = case DateTime.diff(DateTime.utc_now(), syndication.syndicated_at, :hour) do
      hours when hours < 24 -> 1  # Hourly for first day
      hours when hours < 168 -> 6  # Every 6 hours for first week
      _ -> 24  # Daily afterwards
    end

    %{syndication_id: syndication.id}
    |> __MODULE__.new(schedule_in: delay_hours * 3600)
    |> Oban.insert()
  end
end
