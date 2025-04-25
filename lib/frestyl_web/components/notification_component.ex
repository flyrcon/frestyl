# lib/frestyl_web/components/notification_component.ex
defmodule FrestylWeb.NotificationComponent do
  use Phoenix.Component
  import Phoenix.LiveView.Helpers

  def notification(assigns) do
    ~H"""
    <div
      id={"notification-#{@id}"}
      class="fixed inset-x-0 top-0 flex items-end justify-center px-4 py-6 sm:items-start sm:justify-end z-50 pointer-events-none"
      role="status"
      aria-live="polite"
    >
      <div
        class={[
          "max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto transform transition-all duration-300 ease-in-out",
          "ring-1 ring-black ring-opacity-5 overflow-hidden",
          if(@show, do: "translate-y-0 opacity-100", else: "translate-y-2 opacity-0")
        ]}
      >
        <div class="p-4">
          <div class="flex items-start">
            <div class="flex-shrink-0">
              <%= case @type do %>
                <% "success" -> %>
                  <svg class="h-6 w-6 text-green-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                <% "error" -> %>
                  <svg class="h-6 w-6 text-red-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                <% "warning" -> %>
                  <svg class="h-6 w-6 text-yellow-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                <% _ -> %>
                  <svg class="h-6 w-6 text-blue-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
              <% end %>
            </div>
            <div class="ml-3 w-0 flex-1 pt-0.5">
              <p class="text-sm font-medium text-gray-900">
                <%= @title %>
              </p>
              <p class="mt-1 text-sm text-gray-500">
                <%= @message %>
              </p>
            </div>
            <div class="ml-4 flex-shrink-0 flex">
              <button
                type="button"
                phx-click={@on_close}
                class="bg-white rounded-md inline-flex text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                aria-label="Close notification"
              >
                <span class="sr-only">Close</span>
                <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
