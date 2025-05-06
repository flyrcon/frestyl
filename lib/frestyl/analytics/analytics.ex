defmodule Frestyl.Analytics do
  @moduledoc """
  The Analytics context provides functions for tracking, retrieving, and analyzing
  various metrics related to channel usage, session performance, audience engagement,
  and revenue reporting.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Analytics.{Metric, SessionMetric, ChannelMetric, RevenueMetric, AudienceInsight}

  @doc """
  Returns a list of metrics for a given channel within a date range.
  """
  def list_channel_metrics(channel_id, start_date, end_date) do
    ChannelMetric
    |> where([m], m.channel_id == ^channel_id)
    |> where([m], m.recorded_at >= ^start_date and m.recorded_at <= ^end_date)
    |> order_by([m], asc: m.recorded_at)
    |> Repo.all()
  end

  @doc """
  Returns aggregated channel metrics grouped by day, week, or month.
  """
  def aggregate_channel_metrics(channel_id, start_date, end_date, interval \\ "day") do
    interval_fragment =
      case interval do
        "day" -> "date_trunc('day', recorded_at)"
        "week" -> "date_trunc('week', recorded_at)"
        "month" -> "date_trunc('month', recorded_at)"
      end

    query =
      from m in ChannelMetric,
        where: m.channel_id == ^channel_id,
        where: m.recorded_at >= ^start_date and m.recorded_at <= ^end_date,
        group_by: fragment(^interval_fragment),
        select: %{
          date: fragment(^interval_fragment),
          views: sum(m.views),
          unique_viewers: sum(m.unique_viewers),
          average_watch_time: avg(m.average_watch_time),
          engagement_rate: avg(m.engagement_rate)
        },
        order_by: fragment(^interval_fragment)

    Repo.all(query)
  end

  @doc """
  Returns session metrics for a specific session.
  """
  def get_session_metrics(session_id) do
    SessionMetric
    |> where([m], m.session_id == ^session_id)
    |> Repo.all()
  end

  @doc """
  Returns performance metrics for streaming quality.
  """
  def get_streaming_performance_metrics(session_id) do
    SessionMetric
    |> where([m], m.session_id == ^session_id)
    |> select([m], %{
      buffer_count: m.buffer_count,
      average_bitrate: m.average_bitrate,
      dropped_frames: m.dropped_frames,
      latency: m.latency,
      recorded_at: m.recorded_at
    })
    |> Repo.all()
  end

  @doc """
  Returns audience insights for an event.
  """
  def get_audience_insights(event_id) do
    AudienceInsight
    |> where([a], a.event_id == ^event_id)
    |> Repo.all()
  end

  @doc """
  Returns demographic breakdown of audience for an event.
  """
  def get_audience_demographics(event_id) do
    AudienceInsight
    |> where([a], a.event_id == ^event_id)
    |> group_by([a], a.demographic_group)
    |> select([a], %{
      demographic_group: a.demographic_group,
      count: count(a.id),
      average_watch_time: avg(a.watch_time),
      engagement_rate: avg(a.engagement_rate)
    })
    |> Repo.all()
  end

  @doc """
  Returns geographic distribution of audience for an event.
  """
  def get_audience_geography(event_id) do
    AudienceInsight
    |> where([a], a.event_id == ^event_id)
    |> group_by([a], a.country)
    |> select([a], %{
      country: a.country,
      count: count(a.id),
      percentage: fragment("count(*) * 100.0 / sum(count(*)) over()")
    })
    |> Repo.all()
  end

  @doc """
  Returns revenue metrics for a channel within a date range.
  """
  def get_revenue_metrics(channel_id, start_date, end_date) do
    RevenueMetric
    |> where([r], r.channel_id == ^channel_id)
    |> where([r], r.date >= ^start_date and r.date <= ^end_date)
    |> Repo.all()
  end

  @doc """
  Returns revenue metrics aggregated by day, week, or month.
  """
  def aggregate_revenue_metrics(channel_id, start_date, end_date, interval \\ "day") do
    interval_fragment = case interval do
      "day" -> "date_trunc('day', date)"
      "week" -> "date_trunc('week', date)"
      "month" -> "date_trunc('month', date)"
    end

    query = from r in RevenueMetric,
      where: r.channel_id == ^channel_id,
      where: r.date >= ^start_date and r.date <= ^end_date,
      group_by: fragment(^interval_fragment),
      select: %{
        date: fragment(^interval_fragment),
        total_revenue: sum(r.total_amount),
        subscription_revenue: sum(r.subscription_amount),
        donation_revenue: sum(r.donation_amount),
        ticket_revenue: sum(r.ticket_amount)
      },
      order_by: fragment(^interval_fragment)

    Repo.all(query)
  end

  @doc """
  Tracks a new metric for a channel.
  """
  def track_channel_metric(attrs \\ %{}) do
    %ChannelMetric{}
    |> ChannelMetric.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Tracks a new session metric.
  """
  def track_session_metric(attrs \\ %{}) do
    %SessionMetric{}
    |> SessionMetric.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Tracks a new audience insight.
  """
  def track_audience_insight(attrs \\ %{}) do
    %AudienceInsight{}
    |> AudienceInsight.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Records revenue for a channel.
  """
  def record_revenue(attrs \\ %{}) do
    %RevenueMetric{}
    |> RevenueMetric.changeset(attrs)
    |> Repo.insert()
  end
end
