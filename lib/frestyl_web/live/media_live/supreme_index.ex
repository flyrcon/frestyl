defmodule FrestylWeb.MediaLive.SupremeIndex do
  use FrestylWeb, :live_view
  alias Frestyl.Media
  alias Frestyl.Accounts

  @impl true
  def mount(_params, session, socket) do
    # Get user from session or create anonymous user context
    user = get_user_from_session(session)

    # Set initial theme preference
    theme_preference = get_user_theme_preference(user)

    # Load initial media groups with error handling
    {media_groups, total_count} = safe_load_media_groups(user)

    socket =
      socket
      |> assign(:current_user, user)
      |> assign(:media_groups, media_groups)
      |> assign(:total_count, total_count)
      |> assign(:view_mode, "grid")
      |> assign(:current_theme, theme_preference)
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:selected_filters, %{})
      |> assign(:page_info, %{page: 1, per_page: 20, has_more: total_count > 20})

    {:ok, socket}
  rescue
    error ->
      {:ok, assign(socket, :error, "Failed to load media: #{inspect(error)}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Handle URL parameters for filtering and pagination
    filters = extract_filters(params)
    page = String.to_integer(params["page"] || "1")

    socket =
      socket
      |> assign(:selected_filters, filters)
      |> assign(:page_info, Map.put(socket.assigns.page_info, :page, page))
      |> reload_media_with_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_theme", %{"theme" => theme}, socket) do
    user = socket.assigns.current_user

    # Save theme preference if user exists
    if user do
      Media.update_user_theme_preference(user, theme)
    end

    {:noreply, assign(socket, :current_theme, theme)}
  end

  def handle_event("toggle_view_mode", _params, socket) do
    new_mode = if socket.assigns.view_mode == "grid", do: "list", else: "grid"
    {:noreply, assign(socket, :view_mode, new_mode)}
  end

  def handle_event("add_reaction", %{"group_id" => group_id, "reaction_type" => reaction_type}, socket) do
    user = socket.assigns.current_user

    case user && Media.add_group_reaction(group_id, user.id, reaction_type, socket.assigns.current_theme) do
      {:ok, _reaction} ->
        # Reload the specific group to show new reaction
        updated_groups = reload_single_group(socket.assigns.media_groups, group_id)
        {:noreply, assign(socket, :media_groups, updated_groups)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add reaction")}

      nil ->
        {:noreply, put_flash(socket, :info, "Please sign in to react")}
    end
  end

  def handle_event("apply_filters", %{"filters" => filters}, socket) do
    socket =
      socket
      |> assign(:selected_filters, filters)
      |> assign(:page_info, %{page: 1, per_page: 20, has_more: false})
      |> reload_media_with_filters()

    {:noreply, socket}
  end

  def handle_event("load_more", _params, socket) do
    page_info = socket.assigns.page_info
    next_page = page_info.page + 1

    {new_groups, total_count} = safe_load_media_groups(
      socket.assigns.current_user,
      socket.assigns.selected_filters,
      next_page,
      page_info.per_page
    )

    updated_groups = socket.assigns.media_groups ++ new_groups
    has_more = length(updated_groups) < total_count

    socket =
      socket
      |> assign(:media_groups, updated_groups)
      |> assign(:page_info, %{page: next_page, per_page: page_info.per_page, has_more: has_more})

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="supreme-discovery" class="min-h-screen" data-theme={@current_theme}>
      <!-- Theme Switcher -->
      <div class="fixed top-4 right-4 z-50">
        <div class="flex gap-2 p-2 bg-white/80 backdrop-blur rounded-lg shadow-lg">
          <button
            :for={theme <- available_themes()}
            phx-click="switch_theme"
            phx-value-theme={theme.id}
            class={["w-8 h-8 rounded-full border-2 transition-all",
                   theme_button_class(theme.id, @current_theme)]}
            style={"background: #{theme.color}"}
            title={theme.name}
          />
        </div>
      </div>

      <!-- Header -->
      <div class="p-4 bg-gradient-to-r from-purple-600 to-blue-600 text-white">
        <h1 class="text-2xl font-bold">Supreme Music Discovery</h1>
        <p class="opacity-90">Discover music with AI-powered intelligent grouping</p>

        <!-- View Mode Toggle -->
        <div class="mt-4 flex gap-2">
          <button
            phx-click="toggle_view_mode"
            class="px-4 py-2 bg-white/20 rounded-lg hover:bg-white/30 transition"
          >
            <%= if @view_mode == "grid", do: "📋 List View", else: "⊞ Grid View" %>
          </button>

          <div class="ml-auto text-sm opacity-75">
            <%= @total_count %> groups found
          </div>
        </div>
      </div>

      <!-- Error Display -->
      <div :if={@error} class="p-4 bg-red-100 border border-red-400 text-red-700">
        <p><strong>Error:</strong> <%= @error %></p>
      </div>

      <!-- Loading State -->
      <div :if={@loading} class="flex items-center justify-center py-12">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600"></div>
        <span class="ml-2">Loading revolutionary interface...</span>
      </div>

      <!-- Media Groups Display -->
      <div :if={!@loading and !@error} class="p-4">
        <%= if @view_mode == "grid" do %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div :for={group <- @media_groups} class="group-card bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-all">
              <.render_group_card group={group} theme={@current_theme} />
            </div>
          </div>
        <% else %>
          <div class="space-y-4">
            <div :for={group <- @media_groups} class="group-item bg-white rounded-lg shadow p-4 hover:shadow-md transition-all">
              <.render_group_list_item group={group} theme={@current_theme} />
            </div>
          </div>
        <% end %>

        <!-- Load More Button -->
        <div :if={@page_info.has_more} class="text-center mt-8">
          <button
            phx-click="load_more"
            class="px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition"
          >
            Load More Groups
          </button>
        </div>

        <!-- Empty State -->
        <div :if={Enum.empty?(@media_groups)} class="text-center py-12">
          <div class="text-6xl mb-4">🎵</div>
          <h3 class="text-xl font-semibold text-gray-600">No media groups found</h3>
          <p class="text-gray-500">Upload some music files to get started with intelligent discovery!</p>
        </div>
      </div>
    </div>
    """
  end

  # Helper function components
  defp render_group_card(assigns) do
    ~H"""
    <div class="relative">
      <!-- Thumbnail -->
      <div class="aspect-square bg-gradient-to-br from-purple-500 to-blue-500 relative overflow-hidden">
        <%= if @group.thumbnail_url do %>
          <img src={@group.thumbnail_url} alt={@group.name} class="w-full h-full object-cover" />
        <% else %>
          <div class="w-full h-full flex items-center justify-center text-white text-4xl">
            🎵
          </div>
        <% end %>

        <!-- Reaction Overlay -->
        <div class="absolute bottom-2 right-2 flex gap-1">
          <button
            :for={reaction <- quick_reactions()}
            phx-click="add_reaction"
            phx-value-group-id={@group.id}
            phx-value-reaction-type={reaction}
            class="w-8 h-8 bg-black/50 text-white rounded-full hover:bg-black/70 transition text-sm"
          >
            <%= reaction_emoji(reaction) %>
          </button>
        </div>
      </div>

      <!-- Content -->
      <div class="p-4">
        <h3 class="font-semibold text-lg truncate"><%= @group.name %></h3>
        <p class="text-sm text-gray-600 capitalize"><%= @group.group_type %></p>
        <p class="text-xs text-gray-500"><%= @group.file_count %> files</p>

        <!-- Tags -->
        <div class="mt-2 flex flex-wrap gap-1">
          <span
            :for={tag <- (@group.tags || [])}
            class="px-2 py-1 bg-purple-100 text-purple-700 text-xs rounded"
          >
            <%= tag %>
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp render_group_list_item(assigns) do
    ~H"""
    <div class="flex items-center gap-4">
      <!-- Thumbnail -->
      <div class="w-16 h-16 bg-gradient-to-br from-purple-500 to-blue-500 rounded-lg flex-shrink-0 flex items-center justify-center text-white">
        <%= if @group.thumbnail_url do %>
          <img src={@group.thumbnail_url} alt={@group.name} class="w-full h-full object-cover rounded-lg" />
        <% else %>
          🎵
        <% end %>
      </div>

      <!-- Content -->
      <div class="flex-1 min-w-0">
        <h3 class="font-semibold truncate"><%= @group.name %></h3>
        <p class="text-sm text-gray-600 capitalize"><%= @group.group_type %></p>
        <p class="text-xs text-gray-500"><%= @group.file_count %> files</p>
      </div>

      <!-- Actions -->
      <div class="flex gap-2">
        <button
          :for={reaction <- quick_reactions()}
          phx-click="add_reaction"
          phx-value-group-id={@group.id}
          phx-value-reaction-type={reaction}
          class="w-8 h-8 bg-gray-100 hover:bg-gray-200 rounded-full transition text-sm"
        >
          <%= reaction_emoji(reaction) %>
        </button>
      </div>
    </div>
    """
  end

  # Private helper functions
  defp get_user_from_session(session) do
    # Try different session keys that might exist
    cond do
      session["user_id"] ->
        try do
          Frestyl.Repo.get(Frestyl.Accounts.User, session["user_id"])
        rescue
          _ -> nil
        end
      session["current_user_id"] ->
        try do
          Frestyl.Repo.get(Frestyl.Accounts.User, session["current_user_id"])
        rescue
          _ -> nil
        end
      true -> nil
    end
  rescue
    _ -> nil
  end

  defp get_user_theme_preference(nil), do: "cosmic_dreams"
  defp get_user_theme_preference(user) do
    case Media.get_user_theme_preference(user.id) do
      %{current_theme: theme} -> theme
      _ -> "cosmic_dreams"
    end
  rescue
    _ -> "cosmic_dreams"
  end

  defp safe_load_media_groups(user, filters \\ %{}, page \\ 1, per_page \\ 20) do
    try do
      user_id = if user, do: user.id, else: nil

      case Media.list_intelligent_groups(user_id, filters, page: page, per_page: per_page) do
        {groups, count} when is_list(groups) -> {groups, count}
        groups when is_list(groups) -> {groups, length(groups)}
        _ -> {[], 0}
      end
    rescue
      error ->
        IO.inspect(error, label: "Error loading media groups")
        {[], 0}
    end
  end

  defp reload_media_with_filters(socket) do
    {groups, total_count} = safe_load_media_groups(
      socket.assigns.current_user,
      socket.assigns.selected_filters,
      1,
      socket.assigns.page_info.per_page
    )

    socket
    |> assign(:media_groups, groups)
    |> assign(:total_count, total_count)
    |> assign(:page_info, Map.put(socket.assigns.page_info, :has_more, total_count > length(groups)))
  end

  defp reload_single_group(groups, group_id) do
    # In a real implementation, you'd reload just this group
    # For now, return the existing groups
    groups
  end

  defp extract_filters(params) do
    %{}
    |> maybe_add_filter("type", params["type"])
    |> maybe_add_filter("tag", params["tag"])
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp available_themes do
    [
      %{id: "cosmic_dreams", name: "Cosmic Dreams", color: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"},
      %{id: "neon_cyberpunk", name: "Neon Cyberpunk", color: "linear-gradient(135deg, #f093fb 0%, #f5576c 100%)"},
      %{id: "liquid_flow", name: "Liquid Flow", color: "linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)"},
      %{id: "crystal_matrix", name: "Crystal Matrix", color: "linear-gradient(135deg, #43e97b 0%, #38f9d7 100%)"},
      %{id: "organic_growth", name: "Organic Growth", color: "linear-gradient(135deg, #fa709a 0%, #fee140 100%)"},
      %{id: "clean_paper", name: "Clean Paper", color: "#ffffff"}
    ]
  end

  defp theme_button_class(theme_id, current_theme) do
    if theme_id == current_theme do
      "border-gray-800 scale-110"
    else
      "border-gray-300 hover:border-gray-500"
    end
  end

  defp quick_reactions, do: ["love", "fire", "star"]

  defp reaction_emoji("love"), do: "💖"
  defp reaction_emoji("fire"), do: "🔥"
  defp reaction_emoji("star"), do: "⭐"
  defp reaction_emoji(_), do: "👍"
end
