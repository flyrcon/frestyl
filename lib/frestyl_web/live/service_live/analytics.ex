defmodule FrestylWeb.ServiceLive.Analytics do
  use FrestylWeb, :live_view
  alias Frestyl.Services
  alias Frestyl.Billing.ServiceRevenueTracker

  @impl true
  def mount(%{"id" => service_id}, _session, socket) do
    user = socket.assigns.current_user

    case Services.get_service!(service_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "Service not found")
          |> push_navigate(to: ~p"/services")

        {:ok, socket}

      service ->
        if service.user_id == user.id do
          analytics = ServiceRevenueTracker.get_service_analytics(service_id, user.id)
          monthly_data = get_monthly_analytics(service_id)

          socket =
            socket
            |> assign(:page_title, "Analytics - #{service.title}")
            |> assign(:service, service)
            |> assign(:analytics, analytics)
            |> assign(:monthly_data, monthly_data)
            |> assign(:selected_period, :last_30_days)

          {:ok, socket}
        else
          socket =
            socket
            |> put_flash(:error, "Unauthorized")
            |> push_navigate(to: ~p"/services")

          {:ok, socket}
        end
    end
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    service_id = socket.assigns.service.id
    monthly_data = get_monthly_analytics(service_id, String.to_atom(period))

    socket =
      socket
      |> assign(:selected_period, String.to_atom(period))
      |> assign(:monthly_data, monthly_data)

    {:noreply, socket}
  end

  defp get_monthly_analytics(service_id, period \\ :last_30_days) do
    # Calculate analytics based on period
    case period do
      :last_30_days -> calculate_period_analytics(service_id, 30)
      :last_90_days -> calculate_period_analytics(service_id, 90)
      :this_year -> calculate_year_analytics(service_id)
    end
  end

  defp calculate_period_analytics(service_id, days) do
    # Implementation for period-based analytics
    %{
      total_bookings: 0,
      total_revenue: 0,
      conversion_rate: 0,
      daily_breakdown: []
    }
  end

  defp calculate_year_analytics(service_id) do
    # Implementation for yearly analytics
    %{
      total_bookings: 0,
      total_revenue: 0,
      conversion_rate: 0,
      monthly_breakdown: []
    }
  end
end
