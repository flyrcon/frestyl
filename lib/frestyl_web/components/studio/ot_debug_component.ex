defmodule FrestylWeb.Studio.OtDebugComponent do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      expanded_sections: MapSet.new(["overview"]),
      operation_history: [],
      show_raw_data: false
    )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket) do
    expanded = socket.assigns.expanded_sections
    new_expanded = if MapSet.member?(expanded, section) do
      MapSet.delete(expanded, section)
    else
      MapSet.put(expanded, section)
    end

    {:noreply, assign(socket, expanded_sections: new_expanded)}
  end

  @impl true
  def handle_event("toggle_raw_data", _, socket) do
    {:noreply, assign(socket, show_raw_data: !socket.assigns.show_raw_data)}
  end

  @impl true
  def handle_event("clear_conflicts", _, socket) do
    send(self(), :clear_ot_conflicts)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-yellow-900/20 backdrop-blur-sm border border-yellow-500/30 rounded-xl p-4 text-yellow-100 font-mono text-sm">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-yellow-300 font-bold">OT Debug Panel</h3>
        <div class="flex gap-2">
          <button
            phx-click="toggle_raw_data"
            phx-target={@myself}
            class={[
              "px-2 py-1 rounded text-xs transition-colors",
              @show_raw_data && "bg-yellow-600 text-black" || "bg-yellow-900/50 text-yellow-300 hover:bg-yellow-800/50"
            ]}
          >
            Raw Data
          </button>
          <%= if length(@operation_conflicts) > 0 do %>
            <button
              phx-click="clear_conflicts"
              phx-target={@myself}
              class="px-2 py-1 rounded text-xs bg-red-600 text-white hover:bg-red-700 transition-colors"
            >
              Clear Conflicts
            </button>
          <% end %>
        </div>
      </div>

      <!-- Overview Section -->
      <div class="mb-3">
        <button
          phx-click="toggle_section"
          phx-value-section="overview"
          phx-target={@myself}
          class="flex items-center gap-2 text-yellow-300 hover:text-yellow-200 font-medium"
        >
          <svg class={[
            "h-4 w-4 transition-transform",
            MapSet.member?(@expanded_sections, "overview") && "rotate-90" || ""
          ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
          Overview
        </button>

        <%= if MapSet.member?(@expanded_sections, "overview") do %>
          <div class="ml-6 mt-2 space-y-1">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <span class="text-yellow-400">Text Version:</span>
                <span class="text-white ml-2"><%= @workspace_state.text.version %></span>
              </div>
              <div>
                <span class="text-yellow-400">Audio Version:</span>
                <span class="text-white ml-2"><%= @workspace_state.audio.version %></span>
              </div>
              <div>
                <span class="text-yellow-400">Pending Ops:</span>
                <span class="text-white ml-2"><%= length(@pending_operations) %></span>
              </div>
              <div>
                <span class="text-yellow-400">Conflicts:</span>
                <span class={[
                  "ml-2",
                  length(@operation_conflicts) > 0 && "text-red-400" || "text-green-400"
                ]}><%= length(@operation_conflicts) %></span>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Pending Operations Section -->
      <%= if length(@pending_operations) > 0 do %>
        <div class="mb-3">
          <button
            phx-click="toggle_section"
            phx-value-section="pending"
            phx-target={@myself}
            class="flex items-center gap-2 text-yellow-300 hover:text-yellow-200 font-medium"
          >
            <svg class={[
              "h-4 w-4 transition-transform",
              MapSet.member?(@expanded_sections, "pending") && "rotate-90" || ""
            ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
            Pending Operations (<%= length(@pending_operations) %>)
          </button>

          <%= if MapSet.member?(@expanded_sections, "pending") do %>
            <div class="ml-6 mt-2 space-y-2 max-h-40 overflow-y-auto">
              <%= for op <- Enum.take(@pending_operations, 10) do %>
                <div class="bg-yellow-900/30 rounded p-2 text-xs">
                  <div class="flex justify-between items-center">
                    <span class="text-yellow-400"><%= op.type %>:<%= op.action %></span>
                    <span class="text-yellow-600"><%= format_timestamp(op.timestamp) %></span>
                  </div>
                  <%= if @show_raw_data do %>
                    <pre class="text-yellow-200 mt-1 overflow-x-auto"><%= inspect(op.data, limit: :infinity, pretty: true) %></pre>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Conflicts Section -->
      <%= if length(@operation_conflicts) > 0 do %>
        <div class="mb-3">
          <button
            phx-click="toggle_section"
            phx-value-section="conflicts"
            phx-target={@myself}
            class="flex items-center gap-2 text-red-300 hover:text-red-200 font-medium"
          >
            <svg class={[
              "h-4 w-4 transition-transform",
              MapSet.member?(@expanded_sections, "conflicts") && "rotate-90" || ""
            ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
            Conflicts (<%= length(@operation_conflicts) %>)
          </button>

          <%= if MapSet.member?(@expanded_sections, "conflicts") do %>
            <div class="ml-6 mt-2 space-y-2">
              <%= for conflict <- @operation_conflicts do %>
                <div class="bg-red-900/30 rounded p-2 text-xs">
                  <div class="text-red-400"><%= conflict.type %></div>
                  <div class="text-red-200 mt-1"><%= conflict.description || "Conflict detected" %></div>
                  <%= if @show_raw_data do %>
                    <pre class="text-red-200 mt-1 overflow-x-auto"><%= inspect(conflict, limit: :infinity, pretty: true) %></pre>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- State Info -->
      <div class="mb-3">
        <button
          phx-click="toggle_section"
          phx-value-section="state"
          phx-target={@myself}
          class="flex items-center gap-2 text-yellow-300 hover:text-yellow-200 font-medium"
        >
          <svg class={[
            "h-4 w-4 transition-transform",
            MapSet.member?(@expanded_sections, "state") && "rotate-90" || ""
          ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
          Workspace State
        </button>

        <%= if MapSet.member?(@expanded_sections, "state") do %>
          <div class="ml-6 mt-2 space-y-2 text-xs">
            <div>
              <span class="text-yellow-400">Audio Tracks:</span>
              <span class="text-white ml-2"><%= length(@workspace_state.audio.tracks) %></span>
            </div>
            <div>
              <span class="text-yellow-400">Track Counter:</span>
              <span class="text-white ml-2"><%= @workspace_state.audio.track_counter %></span>
            </div>
            <div>
              <span class="text-yellow-400">Text Content Length:</span>
              <span class="text-white ml-2"><%= String.length(@workspace_state.text.content) %> chars</span>
            </div>
            <div>
              <span class="text-yellow-400">Active Cursors:</span>
              <span class="text-white ml-2"><%= map_size(@workspace_state.text.cursors) %></span>
            </div>
            <%= if @show_raw_data do %>
              <pre class="text-yellow-200 mt-2 overflow-x-auto max-h-40 overflow-y-auto"><%= inspect(@workspace_state, limit: :infinity, pretty: true) %></pre>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp, :millisecond)
    |> Calendar.strftime("%H:%M:%S.%f")
    |> String.slice(0..-4)
  end

  defp format_timestamp(_), do: "N/A"
end
