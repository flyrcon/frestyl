# lib/frestyl_web/live/studio_live/header_component.ex

defmodule FrestylWeb.StudioLive.HeaderComponent do
  use FrestylWeb, :live_component
  alias FrestylWeb.AccessibilityComponents, as: A11y

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="flex items-center justify-between px-4 py-3 bg-black/20 backdrop-blur-xl border-b border-white/10 sticky top-0 z-50">
      <!-- Left Section: Navigation & Session Info -->
      <div class="flex items-center gap-4 flex-1 min-w-0">
        <!-- Back Button -->
        <.link
          navigate={~p"/channels/#{@channel.slug}"}
          class="text-white hover:text-purple-300 transition-colors group flex-shrink-0"
          aria-label="Back to channel"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 group-hover:transform group-hover:-translate-x-1 transition-all" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" />
          </svg>
        </.link>

        <!-- Session Info -->
        <div class="flex items-center space-x-3 min-w-0 flex-1">
          <!-- Channel Name -->
          <div class="text-sm text-purple-300 uppercase tracking-wider font-bold flex-shrink-0">
            <%= @channel.name %>
          </div>

          <span class="text-purple-400 flex-shrink-0">/</span>

          <!-- Session Title (Editable) -->
          <div class="min-w-0 flex-1">
            <%= if can_edit_session?(@permissions) do %>
              <input
                type="text"
                value={@session.title || "Untitled Session"}
                phx-blur="update_session_title"
                phx-target={@myself}
                class="bg-transparent border-b-2 border-purple-400 focus:border-pink-400 text-white focus:outline-none text-lg font-bold placeholder-purple-300 transition-colors w-full min-w-0"
                placeholder="Enter session title..."
                aria-label="Session name"
              />
            <% else %>
              <h1 class="text-lg font-bold text-white truncate">
                <%= @session.title || "Untitled Session" %>
              </h1>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Center Section: Status Indicators (Mobile Hidden) -->
      <div class="hidden md:flex items-center space-x-4">
        <!-- OT Status Indicators -->
        <%= if length(@pending_operations) > 0 do %>
          <div class="flex items-center space-x-2 text-yellow-300 text-sm bg-yellow-900/30 px-3 py-1.5 rounded-full backdrop-blur-sm border border-yellow-500/30">
            <div class="animate-pulse w-2 h-2 bg-yellow-400 rounded-full"></div>
            <span class="font-medium"><%= length(@pending_operations) %> syncing</span>
          </div>
        <% end %>

        <%= if length(@operation_conflicts) > 0 do %>
          <button
            phx-click="clear_conflicts"
            phx-target={@myself}
            class="flex items-center space-x-2 text-red-300 text-sm bg-red-900/30 px-3 py-1.5 rounded-full backdrop-blur-sm border border-red-500/30 hover:bg-red-900/50 transition-colors"
          >
            <div class="w-2 h-2 bg-red-400 rounded-full"></div>
            <span class="font-medium"><%= length(@operation_conflicts) %> conflicts</span>
          </button>
        <% end %>

        <!-- Connection Status -->
        <div class="flex items-center gap-2">
          <span class={[
            "h-3 w-3 rounded-full animate-pulse",
            case @connection_status do
              "connected" -> "bg-green-400 shadow-lg shadow-green-400/50"
              "connecting" -> "bg-yellow-400 shadow-lg shadow-yellow-400/50"
              _ -> "bg-red-400 shadow-lg shadow-red-400/50"
            end
          ]} title={String.capitalize(@connection_status)}></span>
          <span class="text-white/70 text-sm font-medium hidden lg:inline">
            <%= String.capitalize(@connection_status) %>
          </span>
        </div>
      </div>

      <!-- Right Section: Collaborators & Actions -->
      <div class="flex items-center space-x-3 flex-shrink-0">
        <!-- Collaborators Display -->
        <div class="hidden sm:flex items-center">
          <div class="flex -space-x-2">
            <%= for {collaborator, index} <- Enum.with_index(Enum.take(@collaborators, 3)) do %>
              <div
                class="w-8 h-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-xs font-bold border-2 border-white/20 shadow-lg"
                title={collaborator.username}
              >
                <%= String.first(collaborator.username || "U") %>
              </div>
            <% end %>

            <%= if length(@collaborators) > 3 do %>
              <div class="w-8 h-8 rounded-full bg-gray-600 flex items-center justify-center text-white text-xs font-bold border-2 border-white/20">
                +<%= length(@collaborators) - 3 %>
              </div>
            <% end %>
          </div>

          <span class="ml-3 text-white/70 text-sm font-medium">
            <%= length(@collaborators) %> online
          </span>
        </div>

        <!-- Mobile Collaborator Count -->
        <div class="sm:hidden flex items-center space-x-2">
          <div class="w-6 h-6 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-xs font-bold">
            <%= length(@collaborators) %>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex items-center space-x-2">
          <!-- Invite Button -->
          <%= if can_invite_users?(@permissions) do %>
            <A11y.a11y_button
              variant="primary"
              size="sm"
              class="bg-gradient-to-r from-pink-500 to-purple-600 hover:from-pink-600 hover:to-purple-700 border-0 shadow-lg shadow-pink-500/25 hover:shadow-xl hover:shadow-pink-500/40 transition-all duration-300 transform hover:scale-110"
              phx-click="toggle_invite_modal"
              phx-target={@myself}
              aria_label="Invite collaborators"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                <path d="M8 9a3 3 0 100-6 3 3 0 000 6zM8 11a6 6 0 016 6H2a6 6 0 016-6zM16 7a1 1 0 10-2 0v1h-1a1 1 0 100 2h1v1a1 1 0 102 0v-1h1a1 1 0 100-2h-1V7z" />
              </svg>
              <span class="hidden sm:inline ml-1">Invite</span>
            </A11y.a11y_button>
          <% end %>

          <!-- Settings Button -->
          <A11y.a11y_button
            variant="outline"
            size="sm"
            class="text-white/70 hover:text-white border-white/20 hover:bg-white/10 transition-all duration-200"
            phx-click="toggle_settings_modal"
            phx-target={@myself}
            aria_label="Settings"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd" />
            </svg>
          </A11y.a11y_button>

          <!-- OT Debug Toggle (dev only) -->
          <%= if Application.get_env(:frestyl, :environment) == :dev do %>
            <A11y.a11y_toggle
              id="ot-debug-toggle"
              checked={@ot_debug_mode}
              on_toggle="toggle_ot_debug"
              aria_label="Toggle OT Debug"
            />
          <% end %>

          <!-- End Session Button -->
          <%= if can_end_session?(@current_user, @session) do %>
            <A11y.a11y_button
              variant="primary"
              size="sm"
              class="bg-gradient-to-r from-red-500 to-red-600 hover:from-red-600 hover:to-red-700 border-0 shadow-lg shadow-red-500/25 hover:shadow-xl hover:shadow-red-500/40 transition-all duration-300"
              phx-click="end_session"
              phx-target={@myself}
            >
              <span class="hidden sm:inline">End Session</span>
              <span class="sm:hidden">End</span>
            </A11y.a11y_button>
          <% end %>

          <!-- Mobile Menu Button -->
          <%= if @is_mobile do %>
            <A11y.a11y_button
              variant="outline"
              size="sm"
              class="sm:hidden text-white/70 hover:text-white border-white/20 hover:bg-white/10"
              phx-click="toggle_mobile_menu"
              phx-target={@myself}
              aria_label="Menu"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </A11y.a11y_button>
          <% end %>
        </div>
      </div>
    </header>
    """
  end

  @impl true
  def handle_event("update_session_title", %{"value" => title}, socket) do
    send(self(), {:update_session_title, title})
    {:noreply, socket}
  end

  def handle_event("toggle_invite_modal", _, socket) do
    send(self(), :toggle_invite_modal)
    {:noreply, socket}
  end

  def handle_event("toggle_settings_modal", _, socket) do
    send(self(), :toggle_settings_modal)
    {:noreply, socket}
  end

  def handle_event("toggle_ot_debug", _, socket) do
    send(self(), :toggle_ot_debug)
    {:noreply, socket}
  end

  def handle_event("clear_conflicts", _, socket) do
    send(self(), :clear_conflicts)
    {:noreply, socket}
  end

  def handle_event("end_session", _, socket) do
    send(self(), :end_session)
    {:noreply, socket}
  end

  def handle_event("toggle_mobile_menu", _, socket) do
    send(self(), :toggle_mobile_menu)
    {:noreply, socket}
  end

  # Helper functions
  defp can_edit_session?(permissions), do: :edit in permissions
  defp can_invite_users?(permissions), do: :invite in permissions

  defp can_end_session?(user, session) do
    user.id == session.creator_id || user.id == session.host_id
  end
end
