# lib/frestyl_web/live/portfolio_live/components/section_modals/education_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.EducationModalComponent do
  @moduledoc """
  Specialized modal for editing education sections - degrees, certifications, courses
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Education")
    |> assign(:modal_description, "Showcase your academic background and learning journey")
    |> assign(:section_type, :education)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="education-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Education Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Section Description</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Overview of your educational background and continuous learning..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Display Style -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Display Style</label>
          <select
            name="display_style"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            <option value="timeline" selected={Map.get(@content, "display_style") == "timeline"}>Timeline</option>
            <option value="cards" selected={Map.get(@content, "display_style") == "cards"}>Card Grid</option>
            <option value="list" selected={Map.get(@content, "display_style") == "list"}>Simple List</option>
            <option value="grouped" selected={Map.get(@content, "display_style") == "grouped"}>Grouped by Type</option>
          </select>
        </div>

        <!-- Education Items -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Education History</h4>
            <button
              type="button"
              phx-click="add_education_item"
              phx-target={@myself}
              class="px-3 py-1 bg-indigo-600 text-white text-sm rounded-md hover:bg-indigo-700 transition-colors">
              + Add Education
            </button>
          </div>

          <div class="space-y-6" id="education-items-container">
            <%= for {item, index} <- Enum.with_index(Map.get(@content, "education", [])) do %>
              <div class="border rounded-lg p-4 bg-white relative">
                <!-- Remove button -->
                <button
                  type="button"
                  phx-click="remove_education_item"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="absolute top-2 right-2 p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>

                <!-- Basic information -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Degree/Certification</label>
                    <input
                      type="text"
                      name={"education[#{index}][degree]"}
                      value={Map.get(item, "degree", "")}
                      placeholder="Bachelor of Science, MBA, Certificate"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Field of Study</label>
                    <input
                      type="text"
                      name={"education[#{index}][field]"}
                      value={Map.get(item, "field", "")}
                      placeholder="Computer Science, Business Administration"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Institution</label>
                    <input
                      type="text"
                      name={"education[#{index}][institution]"}
                      value={Map.get(item, "institution", "")}
                      placeholder="University Name"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Location</label>
                    <input
                      type="text"
                      name={"education[#{index}][location]"}
                      value={Map.get(item, "location", "")}
                      placeholder="City, State/Country"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                </div>

                <!-- Dates and status -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Start Date</label>
                    <input
                      type="text"
                      name={"education[#{index}][start_date]"}
                      value={Map.get(item, "start_date", "")}
                      placeholder="2018"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">End Date</label>
                    <input
                      type="text"
                      name={"education[#{index}][end_date]"}
                      value={Map.get(item, "end_date", "")}
                      placeholder="2022 or Expected 2024"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Status</label>
                    <select
                      name={"education[#{index}][status]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500">
                      <option value="completed" selected={Map.get(item, "status") == "completed"}>Completed</option>
                      <option value="in_progress" selected={Map.get(item, "status") == "in_progress"}>In Progress</option>
                      <option value="expected" selected={Map.get(item, "status") == "expected"}>Expected</option>
                      <option value="transferred" selected={Map.get(item, "status") == "transferred"}>Transferred</option>
                    </select>
                  </div>
                </div>

                <!-- Academic details -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">GPA (Optional)</label>
                    <input
                      type="text"
                      name={"education[#{index}][gpa]"}
                      value={Map.get(item, "gpa", "")}
                      placeholder="3.8/4.0"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Honors/Awards</label>
                    <input
                      type="text"
                      name={"education[#{index}][honors]"}
                      value={Map.get(item, "honors", "")}
                      placeholder="Magna Cum Laude, Dean's List"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                </div>

                <!-- Description -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Description</label>
                  <textarea
                    name={"education[#{index}][description]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500"
                    placeholder="Relevant details about your educational experience, achievements, or focus areas..."><%= Map.get(item, "description", "") %></textarea>
                </div>

                <!-- Relevant coursework -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Relevant Coursework</label>
                  <textarea
                    name={"education[#{index}][relevant_coursework]"}
                    rows="2"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500"
                    placeholder="Data Structures, Machine Learning, Advanced Statistics (separate with commas)"><%= format_coursework_for_textarea(Map.get(item, "relevant_coursework", [])) %></textarea>
                  <p class="text-xs text-gray-500 mt-1">Separate courses with commas</p>
                </div>

                <!-- Activities and thesis -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Activities/Organizations</label>
                    <textarea
                      name={"education[#{index}][activities]"}
                      rows="2"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500"
                      placeholder="Student Government, Research Assistant, Club President"><%= format_activities_for_textarea(Map.get(item, "activities", [])) %></textarea>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Thesis/Project Title</label>
                    <input
                      type="text"
                      name={"education[#{index}][thesis_title]"}
                      value={Map.get(item, "thesis_title", "")}
                      placeholder="Senior Capstone Project Title"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                </div>

                <!-- Institution details -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Institution Logo URL</label>
                    <input
                      type="url"
                      name={"education[#{index}][institution_logo]"}
                      value={Map.get(item, "institution_logo", "")}
                      placeholder="https://university.edu/logo.png"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Institution Website</label>
                    <input
                      type="url"
                      name={"education[#{index}][institution_url]"}
                      value={Map.get(item, "institution_url", "")}
                      placeholder="https://university.edu"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-indigo-500" />
                  </div>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "education", [])) == 0 do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                </svg>
                <p>No education history added yet</p>
                <p class="text-sm">Click "Add Education" to showcase your academic background</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Certifications -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Professional Certifications</h4>
            <button
              type="button"
              phx-click="add_certification"
              phx-target={@myself}
              class="px-3 py-1 bg-green-600 text-white text-sm rounded-md hover:bg-green-700 transition-colors">
              + Add Certification
            </button>
          </div>

          <div class="space-y-4" id="certifications-container">
            <%= for {cert, index} <- Enum.with_index(Map.get(@content, "certifications", [])) do %>
              <div class="border rounded p-3 bg-white">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Certification Name</label>
                    <input
                      type="text"
                      name={"certifications[#{index}][name]"}
                      value={Map.get(cert, "name", "")}
                      placeholder="AWS Certified Solutions Architect"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-green-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Issuing Organization</label>
                    <input
                      type="text"
                      name={"certifications[#{index}][issuer]"}
                      value={Map.get(cert, "issuer", "")}
                      placeholder="Amazon Web Services, Google, Microsoft"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-green-500" />
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Date Earned</label>
                    <input
                      type="text"
                      name={"certifications[#{index}][date_earned]"}
                      value={Map.get(cert, "date_earned", "")}
                      placeholder="March 2023"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-green-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Expiry Date</label>
                    <input
                      type="text"
                      name={"certifications[#{index}][expiry_date]"}
                      value={Map.get(cert, "expiry_date", "")}
                      placeholder="March 2026 or Never"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-green-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Credential ID</label>
                    <input
                      type="text"
                      name={"certifications[#{index}][credential_id]"}
                      value={Map.get(cert, "credential_id", "")}
                      placeholder="ABC123XYZ"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-green-500" />
                  </div>
                </div>

                <div class="flex items-center justify-between">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Verification URL</label>
                    <input
                      type="url"
                      name={"certifications[#{index}][verification_url]"}
                      value={Map.get(cert, "verification_url", "")}
                      placeholder="https://verify.certification.com/abc123"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-green-500" />
                  </div>
                  <button
                    type="button"
                    phx-click="remove_certification"
                    phx-target={@myself}
                    phx-value-index={index}
                    class="ml-3 text-xs text-red-600 hover:text-red-800">
                    Remove
                  </button>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "certifications", [])) == 0 do %>
              <div class="text-center py-4 text-gray-500 text-sm">
                No certifications added yet. Click "Add Certification" to showcase professional credentials.
              </div>
            <% end %>
          </div>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_gpa"
              name="show_gpa"
              value="true"
              checked={Map.get(@content, "show_gpa", false)}
              class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
            <label for="show_gpa" class="ml-2 block text-sm text-gray-900">
              Show GPA information
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_coursework"
              name="show_coursework"
              value="true"
              checked={Map.get(@content, "show_coursework", true)}
              class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
            <label for="show_coursework" class="ml-2 block text-sm text-gray-900">
              Show relevant coursework
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_activities"
              name="show_activities"
              value="true"
              checked={Map.get(@content, "show_activities", true)}
              class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
            <label for="show_activities" class="ml-2 block text-sm text-gray-900">
              Show activities & organizations
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_institution_logos"
              name="show_institution_logos"
              value="true"
              checked={Map.get(@content, "show_institution_logos", true)}
              class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
            <label for="show_institution_logos" class="ml-2 block text-sm text-gray-900">
              Show institution logos
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_education_item", _params, socket) do
    content = socket.assigns.content
    current_education = Map.get(content, "education", [])

    new_education = %{
      "degree" => "",
      "field" => "",
      "institution" => "",
      "location" => "",
      "start_date" => "",
      "end_date" => "",
      "status" => "completed",
      "gpa" => "",
      "honors" => "",
      "description" => "",
      "relevant_coursework" => [],
      "activities" => [],
      "thesis_title" => "",
      "institution_logo" => "",
      "institution_url" => ""
    }

    updated_content = Map.put(content, "education", current_education ++ [new_education])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_education_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_education = Map.get(content, "education", [])

    updated_education = List.delete_at(current_education, index)
    updated_content = Map.put(content, "education", updated_education)

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("add_certification", _params, socket) do
    content = socket.assigns.content
    current_certifications = Map.get(content, "certifications", [])

    new_certification = %{
      "name" => "",
      "issuer" => "",
      "date_earned" => "",
      "expiry_date" => "",
      "credential_id" => "",
      "verification_url" => ""
    }

    updated_content = Map.put(content, "certifications", current_certifications ++ [new_certification])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_certification", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_certifications = Map.get(content, "certifications", [])

    updated_certifications = List.delete_at(current_certifications, index)
    updated_content = Map.put(content, "certifications", updated_certifications)

    {:noreply, assign(socket, :content, updated_content)}
  end

  defp get_section_content(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> %{"description" => content}
      _ -> %{}
    end
  end

  defp format_coursework_for_textarea(coursework) when is_list(coursework) do
    Enum.join(coursework, ", ")
  end
  defp format_coursework_for_textarea(_), do: ""

  defp format_activities_for_textarea(activities) when is_list(activities) do
    Enum.join(activities, ", ")
  end
  defp format_activities_for_textarea(_), do: ""
end
