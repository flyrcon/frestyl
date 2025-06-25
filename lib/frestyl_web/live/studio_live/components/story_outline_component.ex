# lib/frestyl_web/live/studio_live/components/story_outline_component.ex
defmodule FrestylWeb.StudioLive.StoryOutlineComponent do
  @moduledoc """
  Interactive story outline component for collaborative storytelling.
  Supports multiple story structures, real-time collaboration, and drag-and-drop organization.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Studio.StoryStructure

  @story_templates %{
    "three_act" => %{
      name: "Three-Act Structure",
      description: "Classic beginning, middle, end structure",
      sections: [
        %{name: "Act I - Setup", type: "act", description: "Introduce characters, world, and conflict"},
        %{name: "Plot Point 1", type: "plot_point", description: "Inciting incident that launches the story"},
        %{name: "Act II - Confrontation", type: "act", description: "Rising action, obstacles, character development"},
        %{name: "Midpoint", type: "plot_point", description: "Major revelation or turning point"},
        %{name: "Plot Point 2", type: "plot_point", description: "Crisis point, all seems lost"},
        %{name: "Act III - Resolution", type: "act", description: "Climax and resolution"}
      ]
    },
    "heros_journey" => %{
      name: "Hero's Journey",
      description: "Campbell's monomyth structure",
      sections: [
        %{name: "Ordinary World", type: "stage", description: "Hero's normal life before transformation"},
        %{name: "Call to Adventure", type: "stage", description: "The inciting incident"},
        %{name: "Refusal of the Call", type: "stage", description: "Hero's hesitation or fear"},
        %{name: "Meeting the Mentor", type: "stage", description: "Wise figure gives advice/magical aid"},
        %{name: "Crossing the Threshold", type: "stage", description: "Hero commits to adventure"},
        %{name: "Tests & Allies", type: "stage", description: "Hero faces challenges, makes allies"},
        %{name: "Approach to Inmost Cave", type: "stage", description: "Preparation for major challenge"},
        %{name: "Ordeal", type: "stage", description: "Crisis point, hero faces greatest fear"},
        %{name: "Reward", type: "stage", description: "Hero survives and gains something"},
        %{name: "The Road Back", type: "stage", description: "Hero begins journey back to ordinary world"},
        %{name: "Resurrection", type: "stage", description: "Final test, hero is transformed"},
        %{name: "Return with Elixir", type: "stage", description: "Hero returns with wisdom/power to help others"}
      ]
    },
    "seven_point" => %{
      name: "Seven-Point Story Structure",
      description: "Dan Wells' plot structure method",
      sections: [
        %{name: "Hook", type: "point", description: "Opening scene that grabs attention"},
        %{name: "Plot Turn 1", type: "point", description: "Call to adventure, normal world disrupted"},
        %{name: "Pinch Point 1", type: "point", description: "Apply pressure, show antagonist force"},
        %{name: "Midpoint", type: "point", description: "Hero moves from reaction to action"},
        %{name: "Pinch Point 2", type: "point", description: "Major disaster, highest pressure"},
        %{name: "Plot Turn 2", type: "point", description: "Final piece of puzzle, truth revealed"},
        %{name: "Resolution", type: "point", description: "Conflict resolved, character arc complete"}
      ]
    },
    "custom" => %{
      name: "Custom Structure",
      description: "Build your own story structure",
      sections: []
    }
  }

  @impl true
  def update(assigns, socket) do
    story_outline = get_story_outline(assigns)

    socket = socket
    |> assign(assigns)
    |> assign(:story_outline, story_outline)
    |> assign(:selected_template, story_outline.template || "three_act")
    |> assign(:show_template_modal, false)
    |> assign(:editing_section, nil)
    |> assign(:dragging_section, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-white">
      <!-- Header -->
      <div class="flex items-center justify-between p-4 border-b border-gray-200 bg-gray-50">
        <div class="flex items-center space-x-3">
          <div class="w-8 h-8 rounded-lg bg-purple-100 flex items-center justify-center">
            <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
          </div>
          <div>
            <h3 class="font-semibold text-gray-900">Story Outline</h3>
            <p class="text-sm text-gray-600">
              <%= @story_templates[@selected_template].name %>
            </p>
          </div>
        </div>

        <div class="flex items-center space-x-2">
          <button
            phx-click="show_template_selector"
            phx-target={@myself}
            class="text-sm text-indigo-600 hover:text-indigo-700 font-medium"
          >
            Change Template
          </button>
          <button
            phx-click="export_outline"
            phx-target={@myself}
            class="text-sm text-gray-600 hover:text-gray-700"
          >
            Export
          </button>
        </div>
      </div>

      <!-- Template Modal -->
      <%= if @show_template_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50" phx-click="close_template_modal" phx-target={@myself}>
          <div class="bg-white rounded-xl shadow-xl max-w-2xl w-full mx-4 max-h-96 overflow-y-auto" phx-click-away="close_template_modal" phx-target={@myself}>
            <div class="p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Choose Story Structure</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <%= for {template_key, template} <- @story_templates do %>
                  <button
                    phx-click="select_template"
                    phx-value-template={template_key}
                    phx-target={@myself}
                    class={[
                      "p-4 text-left border-2 rounded-lg transition-all hover:shadow-md",
                      if(@selected_template == template_key, do: "border-indigo-500 bg-indigo-50", else: "border-gray-200 hover:border-gray-300")
                    ]}
                  >
                    <h4 class="font-medium text-gray-900 mb-1"><%= template.name %></h4>
                    <p class="text-sm text-gray-600 mb-2"><%= template.description %></p>
                    <p class="text-xs text-gray-500"><%= length(template.sections) %> sections</p>
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Outline Content -->
      <div class="flex-1 overflow-y-auto p-4">
        <%= if length(@story_outline.sections) > 0 do %>
          <div class="space-y-3" id="story-sections" phx-hook="DragDropOutline">
            <%= for {section, index} <- Enum.with_index(@story_outline.sections) do %>
              <div
                class={[
                  "group relative bg-white border-2 rounded-lg p-4 transition-all cursor-move",
                  get_section_border_class(section.type),
                  if(@dragging_section == index, do: "opacity-50 scale-95", else: "hover:shadow-md")
                ]}
                data-section-index={index}
                draggable="true"
              >
                <!-- Section Header -->
                <div class="flex items-start justify-between mb-2">
                  <div class="flex items-center space-x-3 flex-1">
                    <div class={[
                      "w-3 h-3 rounded-full flex-shrink-0",
                      get_section_color_class(section.type)
                    ]}></div>
                    <div class="flex-1 min-w-0">
                      <%= if @editing_section == index do %>
                        <input
                          type="text"
                          value={section.name}
                          phx-blur="save_section_name"
                          phx-value-index={index}
                          phx-target={@myself}
                          class="w-full font-medium text-gray-900 bg-transparent border-none focus:outline-none focus:ring-2 focus:ring-indigo-500 rounded px-1"
                          autofocus
                        />
                      <% else %>
                        <button
                          phx-click="edit_section_name"
                          phx-value-index={index}
                          phx-target={@myself}
                          class="font-medium text-gray-900 hover:text-indigo-600 text-left truncate w-full"
                        >
                          <%= section.name %>
                        </button>
                      <% end %>
                    </div>
                  </div>

                  <div class="flex items-center space-x-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button
                      phx-click="add_scene"
                      phx-value-section-index={index}
                      phx-target={@myself}
                      class="p-1 text-gray-400 hover:text-indigo-600"
                      title="Add Scene"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                      </svg>
                    </button>
                    <button
                      phx-click="delete_section"
                      phx-value-index={index}
                      phx-target={@myself}
                      class="p-1 text-gray-400 hover:text-red-600"
                      title="Delete Section"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                      </svg>
                    </button>
                  </div>
                </div>

                <!-- Section Description -->
                <p class="text-sm text-gray-600 mb-3 pl-6"><%= section.description %></p>

                <!-- Scenes -->
                <%= if Map.get(section, :scenes) && length(section.scenes) > 0 do %>
                  <div class="pl-6 space-y-2">
                    <%= for {scene, scene_index} <- Enum.with_index(section.scenes) do %>
                      <div class="flex items-center space-x-2 p-2 bg-gray-50 rounded border border-gray-200">
                        <div class="w-2 h-2 rounded-full bg-gray-400"></div>
                        <div class="flex-1 min-w-0">
                          <p class="text-sm font-medium text-gray-900 truncate"><%= scene.name %></p>
                          <%= if scene.description do %>
                            <p class="text-xs text-gray-600 truncate"><%= scene.description %></p>
                          <% end %>
                        </div>
                        <button
                          phx-click="edit_scene"
                          phx-value-section-index={index}
                          phx-value-scene-index={scene_index}
                          phx-target={@myself}
                          class="text-xs text-indigo-600 hover:text-indigo-700"
                        >
                          Edit
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <!-- Collaboration Indicators -->
                <%= if Map.get(section, :collaborators) && length(section.collaborators) > 0 do %>
                  <div class="flex items-center space-x-1 pl-6 mt-2">
                    <%= for collaborator <- Enum.take(section.collaborators, 3) do %>
                      <div class="w-5 h-5 rounded-full bg-gradient-to-br from-blue-500 to-purple-600 border border-white flex items-center justify-center">
                        <span class="text-xs text-white font-medium">
                          <%= String.at(collaborator.username || "?", 0) %>
                        </span>
                      </div>
                    <% end %>
                    <%= if length(section.collaborators) > 3 do %>
                      <span class="text-xs text-gray-500">+<%= length(section.collaborators) - 3 %></span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Add Section Button -->
          <button
            phx-click="add_section"
            phx-target={@myself}
            class="w-full mt-4 p-4 border-2 border-dashed border-gray-300 rounded-lg text-gray-600 hover:text-indigo-600 hover:border-indigo-300 transition-colors"
          >
            <div class="flex items-center justify-center space-x-2">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
              </svg>
              <span class="font-medium">Add New Section</span>
            </div>
          </button>
        <% else %>
          <!-- Empty State -->
          <div class="text-center py-12">
            <div class="w-16 h-16 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">Start Your Story Outline</h3>
            <p class="text-gray-600 mb-6">Choose a template to begin structuring your story, or create a custom outline.</p>
            <button
              phx-click="initialize_template"
              phx-target={@myself}
              class="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-3 rounded-lg font-medium"
            >
              Initialize with <%= @story_templates[@selected_template].name %>
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("show_template_selector", _params, socket) do
    {:noreply, assign(socket, :show_template_modal, true)}
  end

  @impl true
  def handle_event("close_template_modal", _params, socket) do
    {:noreply, assign(socket, :show_template_modal, false)}
  end

  @impl true
  def handle_event("select_template", %{"template" => template}, socket) do
    socket = socket
    |> assign(:selected_template, template)
    |> assign(:show_template_modal, false)

    # Update story outline with new template
    send(self(), {:update_story_template, template})

    {:noreply, socket}
  end

  @impl true
  def handle_event("initialize_template", _params, socket) do
    template = @story_templates[socket.assigns.selected_template]

    story_outline = %{
      template: socket.assigns.selected_template,
      sections: template.sections |> Enum.map(fn section ->
        Map.merge(section, %{
          id: generate_section_id(),
          content: "",
          scenes: [],
          collaborators: [],
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        })
      end)
    }

    # Save to story structure
    send(self(), {:initialize_story_outline, story_outline})

    {:noreply, assign(socket, :story_outline, story_outline)}
  end

  @impl true
  def handle_event("edit_section_name", %{"index" => index}, socket) do
    {:noreply, assign(socket, :editing_section, String.to_integer(index))}
  end

  @impl true
  def handle_event("save_section_name", %{"index" => index, "value" => new_name}, socket) do
    index = String.to_integer(index)
    updated_sections = List.update_at(socket.assigns.story_outline.sections, index, fn section ->
      %{section | name: new_name, updated_at: DateTime.utc_now()}
    end)

    updated_outline = %{socket.assigns.story_outline | sections: updated_sections}

    # Broadcast update to collaborators
    send(self(), {:update_story_outline, updated_outline})

    socket = socket
    |> assign(:story_outline, updated_outline)
    |> assign(:editing_section, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_section", _params, socket) do
    new_section = %{
      id: generate_section_id(),
      name: "New Section",
      type: "custom",
      description: "Describe what happens in this section",
      content: "",
      scenes: [],
      collaborators: [],
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    updated_sections = socket.assigns.story_outline.sections ++ [new_section]
    updated_outline = %{socket.assigns.story_outline | sections: updated_sections}

    send(self(), {:update_story_outline, updated_outline})

    {:noreply, assign(socket, :story_outline, updated_outline)}
  end

  @impl true
  def handle_event("delete_section", %{"index" => index}, socket) do
    index = String.to_integer(index)
    updated_sections = List.delete_at(socket.assigns.story_outline.sections, index)
    updated_outline = %{socket.assigns.story_outline | sections: updated_sections}

    send(self(), {:update_story_outline, updated_outline})

    {:noreply, assign(socket, :story_outline, updated_outline)}
  end

  @impl true
  def handle_event("add_scene", %{"section-index" => section_index}, socket) do
    section_index = String.to_integer(section_index)

    new_scene = %{
      id: generate_scene_id(),
      name: "New Scene",
      description: "",
      content: "",
      created_at: DateTime.utc_now()
    }

    updated_sections = List.update_at(socket.assigns.story_outline.sections, section_index, fn section ->
      updated_scenes = (section.scenes || []) ++ [new_scene]
      %{section | scenes: updated_scenes, updated_at: DateTime.utc_now()}
    end)

    updated_outline = %{socket.assigns.story_outline | sections: updated_sections}

    send(self(), {:update_story_outline, updated_outline})

    {:noreply, assign(socket, :story_outline, updated_outline)}
  end

  # Helper Functions

  defp get_story_outline(assigns) do
    # Get story outline from workspace state or create default
    get_in(assigns, [:workspace_state, :story, :outline]) || %{
      template: "three_act",
      sections: []
    }
  end

  defp get_section_border_class(type) do
    case type do
      "act" -> "border-blue-200 hover:border-blue-300"
      "plot_point" -> "border-red-200 hover:border-red-300"
      "stage" -> "border-green-200 hover:border-green-300"
      "point" -> "border-purple-200 hover:border-purple-300"
      _ -> "border-gray-200 hover:border-gray-300"
    end
  end

  defp get_section_color_class(type) do
    case type do
      "act" -> "bg-blue-500"
      "plot_point" -> "bg-red-500"
      "stage" -> "bg-green-500"
      "point" -> "bg-purple-500"
      _ -> "bg-gray-500"
    end
  end

  defp generate_section_id do
    :crypto.strong_rand_bytes(8) |> Base.encode64() |> binary_part(0, 8)
  end

  defp generate_scene_id do
    :crypto.strong_rand_bytes(6) |> Base.encode64() |> binary_part(0, 6)
  end
end
