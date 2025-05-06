defmodule FrestylWeb.AnalyticsLive.Dashboard do
  use FrestylWeb, :live_view
  alias Frestyl.Analytics
  alias Frestyl.Channels
  # Change from alias to import to bring all the helper functions into scope
  import FrestylWeb.AnalyticsLive.Helpers

  @default_date_range 30 # days

  @impl true
  def mount(_params, session, socket) do
    with {:ok, user_id} <- Map.fetch(session, "user_id"),
         user when not is_nil(user) <- Frestyl.Accounts.get_user(user_id) do
      # Get channels owned by the user
      channels = Channels.list_channels_by_owner(user.id)

      # Default to first channel if available
      default_channel = List.first(channels)

      # Calculate date range
      end_date = Date.utc_today()
      start_date = Date.add(end_date, -@default_date_range)

      # Initialize with empty data that will be loaded when channel is selected
      socket =
        socket
        |> assign(:current_user, user)
        |> assign(:channels, channels)
        |> assign(:selected_channel_id, if(default_channel, do: default_channel.id, else: nil))
        |> assign(:start_date, start_date)
        |> assign(:end_date, end_date)
        |> assign(:date_range, @default_date_range)
        |> assign(:interval, "day")
        |> assign(:channel_metrics, [])
        |> assign(:revenue_metrics, [])
        |> assign(:audience_insights, [])
        |> assign(:loading, false)

      # If Helpers.assign_analytics_config exists, call it
      # Otherwise, remove or comment this line
      # socket = assign_analytics_config(socket, user)

      # If we have a default channel, load its data
      socket = if default_channel do
        load_analytics_data(socket)
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
    # Handle channel_id, date_range, or interval from URL if provided
    socket =
      socket
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-channel", %{"channel_id" => channel_id}, socket) do
    socket =
      socket
      |> assign(:selected_channel_id, channel_id)
      |> load_analytics_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-date-range", %{"date_range" => date_range}, socket) do
    # Parse the date range (could be "7", "30", "90" days)
    {days, _} = Integer.parse(date_range)

    end_date = Date.utc_today()
    start_date = Date.add(end_date, -days)

    socket =
      socket
      |> assign(:start_date, start_date)
      |> assign(:end_date, end_date)
      |> assign(:date_range, days)
      |> load_analytics_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-interval", %{"interval" => interval}, socket) do
    # interval could be "day", "week", "month"
    socket =
      socket
      |> assign(:interval, interval)
      |> load_analytics_data()

    {:noreply, socket}
  end

  def metric_card(assigns) do
    ~H"""
    <div class="metric-card">
      <div class="value"><%= @value %></div>
      <div class="change"><%= @change %></div>
      <%# Make sure you removed any commented out HTML tags from here %>
    </div>
    """
  end

  defp apply_action(socket, :index, params) do
    # Handle optional params
    socket =
      with channel_id when not is_nil(channel_id) <- params["channel_id"],
           channel when not is_nil(channel) <- Channels.get_channel(channel_id) do
        assign(socket, :selected_channel_id, channel_id)
      else
        _ -> socket
      end

    # Handle date range if provided
    socket =
      with date_range when not is_nil(date_range) <- params["date_range"],
           {days, _} <- Integer.parse(date_range) do
        end_date = Date.utc_today()
        start_date = Date.add(end_date, -days)

        socket
        |> assign(:start_date, start_date)
        |> assign(:end_date, end_date)
        |> assign(:date_range, days)
      else
        _ -> socket
      end

    # Handle interval if provided
    socket =
      with interval when not is_nil(interval) <- params["interval"],
           true <- interval in ["day", "week", "month"] do
        assign(socket, :interval, interval)
      else
        _ -> socket
      end

    # Load data with applied filters
    load_analytics_data(socket)
  end

  defp load_analytics_data(socket) do
    %{
      selected_channel_id: channel_id,
      start_date: start_date,
      end_date: end_date,
      interval: interval
    } = socket.assigns

    # Only proceed if we have a channel selected
    if channel_id do
      socket = assign(socket, :loading, true)

      # Load channel metrics
      channel_metrics = Analytics.aggregate_channel_metrics(channel_id, start_date, end_date, interval)

      # Load revenue metrics
      revenue_metrics = Analytics.aggregate_revenue_metrics(channel_id, start_date, end_date, interval)

      # Load audience insights from events within the date range
      # This is a more complex query - we'd need to get events in the date range first
      # and then fetch audience insights for those events
      # For simplicity, this is a placeholder
      audience_insights = [] # Would need to implement actual data fetching

      socket
      |> assign(:channel_metrics, channel_metrics)
      |> assign(:revenue_metrics, revenue_metrics)
      |> assign(:audience_insights, audience_insights)
      |> assign(:loading, false)
    else
      socket
    end
  end

  # Add your main render function here if it exists, and update calls within its template
  # def render(assigns) do
  #   ~H"""
  #   ...
  #   <%# Example: Call helper functions here with the prefix %>
  #   Total Views: <%= Helpers.total_views(@channel_metrics) %>
  #   ...
  #   """
  # end

end
