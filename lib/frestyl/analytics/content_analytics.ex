# lib/frestyl/analytics/content_analytics.ex
defmodule Frestyl.Analytics.ContentAnalytics do
  @moduledoc """
  Analytics for collaborative content and syndication performance
  """

  import Ecto.Query
  alias Frestyl.Repo
  alias Frestyl.Content.{Document, Syndication, CollaborationCampaign}

  @doc """
  Get comprehensive analytics for an account's content performance
  """
  def get_account_analytics(account, date_range \\ :last_30_days) do
    {start_date, end_date} = get_date_range(date_range)

    %{
      content_performance: get_content_performance(account, start_date, end_date),
      collaboration_metrics: get_collaboration_metrics(account, start_date, end_date),
      syndication_analytics: get_syndication_analytics(account, start_date, end_date),
      revenue_summary: get_revenue_summary(account, start_date, end_date),
      top_performing_content: get_top_performing_content(account, start_date, end_date)
    }
  end

  defp get_content_performance(account, start_date, end_date) do
    query = from d in Document,
      join: s in Syndication, on: s.document_id == d.id,
      where: s.account_id == ^account.id,
      where: s.syndicated_at >= ^start_date and s.syndicated_at <= ^end_date,
      group_by: d.id,
      select: %{
        document_id: d.id,
        title: d.title,
        total_views: sum(fragment("COALESCE((?->>'views')::integer, 0)", s.platform_metrics)),
        total_engagement: sum(fragment("COALESCE((?->>'engagement')::integer, 0)", s.platform_metrics)),
        platforms_count: count(s.platform),
        total_revenue: sum(s.revenue_attribution)
      }

    Repo.all(query)
  end

  defp get_collaboration_metrics(account, start_date, end_date) do
    campaign_query = from c in CollaborationCampaign,
      where: c.account_id == ^account.id,
      where: c.inserted_at >= ^start_date and c.inserted_at <= ^end_date

    campaigns = Repo.all(campaign_query)

    %{
      total_campaigns: length(campaigns),
      active_campaigns: Enum.count(campaigns, &(&1.status == "active")),
      completed_campaigns: Enum.count(campaigns, &(&1.status == "completed")),
      total_collaborators: get_unique_collaborators_count(account, start_date, end_date),
      avg_collaboration_score: calculate_avg_collaboration_score(campaigns)
    }
  end

  defp get_syndication_analytics(account, start_date, end_date) do
    query = from s in Syndication,
      where: s.account_id == ^account.id,
      where: s.syndicated_at >= ^start_date and s.syndicated_at <= ^end_date

    syndications = Repo.all(query)

    platform_breakdown = syndications
    |> Enum.group_by(& &1.platform)
    |> Enum.map(fn {platform, synds} ->
      %{
        platform: platform,
        count: length(synds),
        total_views: Enum.sum(Enum.map(synds, &get_metric(&1, "views"))),
        total_engagement: Enum.sum(Enum.map(synds, &get_metric(&1, "engagement"))),
        success_rate: calculate_success_rate(synds)
      }
    end)

    %{
      total_syndications: length(syndications),
      successful_syndications: Enum.count(syndications, &(&1.syndication_status == "published")),
      platform_breakdown: platform_breakdown,
      avg_time_to_publish: calculate_avg_publish_time(syndications)
    }
  end

  defp get_revenue_summary(account, start_date, end_date) do
    query = from s in Syndication,
      where: s.account_id == ^account.id,
      where: s.syndicated_at >= ^start_date and s.syndicated_at <= ^end_date,
      where: not is_nil(s.revenue_attribution),
      select: %{
        total_revenue: sum(s.revenue_attribution),
        avg_revenue_per_post: avg(s.revenue_attribution),
        revenue_by_platform: fragment("json_object_agg(?, ?)", s.platform, s.revenue_attribution)
      }

    Repo.one(query) || %{total_revenue: 0, avg_revenue_per_post: 0, revenue_by_platform: %{}}
  end

  defp get_top_performing_content(account, start_date, end_date) do
    query = from d in Document,
      join: s in Syndication, on: s.document_id == d.id,
      where: s.account_id == ^account.id,
      where: s.syndicated_at >= ^start_date and s.syndicated_at <= ^end_date,
      group_by: [d.id, d.title],
      order_by: [desc: sum(fragment("COALESCE((?->>'views')::integer, 0)", s.platform_metrics))],
      limit: 10,
      select: %{
        document_id: d.id,
        title: d.title,
        total_views: sum(fragment("COALESCE((?->>'views')::integer, 0)", s.platform_metrics)),
        total_engagement: sum(fragment("COALESCE((?->>'engagement')::integer, 0)", s.platform_metrics)),
        revenue: sum(s.revenue_attribution),
        platforms: fragment("array_agg(?)", s.platform)
      }

    Repo.all(query)
  end

  # Helper functions
  defp get_date_range(:last_7_days), do: {DateTime.add(DateTime.utc_now(), -7, :day), DateTime.utc_now()}
  defp get_date_range(:last_30_days), do: {DateTime.add(DateTime.utc_now(), -30, :day), DateTime.utc_now()}
  defp get_date_range(:last_90_days), do: {DateTime.add(DateTime.utc_now(), -90, :day), DateTime.utc_now()}

  defp get_metric(syndication, metric_name) do
    get_in(syndication.platform_metrics, [metric_name]) || 0
  end

  defp calculate_success_rate(syndications) when length(syndications) == 0, do: 0
  defp calculate_success_rate(syndications) do
    successful = Enum.count(syndications, &(&1.syndication_status == "published"))
    (successful / length(syndications) * 100) |> Float.round(1)
  end

  defp calculate_avg_publish_time(syndications) do
    # Calculate average time from creation to publication
    times = Enum.filter_map(syndications,
      &(not is_nil(&1.syndicated_at)),
      &DateTime.diff(&1.syndicated_at, &1.inserted_at, :minute)
    )

    if Enum.empty?(times), do: 0, else: Enum.sum(times) / length(times) |> Float.round(0)
  end

  defp get_unique_collaborators_count(account, start_date, end_date) do
    # Count unique collaborators across all campaigns in the date range
    from(cc in Frestyl.Content.CampaignContributor,
      join: c in CollaborationCampaign, on: cc.campaign_id == c.id,
      where: c.account_id == ^account.id,
      where: c.inserted_at >= ^start_date and c.inserted_at <= ^end_date,
      select: count(cc.user_id, :distinct)
    ) |> Repo.one() || 0
  end

  defp calculate_avg_collaboration_score(campaigns) when length(campaigns) == 0, do: 0
  defp calculate_avg_collaboration_score(campaigns) do
    # Calculate based on contributor engagement, completion rate, etc.
    scores = Enum.map(campaigns, &calculate_campaign_score/1)
    Enum.sum(scores) / length(scores) |> Float.round(1)
  end

  defp calculate_campaign_score(campaign) do
    # Scoring algorithm based on:
    # - Number of active contributors
    # - Completion rate
    # - Content quality metrics
    base_score = min(length(campaign.contributors) * 10, 50)
    completion_bonus = if campaign.status == "completed", do: 25, else: 0
    base_score + completion_bonus
  end
end
