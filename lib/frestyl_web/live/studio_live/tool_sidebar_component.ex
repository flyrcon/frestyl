# lib/frestyl_web/live/studio_live/tool_sidebar_component.ex

defmodule FrestylWeb.StudioLive.ToolSidebarComponent do
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
    <div class={[
      "bg-black/30 backdrop-blur-xl flex flex-col items-center py-6 space-y-4 border-r border-white/10 transition-all duration-300",
      (if @collapsed, do: "w-0 opacity-0 overflow-hidden", else: "w-20")
    ]}>

      <!-- Collapse Toggle -->
      <button
        phx-click="toggle_sidebar"
        phx-target={@myself}
        class="absolute -right-3 top-6 w-6 h-6 bg-black/50 backdrop-blur-sm rounded-full flex items-center justify-center text-white/70 hover:text-white hover:bg-black/70 transition-all duration-200 z-10"
        aria-label={if @collapsed, do: "Expand sidebar", else: "Collapse sidebar"}
      >
        <svg class={[
          "w-3 h-3 transition-transform duration-200",
          (if @collapsed, do: "rotate-180", else: "rotate-0")
        ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
      </button>

      <!-- Tools -->
      <%= for tool <- @tools do %>
        <div class="relative group">
          <A11y.a11y_button
            variant="outline"
            size="lg"
            class={[
              "w-14 h-14 rounded-2xl transition-all duration-300 transform hover:scale-110 border-0 relative overflow-hidden",
              if @active_tool == tool.id do
                "bg-gradient-to-r from-pink-500 to-purple-600 text-white shadow-2xl shadow-pink-500/50"
              else
                "text-white/60 hover:text-white bg-white/5 hover:bg-white/10"
              end,
              if !tool.enabled do
                "opacity-30 cursor-not-allowed"
              end
            ]}
            disabled={!tool.enabled}
            phx-click="set_active_tool"
            phx-value-tool={tool.id}
            phx-target={@myself}
            aria_label={tool.name}
            aria_pressed={@active_tool == tool.id}
          >
            <!-- Glow effect for active tool -->
            <%= if @active_tool == tool.id do %>
              <div class="absolute inset-0 bg-gradient-to-r from-pink-500/20 to-purple-600/20 rounded-2xl blur-xl"></div>
            <% end %>

            <div class={[
              "relative z-10 w-full h-full flex items-center justify-center rounded-xl transition-all duration-200",
              if @active_tool == tool.id do
                "bg-white/20"
              else
                "bg-white/5 group-hover:bg-white/10"
              end
            ]}>
              <%= render_tool_icon(tool.icon) %>
            </div>
          </A11y.a11y_button>

          <!-- Tool name tooltip -->
          <div class="absolute left-full ml-4 px-3 py-2 bg-black/80 backdrop-blur-sm text-white text-sm rounded-lg opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap z-20 top-1/2 transform -translate-y-1/2">
            <%= tool.name %>
            <%= unless tool.enabled do %>
              <div class="text-xs text-gray-400 mt-1">Coming Soon</div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Spacer -->
      <div class="flex-1"></div>

      <!-- Additional Actions -->
      <div class="space-y-3">
        <!-- Help/Info Button -->
        <A11y.a11y_button
          variant="outline"
          size="md"
          class="w-12 h-12 rounded-xl text-white/40 hover:text-white/70 bg-white/5 hover:bg-white/10 border-0 transition-all duration-200"
          aria_label="Help and shortcuts"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </A11y.a11y_button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("set_active_tool", %{"tool" => tool}, socket) do
    send(self(), {:set_active_tool, tool})
    {:noreply, socket}
  end

  def handle_event("toggle_sidebar", _, socket) do
    send(self(), :toggle_sidebar)
    {:noreply, socket}
  end

  # Icon rendering helper
  defp render_tool_icon("microphone") do
    Phoenix.HTML.raw("""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
    </svg>
    """)
  end

  defp render_tool_icon("music-note") do
    Phoenix.HTML.raw("""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
    </svg>
    """)
  end

  defp render_tool_icon("document-text") do
    Phoenix.HTML.raw("""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    </svg>
    """)
  end

  defp render_tool_icon("pencil") do
    Phoenix.HTML.raw("""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
    </svg>
    """)
  end

  defp render_tool_icon(_) do
    Phoenix.HTML.raw("""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
    </svg>
    """)
  end
end
