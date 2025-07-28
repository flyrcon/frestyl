# lib/frestyl_web/live/portfolio_live/components/section_modals/skills_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.SkillsModalComponent do
  @moduledoc """
  Specialized modal for editing skills sections
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Skills")
    |> assign(:modal_description, "Showcase your expertise and abilities")
    |> assign(:section_type, :skills)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="skills-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Skills Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Section Description</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Brief overview of your skills and expertise..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Display Mode -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Display Mode</label>
          <select
            name="display_mode"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            <option value="categorized" selected={Map.get(@content, "display_mode") == "categorized"}>Categorized</option>
            <option value="flat" selected={Map.get(@content, "display_mode") == "flat"}>Flat List</option>
            <option value="proficiency_bars" selected={Map.get(@content, "display_mode") == "proficiency_bars"}>Proficiency Bars</option>
            <option value="tech_stack" selected={Map.get(@content, "display_mode") == "tech_stack"}>Tech Stack Grid</option>
          </select>
        </div>

        <!-- Skill Categories -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Skill Categories</h4>
            <button
              type="button"
              phx-click="add_skill_category"
              phx-target={@myself}
              class="px-3 py-1 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700 transition-colors">
              + Add Category
            </button>
          </div>

          <div class="space-y-4" id="skill-categories-container">
            <%= for {category, index} <- Enum.with_index(Map.get(@content, "skill_categories", [])) do %>
              <div class="border rounded-lg p-4 bg-white relative">
                <!-- Remove button -->
                <button
                  type="button"
                  phx-click="remove_skill_category"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="absolute top-2 right-2 p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>

                <!-- Category name -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Category Name</label>
                  <input
                    type="text"
                    name={"skill_categories[#{index}][name]"}
                    value={Map.get(category, "name", "")}
                    placeholder="Programming Languages"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                </div>

                <!-- Skills in category -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Skills</label>
                  <div class="space-y-2" id={"skills-#{index}-container"}>
                    <%= for {skill, skill_index} <- Enum.with_index(Map.get(category, "skills", [])) do %>
                      <div class="flex items-center space-x-2">
                        <input
                          type="text"
                          name={"skill_categories[#{index}][skills][#{skill_index}][name]"}
                          value={get_skill_name(skill)}
                          placeholder="JavaScript"
                          class="flex-1 px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />

                        <%= if Map.get(@content, "show_proficiency", true) do %>
                          <select
                            name={"skill_categories[#{index}][skills][#{skill_index}][proficiency]"}
                            class="px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                            <option value="beginner" selected={get_skill_proficiency(skill) == "beginner"}>Beginner</option>
                            <option value="intermediate" selected={get_skill_proficiency(skill) == "intermediate"}>Intermediate</option>
                            <option value="advanced" selected={get_skill_proficiency(skill) == "advanced"}>Advanced</option>
                            <option value="expert" selected={get_skill_proficiency(skill) == "expert"}>Expert</option>
                          </select>
                        <% end %>

                        <%= if Map.get(@content, "show_years", false) do %>
                          <input
                            type="number"
                            name={"skill_categories[#{index}][skills][#{skill_index}][years]"}
                            value={get_skill_years(skill)}
                            placeholder="3"
                            min="0"
                            max="50"
                            class="w-16 px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                        <% end %>

                        <button
                          type="button"
                          phx-click="remove_skill"
                          phx-target={@myself}
                          phx-value-category-index={index}
                          phx-value-skill-index={skill_index}
                          class="p-1 text-red-500 hover:text-red-700">
                          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                          </svg>
                        </button>
                      </div>
                    <% end %>
                  </div>

                  <button
                    type="button"
                    phx-click="add_skill"
                    phx-target={@myself}
                    phx-value-category-index={index}
                    class="mt-2 text-sm text-blue-600 hover:text-blue-700">
                    + Add Skill
                  </button>
                </div>

                <!-- Category description -->
                <div>
                  <label class="block text-xs font-medium text-gray-700 mb-1">Category Description (Optional)</label>
                  <textarea
                    name={"skill_categories[#{index}][description]"}
                    rows="2"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                    placeholder="Brief description of this skill category..."><%= Map.get(category, "description", "") %></textarea>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "skill_categories", [])) == 0 do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
                </svg>
                <p>No skill categories added yet</p>
                <p class="text-sm">Click "Add Category" to organize your skills</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_proficiency"
              name="show_proficiency"
              value="true"
              checked={Map.get(@content, "show_proficiency", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_proficiency" class="ml-2 block text-sm text-gray-900">
              Show proficiency levels
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_years"
              name="show_years"
              value="true"
              checked={Map.get(@content, "show_years", false)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_years" class="ml-2 block text-sm text-gray-900">
              Show years of experience
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
              Enable skill filtering
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_skill_category", _params, socket) do
    content = socket.assigns.content
    current_categories = Map.get(content, "skill_categories", [])

    new_category = %{
      "name" => "",
      "description" => "",
      "skills" => []
    }

    updated_content = Map.put(content, "skill_categories", current_categories ++ [new_category])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_skill_category", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_categories = Map.get(content, "skill_categories", [])

    updated_categories = List.delete_at(current_categories, index)
    updated_content = Map.put(content, "skill_categories", updated_categories)

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("add_skill", %{"category-index" => category_index_str}, socket) do
    category_index = String.to_integer(category_index_str)
    content = socket.assigns.content
    current_categories = Map.get(content, "skill_categories", [])

    if category_index < length(current_categories) do
      category = Enum.at(current_categories, category_index)
      current_skills = Map.get(category, "skills", [])

      new_skill = %{
        "name" => "",
        "proficiency" => "intermediate",
        "years" => 1
      }

      updated_skills = current_skills ++ [new_skill]
      updated_category = Map.put(category, "skills", updated_skills)
      updated_categories = List.replace_at(current_categories, category_index, updated_category)
      updated_content = Map.put(content, "skill_categories", updated_categories)

      {:noreply, assign(socket, :content, updated_content)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_skill", %{"category-index" => category_index_str, "skill-index" => skill_index_str}, socket) do
    category_index = String.to_integer(category_index_str)
    skill_index = String.to_integer(skill_index_str)
    content = socket.assigns.content
    current_categories = Map.get(content, "skill_categories", [])

    if category_index < length(current_categories) do
      category = Enum.at(current_categories, category_index)
      current_skills = Map.get(category, "skills", [])

      updated_skills = List.delete_at(current_skills, skill_index)
      updated_category = Map.put(category, "skills", updated_skills)
      updated_categories = List.replace_at(current_categories, category_index, updated_category)
      updated_content = Map.put(content, "skill_categories", updated_categories)

      {:noreply, assign(socket, :content, updated_content)}
    else
      {:noreply, socket}
    end
  end

  defp get_section_content(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> %{"description" => content}
      _ -> %{}
    end
  end

  defp get_skill_name(skill) when is_map(skill), do: Map.get(skill, "name", "")
  defp get_skill_name(skill) when is_binary(skill), do: skill
  defp get_skill_name(_), do: ""

  defp get_skill_proficiency(skill) when is_map(skill), do: Map.get(skill, "proficiency", "intermediate")
  defp get_skill_proficiency(_), do: "intermediate"

  defp get_skill_years(skill) when is_map(skill), do: Map.get(skill, "years", 1)
  defp get_skill_years(_), do: 1
end
