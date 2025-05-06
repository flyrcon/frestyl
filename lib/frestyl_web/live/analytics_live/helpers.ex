defmodule FrestylWeb.AnalyticsLive.Helpers do

  alias FrestylWeb.API.AnalyticsController

  @moduledoc """
  Helper functions for the analytics dashboard.
  """

  # --- Formatting ---

    def assign_analytics_config(socket, current_user) do
      config = %{
        apiEndpoint: "/api/analytics/metrics",
        apiKey: AnalyticsController.get_analytics_api_key(current_user), # Make sure get_analytics_api_key is accessible (maybe from import above?)
        debugMode: Mix.env() == :dev
      }

      # Correct line: Call assign on the socket and rebind the socket variable
      socket = Phoenix.LiveView.assign(socket, analytics_config: [data_analytics_config: Jason.encode!(config)])

      # The helper function should return the updated socket
      socket
    end

    # ... (rest of your helper functions) ...

    # Keep the private helpers here or ensure they are accessible
    # defp determine_time_unit(metrics) do ... end
    # defp generate_colors(n) do ... end



  @doc "Formats time in seconds to a human-readable string."
  def format_time(seconds) when is_float(seconds) or is_integer(seconds) do
    total_seconds = round(seconds)
    minutes = div(total_seconds, 60)
    remaining = rem(total_seconds, 60)

    cond do
      minutes == 0 -> "#{remaining}s"
      remaining == 0 -> "#{minutes}m"
      true -> "#{minutes}m #{remaining}s"
    end
  end
  def format_time(_), do: "0s"

  @doc "Formats a number as currency."
  def format_currency(amount) when is_float(amount) or is_integer(amount) do
    "$#{:erlang.float_to_binary(amount, decimals: 2)}"
  end
  def format_currency(%Decimal{} = amount) do
    float = Decimal.to_float(Decimal.round(amount, 2))
    "$#{:erlang.float_to_binary(float, decimals: 2)}"
  end
  def format_currency(_), do: "$0.00"

  @doc "Formats a bitrate in bps, Kbps, or Mbps."
  def format_bitrate(bitrate) when is_number(bitrate) do
    cond do
      bitrate >= 1_000_000 -> "#{Float.round(bitrate / 1_000_000, 2)} Mbps"
      bitrate >= 1_000     -> "#{Float.round(bitrate / 1_000, 2)} Kbps"
      true                 -> "#{round(bitrate)} bps"
    end
  end
  def format_bitrate(_), do: "N/A"

  @doc "Formats latency in milliseconds."
  def format_latency(latency) when is_number(latency) do
    "#{Float.round(latency, 2)} ms"
  end
  def format_latency(_), do: "N/A"

  @doc "Formats a Date or DateTime in long date format."
  def format_date(%Date{} = date), do: Calendar.strftime(date, "%B %d, %Y")
  def format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%B %d, %Y")
  def format_date(%NaiveDateTime{} = naive) do
    case DateTime.from_naive(naive, "Etc/UTC") do
      {:ok, dt} -> format_date(dt)
      _ -> "Unknown date"
    end
  end
  def format_date(_), do: "Unknown date"

  @doc "Formats DateTime or NaiveDateTime for dashboard display."
  def format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %H:%M")
  def format_datetime(%NaiveDateTime{} = naive) do
    case DateTime.from_naive(naive, "Etc/UTC") do
      {:ok, dt} -> format_datetime(dt)
      _ -> "Unknown time"
    end
  end
  def format_datetime(_), do: "Unknown time"

  # --- Metrics Calculations ---

  @doc "Total views from metrics list."
  def total_views(metrics) do
    metrics |> Enum.map(& &1.views) |> Enum.sum() |> to_string()
  end

  @doc "Total unique viewers from metrics list."
  def total_unique_viewers(metrics) do
    metrics |> Enum.map(& &1.unique_viewers) |> Enum.sum() |> to_string()
  end

  @doc "Average watch time from metrics list."
  def average_watch_time([]), do: 0.0
  def average_watch_time(metrics) do
    metrics
    |> Enum.map(& &1.average_watch_time)
    |> Enum.sum()
    |> Kernel./(length(metrics))
  end

  @doc "Total revenue from metrics list."
  def total_revenue(metrics) do
    metrics |> Enum.map(& &1.total_revenue) |> Enum.sum()
  end

  @doc "Fake percentage change for demo purposes."
  def calculate_change(_metrics, _key) do
    :rand.uniform() * 20 - 10
  end

  # --- Chart Data ---

  @doc "Prepares data for views and engagement chart."
  def prepare_views_chart_data(metrics) do
    labels = Enum.map(metrics, &format_date(&1.date))
    views = Enum.map(metrics, & &1.views)
    engagement = Enum.map(metrics, & &1.engagement_rate)

    %{
      labels: labels,
      datasets: [
        %{
          label: "Views",
          data: views,
          borderColor: "rgba(59, 130, 246, 1)",
          backgroundColor: "rgba(59, 130, 246, 0.1)",
          borderWidth: 2,
          fill: true,
          yAxisID: "y"
        },
        %{
          label: "Engagement Rate (%)",
          data: engagement,
          borderColor: "rgba(16, 185, 129, 1)",
          backgroundColor: "rgba(16, 185, 129, 0.1)",
          borderWidth: 2,
          borderDash: [5, 5],
          fill: false,
          yAxisID: "y1"
        }
      ],
      time_unit: determine_time_unit(metrics)
    }
  end

  @doc "Prepares data for revenue chart."
  def prepare_revenue_chart_data(metrics) do
    labels = Enum.map(metrics, &format_date(&1.date))

    %{
      labels: labels,
      datasets: [
        %{
          label: "Subscription Revenue",
          data: Enum.map(metrics, & &1.subscription_revenue),
          backgroundColor: "rgba(59, 130, 246, 0.6)"
        },
        %{
          label: "Donation Revenue",
          data: Enum.map(metrics, & &1.donation_revenue),
          backgroundColor: "rgba(16, 185, 129, 0.6)"
        },
        %{
          label: "Ticket Revenue",
          data: Enum.map(metrics, & &1.ticket_revenue),
          backgroundColor: "rgba(245, 158, 11, 0.6)"
        }
      ],
      time_unit: determine_time_unit(metrics)
    }
  end

  @doc "Prepares data for audience demographics pie chart."
  def prepare_demographics_chart_data(audience_insights) do
    grouped = Enum.group_by(audience_insights, & &1.demographic_group)
    labels = Map.keys(grouped)
    data = Enum.map(labels, &Enum.count(grouped[&1]))
    colors = generate_colors(length(labels))

    %{
      labels: labels,
      datasets: [%{data: data, backgroundColor: colors, hoverOffset: 4}]
    }
  end

  @doc "Prepares data for audience geography chart."
  def prepare_geo_chart_data(audience_insights) do
    grouped = Enum.group_by(audience_insights, & &1.country)
    total = Enum.count(audience_insights)

    data =
      grouped
      |> Enum.map(fn {country, entries} ->
        count = length(entries)
        %{
          country: country,
          count: count,
          percentage: (if total > 0, do: count / total * 100, else: 0)
        }
      end)
      |> Enum.sort_by(& &1.count, :desc)

    %{data: data}
  end

  # --- Private ---

  defp determine_time_unit(metrics) do
    cond do
      length(metrics) > 60 -> "month"
      length(metrics) > 14 -> "week"
      true -> "day"
    end
  end

  defp generate_colors(n) do
    base = [
      "rgba(59, 130, 246, 0.6)",   # Blue
      "rgba(16, 185, 129, 0.6)",   # Green
      "rgba(245, 158, 11, 0.6)",   # Yellow
      "rgba(239, 68, 68, 0.6)",    # Red
      "rgba(139, 92, 246, 0.6)",   # Purple
      "rgba(236, 72, 153, 0.6)",   # Pink
      "rgba(6, 182, 212, 0.6)",    # Cyan
      "rgba(249, 115, 22, 0.6)",   # Orange
      "rgba(75, 85, 99, 0.6)"      # Gray
    ]

    Stream.cycle(base) |> Enum.take(n)
  end
end
