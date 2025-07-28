# lib/frestyl_web/live/portfolio_live/components/section_modals/collaborations_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.CollaborationsModalComponent do
  @moduledoc """
  Specialized modal for editing collaborations sections - team projects, partnerships, co-creators
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Collaborations")
    |> assign(:modal_description, "Showcase your team projects and partnerships")
    |> assign(:section_type, :collaborations)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="collaborations-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Collaborations Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Section Description</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Overview of your collaborative work and partnerships..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Display Style</label>
            <select
              name="display_style"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="cards" selected={Map.get(@content, "display_style") == "cards"}>Project Cards</option>
              <option value="timeline" selected={Map.get(@content, "display_style") == "timeline"}>Timeline</option>
              <option value="grid" selected={Map.get(@content, "display_style") == "grid"}>Partner Grid</option>
              <option value="featured" selected={Map.get(@content, "display_style") == "featured"}>Featured + List</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Items Per Row</label>
            <select
              name="items_per_row"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="1" selected={Map.get(@content, "items_per_row", 2) == 1}>1 Column</option>
              <option value="2" selected={Map.get(@content, "items_per_row", 2) == 2}>2 Columns</option>
              <option value="3" selected={Map.get(@content, "items_per_row", 2) == 3}>3 Columns</option>
            </select>
          </div>
        </div>

        <!-- Collaboration Items -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Collaborations & Partnerships</h4>
            <button
              type="button"
              phx-click="add_collaboration"
              phx-target={@myself}
              class="px-3 py-1 bg-teal-600 text-white text-sm rounded-md hover:bg-teal-700 transition-colors">
              + Add Collaboration
            </button>
          </div>

          <div class="space-y-6" id="collaborations-container">
            <%= for {collab, index} <- Enum.with_index(Map.get(@content, "collaborations", [])) do %>
              <div class="border rounded-lg p-4 bg-white relative">
                <!-- Remove button -->
                <button
                  type="button"
                  phx-click="remove_collaboration"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="absolute top-2 right-2 p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>

                <!-- Project/Partnership basic info -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Project/Partnership Name</label>
                    <input
                      type="text"
                      name={"collaborations[#{index}][name]"}
                      value={Map.get(collab, "name", "")}
                      placeholder="Mobile App Development, Joint Research"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Collaboration Type</label>
                    <select
                      name={"collaborations[#{index}][type]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500">
                      <option value="project" selected={Map.get(collab, "type") == "project"}>Joint Project</option>
                      <option value="partnership" selected={Map.get(collab, "type") == "partnership"}>Business Partnership</option>
                      <option value="mentorship" selected={Map.get(collab, "type") == "mentorship"}>Mentorship</option>
                      <option value="research" selected={Map.get(collab, "type") == "research"}>Research Collaboration</option>
                      <option value="creative" selected={Map.get(collab, "type") == "creative"}>Creative Collaboration</option>
                      <option value="consulting" selected={Map.get(collab, "type") == "consulting"}>Consulting Partnership</option>
                    </select>
                  </div>
                </div>

                <!-- Description -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Project Description</label>
                  <textarea
                    name={"collaborations[#{index}][description]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500"
                    placeholder="Describe the collaboration, goals, and outcomes..."><%= Map.get(collab, "description", "") %></textarea>
                </div>

                <!-- Timeline and status -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Start Date</label>
                    <input
                      type="text"
                      name={"collaborations[#{index}][start_date]"}
                      value={Map.get(collab, "start_date", "")}
                      placeholder="Jan 2023"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">End Date</label>
                    <input
                      type="text"
                      name={"collaborations[#{index}][end_date]"}
                      value={Map.get(collab, "end_date", "")}
                      placeholder="Ongoing, Dec 2023"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Status</label>
                    <select
                      name={"collaborations[#{index}][status]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500">
                      <option value="completed" selected={Map.get(collab, "status") == "completed"}>Completed</option>
                      <option value="ongoing" selected={Map.get(collab, "status") == "ongoing"}>Ongoing</option>
                      <option value="planned" selected={Map.get(collab, "status") == "planned"}>Planned</option>
                      <option value="paused" selected={Map.get(collab, "status") == "paused"}>Paused</option>
                    </select>
                  </div>
                </div>

                <!-- Collaborators/Partners -->
                <div class="mb-4">
                  <div class="flex items-center justify-between mb-2">
                    <label class="block text-xs font-medium text-gray-700">Collaborators/Partners</label>
                    <button
                      type="button"
                      phx-click="add_collaborator"
                      phx-target={@myself}
                      phx-value-collab-index={index}
                      class="text-xs text-teal-600 hover:text-teal-700">
                      + Add Partner
                    </button>
                  </div>

                  <div class="space-y-2">
                    <%= for {partner, partner_index} <- Enum.with_index(Map.get(collab, "partners", [])) do %>
                      <div class="flex items-center space-x-2 bg-gray-50 p-2 rounded">
                        <input
                          type="text"
                          name={"collaborations[#{index}][partners][#{partner_index}][name]"}
                          value={Map.get(partner, "name", "")}
                          placeholder="Partner Name"
                          class="flex-1 px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
                        <input
                          type="text"
                          name={"collaborations[#{index}][partners][#{partner_index}][role]"}
                          value={Map.get(partner, "role", "")}
                          placeholder="Designer, Developer, PM"
                          class="flex-1 px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
                        <input
                          type="url"
                          name={"collaborations[#{index}][partners][#{partner_index}][url]"}
                          value={Map.get(partner, "url", "")}
                          placeholder="https://partner.com"
                          class="flex-1 px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
                        <button
                          type="button"
                          phx-click="remove_collaborator"
                          phx-target={@myself}
                          phx-value-collab-index={index}
                          phx-value-partner-index={partner_index}
                          class="p-1 text-red-500 hover:text-red-700">
                          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                          </svg>
                        </button>
                      </div>
                    <% end %>

                    <%= if Enum.empty?(Map.get(collab, "partners", [])) do %>
                      <div class="text-center py-2 text-gray-400 text-xs">
                        No partners added yet
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Your role and contributions -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Your Role</label>
                    <input
                      type="text"
                      name={"collaborations[#{index}][your_role]"}
                      value={Map.get(collab, "your_role", "")}
                      placeholder="Lead Developer, Co-founder, Consultant"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Team Size</label>
                    <input
                      type="number"
                      name={"collaborations[#{index}][team_size]"}
                      value={Map.get(collab, "team_size", "")}
                      placeholder="3"
                      min="2"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
                  </div>
                </div>

                <!-- Key contributions -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Your Key Contributions</label>
                  <textarea
                    name={"collaborations[#{index}][contributions]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500"
                    placeholder="• Led the technical architecture&#10;• Managed client relationships&#10;• Developed core features"><%= format_contributions_for_textarea(Map.get(collab, "contributions", [])) %></textarea>
                  <p class="text-xs text-gray-500 mt-1">Use bullet points (•) for each contribution</p>
                </div>

                <!-- Results and impact -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Results & Impact</label>
                  <textarea
                    name={"collaborations[#{index}][results]"}
                    rows="2"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500"
                    placeholder="Launched to 10k users, Generated $50k revenue, Won industry award..."><%= Map.get(collab, "results", "") %></textarea>
                </div>

                <!-- Media and links -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Project Image URL</label>
                    <input
                      type="url"
                      name={"collaborations[#{index}][image_url]"}
                      value={Map.get(collab, "image_url", "")}
                      placeholder="https://example.com/project-image.jpg"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Project/Demo URL</label>
                    <input
                      type="url"
                      name={"collaborations[#{index}][demo_url]"}
                      value={Map.get(collab, "demo_url", "")}
                      placeholder="https://project.com"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
                  </div>
                </div>

                <!-- Technologies used -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Technologies/Tools Used</label>
                  <input
                    type="text"
                    name={"collaborations[#{index}][technologies]"}
                    value={Enum.join(Map.get(collab, "technologies", []), ", ")}
                    placeholder="React, Node.js, MongoDB, Figma"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
                  <p class="text-xs text-gray-500 mt-1">Separate technologies with commas</p>
                </div>

                <!-- Collaboration flags -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"featured_collab_#{index}"}
                      name={"collaborations[#{index}][featured]"}
                      value="true"
                      checked={Map.get(collab, "featured", false)}
                      class="h-4 w-4 text-teal-600 focus:ring-teal-500 border-gray-300 rounded">
                    <label for={"featured_collab_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Featured collaboration
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"remote_#{index}"}
                      name={"collaborations[#{index}][remote]"}
                      value="true"
                      checked={Map.get(collab, "remote", false)}
                      class="h-4 w-4 text-teal-600 focus:ring-teal-500 border-gray-300 rounded">
                    <label for={"remote_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Remote collaboration
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"open_to_similar_#{index}"}
                      name={"collaborations[#{index}][open_to_similar]"}
                      value="true"
                      checked={Map.get(collab, "open_to_similar", false)}
                      class="h-4 w-4 text-teal-600 focus:ring-teal-500 border-gray-300 rounded">
                    <label for={"open_to_similar_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Open to similar projects
                    </label>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "collaborations", [])) == 0 do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                </svg>
                <p>No collaborations added yet</p>
                <p class="text-sm">Click "Add Collaboration" to showcase your team projects</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Partnership Preferences -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <h4 class="font-medium text-gray-900 mb-4">Partnership Preferences</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Open to New Collaborations</label>
              <select
                name="open_to_collaborations"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500">
                <option value="yes" selected={Map.get(@content, "open_to_collaborations") == "yes"}>Yes, actively seeking</option>
                <option value="selective" selected={Map.get(@content, "open_to_collaborations") == "selective"}>Selective opportunities</option>
                <option value="no" selected={Map.get(@content, "open_to_collaborations") == "no"}>Not currently</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Preferred Collaboration Types</label>
              <input
                type="text"
                name="preferred_types"
                value={Enum.join(Map.get(@content, "preferred_types", []), ", ")}
                placeholder="Creative projects, Technical consulting, Research"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-teal-500" />
            </div>
          </div>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_partners"
              name="show_partners"
              value="true"
              checked={Map.get(@content, "show_partners", true)}
              class="h-4 w-4 text-teal-600 focus:ring-teal-500 border-gray-300 rounded">
            <label for="show_partners" class="ml-2 block text-sm text-gray-900">
              Show partner information
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_technologies"
              name="show_technologies"
              value="true"
              checked={Map.get(@content, "show_technologies", true)}
              class="h-4 w-4 text-teal-600 focus:ring-teal-500 border-gray-300 rounded">
            <label for="show_technologies" class="ml-2 block text-sm text-gray-900">
              Show technologies used
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_results"
              name="show_results"
              value="true"
              checked={Map.get(@content, "show_results", true)}
              class="h-4 w-4 text-teal-600 focus:ring-teal-500 border-gray-300 rounded">
            <label for="show_results" class="ml-2 block text-sm text-gray-900">
              Show results & impact
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="enable_contact_for_collabs"
              name="enable_contact_for_collabs"
              value="true"
              checked={Map.get(@content, "enable_contact_for_collabs", false)}
              class="h-4 w-4 text-teal-600 focus:ring-teal-500 border-gray-300 rounded">
            <label for="enable_contact_for_collabs" class="ml-2 block text-sm text-gray-900">
              Enable collaboration inquiries
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_collaboration", _params, socket) do
    content = socket.assigns.content
    current_collaborations = Map.get(content, "collaborations", [])

    new_collaboration = %{
      "name" => "",
      "type" => "project",
      "description" => "",
      "start_date" => "",
      "end_date" => "",
      "status" => "completed",
      "partners" => [],
      "your_role" => "",
      "team_size" => "",
      "contributions" => [],
      "results" => "",
      "image_url" => "",
      "demo_url" => "",
      "technologies" => [],
      "featured" => false,
      "remote" => false,
      "open_to_similar" => false
    }

    updated_content = Map.put(content, "collaborations", current_collaborations ++ [new_collaboration])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_collaboration", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_collaborations = Map.get(content, "collaborations", [])

    updated_collaborations = List.delete_at(current_collaborations, index)
    updated_content = Map.put(content, "collaborations", updated_collaborations)

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("add_collaborator", %{"collab-index" => collab_index_str}, socket) do
    collab_index = String.to_integer(collab_index_str)
    content = socket.assigns.content
    current_collaborations = Map.get(content, "collaborations", [])

    if collab_index < length(current_collaborations) do
      collaboration = Enum.at(current_collaborations, collab_index)
      current_partners = Map.get(collaboration, "partners", [])

      new_partner = %{
        "name" => "",
        "role" => "",
        "url" => ""
      }

      updated_partners = current_partners ++ [new_partner]
      updated_collaboration = Map.put(collaboration, "partners", updated_partners)
      updated_collaborations = List.replace_at(current_collaborations, collab_index, updated_collaboration)
      updated_content = Map.put(content, "collaborations", updated_collaborations)

      {:noreply, assign(socket, :content, updated_content)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_collaborator", %{"collab-index" => collab_index_str, "partner-index" => partner_index_str}, socket) do
    collab_index = String.to_integer(collab_index_str)
    partner_index = String.to_integer(partner_index_str)
    content = socket.assigns.content
    current_collaborations = Map.get(content, "collaborations", [])

    if collab_index < length(current_collaborations) do
      collaboration = Enum.at(current_collaborations, collab_index)
      current_partners = Map.get(collaboration, "partners", [])

      updated_partners = List.delete_at(current_partners, partner_index)
      updated_collaboration = Map.put(collaboration, "partners", updated_partners)
      updated_collaborations = List.replace_at(current_collaborations, collab_index, updated_collaboration)
      updated_content = Map.put(content, "collaborations", updated_collaborations)

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

  defp format_contributions_for_textarea(contributions) when is_list(contributions) do
    contributions
    |> Enum.map(fn contribution ->
      contribution = if is_map(contribution), do: Map.get(contribution, "text", contribution), else: contribution
      if String.starts_with?(contribution, "•"), do: contribution, else: "• #{contribution}"
    end)
    |> Enum.join("\n")
  end
  defp format_contributions_for_textarea(_), do: ""
end
