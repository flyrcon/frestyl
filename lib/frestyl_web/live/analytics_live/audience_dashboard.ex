defmodule FrestylWeb.AnalyticsLive.AudienceDashboard do
  use FrestylWeb, :live_view
  alias Frestyl.Analytics
  alias Frestyl.Channels
  alias Frestyl.Events
  import FrestylWeb.AnalyticsLive.Helpers, only: [format_date: 1]

  @impl true
  def mount(_params, session, socket) do
    with {:ok, user_id} <- Map.fetch(session, "user_id"),
         user when not is_nil(user) <- Frestyl.Accounts.get_user(user_id) do
      # Get channels owned by the user
      channels = Channels.list_channels_by_owner(user.id)

      # Default to first channel if available
      default_channel = List.first(channels)

      # Get events for the default channel
      events = if default_channel do
        Events.list_recent_events(default_channel.id, 10)
      else
        []
      end

      # Default to first event if available
      default_event = List.first(events)

      socket =
        socket
        |> assign(:current_user, user)
        |> assign(:channels, channels)
        |> assign(:selected_channel_id, if(default_channel, do: default_channel.id, else: nil))
        |> assign(:events, events)
        |> assign(:selected_event_id, if(default_event, do: default_event.id, else: nil))
        |> assign(:audience_insights, [])
        |> assign(:demographics_data, %{})
        |> assign(:geography_data, %{})
        |> assign(:device_data, %{})
        |> assign(:engagement_data, %{})
        |> assign(:loading, false)

      # Load audience data if we have a default event
      socket = if default_event do
        load_audience_data(socket)
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

  @impl true
  def handle_params(params, _url, socket) do
    # Handle channel_id and event_id from URL if provided
    socket =
      socket
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-channel", %{"channel_id" => channel_id}, socket) do
    # Get events for the selected channel
    events = Events.list_recent_events(channel_id, 10)

    # Default to first event if available
    default_event = List.first(events)

    socket =
      socket
      |> assign(:selected_channel_id, channel_id)
      |> assign(:events, events)
      |> assign(:selected_event_id, if(default_event, do: default_event.id, else: nil))

    # Load audience data if we have a default event
    socket = if default_event do
      load_audience_data(socket)
    else
      assign(socket, :audience_insights, [])
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-event", %{"event_id" => event_id}, socket) do
    socket =
      socket
      |> assign(:selected_event_id, event_id)
      |> load_audience_data()

    {:noreply, socket}
  end

  defp apply_action(socket, :index, params) do
    # Handle optional params
    socket =
      with channel_id when not is_nil(channel_id) <- params["channel_id"],
           channel when not is_nil(channel) <- Channels.get_channel(channel_id) do
        # Get events for the channel
        events = Events.list_recent_events(channel_id, 10)

        socket
        |> assign(:selected_channel_id, channel_id)
        |> assign(:events, events)
      else
        _ -> socket
      end

    # Handle event_id if provided
    socket =
      with event_id when not is_nil(event_id) <- params["event_id"],
           event when not is_nil(event) <- Events.get_event(event_id) do
        assign(socket, :selected_event_id, event_id)
      else
        _ -> socket
      end

    # Load data with applied filters
    if socket.assigns.selected_event_id do
      load_audience_data(socket)
    else
      socket
    end
  end

  defp load_audience_data(socket) do
    %{selected_event_id: event_id} = socket.assigns

    # Only proceed if we have an event selected
    if event_id do
      socket = assign(socket, :loading, true)

      # Load audience insights
      audience_insights = Analytics.get_audience_insights(event_id)
      demographics = Analytics.get_audience_demographics(event_id)
      geography = Analytics.get_audience_geography(event_id)

      # Prepare chart data
      demographics_data = prepare_demographics_chart_data(demographics)
      geography_data = prepare_geography_chart_data(geography)
      device_data = prepare_device_chart_data(audience_insights)
      engagement_data = prepare_engagement_chart_data(audience_insights)

      socket
      |> assign(:audience_insights, audience_insights)
      |> assign(:demographics, demographics)
      |> assign(:geography, geography)
      |> assign(:demographics_data, demographics_data)
      |> assign(:geography_data, geography_data)
      |> assign(:device_data, device_data)
      |> assign(:engagement_data, engagement_data)
      |> assign(:loading, false)
    else
      socket
    end
  end

  # Chart data preparation functions

  defp prepare_demographics_chart_data(demographics) do
    # Extract demographics data
    labels = Enum.map(demographics, fn d -> d.demographic_group end)
    data = Enum.map(demographics, fn d -> d.count end)

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

  defp prepare_geography_chart_data(geography) do
    # Extract geography data
    labels = Enum.map(geography, fn g -> g.country end)
    data = Enum.map(geography, fn g -> g.count end)

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

  defp prepare_device_chart_data(audience_insights) do
    # Group by device type
    device_groups =
      audience_insights
      |> Enum.filter(fn i -> i.device_type end)
      |> Enum.group_by(fn i -> i.device_type end)

    # Extract labels and counts
    labels = Map.keys(device_groups)
    data = Enum.map(labels, fn l -> Enum.count(Map.get(device_groups, l)) end)

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

  defp prepare_engagement_chart_data(audience_insights) do
    # Extract engagement metrics by demographic group
    demographic_groups =
      audience_insights
      |> Enum.filter(fn i -> i.demographic_group && i.engagement_rate end)
      |> Enum.group_by(fn i -> i.demographic_group end)

    # Calculate average engagement rate for each demographic group
    labels = Map.keys(demographic_groups)

    data = Enum.map(labels, fn label ->
      group = Map.get(demographic_groups, label, [])

      # Calculate average engagement rate
      engagement_rates = Enum.map(group, fn i -> i.engagement_rate end)
      Enum.sum(engagement_rates) / length(engagement_rates)
    end)

    # Generate a consistent color for engagement
    color = "rgba(54, 162, 235, 0.8)"

    %{
      labels: labels,
      datasets: [
        %{
          label: "Average Engagement Rate (%)",
          data: data,
          backgroundColor: color,
          borderColor: "rgba(54, 162, 235, 1)",
          borderWidth: 1
        }
      ]
    }
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

  # Helper functions for insights and recommendations

  def audience_size(audience_insights) do
    length(audience_insights)
  end

  def top_demographic_group(demographics) do
    demographics
    |> Enum.sort_by(fn d -> d.count end, :desc)
    |> List.first()
  end

  def top_country(geography) do
    geography
    |> Enum.sort_by(fn g -> g.count end, :desc)
    |> List.first()
  end

  def most_engaged_demographic(demographics) do
    demographics
    |> Enum.sort_by(fn d -> d.engagement_rate end, :desc)
    |> List.first()
  end

  def audience_recommendations(audience_insights, demographics, geography) do
    # Basic recommendations
    recommendations = ["Ensure your content appeals to your core demographics"]

    # Add demographic-specific recommendations
    recommendations =
      if not Enum.empty?(demographics) do
        top_demo = top_demographic_group(demographics)
        most_engaged = most_engaged_demographic(demographics)

        demo_recommendations = []

        # Recommend focusing on top demographic
        if top_demo do
          demo_recommendations = [
            "Focus your content strategy on #{top_demo.demographic_group} as they represent your largest audience segment"
            | demo_recommendations
          ]
        end

        # Recommend engaging less-engaged demographics
        if most_engaged && top_demo && most_engaged.demographic_group != top_demo.demographic_group do
          demo_recommendations = [
            "Consider creating content to better engage the #{top_demo.demographic_group} demographic, as they have lower engagement rates than #{most_engaged.demographic_group}"
            | demo_recommendations
          ]
        end

        recommendations ++ demo_recommendations
      else
        recommendations
      end

    # Add geographic recommendations
    recommendations =
      if not Enum.empty?(geography) do
        top_geo = top_country(geography)

        geo_recommendations = []

        if top_geo do
          geo_recommendations = [
            "Consider scheduling events at times convenient for viewers in #{top_geo.country}, your largest audience location"
            | geo_recommendations
          ]
        end

        recommendations ++ geo_recommendations
      else
        recommendations
      end

    # Add device-specific recommendations
    device_types =
      audience_insights
      |> Enum.filter(fn i -> i.device_type end)
      |> Enum.group_by(fn i -> i.device_type end)

    recommendations =
      if not Enum.empty?(device_types) do
        counts = Enum.map(device_types, fn {type, insights} -> {type, length(insights)} end)
        {top_device, _} = Enum.max_by(counts, fn {_type, count} -> count end)

        device_recommendations = [
          "Optimize your streaming experience for #{top_device} users, as they make up a significant portion of your audience"
        ]

        recommendations ++ device_recommendations
      else
        recommendations
      end

    # Return all recommendations
    recommendations
  end
end
