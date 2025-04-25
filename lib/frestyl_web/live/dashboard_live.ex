# lib/frestyl_web/live/dashboard_live.ex
defmodule FrestylWeb.DashboardLive do
  use FrestylWeb, :live_view

  alias FrestylWeb.EventComponents
  alias FrestylWeb.MobileMenuComponent
  alias FrestylWeb.NotificationComponent

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      page_title: "Dashboard",
      mobile_menu_open: false,
      show_notification: false,
      notification_id: nil,
      user: %{
        name: "Demo User",
        email: "user@example.com",
        avatar: nil
      },
      upcoming_events: [
        %{
          id: "1",
          title: "Music Production Workshop",
          description: "Learn the basics of music production",
          host_name: "Producer Pro",
          host_avatar: nil,
          starts_at: DateTime.add(DateTime.utc_now(), 86400, :second) # Tomorrow
        },
        %{
          id: "2",
          title: "Collaborative Songwriting",
          description: "Write a song with other musicians",
          host_name: "Songwriter Guild",
          host_avatar: nil,
          starts_at: DateTime.add(DateTime.utc_now(), 172800, :second) # 2 days from now
        }
      ],
      recent_collaborations: [
        %{
          id: "1",
          title: "Beat Session",
          type: "music",
          last_active: DateTime.add(DateTime.utc_now(), -3600, :second), # 1 hour ago
          participants: 3
        },
        %{
          id: "2",
          title: "Album Artwork",
          type: "visual",
          last_active: DateTime.add(DateTime.utc_now(), -86400, :second), # 1 day ago
          participants: 2
        }
      ],
      menu_items: [
        {"Dashboard", "/dashboard", "home"},
        {"Events", "/events", "event"},
        {"Collaborations", "/collaborations", "collab"},
        {"Studio", "/studio", "studio"},
        {"Settings", "/settings", "settings"}
      ]
    )}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_event("close_mobile_menu", _, socket) do
    {:noreply, assign(socket, mobile_menu_open: false)}
  end

  @impl true
  def handle_event("show_notification", %{"type" => type, "message" => message}, socket) do
    notification_id = System.unique_integer([:positive]) |> to_string()

    title = case type do
      "success" -> "Success!"
      "error" -> "Error!"
      "warning" -> "Warning!"
      _ -> "Information"
    end

    # In a real app, you might use a PubSub broadcast to show notifications
    # across multiple LiveViews

    # Schedule the notification to disappear after 5 seconds
    Process.send_after(self(), {:hide_notification, notification_id}, 5000)

    {:noreply, assign(socket,
      show_notification: true,
      notification_id: notification_id,
      notification_type: type,
      notification_title: title,
      notification_message: message
    )}
  end

  @impl true
  def handle_event("hide_notification", _, socket) do
    {:noreply, assign(socket, show_notification: false)}
  end

  @impl true
  def handle_info({:hide_notification, id}, %{assigns: %{notification_id: id}} = socket) do
    {:noreply, assign(socket, show_notification: false)}
  end

  @impl true
  def handle_info({:hide_notification, _}, socket) do
    # Ignore notifications that don't match the current one
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <!-- Notification component -->
      <NotificationComponent.notification
        id={@notification_id}
        show={@show_notification}
        type={@notification_type}
        title={@notification_title}
        message={@notification_message}
        on_close="hide_notification"
      />

      <!-- Mobile menu -->
      <MobileMenuComponent.mobile_menu
        open={@mobile_menu_open}
        on_close="close_mobile_menu"
        menu_items={@menu_items}
      />

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="py-6">
          <div class="flex items-center justify-between">
            <h1 class="text-2xl font-semibold text-gray-900">Dashboard</h1>
            <div class="flex items-center">
              <button
                type="button"
                class="bg-indigo-600 p-2 rounded-md text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                phx-click="show_notification"
                phx-value-type="success"
                phx-value-message="Welcome to Frestyl! Your creative collaboration hub."
              >
                <span class="sr-only">Show welcome notification</span>
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path d="M10 2a6 6 0 00-6 6v3.586l-.707.707A1 1 0 004 14h12a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-3-3h6a3 3 0 01-3 3z" />
                </svg>
              </button>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <!-- Stats -->
          <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">Quick Stats</h2>
            <div class="grid grid-cols-1 gap-5 sm:grid-cols-3">
              <div class="bg-indigo-50 rounded-lg p-4">
                <div class="flex items-center">
                  <div class="flex-shrink-0 bg-indigo-500 rounded-md p-3">
                    <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z" />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dl>
                      <dt class="text-sm font-medium text-gray-500 truncate">
                        Active Projects
                      </dt>
                      <dd>
                        <div class="text-lg font-medium text-gray-900">
                          5
                        </div>
                      </dd>
                    </dl>
                  </div>
                </div>
              </div>

              <div class="bg-purple-50 rounded-lg p-4">
                <div class="flex items-center">
                  <div class="flex-shrink-0 bg-purple-500 rounded-md p-3">
                    <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dl>
                      <dt class="text-sm font-medium text-gray-500 truncate">
                        Collaborators
                      </dt>
                      <dd>
                        <div class="text-lg font-medium text-gray-900">
                          12
                        </div>
                      </dd>
                    </dl>
                  </div>
                </div>
              </div>

              <div class="bg-green-50 rounded-lg p-4">
                <div class="flex items-center">
                  <div class="flex-shrink-0 bg-green-500 rounded-md p-3">
                    <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dl>
                      <dt class="text-sm font-medium text-gray-500 truncate">
                        Upcoming Events
                      </dt>
                      <dd>
                        <div class="text-lg font-medium text-gray-900">
                          <%= length(@upcoming_events) %>
                        </div>
                      </dd>
                    </dl>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Recent Activity -->
          <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">Recent Activity</h2>
            <div class="flow-root">
              <ul role="list" class="-mb-8">
                <li>
                  <div class="relative pb-8">
                    <span class="absolute top-4 left-4 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true"></span>
                    <div class="relative flex space-x-3">
                      <div>
                        <span class="h-8 w-8 rounded-full bg-green-500 flex items-center justify-center ring-8 ring-white">
                          <svg class="h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                          </svg>
                        </span>
                      </div>
                      <div class="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
                        <div>
                          <p class="text-sm text-gray-500">
                            Registered for <a href="#" class="font-medium text-gray-900">Music Production Workshop</a>
                          </p>
                        </div>
                        <div class="text-right text-sm whitespace-nowrap text-gray-500">
                          1h ago
                        </div>
                      </div>
                    </div>
                  </div>
                </li>

                <li>
                  <div class="relative pb-8">
                    <span class="absolute top-4 left-4 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true"></span>
                    <div class="relative flex space-x-3">
                      <div>
                        <span class="h-8 w-8 rounded-full bg-indigo-500 flex items-center justify-center ring-8 ring-white">
                          <svg class="h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                            <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z" />
                          </svg>
                        </span>
                      </div>
                      <div class="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
                        <div>
                          <p class="text-sm text-gray-500">
                            Created a new project <a href="#" class="font-medium text-gray-900">Beat Session</a>
                          </p>
                        </div>
                        <div class="text-right text-sm whitespace-nowrap text-gray-500">
                          2d ago
                        </div>
                      </div>
                    </div>
                  </div>
                </li>

                <li>
                  <div class="relative pb-8">
                    <div class="relative flex space-x-3">
                      <div>
                        <span class="h-8 w-8 rounded-full bg-purple-500 flex items-center justify-center ring-8 ring-white">
                          <svg class="h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                            <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-3a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v3h-3zM4.75 12.094A5.973 5.973 0 004 15v3H1v-3a3 3 0 013.75-2.906z" />
                          </svg>
                        </span>
                      </div>
                      <div class="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
                        <div>
                          <p class="text-sm text-gray-500">
                            Joined collaboration <a href="#" class="font-medium text-gray-900">Album Artwork</a>
                          </p>
                        </div>
                        <div class="text-right text-sm whitespace-nowrap text-gray-500">
                          1w ago
                        </div>
                      </div>
                    </div>
                  </div>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <!-- Upcoming Events -->
        <div class="mt-6">
          <h2 class="text-lg font-medium text-gray-900 mb-4">Upcoming Events</h2>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <%= for event <- @upcoming_events do %>
              <EventComponents.event_card event={event} />
            <% end %>
          </div>
          <div class="mt-2 text-right">
            <a href="/events" class="text-sm font-medium text-indigo-600 hover:text-indigo-500">
              View all events <span aria-hidden="true">&rarr;</span>
            </a>
          </div>
        </div>

        <!-- Recent Collaborations -->
        <div class="mt-8">
          <h2 class="text-lg font-medium text-gray-900 mb-4">Recent Collaborations</h2>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <%= for collab <- @recent_collaborations do %>
              <div class="bg-white overflow-hidden shadow rounded-lg">
                <div class="px-4 py-5 sm:p-6">
                  <div class="flex items-center">
                    <div class={[
                      "flex-shrink-0 rounded-md p-3",
                      collab.type == "music" && "bg-indigo-500",
                      collab.type == "visual" && "bg-purple-500"
                    ]}>
                      <%= if collab.type == "music" do %>
                        <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                        </svg>
                      <% else %>
                        <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                        </svg>
                      <% end %>
                    </div>
                    <div class="ml-5 w-0 flex-1">
                      <dl>
                        <dt class="text-sm font-medium text-gray-500 truncate">
                          <%= collab.title %>
                        </dt>
                        <dd>
                          <div class="text-sm text-gray-900">
                            Last active <%= format_relative_time(collab.last_active) %>
                          </div>
                        </dd>
                      </dl>
                    </div>
                  </div>
                  <div class="mt-5">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center">
                        <div class="flex -space-x-2 overflow-hidden">
                          <%= for i <- 1..min(3, collab.participants) do %>
                            <div class="inline-block h-8 w-8 rounded-full bg-gray-200 border-2 border-white flex items-center justify-center text-gray-500 font-medium">
                              <%= String.at("UCP", i-1) %>
                            </div>
                          <% end %>
                        </div>
                        <span class="ml-2 text-sm text-gray-500"><%= collab.participants %> collaborators</span>
                      </div>
                      <a href={"/collaborations/#{collab.id}"} class="text-sm font-medium text-indigo-600 hover:text-indigo-500">
                        Open
                      </a>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Create new collaboration card -->
            <div class="bg-white overflow-hidden shadow rounded-lg border-2 border-dashed border-gray-300">
              <div class="px-4 py-5 sm:p-6 flex flex-col items-center justify-center h-full">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                </svg>
                <span class="mt-2 block text-sm font-medium text-gray-900">
                  New Collaboration
                </span>

                <a href="/collaborations/new"
                  class="mt-2 inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  Create
                </a>
              </div>
            </div>
          </div>
        </div>

        <!-- Quick Actions -->
        <div class="mt-8 mb-12">
          <h2 class="text-lg font-medium text-gray-900 mb-4">Quick Actions</h2>
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <a href="/studio" class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow duration-200">
              <div class="px-4 py-5 sm:p-6 flex flex-col items-center text-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-indigo-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                </svg>
                <span class="mt-2 block text-sm font-medium text-gray-900">
                  Open Studio
                </span>
              </div>
            </a>

            <a href="/events/create" class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow duration-200">
              <div class="px-4 py-5 sm:p-6 flex flex-col items-center text-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <span class="mt-2 block text-sm font-medium text-gray-900">
                  Create Event
                </span>
              </div>
            </a>

            <a href="/channels/my" class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow duration-200">
              <div class="px-4 py-5 sm:p-6 flex flex-col items-center text-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-purple-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
                </svg>
                <span class="mt-2 block text-sm font-medium text-gray-900">
                  My Channels
                </span>
              </div>
            </a>

            <a href="/profile" class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow duration-200">
              <div class="px-4 py-5 sm:p-6 flex flex-col items-center text-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                <span class="mt-2 block text-sm font-medium text-gray-900">
                  Profile Settings
                </span>
              </div>
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 ->
        "just now"
      diff_seconds < 3600 ->
        "#{div(diff_seconds, 60)} minute(s) ago"
      diff_seconds < 86400 ->
        "#{div(diff_seconds, 3600)} hour(s) ago"
      diff_seconds < 604800 ->
        "#{div(diff_seconds, 86400)} day(s) ago"
      true ->
        "#{div(diff_seconds, 604800)} week(s) ago"
    end
  end
end
