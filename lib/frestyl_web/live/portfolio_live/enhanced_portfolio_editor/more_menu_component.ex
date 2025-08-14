# File: lib/frestyl_web/live/portfolio_live/enhanced_portfolio_editor/more_menu_component.ex
defmodule FrestylWeb.PortfolioLive.EnhancedPortfolioEditor.MoreMenuComponent do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    socket = socket
    |> assign(:show_more_menu, false)
    |> assign(:exporting, false)
    |> assign(:export_type, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_more_menu", _params, socket) do
    {:noreply, assign(socket, :show_more_menu, !socket.assigns.show_more_menu)}
  end

  @impl true
  def handle_event("close_more_menu", _params, socket) do
    {:noreply, assign(socket, :show_more_menu, false)}
  end

  @impl true
  def handle_event("export_resume_pdf", _params, socket) do
    socket = socket
    |> assign(:exporting, true)
    |> assign(:export_type, "ats_resume")
    |> assign(:show_more_menu, false)

    # Start export process
    send(self(), {:export_ats_resume, socket.assigns.portfolio.id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_portfolio", _params, socket) do
    portfolio = socket.assigns.portfolio
    sections = socket.assigns.sections
    customization = socket.assigns.customization

    case save_portfolio_data(portfolio.id, sections, customization) do
      {:ok, _} ->
        {:noreply, socket
         |> assign(:show_more_menu, false)
         |> put_flash(:info, "Portfolio saved successfully!")}

      {:error, reason} ->
        {:noreply, socket
         |> assign(:show_more_menu, false)
         |> put_flash(:error, "Failed to save: #{reason}")}
    end
  end

  @impl true
  def handle_info({:export_complete, download_url}, socket) do
    socket = socket
    |> assign(:exporting, false)
    |> assign(:export_type, nil)
    |> push_event("download_file", %{url: download_url, filename: "resume.pdf"})
    |> put_flash(:info, "ATS Resume exported successfully!")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:export_error, reason}, socket) do
    socket = socket
    |> assign(:exporting, false)
    |> assign(:export_type, nil)
    |> put_flash(:error, "Export failed: #{reason}")

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="more-menu-component relative">
      <!-- More Menu Button -->
      <button
        phx-click="toggle_more_menu"
        phx-target={@myself}
        class="flex items-center space-x-2 px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg transition-colors font-medium border border-gray-300">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/>
        </svg>
        <span>More</span>
      </button>

      <!-- Dropdown Menu -->
      <%= if @show_more_menu do %>
        <div class="absolute right-0 top-full mt-2 w-64 bg-white rounded-lg shadow-lg border border-gray-200 z-50">
          <!-- Backdrop Click Handler -->
          <div
            class="fixed inset-0 z-40"
            phx-click="close_more_menu"
            phx-target={@myself}>
          </div>

          <div class="relative z-50 py-2">
            <!-- Save Portfolio -->
            <button
              phx-click="save_portfolio"
              phx-target={@myself}
              class="w-full flex items-center px-4 py-3 text-left hover:bg-gray-50 transition-colors">
              <svg class="w-5 h-5 text-green-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3-3m0 0l-3 3m3-3v12"/>
              </svg>
              <div>
                <p class="text-sm font-medium text-gray-900">Save Portfolio</p>
                <p class="text-xs text-gray-500">Save all changes to the cloud</p>
              </div>
            </button>

            <!-- Divider -->
            <div class="border-t border-gray-100 my-1"></div>

            <!-- Export ATS Resume -->
            <button
              phx-click="export_resume_pdf"
              phx-target={@myself}
              disabled={@exporting}
              class="w-full flex items-center px-4 py-3 text-left hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed">
              <%= if @exporting and @export_type == "ats_resume" do %>
                <svg class="w-5 h-5 text-blue-600 mr-3 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                </svg>
              <% else %>
                <svg class="w-5 h-5 text-blue-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              <% end %>
              <div>
                <p class="text-sm font-medium text-gray-900">
                  <%= if @exporting, do: "Exporting...", else: "Export ATS Resume" %>
                </p>
                <p class="text-xs text-gray-500">Download PDF with essential sections only</p>
              </div>
            </button>

            <!-- Export Full Portfolio -->
            <button
              phx-click="export_full_portfolio"
              phx-target={@myself}
              class="w-full flex items-center px-4 py-3 text-left hover:bg-gray-50 transition-colors">
              <svg class="w-5 h-5 text-purple-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
              </svg>
              <div>
                <p class="text-sm font-medium text-gray-900">Export Full Portfolio</p>
                <p class="text-xs text-gray-500">Download complete portfolio as PDF</p>
              </div>
            </button>

            <!-- Divider -->
            <div class="border-t border-gray-100 my-1"></div>

            <!-- Portfolio Settings -->
            <button
              phx-click="show_portfolio_settings"
              phx-target={@myself}
              class="w-full flex items-center px-4 py-3 text-left hover:bg-gray-50 transition-colors">
              <svg class="w-5 h-5 text-gray-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
              </svg>
              <div>
                <p class="text-sm font-medium text-gray-900">Portfolio Settings</p>
                <p class="text-xs text-gray-500">Privacy, sharing, and advanced options</p>
              </div>
            </button>

            <!-- Share Portfolio -->
            <button
              phx-click="share_portfolio"
              phx-target={@myself}
              class="w-full flex items-center px-4 py-3 text-left hover:bg-gray-50 transition-colors">
              <svg class="w-5 h-5 text-indigo-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"/>
              </svg>
              <div>
                <p class="text-sm font-medium text-gray-900">Share Portfolio</p>
                <p class="text-xs text-gray-500">Get shareable link or embed code</p>
              </div>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp save_portfolio_data(portfolio_id, sections, customization) do
    # TODO: Implement actual save logic
    # This should save sections and customization to the database
    {:ok, %{saved_at: DateTime.utc_now()}}
  end
end
