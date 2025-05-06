defmodule FrestylWeb.AnalyticsLive.PerformanceDashboard do
  use FrestylWeb, :live_view
  alias Frestyl.Analytics
  alias Frestyl.Channels
  import FrestylWeb.AnalyticsLive.Helpers, only: [
    format_bitrate: 1,
    format_latency: 1
  ]

  @impl true
  def mount(_params, session, socket) do
    with {:ok, user_id} <- Map.fetch(session, "user_id"),
         user when not is_nil(user) <- Frestyl.Accounts.get_user(user_id) do
      # Get channels owned by the user
      channels = Channels.list_channels_by_owner(user.id)

      # Default to first channel if available
      default_channel = List.first(channels)

      # Get sessions for the default channel
      sessions = if default_channel do
        Channels.list_recent_sessions(default_channel.id, 10)
      else
        []
      end

      # Default to first session if available
      default_session = List.first(sessions)

      socket =
        socket
        |> assign(:current_user, user)
        |> assign(:channels, channels)
        |> assign(:selected_channel_id, if(default_channel, do: default_channel.id, else: nil))
        |> assign(:sessions, sessions)
        |> assign(:selected_session_id, if(default_session, do: default_session.id, else: nil))
        |> assign(:performance_metrics, [])
        |> assign(:bitrate_data, %{})
        |> assign(:buffer_events_data, %{})
        |> assign(:latency_data, %{})
        |> assign(:resolution_distribution, %{})
        |> assign(:loading, false)

      # Load performance data if we have a default session
      socket = if default_session do
        load_performance_data(socket)
      else
        socket
      end

      {:ok, socket}
    else
      _ ->
        {:ok, socket
              |> put_flash(:error, "You must be logged in to view analytics")
              |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Handle channel_id and session_id from URL if provided
    socket =
      socket
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-channel", %{"channel_id" => channel_id}, socket) do
    # Get sessions for the selected channel
    sessions = Channels.list_recent_sessions(channel_id, 10)

    # Default to first session if available
    default_session = List.first(sessions)

    socket =
      socket
      |> assign(:selected_channel_id, channel_id)
      |> assign(:sessions, sessions)
      |> assign(:selected_session_id, if(default_session, do: default_session.id, else: nil))

    # Load performance data if we have a default session
    socket = if default_session do
      load_performance_data(socket)
    else
      assign(socket, :performance_metrics, [])
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-session", %{"session_id" => session_id}, socket) do
    socket =
      socket
      |> assign(:selected_session_id, session_id)
      |> load_performance_data()

    {:noreply, socket}
  end

  defp apply_action(socket, :index, params) do
    # Handle optional params
    socket =
      with channel_id when not is_nil(channel_id) <- params["channel_id"],
           channel when not is_nil(channel) <- Channels.get_channel(channel_id) do
        # Get sessions for the channel
        sessions = Channels.list_recent_sessions(channel_id, 10)

        socket
        |> assign(:selected_channel_id, channel_id)
        |> assign(:sessions, sessions)
      else
        _ -> socket
      end

    # Handle session_id if provided
    socket =
      with session_id when not is_nil(session_id) <- params["session_id"],
           session when not is_nil(session) <- Channels.get_session(session_id) do
        assign(socket, :selected_session_id, session_id)
      else
        _ -> socket
      end

    # Load data with applied filters
    if socket.assigns.selected_session_id do
      load_performance_data(socket)
    else
      socket
    end
  end

  defp load_performance_data(socket) do
    %{selected_session_id: session_id} = socket.assigns

    # Only proceed if we have a session selected
    if session_id do
      socket = assign(socket, :loading, true)

      # Load streaming performance metrics
      performance_metrics = Analytics.get_streaming_performance_metrics(session_id)

      # Prepare chart data
      bitrate_data = prepare_bitrate_chart_data(performance_metrics)
      buffer_events_data = prepare_buffer_events_chart_data(performance_metrics)
      latency_data = prepare_latency_chart_data(performance_metrics)
      resolution_distribution = prepare_resolution_distribution(performance_metrics)

      socket
      |> assign(:performance_metrics, performance_metrics)
      |> assign(:bitrate_data, bitrate_data)
      |> assign(:buffer_events_data, buffer_events_data)
      |> assign(:latency_data, latency_data)
      |> assign(:resolution_distribution, resolution_distribution)
      |> assign(:loading, false)
    else
      socket
    end
  end

  # Chart data preparation functions

  defp prepare_bitrate_chart_data(metrics) do
    # Extract bitrate data over time
    labels = Enum.map(metrics, fn m -> Helpers.format_datetime(m.recorded_at) end)
    bitrate_values = Enum.map(metrics, fn m -> m.average_bitrate end)

    %{
      labels: labels,
      datasets: [
        %{
          label: "Average Bitrate (Kbps)",
          data: Enum.map(bitrate_values, fn b -> if b, do: b / 1000, else: nil end),
          borderColor: "rgba(75, 192, 192, 1)",
          backgroundColor: "rgba(75, 192, 192, 0.2)",
          borderWidth: 2,
          fill: true
        }
      ]
    }
  end

  defp prepare_buffer_events_chart_data(metrics) do
    # Extract buffer event data over time
    labels = Enum.map(metrics, fn m -> Helpers.format_datetime(m.recorded_at) end)
    buffer_counts = Enum.map(metrics, fn m -> m.buffer_count end)

    %{
      labels: labels,
      datasets: [
        %{
          label: "Buffer Events",
          data: buffer_counts,
          borderColor: "rgba(255, 99, 132, 1)",
          backgroundColor: "rgba(255, 99, 132, 0.2)",
          borderWidth: 2,
          fill: true
        }
      ]
    }
  end

  defp prepare_latency_chart_data(metrics) do
    # Extract latency data over time
    labels = Enum.map(metrics, fn m -> Helpers.format_datetime(m.recorded_at) end)
    latency_values = Enum.map(metrics, fn m -> m.latency end)

    %{
      labels: labels,
      datasets: [
        %{
          label: "Latency (ms)",
          data: latency_values,
          borderColor: "rgba(54, 162, 235, 1)",
          backgroundColor: "rgba(54, 162, 235, 0.2)",
          borderWidth: 2,
          fill: true
        }
      ]
    }
  end

  defp prepare_resolution_distribution(metrics) do
    # Group metrics by resolution and count occurrences
    resolution_groups =
      metrics
      |> Enum.filter(fn m -> m.resolution end)
      |> Enum.group_by(fn m -> m.resolution end)

    # Extract labels and counts
    labels = Map.keys(resolution_groups)
    data = Enum.map(labels, fn l -> Enum.count(Map.get(resolution_groups, l)) end)

    # Generate colors
    colors = generate_colors(length(labels))

    %{
      labels: labels,
      datasets: [
        %{
          data: data,
          backgroundColor: colors,
          hoverOffset: 4
        }
      ]
    }
  end

  @doc """
  Determines the color to use for bitrate quality indicator.
  """
  def bitrate_quality_color(metrics) do
    avg_bitrate = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.average_bitrate || 0)
    end) / max(length(metrics), 1)

    cond do
      avg_bitrate >= 2_000_000 -> "green"
      avg_bitrate >= 800_000 -> "yellow"
      true -> "red"
    end
  end

  @doc """
  Provides a textual description of bitrate quality.
  """
  def bitrate_quality_text(metrics) do
    avg_bitrate = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.average_bitrate || 0)
    end) / max(length(metrics), 1)

    cond do
      avg_bitrate >= 2_000_000 -> "Excellent"
      avg_bitrate >= 800_000 -> "Good"
      true -> "Poor"
    end
  end

  @doc """
  Provides a detailed description of bitrate quality.
  """
  def bitrate_quality_description(metrics) do
    avg_bitrate = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.average_bitrate || 0)
    end) / max(length(metrics), 1)

    cond do
      avg_bitrate >= 2_000_000 -> "Your stream has high-quality video with excellent clarity."
      avg_bitrate >= 800_000 -> "Your stream has decent quality. Consider increasing for HD streams."
      true -> "Your stream quality may appear pixelated to viewers."
    end
  end

  @doc """
  Determines the color to use for buffer quality indicator.
  """
  def buffer_quality_color(metrics) do
    buffer_events = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.buffer_count || 0)
    end)

    # Calculate buffer ratio (events per metric)
    buffer_ratio = buffer_events / max(length(metrics), 1)

    cond do
      buffer_ratio <= 0.02 -> "green"
      buffer_ratio <= 0.05 -> "yellow"
      true -> "red"
    end
  end

  @doc """
  Provides a textual description of buffer quality.
  """
  def buffer_quality_text(metrics) do
    buffer_events = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.buffer_count || 0)
    end)

    # Calculate buffer ratio (events per metric)
    buffer_ratio = buffer_events / max(length(metrics), 1)

    cond do
      buffer_ratio <= 0.02 -> "Excellent"
      buffer_ratio <= 0.05 -> "Fair"
      true -> "Poor"
    end
  end

  @doc """
  Provides a detailed description of buffer quality.
  """
  def buffer_quality_description(metrics) do
    buffer_events = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.buffer_count || 0)
    end)

    # Calculate buffer ratio (events per metric)
    buffer_ratio = buffer_events / max(length(metrics), 1)

    cond do
      buffer_ratio <= 0.02 -> "Your viewers experience minimal buffering during playback."
      buffer_ratio <= 0.05 -> "Some viewers may experience occasional buffering."
      true -> "Many viewers are experiencing frequent buffering issues."
    end
  end

  @doc """
  Determines the color to use for latency quality indicator.
  """
  def latency_quality_color(metrics) do
    avg_latency = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.latency || 0)
    end) / max(length(metrics), 1)

    cond do
      avg_latency <= 2000 -> "green"
      avg_latency <= 5000 -> "yellow"
      true -> "red"
    end
  end

  @doc """
  Provides a textual description of latency quality.
  """
  def latency_quality_text(metrics) do
    avg_latency = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.latency || 0)
    end) / max(length(metrics), 1)

    cond do
      avg_latency <= 2000 -> "Excellent"
      avg_latency <= 5000 -> "Acceptable"
      true -> "High"
    end
  end

  @doc """
  Provides a detailed description of latency quality.
  """
  def latency_quality_description(metrics) do
    avg_latency = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.latency || 0)
    end) / max(length(metrics), 1)

    cond do
      avg_latency <= 2000 -> "Your stream has low latency, ideal for interactive streams."
      avg_latency <= 5000 -> "Moderate latency, acceptable for most content."
      true -> "High latency may impact viewer experience for interactive content."
    end
  end

  @doc """
  Generate performance recommendations based on metrics.
  """
  def performance_recommendations(metrics) do
    avg_bitrate = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.average_bitrate || 0)
    end) / max(length(metrics), 1)

    buffer_events = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.buffer_count || 0)
    end)
    buffer_ratio = buffer_events / max(length(metrics), 1)

    avg_latency = Enum.reduce(metrics, 0, fn m, acc ->
      acc + (m.latency || 0)
    end) / max(length(metrics), 1)

    recommendations = []

    recommendations = if avg_bitrate < 1_500_000 do
      recommendations ++ ["Consider increasing your bitrate to at least 1.5 Mbps for better video quality."]
    else
      recommendations
    end

    recommendations = if buffer_ratio > 0.03 do
      recommendations ++ ["Check your network connection stability to reduce buffering."]
    else
      recommendations
    end

    recommendations = if avg_latency > 3000 do
      recommendations ++ ["Enable low-latency mode in your streaming software for more interactive streams."]
    else
      recommendations
    end

    if recommendations == [] do
      ["Your stream performance is excellent! Keep up the good work."]
    else
      recommendations
    end
  end

  # Helper function to generate colors for charts
  defp generate_colors(count) do
    base_colors = [
      "rgba(75, 192, 192, 0.7)",
      "rgba(54, 162, 235, 0.7)",
      "rgba(255, 99, 132, 0.7)",
      "rgba(255, 206, 86, 0.7)",
      "rgba(153, 102, 255, 0.7)",
      "rgba(255, 159, 64, 0.7)"
    ]

    Stream.cycle(base_colors)
    |> Enum.take(count)
  end
end
