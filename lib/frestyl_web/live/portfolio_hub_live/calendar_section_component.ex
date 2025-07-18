defmodule FrestylWeb.PortfolioHubLive.CalendarSectionComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Calendar
  alias Frestyl.Features.TierManager

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_calendar_view_state()}
  end

  @impl true
  def handle_event("change_calendar_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :calendar_view, view)}
  end

  @impl true
  def handle_event("navigate_calendar_date", %{"direction" => direction}, socket) do
    current_date = socket.assigns.current_calendar_date || Date.utc_today()

    new_date = case direction do
      "prev" -> Date.add(current_date, -7)
      "next" -> Date.add(current_date, 7)
      "today" -> Date.utc_today()
      _ -> current_date
    end

    {:noreply,
     socket
     |> assign(:current_calendar_date, new_date)
     |> refresh_calendar_events()}
  end

  @impl true
  def handle_event("create_quick_event", params, socket) do
    if socket.assigns.calendar_data.permissions.can_create do
      user = socket.assigns.user
      account = socket.assigns.account

      event_attrs = %{
        title: params["title"],
        event_type: params["type"] || "personal",
        starts_at: parse_datetime(params["start_time"]),
        ends_at: parse_datetime(params["end_time"]),
        visibility: params["visibility"] || "private"
      }

      case Calendar.create_event(event_attrs, user, account) do
        {:ok, _event} ->
          send(self(), {:calendar_event_created, "Event created successfully"})
          {:noreply, refresh_calendar_events(socket)}

        {:error, _changeset} ->
          send(self(), {:calendar_error, "Failed to create event"})
          {:noreply, socket}
      end
    else
      send(self(), {:calendar_error, "Upgrade to Creator to create events"})
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("connect_calendar", %{"provider" => provider}, socket) do
    if socket.assigns.calendar_data.permissions.can_integrate do
      # Redirect to OAuth flow
      oauth_url = get_calendar_oauth_url(provider, socket.assigns.user)
      send(self(), {:redirect_external, oauth_url})
      {:noreply, socket}
    else
      send(self(), {:calendar_error, "Upgrade to Creator for calendar integrations"})
      {:noreply, socket}
    end
  end

  defp assign_calendar_view_state(socket) do
    socket
    |> assign_new(:calendar_view, fn -> "week" end)
    |> assign_new(:current_calendar_date, fn -> Date.utc_today() end)
    |> assign_new(:show_event_form, fn -> false end)
  end

  defp refresh_calendar_events(socket) do
    user = socket.assigns.user
    account = socket.assigns.account
    date = socket.assigns.current_calendar_date

    {start_date, end_date} = get_date_range(date, socket.assigns.calendar_view)

    events = Calendar.get_user_visible_events(user, account,
      start_date: start_date,
      end_date: end_date
    )

    assign(socket, :calendar_events, events)
  end

  defp get_date_range(date, "week") do
    start_date = Date.add(date, -Date.day_of_week(date) + 1)
    end_date = Date.add(start_date, 6)
    {start_date, end_date}
  end

  defp get_date_range(date, "day") do
    {date, date}
  end

  defp get_date_range(date, _) do
    # Default to week view
    get_date_range(date, "week")
  end

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  defp parse_datetime(_), do: DateTime.utc_now()

  defp get_calendar_oauth_url(provider, user) do
    case provider do
      "google" -> "/auth/google/calendar?user_id=#{user.id}"
      "outlook" -> "/auth/microsoft/calendar?user_id=#{user.id}"
      _ -> "/calendar"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Calendar Header -->
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold text-gray-900">Calendar</h2>
          <p class="text-gray-600 mt-1">Manage your schedule and events</p>
        </div>

        <div class="flex items-center space-x-3">
          <!-- View Toggle -->
          <div class="flex bg-gray-100 rounded-lg p-1">
            <%= for view <- ["day", "week"] do %>
              <button phx-click="change_calendar_view"
                      phx-value-view={view}
                      phx-target={@myself}
                      class={[
                        "px-3 py-1 text-sm font-medium rounded-md transition-colors",
                        if(@calendar_view == view, do: "bg-white text-gray-900 shadow-sm", else: "text-gray-500 hover:text-gray-700")
                      ]}>
                <%= String.capitalize(view) %>
              </button>
            <% end %>
          </div>

          <!-- Full Calendar Link -->
          <.link navigate="/calendar"
                class="inline-flex items-center px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
            </svg>
            Full Calendar
          </.link>
        </div>
      </div>

      <!-- Calendar Stats Row -->
      <%= if @calendar_data.permissions.can_see_analytics do %>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-2 bg-blue-100 rounded-lg">
                <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Upcoming Events</p>
                <p class="text-2xl font-bold text-gray-900"><%= @calendar_data.stats.total_upcoming %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-2 bg-green-100 rounded-lg">
                <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Service Bookings</p>
                <p class="text-2xl font-bold text-gray-900"><%= @calendar_data.stats.bookings_count %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-2 bg-purple-100 rounded-lg">
                <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Broadcasts</p>
                <p class="text-2xl font-bold text-gray-900"><%= @calendar_data.stats.broadcasts_count %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-2 bg-yellow-100 rounded-lg">
                <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Channel Events</p>
                <p class="text-2xl font-bold text-gray-900"><%= @calendar_data.stats.channel_events_count %></p>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <!-- Free Tier Info -->
        <div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-xl p-6 border border-blue-200">
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <div class="p-2 bg-blue-100 rounded-lg">
                <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
              </div>
              <div class="ml-4">
                <h3 class="text-lg font-semibold text-gray-900">Personal Tier Calendar</h3>
                <p class="text-gray-600"><%= @calendar_data.stats.visible_note %></p>
                <p class="text-sm text-gray-500 mt-1">Showing <%= @calendar_data.stats.total_upcoming %> upcoming events</p>
              </div>
            </div>
            <.link navigate="/account/subscription"
                  class="inline-flex items-center px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700">
              Upgrade to Creator
            </.link>
          </div>
        </div>
      <% end %>

      <!-- Today's Events -->
      <%= if length(@calendar_data.today_events) > 0 do %>
        <div class="bg-white rounded-xl border border-gray-200">
          <div class="p-6 border-b border-gray-200">
            <h3 class="text-lg font-semibold text-gray-900">Today's Events</h3>
          </div>
          <div class="divide-y divide-gray-200">
            <%= for event <- @calendar_data.today_events do %>
              <div class="p-6 hover:bg-gray-50">
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <div class={[
                      "w-3 h-3 rounded-full mr-4",
                      get_event_color(event.event_type)
                    ]}></div>
                    <div>
                      <h4 class="font-medium text-gray-900"><%= event.title %></h4>
                      <p class="text-sm text-gray-500">
                        <%= format_event_time(event.starts_at) %> - <%= format_event_time(event.ends_at) %>
                        <%= if event.location do %>
                          • <%= event.location %>
                        <% end %>
                      </p>
                      <span class={[
                        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium mt-1",
                        get_event_badge_color(event.event_type)
                      ]}>
                        <%= format_event_type(event.event_type) %>
                      </span>
                    </div>
                  </div>
                  <%= if event.meeting_url do %>
                    <a href={event.meeting_url} target="_blank"
                       class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50">
                      Join Meeting
                    </a>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Calendar Integrations Status -->
      <div class="bg-white rounded-xl border border-gray-200 p-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-gray-900">Calendar Integrations</h3>
          <div class={[
            "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
            case @calendar_data.sync_status.status do
              :synced -> "bg-green-100 text-green-800"
              :partial_sync -> "bg-yellow-100 text-yellow-800"
              :no_integrations -> "bg-gray-100 text-gray-800"
              _ -> "bg-red-100 text-red-800"
            end
          ]}>
            <%= @calendar_data.sync_status.message %>
          </div>
        </div>

        <%= if length(@calendar_data.integrations) > 0 do %>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <%= for integration <- @calendar_data.integrations do %>
              <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                <div class="flex items-center">
                  <div class={[
                    "w-3 h-3 rounded-full mr-3",
                    if(integration.sync_enabled, do: "bg-green-500", else: "bg-gray-400")
                  ]}></div>
                  <div>
                    <p class="font-medium text-gray-900"><%= integration.calendar_name %></p>
                    <p class="text-sm text-gray-500"><%= String.capitalize(integration.provider) %></p>
                  </div>
                </div>
                <%= if integration.last_synced_at do %>
                  <p class="text-xs text-gray-400">
                    Last sync: <%= format_relative_time(integration.last_synced_at) %>
                  </p>
                <% end %>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-8">
            <svg class="w-12 h-12 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
            </svg>
            <h4 class="text-lg font-medium text-gray-900 mb-2">No Calendar Integrations</h4>
            <p class="text-gray-500 mb-4">Connect your external calendars to sync events automatically</p>

            <%= if @calendar_data.permissions.can_integrate do %>
              <div class="flex justify-center space-x-3">
                <button phx-click="connect_calendar"
                        phx-value-provider="google"
                        phx-target={@myself}
                        class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50">
                  <img src="/images/google-calendar.svg" alt="Google" class="w-4 h-4 mr-2">
                  Connect Google Calendar
                </button>
                <button phx-click="connect_calendar"
                        phx-value-provider="outlook"
                        phx-target={@myself}
                        class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50">
                  <img src="/images/outlook.svg" alt="Outlook" class="w-4 h-4 mr-2">
                  Connect Outlook
                </button>
              </div>
            <% else %>
              <p class="text-sm text-gray-400"><%= @calendar_data.permissions.upgrade_message %></p>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Quick Actions -->
      <%= if @calendar_data.permissions.can_create do %>
        <div class="bg-white rounded-xl border border-gray-200 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <button class="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
              <div class="p-2 bg-blue-100 rounded-lg mr-4">
                <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                </svg>
              </div>
              <div class="text-left">
                <p class="font-medium text-gray-900">Create Event</p>
                <p class="text-sm text-gray-500">Schedule a new event</p>
              </div>
            </button>

            <button class="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
              <div class="p-2 bg-green-100 rounded-lg mr-4">
                <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                </svg>
              </div>
              <div class="text-left">
                <p class="font-medium text-gray-900">Book Service</p>
                <p class="text-sm text-gray-500">Schedule a service appointment</p>
              </div>
            </button>

            <button class="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
              <div class="p-2 bg-purple-100 rounded-lg mr-4">
                <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/>
                </svg>
              </div>
              <div class="text-left">
                <p class="font-medium text-gray-900">Schedule Broadcast</p>
                <p class="text-sm text-gray-500">Plan a live broadcast</p>
              </div>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions for the template
  defp get_event_color("service_booking"), do: "bg-green-500"
  defp get_event_color("broadcast"), do: "bg-purple-500"
  defp get_event_color("channel_event"), do: "bg-blue-500"
  defp get_event_color("collaboration"), do: "bg-yellow-500"
  defp get_event_color(_), do: "bg-gray-500"

  defp get_event_badge_color("service_booking"), do: "bg-green-100 text-green-800"
  defp get_event_badge_color("broadcast"), do: "bg-purple-100 text-purple-800"
  defp get_event_badge_color("channel_event"), do: "bg-blue-100 text-blue-800"
  defp get_event_badge_color("collaboration"), do: "bg-yellow-100 text-yellow-800"
  defp get_event_badge_color(_), do: "bg-gray-100 text-gray-800"

  defp format_event_type("service_booking"), do: "Service Booking"
  defp format_event_type("channel_event"), do: "Channel Event"
  defp format_event_type(type), do: String.capitalize(type)

  defp format_event_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  defp format_relative_time(datetime) do
    # Simple relative time formatting - you might want to use a library like Timex
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
end
