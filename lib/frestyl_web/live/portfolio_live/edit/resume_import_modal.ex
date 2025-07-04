# lib/frestyl_web/live/portfolio_live/edit/resume_import_modal.ex
defmodule FrestylWeb.PortfolioLive.Edit.ResumeImportModal do
  use FrestylWeb, :live_component
  alias Frestyl.ResumeParser
  alias Frestyl.Portfolios

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> assign(:parsed_content, nil)
     |> assign(:section_mapping, %{})
     |> assign(:parsing_status, :idle)
     |> assign(:import_step, :upload)
     |> assign(:validation_errors, [])
     |> assign(:preview_sections, %{})
     |> allow_upload(:resume,
       accept: ~w(.pdf .docx .txt .rtf),
       max_entries: 1,
       max_file_size: 10_000_000,
       progress: &handle_progress/3,
       auto_upload: true
     )}
  end

  @impl true
  def update(%{portfolio: portfolio} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:portfolio, portfolio)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :resume, ref)}
  end

  @impl true
  def handle_event("parse-resume", _params, socket) do
    socket =
      consume_uploaded_entries(socket, :resume, fn %{path: path}, entry ->
        case ResumeParser.parse_file(path, entry.client_name) do
          {:ok, parsed_data} ->
            {:ok, parsed_data}
          {:error, reason} ->
            {:error, reason}
        end
      end)
      |> case do
        [parsed_data] when is_map(parsed_data) ->
          socket
          |> assign(:parsed_content, parsed_data)
          |> assign(:import_step, :mapping)
          |> assign(:parsing_status, :success)
          |> generate_section_preview()

        [error: reason] ->
          socket
          |> assign(:parsing_status, :error)
          |> put_flash(:error, "Failed to parse resume: #{reason}")

        [] ->
          socket
          |> assign(:parsing_status, :error)
          |> put_flash(:error, "No file was uploaded")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update-section-mapping", %{"section" => section, "content" => content}, socket) do
    section_mapping = Map.put(socket.assigns.section_mapping, section, content)

    {:noreply,
     socket
     |> assign(:section_mapping, section_mapping)
     |> update_preview_sections()}
  end

  @impl true
  def handle_event("import-sections", _params, socket) do
    %{portfolio: portfolio, section_mapping: section_mapping} = socket.assigns

    case import_sections_to_portfolio(portfolio, section_mapping) do
      {:ok, updated_portfolio} ->
        # Broadcast update via PubSub for real-time sync
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "portfolio:#{portfolio.id}",
          {:portfolio_updated, updated_portfolio}
        )

        send(self(), {:close_modal, :resume_import})

        {:noreply,
         socket
         |> put_flash(:info, "Resume sections imported successfully!")
         |> assign(:import_step, :complete)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Import failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("reset-import", _params, socket) do
    {:noreply,
     socket
     |> assign(:import_step, :upload)
     |> assign(:parsed_content, nil)
     |> assign(:section_mapping, %{})
     |> assign(:parsing_status, :idle)
     |> assign(:preview_sections, %{})}
  end

  defp handle_progress(:resume, entry, socket) do
    if entry.done? do
      {:noreply,
       socket
       |> assign(:parsing_status, :parsing)
       |> put_flash(:info, "File uploaded successfully. Click 'Parse Resume' to continue.")}
    else
      {:noreply, socket}
    end
  end

  defp generate_section_preview(socket) do
    %{parsed_content: content} = socket.assigns

    preview_sections = %{
      "contact" => extract_contact_preview(content),
      "summary" => extract_summary_preview(content),
      "experience" => extract_experience_preview(content),
      "education" => extract_education_preview(content),
      "skills" => extract_skills_preview(content)
    }

    assign(socket, :preview_sections, preview_sections)
  end

  defp update_preview_sections(socket) do
    %{section_mapping: mapping} = socket.assigns

    preview_sections =
      mapping
      |> Enum.map(fn {section, content} ->
        {section, String.slice(content, 0, 200) <> if(String.length(content) > 200, do: "...", else: "")}
      end)
      |> Enum.into(%{})

    assign(socket, :preview_sections, preview_sections)
  end

  defp extract_contact_preview(%{contact: contact}), do: format_contact_info(contact)
  defp extract_contact_preview(_), do: "No contact information detected"

  defp extract_summary_preview(%{summary: summary}) when is_binary(summary) do
    String.slice(summary, 0, 150) <> if(String.length(summary) > 150, do: "...", else: "")
  end
  defp extract_summary_preview(_), do: "No summary detected"

  defp extract_experience_preview(%{experience: experiences}) when is_list(experiences) do
    experiences
    |> Enum.take(2)
    |> Enum.map_join("\n", fn exp -> "• #{exp.title} at #{exp.company}" end)
  end
  defp extract_experience_preview(_), do: "No experience detected"

  defp extract_education_preview(%{education: education}) when is_list(education) do
    education
    |> Enum.take(2)
    |> Enum.map_join("\n", fn edu -> "• #{edu.degree} from #{edu.institution}" end)
  end
  defp extract_education_preview(_), do: "No education detected"

  defp extract_skills_preview(%{skills: skills}) when is_list(skills) do
    skills |> Enum.take(10) |> Enum.join(", ")
  end
  defp extract_skills_preview(_), do: "No skills detected"

  defp format_contact_info(%{email: email, phone: phone, name: name}) do
    [name, email, phone] |> Enum.reject(&is_nil/1) |> Enum.join(" | ")
  end
  defp format_contact_info(contact) when is_map(contact) do
    contact |> Map.values() |> Enum.reject(&is_nil/1) |> Enum.join(" | ")
  end
  defp format_contact_info(_), do: "Contact info available"

  defp import_sections_to_portfolio(portfolio, section_mapping) do
    sections_to_update =
      section_mapping
      |> Enum.map(fn {section_type, content} ->
        case section_type do
          "contact" -> update_contact_section(portfolio, content)
          "summary" -> update_summary_section(portfolio, content)
          "experience" -> update_experience_section(portfolio, content)
          "education" -> update_education_section(portfolio, content)
          "skills" -> update_skills_section(portfolio, content)
          _ -> {:ok, nil}
        end
      end)
      |> Enum.filter(fn {status, _} -> status == :ok end)

    if length(sections_to_update) > 0 do
      Portfolios.update_portfolio(portfolio, %{last_updated: DateTime.utc_now()})
    else
      {:error, "No valid sections to import"}
    end
  end

  defp update_contact_section(portfolio, content) do
    # Implementation depends on your portfolio schema
    # This is a placeholder for the actual contact update logic
    {:ok, content}
  end

  defp update_summary_section(portfolio, content) do
    # Implementation depends on your portfolio schema
    {:ok, content}
  end

  defp update_experience_section(portfolio, content) do
    # Implementation depends on your portfolio schema
    {:ok, content}
  end

  defp update_education_section(portfolio, content) do
    # Implementation depends on your portfolio schema
    {:ok, content}
  end

  defp update_skills_section(portfolio, content) do
    # Implementation depends on your portfolio schema
    {:ok, content}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto bg-black bg-opacity-50">
      <div class="flex min-h-screen items-center justify-center p-4">
        <div class="w-full max-w-4xl rounded-lg bg-white shadow-xl">
          <!-- Modal Header -->
          <div class="border-b border-gray-200 px-6 py-4">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-semibold text-gray-900">Import Resume</h3>
              <button
                type="button"
                phx-click={JS.dispatch("close-modal")}
                class="text-gray-400 hover:text-gray-600"
              >
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>

          <!-- Modal Body -->
          <div class="p-6">
            <!-- Step Indicator -->
            <div class="mb-6">
              <div class="flex items-center space-x-4">
                <div class={"flex items-center #{if @import_step in [:upload], do: "text-blue-600", else: "text-gray-400"}"}>
                  <div class={"w-8 h-8 rounded-full border-2 flex items-center justify-center text-sm font-medium #{if @import_step in [:upload], do: "border-blue-600 bg-blue-600 text-white", else: "border-gray-300"}"}>
                    1
                  </div>
                  <span class="ml-2 text-sm font-medium">Upload</span>
                </div>
                <div class="flex-1 border-t border-gray-300"></div>
                <div class={"flex items-center #{if @import_step in [:mapping], do: "text-blue-600", else: "text-gray-400"}"}>
                  <div class={"w-8 h-8 rounded-full border-2 flex items-center justify-center text-sm font-medium #{if @import_step in [:mapping], do: "border-blue-600 bg-blue-600 text-white", else: "border-gray-300"}"}>
                    2
                  </div>
                  <span class="ml-2 text-sm font-medium">Map Sections</span>
                </div>
                <div class="flex-1 border-t border-gray-300"></div>
                <div class={"flex items-center #{if @import_step in [:complete], do: "text-green-600", else: "text-gray-400"}"}>
                  <div class={"w-8 h-8 rounded-full border-2 flex items-center justify-center text-sm font-medium #{if @import_step in [:complete], do: "border-green-600 bg-green-600 text-white", else: "border-gray-300"}"}>
                    3
                  </div>
                  <span class="ml-2 text-sm font-medium">Import</span>
                </div>
              </div>
            </div>

            <!-- Upload Step -->
            <div :if={@import_step == :upload} class="space-y-6">
              <div class="text-center">
                <p class="text-gray-600 mb-4">
                  Upload your resume in PDF, DOCX, RTF, or TXT format. We'll automatically extract and organize the content.
                </p>
              </div>

              <form id="resume-upload-form" phx-target={@myself} phx-submit="parse-resume" phx-change="validate">
                <div
                  class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-gray-400 transition-colors"
                  phx-drop-target={@uploads.resume.ref}
                >
                  <.live_file_input upload={@uploads.resume} class="hidden" />

                  <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                    <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>

                  <div class="mt-4">
                    <label for={@uploads.resume.ref} class="cursor-pointer">
                      <span class="mt-2 block text-sm font-medium text-gray-900">
                        Drop your resume here or click to browse
                      </span>
                      <span class="mt-1 block text-xs text-gray-500">
                        PDF, DOCX, RTF, or TXT up to 10MB
                      </span>
                    </label>
                  </div>
                </div>

                <!-- Upload Progress -->
                <div :for={entry <- @uploads.resume.entries} class="mt-4">
                  <div class="flex items-center justify-between text-sm">
                    <span class="text-gray-700">{entry.client_name}</span>
                    <span class="text-gray-500">{entry.progress}%</span>
                  </div>
                  <div class="mt-1 bg-gray-200 rounded-full h-2">
                    <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{entry.progress}%"}></div>
                  </div>

                  <!-- Upload Errors -->
                  <div :for={err <- upload_errors(@uploads.resume, entry)} class="mt-1 text-sm text-red-600">
                    {error_to_string(err)}
                  </div>
                </div>

                <div :if={length(@uploads.resume.entries) > 0} class="mt-6 flex justify-end">
                  <button
                    type="submit"
                    disabled={@parsing_status == :parsing}
                    class="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
                  >
                    {if @parsing_status == :parsing, do: "Parsing...", else: "Parse Resume"}
                  </button>
                </div>
              </form>
            </div>

            <!-- Mapping Step -->
            <div :if={@import_step == :mapping} class="space-y-6">
              <div class="text-center">
                <p class="text-gray-600 mb-4">
                  Review and edit the extracted sections before importing them to your portfolio.
                </p>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <!-- Section Mapping Controls -->
                <div class="space-y-4">
                  <h4 class="font-medium text-gray-900">Detected Sections</h4>

                  <div :for={{section, preview} <- @preview_sections} class="border rounded-lg p-4">
                    <div class="flex items-center justify-between mb-2">
                      <h5 class="font-medium text-sm text-gray-800 capitalize">{section}</h5>
                      <input
                        type="checkbox"
                        checked={Map.has_key?(@section_mapping, section)}
                        phx-click="toggle-section"
                        phx-value-section={section}
                        phx-target={@myself}
                        class="rounded border-gray-300"
                      />
                    </div>
                    <p class="text-xs text-gray-600 mb-2">{preview}</p>
                    <button
                      :if={Map.has_key?(@section_mapping, section)}
                      phx-click="edit-section"
                      phx-value-section={section}
                      phx-target={@myself}
                      class="text-blue-600 hover:text-blue-800 text-xs"
                    >
                      Edit Content
                    </button>
                  </div>
                </div>

                <!-- Preview -->
                <div class="space-y-4">
                  <h4 class="font-medium text-gray-900">Import Preview</h4>
                  <div class="border rounded-lg p-4 bg-gray-50 max-h-96 overflow-y-auto">
                    <div :if={map_size(@section_mapping) == 0} class="text-gray-500 text-sm text-center py-8">
                      Select sections to preview here
                    </div>
                    <div :for={{section, content} <- @section_mapping} class="mb-4 last:mb-0">
                      <h5 class="font-medium text-sm text-gray-800 capitalize mb-2">{section}</h5>
                      <div class="text-xs text-gray-600 whitespace-pre-wrap">{String.slice(content, 0, 300)}{if String.length(content) > 300, do: "...", else: ""}</div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="flex justify-between pt-6 border-t">
                <button
                  phx-click="reset-import"
                  phx-target={@myself}
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                >
                  Start Over
                </button>
                <button
                  phx-click="import-sections"
                  phx-target={@myself}
                  disabled={map_size(@section_mapping) == 0}
                  class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 disabled:bg-gray-400"
                >
                  Import Selected Sections
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(error), do: "Upload error: #{error}"
end
