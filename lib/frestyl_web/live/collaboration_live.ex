# lib/frestyl_web/live/collaboration_live.ex
defmodule FrestylWeb.CollaborationLive do
  use FrestylWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to necessary topics for real-time updates
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "collaboration:updates")
    end

    {:ok, assign(socket,
      page_title: "Collaboration Hub",
      active_collaborations: [],
      invitations: [],
      mobile_menu_open: false
    )}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_event("create_collaboration", %{"type" => type}, socket) do
    # Logic to create a new collaboration space
    # Would interact with a context module

    {:noreply, socket}
  end

  @impl true
  def handle_event("join_collaboration", %{"id" => id}, socket) do
    # Logic to join an existing collaboration

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
      <div class="md:flex md:items-center md:justify-between">
        <div class="flex-1 min-w-0">
          <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
            Collaboration Hub
          </h2>
        </div>
        <div class="mt-4 flex md:mt-0 md:ml-4">
          <button type="button" phx-click="create_collaboration" phx-value-type="music"
            class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
            New Music Collab
          </button>
          <button type="button" phx-click="create_collaboration" phx-value-type="visual"
            class="ml-3 inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-purple-600 hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500">
            New Visual Collab
          </button>
        </div>
      </div>

      <div class="mt-8 grid gap-5 md:grid-cols-2 lg:grid-cols-3">
        <!-- Active Collaborations -->
        <div class="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
          <div class="px-4 py-5 sm:px-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Music Collaboration</h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">Beat Session with DJ Freso</p>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="flex items-center justify-between">
              <div class="flex items-center">
                <div class="flex -space-x-2 overflow-hidden">
                  <img class="inline-block h-8 w-8 rounded-full ring-2 ring-white" src="https://via.placeholder.com/150" alt="User 1">
                  <img class="inline-block h-8 w-8 rounded-full ring-2 ring-white" src="https://via.placeholder.com/150" alt="User 2">
                  <img class="inline-block h-8 w-8 rounded-full ring-2 ring-white" src="https://via.placeholder.com/150" alt="User 3">
                </div>
                <span class="ml-2 text-sm text-gray-500">3 participants</span>
              </div>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                Live
              </span>
            </div>
            <div class="mt-4">
              <a href="#" class="text-sm font-medium text-indigo-600 hover:text-indigo-500">
                Join session <span aria-hidden="true">→</span>
              </a>
            </div>
          </div>
        </div>

        <!-- Add more collaboration cards here as needed -->
      </div>
    </div>
    """
  end
end
