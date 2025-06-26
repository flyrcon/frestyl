# lib/frestyl_web/live/studio_live/header_component.ex
defmodule FrestylWeb.StudioLive.HeaderComponent do
  use FrestylWeb, :live_component

  @impl true
  def update(assigns, socket) do
    # Check if this is a portfolio collaboration channel
    portfolio_context = get_portfolio_context(assigns.channel)

    {:ok, socket
    |> assign(assigns)
    |> assign(:portfolio_context, portfolio_context)
    |> assign(:show_portfolio_preview, false)}
  end

  @impl true
  def handle_event("show_portfolio_preview", _params, socket) do
    {:noreply, assign(socket, :show_portfolio_preview, true)}
  end

  @impl true
  def handle_event("hide_portfolio_preview", _params, socket) do
    {:noreply, assign(socket, :show_portfolio_preview, false)}
  end

  @impl true
  def handle_event("open_portfolio", _params, socket) do
    if socket.assigns.portfolio_context do
      portfolio_url = "/p/#{socket.assigns.portfolio_context.slug}"
      {:noreply, push_event(socket, "open_url", %{url: portfolio_url, target: "_blank"})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="bg-gradient-to-r from-gray-900 via-purple-900 to-indigo-900 border-b border-gray-700 px-4 py-3">
      <div class="flex items-center justify-between">

        <!-- Left Section: Channel Info + Portfolio Context -->
        <div class="flex items-center space-x-4">

          <!-- Channel Name & Status -->
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 bg-gradient-to-br from-purple-500 to-indigo-600 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
              </svg>
            </div>

            <div>
              <h1 class="text-white font-bold text-lg flex items-center">
                <%= @channel.name %>
                <%= if @portfolio_context do %>
                  <span class="ml-2 px-2 py-1 bg-purple-500/30 text-purple-200 rounded-full text-xs font-medium">
                    <%= @portfolio_context.enhancement_type %>
                  </span>
                <% end %>
              </h1>

              <div class="flex items-center space-x-2 text-sm">
                <!-- Connection Status -->
                <div class="flex items-center text-green-400">
                  <div class="w-2 h-2 bg-green-400 rounded-full mr-1 animate-pulse"></div>
                  <span>Live</span>
                </div>

                <!-- Collaborator Count -->
                <span class="text-gray-300">•</span>
                <span class="text-gray-300"><%= length(@collaborators) %> collaborators</span>

                <!-- Portfolio Link if available -->
                <%= if @portfolio_context && @portfolio_context.slug do %>
                  <span class="text-gray-300">•</span>
                  <button
                    phx-click="show_portfolio_preview"
                    phx-target={@myself}
                    class="text-indigo-300 hover:text-indigo-200 transition-colors flex items-center">
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                    View Portfolio
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Portfolio Context Card -->
          <%= if @portfolio_context do %>
            <div class="hidden lg:flex items-center space-x-3 bg-white/10 backdrop-blur-sm rounded-lg px-4 py-2 border border-white/20">
              <div class="w-8 h-8 bg-gradient-to-br from-indigo-400 to-purple-500 rounded-md flex items-center justify-center">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                </svg>
              </div>
              <div>
                <div class="text-white font-medium text-sm"><%= @portfolio_context.title %></div>
                <div class="text-indigo-200 text-xs">Enhancing Portfolio</div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Right Section: Tools & Actions (existing content) -->
        <div class="flex items-center space-x-3">

          <!-- Collaboration Mode Selector (existing) -->
          <!-- ... existing collaboration mode selector ... -->

          <!-- Action Buttons -->
          <div class="flex items-center space-x-2">

            <!-- Portfolio Preview Button (mobile) -->
            <%= if @portfolio_context && @portfolio_context.slug do %>
              <button
                phx-click="show_portfolio_preview"
                phx-target={@myself}
                class="lg:hidden p-2 text-indigo-300 hover:text-white hover:bg-white/10 rounded-lg transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                </svg>
              </button>
            <% end %>

            <!-- Invite Button -->
            <button
              phx-click="toggle_invite_modal"
              class="flex items-center px-3 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg transition-colors text-sm font-medium">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
              </svg>
              Invite
            </button>

            <!-- Settings Menu (existing) -->
            <!-- ... existing settings menu ... -->
          </div>
        </div>
      </div>
    </header>

    <!-- Portfolio Preview Modal -->
    <%= if @show_portfolio_preview && @portfolio_context do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" role="dialog" aria-modal="true">
        <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <!-- Background overlay -->
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
              phx-click="hide_portfolio_preview"
              phx-target={@myself}
              aria-hidden="true"></div>

          <!-- Modal content -->
          <div class="inline-block align-bottom bg-white rounded-xl text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full">
            <div class="bg-gradient-to-r from-indigo-600 to-purple-600 px-6 py-4">
              <div class="flex items-center justify-between text-white">
                <div class="flex items-center">
                  <svg class="w-6 h-6 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                  </svg>
                  <div>
                    <h2 class="text-xl font-bold"><%= @portfolio_context.title %></h2>
                    <p class="text-indigo-200 text-sm">Currently enhancing: <%= @portfolio_context.enhancement_type %></p>
                  </div>
                </div>
                <button
                  phx-click="hide_portfolio_preview"
                  phx-target={@myself}
                  class="text-white hover:text-indigo-200 transition-colors">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            </div>

            <div class="p-6">
              <!-- Portfolio Preview Content -->
              <div class="bg-gray-50 rounded-lg p-4 mb-6">
                <div class="flex items-center justify-between mb-4">
                  <h3 class="font-medium text-gray-900">Portfolio Preview</h3>
                  <span class="text-xs text-gray-500 bg-gray-200 px-2 py-1 rounded-full">
                    <%= String.capitalize(@portfolio_context.theme || "default") %> Theme
                  </span>
                </div>

                <!-- Mock portfolio preview -->
                <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
                  <div class="h-32 bg-gradient-to-r from-gray-300 to-gray-400 flex items-center justify-center">
                    <div class="text-gray-600 text-sm">Portfolio Preview</div>
                  </div>
                  <div class="p-4">
                    <h4 class="font-bold text-gray-900 mb-1"><%= @portfolio_context.title %></h4>
                    <p class="text-sm text-gray-600">Preview of your portfolio as visitors see it</p>
                  </div>
                </div>
              </div>

              <!-- Enhancement Progress -->
              <div class="bg-purple-50 rounded-lg p-4 mb-6">
                <h3 class="font-medium text-gray-900 mb-3 flex items-center">
                  <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                  </svg>
                  Enhancement in Progress
                </h3>
                <div class="flex items-center">
                  <div class="flex-1 bg-purple-200 rounded-full h-2">
                    <div class="bg-purple-600 h-2 rounded-full" style="width: 35%"></div>
                  </div>
                  <span class="ml-3 text-sm text-purple-700 font-medium">35% Complete</span>
                </div>
                <p class="text-sm text-purple-600 mt-2">Keep collaborating to complete your <%= @portfolio_context.enhancement_type %></p>
              </div>

              <!-- Quick Actions -->
              <div class="flex justify-between items-center">
                <div class="text-sm text-gray-500">
                  <span>Use the Studio tools to enhance your portfolio, then view the results live</span>
                </div>
                <div class="flex space-x-3">
                  <button
                    phx-click="hide_portfolio_preview"
                    phx-target={@myself}
                    class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                    Continue Working
                  </button>
                  <button
                    phx-click="open_portfolio"
                    phx-target={@myself}
                    class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors flex items-center">
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                    View Live Portfolio
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp get_portfolio_context(channel) do
    cond do
      String.starts_with?(channel.channel_type || "", "portfolio_") ->
        # Extract portfolio from featured_content or channel name
        case channel.featured_content do
          [%{"type" => "portfolio", "id" => portfolio_id} | _] ->
            case Frestyl.Portfolios.get_portfolio(portfolio_id) do
              nil -> nil
              portfolio -> %{
                id: portfolio.id,
                title: portfolio.title,
                slug: portfolio.slug,
                theme: portfolio.theme,
                enhancement_type: extract_enhancement_type(channel.channel_type)
              }
            end
          _ ->
            # Fallback: parse from channel name
            parse_portfolio_from_channel_name(channel.name)
        end

      true -> nil
    end
  end

  defp extract_enhancement_type("portfolio_voice_over"), do: "Voice Introduction"
  defp extract_enhancement_type("portfolio_writing"), do: "Content Writing"
  defp extract_enhancement_type("portfolio_music"), do: "Background Music"
  defp extract_enhancement_type("portfolio_design"), do: "Visual Design"
  defp extract_enhancement_type("portfolio_quarterly_update"), do: "Quarterly Update"
  defp extract_enhancement_type("portfolio_feedback"), do: "Feedback & Review"
  defp extract_enhancement_type(_), do: "Portfolio Enhancement"

  defp parse_portfolio_from_channel_name(channel_name) do
    # Simple parsing - you might want to make this more robust
    case String.split(channel_name, " - ") do
      [portfolio_title, enhancement_type] -> %{
        title: portfolio_title,
        enhancement_type: enhancement_type,
        slug: nil,
        id: nil,
        theme: nil
      }
      _ -> nil
    end
  end
end
