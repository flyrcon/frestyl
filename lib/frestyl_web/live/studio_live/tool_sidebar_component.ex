# lib/frestyl_web/live/studio_live/tool_sidebar_component.ex
defmodule FrestylWeb.StudioLive.ToolSidebarComponent do
  use FrestylWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-16 bg-gray-900 bg-opacity-70 flex flex-col items-center py-4 space-y-4 border-r border-gray-800">
      <%= for tool <- @available_tools do %>
        <button
          type="button"
          phx-click="set_active_tool"
          phx-value-tool={tool.id}
          class={[
            "p-2 rounded-md transition-all duration-200",
            @active_tool == tool.id && "bg-gradient-to-r from-indigo-500 to-purple-600 text-white shadow-md",
            @active_tool != tool.id && "text-gray-400 hover:text-white",
            !tool.enabled && "opacity-50 cursor-not-allowed"
          ]}
          disabled={!tool.enabled}
          aria-label={tool.name}
          title={tool.name}
        >
          <.tool_icon icon={tool.icon} class="w-6 h-6" />
        </button>
      <% end %>
    </div>
    """
  end

  defp tool_icon(assigns) do
    ~H"""
    <%= case @icon do %>
      <% "chat-bubble-left-ellipsis" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
        </svg>
      <% "document-text" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      <% "microphone" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
        </svg>
      <% "adjustments-horizontal" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
        </svg>
      <% "sparkles" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
        </svg>
      <% _ -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
        </svg>
    <% end %>
    """
  end
end
