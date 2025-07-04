# lib/frestyl_web/live/portfolio_live/pdf_export_component.ex
defmodule FrestylWeb.PortfolioLive.PdfExportComponent do
  use FrestylWeb, :live_component
  alias Frestyl.ResumeExporter
  alias Frestyl.Portfolios

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:export_status, :idle)
     |> assign(:export_format, :ats_resume)
     |> assign(:available_formats, get_available_formats())
     |> assign(:export_options, %{})
     |> assign(:download_url, nil)}
  end

  @impl true
  def update(%{portfolio: portfolio, current_user: current_user} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:portfolio, portfolio)
     |> assign(:current_user, current_user)
     |> assign(:can_export_docx, portfolio.user_id == current_user.id)}
  end

  @impl true
  def handle_event("select-format", %{"format" => format}, socket) do
    {:noreply,
     socket
     |> assign(:export_format, String.to_atom(format))
     |> assign(:export_options, get_default_options(String.to_atom(format)))}
  end

  @impl true
  def handle_event("update-option", %{"option" => option, "value" => value}, socket) do
    new_options = Map.put(socket.assigns.export_options, option, value)
    {:noreply, assign(socket, :export_options, new_options)}
  end

  @impl true
  def handle_event("export-portfolio", _params, socket) do
    %{portfolio: portfolio, export_format: format, export_options: options} = socket.assigns

    # Start async export process
    task = Task.async(fn ->
      ResumeExporter.export_portfolio(portfolio, format, options)
    end)

    {:noreply,
     socket
     |> assign(:export_status, :exporting)
     |> assign(:export_task, task)}
  end

  @impl true
  def handle_event("download-file", %{"url" => url}, socket) do
    # This will be handled by the download controller
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset-export", _params, socket) do
    {:noreply,
     socket
     |> assign(:export_status, :idle)
     |> assign(:download_url, nil)}
  end

  @impl true
  def handle_info({ref, result}, socket) do
    # Check if this message is from our export task
    if Map.has_key?(socket.assigns, :export_task) and socket.assigns.export_task do
      case result do
        {:ok, file_info} ->
          {:noreply,
          socket
          |> assign(:export_status, :complete)
          |> assign(:download_url, file_info.download_url)
          |> assign(:file_info, file_info)
          |> put_flash(:info, "Export completed successfully!")}

        {:error, reason} ->
          {:noreply,
          socket
          |> assign(:export_status, :error)
          |> put_flash(:error, "Export failed: #{reason}")}
      end
    else
      # Not our task, ignore
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    # Handle task completion/failure
    {:noreply, socket}
  end

  defp get_available_formats do
    %{
      ats_resume: %{
        name: "ATS-Optimized Resume",
        description: "Clean, ATS-friendly PDF resume (8.5x11)",
        icon: "document-text",
        file_type: "PDF"
      },
      full_portfolio: %{
        name: "Complete Portfolio",
        description: "Full portfolio with all sections and media",
        icon: "document-duplicate",
        file_type: "PDF"
      },
      html_archive: %{
        name: "HTML Archive",
        description: "Self-contained HTML file for web viewing",
        icon: "code-bracket",
        file_type: "HTML"
      },
      docx_resume: %{
        name: "DOCX Resume",
        description: "Editable Word document (owner only)",
        icon: "document",
        file_type: "DOCX",
        restricted: true
      }
    }
  end

  defp get_default_options(format) do
    case format do
      :ats_resume ->
        %{
          "include_photo" => false,
          "font_family" => "Arial",
          "font_size" => "11pt",
          "sections" => ["contact", "summary", "experience", "education", "skills"]
        }

      :full_portfolio ->
        %{
          "include_photo" => true,
          "include_projects" => true,
          "include_testimonials" => true,
          "page_orientation" => "portrait"
        }

      :html_archive ->
        %{
          "responsive_design" => true,
          "include_print_styles" => true,
          "embed_assets" => true
        }

      :docx_resume ->
        %{
          "template_style" => "professional",
          "include_photo" => false
        }

      _ ->
        %{}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <h3 class="text-lg font-semibold text-gray-900">Export Portfolio</h3>
          <p class="text-sm text-gray-600">Download your portfolio in various formats</p>
        </div>
        <div class="flex items-center space-x-2">
          <.status_indicator status={@export_status} />
        </div>
      </div>

      <!-- Export Formats -->
      <div class="space-y-4 mb-6">
        <h4 class="font-medium text-gray-900">Choose Export Format</h4>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div :for={{format_key, format_info} <- @available_formats} class={[
            "relative rounded-lg border p-4 cursor-pointer transition-all",
            if(@export_format == format_key, do: "border-blue-500 bg-blue-50", else: "border-gray-200 hover:border-gray-300"),
            if(format_info[:restricted] && !@can_export_docx, do: "opacity-50 cursor-not-allowed", else: "")
          ]}>
            <input
              type="radio"
              name="export_format"
              value={format_key}
              checked={@export_format == format_key}
              disabled={format_info[:restricted] && !@can_export_docx}
              phx-click="select-format"
              phx-value-format={format_key}
              phx-target={@myself}
              class="sr-only"
            />

            <div class="flex items-start space-x-3">
              <div class="flex-shrink-0">
                <.export_icon name={format_info.icon} class="w-6 h-6 text-gray-400" />
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center justify-between">
                  <h5 class="text-sm font-medium text-gray-900">{format_info.name}</h5>
                  <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-800">
                    {format_info.file_type}
                  </span>
                </div>
                <p class="text-sm text-gray-500 mt-1">{format_info.description}</p>
                <div :if={format_info[:restricted] && !@can_export_docx} class="mt-2">
                  <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800">
                    Owner Only
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Export Options -->
      <div :if={@export_format && map_size(@export_options) > 0} class="space-y-4 mb-6">
        <h4 class="font-medium text-gray-900">Export Options</h4>
        <div class="bg-gray-50 rounded-lg p-4 space-y-4">
          <div :for={{option_key, option_value} <- @export_options} class="flex items-center justify-between">
            <label class="text-sm font-medium text-gray-700 capitalize">
              {String.replace(option_key, "_", " ")}
            </label>

            <!-- Boolean Options -->
            <div :if={is_boolean(option_value)} class="flex items-center">
              <input
                type="checkbox"
                checked={option_value}
                phx-click="update-option"
                phx-value-option={option_key}
                phx-value-value={!option_value}
                phx-target={@myself}
                class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
              />
            </div>

            <!-- Select Options -->
            <div :if={option_key in ["font_family", "template_style", "page_orientation"]} class="flex items-center">
              <select
                phx-change="update-option"
                phx-value-option={option_key}
                phx-target={@myself}
                class="block text-sm border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
              >
                <option :for={opt <- get_select_options(option_key)} value={opt} selected={opt == option_value}>
                  {opt}
                </option>
              </select>
            </div>

            <!-- Multi-select for sections -->
            <div :if={option_key == "sections"} class="flex flex-wrap gap-2">
              <div :for={section <- ["contact", "summary", "experience", "education", "skills", "projects"]} class="flex items-center">
                <input
                  type="checkbox"
                  id={"section_#{section}"}
                  checked={section in option_value}
                  phx-click="toggle-section"
                  phx-value-section={section}
                  phx-target={@myself}
                  class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
                <label for={"section_#{section}"} class="ml-1 text-xs text-gray-600 capitalize">
                  {section}
                </label>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Export Actions -->
      <div class="flex items-center justify-between pt-6 border-t border-gray-200">
        <div class="flex items-center space-x-4">
          <div :if={@export_status == :exporting} class="flex items-center text-sm text-gray-600">
            <.spinner class="w-4 h-4 mr-2" />
            Generating export...
          </div>

          <div :if={@export_status == :complete && @download_url} class="flex items-center space-x-2">
            <.export_icon name="check-circle" class="w-5 h-5 text-green-500" />
            <span class="text-sm text-green-600">Export ready!</span>
          </div>
        </div>

        <div class="flex items-center space-x-3">
          <button
            :if={@export_status == :complete}
            phx-click="reset-export"
            phx-target={@myself}
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Export Again
          </button>

          <a
            :if={@export_status == :complete && @download_url}
            href={@download_url}
            download
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-green-600 border border-transparent rounded-md hover:bg-green-700"
          >
            <.export_icon name="arrow-down-tray" class="w-4 h-4 mr-2" />
            Download
          </a>

          <button
            :if={@export_status in [:idle, :error]}
            phx-click="export-portfolio"
            phx-target={@myself}
            disabled={@export_format == :docx_resume && !@can_export_docx}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 disabled:bg-gray-400"
          >
            <.export_icon name="arrow-down-tray" class="w-4 h-4 mr-2" />
            Export Portfolio
          </button>
        </div>
      </div>

      <!-- Export Preview -->
      <div :if={@export_format} class="mt-6 pt-6 border-t border-gray-200">
        <h4 class="font-medium text-gray-900 mb-3">Preview</h4>
        <div class="bg-gray-50 rounded-lg p-4">
          <.export_preview format={@export_format} portfolio={@portfolio} options={@export_options} />
        </div>
      </div>
    </div>
    """
  end

  defp status_indicator(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <div class={[
        "w-2 h-2 rounded-full",
        case @status do
          :idle -> "bg-gray-300"
          :exporting -> "bg-yellow-400 animate-pulse"
          :complete -> "bg-green-400"
          :error -> "bg-red-400"
        end
      ]}></div>
      <span class="text-xs text-gray-500 capitalize">{@status}</span>
    </div>
    """
  end

  defp export_preview(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-gray-700">Export Format:</span>
        <span class="text-sm text-gray-600 capitalize">{String.replace(to_string(@format), "_", " ")}</span>
      </div>

      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-gray-700">Portfolio Title:</span>
        <span class="text-sm text-gray-600">{@portfolio.title || "Untitled Portfolio"}</span>
      </div>

      <div :if={@options["sections"]} class="flex items-center justify-between">
        <span class="text-sm font-medium text-gray-700">Sections:</span>
        <span class="text-sm text-gray-600">{Enum.join(@options["sections"], ", ")}</span>
      </div>

      <div :if={Map.get(@options, "font_family")} class="flex items-center justify-between">
        <span class="text-sm font-medium text-gray-700">Font:</span>
        <span class="text-sm text-gray-600">{@options["font_family"]}</span>
      </div>

      <div class="pt-2 border-t border-gray-200">
        <div class="flex items-center justify-between text-xs text-gray-500">
          <span>Estimated file size:</span>
          <span>{estimate_file_size(@format, @portfolio)}</span>
        </div>
      </div>
    </div>
    """
  end

  defp get_select_options("font_family"), do: ["Arial", "Times New Roman", "Helvetica", "Calibri"]
  defp get_select_options("template_style"), do: ["professional", "modern", "classic", "minimal"]
  defp get_select_options("page_orientation"), do: ["portrait", "landscape"]
  defp get_select_options(_), do: []

  defp estimate_file_size(format, portfolio) do
    case format do
      :ats_resume -> "150-300 KB"
      :full_portfolio -> "500 KB - 2 MB"
      :html_archive -> "200-500 KB"
      :docx_resume -> "100-200 KB"
      _ -> "Unknown"
    end
  end

  # Helper components
  defp spinner(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    """
  end

  defp export_icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
      <%= case @name do %>
        <% "document-text" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5-3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
        <% "document-duplicate" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 01-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75a9.06 9.06 0 011.5.124m7.5 10.376h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 00-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 01-1.125-1.125v-9.25m12 6.625v-1.875a3.375 3.375 0 00-3.375-3.375h-1.5a1.125 1.125 0 01-1.125-1.125v-1.5a3.375 3.375 0 00-3.375-3.375H9.75" />
        <% "code-bracket" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 16.5" />
        <% "document" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
        <% "check-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% "arrow-down-tray" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
        <% _ -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
      <% end %>
    </svg>
    """
  end
end
