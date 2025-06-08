# Collaboration Sidebar Component (already complete - this was included in the original)
defmodule FrestylWeb.PortfolioLive.Components.CollaborationSidebar do
  use FrestylWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class={[
      "fixed top-0 right-0 h-full w-96 bg-white shadow-2xl transform transition-transform duration-300 z-50",
      if(@feedback_panel_open, do: "translate-x-0", else: "translate-x-full")
    ]}>
      <!-- Sidebar Header -->
      <div class="bg-blue-600 text-white p-6">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="text-lg font-bold">Portfolio Feedback</h3>
            <p class="text-blue-100 text-sm">Help improve this portfolio</p>
          </div>
          <button phx-click="toggle_feedback_panel" class="text-white hover:text-blue-200">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Sidebar Content -->
      <div class="flex-1 overflow-y-auto p-6 space-y-6">
        <!-- Quick Actions -->
        <div class="space-y-3">
          <h4 class="font-semibold text-gray-900">Quick Actions</h4>

          <button class="w-full text-left p-3 bg-yellow-50 border border-yellow-200 rounded-lg hover:bg-yellow-100 transition-colors">
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-yellow-400 rounded-full flex items-center justify-center">
                <svg class="w-4 h-4 text-yellow-900" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14"/>
                </svg>
              </div>
              <div>
                <p class="font-medium text-gray-900">Highlight Text</p>
                <p class="text-sm text-gray-600">Select text to highlight and comment</p>
              </div>
            </div>
          </button>

          <button class="w-full text-left p-3 bg-blue-50 border border-blue-200 rounded-lg hover:bg-blue-100 transition-colors">
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-blue-400 rounded-full flex items-center justify-center">
                <svg class="w-4 h-4 text-blue-900" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
              </div>
              <div>
                <p class="font-medium text-gray-900">Add General Note</p>
                <p class="text-sm text-gray-600">Share overall thoughts and suggestions</p>
              </div>
            </div>
          </button>
        </div>

        <!-- Section-Specific Feedback -->
        <div class="space-y-3">
          <h4 class="font-semibold text-gray-900">Section Feedback</h4>

          <%= for section <- @sections do %>
            <div class="p-3 bg-gray-50 rounded-lg">
              <div class="flex items-center justify-between mb-2">
                <h5 class="font-medium text-gray-900 text-sm"><%= section.title %></h5>
                <span class="text-xs bg-gray-200 text-gray-700 px-2 py-1 rounded">
                  <%= format_section_type(section.section_type) %>
                </span>
              </div>

              <form phx-submit="submit_feedback" class="space-y-2">
                <input type="hidden" name="section_id" value={section.id} />
                <textarea name="feedback"
                          placeholder="Feedback for this section..."
                          class="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                          rows="2"></textarea>
                <button type="submit"
                        class="w-full bg-blue-600 text-white px-3 py-1 rounded text-xs font-medium hover:bg-blue-700 transition-colors">
                  Add Feedback
                </button>
              </form>
            </div>
          <% end %>
        </div>

        <!-- Feedback Guidelines -->
        <div class="bg-green-50 border border-green-200 rounded-lg p-4">
          <h4 class="font-semibold text-green-900 mb-2">💡 Helpful Feedback Tips</h4>
          <ul class="text-sm text-green-800 space-y-1">
            <li>• Be specific about what works well</li>
            <li>• Suggest concrete improvements</li>
            <li>• Consider the target audience</li>
            <li>• Focus on content clarity and impact</li>
          </ul>
        </div>

        <!-- Submit All Feedback -->
        <div class="border-t pt-4">
          <button class="w-full bg-gradient-to-r from-green-600 to-emerald-600 text-white py-3 rounded-lg font-semibold hover:from-green-700 hover:to-emerald-700 transition-all duration-200">
            Submit All Feedback
          </button>
          <p class="text-xs text-gray-500 mt-2 text-center">
            Your feedback will help improve this portfolio
          </p>
        </div>
      </div>
    </div>

    <!-- Overlay when sidebar is open -->
    <%= if @feedback_panel_open do %>
      <div class="fixed inset-0 bg-black bg-opacity-25 z-40" phx-click="toggle_feedback_panel"></div>
    <% end %>
    """
  end

  defp format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      :experience -> "Experience"
      :education -> "Education"
      :skills -> "Skills"
      :featured_project -> "Project"
      :case_study -> "Case Study"
      :media_showcase -> "Media"
      :contact -> "Contact"
      _ -> String.capitalize(to_string(section_type))
    end
  end
end
