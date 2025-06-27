defmodule FrestylWeb.ServiceLive.Book do
  use FrestylWeb, :live_view
  alias Frestyl.Services
  alias Frestyl.Services.ServiceBooking

  @impl true
  def mount(%{"id" => service_id}, _session, socket) do
    case Services.get_service_with_availability(service_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "Service not found")
          |> push_navigate(to: ~p"/")

        {:ok, socket}

      service ->
        changeset = ServiceBooking.changeset(%ServiceBooking{}, %{})

        socket =
          socket
          |> assign(:page_title, "Book #{service.title}")
          |> assign(:service, service)
          |> assign(:changeset, changeset)
          |> assign(:step, :details)  # :details, :datetime, :payment
          |> assign(:selected_date, nil)
          |> assign(:selected_time, nil)
          |> assign(:available_slots, [])
          |> assign(:total_amount, service.price_cents)
          |> assign(:platform_fee, calculate_display_fee(service))

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("validate_details", %{"service_booking" => params}, socket) do
    changeset =
      %ServiceBooking{}
      |> ServiceBooking.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("proceed_to_datetime", %{"service_booking" => params}, socket) do
    changeset = ServiceBooking.changeset(%ServiceBooking{}, params)

    if changeset.valid? do
      socket =
        socket
        |> assign(:step, :datetime)
        |> assign(:client_details, params)

      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:changeset, Map.put(changeset, :action, :validate))
        |> put_flash(:error, "Please fix the errors below")

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_date", %{"date" => date_str}, socket) do
    date = Date.from_iso8601!(date_str)
    service_id = socket.assigns.service.id

    available_slots = Services.get_available_slots(service_id, date)

    socket =
      socket
      |> assign(:selected_date, date)
      |> assign(:selected_time, nil)
      |> assign(:available_slots, available_slots)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_time", %{"time" => time_str}, socket) do
    {:noreply, assign(socket, :selected_time, time_str)}
  end

  @impl true
  def handle_event("proceed_to_payment", _params, socket) do
    if socket.assigns.selected_date && socket.assigns.selected_time do
      {:noreply, assign(socket, :step, :payment)}
    else
      {:noreply, put_flash(socket, :error, "Please select a date and time")}
    end
  end

  @impl true
  def handle_event("confirm_booking", _params, socket) do
    %{
      service: service,
      client_details: client_details,
      selected_date: date,
      selected_time: time
    } = socket.assigns

    # Combine date and time into datetime
    {:ok, scheduled_at} = create_datetime(date, time)

    booking_attrs = Map.merge(client_details, %{
      "scheduled_at" => scheduled_at
    })

    case Services.create_booking(service, booking_attrs, service.user) do
      {:ok, booking} ->
        # Process payment here
        case Services.process_booking_payment(booking, %{}) do
          {:ok, booking} ->
            socket =
              socket
              |> put_flash(:info, "Booking created! Reference: #{booking.booking_reference}")
              |> push_navigate(to: ~p"/booking/#{booking.booking_reference}")

            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Payment processing failed")}
        end

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Failed to create booking")}
    end
  end

  defp calculate_display_fee(service) do
    # This would calculate based on the provider's subscription tier
    platform_fee_percentage = Decimal.new("5.0") # Default to Creator tier
    fee_amount =
      service.price_cents
      |> Decimal.new()
      |> Decimal.mult(platform_fee_percentage)
      |> Decimal.div(100)
      |> Decimal.round(0)
      |> Decimal.to_integer()

    %{
      percentage: platform_fee_percentage,
      amount_cents: fee_amount
    }
  end

  defp create_datetime(date, time_str) do
    {:ok, time} = Time.from_iso8601("#{time_str}:00")
    {:ok, DateTime.new(date, time, "UTC")}
  end
end
