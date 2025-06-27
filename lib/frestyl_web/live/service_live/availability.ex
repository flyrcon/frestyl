defmodule FrestylWeb.ServiceLive.Availability do
  use FrestylWeb, :live_view
  alias Frestyl.Services
  alias Frestyl.Services.ServiceAvailability

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
          availabilities = Services.list_service_availabilities(service_id)
          changeset = ServiceAvailability.changeset(%ServiceAvailability{}, %{})

          socket =
            socket
            |> assign(:page_title, "Availability - #{service.title}")
            |> assign(:service, service)
            |> assign(:availabilities, availabilities)
            |> assign(:changeset, changeset)
            |> assign(:show_add_modal, false)
            |> assign(:editing_availability, nil)

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
  def handle_event("show_add_modal", _params, socket) do
    changeset = ServiceAvailability.changeset(%ServiceAvailability{}, %{})

    socket =
      socket
      |> assign(:show_add_modal, true)
      |> assign(:changeset, changeset)
      |> assign(:editing_availability, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_add_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_modal, false)}
  end

  @impl true
  def handle_event("create_availability", %{"service_availability" => params}, socket) do
    service = socket.assigns.service

    case Services.create_availability(service, params) do
      {:ok, _availability} ->
        availabilities = Services.list_service_availabilities(service.id)

        socket =
          socket
          |> assign(:availabilities, availabilities)
          |> assign(:show_add_modal, false)
          |> put_flash(:info, "Availability added successfully!")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> assign(:changeset, changeset)
          |> put_flash(:error, "Failed to add availability")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_availability", %{"id" => id}, socket) do
    availability = Services.get_availability!(id)

    case Services.update_availability(availability, %{is_active: !availability.is_active}) do
      {:ok, _availability} ->
        availabilities = Services.list_service_availabilities(socket.assigns.service.id)

        socket =
          socket
          |> assign(:availabilities, availabilities)
          |> put_flash(:info, "Availability updated!")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update availability")}
    end
  end

  @impl true
  def handle_event("delete_availability", %{"id" => id}, socket) do
    availability = Services.get_availability!(id)

    case Services.delete_availability(availability) do
      {:ok, _} ->
        availabilities = Services.list_service_availabilities(socket.assigns.service.id)

        socket =
          socket
          |> assign(:availabilities, availabilities)
          |> put_flash(:info, "Availability deleted!")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete availability")}
    end
  end
end
