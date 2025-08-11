# lib/frestyl_web/live/studio_live/index.ex
defmodule FrestylWeb.StudioLive.Index do
  @moduledoc """
  Enhanced Studio Live Index - Creator Studio Launch Hub
  Central hub for creating and managing studio sessions
  """

  use FrestylWeb, :live_view
  alias Frestyl.{Sessions, Accounts}
  alias FrestylWeb.StudioLive.CreatorStudioComponent

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user_from_session(session)

    if current_user do
      current_account = Accounts.get_account_for_user(current_user)

      socket = socket
      |> assign(:current_user, current_user)
      |> assign(:current_account, current_account)
      |> assign(:page_title, "Creator Studio")
      |> assign(:show_session_browser, false)
      |> assign(:active_sessions, load_active_sessions(current_user.id))

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_event("toggle_session_browser", _params, socket) do
    {:noreply, assign(socket, :show_session_browser, !socket.assigns.show_session_browser)}
  end

  @impl true
  def handle_event("refresh_sessions", _params, socket) do
    active_sessions = load_active_sessions(socket.assigns.current_user.id)
    {:noreply, assign(socket, :active_sessions, active_sessions)}
  end

  # Forward Creator Studio events to the component
  @impl true
  def handle_event(event, params, socket) when event in [
    "launch_studio_tool", "launch_quick_session", "resume_session",
    "delete_session", "clear_error"
  ] do
    # These events will be handled by the CreatorStudioComponent
    {:noreply, socket}
  end

  defp get_current_user_from_session(session) do
    if user_token = session["user_token"] do
      Accounts.get_user_by_session_token(user_token)
    else
      nil
    end
  end

  defp load_active_sessions(user_id) do
    case Sessions.list_active_user_sessions(user_id) do
      sessions when is_list(sessions) -> sessions
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 via-purple-50 to-blue-50">
      <!-- Studio Header -->
      <div class="bg-gradient-to-r from-purple-900 via-blue-900 to-indigo-900 text-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div class="flex flex-col lg:flex-row lg:items-center justify-between">
            <div class="mb-6 lg:mb-0">
              <h1 class="text-4xl lg:text-5xl font-bold frestyl-text-cosmic mb-3">
                Frestyl Creator Studio
              </h1>
              <p class="text-xl text-purple-200 max-w-2xl">
                Professional audio production, beat creation, podcast recording, and live streaming suite
              </p>
            </div>

            <div class="flex flex-col sm:flex-row items-start sm:items-center space-y-4 sm:space-y-0 sm:space-x-4">
              <!-- Quick Actions -->
              <div class="flex items-center space-x-3">
                <button phx-click="refresh_sessions"
                        class="frestyl-btn frestyl-btn-glass frestyl-btn-sm">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                  </svg>
                  Refresh
                </button>

                <button phx-click="toggle_session_browser"
                        class="frestyl-btn frestyl-btn-outline frestyl-btn-sm">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                  </svg>
                  Browse Sessions
                </button>
              </div>

              <!-- Navigation -->
              <div class="flex items-center space-x-3">
                <.link navigate={~p"/dashboard"} class="frestyl-btn frestyl-btn-glass frestyl-btn-sm">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
                  </svg>
                  Dashboard
                </.link>

                <.link navigate={~p"/portfolio-hub"} class="frestyl-btn frestyl-btn-glass frestyl-btn-sm">
                  Portfolio Hub
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Main Content -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Active Sessions Quick Bar (if any) -->
        <%= if length(@active_sessions) > 0 do %>
          <div class="frestyl-card p-4 mb-8">
            <div class="flex items-center justify-between mb-3">
              <h3 class="font-semibold text-gray-900">Active Sessions</h3>
              <span class="text-sm text-gray-600"><%= length(@active_sessions) %> running</span>
            </div>

            <div class="flex flex-wrap gap-3">
              <%= for session <- @active_sessions do %>
                <.link navigate={~p"/studio/#{session.id}"}
                       class="flex items-center space-x-2 bg-green-50 hover:bg-green-100 px-3 py-2 rounded-lg transition-colors border border-green-200">
                  <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                  <span class="text-sm font-medium text-green-800"><%= session.title %></span>
                </.link>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Session Browser Modal (if enabled) -->
        <%= if @show_session_browser do %>
          <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" phx-click="toggle_session_browser">
            <div class="frestyl-card max-w-4xl w-full mx-4 p-6" phx-click="stop_propagation">
              <div class="flex items-center justify-between mb-6">
                <h2 class="text-xl font-bold text-gray-900">Browse All Sessions</h2>
                <button phx-click="toggle_session_browser" class="text-gray-400 hover:text-gray-600">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>

              <div class="text-center py-12 text-gray-500">
                <svg class="w-16 h-16 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                </svg>
                <p>Session browser will be implemented here</p>
                <p class="text-sm mt-2">Browse, filter, and manage all your studio sessions</p>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Creator Studio Component -->
        <.live_component module={CreatorStudioComponent}
                        id="creator-studio"
                        current_user={@current_user}
                        current_account={@current_account} />
      </div>

      <!-- Footer -->
      <div class="bg-gray-50 border-t border-gray-200 mt-16">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div class="flex flex-col md:flex-row md:items-center justify-between">
            <div class="mb-4 md:mb-0">
              <h3 class="text-lg font-semibold frestyl-text-gradient">Frestyl Studio</h3>
              <p class="text-gray-600">Professional creative tools for modern creators</p>
            </div>

            <div class="flex items-center space-x-6 text-sm text-gray-500">
              <.link href="#" class="hover:text-purple-600 transition-colors">Help & Support</.link>
              <.link href="#" class="hover:text-purple-600 transition-colors">Keyboard Shortcuts</.link>
              <.link href="#" class="hover:text-purple-600 transition-colors">Studio Guide</.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
