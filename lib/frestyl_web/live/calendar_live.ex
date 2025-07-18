# lib/frestyl_web/live/calendar_live.ex
defmodule FrestylWeb.CalendarLive do
  use FrestylWeb, :live_view

  alias Frestyl.Calendar
  alias Frestyl.Features.TierManager
  alias Frestyl.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    account = get_user_account(user)

    # Get user's calendar preferences
    calendar_views = Calendar.get_user_views(user.id)
    default_view = Enum.find(calendar_views, &(&1.default_view)) ||
                   %{view_type: "month", filters: %{}}

    # Get events for current month
    {start_date, end_date} = get_month_range(Date.utc_today())
    events = Calendar.get_user_visible_events(user, account,
      start_date: start_date,
      end_date: end_date
    )

    # Get calendar integrations
    integrations = Calendar.get_user_integrations(user.id)

    # Check tier permissions
    tier = TierManager.get_user_tier(user)
    calendar_permissions = get_calendar_permissions(tier)

    {:ok,
     socket
     |> assign(:page_title, "Calendar")
     |> assign(:user, user)
     |> assign(:account, account)
     |> assign(:current_date, Date.utc_today())
     |> assign(:current_view, default_view.view_type)
     |> assign(:events, events)
     |> assign(:calendar_views, calendar_views)
     |> assign(:integrations, integrations)
     |> assign(:calendar_permissions, calendar_permissions)
     |> assign(:selected_event, nil)
     |> assign(:show_event_modal, false)
     |> assign(:show_create_modal, false)
     |> assign(:show_integration_modal, false)
     |> assign(:filter_options, get_filter_options(tier))
     |> assign(:active_filters, default_view.filters)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    date = parse_date_param(params["date"]) || socket.assigns.current_date
    view = params["view"] || socket.assigns.current_view

    socket =
      socket
      |> assign(:current_date, date)
      |> assign(:current_view, view)
      |> load_events_for_date_range(date, view)

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_view", %{"view" => view}, socket) do
    {:noreply,
     socket
     |> assign(:current_view, view)
     |> push_patch(to: ~p"/calendar?view=#{view}&date=#{socket.assigns.current_date}")}
  end

  @impl true
  def handle_event("navigate_date", %{"direction" => direction}, socket) do
    current_date = socket.assigns.current_date
    current_view = socket.assigns.current_view

    new_date = case {direction, current_view} do
      {"prev", "month"} -> Date.add(current_date, -30)
      {"next", "month"} -> Date.add(current_date, 30)
      {"prev", "week"} -> Date.add(current_date, -7)
      {"next", "week"} -> Date.add(current_date, 7)
      {"prev", "day"} -> Date.add(current_date, -1)
      {"next", "day"} -> Date.add(current_date, 1)
      _ -> current_date
    end

    {:noreply,
     socket
     |> assign(:current_date, new_date)
     |> push_patch(to: ~p"/calendar?view=#{current_view}&date=#{new_date}")}
  end

  @impl true
  def handle_event("create_event", params, socket) do
    if socket.assigns.calendar_permissions.can_create do
      {:noreply, assign(socket, :show_create_modal, true)}
    else
      {:noreply, put_flash(socket, :error, "Upgrade to Creator to create calendar events")}
    end
  end

  @impl true
  def handle_event("edit_event", %{"id" => event_id}, socket) do
    event = Enum.find(socket.assigns.events, &(&1.id == event_id))

    {:noreply,
     socket
     |> assign(:selected_event, event)
     |> assign(:show_event_modal, true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_event_modal, false)
     |> assign(:show_create_modal, false)
     |> assign(:show_integration_modal, false)
     |> assign(:selected_event, nil)}
  end

  @impl true
  def handle_event("toggle_filter", %{"filter" => filter_type, "value" => value}, socket) do
    current_filters = socket.assigns.active_filters
    event_types = Map.get(current_filters, "event_types", [])

    new_event_types = case filter_type do
      "event_type" ->
        if value in event_types do
          List.delete(event_types, value)
        else
          [value | event_types]
        end
      _ -> event_types
    end

    new_filters = Map.put(current_filters, "event_types", new_event_types)

    {:noreply,
     socket
     |> assign(:active_filters, new_filters)
     |> refresh_events()}
  end

  @impl true
  def handle_event("setup_integration", %{"provider" => provider}, socket) do
    if socket.assigns.calendar_permissions.can_integrate do
      # Start OAuth flow for calendar integration
      oauth_url = get_oauth_url(provider, socket.assigns.user)
      {:noreply, redirect(socket, external: oauth_url)}
    else
      {:noreply, put_flash(socket, :error, "Upgrade to Creator to integrate external calendars")}
    end
  end

  @impl true
  def handle_event("refresh_calendar", _params, socket) do
    {:noreply,
     socket
     |> assign(:loading, true)
     |> refresh_events()
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("save_event", %{"event" => event_params}, socket) do
    user = socket.assigns.user
    account = socket.assigns.account

    case Calendar.create_event(event_params, user, account) do
      {:ok, _event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event created successfully")
         |> assign(:show_create_modal, false)
         |> refresh_events()}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create event")
         |> assign(:changeset, changeset)}
    end
  end

  @impl true
  def handle_event("update_event", %{"event" => event_params}, socket) do
    event = socket.assigns.selected_event
    user = socket.assigns.user

    case Calendar.update_event(event, event_params, user) do
      {:ok, _updated_event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event updated successfully")
         |> assign(:show_event_modal, false)
         |> assign(:selected_event, nil)
         |> refresh_events()}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to edit this event")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update event")
         |> assign(:changeset, changeset)}
    end
  end

  @impl true
  def handle_event("delete_event", %{"id" => event_id}, socket) do
    event = Enum.find(socket.assigns.events, &(&1.id == event_id))
    user = socket.assigns.user

    case Calendar.delete_event(event, user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event deleted successfully")
         |> assign(:show_event_modal, false)
         |> assign(:selected_event, nil)
         |> refresh_events()}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to delete this event")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete event")}
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp get_user_account(user) do
    case user.account || List.first(user.accounts || []) do
      nil ->
        # Create default account if none exists
        {:ok, account} = Accounts.create_account(%{name: "Personal", user_id: user.id})
        account
      account -> account
    end
  end

  defp get_calendar_permissions(tier) do
    case tier do
      "personal" ->
        %{
          can_create: false,
          can_integrate: false,
          can_see_analytics: false,
          event_visibility: ["channel"],
          max_attendees: 0
        }

      "creator" ->
        %{
          can_create: true,
          can_integrate: true,
          can_see_analytics: true,
          event_visibility: ["channel", "account", "public"],
          max_attendees: 50
        }

      tier when tier in ["professional", "enterprise"] ->
        %{
          can_create: true,
          can_integrate: true,
          can_see_analytics: true,
          event_visibility: ["channel", "account", "public", "private"],
          max_attendees: :unlimited
        }
    end
  end

  defp get_filter_options(tier) do
    base_options = [
      event_types: [
        %{value: "channel_event", label: "Channel Events", icon: "👥"},
        %{value: "broadcast", label: "Broadcasts", icon: "📺"}
      ]
    ]

    case tier do
      "personal" -> base_options
      _ ->
        base_options ++ [
          event_types: base_options[:event_types] ++ [
            %{value: "service_booking", label: "Service Bookings", icon: "📅"},
            %{value: "collaboration", label: "Collaborations", icon: "🤝"},
            %{value: "personal", label: "Personal Events", icon: "📝"}
          ]
        ]
    end
  end

  defp get_month_range(date) do
    start_date = Date.beginning_of_month(date)
    end_date = Date.end_of_month(date)
    {start_date, end_date}
  end

  defp get_week_range(date) do
    start_date = Date.add(date, -Date.day_of_week(date) + 1)
    end_date = Date.add(start_date, 6)
    {start_date, end_date}
  end

  defp load_events_for_date_range(socket, date, view) do
    {start_date, end_date} = case view do
      "month" -> get_month_range(date)
      "week" -> get_week_range(date)
      "day" -> {date, date}
      "list" -> get_month_range(date)
      _ -> get_month_range(date)
    end

    events = Calendar.get_user_visible_events(
      socket.assigns.user,
      socket.assigns.account,
      start_date: start_date,
      end_date: end_date,
      event_types: get_filtered_event_types(socket.assigns.active_filters)
    )

    assign(socket, :events, events)
  end

  defp get_filtered_event_types(filters) do
    case Map.get(filters, "event_types", []) do
      [] -> :all
      types -> types
    end
  end

  defp refresh_events(socket) do
    load_events_for_date_range(socket, socket.assigns.current_date, socket.assigns.current_view)
  end

  defp parse_date_param(nil), do: nil
  defp parse_date_param(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp get_oauth_url(provider, user) do
    # Implementation would depend on your OAuth setup
    case provider do
      "google" -> "/auth/google/calendar?user_id=#{user.id}"
      "outlook" -> "/auth/microsoft/calendar?user_id=#{user.id}"
      _ -> "/calendar"
    end
  end
end
