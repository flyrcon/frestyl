# lib/frestyl_web/live/portfolio_live/edit/resume_import_modal.ex
defmodule FrestylWeb.PortfolioLive.Edit.ResumeImportModal do
  use FrestylWeb, :live_component
  alias Frestyl.Portfolios
  alias FrestylWeb.PortfolioLive.Edit.ResumeImporter

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:processing, false)
     |> assign(:parsing_stage, :idle)
     |> assign(:parsed_data, nil)
     |> assign(:sections_to_import, %{})
     |> assign(:error_message, nil)
     |> assign(:upload_progress, 0)
     |> allow_upload(:resume_file,
       accept: ~w(.pdf .doc .docx .txt .rtf),
       max_entries: 1,
       max_file_size: 10 * 1024 * 1024
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 backdrop-blur-sm">
      <div class="bg-white rounded-2xl shadow-2xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <!-- Modal Header -->
        <div class="bg-gradient-to-r from-emerald-600 to-green-600 px-8 py-6 rounded-t-2xl">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3">
              <div class="w-12 h-12 bg-white bg-opacity-20 rounded-xl flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              </div>
              <div>
                <h3 class="text-2xl font-bold text-white">Import Resume Data</h3>
                <p class="text-emerald-100">Upload your resume to automatically populate your portfolio</p>
              </div>
            </div>
            <button phx-click="close_modal" phx-target={@myself}
                    class="text-white hover:text-gray-200 transition-colors p-2 hover:bg-white hover:bg-opacity-10 rounded-lg">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Modal Content -->
        <div class="p-8">
          <%= case @parsing_stage do %>
            <% :idle -> %>
              <%= render_upload_section(assigns) %>
            <% :processing -> %>
              <%= render_processing_section(assigns) %>
            <% :parsed -> %>
              <%= render_import_selection_section(assigns) %>
            <% :error -> %>
              <%= render_error_section(assigns) %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_upload_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center">
        <div class="w-20 h-20 bg-emerald-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
          <svg class="w-10 h-10 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
          </svg>
        </div>
        <h3 class="text-xl font-bold text-gray-900 mb-2">Upload Your Resume</h3>
        <p class="text-gray-600 mb-6">Supported formats: PDF, DOC, DOCX, TXT, RTF (Max 10MB)</p>
      </div>

      <form phx-submit="process_resume" phx-target={@myself} phx-change="validate_upload">
        <div class="border-2 border-dashed border-gray-300 rounded-xl p-8 text-center hover:border-emerald-400 transition-colors">
          <.live_file_input upload={@uploads.resume_file} class="sr-only" />

          <label for={@uploads.resume_file.ref} class="cursor-pointer">
            <div class="space-y-4">
              <svg class="w-12 h-12 text-gray-400 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
              </svg>
              <div>
                <p class="text-lg font-medium text-gray-900">Click to upload or drag and drop</p>
                <p class="text-gray-500">PDF, DOC, DOCX, TXT, RTF up to 10MB</p>
              </div>
            </div>
          </label>
        </div>

        <!-- Upload Progress -->
        <%= for entry <- @uploads.resume_file.entries do %>
          <div class="mt-4 p-4 bg-gray-50 rounded-lg">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-gray-900"><%= entry.client_name %></span>
              <button type="button" phx-click="cancel_upload" phx-target={@myself} phx-value-ref={entry.ref}
                      class="text-red-500 hover:text-red-700">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div class="bg-emerald-600 h-2 rounded-full transition-all duration-300"
                   style={"width: #{entry.progress}%"}></div>
            </div>
            <p class="text-xs text-gray-500 mt-1"><%= entry.progress %>% uploaded</p>
          </div>

          <%= for err <- upload_errors(@uploads.resume_file, entry) do %>
            <div class="mt-2 text-sm text-red-600">
              <%= format_upload_error(err) %>
            </div>
          <% end %>
        <% end %>

        <%= if length(@uploads.resume_file.entries) > 0 do %>
          <div class="mt-6 flex justify-end">
            <button type="submit"
                    class="bg-emerald-600 text-white px-6 py-3 rounded-xl font-semibold hover:bg-emerald-700 transition-colors">
              Process Resume
            </button>
          </div>
        <% end %>
      </form>

      <!-- Features Info -->
      <div class="mt-8 bg-blue-50 rounded-xl p-6">
        <h4 class="font-semibold text-blue-900 mb-3">What we'll extract:</h4>
        <div class="grid grid-cols-2 gap-3 text-sm text-blue-800">
          <div class="flex items-center">
            <svg class="w-4 h-4 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            Contact information
          </div>
          <div class="flex items-center">
            <svg class="w-4 h-4 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            Work experience
          </div>
          <div class="flex items-center">
            <svg class="w-4 h-4 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            Education history
          </div>
          <div class="flex items-center">
            <svg class="w-4 h-4 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            Skills & certifications
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_processing_section(assigns) do
    ~H"""
    <div class="text-center space-y-6">
      <div class="w-20 h-20 bg-emerald-100 rounded-2xl flex items-center justify-center mx-auto">
        <svg class="w-10 h-10 text-emerald-600 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
        </svg>
      </div>

      <div>
        <h3 class="text-xl font-bold text-gray-900 mb-2">Processing Your Resume</h3>
        <p class="text-gray-600">Our AI is extracting information from your resume...</p>
      </div>

      <div class="max-w-md mx-auto">
        <div class="w-full bg-gray-200 rounded-full h-3">
          <div class="bg-emerald-600 h-3 rounded-full transition-all duration-500 animate-pulse"
               style={"width: #{@upload_progress}%"}></div>
        </div>
        <p class="text-sm text-gray-500 mt-2">This may take a few moments...</p>
      </div>
    </div>
    """
  end

  defp render_import_selection_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-6">
        <div class="w-16 h-16 bg-green-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
          </svg>
        </div>
        <h3 class="text-xl font-bold text-gray-900 mb-2">Resume Processed Successfully!</h3>
        <p class="text-gray-600">Select which sections to import to your portfolio</p>
      </div>

      <form phx-submit="import_selected_sections" phx-target={@myself}>
        <div class="space-y-4">
          <!-- Personal Information -->
          <%= if Map.get(@parsed_data, :personal_info) do %>
            <div class="border border-gray-200 rounded-xl p-6">
              <label class="flex items-start space-x-3 cursor-pointer">
                <input type="checkbox" name="sections[]" value="personal_info" checked
                       class="mt-1 h-4 w-4 text-emerald-600 rounded border-gray-300 focus:ring-emerald-500" />
                <div class="flex-1">
                  <h4 class="font-semibold text-gray-900 mb-2">📧 Contact Information</h4>
                  <div class="grid grid-cols-2 gap-4 text-sm text-gray-600">
                    <div>Name: <%= get_in(@parsed_data, [:personal_info, "name"]) || "Not found" %></div>
                    <div>Email: <%= get_in(@parsed_data, [:personal_info, "email"]) || "Not found" %></div>
                    <div>Phone: <%= get_in(@parsed_data, [:personal_info, "phone"]) || "Not found" %></div>
                    <div>Location: <%= get_in(@parsed_data, [:personal_info, "location"]) || "Not found" %></div>
                  </div>
                </div>
              </label>
            </div>
          <% end %>

          <!-- Work Experience -->
          <%= if length(Map.get(@parsed_data, :work_experience, [])) > 0 do %>
            <div class="border border-gray-200 rounded-xl p-6">
              <label class="flex items-start space-x-3 cursor-pointer">
                <input type="checkbox" name="sections[]" value="work_experience" checked
                       class="mt-1 h-4 w-4 text-emerald-600 rounded border-gray-300 focus:ring-emerald-500" />
                <div class="flex-1">
                  <h4 class="font-semibold text-gray-900 mb-2">💼 Work Experience (<%= length(@parsed_data.work_experience) %> positions)</h4>
                  <div class="space-y-2">
                    <%= for job <- Enum.take(@parsed_data.work_experience, 3) do %>
                      <div class="text-sm text-gray-600">
                        <span class="font-medium"><%= Map.get(job, "title", "Position") %></span> at
                        <span class="font-medium"><%= Map.get(job, "company", "Company") %></span>
                        <%= if Map.get(job, "start_date") do %>
                          (<%= Map.get(job, "start_date") %> - <%= if Map.get(job, "current"), do: "Present", else: Map.get(job, "end_date", "?") %>)
                        <% end %>
                      </div>
                    <% end %>
                    <%= if length(@parsed_data.work_experience) > 3 do %>
                      <div class="text-sm text-gray-500">And <%= length(@parsed_data.work_experience) - 3 %> more positions...</div>
                    <% end %>
                  </div>
                </div>
              </label>
            </div>
          <% end %>

          <!-- Education -->
          <%= if length(Map.get(@parsed_data, :education, [])) > 0 do %>
            <div class="border border-gray-200 rounded-xl p-6">
              <label class="flex items-start space-x-3 cursor-pointer">
                <input type="checkbox" name="sections[]" value="education" checked
                       class="mt-1 h-4 w-4 text-emerald-600 rounded border-gray-300 focus:ring-emerald-500" />
                <div class="flex-1">
                  <h4 class="font-semibold text-gray-900 mb-2">🎓 Education (<%= length(@parsed_data.education) %> entries)</h4>
                  <div class="space-y-2">
                    <%= for edu <- @parsed_data.education do %>
                      <div class="text-sm text-gray-600">
                        <span class="font-medium"><%= Map.get(edu, "degree", "Degree") %></span>
                        <%= if Map.get(edu, "field") do %>in <%= Map.get(edu, "field") %><% end %>
                        <%= if Map.get(edu, "institution") do %>from <%= Map.get(edu, "institution") %><% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </label>
            </div>
          <% end %>

          <!-- Skills -->
          <%= if length(Map.get(@parsed_data, :skills, [])) > 0 do %>
            <div class="border border-gray-200 rounded-xl p-6">
              <label class="flex items-start space-x-3 cursor-pointer">
                <input type="checkbox" name="sections[]" value="skills" checked
                       class="mt-1 h-4 w-4 text-emerald-600 rounded border-gray-300 focus:ring-emerald-500" />
                <div class="flex-1">
                  <h4 class="font-semibold text-gray-900 mb-2">⚡ Skills (<%= length(@parsed_data.skills) %> skills)</h4>
                  <div class="flex flex-wrap gap-1">
                    <%= for skill <- Enum.take(@parsed_data.skills, 10) do %>
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs bg-blue-100 text-blue-800">
                        <%= get_skill_name(skill) %>
                      </span>
                    <% end %>
                    <%= if length(@parsed_data.skills) > 10 do %>
                      <span class="text-xs text-gray-500">+<%= length(@parsed_data.skills) - 10 %> more</span>
                    <% end %>
                  </div>
                </div>
              </label>
            </div>
          <% end %>

          <!-- Projects -->
          <%= if length(Map.get(@parsed_data, :projects, [])) > 0 do %>
            <div class="border border-gray-200 rounded-xl p-6">
              <label class="flex items-start space-x-3 cursor-pointer">
                <input type="checkbox" name="sections[]" value="projects"
                       class="mt-1 h-4 w-4 text-emerald-600 rounded border-gray-300 focus:ring-emerald-500" />
                <div class="flex-1">
                  <h4 class="font-semibold text-gray-900 mb-2">🚀 Projects (<%= length(@parsed_data.projects) %> projects)</h4>
                  <div class="space-y-2">
                    <%= for project <- Enum.take(@parsed_data.projects, 3) do %>
                      <div class="text-sm text-gray-600">
                        <span class="font-medium"><%= Map.get(project, "title", "Project") %></span>
                        <%= if Map.get(project, "description") do %>
                          - <%= String.slice(Map.get(project, "description"), 0, 80) %>...
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </label>
            </div>
          <% end %>

          <!-- Certifications -->
          <%= if length(Map.get(@parsed_data, :certifications, [])) > 0 do %>
            <div class="border border-gray-200 rounded-xl p-6">
              <label class="flex items-start space-x-3 cursor-pointer">
                <input type="checkbox" name="sections[]" value="certifications"
                       class="mt-1 h-4 w-4 text-emerald-600 rounded border-gray-300 focus:ring-emerald-500" />
                <div class="flex-1">
                  <h4 class="font-semibold text-gray-900 mb-2">🏆 Certifications (<%= length(@parsed_data.certifications) %> items)</h4>
                  <div class="space-y-2">
                    <%= for cert <- @parsed_data.certifications do %>
                      <div class="text-sm text-gray-600">
                        <span class="font-medium"><%= Map.get(cert, "title", Map.get(cert, "name", "Certification")) %></span>
                        <%= if Map.get(cert, "provider") do %>by <%= Map.get(cert, "provider") %><% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </label>
            </div>
          <% end %>
        </div>

        <div class="mt-8 flex justify-between">
          <button type="button" phx-click="start_over" phx-target={@myself}
                  class="px-6 py-3 border border-gray-300 rounded-xl font-semibold text-gray-700 hover:bg-gray-50 transition-colors">
            Upload Different Resume
          </button>
          <button type="submit"
                  class="bg-emerald-600 text-white px-8 py-3 rounded-xl font-semibold hover:bg-emerald-700 transition-colors">
            Import Selected Sections
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp render_error_section(assigns) do
    ~H"""
    <div class="text-center space-y-6">
      <div class="w-20 h-20 bg-red-100 rounded-2xl flex items-center justify-center mx-auto">
        <svg class="w-10 h-10 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.232 15.5c-.77.833.192 2.5 1.732 2.5z"/>
        </svg>
      </div>

      <div>
        <h3 class="text-xl font-bold text-gray-900 mb-2">Processing Failed</h3>
        <p class="text-gray-600 mb-4">We encountered an error while processing your resume.</p>
        <div class="bg-red-50 border border-red-200 rounded-lg p-4">
          <p class="text-sm text-red-800"><%= @error_message %></p>
        </div>
      </div>

      <div class="space-y-3">
        <button phx-click="start_over" phx-target={@myself}
                class="w-full bg-emerald-600 text-white px-6 py-3 rounded-xl font-semibold hover:bg-emerald-700 transition-colors">
          Try Again
        </button>
        <button phx-click="close_modal" phx-target={@myself}
                class="w-full border border-gray-300 px-6 py-3 rounded-xl font-semibold text-gray-700 hover:bg-gray-50 transition-colors">
          Close
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :resume_file, ref)}
  end

  @impl true
  def handle_event("process_resume", _params, socket) do
    case consume_uploaded_entries(socket, :resume_file, &process_file/2) do
      [result] ->
        case result do
          {:ok, parsed_data} ->
            {:noreply,
             socket
             |> assign(:parsing_stage, :parsed)
             |> assign(:parsed_data, parsed_data)
             |> assign(:sections_to_import, initialize_section_selections(parsed_data))}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:parsing_stage, :error)
             |> assign(:error_message, reason)}
        end

      [] ->
        {:noreply,
         socket
         |> assign(:parsing_stage, :error)
         |> assign(:error_message, "No file was uploaded")}
    end
  end

  @impl true
  def handle_event("import_selected_sections", params, socket) do
    selected_sections = Map.get(params, "sections", [])

    case ResumeImporter.import_sections_to_portfolio(
           socket.assigns.portfolio,
           socket.assigns.parsed_data,
           selected_sections
         ) do
      {:ok, result} ->
        send(self(), {:resume_import_complete, result})
        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:parsing_stage, :error)
         |> assign(:error_message, reason)}
    end
  end

  @impl true
  def handle_event("start_over", _params, socket) do
    {:noreply,
     socket
     |> assign(:parsing_stage, :idle)
     |> assign(:parsed_data, nil)
     |> assign(:error_message, nil)
     |> assign(:upload_progress, 0)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    send(self(), :close_resume_import_modal)
    {:noreply, socket}
  end

  defp process_file(%{path: path}, %{client_name: filename}) do
    ResumeImporter.process_uploaded_file(path, filename)
  end

  defp initialize_section_selections(parsed_data) do
    %{
      "personal_info" => true,
      "work_experience" => length(Map.get(parsed_data, :work_experience, [])) > 0,
      "education" => length(Map.get(parsed_data, :education, [])) > 0,
      "skills" => length(Map.get(parsed_data, :skills, [])) > 0,
      "projects" => length(Map.get(parsed_data, :projects, [])) > 0,
      "certifications" => length(Map.get(parsed_data, :certifications, [])) > 0
    }
  end

  defp get_skill_name(skill) when is_binary(skill), do: skill
  defp get_skill_name(%{"name" => name}), do: name
  defp get_skill_name(_), do: "Unknown Skill"

  defp format_upload_error(:too_large), do: "File is too large (max 10MB)"
  defp format_upload_error(:too_many_files), do: "Only one file allowed"
  defp format_upload_error(:not_accepted), do: "File type not supported"
  defp format_upload_error(error), do: "Upload error: #{inspect(error)}"
end
