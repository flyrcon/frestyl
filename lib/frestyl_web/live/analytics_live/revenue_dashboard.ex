defmodule FrestylWeb.AnalyticsLive.RevenueDashboard do
  use FrestylWeb, :live_view
  alias Frestyl.Analytics
  alias Frestyl.Channels
  alias FrestylWeb.AnalyticsLive.Helpers

  # Import the specific functions you need
  import FrestylWeb.AnalyticsLive.Helpers, only: [
    format_currency: 1,
    format_date: 1   # Add this line to import format_date/1
  ]

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

      socket =
        socket
        |> assign(:current_user, user)
        |> assign(:channels, channels)
        |> assign(:selected_channel_id, if(default_channel, do: default_channel.id, else: nil))
        |> assign(:start_date, start_date)
        |> assign(:end_date, end_date)
        |> assign(:date_range, @default_date_range)
        |> assign(:interval, "day")
        |> assign(:revenue_metrics, [])
        |> assign(:revenue_chart_data, %{})
        |> assign(:revenue_breakdown_data, %{})
        |> assign(:loading, false)

      # Load revenue data if we have a default channel
      socket = if default_channel do
        load_revenue_data(socket)
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
      |> load_revenue_data()

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
      |> load_revenue_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-interval", %{"interval" => interval}, socket) do
    # interval could be "day", "week", "month"
    socket =
      socket
      |> assign(:interval, interval)
      |> load_revenue_data()

    {:noreply, socket}
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
    if socket.assigns.selected_channel_id do
      load_revenue_data(socket)
    else
      socket
    end
  end

  @doc """
  Renders a metric card with title, value, and optional icon and color.
  """
  def metric_card(assigns) do
    assigns = assign_new(assigns, :color, fn -> "blue" end)
    assigns = assign_new(assigns, :icon, fn -> "currency-dollar" end)

    ~H"""
    <div class="bg-white rounded-lg shadow p-4">
      <div class="flex items-center">
        <div class={"bg-#{@color}-100 p-3 rounded-full mr-4"}>
          <svg xmlns="http://www.w3.org/2000/svg" class={"h-6 w-6 text-#{@color}-600"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={get_icon_path(@icon)} />
          </svg>
        </div>
        <div>
          <div class="text-sm font-medium text-gray-500"><%= @title %></div>
          <div class="text-lg font-semibold text-gray-900"><%= @value %></div>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to get SVG path for different icons
  defp get_icon_path(icon) do
    case icon do
      "currency-dollar" -> "M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      "ticket" -> "M15 5v2m0 4v2m0 4v2M5 5a2 2 0 00-2 2v3a2 2 0 110 4v3a2 2 0 002 2h14a2 2 0 002-2v-3a2 2 0 110-4V7a2 2 0 00-2-2H5z"
      "users" -> "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
      "gift" -> "M12 8v13m0-13V6a2 2 0 112 2h-2zm0 0V5.5A2.5 2.5 0 109.5 8H12zm-7 4h14M5 12a2 2 0 110-4h14a2 2 0 110 4M5 12v7a2 2 0 002 2h10a2 2 0 002-2v-7"
      _ -> "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
    end
  end

  defp load_revenue_data(socket) do
    %{
      selected_channel_id: channel_id,
      start_date: start_date,
      end_date: end_date,
      interval: interval
    } = socket.assigns

    # Only proceed if we have a channel selected
    if channel_id do
      socket = assign(socket, :loading, true)

      # Load revenue metrics
      revenue_metrics = Analytics.aggregate_revenue_metrics(channel_id, start_date, end_date, interval)

      # Prepare chart data
      revenue_chart_data = prepare_revenue_chart_data(revenue_metrics)
      revenue_breakdown_data = prepare_revenue_breakdown_data(revenue_metrics)

      socket
      |> assign(:revenue_metrics, revenue_metrics)
      |> assign(:revenue_chart_data, revenue_chart_data)
      |> assign(:revenue_breakdown_data, revenue_breakdown_data)
      |> assign(:loading, false)
    else
      socket
    end
  end

  # Chart data preparation functions

  defp prepare_revenue_chart_data(metrics) do
    # Extract revenue data over time
    labels = Enum.map(metrics, fn m -> Helpers.format_date(m.date) end)
    total_revenue = Enum.map(metrics, fn m -> Decimal.to_float(m.total_revenue) end)

    %{
      labels: labels,
      datasets: [
        %{
          label: "Total Revenue",
          data: total_revenue,
          borderColor: "rgba(75, 192, 192, 1)",
          backgroundColor: "rgba(75, 192, 192, 0.2)",
          borderWidth: 2,
          fill: true
        }
      ]
    }
  end

  defp prepare_revenue_breakdown_data(metrics) do
    # Extract revenue by source
    labels = Enum.map(metrics, fn m -> Helpers.format_date(m.date) end)

    subscription_revenue = Enum.map(metrics, fn m ->
      if m.subscription_revenue, do: Decimal.to_float(m.subscription_revenue), else: 0.0
    end)

    donation_revenue = Enum.map(metrics, fn m ->
      if m.donation_revenue, do: Decimal.to_float(m.donation_revenue), else: 0.0
    end)

    ticket_revenue = Enum.map(metrics, fn m ->
      if m.ticket_revenue, do: Decimal.to_float(m.ticket_revenue), else: 0.0
    end)

    merchandise_revenue = Enum.map(metrics, fn m ->
      if m.merchandise_amount, do: Decimal.to_float(m.merchandise_amount), else: 0.0
    end)

    %{
      labels: labels,
      datasets: [
        %{
          label: "Subscription Revenue",
          data: subscription_revenue,
          backgroundColor: "rgba(54, 162, 235, 0.7)"
        },
        %{
          label: "Donation Revenue",
          data: donation_revenue,
          backgroundColor: "rgba(255, 99, 132, 0.7)"
        },
        %{
          label: "Ticket Revenue",
          data: ticket_revenue,
          backgroundColor: "rgba(255, 206, 86, 0.7)"
        },
        %{
          label: "Merchandise Revenue",
          data: merchandise_revenue,
          backgroundColor: "rgba(75, 192, 192, 0.7)"
        }
      ]
    }
  end

  # Helper functions for revenue calculations

  def total_revenue(metrics) do
    metrics
    |> Enum.map(fn m -> Decimal.to_float(m.total_revenue) end)
    |> Enum.sum()
  end

  def revenue_by_source(metrics) do
    subscription = metrics
                  |> Enum.map(fn m -> if m.subscription_revenue, do: Decimal.to_float(m.subscription_revenue), else: 0.0 end)
                  |> Enum.sum()

    donation = metrics
              |> Enum.map(fn m -> if m.donation_revenue, do: Decimal.to_float(m.donation_revenue), else: 0.0 end)
              |> Enum.sum()

    ticket = metrics
            |> Enum.map(fn m -> if m.ticket_revenue, do: Decimal.to_float(m.ticket_revenue), else: 0.0 end)
            |> Enum.sum()

    merchandise = metrics
                 |> Enum.map(fn m -> if m.merchandise_amount, do: Decimal.to_float(m.merchandise_amount), else: 0.0 end)
                 |> Enum.sum()

    %{
      subscription: subscription,
      donation: donation,
      ticket: ticket,
      merchandise: merchandise
    }
  end

  def revenue_growth(metrics) do
    # Group metrics by month
    monthly_revenue = Enum.group_by(metrics, fn m ->
      {m.date.year, m.date.month}
    end)

    # Sort by month
    sorted_months = Enum.sort(Map.keys(monthly_revenue))

    # Calculate total revenue for each month
    monthly_totals = Enum.map(sorted_months, fn month ->
      total = monthly_revenue[month]
              |> Enum.map(fn m -> Decimal.to_float(m.total_revenue) end)
              |> Enum.sum()
      {month, total}
    end)

    # Calculate month-over-month growth
    if length(monthly_totals) >= 2 do
      {_, prev_month_total} = Enum.at(monthly_totals, -2)
      {_, current_month_total} = Enum.at(monthly_totals, -1)

      if prev_month_total > 0 do
        (current_month_total - prev_month_total) / prev_month_total * 100
      else
        nil
      end
    else
      nil
    end
  end

  def top_revenue_source(metrics) do
    sources = revenue_by_source(metrics)

    sources
    |> Enum.max_by(fn {_source, amount} -> amount end)
  end

  def revenue_recommendations(metrics) do
    # Basic recommendations
    recommendations = ["Regularly analyze your revenue trends to identify growth opportunities"]

    # Revenue source recommendations
    sources = revenue_by_source(metrics)

    {top_source, _} = sources
                      |> Enum.max_by(fn {_source, amount} -> amount end, fn -> {:none, 0} end)

    recommendations =
      case top_source do
        :subscription ->
          ["Focus on subscriber retention to maintain your primary revenue stream" | recommendations]
        :donation ->
          ["Consider promoting donation tiers or benefits to increase donation revenue" | recommendations]
        :ticket ->
          ["Explore dynamic ticket pricing for future events to maximize ticket revenue" | recommendations]
        :merchandise ->
          ["Expand your merchandise offerings based on current popularity" | recommendations]
        _ ->
          recommendations
      end

    # Growth recommendations
    growth = revenue_growth(metrics)

    recommendations =
      if growth do
        if growth < 0 do
          ["Implement promotional campaigns to reverse the negative revenue trend observed in recent months" | recommendations]
        else
          ["Continue your current growth strategy which has yielded positive results" | recommendations]
        end
      else
        recommendations
      end

    # Return all recommendations
    recommendations
  end
end
