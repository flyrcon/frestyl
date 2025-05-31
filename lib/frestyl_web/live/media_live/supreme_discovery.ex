defmodule FrestylWeb.MediaLive.SupremeDiscovery do
  use FrestylWeb, :live_view
  alias Frestyl.{Media, Accounts}
  alias FrestylWeb.Navigation



  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Load real user data instead of demo data
    case load_user_media_data(user.id) do
      {:ok, media_data} ->
        planetary_cards = convert_media_to_planetary_cards(media_data)
        user_theme_prefs = get_user_theme_preferences(user.id)

        socket =
          socket
          |> assign(:current_user, user)
          |> assign(:planetary_cards, planetary_cards)
          |> assign(:current_theme, user_theme_prefs.current_theme)
          |> assign(:view_mode, user_theme_prefs.preferred_view_mode)
          |> assign(:current_card_index, 0)
          |> assign(:total_cards, length(planetary_cards))
          |> assign(:show_preview_modal, false)
          |> assign(:preview_card, nil)
          |> assign(:auto_theme_switching, user_theme_prefs.auto_switch_themes)
          |> assign(:loading, false)
          |> assign(:page_title, "Supreme Discovery")
          |> assign(:assembling_card, nil)
          |> assign(:filter_type, "all")
          |> assign(:search_query, "")  # ✅ FIXED: Added missing search_query
          |> assign(:show_media_preview, false)
          |> assign(:preview_media_file, nil)
          |> assign(:media_nav_index, 0)

        subscribe_to_updates(user.id)
        {:ok, socket}

      {:error, _reason} ->
        # Fallback to demo data if real data fails
        socket =
          socket
          |> assign(:current_user, user)
          |> assign(:planetary_cards, create_demo_planetary_cards())
          |> assign(:current_theme, "cosmic_dreams")
          |> assign(:view_mode, "discovery")
          |> assign(:current_card_index, 0)
          |> assign(:total_cards, 7)
          |> assign(:show_preview_modal, false)
          |> assign(:preview_card, nil)
          |> assign(:auto_theme_switching, false)
          |> assign(:loading, false)
          |> assign(:page_title, "Supreme Discovery")
          |> assign(:assembling_card, nil)
          |> assign(:filter_type, "all")
          |> assign(:search_query, "")  # ✅ FIXED: Added missing search_query
          |> assign(:show_media_preview, false)
          |> assign(:preview_media_file, nil)
          |> assign(:media_nav_index, 0)

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = apply_url_filters(socket, params)
    {:noreply, socket}
  end

  @impl true
  def handle_event("swipe_next", _params, socket) do
    current = socket.assigns.current_card_index
    total = socket.assigns.total_cards
    new_index = if current + 1 >= total, do: 0, else: current + 1

    socket = socket
    |> assign(:assembling_card, new_index)
    |> assign(:current_card_index, new_index)
    |> maybe_auto_switch_theme(new_index)

    Process.send_after(self(), :clear_assembly, 1200) # Increased from 800ms
    {:noreply, socket}
  end

  def handle_event("swipe_prev", _params, socket) do
    current = socket.assigns.current_card_index
    total = socket.assigns.total_cards
    new_index = if current - 1 < 0, do: total - 1, else: current - 1

    socket = socket
    |> assign(:assembling_card, new_index)
    |> assign(:current_card_index, new_index)
    |> maybe_auto_switch_theme(new_index)

    Process.send_after(self(), :clear_assembly, 1200) # Increased from 800ms
    {:noreply, socket}
  end

  def handle_event("navigate_to_card", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    total = socket.assigns.total_cards
    new_index = max(0, min(index, total - 1))

    socket = socket
    |> assign(:assembling_card, new_index)
    |> assign(:current_card_index, new_index)
    |> maybe_auto_switch_theme(new_index)

    Process.send_after(self(), :clear_assembly, 1200)
    {:noreply, socket}
  end

  # Mobile-friendly key navigation
  def handle_event("key_navigation", %{"key" => key}, socket) do
    case key do
      "ArrowLeft" -> handle_event("swipe_prev", %{}, socket)
      "ArrowRight" -> handle_event("swipe_next", %{}, socket)
      "Escape" ->
        if socket.assigns.show_preview_modal do
          handle_event("close_preview", %{}, socket)
        else
          {:noreply, socket}
        end
      " " -> # Spacebar to open current media
        current_card = Enum.at(socket.assigns.planetary_cards, socket.assigns.current_card_index)
        if current_card do
          handle_event("expand_planet", %{"card_id" => current_card.id}, socket)
        else
          {:noreply, socket}
        end
      _ -> {:noreply, socket}
    end
  end

  def handle_event("switch_theme", %{"theme" => theme}, socket) do
    user = socket.assigns.current_user

    case update_user_theme(user.id, theme) do
      {:ok, _} ->
        broadcast_theme_change(user.id, theme)
        {:noreply, assign(socket, :current_theme, theme)}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save theme")}
    end
  end

  def handle_event("toggle_view_mode", _params, socket) do
    current_mode = socket.assigns.view_mode
    new_mode = case current_mode do
      "discovery" -> "grid"
      "grid" -> "list"
      "list" -> "discovery"
    end

    # Save user preference
    user = socket.assigns.current_user
    update_user_view_mode(user.id, new_mode)

    {:noreply, assign(socket, :view_mode, new_mode)}
  end

  # Enhanced media preview with navigation
  def handle_event("expand_planet", %{"card_id" => card_id}, socket) do
    card = find_card_by_id(socket.assigns.planetary_cards, card_id)

    if card do
      # Convert card to media file for preview
      media_file = convert_card_to_media_file(card)

      # Record view
      if media_file.id do
        Media.record_view(%{
          media_file_id: media_file.id,
          user_id: socket.assigns.current_user.id,
          metadata: %{source: "supreme_discovery"}
        })
      end

      socket = socket
      |> assign(:show_media_preview, true)
      |> assign(:preview_media_file, media_file)
      |> assign(:media_nav_index, find_card_index(socket.assigns.planetary_cards, card_id))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_preview", _params, socket) do
    socket = socket
    |> assign(:show_media_preview, false)
    |> assign(:preview_media_file, nil)
    |> assign(:media_nav_index, 0)
    {:noreply, socket}
  end

  # Media navigation in preview
  def handle_event("navigate_media_prev", _params, socket) do
    current_index = socket.assigns.media_nav_index
    total = socket.assigns.total_cards
    new_index = if current_index - 1 < 0, do: total - 1, else: current_index - 1

    new_card = Enum.at(socket.assigns.planetary_cards, new_index)
    if new_card do
      media_file = convert_card_to_media_file(new_card)

      socket = socket
      |> assign(:preview_media_file, media_file)
      |> assign(:media_nav_index, new_index)
      |> assign(:current_card_index, new_index) # Keep discovery in sync

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("navigate_media_next", _params, socket) do
    current_index = socket.assigns.media_nav_index
    total = socket.assigns.total_cards
    new_index = if current_index + 1 >= total, do: 0, else: current_index + 1

    new_card = Enum.at(socket.assigns.planetary_cards, new_index)
    if new_card do
      media_file = convert_card_to_media_file(new_card)

      socket = socket
      |> assign(:preview_media_file, media_file)
      |> assign(:media_nav_index, new_index)
      |> assign(:current_card_index, new_index) # Keep discovery in sync

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("add_reaction", %{"type" => reaction_type, "target_id" => target_id, "target_type" => target_type}, socket) do
    user = socket.assigns.current_user
    case add_user_reaction(user.id, target_id, target_type, reaction_type) do
      {:ok, _reaction} -> {:noreply, socket}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to add reaction")}
    end
  end

  def handle_event("toggle_auto_theme", _params, socket) do
    user = socket.assigns.current_user
    current_setting = socket.assigns.auto_theme_switching
    new_setting = !current_setting

    case update_auto_theme_setting(user.id, new_setting) do
      {:ok, _} -> {:noreply, assign(socket, :auto_theme_switching, new_setting)}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_event("search", %{"query" => query}, socket) do
    filtered_cards = filter_cards(socket.assigns.planetary_cards, query, socket.assigns.filter_type)

    socket = socket
    |> assign(:search_query, query)
    |> assign(:planetary_cards, filtered_cards)
    |> assign(:total_cards, length(filtered_cards))
    |> assign(:current_card_index, 0) # Reset to first card

    {:noreply, socket}
  end

  def handle_event("filter_type", %{"type" => type}, socket) do
    # Reload cards with filter
    user = socket.assigns.current_user
    {:ok, media_data} = load_user_media_data(user.id, %{filter_type: type})
    planetary_cards = convert_media_to_planetary_cards(media_data)

    socket = socket
    |> assign(:filter_type, type)
    |> assign(:planetary_cards, planetary_cards)
    |> assign(:total_cards, length(planetary_cards))
    |> assign(:current_card_index, 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:clear_assembly, socket) do
    {:noreply, assign(socket, :assembling_card, nil)}
  end

  def handle_info({:theme_changed, new_theme}, socket) do
    {:noreply, assign(socket, :current_theme, new_theme)}
  end

  def handle_info({:media_file_updated, updated_file}, socket) do
    updated_cards = update_card_data(socket.assigns.planetary_cards, updated_file)
    {:noreply, assign(socket, :planetary_cards, updated_cards)}
  end

  def handle_info({:reaction_update, _data}, socket) do
    {:noreply, socket}
  end

  def handle_info(:close_media_preview, socket) do
    socket = socket
    |> assign(:show_media_preview, false)
    |> assign(:preview_media_file, nil)
    {:noreply, socket}
  end

  def handle_info(:navigate_prev_media, socket) do
    handle_event("navigate_media_prev", %{}, socket)
  end

  def handle_info(:navigate_next_media, socket) do
    handle_event("navigate_media_next", %{}, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <!-- Add Navigation -->
      <FrestylWeb.Navigation.nav current_user={@current_user} active_tab={:media} />

      <!-- Main Content -->
      <div class="pt-16"> <!-- Account for fixed nav -->
        <div
          class="supreme-discovery min-h-screen overflow-hidden relative"
          data-theme={@current_theme}
          phx-hook="SupremeDiscovery"
          id="supreme-discovery-container"
          phx-window-keydown="key_navigation"
          tabindex="0"
        >
          <.enhanced_theme_styles theme={@current_theme} />
          <.ambient_background theme={@current_theme} />

          <%= case @view_mode do %>
            <% "discovery" -> %>
              <.mobile_optimized_discovery_mode
                cards={@planetary_cards}
                current_index={@current_card_index}
                current_theme={@current_theme}
                current_user={@current_user}
                assembling_card={@assembling_card}
                search_query={@search_query}
                filter_type={@filter_type}
              />
            <% "grid" -> %>
              <.enhanced_grid_mode
                cards={@planetary_cards}
                current_theme={@current_theme}
                current_user={@current_user}
              />
            <% "list" -> %>
              <.enhanced_list_mode
                cards={@planetary_cards}
                current_theme={@current_theme}
                current_user={@current_user}
              />
          <% end %>

          <.mobile_control_panel
            current_theme={@current_theme}
            view_mode={@view_mode}
            auto_theme_switching={@auto_theme_switching}
            current_index={@current_card_index}
            total_cards={@total_cards}
            search_query={@search_query}
            filter_type={@filter_type}
          />

          <%= if @show_media_preview and @preview_media_file do %>
            <.live_component
              module={FrestylWeb.MediaLive.MediaPreviewModalComponent}
              id="media-preview-modal"
              file={@preview_media_file}
              current_user={@current_user}
              has_prev={@media_nav_index > 0}
              has_next={@media_nav_index < @total_cards - 1}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # MOBILE-OPTIMIZED DISCOVERY MODE
  defp mobile_optimized_discovery_mode(assigns) do
    ~H"""
    <div class="discovery-mode relative h-screen overflow-hidden">
      <!-- Mobile Search Bar -->
      <div class="absolute top-4 left-4 right-4 z-50 lg:hidden">
        <div class="flex space-x-2">
          <input
            type="text"
            placeholder="Search media..."
            value={assigns[:search_query] || ""}
            phx-keyup="search"
            phx-debounce="300"
            class="flex-1 px-4 py-2 bg-white/20 backdrop-blur-md border border-white/30 rounded-xl text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/40"
          />
          <select
            phx-change="filter_type"
            class="px-3 py-2 bg-white/20 backdrop-blur-md border border-white/30 rounded-xl text-white focus:outline-none"
          >
            <option value="all" selected={assigns[:filter_type] == "all"}>All</option>
            <option value="audio" selected={assigns[:filter_type] == "audio"}>Audio</option>
            <option value="image" selected={assigns[:filter_type] == "image"}>Images</option>
            <option value="video" selected={assigns[:filter_type] == "video"}>Videos</option>
            <option value="document" selected={assigns[:filter_type] == "document"}>Docs</option>
          </select>
        </div>
      </div>

      <!-- Main Cards Container - MOBILE CENTERED -->
      <div class="axis-container relative h-full flex items-center justify-center px-4">
        <div
          style={"transform: translateX(calc(-#{@current_index * 100}vw + 50vw - 50%));"}
        >
          <%= for {card, index} <- Enum.with_index(@cards) do %>
            <div class={[
              "axis-item flex-shrink-0 w-screen flex items-center justify-center px-4",
              get_mobile_axis_item_classes(index, @current_index),
              if(@assembling_card == index, do: "assembling", else: "")
            ]}>
              <.mobile_information_cluster
                card={card}
                is_focused={index == @current_index}
                current_user={@current_user}
                theme={@current_theme}
                assembling={@assembling_card == index}
                position={get_axis_position(index, @current_index)}
              />
            </div>
          <% end %>
        </div>
      </div>

      <!-- Mobile Touch Areas -->
      <div class="absolute left-0 top-20 bottom-20 w-1/3 z-30" phx-click="swipe_prev"></div>
      <div class="absolute right-0 top-20 bottom-20 w-1/3 z-30" phx-click="swipe_next"></div>

      <!-- Mobile Navigation Dots -->
      <div class="absolute bottom-8 left-1/2 transform -translate-x-1/2 z-40">
        <.mobile_axis_navigation
          current_index={@current_index}
          total_cards={length(@cards)}
        />
      </div>
    </div>
    """
  end

  # MOBILE-OPTIMIZED INFORMATION CLUSTER
  defp mobile_information_cluster(assigns) do
    ~H"""
    <div class={[
      "information-cluster relative w-full max-w-sm mx-auto",
      get_mobile_cluster_size_classes(@position)
    ]} data-card-id={@card.id}>
      <div class="cluster-core relative bg-white/10 backdrop-blur-md rounded-3xl p-6 border border-white/20">

        <!-- Media Visual - Larger on mobile -->
        <div class="component media-visual flex justify-center mb-6" style="--start-x: 0px; --start-y: -30px;">
          <.mobile_media_visualization
            card={@card}
            theme={@theme}
            is_focused={@is_focused}
          />
        </div>

        <!-- Info Cluster -->
        <div class="component info-cluster text-center" style="--start-x: 0px; --start-y: 20px;">
          <h3 class={[
            "font-bold mb-3 transition-all duration-500",
            if(@is_focused, do: "text-xl", else: "text-lg opacity-70")
          ]} style="color: var(--text-primary);">
            <%= get_card_title(@card) %>
          </h3>

          <p class={[
            "transition-all duration-500 mb-4",
            if(@is_focused, do: "text-sm opacity-80", else: "text-xs opacity-50")
          ]} style="color: var(--text-secondary);">
            <%= get_card_description(@card) %>
          </p>

          <%= if @is_focused and has_metadata?(@card) do %>
            <div class="component metadata-tags flex flex-wrap justify-center gap-2 mb-4" style="--start-x: 0px; --start-y: 10px;">
              <%= if genre = get_in(@card, [:music_metadata, :genre]) do %>
                <div class="px-3 py-1 rounded-full text-xs font-medium" style="background: var(--accent-glow); color: var(--text-primary);">
                  <%= genre %>
                </div>
              <% end %>
              <%= if bpm = get_in(@card, [:music_metadata, :bpm]) do %>
                <div class="px-3 py-1 rounded-full text-xs font-medium" style="background: var(--surface); color: var(--text-secondary);">
                  <%= round(bpm) %> BPM
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <%= if @is_focused do %>
          <div class="component action-cluster text-center mt-6" style="--start-x: 0px; --start-y: 30px;">
            <button
              phx-click="expand_planet"
              phx-value-card_id={@card.id}
              class="w-full px-6 py-3 rounded-2xl transition-all duration-300 hover:scale-105 font-medium text-lg"
              style="background: var(--accent); color: white;"
            >
              <span class="mr-2">🚀</span> Explore
            </button>
          </div>
        <% end %>

        <%= if @is_focused do %>
          <div class="absolute inset-0 -z-10 rounded-3xl opacity-20 blur-xl" style="background: var(--accent);"></div>
        <% end %>
      </div>
    </div>
    """
  end

  # Mobile-specific helper functions
  defp get_mobile_axis_item_classes(index, current_index) do
    distance = abs(index - current_index)

    cond do
      distance == 0 -> "z-20 scale-100 opacity-100"
      distance == 1 -> "z-10 scale-75 opacity-40"
      true -> "z-5 scale-50 opacity-20"
    end
  end

  defp get_mobile_cluster_size_classes(position) do
    case position do
      :focused -> "transform scale-100"
      :adjacent -> "transform scale-90"
      :distant -> "transform scale-75"
    end
  end

  # Mobile media visualization
  defp mobile_media_visualization(assigns) do
    ~H"""
    <div class={[
      "media-visual relative transition-all duration-500",
      if(@is_focused, do: "w-32 h-32", else: "w-24 h-24 opacity-60")
    ]}>
      <%= case determine_media_type(@card) do %>
        <% :audio -> %>
          <div class="relative w-full h-full">
            <div class="w-full h-full rounded-2xl overflow-hidden relative" style="background: linear-gradient(135deg, #8b5cf6, #ec4899);">
              <div class="absolute inset-2 rounded-xl bg-gradient-to-br from-purple-300/30 to-pink-300/30 flex items-center justify-center">
                <svg class={[
                  "text-white transition-all duration-500",
                  if(@is_focused, do: "w-8 h-8", else: "w-6 h-6")
                ]} fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/>
                </svg>
              </div>
              <%= if @is_focused do %>
                <div class="absolute top-1 right-1 px-1 py-0.5 bg-black/50 backdrop-blur-sm rounded text-xs font-medium text-white">
                  ♪
                </div>
              <% end %>
            </div>
          </div>

        <% :image -> %>
          <div class="relative w-full h-full">
            <div class="w-full h-full rounded-2xl overflow-hidden relative" style="background: linear-gradient(135deg, #ec4899, #8b5cf6);">
              <div class="absolute inset-2 rounded-xl bg-gradient-to-br from-pink-300/30 to-purple-300/30 flex items-center justify-center">
                <svg class={[
                  "text-white transition-all duration-500",
                  if(@is_focused, do: "w-8 h-8", else: "w-6 h-6")
                ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
              </div>
            </div>
          </div>

        <% :video -> %>
          <div class="relative w-full h-full">
            <div class="w-full h-full rounded-2xl overflow-hidden relative" style="background: linear-gradient(135deg, #ef4444, #f97316);">
              <div class="absolute inset-2 rounded-xl bg-gradient-to-br from-red-300/30 to-orange-300/30 flex items-center justify-center">
                <svg class={[
                  "text-white transition-all duration-500",
                  if(@is_focused, do: "w-8 h-8", else: "w-6 h-6")
                ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
              </div>
              <%= if @is_focused do %>
                <div class="absolute inset-0 flex items-center justify-center">
                  <div class="w-8 h-8 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center">
                    <svg class="w-4 h-4 text-white ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M8 5v14l11-7z"/>
                    </svg>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

        <% _ -> %>
          <div class="relative w-full h-full">
            <div class="w-full h-full rounded-2xl overflow-hidden relative" style="background: linear-gradient(135deg, #6b7280, #374151);">
              <div class="absolute inset-2 rounded-xl bg-gradient-to-br from-gray-300/30 to-gray-400/30 flex items-center justify-center">
                <svg class={[
                  "text-white transition-all duration-500",
                  if(@is_focused, do: "w-8 h-8", else: "w-6 h-6")
                ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              </div>
            </div>
          </div>
      <% end %>
    </div>
    """
  end

  defp mobile_axis_navigation(assigns) do
    ~H"""
    <div class="axis-nav flex items-center space-x-4">
      <button
        phx-click="swipe_prev"
        class="w-10 h-10 bg-white/10 backdrop-blur-sm border border-white/20 rounded-full flex items-center justify-center text-white/80 hover:text-white hover:bg-white/20 transition-all duration-300"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
      </button>

      <div class="flex space-x-2">
        <%= for index <- 0..min(@total_cards - 1, 7) do %>
          <button
            phx-click="navigate_to_card"
            phx-value-index={index}
            class={[
              "w-2 h-2 rounded-full transition-all duration-300",
              if(index == @current_index,
                do: "bg-white scale-125",
                else: "bg-white/40 hover:bg-white/60")
            ]}
          ></button>
        <% end %>

        <%= if @total_cards > 8 do %>
          <div class="text-white/40 text-xs ml-2 flex items-center">+<%= @total_cards - 8 %></div>
        <% end %>
      </div>

      <button
        phx-click="swipe_next"
        class="w-10 h-10 bg-white/10 backdrop-blur-sm border border-white/20 rounded-full flex items-center justify-center text-white/80 hover:text-white hover:bg-white/20 transition-all duration-300"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </button>
    </div>
    """
  end

  defp mobile_control_panel(assigns) do
    ~H"""
    <div class="mobile-controls fixed top-20 right-4 space-y-3 z-50 lg:top-6">
      <!-- Theme Switcher -->
      <div class="control-panel p-3 bg-white/10 backdrop-blur-md border border-white/20 rounded-xl">
        <div class="grid grid-cols-2 gap-2">
          <%= for {theme_id, theme_data} <- get_available_themes() do %>
            <button
              phx-click="switch_theme"
              phx-value-theme={theme_id}
              class={[
                "w-8 h-5 rounded transition-all duration-300",
                theme_data.preview_bg,
                if(@current_theme == theme_id, do: "ring-2 ring-white scale-110", else: "hover:scale-105")
              ]}
              title={theme_data.name}
            ></button>
          <% end %>
        </div>
      </div>

      <!-- View Mode Toggle -->
      <button
        phx-click="toggle_view_mode"
        class="control-panel w-12 h-12 flex items-center justify-center bg-white/10 backdrop-blur-md border border-white/20 rounded-xl transition-all"
        style="color: var(--text-secondary);"
        title={"Switch from #{@view_mode} mode"}
      >
        <%= case @view_mode do %>
          <% "discovery" -> %>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>
            </svg>
          <% "grid" -> %>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>
            </svg>
          <% "list" -> %>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
            </svg>
        <% end %>
      </button>

      <!-- Progress Indicator -->
      <div class="control-panel px-3 py-2 text-xs font-medium text-center bg-white/10 backdrop-blur-md border border-white/20 rounded-xl" style="color: var(--text-secondary);">
        <%= @current_index + 1 %> / <%= @total_cards %>
      </div>
    </div>
    """
  end

  # Data loading and conversion functions
  defp load_user_media_data(user_id, opts \\ %{}) do
    try do
      # Try to load real media data
      filter_type = Map.get(opts, :filter_type, "all")

      # Use your existing Media.list_media_files_for_user function
      media_files = Media.list_media_files_for_user(user_id,
        channel_id: nil,
        file_type: if(filter_type == "all", do: nil, else: filter_type),
        limit: 50
      )

      if length(media_files) > 0 do
        {:ok, %{files: media_files, groups: []}}
      else
        {:error, :no_media}
      end
    rescue
      _ -> {:error, :function_not_available}
    catch
      _ -> {:error, :no_data}
    end
  end

  defp convert_media_to_planetary_cards(media_data) do
    media_data.files
    |> Enum.map(&convert_media_file_to_card/1)
    |> Enum.with_index()
    |> Enum.map(fn {card, index} -> Map.put(card, :id, "card_#{index}") end)
  end

  defp convert_media_file_to_card(media_file) do
    %{
      id: "file_#{media_file.id}",
      type: :individual_file,
      planet: %{
        file: %{
          id: media_file.id,
          title: media_file.filename,
          original_filename: media_file.filename
        },
        type: determine_planet_type_from_file(media_file)
      },
      satellites: [],
      metadata: %{},
      music_metadata: get_file_music_metadata(media_file),
      media_file: media_file
    }
  end

  defp determine_planet_type_from_file(media_file) do
    case media_file.file_type do
      type when type in ["audio", "mp3", "wav", "flac"] -> :audio
      type when type in ["image", "jpg", "png", "gif"] -> :image
      type when type in ["video", "mp4", "mov", "avi"] -> :video
      _ -> :document
    end
  end

  defp determine_media_type(card) do
    case Map.get(card, :planet) do
      %{type: type} -> type
      _ -> :document
    end
  end

  defp get_file_music_metadata(media_file) do
    # Try to get music metadata if available
    case Media.get_music_metadata(media_file.id) do
      %{} = metadata -> metadata
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  defp get_user_theme_preferences(user_id) do
    try do
      case Accounts.get_user_theme_preferences(user_id) do
        %{} = prefs -> prefs
        _ -> create_default_theme_prefs()
      end
    rescue
      _ -> create_default_theme_prefs()
    catch
      _ -> create_default_theme_prefs()
    end
  end

  defp create_default_theme_prefs do
    %{
      current_theme: "cosmic_dreams",
      preferred_view_mode: "discovery",
      auto_switch_themes: false
    }
  end

  defp convert_card_to_media_file(card) do
    # Convert planetary card back to media file format for preview
    case Map.get(card, :media_file) do
      %{} = media_file ->
        # Add the missing media_type field
        Map.put(media_file, :media_type, media_file.file_type)
      _ ->
        # Fallback: create a minimal media file struct
        file_type = determine_media_type(card) |> Atom.to_string()
        %{
          id: get_in(card, [:planet, :file, :id]) || 1,
          filename: get_in(card, [:planet, :file, :title]) || "Unknown File",
          original_filename: get_in(card, [:planet, :file, :original_filename]) || "unknown.file",
          file_type: file_type,
          media_type: file_type,  # Add this field for compatibility
          file_size: 1024 * 1024, # 1MB default
          inserted_at: DateTime.utc_now(),
          user_id: 1,
          metadata: %{}
        }
    end
  end

  # Utility functions
  defp find_card_by_id(cards, card_id) do
    Enum.find(cards, &(to_string(&1.id) == to_string(card_id)))
  end

  defp find_card_index(cards, card_id) do
    Enum.find_index(cards, &(to_string(&1.id) == to_string(card_id))) || 0
  end

  defp filter_cards(cards, query, filter_type) do
    cards
    |> filter_by_type(filter_type)
    |> filter_by_search(query)
  end

  defp filter_by_type(cards, "all"), do: cards
  defp filter_by_type(cards, type) do
    Enum.filter(cards, fn card ->
      card_type = determine_media_type(card) |> Atom.to_string()
      card_type == type
    end)
  end

  defp filter_by_search(cards, ""), do: cards
  defp filter_by_search(cards, query) do
    query_lower = String.downcase(query)
    Enum.filter(cards, fn card ->
      title = get_card_title(card) |> String.downcase()
      String.contains?(title, query_lower)
    end)
  end

  defp update_user_theme(user_id, theme) do
    try do
      if function_exported?(Accounts, :update_user_theme_preferences, 2) do
        Accounts.update_user_theme_preferences(user_id, %{current_theme: theme})
      else
        {:ok, :theme_updated}
      end
    rescue
      _ -> {:error, :function_not_found}
    catch
      _ -> {:error, :update_failed}
    end
  end

  defp update_user_view_mode(user_id, view_mode) do
    try do
      if function_exported?(Accounts, :update_user_theme_preferences, 2) do
        Accounts.update_user_theme_preferences(user_id, %{preferred_view_mode: view_mode})
      else
        {:ok, :view_mode_updated}
      end
    rescue
      _ -> {:error, :function_not_found}
    catch
      _ -> {:error, :update_failed}
    end
  end

  defp update_auto_theme_setting(user_id, setting) do
    try do
      if function_exported?(Accounts, :update_user_theme_preferences, 2) do
        Accounts.update_user_theme_preferences(user_id, %{auto_switch_themes: setting})
      else
        {:ok, :setting_updated}
      end
    rescue
      _ -> {:error, :function_not_found}
    catch
      _ -> {:error, :update_failed}
    end
  end

  defp add_user_reaction(user_id, target_id, target_type, reaction_type) do
    try do
      target_id_int = String.to_integer(target_id)
      reaction_params = %{
        "reaction_type" => reaction_type,
        "user_id" => user_id,
        "#{target_type}_id" => target_id_int
      }
      Media.toggle_reaction(reaction_params)
    rescue
      _ -> {:error, :function_not_found}
    catch
      _ -> {:error, :reaction_failed}
    end
  end

  defp subscribe_to_updates(user_id) do
    try do
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "theme_updates:#{user_id}")
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "discovery:#{user_id}")
    rescue
      _ -> :ok
    catch
      _ -> :ok
    end
  end

  defp broadcast_theme_change(user_id, theme) do
    try do
      Phoenix.PubSub.broadcast(Frestyl.PubSub, "theme_updates:#{user_id}", {:theme_changed, theme})
    rescue
      _ -> :ok
    catch
      _ -> :ok
    end
  end

  defp maybe_auto_switch_theme(socket, card_index) do
    if socket.assigns.auto_theme_switching do
      auto_switch_theme_for_card(socket, card_index)
    else
      socket
    end
  end

  defp auto_switch_theme_for_card(socket, card_index) do
    cards = socket.assigns.planetary_cards
    case Enum.at(cards, card_index) do
      %{music_metadata: %{genre: genre}} when is_binary(genre) ->
        new_theme = genre_to_theme(genre)
        assign(socket, :current_theme, new_theme)
      _ ->
        socket
    end
  end

  defp genre_to_theme(genre) do
    genre_lower = String.downcase(genre)
    cond do
      String.contains?(genre_lower, "electronic") or String.contains?(genre_lower, "synthwave") -> "neon_cyberpunk"
      String.contains?(genre_lower, "ambient") or String.contains?(genre_lower, "cosmic") -> "cosmic_dreams"
      String.contains?(genre_lower, "classical") or String.contains?(genre_lower, "minimal") -> "minimalist"
      String.contains?(genre_lower, "rock") or String.contains?(genre_lower, "industrial") -> "blueprint_industrial"
      true -> "cosmic_dreams"
    end
  end

  defp apply_url_filters(socket, _params), do: socket
  defp update_card_data(cards, _updated_file), do: cards

  defp get_available_themes do
    %{
      "cosmic_dreams" => %{name: "Cosmic Dreams", preview_bg: "bg-gradient-to-br from-purple-600 to-blue-600"},
      "minimalist" => %{name: "Minimalist", preview_bg: "bg-gradient-to-br from-gray-100 to-gray-300"},
      "glass_morphism" => %{name: "Glass Morphism", preview_bg: "bg-gradient-to-br from-blue-400 to-purple-400"},
      "blueprint_industrial" => %{name: "Blueprint", preview_bg: "bg-gradient-to-br from-gray-600 to-red-600"},
      "neon_cyberpunk" => %{name: "Neon Cyberpunk", preview_bg: "bg-gradient-to-br from-pink-500 to-purple-500"}
    }
  end

  defp get_card_title(card) do
    case card.planet.file do
      %{title: title} when is_binary(title) and title != "" -> title
      %{original_filename: filename} when is_binary(filename) -> filename
      _ -> "Unknown File"
    end
  end

  defp get_card_description(card) do
    file_type = determine_media_type(card) |> Atom.to_string() |> String.capitalize()
    case card.type do
      :planet_system ->
        satellite_count = length(Map.get(card, :satellites, []))
        "#{file_type} • #{satellite_count + 1} files"
      _ ->
        "#{file_type} • Individual file"
    end
  end

  defp has_metadata?(card) do
    metadata = Map.get(card, :music_metadata, %{})
    Map.get(metadata, :genre) || Map.get(metadata, :bpm) || Map.get(metadata, :key_signature)
  end

  defp get_axis_position(index, current_index) do
    distance = abs(index - current_index)
    cond do
      distance == 0 -> :focused
      distance == 1 -> :adjacent
      true -> :distant
    end
  end

  # Keep the existing enhanced_theme_styles, ambient_background, enhanced_grid_mode, and enhanced_list_mode functions from your original file
  # (They remain the same but I'll include them for completeness)

  defp enhanced_theme_styles(assigns) do
    ~H"""
    <style id="enhanced-theme-styles">
      <%= case @theme do %>
        <% "cosmic_dreams" -> %>
          :root {
            --bg-primary: linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 25%, #16213e 50%, #0f1419 100%);
            --bg-secondary: rgba(139, 92, 246, 0.05);
            --surface: rgba(255, 255, 255, 0.08);
            --surface-hover: rgba(255, 255, 255, 0.12);
            --text-primary: #ffffff;
            --text-secondary: rgba(255, 255, 255, 0.7);
            --accent: #8b5cf6;
            --accent-glow: rgba(139, 92, 246, 0.3);
            --border: rgba(255, 255, 255, 0.1);
            --shadow: 0 25px 50px rgba(139, 92, 246, 0.15);
          }
        <% "minimalist" -> %>
          :root {
            --bg-primary: linear-gradient(135deg, #fafafa 0%, #f5f5f5 100%);
            --bg-secondary: rgba(0, 0, 0, 0.02);
            --surface: rgba(255, 255, 255, 0.8);
            --surface-hover: rgba(255, 255, 255, 0.95);
            --text-primary: #1a1a1a;
            --text-secondary: rgba(26, 26, 26, 0.6);
            --accent: #2563eb;
            --accent-glow: rgba(37, 99, 235, 0.1);
            --border: rgba(0, 0, 0, 0.08);
            --shadow: 0 25px 50px rgba(0, 0, 0, 0.08);
          }
        <% _ -> %>
          :root {
            --bg-primary: linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 25%, #16213e 50%, #0f1419 100%);
            --bg-secondary: rgba(139, 92, 246, 0.05);
            --surface: rgba(255, 255, 255, 0.08);
            --surface-hover: rgba(255, 255, 255, 0.12);
            --text-primary: #ffffff;
            --text-secondary: rgba(255, 255, 255, 0.7);
            --accent: #8b5cf6;
            --accent-glow: rgba(139, 92, 246, 0.3);
            --border: rgba(255, 255, 255, 0.1);
            --shadow: 0 25px 50px rgba(139, 92, 246, 0.15);
          }
      <% end %>

      .supreme-discovery {
        background: var(--bg-primary);
        color: var(--text-primary);
        transition: all 1.5s cubic-bezier(0.4, 0, 0.2, 1);
      }

      .axis-container {
        perspective: 1000px;
      }

      .axis-strip {
        will-change: transform;
      }

      .axis-item {
        transition: all 1.2s cubic-bezier(0.4, 0, 0.2, 1); /* Increased from 0.8s */
      }

      .information-cluster {
        transition: all 1.2s cubic-bezier(0.4, 0, 0.2, 1); /* Increased from 0.8s */
      }

      .assembling .component {
        animation: assembleComponent 1.2s cubic-bezier(0.4, 0, 0.2, 1) forwards; /* Increased from 0.8s */
      }

      .assembling .component:nth-child(1) { animation-delay: 0ms; }
      .assembling .component:nth-child(2) { animation-delay: 200ms; } /* Increased delays */
      .assembling .component:nth-child(3) { animation-delay: 400ms; }
      .assembling .component:nth-child(4) { animation-delay: 600ms; }

      @keyframes assembleComponent {
        0% {
          opacity: 0;
          transform: translateY(var(--start-y, 50px)) translateX(var(--start-x, 0)) scale(0.8);
        }
        100% {
          opacity: 1;
          transform: translateY(0) translateX(0) scale(1);
        }
      }

      /* Mobile optimizations */
      @media (max-width: 768px) {
        .axis-item {
          width: 100vw !important;
        }

        .information-cluster {
          padding: 1.5rem;
        }
      }
    </style>
    """
  end

  defp ambient_background(assigns) do
    ~H"""
    <div class="ambient-background fixed inset-0 pointer-events-none z-0">
      <%= case @theme do %>
        <% "cosmic_dreams" -> %>
          <%= for i <- 1..12 do %>
            <div
              class="absolute w-1 h-1 bg-white rounded-full opacity-40"
              style={
                "left: #{rem(i * 7, 100)}%; " <>
                "top: #{rem(i * 11, 100)}%; " <>
                "animation: twinkle #{3 + rem(i, 3)}s ease-in-out infinite;"
              }
            ></div>
          <% end %>
        <% _ -> %>
          <div class="absolute inset-0 bg-gradient-to-br from-white/5 to-transparent"></div>
      <% end %>

      <style>
        @keyframes twinkle {
          0%, 100% { opacity: 0.2; }
          50% { opacity: 0.8; }
        }
      </style>
    </div>
    """
  end

  defp enhanced_grid_mode(assigns) do
    ~H"""
    <div class="enhanced-grid p-8 min-h-screen pt-24"> <!-- Added pt-24 for mobile nav space -->
      <div class="text-center mb-12">
        <h1 class="text-4xl font-bold mb-4" style="color: var(--text-primary);">Media Grid</h1>
        <p class="text-lg" style="color: var(--text-secondary);">Explore your universe in organized constellations</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8 max-w-7xl mx-auto">
        <%= for card <- @cards do %>
          <div
            class="bg-white/10 backdrop-blur-md rounded-xl p-6 border border-white/20 hover:bg-white/20 transition-all duration-300 hover:scale-105 cursor-pointer"
            phx-click="expand_planet"
            phx-value-card_id={card.id}
          >
            <div class="text-center">
              <.mobile_media_visualization
                card={card}
                theme={@current_theme}
                is_focused={true}
              />
              <h3 class="text-white font-semibold mt-4 mb-2 truncate">
                <%= get_card_title(card) %>
              </h3>
              <p class="text-white/60 text-sm">
                <%= get_card_description(card) %>
              </p>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp enhanced_list_mode(assigns) do
    ~H"""
    <div class="enhanced-list p-8 min-h-screen pt-24"> <!-- Added pt-24 for mobile nav space -->
      <div class="text-center mb-12">
        <h1 class="text-4xl font-bold mb-4" style="color: var(--text-primary);">Navigation List</h1>
        <p class="text-lg" style="color: var(--text-secondary);">Linear exploration through your media cosmos</p>
      </div>

      <div class="max-w-4xl mx-auto space-y-4">
        <%= for {card, index} <- Enum.with_index(@cards) do %>
          <div
            class="discovery-card flex items-center p-6 bg-white/10 backdrop-blur-md rounded-xl border border-white/20 hover:bg-white/20 transition-all duration-300 cursor-pointer"
            phx-click="expand_planet"
            phx-value-card_id={card.id}
          >
            <div class="w-16 h-16 rounded-xl overflow-hidden mr-6 flex-shrink-0">
              <.mobile_media_visualization
                card={card}
                theme={@current_theme}
                is_focused={false}
              />
            </div>

            <div class="flex-1 min-w-0">
              <h3 class="text-xl font-bold mb-2 truncate" style="color: var(--text-primary);">
                <%= get_card_title(card) %>
              </h3>
              <p class="text-sm mb-3 opacity-70" style="color: var(--text-secondary);">
                <%= get_card_description(card) %>
              </p>
            </div>

            <div class="flex items-center space-x-3 flex-shrink-0">
              <button class="px-4 py-2 rounded-xl transition-all duration-300 text-sm font-medium hover:scale-105" style="background: var(--surface); color: var(--text-primary); border: 1px solid var(--border);">
                Explore
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Demo data fallback (keep this for when real data isn't available)
  defp create_demo_planetary_cards do
    [
      %{
        id: "demo_1",
        type: :planet_system,
        planet: %{
          file: %{id: 1, title: "Cosmic Symphony", original_filename: "cosmic_symphony.mp3"},
          type: :audio
        },
        satellites: [],
        metadata: %{},
        music_metadata: %{genre: "Ambient", bpm: 85, key_signature: "Cm"}
      },
      %{
        id: "demo_2",
        type: :individual_file,
        planet: %{
          file: %{id: 2, title: "Nature Landscape", original_filename: "landscape.jpg"},
          type: :image
        },
        satellites: [],
        metadata: %{},
        music_metadata: %{}
      }
      # Add more demo data as needed...
    ]
  end
end
