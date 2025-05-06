defmodule FrestylWeb.AnalyticsLive.FormatHelpers do
  @moduledoc """
  Helper functions for formatting data in analytics views.
  """

  @doc """
  Formats a date to a human-readable string.
  """
  def format_date(%Date{} = date) do
    Calendar.strftime(date, "%b %d, %Y")
  end
  def format_date(_), do: "N/A"

  @doc """
  Formats a datetime to a human-readable string.
  """
  def format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M")
  end
  def format_datetime(_), do: "N/A"

  @doc """
  Formats a currency value.
  """
  def format_currency(%Decimal{} = amount) do
    "$#{Decimal.round(amount, 2)}"
  end
  def format_currency(amount) when is_float(amount) or is_integer(amount) do
    "$#{:erlang.float_to_binary(amount / 1, [decimals: 2])}"
  end
  def format_currency(_), do: "$0.00"

  @doc """
  Formats a bitrate value.
  """
  def format_bitrate(bitrate) when is_float(bitrate) or is_integer(bitrate) do
    cond do
      bitrate >= 1_000_000 -> "#{Float.round(bitrate / 1_000_000, 2)} Mbps"
      bitrate >= 1_000 -> "#{Float.round(bitrate / 1_000, 2)} Kbps"
      true -> "#{round(bitrate)} bps"
    end
  end
  def format_bitrate(_), do: "N/A"

  @doc """
  Formats a latency value.
  """
  def format_latency(latency) when is_float(latency) or is_integer(latency) do
    "#{Float.round(latency, 2)} ms"
  end
  def format_latency(_), do: "N/A"

  @doc """
  Returns a color based on bitrate quality.
  """
  def bitrate_quality_color(metrics) do
    avg_bitrate = average_bitrate(metrics)

    cond do
      avg_bitrate >= 2_000_000 -> "bg-green-500" # Good (2+ Mbps)
      avg_bitrate >= 1_000_000 -> "bg-yellow-500" # Fair (1-2 Mbps)
      avg_bitrate > 0 -> "bg-red-500" # Poor (< 1 Mbps)
      true -> "bg-gray-500" # No data
    end
  end

  @doc """
  Returns a text description of bitrate quality.
  """
  def bitrate_quality_text(metrics) do
    avg_bitrate = average_bitrate(metrics)

    cond do
      avg_bitrate >= 2_000_000 -> "Good"
      avg_bitrate >= 1_000_000 -> "Fair"
      avg_bitrate > 0 -> "Poor"
      true -> "No data"
    end
  end

  @doc """
  Returns a description of bitrate quality.
  """
  def bitrate_quality_description(metrics) do
    avg_bitrate = average_bitrate(metrics)

    cond do
      avg_bitrate >= 2_000_000 -> "Your stream quality is good for most content types."
      avg_bitrate >= 1_000_000 -> "Adequate for standard definition, but may have issues with high-definition content."
      avg_bitrate > 0 -> "Low bitrate may cause visual quality issues for viewers."
      true -> "No bitrate data available."
    end
  end

  @doc """
  Returns a color based on buffer quality.
  """
  def buffer_quality_color(metrics) do
    buffer_per_minute = buffer_events_per_minute(metrics)

    cond do
      buffer_per_minute < 0.1 -> "bg-green-500" # Good (< 0.1 buffer events per minute)
      buffer_per_minute < 0.5 -> "bg-yellow-500" # Fair (0.1-0.5 buffer events per minute)
      buffer_per_minute > 0 -> "bg-red-500" # Poor (> 0.5 buffer events per minute)
      true -> "bg-gray-500" # No data
    end
  end

  @doc """
  Returns a text description of buffer quality.
  """
  def buffer_quality_text(metrics) do
    buffer_per_minute = buffer_events_per_minute(metrics)

    cond do
      buffer_per_minute < 0.1 -> "Good"
      buffer_per_minute < 0.5 -> "Fair"
      buffer_per_minute > 0 -> "Poor"
      true -> "No data"
    end
  end

  @doc """
  Returns a description of buffer quality.
  """
  def buffer_quality_description(metrics) do
    buffer_per_minute = buffer_events_per_minute(metrics)

    cond do
      buffer_per_minute < 0.1 -> "Few buffering issues detected, viewers likely have a smooth experience."
      buffer_per_minute < 0.5 -> "Some buffering issues may be affecting user experience."
      buffer_per_minute > 0 -> "Frequent buffering is likely causing significant viewer drop-off."
      true -> "No buffer event data available."
    end
  end

  @doc """
  Returns a color based on latency quality.
  """
  def latency_quality_color(metrics) do
    avg_latency = average_latency(metrics)

    cond do
      avg_latency < 2000 -> "bg-green-500" # Good (< 2 seconds)
      avg_latency < 5000 -> "bg-yellow-500" # Fair (2-5 seconds)
      avg_latency > 0 -> "bg-red-500" # Poor (> 5 seconds)
      true -> "bg-gray-500" # No data
    end
  end

  @doc """
  Returns a text description of latency quality.
  """
  def latency_quality_text(metrics) do
    avg_latency = average_latency(metrics)

    cond do
      avg_latency < 2000 -> "Good"
      avg_latency < 5000 -> "Fair"
      avg_latency > 0 -> "Poor"
      true -> "No data"
    end
  end

  @doc """
  Returns a description of latency quality.
  """
  def latency_quality_description(metrics) do
    avg_latency = average_latency(metrics)

    cond do
      avg_latency < 2000 -> "Low latency enables good interactivity for live streams."
      avg_latency < 5000 -> "Moderate latency may impact real-time interaction."
      avg_latency > 0 -> "High latency will significantly affect interactive elements."
      true -> "No latency data available."
    end
  end

  @doc """
  Returns performance recommendations based on metrics.
  """
  def performance_recommendations(metrics) do
    recommendations = []

    # Bitrate recommendations
    recommendations =
      case bitrate_quality_text(metrics) do
        "Poor" ->
          ["Consider upgrading your internet connection or lowering your stream resolution",
           "Test different stream servers to find the best connection for your location" | recommendations]
        "Fair" ->
          ["Try a slightly lower resolution to improve overall stream stability" | recommendations]
        _ ->
          recommendations
      end

    # Buffer recommendations
    recommendations =
      case buffer_quality_text(metrics) do
        "Poor" ->
          ["Evaluate your network for potential sources of instability",
           "Consider using a wired connection instead of Wi-Fi for streaming" | recommendations]
        "Fair" ->
          ["Monitor your connection during peak usage hours to identify potential congestion issues" | recommendations]
        _ ->
          recommendations
      end

    # Latency recommendations
    recommendations =
      case latency_quality_text(metrics) do
        "Poor" ->
          ["Choose a CDN server that's geographically closer to your primary audience" | recommendations]
        "Fair" ->
          ["For interactive streams, consider using low-latency streaming options if available" | recommendations]
        _ ->
          recommendations
      end

    # If we have no recommendations, add a default one
    if Enum.empty?(recommendations) do
      ["Continue monitoring your stream performance to maintain quality"]
    else
      recommendations
    end
  end

  # Helper functions for calculating metrics

  defp average_bitrate(metrics) do
    non_nil_bitrates = Enum.filter(metrics, fn m -> m.average_bitrate end)

    if Enum.empty?(non_nil_bitrates) do
      0
    else
      non_nil_bitrates
      |> Enum.map(fn m -> m.average_bitrate end)
      |> Enum.sum()
      |> Kernel./(length(non_nil_bitrates))
    end
  end

  defp buffer_events_per_minute(metrics) do
    # Get the total duration in minutes
    time_range = time_range_in_minutes(metrics)

    if time_range <= 0 do
      0
    else
      # Calculate buffer events per minute
      total_buffer_events = metrics |> Enum.map(fn m -> m.buffer_count || 0 end) |> Enum.sum()
      total_buffer_events / time_range
    end
  end

  defp average_latency(metrics) do
    non_nil_latencies = Enum.filter(metrics, fn m -> m.latency end)

    if Enum.empty?(non_nil_latencies) do
      0
    else
      non_nil_latencies
      |> Enum.map(fn m -> m.latency end)
      |> Enum.sum()
      |> Kernel./(length(non_nil_latencies))
    end
  end

  defp time_range_in_minutes(metrics) do
    if Enum.empty?(metrics) do
      0
    else
      # Get the timestamps sorted
      timestamps =
        metrics
        |> Enum.map(fn m -> m.recorded_at end)
        |> Enum.filter(fn t -> t end)
        |> Enum.sort(DateTime)

      if length(timestamps) < 2 do
        # Default to 1 minute if we can't calculate
        1
      else
        # Get first and last timestamp
        first = List.first(timestamps)
        last = List.last(timestamps)

        # Calculate difference in minutes
        DateTime.diff(last, first) / 60
      end
    end
  end
end
