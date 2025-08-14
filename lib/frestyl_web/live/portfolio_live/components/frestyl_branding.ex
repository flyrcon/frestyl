defmodule FrestylWeb.PortfolioLive.Components.FrestylBranding do
  use Phoenix.Component

  def render_frestyl_branding(assigns) do
    ~H"""
    <%= if @show_branding do %>
      <div class={[
        "frestyl-branding flex items-center justify-center text-xs text-gray-500 transition-colors hover:text-gray-700",
        case @position do
          "header" -> "py-2 border-b border-gray-100"
          "footer" -> "py-4 border-t border-gray-100 mt-8"
          _ -> "py-4"
        end
      ]}>
        <div class="flex items-center space-x-2">
          <!-- Frestyl Logo Icon -->
          <div class="w-4 h-4 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
            <svg class="w-2 h-2 text-white" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
            </svg>
          </div>

          <span>Made with</span>

          <a
            href="https://frestyl.com"
            target="_blank"
            rel="noopener noreferrer"
            class="font-medium text-blue-600 hover:text-blue-700 transition-colors">
            Frestyl
          </a>
        </div>
      </div>
    <% end %>
    """
  end
end
