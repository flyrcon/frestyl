# lib/frestyl_web/live/components/notification_center_component.ex

defmodule FrestylWeb.NotificationCenterComponent do
  @moduledoc """
  Enhanced notification center that integrates with the contextual chat system
  """

  use FrestylWeb, :live_component
  alias Frestyl.{Notifications, Chat}
  alias Phoenix.PubSub

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      show_panel: false,
      notifications: [],
      unread_count: 0,
      active_filter: :all,
      loading: false
    )}
  end

  @impl true
  def update(assigns, socket) do
    # Load notifications for current user
    notifications = load_user_notifications(assigns.current_user.id)
    unread_count = count_unread_notifications(notifications)

    # Subscribe to notification updates
    if connected?(socket) do
      PubSub.subscribe(Frestyl.PubSub, "user:#{assigns.current_user.id}:notifications")
    end

    {:ok, socket
     |> assign(assigns)
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def handle_event("toggle_panel", _params, socket) do
    {:noreply, assign(socket, :show_panel, !socket.assigns.show_panel)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    Notifications.mark_user_notifications_read(socket.assigns.current_user.id)

    updated_notifications = Enum.map(socket.assigns.notifications, fn notification ->
      Map.put(notification, :read_at, DateTime.utc_now())
    end)

    {:noreply, socket
     |> assign(:notifications, updated_notifications)
     |> assign(:unread_count, 0)}
  end

  @impl true
  def handle_event("mark_read", %{"notification_id" => notification_id}, socket) do
    Notifications.mark_notification_read(notification_id, socket.assigns.current_user.id)

    updated_notifications = Enum.map(socket.assigns.notifications, fn notification ->
      if notification.id == notification_id do
        Map.put(notification, :read_at, DateTime.utc_now())
      else
        notification
      end
    end)

    unread_count = count_unread_notifications(updated_notifications)

    {:noreply, socket
     |> assign(:notifications, updated_notifications)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def handle_event("filter_notifications", %{"filter" => filter}, socket) do
    filter_atom = String.to_atom(filter)
    filtered_notifications = filter_notifications(socket.assigns.notifications, filter_atom)

    {:noreply, socket
     |> assign(:active_filter, filter_atom)
     |> assign(:notifications, filtered_notifications)}
  end

  @impl true
  def handle_event("open_chat_from_notification", %{"notification_id" => notification_id}, socket) do
    notification = Enum.find(socket.assigns.notifications, & &1.id == notification_id)

    if notification && notification.metadata["conversation_id"] do
      # Send event to parent to open chat widget with specific conversation
      send(self(), {:open_chat_conversation, notification.metadata["conversation_id"]})

      # Mark notification as read
      Notifications.mark_notification_read(notification_id, socket.assigns.current_user.id)
    end

    {:noreply, assign(socket, :show_panel, false)}
  end

  @impl true
  def handle_info({:new_notification, notification}, socket) do
    updated_notifications = [notification | socket.assigns.notifications]
    unread_count = count_unread_notifications(updated_notifications)

    {:noreply, socket
     |> assign(:notifications, updated_notifications)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
      <!-- Notification Bell -->
      <button
        phx-click="toggle_panel"
        phx-target={@myself}
        class="relative p-2 text-gray-600 hover:text-gray-900 transition-colors"
      >
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M15 17h5l-3.5-3.5a1.5 1.5 0 010-2.121l.7-.7c.56-.56.56-1.46 0-2.02L12 4l-5.2 5.18c-.56.56-.56 1.46 0 2.02l.7.7a1.5 1.5 0 010 2.121L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
        </svg>

        <!-- Unread Badge -->
        <%= if @unread_count > 0 do %>
          <div class="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center font-bold">
            <%= if @unread_count > 99, do: "99+", else: @unread_count %>
          </div>
        <% end %>
      </button>

      <!-- Notification Panel -->
      <%= if @show_panel do %>
        <div class="absolute top-full right-0 mt-2 w-96 bg-white rounded-xl shadow-2xl border border-gray-200 z-50 max-h-96 overflow-hidden">
          <!-- Header -->
          <div class="p-4 border-b border-gray-200 bg-gray-50">
            <div class="flex items-center justify-between">
              <h3 class="font-semibold text-gray-900">Notifications</h3>
              <%= if @unread_count > 0 do %>
                <button
                  phx-click="mark_all_read"
                  phx-target={@myself}
                  class="text-sm text-blue-600 hover:text-blue-700 font-medium"
                >
                  Mark all read
                </button>
              <% end %>
            </div>

            <!-- Filter Tabs -->
            <div class="flex gap-2 mt-3">
              <%= for filter <- [:all, :chat, :collaboration, :service, :system] do %>
                <button
                  phx-click="filter_notifications"
                  phx-value-filter={filter}
                  phx-target={@myself}
                  class={[
                    "px-3 py-1 text-xs rounded-full transition-colors",
                    @active_filter == filter && "bg-blue-100 text-blue-700" || "text-gray-600 hover:bg-gray-100"
                  ]}
                >
                  <%= String.capitalize(to_string(filter)) %>
                </button>
              <% end %>
            </div>
          </div>

          <!-- Notifications List -->
          <div class="max-h-80 overflow-y-auto">
            <%= if length(@notifications) == 0 do %>
              <div class="p-8 text-center text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-2 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-3.5-3.5a1.5 1.5 0 010-2.121l.7-.7c.56-.56.56-1.46 0-2.02L12 4l-5.2 5.18c-.56.56-.56 1.46 0 2.02l.7.7a1.5 1.5 0 010 2.121L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                </svg>
                <p class="text-sm">No notifications yet</p>
              </div>
            <% else %>
              <%= for notification <- @notifications do %>
                <div class={[
                  "p-4 border-b border-gray-100 hover:bg-gray-50 transition-colors cursor-pointer",
                  !notification.read_at && "bg-blue-50"
                ]}>
                  <div class="flex items-start gap-3">
                    <!-- Notification Icon -->
                    <div class={[
                      "flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center",
                      get_notification_icon_bg(notification.type)
                    ]}>
                      <%= render_notification_icon(assigns, notification.type) %>
                    </div>

                    <!-- Content -->
                    <div class="flex-1 min-w-0">
                      <div class="flex items-start justify-between">
                        <div class="flex-1">
                          <p class="text-sm font-medium text-gray-900">
                            <%= notification.title %>
                          </p>
                          <p class="text-xs text-gray-600 mt-1">
                            <%= notification.message %>
                          </p>
                          <p class="text-xs text-gray-400 mt-2">
                            <%= format_notification_time(notification.inserted_at) %>
                          </p>
                        </div>

                        <!-- Actions -->
                        <div class="flex items-center gap-1">
                          <%= if notification.metadata["conversation_id"] do %>
                            <button
                              phx-click="open_chat_from_notification"
                              phx-value-notification_id={notification.id}
                              phx-target={@myself}
                              class="p-1 text-blue-600 hover:bg-blue-100 rounded"
                              title="Open chat"
                            >
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                              </svg>
                            </button>
                          <% end %>

                          <%= if !notification.read_at do %>
                            <button
                              phx-click="mark_read"
                              phx-value-notification_id={notification.id}
                              phx-target={@myself}
                              class="p-1 text-gray-600 hover:bg-gray-100 rounded"
                              title="Mark as read"
                            >
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                              </svg>
                            </button>
                          <% end %>
                        </div>
                      </div>

                      <!-- Unread Indicator -->
                      <%= if !notification.read_at do %>
                        <div class="absolute left-2 top-1/2 transform -translate-y-1/2 w-2 h-2 bg-blue-500 rounded-full"></div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp load_user_notifications(user_id) do
    # Placeholder - replace with actual Notifications module call
    []
  end

  defp count_unread_notifications(notifications) do
    Enum.count(notifications, & is_nil(&1.read_at))
  end

  defp filter_notifications(notifications, :all), do: notifications
  defp filter_notifications(notifications, filter) do
    Enum.filter(notifications, & &1.type == to_string(filter))
  end

  defp get_notification_icon_bg(:chat), do: "bg-blue-100"
  defp get_notification_icon_bg(:collaboration), do: "bg-green-100"
  defp get_notification_icon_bg(:service), do: "bg-purple-100"
  defp get_notification_icon_bg(:system), do: "bg-gray-100"
  defp get_notification_icon_bg(_), do: "bg-gray-100"

  defp render_notification_icon(assigns, :chat) do
    ~H"""
    <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
    </svg>
    """
  end

  defp render_notification_icon(assigns, :collaboration) do
    ~H"""
    <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
    </svg>
    """
  end

  defp render_notification_icon(assigns, :service) do
    ~H"""
    <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m8 0H8m8 0v10a2 2 0 01-2 2H10a2 2 0 01-2-2V6h8z" />
    </svg>
    """
  end

  defp render_notification_icon(assigns, _) do
    ~H"""
    <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  defp format_notification_time(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      diff when diff < 60 -> "Just now"
      diff when diff < 3600 -> "#{div(diff, 60)}m ago"
      diff when diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff when diff < 604800 -> "#{div(diff, 86400)}d ago"
      _ -> Calendar.strftime(datetime, "%m/%d")
    end
  end
end
