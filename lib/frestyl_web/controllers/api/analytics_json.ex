defmodule FrestylWeb.API.AnalyticsJSON do
  @moduledoc """
  JSON view for the Analytics API.
  """

  @doc """
  Renders a list of metrics.
  """
  def index(%{metrics: metrics}) do
    %{data: render_many(metrics, __MODULE__, "metric.json")}
  end

  @doc """
  Renders a single metric.
  """
  def show(%{metric: metric}) do
    %{data: render_one(metric, __MODULE__, "metric.json")}
  end

  @doc """
  Renders channel metrics.
  """
  def channel_metrics(%{metrics: metrics}) do
    %{
      data: Enum.map(metrics, fn metric ->
        %{
          date: format_date(metric.date),
          views: metric.views,
          unique_viewers: metric.unique_viewers,
          average_watch_time: metric.average_watch_time,
          engagement_rate: metric.engagement_rate,
          comments_count: metric.comments_count || 0,
          shares_count: metric.shares_count || 0,
          likes_count: metric.likes_count || 0
        }
      end)
    }
  end

  @doc """
  Renders session metrics.
  """
  def session_metrics(%{metrics: metrics}) do
    %{
      data: Enum.map(metrics, fn metric ->
        %{
          recorded_at: format_datetime(metric.recorded_at),
          concurrent_viewers: metric.concurrent_viewers,
          peak_viewers: metric.peak_viewers,
          average_watch_time: metric.average_watch_time,
          buffer_count: metric.buffer_count,
          average_bitrate: metric.average_bitrate,
          dropped_frames: metric.dropped_frames,
          latency: metric.latency,
          resolution: metric.resolution,
          cdn_provider: metric.cdn_provider
        }
      end)
    }
  end

  @doc """
  Renders audience insights.
  """
  def audience_insights(%{insights: insights, demographics: demographics, geography: geography}) do
    %{
      data: %{
        insights: Enum.map(insights, fn insight ->
          %{
            demographic_group: insight.demographic_group,
            age_range: insight.age_range,
            gender: insight.gender,
            country: insight.country,
            region: insight.region,
            city: insight.city,
            watch_time: insight.watch_time,
            engagement_rate: insight.engagement_rate,
            interaction_count: insight.interaction_count,
            device_type: insight.device_type,
            browser: insight.browser,
            os: insight.os,
            referral_source: insight.referral_source,
            recorded_at: format_datetime(insight.recorded_at)
          }
        end),
        demographics: Enum.map(demographics, fn demographic ->
          %{
            demographic_group: demographic.demographic_group,
            count: demographic.count,
            average_watch_time: demographic.average_watch_time,
            engagement_rate: demographic.engagement_rate
          }
        end),
        geography: Enum.map(geography, fn geo ->
          %{
            country: geo.country,
            count: geo.count,
            percentage: geo.percentage
          }
        end)
      }
    }
  end

  @doc """
  Renders revenue metrics.
  """
  def revenue_metrics(%{metrics: metrics}) do
    %{
      data: Enum.map(metrics, fn metric ->
        %{
          date: format_date(metric.date),
          total_revenue: convert_decimal(metric.total_revenue),
          subscription_revenue: convert_decimal(metric.subscription_revenue),
          donation_revenue: convert_decimal(metric.donation_revenue),
          ticket_revenue: convert_decimal(metric.ticket_revenue),
          merchandise_revenue: convert_decimal(metric.merchandise_amount),
          subscription_count: metric.subscription_count,
          donation_count: metric.donation_count,
          ticket_count: metric.ticket_count,
          merchandise_count: metric.merchandise_count,
          currency: metric.currency
        }
      end)
    }
  end

  @doc """
  Renders an error.
  """
  def error(%{changeset: changeset}) do
    %{
      error: true,
      details: Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)
    }
  end

  def error(%{error: error}) do
    %{
      error: true,
      message: error
    }
  end

  # Helper functions for rendering
  defp render_one(item, view, template) do
    view.render(template, %{item: item})
  end

  defp render_many(items, view, template) do
    Enum.map(items, fn item ->
      view.render(template, %{item: item})
    end)
  end

  def render("metric.json", %{item: metric}) do
    # Generic renderer for any type of metric
    metric
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__])
    |> convert_decimals()
    |> convert_dates()
  end

  # Helper functions
  defp format_date(%Date{} = date) do
    Date.to_iso8601(date)
  end
  defp format_date(_), do: nil

  defp format_datetime(%DateTime{} = datetime) do
    DateTime.to_iso8601(datetime)
  end
  defp format_datetime(_), do: nil

  defp convert_decimal(%Decimal{} = decimal) do
    Decimal.to_float(decimal)
  end
  defp convert_decimal(value), do: value

  defp convert_decimals(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      Map.put(acc, k, if(is_struct(v, Decimal), do: convert_decimal(v), else: v))
    end)
  end

  defp convert_dates(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      value = cond do
        is_struct(v, DateTime) -> format_datetime(v)
        is_struct(v, Date) -> format_date(v)
        true -> v
      end
      Map.put(acc, k, value)
    end)
  end
end
