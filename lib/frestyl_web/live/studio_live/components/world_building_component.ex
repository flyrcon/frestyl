# lib/frestyl_web/live/studio_live/components/world_building_component.ex
defmodule FrestylWeb.StudioLive.WorldBuildingComponent do
  @moduledoc """
  World building and lore management for collaborative storytelling.
  Manages shared universe details, continuity, and reference materials.
  """

  use FrestylWeb, :live_component

  @world_categories [
    %{key: "geography", name: "Geography", icon: "map", description: "Locations, maps, and physical world"},
    %{key: "history", name: "History", icon: "clock", description: "Timeline of events and background"},
    %{key: "culture", name: "Culture", icon: "academic-cap", description: "Societies, customs, and beliefs"},
    %{key: "technology", name: "Technology", icon: "cog", description: "Science, magic systems, and tools"},
    %{key: "politics", name: "Politics", icon: "scale", description: "Governments, factions, and conflicts"},
    %{key: "economy", name: "Economy", icon: "currency-dollar", description: "Trade, resources, and commerce"},
    %{key: "religion", name: "Religion", icon: "sparkles", description: "Beliefs, deities, and spiritual systems"},
    %{key: "languages", name: "Languages", icon: "chat-bubble", description: "Communication and linguistic systems"}
  ]

  @impl true
  def update(assigns, socket) do
    world_bible = get_world_bible(assigns)

    socket = socket
    |> assign(assigns)
    |> assign(:world_bible, world_bible)
    |> assign(:selected_category, "geography")
    |> assign(:show_entry_modal, false)
    |> assign(:editing_entry, nil)
    |> assign(:search_query, "")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-white">
      <!-- Header -->
      <div class="flex items-center justify-between p-4 border-b border-gray-200 bg-gray-50">
        <div class="flex items-center space-x-3">
          <div class="w-8 h-8 rounded-lg bg-indigo-100 flex items-center justify-center">
            <svg class="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
          </div>
          <div>
            <h3 class="font-semibold text-gray-900">World Bible</h3>
            <p class="text-sm text-gray-600">
              <%= get_total_entries(@world_bible) %> entries across <%= length(@world_categories) %> categories
            </p>
          </div>
        </div>

        <div class="flex items-center space-x-3">
          <!-- Search -->
          <div class="relative">
            <input
              type="text"
              placeholder="Search world..."
              value={@search_query}
              phx-change="search_world"
              phx-target={@myself}
              class="w-64 pl-10 pr-4 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            />
            <svg class="absolute left-3 top-2.5 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
            </svg>
          </div>

          <button
            phx-click="show_entry_modal"
            phx-target={@myself}
            class="bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-2 rounded-lg text-sm font-medium"
          >
            Add Entry
          </button>
        </div>
      </div>

      <!-- Category Tabs -->
      <div class="border-b border-gray-200 bg-white">
        <nav class="flex space-x-8 px-4" aria-label="Tabs">
          <%= for category <- @world_categories do %>
            <button
              phx-click="select_category"
              phx-value-category={category.key}
              phx-target={@myself}
              class={[
                "py-3 px-1 border-b-2 font-medium text-sm whitespace-nowrap transition-colors",
                if(@selected_category == category.key,
                   do: "border-indigo-500 text-indigo-600",
                   else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
              ]}
            >
              <div class="flex items-center space-x-2">
                <%= render_category_icon(category.icon) %>
                <span><%= category.name %></span>
                <span class="bg-gray-100 text-gray-600 ml-2 py-0.5 px-2 rounded-full text-xs">
                  <%= get_category_count(@world_bible, category.key) %>
                </span>
              </div>
            </button>
          <% end %>
        </nav>
      </div>

      <!-- Entry Creation Modal -->
      <%= if @show_entry_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50" phx-click="close_entry_modal" phx-target={@myself}>
          <div class="bg-white rounded-xl shadow-xl max-w-2xl w-full mx-4 max-h-[80vh] overflow-y-auto" phx-click-away="close_entry_modal" phx-target={@myself}>
            <form phx-submit="create_entry" phx-target={@myself} class="p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Add World Entry</h3>

              <div class="space-y-4">
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
                    <input type="text" name="title" required class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" placeholder="Entry title">
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Category</label>
                    <select name="category" class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
                      <%= for category <- @world_categories do %>
                        <option value={category.key} selected={@selected_category == category.key}>
                          <%= category.name %>
                        </option>
                      <% end %>
                    </select>
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Brief Summary</label>
                  <input type="text" name="summary" class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" placeholder="One-line description">
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Detailed Description</label>
                  <textarea name="content" rows="6" class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" placeholder="Detailed information about this world element"></textarea>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Tags (comma-separated)</label>
                  <input type="text" name="tags" class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" placeholder="important, secret, location">
                </div>

                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="flex items-center">
                      <input type="checkbox" name="is_public" class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" checked>
                      <span class="ml-2 text-sm text-gray-700">Visible to all collaborators</span>
                    </label>
                  </div>

                  <div>
                    <label class="flex items-center">
                      <input type="checkbox" name="is_canon" class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500">
                      <span class="ml-2 text-sm text-gray-700">Official canon</span>
                    </label>
                  </div>
                </div>
              </div>

              <div class="flex justify-end space-x-3 mt-6">
                <button type="button" phx-click="close_entry_modal" phx-target={@myself} class="px-4 py-2 text-gray-600 hover:text-gray-800">
                  Cancel
                </button>
                <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg font-medium">
                  Create Entry
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <!-- Content Area -->
      <div class="flex-1 overflow-y-auto p-4">
        <%= if get_filtered_entries(@world_bible, @selected_category, @search_query) |> length() > 0 do %>
          <div class="space-y-4">
            <%= for entry <- get_filtered_entries(@world_bible, @selected_category, @search_query) do %>
              <div class="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow group">
              <!-- Entry Header -->
                <div class="flex items-start justify-between mb-3">
                  <div class="flex-1">
                    <div class="flex items-center space-x-3 mb-1">
                      <h4 class="font-medium text-gray-900"><%= entry.title %></h4>
                      <%= if Map.get(entry, :is_canon, false) do %>
                        <span class="bg-green-100 text-green-800 text-xs font-medium px-2 py-1 rounded">Canon</span>
                      <% end %>
                      <%= if not Map.get(entry, :is_public, true) do %>
                        <span class="bg-yellow-100 text-yellow-800 text-xs font-medium px-2 py-1 rounded">Private</span>
                      <% end %>
                    </div>
                    <%= if Map.get(entry, :summary) do %>
                      <p class="text-sm text-gray-600 italic"><%= entry.summary %></p>
                    <% end %>
                  </div>

                  <div class="flex items-center space-x-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button
                      phx-click="edit_entry"
                      phx-value-entry-id={entry.id}
                      phx-target={@myself}
                      class="p-1 text-gray-400 hover:text-blue-600"
                      title="Edit Entry"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                      </svg>
                    </button>
                    <button
                      phx-click="delete_entry"
                      phx-value-entry-id={entry.id}
                      phx-target={@myself}
                      class="p-1 text-gray-400 hover:text-red-600"
                      title="Delete Entry"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                      </svg>
                    </button>
                  </div>
                </div>

                <!-- Entry Content -->
                <%= if Map.get(entry, :content) do %>
                  <div class="prose prose-sm max-w-none mb-3">
                    <p class="text-gray-700"><%= entry.content %></p>
                  </div>
                <% end %>

                <!-- Tags -->
                <%= if Map.get(entry, :tags) && length(entry.tags) > 0 do %>
                  <div class="flex flex-wrap gap-1 mb-3">
                    <%= for tag <- entry.tags do %>
                      <span class="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded">
                        #<%= tag %>
                      </span>
                    <% end %>
                  </div>
                <% end %>

                <!-- References and Connections -->
                <%= if Map.get(entry, :references) && length(entry.references) > 0 do %>
                  <div class="border-t border-gray-100 pt-3 mt-3">
                    <div class="flex items-center space-x-2 mb-2">
                      <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
                      </svg>
                      <span class="text-xs font-medium text-gray-600">Connected to</span>
                    </div>
                    <div class="flex flex-wrap gap-2">
                      <%= for reference <- entry.references do %>
                        <button
                          phx-click="navigate_to_entry"
                          phx-value-entry-id={reference.id}
                          phx-target={@myself}
                          class="text-xs text-indigo-600 hover:text-indigo-800 underline"
                        >
                          <%= reference.title %>
                        </button>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <!-- Collaboration Footer -->
                <div class="border-t border-gray-100 pt-3 mt-3 flex items-center justify-between text-xs text-gray-500">
                  <div class="flex items-center space-x-4">
                    <span>Created by <%= Map.get(entry, :created_by, "Unknown") %></span>
                    <%= if Map.get(entry, :last_edited_by) && entry.last_edited_by != Map.get(entry, :created_by) do %>
                      <span>• Edited by <%= entry.last_edited_by %></span>
                    <% end %>
                  </div>
                  <span><%= format_time_ago(Map.get(entry, :updated_at, DateTime.utc_now())) %></span>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <!-- Empty State -->
          <div class="text-center py-12">
            <%= if @search_query != "" do %>
              <!-- Search No Results -->
              <div class="w-16 h-16 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4">
                <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                </svg>
              </div>
              <h3 class="text-lg font-medium text-gray-900 mb-2">No Results Found</h3>
              <p class="text-gray-600 mb-4">No entries match "<%= @search_query %>" in <%= get_category_name(@selected_category) %>.</p>
              <button
                phx-click="clear_search"
                phx-target={@myself}
                class="text-indigo-600 hover:text-indigo-700 font-medium"
              >
                Clear search
              </button>
            <% else %>
              <!-- Category Empty State -->
              <div class="w-16 h-16 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4">
                <%= render_category_icon(get_selected_category_icon(@selected_category)) %>
              </div>
              <h3 class="text-lg font-medium text-gray-900 mb-2">
                No <%= get_category_name(@selected_category) %> Entries
              </h3>
              <p class="text-gray-600 mb-6">
                <%= get_category_description(@selected_category) %>
              </p>
              <button
                phx-click="show_entry_modal"
                phx-target={@myself}
                class="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-3 rounded-lg font-medium"
              >
                Add First Entry
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("select_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :selected_category, category)}
  end

  @impl true
  def handle_event("search_world", %{"value" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, assign(socket, :search_query, "")}
  end

  @impl true
  def handle_event("show_entry_modal", _params, socket) do
    {:noreply, assign(socket, :show_entry_modal, true)}
  end

  @impl true
  def handle_event("close_entry_modal", _params, socket) do
    {:noreply, assign(socket, :show_entry_modal, false)}
  end

  @impl true
  def handle_event("create_entry", params, socket) do
    tags = if params["tags"] && params["tags"] != "" do
      String.split(params["tags"], ",") |> Enum.map(&String.trim/1)
    else
      []
    end

    entry = %{
      id: generate_entry_id(),
      title: params["title"],
      category: params["category"],
      summary: params["summary"],
      content: params["content"],
      tags: tags,
      is_public: params["is_public"] == "true",
      is_canon: params["is_canon"] == "true",
      references: [],
      created_by: socket.assigns.current_user.username,
      last_edited_by: socket.assigns.current_user.username,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    # Add to world bible
    category_entries = Map.get(socket.assigns.world_bible, params["category"], [])
    updated_category_entries = category_entries ++ [entry]
    updated_world_bible = Map.put(socket.assigns.world_bible, params["category"], updated_category_entries)

    # Broadcast to collaborators
    send(self(), {:update_world_bible, updated_world_bible})

    socket = socket
    |> assign(:world_bible, updated_world_bible)
    |> assign(:show_entry_modal, false)
    |> assign(:selected_category, params["category"])

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_entry", %{"entry-id" => entry_id}, socket) do
    send(self(), {:open_world_entry_editor, entry_id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_entry", %{"entry-id" => entry_id}, socket) do
    updated_world_bible = remove_entry_from_world_bible(socket.assigns.world_bible, entry_id)
    send(self(), {:update_world_bible, updated_world_bible})
    {:noreply, assign(socket, :world_bible, updated_world_bible)}
  end

  @impl true
  def handle_event("navigate_to_entry", %{"entry-id" => entry_id}, socket) do
    case find_entry_by_id(socket.assigns.world_bible, entry_id) do
      {category, _entry} ->
        {:noreply, assign(socket, :selected_category, category)}
      nil ->
        {:noreply, socket}
    end
  end

  # Helper Functions

  defp get_world_bible(assigns) do
    get_in(assigns, [:workspace_state, :story, :world_bible]) || %{}
  end

  defp get_total_entries(world_bible) do
    world_bible
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp get_category_count(world_bible, category) do
    Map.get(world_bible, category, []) |> length()
  end

  defp get_filtered_entries(world_bible, category, search_query) do
    entries = Map.get(world_bible, category, [])

    if search_query == "" do
      entries
    else
      query_lower = String.downcase(search_query)
      Enum.filter(entries, fn entry ->
        String.contains?(String.downcase(entry.title), query_lower) ||
        String.contains?(String.downcase(entry.content || ""), query_lower) ||
        String.contains?(String.downcase(entry.summary || ""), query_lower) ||
        Enum.any?(entry.tags || [], &String.contains?(String.downcase(&1), query_lower))
      end)
    end
  end

  defp get_category_name(category_key) do
    case Enum.find(@world_categories, &(&1.key == category_key)) do
      %{name: name} -> name
      _ -> String.capitalize(category_key)
    end
  end

  defp get_category_description(category_key) do
    case Enum.find(@world_categories, &(&1.key == category_key)) do
      %{description: description} -> description
      _ -> "Add entries for this category."
    end
  end

  defp get_selected_category_icon(category_key) do
    case Enum.find(@world_categories, &(&1.key == category_key)) do
      %{icon: icon} -> icon
      _ -> "document"
    end
  end

  defp render_category_icon(icon_name) do
    case icon_name do
      "map" ->
        {:safe, ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"/></svg>)}
      "clock" ->
        {:safe, ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>)}
      "academic-cap" ->
        {:safe, ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z"/></svg>)}
      "cog" ->
        {:safe, ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>)}
      "scale" ->
        {:safe, ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 6l3 1m0 0l-3 9a5.002 5.002 0 006.001 0M6 7l3 9M6 7l6-2m6 2l3-1m-3 1l-3 9a5.002 5.002 0 006.001 0M18 7l3 9m-3-9l-6-2m0-2v2m0 16V5m0 16H9m3 0h3"/></svg>)}
      "currency-dollar" ->
        {:safe, ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>)}
      "sparkles" ->
        {:safe, ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z"/></svg>)}
      "chat-bubble" ->
        {:safe, ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/></svg>)}
      _ ->
        {:safe, ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>)}
    end
  end

  defp generate_entry_id do
    :crypto.strong_rand_bytes(8) |> Base.encode64() |> binary_part(0, 8)
  end

  defp remove_entry_from_world_bible(world_bible, entry_id) do
    Enum.reduce(world_bible, %{}, fn {category, entries}, acc ->
      filtered_entries = Enum.reject(entries, &(&1.id == entry_id))
      Map.put(acc, category, filtered_entries)
    end)
  end

  defp find_entry_by_id(world_bible, entry_id) do
    Enum.find_value(world_bible, fn {category, entries} ->
      case Enum.find(entries, &(&1.id == entry_id)) do
        nil -> nil
        entry -> {category, entry}
      end
    end)
  end

  defp format_time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :minute)

    case diff do
      diff when diff < 1 -> "just now"
      diff when diff < 60 -> "#{diff}m ago"
      diff when diff < 1440 -> "#{div(diff, 60)}h ago"
      diff -> "#{div(diff, 1440)}d ago"
    end
  end
end
