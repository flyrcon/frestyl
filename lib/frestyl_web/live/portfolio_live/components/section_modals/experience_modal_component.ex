# lib/frestyl_web/live/portfolio_live/components/section_modals/experience_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.ExperienceModalComponent do
  @moduledoc """
  Specialized modal for editing experience sections
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Experience")
    |> assign(:modal_description, "Showcase your professional journey")
    |> assign(:section_type, :experience)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="experience-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Experience Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Section Description</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Brief overview of your professional experience..."><%= Map.get(@content, "description", "") %></textarea>
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
            <option value="story" selected={Map.get(@content, "display_style") == "story"}>Story Format</option>
          </select>
        </div>

        <!-- Experience Items -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Work Experience</h4>
            <button
              type="button"
              phx-click="add_experience_item"
              phx-target={@myself}
              class="px-3 py-1 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700 transition-colors">
              + Add Position
            </button>
          </div>

          <div class="space-y-4" id="experience-items-container">
            <%= for {item, index} <- Enum.with_index(Map.get(@content, "items", [])) do %>
              <div class="border rounded-lg p-4 bg-white relative">
                <!-- Remove button -->
                <button
                  type="button"
                  phx-click="remove_experience_item"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="absolute top-2 right-2 p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>

                <!-- Job details -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Job Title</label>
                    <input
                      type="text"
                      name={"items[#{index}][title]"}
                      value={Map.get(item, "title", "")}
                      placeholder="Senior Developer"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Company</label>
                    <input
                      type="text"
                      name={"items[#{index}][company]"}
                      value={Map.get(item, "company", "")}
                      placeholder="Company Name"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Start Date</label>
                    <input
                      type="text"
                      name={"items[#{index}][start_date]"}
                      value={Map.get(item, "start_date", "")}
                      placeholder="Jan 2020"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">End Date</label>
                    <input
                      type="text"
                      name={"items[#{index}][end_date]"}
                      value={Map.get(item, "end_date", "")}
                      placeholder="Present"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Location</label>
                    <input
                      type="text"
                      name={"items[#{index}][location]"}
                      value={Map.get(item, "location", "")}
                      placeholder="New York, NY"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                </div>

                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Description</label>
                  <textarea
                    name={"items[#{index}][description]"}
                    rows="4"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                    placeholder="Describe your role, responsibilities, and achievements..."><%= Map.get(item, "description", "") %></textarea>
                </div>

                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Key Achievements</label>
                  <textarea
                    name={"items[#{index}][achievements]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                    placeholder="• Increased team productivity by 40%&#10;• Led successful migration to new platform&#10;• Mentored 5 junior developers"><%= format_achievements_for_textarea(Map.get(item, "achievements", [])) %></textarea>
                  <p class="text-xs text-gray-500 mt-1">Use bullet points (•) for each achievement</p>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Skills Used</label>
                    <input
                      type="text"
                      name={"items[#{index}][skills_used]"}
                      value={Enum.join(Map.get(item, "skills_used", []), ", ")}
                      placeholder="JavaScript, React, Node.js"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                    <p class="text-xs text-gray-500 mt-1">Separate skills with commas</p>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"current_job_#{index}"}
                      name={"items[#{index}][current]"}
                      value="true"
                      checked={Map.get(item, "current", false)}
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                    <label for={"current_job_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Current position
                    </label>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "items", [])) == 0 do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 002 2h2a2 2 0 002-2V6m0 0v6a2 2 0 01-2 2H6a2 2 0 01-2-2V6a2 2 0 012-2h12a2 2 0 012 2z"/>
                </svg>
                <p>No work experience added yet</p>
                <p class="text-sm">Click "Add Position" to start building your experience</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_duration"
              name="show_duration"
              value="true"
              checked={Map.get(@content, "show_duration", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_duration" class="ml-2 block text-sm text-gray-900">
              Show employment duration
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_skills"
              name="show_skills"
              value="true"
              checked={Map.get(@content, "show_skills", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_skills" class="ml-2 block text-sm text-gray-900">
              Show skills used
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_experience_item", _params, socket) do
    content = socket.assigns.content
    current_items = Map.get(content, "items", [])

    new_item = %{
      "title" => "",
      "company" => "",
      "start_date" => "",
      "end_date" => "",
      "location" => "",
      "description" => "",
      "achievements" => [],
      "skills_used" => [],
      "current" => false
    }

    updated_content = Map.put(content, "items", current_items ++ [new_item])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_experience_item", %{"index" => index_str}, socket) do
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

  defp format_achievements_for_textarea(achievements) when is_list(achievements) do
    achievements
    |> Enum.map(fn achievement ->
      achievement = if is_map(achievement), do: Map.get(achievement, "text", achievement), else: achievement
      if String.starts_with?(achievement, "•"), do: achievement, else: "• #{achievement}"
    end)
    |> Enum.join("\n")
  end
  defp format_achievements_for_textarea(_), do: ""
end
