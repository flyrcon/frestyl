defmodule FrestylWeb.ServiceLive.Index do
  use FrestylWeb, :live_view
  alias Frestyl.Services
  alias Frestyl.Features.FeatureGate
  alias Frestyl.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    account = Accounts.get_user_primary_account(user.id)

    if FeatureGate.can_access_feature?(account, :service_booking) do
      services = Services.list_user_services(user.id)
      limits = get_service_limits(account)

      socket =
        socket
        |> assign(:page_title, "My Services")
        |> assign(:services, services)
        |> assign(:account, account)
        |> assign(:limits, limits)
        |> assign(:can_create, can_create_service?(account, services))
        |> assign(:show_create_modal, false)

      {:ok, socket}
    else
      socket =
        socket
        |> put_flash(:error, "Service booking requires Creator tier or higher")
        |> push_navigate(to: ~p"/portfolio")

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("show_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  @impl true
  def handle_event("hide_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  @impl true
  def handle_event("create_service", params, socket) do
    case Services.create_service(socket.assigns.current_user, params) do
      {:ok, service} ->
        services = Services.list_user_services(socket.assigns.current_user.id)

        socket =
          socket
          |> assign(:services, services)
          |> assign(:show_create_modal, false)
          |> put_flash(:info, "Service created successfully!")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to create service")
          |> assign(:changeset, changeset)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_service", %{"id" => id}, socket) do
    service = Services.get_service!(id)

    case Services.update_service(service, %{is_active: !service.is_active}) do
      {:ok, _service} ->
        services = Services.list_user_services(socket.assigns.current_user.id)

        socket =
          socket
          |> assign(:services, services)
          |> put_flash(:info, "Service updated successfully!")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update service")}
    end
  end

  defp can_create_service?(account, services) do
    current_count = length(services)

    case account.subscription_tier do
      :personal -> false
      :creator -> current_count < 10
      :professional -> true
      :enterprise -> true
    end
  end

  defp get_service_limits(account) do
    case account.subscription_tier do
      :personal -> %{max_services: 0, platform_fee: "N/A"}
      :creator -> %{max_services: 10, platform_fee: "5%"}
      :professional -> %{max_services: "Unlimited", platform_fee: "3%"}
      :enterprise -> %{max_services: "Unlimited", platform_fee: "1.5%"}
    end
  end
end
