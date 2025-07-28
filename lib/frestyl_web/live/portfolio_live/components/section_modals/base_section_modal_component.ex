# lib/frestyl_web/live/portfolio_live/components/section_modals/base_section_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent do
  @moduledoc """
  Base component for section modals - provides common modal structure and behavior
  """
  use FrestylWeb, :live_component

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
         phx-window-keydown="close_modal_on_escape"
         phx-key="Escape">
      <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden"
           phx-click-away="close_section_modal">

        <!-- Modal Header -->
        <div class="flex items-center justify-between p-6 border-b border-gray-200">
          <div>
            <h3 class="text-xl font-bold text-gray-900 flex items-center">
              <div class={["w-8 h-8 rounded-lg flex items-center justify-center mr-3", header_bg_class(@section_type)]}>
                <%= raw(get_section_icon(@section_type)) %>
              </div>
              <%= @modal_title %>
            </h3>
            <p class="text-gray-600 mt-1"><%= @modal_description %></p>
          </div>
          <button
            phx-click="close_section_modal"
            phx-target={@myself}
            class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition-colors">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Modal Content -->
        <div class="p-6 max-h-[70vh] overflow-y-auto">
          <form phx-submit="save_section" phx-target={@myself} class="space-y-6">
            <input type="hidden" name="section_id" value={@editing_section.id} />

            <!-- Section Title -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
              <input
                type="text"
                name="title"
                value={@editing_section.title || ""}
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Enter section title" />
            </div>

            <!-- Section Visibility -->
            <div class="flex items-center">
              <input
                type="checkbox"
                id="section_visible"
                name="visible"
                value="true"
                checked={@editing_section.visible}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
              <label for="section_visible" class="ml-2 block text-sm text-gray-900">
                Show this section on portfolio
              </label>
            </div>

            <!-- Custom Content Area - Override in child components -->
            <%= render_slot(@inner_block) %>

            <!-- Modal Actions -->
            <div class="flex items-center justify-end space-x-3 pt-6 border-t border-gray-200">
              <button
                type="button"
                phx-click="close_section_modal"
                phx-target={@myself}
                class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors">
                Cancel
              </button>
              <button
                type="submit"
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
                Save Section
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("close_section_modal", _params, socket) do
    send(self(), {:close_section_modal})
    {:noreply, socket}
  end

  def handle_event("save_section", params, socket) do
    send(self(), {:save_section, params})
    {:noreply, socket}
  end

  defp header_bg_class(section_type) do
    case section_type do
      :code_showcase -> "bg-gradient-to-br from-green-500 to-blue-600"
      :media_showcase -> "bg-gradient-to-br from-purple-500 to-pink-600"
      :experience -> "bg-gradient-to-br from-blue-500 to-indigo-600"
      :skills -> "bg-gradient-to-br from-orange-500 to-red-600"
      :projects -> "bg-gradient-to-br from-teal-500 to-cyan-600"
      _ -> "bg-gradient-to-br from-gray-500 to-gray-600"
    end
  end

  defp get_section_icon(section_type) do
    case section_type do
      :code_showcase -> "<svg class='w-4 h-4 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4'/></svg>"
      :media_showcase -> "<svg class='w-4 h-4 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z'/></svg>"
      :experience -> "<svg class='w-4 h-4 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 002 2h2a2 2 0 002-2V6m0 0v6a2 2 0 01-2 2H6a2 2 0 01-2-2V6a2 2 0 012-2h12a2 2 0 012 2z'/></svg>"
      :skills -> "<svg class='w-4 h-4 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z'/></svg>"
      :projects -> "<svg class='w-4 h-4 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10'/></svg>"
      _ -> "<svg class='w-4 h-4 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z'/></svg>"
    end
  end
end
