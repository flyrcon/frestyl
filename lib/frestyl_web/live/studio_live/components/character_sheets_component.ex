# lib/frestyl_web/live/studio_live/components/character_sheets_component.ex
defmodule FrestylWeb.StudioLive.CharacterSheetsComponent do
  @moduledoc """
  Character development and relationship tracking for collaborative storytelling.
  Supports character creation, relationship mapping, and collaborative editing.
  """

  use FrestylWeb, :live_component

  @character_archetypes [
    %{name: "Protagonist", description: "Main character driving the story"},
    %{name: "Antagonist", description: "Primary opposition or conflict source"},
    %{name: "Mentor", description: "Wise guide or teacher character"},
    %{name: "Ally", description: "Supporting character who helps the protagonist"},
    %{name: "Threshold Guardian", description: "Character who tests the protagonist"},
    %{name: "Shapeshifter", description: "Character whose loyalty/nature changes"},
    %{name: "Trickster", description: "Comic relief or catalyst character"},
    %{name: "Supporting", description: "Secondary character with specific role"}
  ]

  @relationship_types [
    "Family", "Friend", "Enemy", "Rival", "Mentor", "Student",
    "Romantic", "Professional", "Ally", "Neutral", "Unknown"
  ]

  @impl true
  def update(assigns, socket) do
    characters = get_characters(assigns)

    socket = socket
    |> assign(assigns)
    |> assign(:characters, characters)
    |> assign(:selected_character, nil)
    |> assign(:show_character_modal, false)
    |> assign(:show_relationship_modal, false)
    |> assign(:editing_character, nil)
    |> assign(:relationship_from, nil)
    |> assign(:relationship_to, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-white">
      <!-- Header -->
      <div class="flex items-center justify-between p-4 border-b border-gray-200 bg-gray-50">
        <div class="flex items-center space-x-3">
          <div class="w-8 h-8 rounded-lg bg-green-100 flex items-center justify-center">
            <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
            </svg>
          </div>
          <div>
            <h3 class="font-semibold text-gray-900">Characters</h3>
            <p class="text-sm text-gray-600"><%= length(@characters) %> characters</p>
          </div>
        </div>

        <button
          phx-click="show_character_modal"
          phx-target={@myself}
          class="bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded-lg text-sm font-medium"
        >
          Add Character
        </button>
      </div>

      <!-- Character Creation Modal -->
      <%= if @show_character_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50" phx-click="close_character_modal" phx-target={@myself}>
          <div class="bg-white rounded-xl shadow-xl max-w-lg w-full mx-4 max-h-96 overflow-y-auto" phx-click-away="close_character_modal" phx-target={@myself}>
            <form phx-submit="create_character" phx-target={@myself} class="p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Create New Character</h3>

              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Character Name</label>
                  <input type="text" name="name" required class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-green-500 focus:border-green-500" placeholder="Enter character name">
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Archetype</label>
                  <select name="archetype" class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-green-500 focus:border-green-500">
                    <%= for archetype <- @character_archetypes do %>
                      <option value={archetype.name}><%= archetype.name %> - <%= archetype.description %></option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Brief Description</label>
                  <textarea name="description" rows="3" class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-green-500 focus:border-green-500" placeholder="Brief character description"></textarea>
                </div>
              </div>

              <div class="flex justify-end space-x-3 mt-6">
                <button type="button" phx-click="close_character_modal" phx-target={@myself} class="px-4 py-2 text-gray-600 hover:text-gray-800">
                  Cancel
                </button>
                <button type="submit" class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg font-medium">
                  Create Character
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <!-- Character List/Grid -->
      <div class="flex-1 overflow-y-auto p-4">
        <%= if length(@characters) > 0 do %>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <%= for character <- @characters do %>
              <div class="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow group">
                <!-- Character Header -->
                <div class="flex items-start justify-between mb-3">
                  <div class="flex items-center space-x-3">
                    <div class={[
                      "w-10 h-10 rounded-full flex items-center justify-center text-white font-medium text-sm",
                      get_archetype_color(character.archetype)
                    ]}>
                      <%= String.at(character.name || "?", 0) %>
                    </div>
                    <div>
                      <h4 class="font-medium text-gray-900"><%= character.name %></h4>
                      <p class="text-sm text-gray-600"><%= character.archetype %></p>
                    </div>
                  </div>

                  <div class="flex items-center space-x-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button
                      phx-click="edit_character"
                      phx-value-character-id={character.id}
                      phx-target={@myself}
                      class="p-1 text-gray-400 hover:text-blue-600"
                      title="Edit Character"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                      </svg>
                    </button>
                    <button
                      phx-click="add_relationship"
                      phx-value-character-id={character.id}
                      phx-target={@myself}
                      class="p-1 text-gray-400 hover:text-green-600"
                      title="Add Relationship"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                      </svg>
                    </button>
                  </div>
                </div>

                <!-- Character Description -->
                <%= if character.description do %>
                  <p class="text-sm text-gray-700 mb-3 line-clamp-2"><%= character.description %></p>
                <% end %>

                <!-- Character Details Grid -->
                <div class="grid grid-cols-2 gap-3 text-xs">
                  <%= if character.age do %>
                    <div>
                      <span class="text-gray-500">Age:</span>
                      <span class="text-gray-900 font-medium ml-1"><%= character.age %></span>
                    </div>
                  <% end %>
                  <%= if character.occupation do %>
                    <div>
                      <span class="text-gray-500">Role:</span>
                      <span class="text-gray-900 font-medium ml-1"><%= character.occupation %></span>
                    </div>
                  <% end %>
                  <%= if character.motivation do %>
                    <div class="col-span-2">
                      <span class="text-gray-500">Goal:</span>
                      <span class="text-gray-900 font-medium ml-1"><%= character.motivation %></span>
                    </div>
                  <% end %>
                </div>

                <!-- Relationships -->
                <%= if Map.get(character, :relationships) && length(character.relationships) > 0 do %>
                  <div class="mt-3 pt-3 border-t border-gray-100">
                    <div class="flex items-center space-x-2 mb-2">
                      <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
                      </svg>
                      <span class="text-xs font-medium text-gray-600">Relationships</span>
                    </div>
                    <div class="space-y-1">
                      <%= for relationship <- Enum.take(character.relationships, 3) do %>
                        <div class="flex items-center justify-between text-xs">
                          <span class="text-gray-700"><%= relationship.target_name %></span>
                          <span class={[
                            "px-2 py-1 rounded text-xs font-medium",
                            get_relationship_color(relationship.type)
                          ]}>
                            <%= relationship.type %>
                          </span>
                        </div>
                      <% end %>
                      <%= if length(character.relationships) > 3 do %>
                        <div class="text-xs text-gray-500">+<%= length(character.relationships) - 3 %> more</div>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <!-- Collaboration Info -->
                <%= if Map.get(character, :last_edited_by) do %>
                  <div class="mt-3 pt-3 border-t border-gray-100 flex items-center justify-between text-xs text-gray-500">
                    <span>Last edited by <%= character.last_edited_by %></span>
                    <span><%= format_time_ago(character.updated_at) %></span>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% else %>
          <!-- Empty State -->
          <div class="text-center py-12">
            <div class="w-16 h-16 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No Characters Yet</h3>
            <p class="text-gray-600 mb-6">Start building your story by creating characters with distinct personalities and motivations.</p>
            <button
              phx-click="show_character_modal"
              phx-target={@myself}
              class="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-lg font-medium"
            >
              Create Your First Character
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("show_character_modal", _params, socket) do
    {:noreply, assign(socket, :show_character_modal, true)}
  end

  @impl true
  def handle_event("close_character_modal", _params, socket) do
    {:noreply, assign(socket, :show_character_modal, false)}
  end

  @impl true
  def handle_event("create_character", params, socket) do
    character = %{
      id: generate_character_id(),
      name: params["name"],
      archetype: params["archetype"],
      description: params["description"],
      age: nil,
      occupation: nil,
      motivation: nil,
      relationships: [],
      traits: [],
      backstory: "",
      goals: [],
      conflicts: [],
      created_by: socket.assigns.current_user.id,
      last_edited_by: socket.assigns.current_user.username,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    updated_characters = socket.assigns.characters ++ [character]

    # Broadcast to collaborators
    send(self(), {:update_characters, updated_characters})

    socket = socket
    |> assign(:characters, updated_characters)
    |> assign(:show_character_modal, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_character", %{"character-id" => character_id}, socket) do
    # Open detailed character editing modal/panel
    send(self(), {:open_character_editor, character_id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_relationship", %{"character-id" => character_id}, socket) do
    socket = socket
    |> assign(:show_relationship_modal, true)
    |> assign(:relationship_from, character_id)

    {:noreply, socket}
  end

  # Helper Functions

  defp get_characters(assigns) do
    # Get characters from workspace state or return empty list
    get_in(assigns, [:workspace_state, :story, :characters]) || []
  end

  defp get_archetype_color(archetype) do
    case archetype do
      "Protagonist" -> "bg-blue-600"
      "Antagonist" -> "bg-red-600"
      "Mentor" -> "bg-purple-600"
      "Ally" -> "bg-green-600"
      "Threshold Guardian" -> "bg-yellow-600"
      "Shapeshifter" -> "bg-indigo-600"
      "Trickster" -> "bg-pink-600"
      _ -> "bg-gray-600"
    end
  end

  defp get_relationship_color(relationship_type) do
    case relationship_type do
      "Family" -> "bg-blue-100 text-blue-800"
      "Friend" -> "bg-green-100 text-green-800"
      "Enemy" -> "bg-red-100 text-red-800"
      "Rival" -> "bg-orange-100 text-orange-800"
      "Mentor" -> "bg-purple-100 text-purple-800"
      "Romantic" -> "bg-pink-100 text-pink-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp generate_character_id do
    :crypto.strong_rand_bytes(8) |> Base.encode64() |> binary_part(0, 8)
  end

  defp format_time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :minute)

    cond do
      diff < 1 -> "just now"
      diff < 60 -> "#{diff}m ago"
      diff < 1440 -> "#{div(diff, 60)}h ago"
      true -> "#{div(diff, 1440)}d ago"
    end
  end
end
