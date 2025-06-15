# lib/frestyl_web/live/portfolio_live/pdf_export_component.ex
defmodule FrestylWeb.PortfolioLive.PdfExportComponent do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:show_export_options, false)
     |> assign(:export_format, "portfolio")
     |> assign(:export_processing, false)
     |> assign(:export_ready, false)
     |> assign(:download_url, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative inline-block">
      <!-- Export Button -->
      <button phx-click="toggle_export_options" phx-target={@myself}
              class="group inline-flex items-center px-4 py-2 bg-gray-600 text-white rounded-lg font-medium hover:bg-gray-700 transition-all duration-200 shadow-md hover:shadow-lg">
        <svg class="w-4 h-4 mr-2 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
        Export
        <svg class={[
          "w-4 h-4 ml-1 transition-transform duration-200",
          if(@show_export_options, do: "rotate-180", else: "rotate-0")
        ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
        </svg>
      </button>

      <!-- Export Options Dropdown -->
      <%= if @show_export_options do %>
        <div class="absolute right-0 mt-2 w-80 bg-white rounded-xl shadow-2xl border border-gray-200 z-50 overflow-hidden">
          <!-- Header -->
          <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-4">
            <h3 class="text-lg font-bold text-white">Export Options</h3>
            <p class="text-blue-100 text-sm">Choose your export format</p>
          </div>

          <!-- Export Formats -->
          <div class="p-6 space-y-4">
            <%= for {format_key, format_config} <- export_formats() do %>
              <label class={[
                "flex items-start p-4 rounded-lg border-2 cursor-pointer transition-all duration-200 hover:bg-gray-50",
                if(@export_format == format_key,
                   do: "border-blue-500 bg-blue-50",
                   else: "border-gray-200")
              ]}>
                <input type="radio"
                       name="export_format"
                       value={format_key}
                       checked={@export_format == format_key}
                       phx-click="select_format"
                       phx-value-format={format_key}
                       phx-target={@myself}
                       class="mt-1 text-blue-600" />
                <div class="ml-3 flex-1">
                  <div class="flex items-center mb-1">
                    <span class="text-2xl mr-2"><%= format_config.icon %></span>
                    <h4 class="font-semibold text-gray-900"><%= format_config.name %></h4>
                  </div>
                  <p class="text-sm text-gray-600 mb-2"><%= format_config.description %></p>
                  <div class="flex flex-wrap gap-1">
                    <%= for feature <- format_config.features do %>
                      <span class="text-xs bg-gray-100 text-gray-700 px-2 py-1 rounded-full">
                        <%= feature %>
                      </span>
                    <% end %>
                  </div>
                </div>
              </label>
            <% end %>

            <!-- ATS Optimization Notice -->
            <%= if @export_format in ["resume", "ats_resume"] do %>
              <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                <div class="flex items-start">
                  <svg class="w-5 h-5 text-green-600 mt-0.5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <div>
                    <h5 class="font-medium text-green-900">ATS Optimized</h5>
                    <p class="text-sm text-green-800">This format is optimized for Applicant Tracking Systems (ATS) and will improve your chances of passing automated resume screens.</p>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Processing State -->
            <%= if @export_processing do %>
              <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <div class="flex items-center">
                  <svg class="w-5 h-5 text-blue-600 animate-spin mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                  </svg>
                  <div>
                    <p class="font-medium text-blue-900">Generating PDF...</p>
                    <p class="text-sm text-blue-700">This may take a few moments</p>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Ready for Download -->
            <%= if @export_ready and @download_url do %>
              <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <svg class="w-5 h-5 text-green-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                    </svg>
                    <div>
                      <p class="font-medium text-green-900">PDF Ready!</p>
                      <p class="text-sm text-green-700">Your export is ready for download</p>
                    </div>
                  </div>
                  <a href={@download_url}
                     download
                     class="bg-green-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-green-700 transition-colors">
                    Download
                  </a>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Action Buttons -->
          <div class="bg-gray-50 px-6 py-4 border-t border-gray-200 flex justify-between">
            <button phx-click="toggle_export_options" phx-target={@myself}
                    class="px-4 py-2 text-gray-700 hover:text-gray-900 transition-colors">
              Cancel
            </button>
            <button phx-click="start_export" phx-target={@myself}
                    disabled={@export_processing}
                    class={[
                      "px-6 py-2 rounded-lg font-medium transition-colors",
                      if(@export_processing,
                         do: "bg-gray-400 text-gray-600 cursor-not-allowed",
                         else: "bg-blue-600 text-white hover:bg-blue-700")
                    ]}>
              <%= if @export_processing, do: "Processing...", else: "Generate PDF" %>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_export_options", _params, socket) do
    {:noreply, assign(socket, :show_export_options, !socket.assigns.show_export_options)}
  end

  @impl true
  def handle_event("select_format", %{"format" => format}, socket) do
    {:noreply, assign(socket, :export_format, format)}
  end

  @impl true
  def handle_event("start_export", _params, socket) do
    # Start the export process
    socket = assign(socket, :export_processing, true)

    # Send export request to parent LiveView
    send(self(), {:start_pdf_export, socket.assigns.export_format})

    {:noreply, socket}
  end

  @impl true
  def update(%{export_complete: download_url}, socket) do
    {:ok,
     socket
     |> assign(:export_processing, false)
     |> assign(:export_ready, true)
     |> assign(:download_url, download_url)}
  end

  @impl true
  def update(%{export_failed: reason}, socket) do
    {:ok,
     socket
     |> assign(:export_processing, false)
     |> assign(:export_ready, false)
     |> put_flash(:error, "Export failed: #{reason}")}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  defp export_formats do
    [
      {"portfolio", %{
        name: "Full Portfolio",
        icon: "📄",
        description: "Complete portfolio with all sections and styling",
        features: ["Full Design", "All Sections", "Interactive Elements"]
      }},
      {"resume", %{
        name: "ATS Resume",
        icon: "📋",
        description: "Clean, ATS-friendly resume format",
        features: ["ATS Optimized", "Clean Layout", "Machine Readable"]
      }},
      {"executive_summary", %{
        name: "Executive Summary",
        icon: "⭐",
        description: "Professional one-page summary",
        features: ["One Page", "Key Highlights", "Executive Format"]
      }},
      {"presentation", %{
        name: "Presentation",
        icon: "📊",
        description: "Presentation-ready format with slides",
        features: ["Slide Format", "Visual Focus", "Presentation Ready"]
      }}
    ]
  end
end
