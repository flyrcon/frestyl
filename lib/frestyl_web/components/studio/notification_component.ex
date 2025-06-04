defmodule FrestylWeb.Studio.NotificationComponent do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, notifications: [])}
  end

  @impl true
  def update(%{notifications: notifications} = assigns, socket) do
    {:ok, assign(socket, notifications: notifications)}
  end

  @impl true
  def handle_event("dismiss_notification", %{"id" => id}, socket) do
    # Send dismissal event to parent
    send(self(), {:dismiss_notification, String.to_integer(id)})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="notification-container"
      class="fixed top-4 right-4 z-50 space-y-3 max-w-sm w-full"
      phx-hook="NotificationManager"
    >
      <%= for notification <- @notifications do %>
        <div
          id={"notification-#{notification.id}"}
          class={[
            "transform transition-all duration-300 ease-out",
            "bg-black/90 backdrop-blur-xl rounded-2xl shadow-2xl border border-white/20",
            "p-4 pr-12 relative overflow-hidden",
            get_notification_classes(notification.type)
          ]}
          role="alert"
          aria-live="polite"
          phx-hook="NotificationItem"
          data-notification-id={notification.id}
          data-auto-dismiss={notification.auto_dismiss || true}
          data-dismiss-after={notification.dismiss_after || 5000}
        >
          <!-- Animated border for different types -->
          <div class={[
            "absolute top-0 left-0 right-0 h-1 rounded-t-2xl",
            get_border_gradient(notification.type)
          ]}></div>

          <!-- Content -->
          <div class="flex items-start gap-3">
            <!-- Icon -->
            <div class={[
              "flex-shrink-0 w-8 h-8 rounded-xl flex items-center justify-center",
              get_icon_background(notification.type)
            ]}>
              <%= case notification.type do %>
                <% :success -> %>
                  <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                <% :error -> %>
                  <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                <% :warning -> %>
                  <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                <% :info -> %>
                  <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                <% :user_joined -> %>
                  <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                  </svg>
                <% :user_left -> %>
                  <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7a4 4 0 11-8 0 4 4 0 018 0zM9 14a6 6 0 00-6 6v1h12v-1a6 6 0 00-6-6zM21 12h-6" />
                  </svg>
                <% :new_message -> %>
                  <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                  </svg>
                <% :recording -> %>
                  <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                  </svg>
                <% :audio -> %>
                  <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                  </svg>
                <% :sync -> %>
                  <svg class="h-5 w-5 text-white animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                <% _ -> %>
                  <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
              <% end %>
            </div>

            <!-- Message Content -->
            <div class="flex-1 min-w-0">
              <%= if Map.get(notification, :title) do %>
                <h4 class="text-white font-semibold text-sm mb-1">
                  <%= notification.title %>
                </h4>
              <% end %>

              <p class="text-white/90 text-sm leading-relaxed">
                <%= notification.message %>
              </p>

              <%= if Map.get(notification, :details) do %>
                <p class="text-white/60 text-xs mt-1">
                  <%= notification.details %>
                </p>
              <% end %>

              <!-- Action buttons if provided -->
              <%= if Map.get(notification, :actions) do %>
                <div class="flex items-center gap-2 mt-3">
                  <%= for action <- notification.actions do %>
                    <button
                      phx-click={action.event}
                      phx-value-id={notification.id}
                      class="text-xs font-medium px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 text-white transition-colors"
                    >
                      <%= action.label %>
                    </button>
                  <% end %>
                </div>
              <% end %>

              <!-- Timestamp -->
              <div class="text-white/40 text-xs mt-2">
                <%= format_notification_time(notification.timestamp) %>
              </div>
            </div>
          </div>

          <!-- Dismiss Button -->
          <button
            phx-click="dismiss_notification"
            phx-value-id={notification.id}
            phx-target={@myself}
            class="absolute top-3 right-3 text-white/60 hover:text-white transition-colors p-1 rounded-lg hover:bg-white/10"
            aria-label="Dismiss notification"
          >
            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          <!-- Progress bar for auto-dismiss -->
          <%= if notification.auto_dismiss != false do %>
            <div class="absolute bottom-0 left-0 right-0 h-1 bg-white/10 rounded-b-2xl overflow-hidden">
              <div class="h-full bg-gradient-to-r from-white/30 to-white/60 rounded-b-2xl notification-progress"></div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions for styling
  defp get_notification_classes(:success), do: "shadow-green-500/20"
  defp get_notification_classes(:error), do: "shadow-red-500/20"
  defp get_notification_classes(:warning), do: "shadow-yellow-500/20"
  defp get_notification_classes(:info), do: "shadow-blue-500/20"
  defp get_notification_classes(:user_joined), do: "shadow-green-500/20"
  defp get_notification_classes(:user_left), do: "shadow-orange-500/20"
  defp get_notification_classes(:new_message), do: "shadow-purple-500/20"
  defp get_notification_classes(:recording), do: "shadow-red-500/20"
  defp get_notification_classes(:audio), do: "shadow-pink-500/20"
  defp get_notification_classes(:sync), do: "shadow-blue-500/20"
  defp get_notification_classes(_), do: "shadow-gray-500/20"

  defp get_border_gradient(:success), do: "bg-gradient-to-r from-green-400 to-emerald-500"
  defp get_border_gradient(:error), do: "bg-gradient-to-r from-red-400 to-red-500"
  defp get_border_gradient(:warning), do: "bg-gradient-to-r from-yellow-400 to-orange-500"
  defp get_border_gradient(:info), do: "bg-gradient-to-r from-blue-400 to-blue-500"
  defp get_border_gradient(:user_joined), do: "bg-gradient-to-r from-green-400 to-green-500"
  defp get_border_gradient(:user_left), do: "bg-gradient-to-r from-orange-400 to-red-500"
  defp get_border_gradient(:new_message), do: "bg-gradient-to-r from-purple-400 to-pink-500"
  defp get_border_gradient(:recording), do: "bg-gradient-to-r from-red-400 to-red-500 animate-pulse"
  defp get_border_gradient(:audio), do: "bg-gradient-to-r from-pink-400 to-purple-500"
  defp get_border_gradient(:sync), do: "bg-gradient-to-r from-blue-400 to-cyan-500"
  defp get_border_gradient(_), do: "bg-gradient-to-r from-gray-400 to-gray-500"

  defp get_icon_background(:success), do: "bg-green-500"
  defp get_icon_background(:error), do: "bg-red-500"
  defp get_icon_background(:warning), do: "bg-yellow-500"
  defp get_icon_background(:info), do: "bg-blue-500"
  defp get_icon_background(:user_joined), do: "bg-green-500"
  defp get_icon_background(:user_left), do: "bg-orange-500"
  defp get_icon_background(:new_message), do: "bg-purple-500"
  defp get_icon_background(:recording), do: "bg-red-500"
  defp get_icon_background(:audio), do: "bg-pink-500"
  defp get_icon_background(:sync), do: "bg-blue-500"
  defp get_icon_background(_), do: "bg-gray-500"

  defp format_notification_time(timestamp) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, timestamp, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)} hr ago"
      true -> Calendar.strftime(timestamp, "%m/%d %H:%M")
    end
  end
end
