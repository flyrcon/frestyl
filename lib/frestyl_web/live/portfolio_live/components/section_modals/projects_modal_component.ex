# lib/frestyl_web/live/portfolio_live/components/section_modals/projects_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.ProjectsModalComponent do
  @moduledoc """
  Specialized modal for editing projects sections
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Projects")
    |> assign(:modal_description, "Showcase your portfolio projects")
    |> assign(:section_type, :projects)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="projects-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Projects Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Section Description</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Brief overview of your projects and work..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Display Style -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Display Style</label>
          <select
            name="display_style"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            <option value="grid" selected={Map.get(@content, "display_style") == "grid"}>Grid Layout</option>
            <option value="masonry" selected={Map.get(@content, "display_style") == "masonry"}>Masonry Layout</option>
            <option value="carousel" selected={Map.get(@content, "display_style") == "carousel"}>Carousel</option>
            <option value="featured" selected={Map.get(@content, "display_style") == "featured"}>Featured + Grid</option>
            <option value="timeline" selected={Map.get(@content, "display_style") == "timeline"}>Timeline</option>
          </select>
        </div>

        <!-- Project Items -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Projects</h4>
            <button
              type="button"
              phx-click="add_project_item"
              phx-target={@myself}
              class="px-3 py-1 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700 transition-colors">
              + Add Project
            </button>
          </div>

          <div class="space-y-6" id="project-items-container">
            <%= for {item, index} <- Enum.with_index(Map.get(@content, "items", [])) do %>
              <div class="border rounded-lg p-4 bg-white relative">
                <!-- Remove button -->
                <button
                  type="button"
                  phx-click="remove_project_item"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="absolute top-2 right-2 p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>

                <!-- Project basic info -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Project Title</label>
                    <input
                      type="text"
                      name={"items[#{index}][title]"}
                      value={Map.get(item, "title", "")}
                      placeholder="Project Name"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Status</label>
                    <select
                      name={"items[#{index}][status]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                      <option value="completed" selected={Map.get(item, "status") == "completed"}>Completed</option>
                      <option value="in_progress" selected={Map.get(item, "status") == "in_progress"}>In Progress</option>
                      <option value="planned" selected={Map.get(item, "status") == "planned"}>Planned</option>
                      <option value="archived" selected={Map.get(item, "status") == "archived"}>Archived</option>
                    </select>
                  </div>
                </div>

                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Description</label>
                  <textarea
                    name={"items[#{index}][description]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                    placeholder="Describe the project, its purpose, and key features..."><%= Map.get(item, "description", "") %></textarea>
                </div>

                <!-- Project links -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Live Demo URL</label>
                    <input
                      type="url"
                      name={"items[#{index}][demo_url]"}
                      value={Map.get(item, "demo_url", "")}
                      placeholder="https://project-demo.com"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Source Code URL</label>
                    <input
                      type="url"
                      name={"items[#{index}][source_url]"}
                      value={Map.get(item, "source_url", "")}
                      placeholder="https://github.com/user/repo"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                </div>

                <!-- Technologies used -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Technologies Used</label>
                  <input
                    type="text"
                    name={"items[#{index}][technologies]"}
                    value={Enum.join(Map.get(item, "technologies", []), ", ")}
                    placeholder="React, Node.js, MongoDB, AWS"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  <p class="text-xs text-gray-500 mt-1">Separate technologies with commas</p>
                </div>

                <!-- Project timeline -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Start Date</label>
                    <input
                      type="text"
                      name={"items[#{index}][start_date]"}
                      value={Map.get(item, "start_date", "")}
                      placeholder="Jan 2023"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">End Date</label>
                    <input
                      type="text"
                      name={"items[#{index}][end_date]"}
                      value={Map.get(item, "end_date", "")}
                      placeholder="Mar 2023"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Duration</label>
                    <input
                      type="text"
                      name={"items[#{index}][duration]"}
                      value={Map.get(item, "duration", "")}
                      placeholder="3 months"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                </div>

                <!-- Key features -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Key Features</label>
                  <textarea
                    name={"items[#{index}][key_features]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                    placeholder="• User authentication and authorization&#10;• Real-time chat functionality&#10;• Responsive design for mobile devices"><%= format_features_for_textarea(Map.get(item, "key_features", [])) %></textarea>
                  <p class="text-xs text-gray-500 mt-1">Use bullet points (•) for each feature</p>
                </div>

                <!-- Challenges and solutions -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Challenges & Solutions</label>
                  <textarea
                    name={"items[#{index}][challenges]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                    placeholder="Describe technical challenges faced and how you solved them..."><%= Map.get(item, "challenges", "") %></textarea>
                </div>

                <!-- Project metrics -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Team Size</label>
                    <input
                      type="number"
                      name={"items[#{index}][team_size]"}
                      value={Map.get(item, "team_size", "")}
                      placeholder="1"
                      min="1"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Your Role</label>
                    <input
                      type="text"
                      name={"items[#{index}][role]"}
                      value={Map.get(item, "role", "")}
                      placeholder="Full Stack Developer"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Client/Company</label>
                    <input
                      type="text"
                      name={"items[#{index}][client]"}
                      value={Map.get(item, "client", "")}
                      placeholder="Personal Project"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                </div>

                <!-- Project flags -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"featured_#{index}"}
                      name={"items[#{index}][featured]"}
                      value="true"
                      checked={Map.get(item, "featured", false)}
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                    <label for={"featured_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Featured project
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"open_source_#{index}"}
                      name={"items[#{index}][open_source]"}
                      value="true"
                      checked={Map.get(item, "open_source", false)}
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                    <label for={"open_source_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Open source
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"case_study_#{index}"}
                      name={"items[#{index}][has_case_study]"}
                      value="true"
                      checked={Map.get(item, "has_case_study", false)}
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                    <label for={"case_study_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Has case study
                    </label>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "items", [])) == 0 do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                </svg>
                <p>No projects added yet</p>
                <p class="text-sm">Click "Add Project" to showcase your work</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_technologies"
              name="show_technologies"
              value="true"
              checked={Map.get(@content, "show_technologies", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_technologies" class="ml-2 block text-sm text-gray-900">
              Show technologies used
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_dates"
              name="show_dates"
              value="true"
              checked={Map.get(@content, "show_dates", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_dates" class="ml-2 block text-sm text-gray-900">
              Show project dates
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="enable_filtering"
              name="enable_filtering"
              value="true"
              checked={Map.get(@content, "enable_filtering", false)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="enable_filtering" class="ml-2 block text-sm text-gray-900">
              Enable technology filtering
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_github_stats"
              name="show_github_stats"
              value="true"
              checked={Map.get(@content, "show_github_stats", false)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_github_stats" class="ml-2 block text-sm text-gray-900">
              Show GitHub stats
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_project_item", _params, socket) do
    content = socket.assigns.content
    current_items = Map.get(content, "items", [])

    new_item = %{
      "title" => "",
      "description" => "",
      "demo_url" => "",
      "source_url" => "",
      "technologies" => [],
      "start_date" => "",
      "end_date" => "",
      "duration" => "",
      "key_features" => [],
      "challenges" => "",
      "team_size" => 1,
      "role" => "",
      "client" => "",
      "status" => "completed",
      "featured" => false,
      "open_source" => false,
      "has_case_study" => false
    }

    updated_content = Map.put(content, "items", current_items ++ [new_item])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_project_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_items = Map.get(content, "items", [])

    updated_items = List.delete_at(current_items, index)
    updated_content = Map.put(content, "items", updated_items)

    {:noreply, assign(socket, :content, updated_content)}
  end

  defp get_section_content(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> %{"description" => content}
      _ -> %{}
    end
  end

  defp format_features_for_textarea(features) when is_list(features) do
    features
    |> Enum.map(fn feature ->
      feature = if is_map(feature), do: Map.get(feature, "text", feature), else: feature
      if String.starts_with?(feature, "•"), do: feature, else: "• #{feature}"
    end)
    |> Enum.join("\n")
  end
  defp format_features_for_textarea(_), do: ""
end
