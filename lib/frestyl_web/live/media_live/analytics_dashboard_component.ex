# lib/frestyl_web/live/media_live/analytics_dashboard_component.ex - Fixed version
defmodule FrestylWeb.MediaLive.AnalyticsDashboardComponent do
  use FrestylWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="mb-6">
      <!-- Main Stats Row -->
      <div class="grid grid-cols-2 lg:grid-cols-5 gap-3 mb-4">

        <!-- Storage Usage -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-3 hover:shadow-md transition-all duration-200 group cursor-pointer">
          <div class="flex items-center space-x-3">
            <div class="p-1.5 bg-purple-100 rounded-lg">
              <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
              </svg>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-lg font-bold text-gray-900 truncate">
                <%= Map.get(@analytics, :storage_percentage, 0) %>%
              </p>
              <p class="text-xs text-gray-500">Storage</p>
            </div>
            <%= if Map.get(@analytics, :needs_upgrade, false) do %>
              <div class="w-2 h-2 bg-orange-500 rounded-full animate-pulse"></div>
            <% end %>
          </div>
          <!-- Mini progress bar -->
          <div class="mt-2 w-full bg-gray-200 rounded-full h-1">
            <div
              class={[
                "h-1 rounded-full transition-all duration-300",
                storage_color(Map.get(@analytics, :storage_percentage, 0))
              ]}
              style={"width: #{min(Map.get(@analytics, :storage_percentage, 0), 100)}%"}
            >
            </div>
          </div>
        </div>

        <!-- Total Files -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-3 hover:shadow-md transition-all duration-200 group cursor-pointer">
          <div class="flex items-center space-x-3">
            <div class="p-1.5 bg-blue-100 rounded-lg">
              <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
              </svg>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-lg font-bold text-gray-900">
                <%= format_number(Map.get(@analytics, :total_files, 0)) %>
              </p>
              <p class="text-xs text-gray-500">Files</p>
            </div>
            <%= if Map.get(@analytics, :recent_uploads, 0) > 0 do %>
              <div class="text-xs text-green-600 font-medium">
                +<%= Map.get(@analytics, :recent_uploads, 0) %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Total Views -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-3 hover:shadow-md transition-all duration-200 group cursor-pointer">
          <div class="flex items-center space-x-3">
            <div class="p-1.5 bg-green-100 rounded-lg">
              <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-lg font-bold text-gray-900">
                <%= format_number(Map.get(@analytics, :total_views, 0)) %>
              </p>
              <p class="text-xs text-gray-500">Views</p>
            </div>
            <%= if Map.get(@analytics, :recent_views, 0) > 0 do %>
              <div class="text-xs text-green-600 font-medium">
                +<%= format_number(Map.get(@analytics, :recent_views, 0)) %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Content Types Mini Chart -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-3 hover:shadow-md transition-all duration-200 group cursor-pointer">
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center space-x-2">
              <div class="p-1.5 bg-pink-100 rounded-lg">
                <svg class="w-4 h-4 text-pink-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h4a1 1 0 011 1v2m-6 0h6m0 0v2m0-2H7m6 2v12a2 2 0 01-2 2H9a2 2 0 01-2-2V6h6z" />
                </svg>
              </div>
              <div>
                <p class="text-sm font-semibold text-gray-900">Types</p>
              </div>
            </div>
          </div>
          <!-- Mini distribution bars -->
          <div class="space-y-1">
            <%= for {type, count} <- Enum.take(Map.get(@analytics, :content_distribution, []), 3) do %>
              <div class="flex items-center space-x-2">
                <div class={["w-2 h-2 rounded-full", content_type_color(type)]}></div>
                <span class="text-xs text-gray-600 capitalize flex-1 truncate"><%= type %></span>
                <span class="text-xs font-medium text-gray-900"><%= count %></span>
              </div>
            <% end %>
            <%= if length(Map.get(@analytics, :content_distribution, [])) == 0 do %>
              <div class="text-xs text-gray-400 text-center py-2">No files yet</div>
            <% end %>
          </div>
        </div>

        <!-- Top Performer Preview -->
        <%= if length(Map.get(@analytics, :top_performers, [])) > 0 do %>
          <% top_file = List.first(Map.get(@analytics, :top_performers, [])) %>
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-3 hover:shadow-md transition-all duration-200 group cursor-pointer">
            <div class="flex items-center space-x-3">
              <div class="relative">
                <%= if top_file.media_type == "image" and Map.get(top_file, :thumbnail_url) do %>
                  <img src={top_file.thumbnail_url} alt="Top performer" class="w-8 h-8 rounded-lg object-cover" />
                <% else %>
                  <div class={["w-8 h-8 rounded-lg flex items-center justify-center", media_type_bg(top_file.media_type)]}>
                    <span class={["text-xs font-bold", media_type_color(top_file.media_type)]}>
                      <%= String.upcase(String.slice(top_file.media_type || "unknown", 0, 1)) %>
                    </span>
                  </div>
                <% end %>
                <!-- Hot indicator -->
                <div class="absolute -top-1 -right-1 w-3 h-3 bg-orange-500 rounded-full flex items-center justify-center">
                  <svg class="w-2 h-2 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M12.395 2.553a1 1 0 00-1.45-.385c-.345.23-.614.558-.822.88-.214.33-.403.713-.57 1.116-.334.804-.614 1.768-.84 2.734a31.365 31.365 0 00-.613 3.58 2.64 2.64 0 01-.945-1.067c-.328-.68-.398-1.534-.398-2.654A1 1 0 005.05 6.05 6.981 6.981 0 003 11a7 7 0 1011.95-4.95c-.592-.591-.98-.985-1.348-1.467-.363-.476-.724-1.063-1.207-2.03zM12.12 15.12A3 3 0 017 13s.879.5 2.5.5c0-1 .5-4 1.25-4.5.5 1 .786 1.293 1.371 1.879A2.99 2.99 0 0113 13a2.99 2.99 0 01-.879 2.121z" clip-rule="evenodd" />
                  </svg>
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-gray-900 truncate">Top File</p>
                <p class="text-xs text-gray-500 truncate">
                  <%= format_number(get_in(top_file.metadata || %{}, ["views"]) || 0) %> views
                </p>
              </div>
            </div>
          </div>
        <% else %>
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-3 hover:shadow-md transition-all duration-200 group cursor-pointer">
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-gray-100 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                </svg>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-gray-900">No Files</p>
                <p class="text-xs text-gray-500">Upload to start</p>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Storage Details -->
      <%= if Map.get(@analytics, :total_storage, 0) > 0 do %>
        <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4 mb-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="text-sm font-semibold text-gray-900">Storage Usage</h3>
            <span class="text-xs text-gray-500">
              <%= format_storage(Map.get(@analytics, :total_storage, 0)) %> / 1 GB
            </span>
          </div>

          <div class="w-full bg-gray-200 rounded-full h-2 mb-2">
            <div
              class={[
                "h-2 rounded-full transition-all duration-300",
                storage_color(Map.get(@analytics, :storage_percentage, 0))
              ]}
              style={"width: #{min(Map.get(@analytics, :storage_percentage, 0), 100)}%"}
            >
            </div>
          </div>

          <%= if Map.get(@analytics, :needs_upgrade, false) do %>
            <div class="flex items-center space-x-2 text-xs text-orange-600 mt-2">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.98-.833-2.75 0L4.064 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
              <span>Storage almost full - consider upgrading</span>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Expandable Detailed Analytics Toggle -->
      <div class="text-center">
        <button
          phx-click="toggle_detailed_analytics"
          phx-target={@myself}
          class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700 transition-colors duration-200"
          id="toggle-detailed-btn"
        >
          <span id="toggle-text">View detailed analytics</span>
          <svg id="toggle-icon" class="ml-1 w-4 h-4 transition-transform duration-200" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
          </svg>
        </button>
      </div>

      <!-- Hidden Detailed Analytics Panel -->
      <div id="detailed-analytics" class="hidden mt-6 space-y-4 overflow-hidden transition-all duration-300">
        <!-- Growth Charts -->
        <%= if length(get_in(@analytics, [:growth_data, :files]) || []) > 0 do %>
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
            <h4 class="text-sm font-semibold text-gray-900 mb-3">Growth Trends</h4>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <h5 class="text-xs font-medium text-gray-700 mb-2">Files Over Time</h5>
                <div class="h-20 flex items-end space-x-1">
                  <%= for point <- get_in(@analytics, [:growth_data, :files]) || [] do %>
                    <div class="flex-1 bg-purple-200 rounded-t" style={"height: #{(point.value / max(Map.get(@analytics, :total_files, 1), 1)) * 100}%"}></div>
                  <% end %>
                </div>
              </div>
              <div>
                <h5 class="text-xs font-medium text-gray-700 mb-2">Views Over Time</h5>
                <div class="h-20 flex items-end space-x-1">
                  <%= for point <- get_in(@analytics, [:growth_data, :views]) || [] do %>
                    <div class="flex-1 bg-green-200 rounded-t" style={"height: #{(point.value / max(Map.get(@analytics, :total_views, 1), 1)) * 100}%"}></div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Popular Tags -->
        <%= if length(Map.get(@analytics, :popular_tags, [])) > 0 do %>
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
            <h4 class="text-sm font-semibold text-gray-900 mb-3">Popular Tags</h4>
            <div class="flex flex-wrap gap-2">
              <%= for tag <- Map.get(@analytics, :popular_tags, []) do %>
                <span class="inline-flex items-center px-2 py-1 bg-purple-100 text-purple-800 text-xs font-medium rounded-full">
                  <%= tag.name %> (<%= tag.count %>)
                </span>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Top Performers -->
        <%= if length(Map.get(@analytics, :top_performers, [])) > 1 do %>
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
            <h4 class="text-sm font-semibold text-gray-900 mb-3">Top Performing Files</h4>
            <div class="space-y-2">
              <%= for {file, index} <- Enum.with_index(Enum.take(Map.get(@analytics, :top_performers, []), 5)) do %>
                <div class="flex items-center space-x-3 p-2 rounded-lg hover:bg-gray-50">
                  <div class="flex-shrink-0 w-6 h-6 bg-gradient-to-r from-purple-600 to-indigo-600 rounded-full flex items-center justify-center">
                    <span class="text-white text-xs font-bold"><%= index + 1 %></span>
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-gray-900 truncate">
                      <%= file.title || file.original_filename || "Untitled" %>
                    </p>
                    <p class="text-xs text-gray-500">
                      <%= String.capitalize(file.media_type || "unknown") %>
                    </p>
                  </div>
                  <div class="text-sm font-medium text-gray-900">
                    <%= format_number(get_in(file.metadata || %{}, ["views"]) || 0) %> views
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Content Distribution -->
        <%= if length(Map.get(@analytics, :content_distribution, [])) > 0 do %>
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
            <h4 class="text-sm font-semibold text-gray-900 mb-3">Content Distribution</h4>
            <div class="space-y-3">
              <%= for {type, count} <- Map.get(@analytics, :content_distribution, []) do %>
                <div class="flex items-center justify-between">
                  <div class="flex items-center space-x-2">
                    <div class={["w-3 h-3 rounded-full", content_type_color(type)]}></div>
                    <span class="text-sm font-medium text-gray-900 capitalize"><%= type %></span>
                  </div>
                  <div class="flex items-center space-x-2">
                    <div class="w-20 bg-gray-200 rounded-full h-2">
                      <div
                        class={["h-2 rounded-full", content_type_color(type)]}
                        style={"width: #{(count / max(Map.get(@analytics, :total_files, 1), 1)) * 100}%"}
                      ></div>
                    </div>
                    <span class="text-sm font-medium text-gray-900 w-8 text-right"><%= count %></span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("toggle_detailed_analytics", _params, socket) do
    # This will be handled by JavaScript for smooth animation
    {:noreply, socket}
  end

  # Helper functions with safe defaults
  defp storage_color(percentage) when percentage > 90, do: "bg-red-500"
  defp storage_color(percentage) when percentage > 80, do: "bg-orange-500"
  defp storage_color(_), do: "bg-purple-500"

  defp content_type_color("image"), do: "bg-purple-500"
  defp content_type_color("video"), do: "bg-blue-500"
  defp content_type_color("audio"), do: "bg-green-500"
  defp content_type_color("document"), do: "bg-yellow-500"
  defp content_type_color(_), do: "bg-gray-500"

  defp media_type_bg("image"), do: "bg-purple-100"
  defp media_type_bg("video"), do: "bg-blue-100"
  defp media_type_bg("audio"), do: "bg-green-100"
  defp media_type_bg("document"), do: "bg-yellow-100"
  defp media_type_bg(_), do: "bg-gray-100"

  defp media_type_color("image"), do: "text-purple-600"
  defp media_type_color("video"), do: "text-blue-600"
  defp media_type_color("audio"), do: "text-green-600"
  defp media_type_color("document"), do: "text-yellow-600"
  defp media_type_color(_), do: "text-gray-600"

  defp format_number(number) when is_number(number) do
    cond do
      number >= 1_000_000 -> "#{Float.round(number / 1_000_000, 1)}M"
      number >= 1_000 -> "#{Float.round(number / 1_000, 1)}K"
      true -> "#{number}"
    end
  end

  defp format_number(_), do: "0"

  defp format_storage(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 2)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_storage(_), do: "0 B"
end
