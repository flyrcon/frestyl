# lib/frestyl_web/live/media_live/media_card_component.ex - Fixed checkbox + Stack expansion

defmodule FrestylWeb.MediaLive.MediaCardComponent do
  use FrestylWeb, :live_component
  alias FrestylWeb.MediaLive.MediaHelpers

  def render(assigns) do
    ~H"""
    <div
      class={[
        "relative group select-none",
        get_card_container_classes(@group)
      ]}
      data-card-type={@group.type}
      data-stack-expanded={@expanded}
    >
      <%= if @group.type == :stack do %>
        <%= if @expanded do %>
          <!-- Expanded Stack View -->
          <div class="space-y-3">
            <!-- Header with collapse button -->
            <div class="flex items-center justify-between mb-3">
              <span class="text-sm font-medium text-gray-700">
                <%= @group.count %> files in stack
              </span>
              <button
                phx-click="collapse_stack"
                phx-target={@myself}
                class="p-1 rounded-lg hover:bg-gray-100 text-gray-500 hover:text-gray-700 transition-colors duration-200"
                title="Collapse stack"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </button>
            </div>

            <!-- Expanded Files Grid -->
            <div class="grid grid-cols-2 gap-2">
              <!-- Primary file -->
              <.render_expanded_file_card
                file={@group.primary_file}
                is_primary={true}
                selected={@selected}
                myself={@myself}
              />

              <!-- Other files -->
              <%= for file <- @group.other_files do %>
                <.render_expanded_file_card
                  file={file}
                  is_primary={false}
                  selected={@selected}
                  myself={@myself}
                />
              <% end %>
            </div>
          </div>
        <% else %>
          <!-- Collapsed Stack View -->
          <div class="relative transform-gpu transition-all duration-300 group-hover:scale-105">
            <!-- Background Cards for Realistic Stack Effect -->
            <div class="absolute inset-0 bg-white rounded-2xl shadow-md border border-gray-200 transform translate-x-2 translate-y-2 opacity-30 -z-10"></div>
            <div class="absolute inset-0 bg-white rounded-2xl shadow-sm border border-gray-150 transform translate-x-1 translate-y-1 opacity-60 -z-5"></div>

            <!-- Main Card (Top) - Made clickable for expansion -->
            <div
              class="relative bg-white rounded-2xl shadow-lg border border-gray-200 overflow-hidden transform transition-all duration-300 hover:shadow-xl z-10 cursor-pointer"
              phx-click="expand_stack"
              phx-target={@myself}
            >
              <.render_card_content
                file={@group.primary_file}
                is_stack={true}
                stack_count={@group.count}
                selected={@selected}
                engagement_data={MediaHelpers.get_engagement_data(@group.primary_file)}
              />

              <!-- Stack Count Badge -->
              <div class="absolute top-2 right-2 bg-gradient-to-r from-purple-600 to-purple-700 text-white text-xs font-bold px-2 py-1 rounded-full shadow-lg z-20">
                <%= @group.count %>
              </div>

              <!-- Stack Expansion Indicator -->
              <div class="absolute bottom-3 right-3 opacity-0 group-hover:opacity-100 transition-opacity duration-200 z-20">
                <div class="bg-black bg-opacity-70 text-white text-xs px-2 py-1 rounded-full flex items-center space-x-1">
                  <span>Expand</span>
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
                  </svg>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      <% else %>
        <!-- Single Card -->
        <div
          class="relative bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden transform transition-all duration-300 hover:shadow-lg hover:-translate-y-1 hover:border-gray-200 cursor-pointer"
          phx-click="view_media"
          phx-value-id={@group.file.id}
        >
          <.render_card_content
            file={@group.file}
            is_stack={false}
            stack_count={nil}
            selected={@selected}
            engagement_data={MediaHelpers.get_engagement_data(@group.file)}
          />
        </div>
      <% end %>

      <!-- Selection Checkbox - Fixed to prevent event bubbling -->
      <div class="absolute top-2 left-2 z-30" phx-click="prevent_bubble" phx-target={@myself}>
        <label class="relative flex items-center cursor-pointer" phx-click="prevent_bubble" phx-target={@myself}>
          <input
            type="checkbox"
            checked={is_selected?(@group, @selected)}
            phx-click="toggle_selection"
            phx-value-id={get_primary_file_id(@group)}
            phx-target={@myself}
            class="sr-only peer"
          />
          <!-- Enhanced checkbox with better contrast -->
          <div class="w-5 h-5 bg-white bg-opacity-95 border-2 border-gray-400 rounded-md shadow-lg backdrop-blur-sm peer-checked:bg-purple-600 peer-checked:border-purple-600 transition-all duration-200 flex items-center justify-center">
            <svg class="w-3 h-3 text-white opacity-0 peer-checked:opacity-100 transition-opacity duration-200" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
            </svg>
          </div>
        </label>
      </div>
    </div>
    """
  end

  # Expanded File Card Component
  defp render_expanded_file_card(assigns) do
    ~H"""
    <div
      class={[
        "relative bg-white rounded-xl border-2 transition-all duration-200 cursor-pointer group/file",
        if(@is_primary, do: "border-purple-300 shadow-md", else: "border-gray-200 hover:border-gray-300")
      ]}
      phx-click="view_media"
      phx-value-id={@file.id}
    >
      <!-- Thumbnail/Preview -->
      <div class="aspect-w-16 aspect-h-10 bg-gradient-to-br from-gray-50 to-gray-100 rounded-t-xl">
        <%= if @file.media_type == "image" and @file.thumbnail_url do %>
          <img
            src={@file.thumbnail_url}
            alt={@file.title || @file.original_filename}
            class="w-full h-full object-cover rounded-t-xl"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center">
            <div class={[
              "w-8 h-8 rounded-lg flex items-center justify-center",
              MediaHelpers.media_type_bg(@file.media_type)
            ]}>
              <svg class={["w-4 h-4", MediaHelpers.media_type_color(@file.media_type)]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <%= raw(MediaHelpers.media_type_icon(@file.media_type)) %>
              </svg>
            </div>
          </div>
        <% end %>

        <!-- Primary badge -->
        <%= if @is_primary do %>
          <div class="absolute top-1 right-1">
            <span class="bg-purple-600 text-white text-xs px-1 py-0.5 rounded-full font-medium">
              Primary
            </span>
          </div>
        <% end %>
      </div>

      <!-- File Info -->
      <div class="p-2">
        <h4 class="text-xs font-medium text-gray-900 truncate" title={@file.title || @file.original_filename}>
          <%= @file.title || @file.original_filename %>
        </h4>
        <div class="flex items-center justify-between mt-1">
          <span class={[
            "text-xs px-1 py-0.5 rounded font-medium",
            MediaHelpers.media_type_badge_color(@file.media_type)
          ]}>
            <%= String.capitalize(@file.media_type) %>
          </span>
          <span class="text-xs text-gray-400">
            <%= MediaHelpers.format_bytes(@file.file_size) %>
          </span>
        </div>
      </div>

      <!-- Selection indicator for expanded files -->
      <div class="absolute top-1 left-1" phx-click="prevent_bubble" phx-target={@myself}>
        <input
          type="checkbox"
          checked={@file.id in @selected}
          phx-click="toggle_file_selection"
          phx-value-id={@file.id}
          phx-target={@myself}
          class="w-3 h-3 rounded border-gray-300 text-purple-600 focus:ring-purple-500"
        />
      </div>

      <!-- Hover overlay -->
      <div class="absolute inset-0 bg-purple-600 bg-opacity-0 group-hover/file:bg-opacity-10 transition-all duration-200 rounded-xl flex items-center justify-center">
        <div class="opacity-0 group-hover/file:opacity-100 transition-opacity duration-200">
          <div class="bg-white bg-opacity-90 text-purple-600 text-xs px-2 py-1 rounded-full font-medium">
            Preview
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Card Content Component - Updated for better interaction
  defp render_card_content(assigns) do
    ~H"""
    <!-- Media Preview/Thumbnail -->
    <div class="relative aspect-w-16 aspect-h-10 bg-gradient-to-br from-gray-100 to-gray-200">
      <%= if @file.media_type == "image" and @file.thumbnail_url do %>
        <img
          src={@file.thumbnail_url}
          alt={@file.title || @file.original_filename}
          class="w-full h-full object-cover transition-transform duration-300 group-hover:scale-105"
        />
      <% else %>
        <div class="w-full h-full flex items-center justify-center">
          <div class={[
            "w-16 h-16 rounded-2xl flex items-center justify-center shadow-lg",
            MediaHelpers.media_type_bg(@file.media_type)
          ]}>
            <svg class={["w-8 h-8", MediaHelpers.media_type_color(@file.media_type)]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <%= raw(MediaHelpers.media_type_icon(@file.media_type)) %>
            </svg>
          </div>
        </div>
      <% end %>

      <!-- Media Type Badge - repositioned to avoid checkbox overlap -->
      <div class="absolute bottom-2 left-2">
        <span class={[
          "inline-flex items-center px-2 py-1 rounded-full text-xs font-medium shadow-sm backdrop-blur-sm",
          MediaHelpers.media_type_badge_color(@file.media_type)
        ]}>
          <%= String.capitalize(@file.media_type) %>
        </span>
      </div>

      <!-- Trending/Hot Badge -->
      <%= if @engagement_data.is_trending do %>
        <div class="absolute top-2 right-2">
          <div class="bg-gradient-to-r from-orange-500 to-red-500 text-white text-xs font-bold px-2 py-1 rounded-full shadow-lg animate-pulse">
            <div class="flex items-center space-x-1">
              <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M12.395 2.553a1 1 0 00-1.45-.385c-.345.23-.614.558-.822.88-.214.33-.403.713-.57 1.116-.334.804-.614 1.768-.84 2.734a31.365 31.365 0 00-.613 3.58 2.64 2.64 0 01-.945-1.067c-.328-.68-.398-1.534-.398-2.654A1 1 0 005.05 6.05 6.981 6.981 0 003 11a7 7 0 1011.95-4.95c-.592-.591-.98-.985-1.348-1.467-.363-.476-.724-1.063-1.207-2.03zM12.12 15.12A3 3 0 017 13s.879.5 2.5.5c0-1 .5-4 1.25-4.5.5 1 .786 1.293 1.371 1.879A2.99 2.99 0 0113 13a2.99 2.99 0 01-.879 2.121z" clip-rule="evenodd" />
              </svg>
              <span>HOT</span>
            </div>
          </div>
        </div>
      <% end %>
    </div>

    <!-- Card Content -->
    <div class="p-4">
      <!-- File Title -->
      <div class="mb-3">
        <h3 class="text-sm font-semibold text-gray-900 truncate group-hover:text-purple-700 transition-colors duration-200" title={@file.title || @file.original_filename}>
          <%= @file.title || @file.original_filename %>
        </h3>
        <%= if @file.description do %>
          <p class="text-xs text-gray-500 truncate mt-1" title={@file.description}>
            <%= @file.description %>
          </p>
        <% end %>
      </div>

      <!-- Enhanced Engagement Metrics with Reactions -->
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center space-x-3 text-xs text-gray-500">
          <!-- Views -->
          <%= if @engagement_data.views > 0 do %>
            <div class="flex items-center space-x-1">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 616 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
              <span class="font-medium"><%= MediaHelpers.format_number(@engagement_data.views) %></span>
            </div>
          <% end %>

          <!-- Comments -->
          <%= if @engagement_data.comments > 0 do %>
            <div class="flex items-center space-x-1">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
              </svg>
              <span class="font-medium"><%= @engagement_data.comments %></span>
            </div>
          <% end %>
        </div>

        <!-- File Size -->
        <div class="text-xs text-gray-400 font-medium">
          <%= MediaHelpers.format_bytes(@file.file_size) %>
        </div>
      </div>

      <!-- Compact Reactions -->
      <%= if map_size(@engagement_data.reactions) > 0 or assigns[:current_user] do %>
        <div class="mb-3">
          <.live_component
            module={FrestylWeb.MediaLive.ReactionsComponent}
            id={"reactions-card-#{@file.id}"}
            file={@file}
            current_user={assigns[:current_user]}
            mode={:compact}
          />
        </div>
      <% end %>

      <!-- Enhanced Stack Preview (if is_stack) -->
      <%= if @is_stack do %>
        <div class="border-t border-gray-100 pt-3 mt-3">
          <div class="flex items-center justify-between">
            <!-- Visual stack indicator instead of text -->
            <div class="flex items-center space-x-2">
              <div class="flex -space-x-1">
                <div class="w-4 h-3 bg-purple-100 border border-purple-200 rounded-sm"></div>
                <div class="w-4 h-3 bg-purple-200 border border-purple-300 rounded-sm"></div>
                <div class="w-4 h-3 bg-purple-300 border border-purple-400 rounded-sm"></div>
              </div>
              <span class="text-xs text-gray-500 font-medium">
                <%= @stack_count %> files
              </span>
            </div>
            <div class="flex items-center space-x-1 text-xs text-purple-600 font-medium">
              <span>Expand</span>
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
              </svg>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Upload Date -->
      <div class="border-t border-gray-100 pt-3 mt-3">
        <div class="flex items-center justify-between text-xs text-gray-500">
          <span>
            <%= MediaHelpers.format_relative_time(@file.inserted_at) %>
          </span>
          <%= if @file.channel do %>
            <div class="flex items-center space-x-1">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14" />
              </svg>
              <span class="truncate max-w-20"><%= @file.channel.name %></span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Event Handlers
  def handle_event("toggle_selection", %{"id" => file_id}, socket) do
    send(self(), {:toggle_file_selection, String.to_integer(file_id)})
    {:noreply, socket}
  end

  def handle_event("toggle_file_selection", %{"id" => file_id}, socket) do
    send(self(), {:toggle_file_selection, String.to_integer(file_id)})
    {:noreply, socket}
  end

  def handle_event("prevent_bubble", _params, socket) do
    # Prevent event bubbling - do nothing
    {:noreply, socket}
  end

  def handle_event("expand_stack", _params, socket) do
    {:noreply, assign(socket, :expanded, true)}
  end

  def handle_event("collapse_stack", _params, socket) do
    {:noreply, assign(socket, :expanded, false)}
  end

  def handle_event("view_media", %{"id" => file_id}, socket) do
    send(self(), {:view_media, String.to_integer(file_id)})
    {:noreply, socket}
  end

  # Mount function to initialize expanded state
  def mount(socket) do
    {:ok, assign(socket, :expanded, false)}
  end

  # Helper functions
  defp get_card_container_classes(%{type: :stack}) do
    "transition-all duration-300 hover:z-10"
  end

  defp get_card_container_classes(_) do
    "transition-all duration-300"
  end

  defp get_primary_file_id(%{type: :stack, primary_file: file}), do: file.id
  defp get_primary_file_id(%{type: :single, file: file}), do: file.id

  defp is_selected?(%{type: :stack, primary_file: file}, selected_files) do
    file.id in selected_files
  end

  defp is_selected?(%{type: :single, file: file}, selected_files) do
    file.id in selected_files
  end
end
