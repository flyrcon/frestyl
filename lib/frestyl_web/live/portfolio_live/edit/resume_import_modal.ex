# lib/frestyl_web/live/portfolio_live/edit/resume_import_modal.ex - FIXED VERSION
defmodule FrestylWeb.PortfolioLive.Edit.ResumeImportModal do
  use FrestylWeb, :live_component
  alias Frestyl.Portfolios
  alias FrestylWeb.PortfolioLive.Edit.ResumeImporter

  require Logger

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
     |> assign(:parsing_progress, 0)
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
      <div class="bg-white rounded-2xl shadow-2xl max-w-2xl w-full mx-4 max-h-[85vh] overflow-y-auto">
        <!-- Compact Header -->
        <div class="bg-gradient-to-r from-emerald-600 to-green-600 px-6 py-4 rounded-t-2xl">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3">
              <div class="w-10 h-10 bg-white bg-opacity-20 rounded-xl flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              </div>
              <div>
                <h3 class="text-xl font-bold text-white">Smart Resume Import</h3>
                <p class="text-emerald-100 text-sm">AI-powered skills detection & categorization</p>
              </div>
            </div>
            <button phx-click="close_modal" phx-target={@myself}
                    class="text-white hover:text-gray-200 transition-colors p-2 hover:bg-white hover:bg-opacity-10 rounded-lg">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Compact Content -->
        <div class="p-6">
          <%= case @parsing_stage do %>
            <% :idle -> %>
              <%= render_compact_upload_section(assigns) %>
            <% :processing -> %>
              <%= render_compact_processing_section(assigns) %>
            <% :parsed -> %>
              <%= render_compact_import_selection_section(assigns) %>
            <% :error -> %>
              <%= render_compact_error_section(assigns) %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_compact_upload_section(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Quick Features Preview -->
      <div class="grid grid-cols-3 gap-3 mb-4">
        <div class="text-center">
          <div class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-1">
            <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
            </svg>
          </div>
          <p class="text-xs font-medium text-blue-900">Smart Skills</p>
          <p class="text-xs text-blue-600">Auto-categorization</p>
        </div>

        <div class="text-center">
          <div class="w-8 h-8 bg-purple-100 rounded-lg flex items-center justify-center mx-auto mb-1">
            <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
          </div>
          <p class="text-xs font-medium text-purple-900">Years Calc</p>
          <p class="text-xs text-purple-600">From work history</p>
        </div>

        <div class="text-center">
          <div class="w-8 h-8 bg-green-100 rounded-lg flex items-center justify-center mx-auto mb-1">
            <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17v4a2 2 0 002 2h4M15 7l3 3"/>
            </svg>
          </div>
          <p class="text-xs font-medium text-green-900">Color Coded</p>
          <p class="text-xs text-green-600">Visual proficiency</p>
        </div>
      </div>

      <.form for={%{}} phx-submit="process_resume" phx-change="validate_upload" phx-target={@myself}>
        <div class="border-2 border-dashed border-gray-300 rounded-xl p-6 text-center hover:border-emerald-400 transition-colors">
          <.live_file_input upload={@uploads.resume_file} class="sr-only" />

          <label for={@uploads.resume_file.ref} class="cursor-pointer">
            <div class="space-y-3">
              <svg class="w-10 h-10 text-gray-400 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
              </svg>
              <div>
                <p class="font-semibold text-gray-900">Drop your resume here</p>
                <p class="text-sm text-gray-500">or click to browse</p>
                <p class="text-xs text-gray-400 mt-1">PDF, DOC, DOCX, TXT, RTF (Max 10MB)</p>
              </div>
            </div>
          </label>

          <%= for entry <- @uploads.resume_file.entries do %>
            <div class="mt-3 p-3 bg-gray-50 rounded-lg">
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-2">
                  <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  <div class="text-left">
                    <p class="text-sm font-medium text-gray-900"><%= entry.client_name %></p>
                    <p class="text-xs text-gray-500"><%= format_file_size(entry.client_size) %></p>
                  </div>
                </div>
                <button type="button" phx-click="cancel_upload" phx-target={@myself} phx-value-ref={entry.ref}
                        class="text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>

              <%= for err <- upload_errors(@uploads.resume_file, entry) do %>
                <p class="mt-1 text-xs text-red-600"><%= format_upload_error(err) %></p>
              <% end %>
            </div>
          <% end %>

          <%= for err <- upload_errors(@uploads.resume_file) do %>
            <p class="mt-2 text-sm text-red-600"><%= format_upload_error(err) %></p>
          <% end %>
        </div>

        <%= if length(@uploads.resume_file.entries) > 0 do %>
          <div class="mt-4">
            <button type="submit"
                    class="w-full bg-emerald-600 text-white px-6 py-3 rounded-xl font-semibold hover:bg-emerald-700 transition-colors flex items-center justify-center space-x-2">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
              </svg>
              <span>Process Resume with AI</span>
            </button>
          </div>
        <% end %>
      </.form>
    </div>
    """
  end

  defp render_compact_processing_section(assigns) do
    ~H"""
    <div class="text-center space-y-4">
      <div class="w-16 h-16 bg-blue-100 rounded-2xl flex items-center justify-center mx-auto">
        <svg class="w-8 h-8 text-blue-600 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
        </svg>
      </div>

      <div>
        <h3 class="text-lg font-bold text-gray-900 mb-1">AI Processing Resume</h3>
        <p class="text-sm text-gray-600">Extracting skills, proficiency levels, and experience...</p>
      </div>

      <!-- Compact Processing Steps -->
      <div class="space-y-2">
        <div class="flex items-center justify-center space-x-2 text-sm">
          <div class="w-4 h-4 bg-green-500 rounded-full flex items-center justify-center">
            <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
          </div>
          <span class="text-gray-700">Text extraction</span>
        </div>

        <div class="flex items-center justify-center space-x-2 text-sm">
          <div class="w-4 h-4 bg-blue-500 rounded-full flex items-center justify-center animate-pulse">
            <div class="w-1 h-1 bg-white rounded-full"></div>
          </div>
          <span class="text-gray-700">Skills & proficiency analysis</span>
        </div>

        <div class="flex items-center justify-center space-x-2 text-sm">
          <div class="w-4 h-4 bg-gray-300 rounded-full flex items-center justify-center">
            <div class="w-1 h-1 bg-gray-500 rounded-full"></div>
          </div>
          <span class="text-gray-500">Section organization</span>
        </div>
      </div>

      <div class="w-full bg-gray-200 rounded-full h-2">
        <div class="bg-gradient-to-r from-blue-600 to-emerald-600 h-2 rounded-full transition-all duration-300" style={"width: #{@parsing_progress}%"}></div>
      </div>

      <p class="text-xs text-gray-500">Usually takes 10-30 seconds</p>
    </div>
    """
  end

  defp render_compact_import_selection_section(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="text-center">
        <div class="w-16 h-16 bg-green-100 rounded-2xl flex items-center justify-center mx-auto mb-3">
          <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
        </div>
        <h3 class="text-lg font-bold text-gray-900 mb-1">Resume Processed Successfully!</h3>
        <p class="text-sm text-gray-600 mb-4">Select sections to import to your portfolio</p>
      </div>

      <.form for={%{}} phx-submit="import_selected_sections" phx-target={@myself}>
        <div class="space-y-3 mb-4">
          <%= for {section_key, should_import} <- @sections_to_import do %>
            <div class="border border-gray-200 rounded-lg p-3 hover:border-emerald-300 transition-colors">
              <label class="flex items-start space-x-3 cursor-pointer">
                <input type="checkbox"
                       name={"sections[#{section_key}]"}
                       value="true"
                       checked={should_import}
                       class="mt-1 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500">

                <div class="flex-1 min-w-0">
                  <div class="flex items-center space-x-2 mb-1">
                    <h4 class="font-medium text-gray-900 text-sm">
                      <%= format_section_title(section_key) %>
                    </h4>
                    <%= render_compact_section_badge(section_key) %>
                  </div>

                  <p class="text-xs text-gray-600 mb-2">
                    <%= get_compact_section_description(section_key, @parsed_data) %>
                  </p>

                  <!-- Compact Previews -->
                  <%= if section_key == "skills" do %>
                    <%= render_compact_skills_preview(@parsed_data) %>
                  <% end %>

                  <%= if section_key == "work_experience" do %>
                    <%= render_compact_experience_preview(@parsed_data) %>
                  <% end %>
                </div>
              </label>
            </div>
          <% end %>
        </div>

        <!-- Compact Actions -->
        <div class="flex space-x-2">
          <button type="submit"
                  class="flex-1 bg-emerald-600 text-white px-4 py-3 rounded-xl font-semibold hover:bg-emerald-700 transition-colors flex items-center justify-center space-x-2">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/>
            </svg>
            <span>Import Selected</span>
          </button>
          <button type="button" phx-click="start_over" phx-target={@myself}
                  class="px-4 py-3 border border-gray-300 rounded-xl font-semibold text-gray-700 hover:bg-gray-50 transition-colors">
            Retry
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp render_compact_error_section(assigns) do
    ~H"""
    <div class="text-center space-y-4">
      <div class="w-16 h-16 bg-red-100 rounded-2xl flex items-center justify-center mx-auto">
        <svg class="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.232 15.5c-.77.833.192 2.5 1.732 2.5z"/>
        </svg>
      </div>

      <div>
        <h3 class="text-lg font-bold text-gray-900 mb-1">Processing Failed</h3>
        <p class="text-sm text-gray-600 mb-3">We encountered an error while processing your resume.</p>
        <div class="bg-red-50 border border-red-200 rounded-lg p-3">
          <p class="text-sm text-red-800"><%= @error_message %></p>
        </div>
      </div>

      <div class="flex space-x-2">
        <button phx-click="start_over" phx-target={@myself}
                class="flex-1 bg-emerald-600 text-white px-4 py-3 rounded-xl font-semibold hover:bg-emerald-700 transition-colors">
          Try Again
        </button>
        <button phx-click="close_modal" phx-target={@myself}
                class="flex-1 border border-gray-300 px-4 py-3 rounded-xl font-semibold text-gray-700 hover:bg-gray-50 transition-colors">
          Close
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # EVENT HANDLERS - FIXED LOGIC
  # ============================================================================

  @impl true
  def handle_event("validate_upload", _params, socket) do
    # Just validate, don't auto-process
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :resume_file, ref)}
  end

  @impl true
  def handle_event("process_resume", _params, socket) do
    Logger.info("🔍 MODAL: process_resume event triggered")

    # Update to processing stage immediately
    socket = socket
    |> assign(:parsing_stage, :processing)
    |> assign(:parsing_progress, 0)

    # Get component ID for progress updates
    component_id = socket.assigns.id

    # Process uploaded files synchronously within the callback
    case consume_uploaded_entries(socket, :resume_file, fn %{path: path}, entry ->
      Logger.info("🔍 MODAL: Processing file synchronously: #{entry.client_name}")

      # Update progress
      send_update(__MODULE__, id: component_id, parsing_progress: 25)

      # Do the actual processing RIGHT NOW while file exists
      Logger.info("🔍 MODAL: Calling ResumeImporter.process_uploaded_file synchronously")
      case ResumeImporter.process_uploaded_file(path, entry.client_name) do
        {:ok, parsed_data} ->
          Logger.info("🔍 MODAL: Processing successful!")

          # Update progress
          send_update(__MODULE__, id: component_id, parsing_progress: 75)

          # Initialize sections
          sections_to_import = initialize_section_selections(parsed_data)

          # Final update - switch to parsed state
          send_update(__MODULE__,
            id: component_id,
            parsing_stage: :parsed,
            parsed_data: parsed_data,
            sections_to_import: sections_to_import,
            parsing_progress: 100
          )

          # Return success for consume_uploaded_entries
          {:ok, parsed_data}

        {:error, reason} ->
          Logger.error("🔍 MODAL: Processing failed: #{reason}")

          # Update to error state
          send_update(__MODULE__,
            id: component_id,
            parsing_stage: :error,
            error_message: reason
          )

          # Return error for consume_uploaded_entries
          {:error, reason}
      end
    end) do
      [result] ->
        Logger.info("🔍 MODAL: File processing completed: #{inspect(result)}")
        {:noreply, socket}

      [] ->
        {:noreply,
        socket
        |> assign(:parsing_stage, :error)
        |> assign(:error_message, "No file was uploaded")}

      results when is_list(results) ->
        Logger.info("🔍 MODAL: Multiple files processed: #{inspect(results)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("import_selected_sections", params, socket) do
    Logger.info("🔍 MODAL: import_selected_sections called")

    section_mappings = extract_section_mappings(params)
    merge_options = %{} # Default merge options

    case ResumeImporter.import_sections_to_portfolio(
           socket.assigns.portfolio,
           socket.assigns.parsed_data,
           section_mappings,
           merge_options
         ) do
      {:ok, result} ->
        Logger.info("🔍 MODAL: Import successful!")
        send(self(), {:resume_import_complete, result})
        {:noreply, socket}

      {:error, reason} ->
        Logger.error("🔍 MODAL: Import failed: #{inspect(reason)}")
        {:noreply,
         socket
         |> assign(:parsing_stage, :error)
         |> assign(:error_message, "Import failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("start_over", _params, socket) do
    {:noreply,
     socket
     |> assign(:parsing_stage, :idle)
     |> assign(:parsed_data, nil)
     |> assign(:error_message, nil)
     |> assign(:upload_progress, 0)
     |> assign(:parsing_progress, 0)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    send(self(), :close_resume_import_modal)
    {:noreply, socket}
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp extract_section_mappings(params) do
    case Map.get(params, "sections") do
      sections when is_map(sections) -> sections
      _ -> %{}
    end
  end

  defp initialize_section_selections(parsed_data) do
    %{
      "personal_info" => true,
      "professional_summary" => has_content?(get_parsed_field(parsed_data, :professional_summary)),
      "work_experience" => has_content?(get_parsed_field(parsed_data, :work_experience)),
      "education" => has_content?(get_parsed_field(parsed_data, :education)),
      "skills" => has_content?(get_parsed_field(parsed_data, :skills)),
      "projects" => has_content?(get_parsed_field(parsed_data, :projects)),
      "certifications" => has_content?(get_parsed_field(parsed_data, :certifications))
    }
  end

  # Keep all your existing helper functions for rendering previews, etc.
  # (render_compact_skills_preview, render_compact_experience_preview, etc.)

  # ... [All your existing helper functions remain the same] ...

  defp render_compact_skills_preview(parsed_data) do
    skills = get_parsed_field(parsed_data, :skills) || []
    assigns = %{skills: skills}

    ~H"""
    <div class="bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg p-2 mt-2">
      <div class="flex flex-wrap gap-1 mb-2">
        <%= for skill <- Enum.take(@skills, 6) do %>
          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 border border-blue-200">
            <%= get_skill_name(skill) %>
            <%= if get_skill_proficiency(skill) do %>
              <span class={"ml-1 w-1.5 h-1.5 rounded-full #{proficiency_dot_color(get_skill_proficiency(skill))}"}></span>
            <% end %>
          </span>
        <% end %>

        <%= if length(@skills) > 6 do %>
          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600">
            +<%= length(@skills) - 6 %>
          </span>
        <% end %>
      </div>

      <div class="text-xs text-blue-700 bg-blue-100 rounded px-2 py-1">
        <strong>Enhanced:</strong> Auto-categorization, proficiency detection, years calculation
      </div>
    </div>
    """
  end

  defp render_compact_experience_preview(parsed_data) do
    experience = get_parsed_field(parsed_data, :work_experience) || []
    assigns = %{experience: experience}

    ~H"""
    <%= if length(@experience) > 0 do %>
      <div class="bg-gray-50 rounded-lg p-2 mt-2">
        <%= for job <- Enum.take(@experience, 2) do %>
          <div class="text-xs mb-1 last:mb-0">
            <span class="font-medium text-gray-900"><%= Map.get(job, "title", "Position") %></span>
            <span class="text-gray-500">at</span>
            <span class="text-gray-700"><%= Map.get(job, "company", "Company") %></span>
          </div>
        <% end %>

        <%= if length(@experience) > 2 do %>
          <p class="text-xs text-gray-500 mt-1">+<%= length(@experience) - 2 %> more</p>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp render_compact_section_badge(section_key) do
    assigns = %{section_key: section_key}

    ~H"""
    <%= case @section_key do %>
      <% "skills" -> %>
        <span class="px-2 py-0.5 bg-blue-100 text-blue-800 text-xs font-medium rounded-full">AI Enhanced</span>
      <% "work_experience" -> %>
        <span class="px-2 py-0.5 bg-purple-100 text-purple-800 text-xs font-medium rounded-full">Experience</span>
      <% "education" -> %>
        <span class="px-2 py-0.5 bg-green-100 text-green-800 text-xs font-medium rounded-full">Education</span>
      <% _ -> %>
        <span class="px-2 py-0.5 bg-gray-100 text-gray-600 text-xs font-medium rounded-full">Standard</span>
    <% end %>
    """
  end

  defp has_content?(list) when is_list(list), do: length(list) > 0
  defp has_content?(value) when is_binary(value), do: String.trim(value) != ""
  defp has_content?(value) when is_map(value), do: map_size(value) > 0
  defp has_content?(nil), do: false
  defp has_content?(_), do: true

  defp get_parsed_field(parsed_data, field) when is_map(parsed_data) do
    case Map.get(parsed_data, field) do
      nil ->
        atom_key = if is_binary(field), do: String.to_atom(field), else: field
        Map.get(parsed_data, atom_key)
      value ->
        value
    end
  rescue
    _ -> nil
  end
  defp get_parsed_field(_, _), do: nil

  defp get_compact_section_description(section_key, parsed_data) do
    try do
      case section_key do
        "personal_info" -> "Contact info and basic details"
        "professional_summary" -> "Professional summary/objective"
        "work_experience" ->
          items = get_parsed_field(parsed_data, :work_experience) || []
          count = length(items)
          "#{count} job #{if count == 1, do: "entry", else: "entries"}"
        "education" ->
          items = get_parsed_field(parsed_data, :education) || []
          count = length(items)
          "#{count} education #{if count == 1, do: "entry", else: "entries"}"
        "skills" ->
          items = get_parsed_field(parsed_data, :skills) || []
          count = length(items)
          "#{count} skills with AI-detected proficiency"
        "projects" ->
          items = get_parsed_field(parsed_data, :projects) || []
          count = length(items)
          "#{count} project#{if count == 1, do: "", else: "s"}"
        "certifications" ->
          items = get_parsed_field(parsed_data, :certifications) || []
          count = length(items)
          "#{count} certification#{if count == 1, do: "", else: "s"}"
        _ ->
          "Additional information available"
      end
    rescue
      _ -> "Information available"
    end
  end

  defp get_skill_name(skill) when is_binary(skill), do: skill
  defp get_skill_name(%{"name" => name}) when is_binary(name), do: name
  defp get_skill_name(%{name: name}) when is_binary(name), do: name
  defp get_skill_name(_), do: "Unknown Skill"

  defp get_skill_proficiency(skill) do
    case skill do
      %{"proficiency" => prof} when is_binary(prof) -> prof
      %{proficiency: prof} when is_binary(prof) -> prof
      _ -> nil
    end
  end

  defp proficiency_dot_color(proficiency) do
    case String.downcase(proficiency || "") do
      "expert" -> "bg-green-500"
      "advanced" -> "bg-blue-500"
      "intermediate" -> "bg-yellow-500"
      "beginner" -> "bg-gray-400"
      _ -> "bg-gray-400"
    end
  end

  defp format_section_title(section_key) do
    section_key
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      bytes < 1024 * 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024), 1)} MB"
      true -> "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
    end
  end
  defp format_file_size(_), do: "Unknown size"

  defp format_upload_error(:too_large), do: "File is too large (max 10MB)"
  defp format_upload_error(:too_many_files), do: "Only one file allowed"
  defp format_upload_error(:not_accepted), do: "File type not supported"
  defp format_upload_error(error), do: "Upload error: #{inspect(error)}"
end
