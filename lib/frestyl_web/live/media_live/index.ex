# lib/frestyl_web/live/media_live/index.ex
defmodule FrestylWeb.MediaLive.Index do
  use FrestylWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Sample data for demonstration - replace with your actual data loading
    media_files = [
      %{
        id: 1,
        filename: "sample_video.mp4",
        file_type: "video",
        file_size: 15728640,
        url: "/uploads/sample_video.mp4",
        uploaded_at: ~N[2024-01-15 10:30:00]
      },
      %{
        id: 2,
        filename: "presentation.pdf",
        file_type: "document",
        file_size: 2097152,
        url: "/uploads/presentation.pdf",
        uploaded_at: ~N[2024-01-14 14:20:00]
      },
      %{
        id: 3,
        filename: "nature_photo.jpg",
        file_type: "image",
        file_size: 5242880,
        url: "/uploads/nature_photo.jpg",
        uploaded_at: ~N[2024-01-13 09:15:00]
      }
    ]

    analytics = calculate_analytics(media_files)

    socket =
      socket
      |> assign(:media_files, media_files)
      |> assign(:filtered_files, media_files)
      |> assign(:current_view, :grid)
      |> assign(:search_query, "")
      |> assign(:filter_type, "all")
      |> assign(:analytics, analytics)
      |> assign(:show_upload_modal, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Media Library")
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    # Find media file from the list
    media_file = Enum.find(socket.assigns.media_files, &(&1.id == String.to_integer(id)))

    if media_file do
      socket
      |> assign(:page_title, "Edit Media")
      |> assign(:media_file, media_file)
    else
      socket
      |> put_flash(:error, "Media file not found")
      |> push_navigate(to: ~p"/media")
    end
  end

  @impl true
  def handle_event("switch_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :current_view, String.to_atom(view))}
  end

  def handle_event("search", %{"query" => query}, socket) do
    filtered_files = filter_files(socket.assigns.media_files, query, socket.assigns.filter_type)

    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:filtered_files, filtered_files)

    {:noreply, socket}
  end

  def handle_event("filter_type", %{"type" => type}, socket) do
    filtered_files = filter_files(socket.assigns.media_files, socket.assigns.search_query, type)

    socket =
      socket
      |> assign(:filter_type, type)
      |> assign(:filtered_files, filtered_files)

    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    # Remove from the list (in real app, this would delete from database)
    media_files = Enum.reject(socket.assigns.media_files, &(&1.id == String.to_integer(id)))
    filtered_files = filter_files(media_files, socket.assigns.search_query, socket.assigns.filter_type)
    analytics = calculate_analytics(media_files)

    socket =
      socket
      |> assign(:media_files, media_files)
      |> assign(:filtered_files, filtered_files)
      |> assign(:analytics, analytics)
      |> put_flash(:info, "Media file deleted successfully")

    {:noreply, socket}
  end

  def handle_event("show_upload_modal", _params, socket) do
    {:noreply, assign(socket, :show_upload_modal, true)}
  end

  def handle_event("hide_upload_modal", _params, socket) do
    {:noreply, assign(socket, :show_upload_modal, false)}
  end

  # Helper functions
  defp filter_files(files, query, type) do
    files
    |> filter_by_type(type)
    |> filter_by_search(query)
  end

  defp filter_by_type(files, "all"), do: files
  defp filter_by_type(files, type) do
    Enum.filter(files, &(&1.file_type == type))
  end

  defp filter_by_search(files, ""), do: files
  defp filter_by_search(files, query) do
    query_lower = String.downcase(query)
    Enum.filter(files, fn file ->
      String.contains?(String.downcase(file.filename), query_lower)
    end)
  end

  defp calculate_analytics(media_files) do
    total_files = length(media_files)
    total_storage = Enum.reduce(media_files, 0, &(&1.file_size + &2))

    content_distribution =
      media_files
      |> Enum.group_by(&(&1.file_type))
      |> Enum.map(fn {type, files} -> {type, length(files)} end)
      |> Enum.into(%{})

    recent_uploads =
      media_files
      |> Enum.sort_by(&(&1.uploaded_at), {:desc, NaiveDateTime})
      |> Enum.take(5)

    %{
      total_files: total_files,
      total_storage: total_storage,
      content_distribution: content_distribution,
      recent_uploads: recent_uploads
    }
  end

  defp format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_file_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_file_size(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  defp format_file_size(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"

  defp get_file_icon("image"), do: "🖼️"
  defp get_file_icon("video"), do: "🎥"
  defp get_file_icon("audio"), do: "🎵"
  defp get_file_icon("document"), do: "📄"
  defp get_file_icon(_), do: "📁"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-indigo-900 via-purple-900 to-pink-800">
      <!-- Header -->
      <div class="relative">
        <div class="absolute inset-0 bg-black/20 backdrop-blur-sm"></div>
        <div class="relative px-6 py-8">
          <div class="max-w-7xl mx-auto">
            <div class="text-center mb-8">
              <h1 class="text-4xl font-bold text-white mb-2">🌌 Media Cosmos</h1>
              <p class="text-xl text-white/80">Explore your digital universe</p>
            </div>

            <!-- Analytics Dashboard -->
            <div :if={@current_view == :analytics} class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
              <div class="bg-white/10 backdrop-blur-md rounded-xl p-6 border border-white/20">
                <div class="text-3xl mb-2">📊</div>
                <div class="text-2xl font-bold text-white"><%= @analytics.total_files %></div>
                <div class="text-white/70">Total Files</div>
              </div>

              <div class="bg-white/10 backdrop-blur-md rounded-xl p-6 border border-white/20">
                <div class="text-3xl mb-2">💾</div>
                <div class="text-2xl font-bold text-white"><%= format_file_size(@analytics.total_storage) %></div>
                <div class="text-white/70">Storage Used</div>
              </div>

              <div class="bg-white/10 backdrop-blur-md rounded-xl p-6 border border-white/20">
                <div class="text-3xl mb-2">🎯</div>
                <div class="text-2xl font-bold text-white"><%= map_size(@analytics.content_distribution) %></div>
                <div class="text-white/70">File Types</div>
              </div>

              <div class="bg-white/10 backdrop-blur-md rounded-xl p-6 border border-white/20">
                <div class="text-3xl mb-2">⚡</div>
                <div class="text-2xl font-bold text-white"><%= length(@analytics.recent_uploads) %></div>
                <div class="text-white/70">Recent Uploads</div>
              </div>
            </div>

            <!-- Controls -->
            <div class="flex flex-col lg:flex-row justify-between items-center gap-4 mb-8">
              <!-- View Switcher -->
              <div class="flex bg-white/10 backdrop-blur-md rounded-full p-1 border border-white/20">
                <button
                  phx-click="switch_view"
                  phx-value-view="grid"
                  class={"px-4 py-2 rounded-full text-sm font-medium transition-all #{if @current_view == :grid, do: "bg-white text-gray-900", else: "text-white hover:bg-white/20"}"}
                >
                  🔲 Grid
                </button>
                <button
                  phx-click="switch_view"
                  phx-value-view="list"
                  class={"px-4 py-2 rounded-full text-sm font-medium transition-all #{if @current_view == :list, do: "bg-white text-gray-900", else: "text-white hover:bg-white/20"}"}
                >
                  📋 List
                </button>
                <button
                  phx-click="switch_view"
                  phx-value-view="cosmos"
                  class={"px-4 py-2 rounded-full text-sm font-medium transition-all #{if @current_view == :cosmos, do: "bg-white text-gray-900", else: "text-white hover:bg-white/20"}"}
                >
                  🌌 Cosmos
                </button>
                <button
                  phx-click="switch_view"
                  phx-value-view="analytics"
                  class={"px-4 py-2 rounded-full text-sm font-medium transition-all #{if @current_view == :analytics, do: "bg-white text-gray-900", else: "text-white hover:bg-white/20"}"}
                >
                  📊 Analytics
                </button>
              </div>

              <!-- Search and Filters -->
              <div :if={@current_view in [:grid, :list]} class="flex gap-4">
                <input
                  type="text"
                  placeholder="Search files..."
                  value={@search_query}
                  phx-keyup="search"
                  phx-value-query={@search_query}
                  class="px-4 py-2 bg-white/10 backdrop-blur-md border border-white/20 rounded-lg text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/30"
                />

                <select
                  phx-change="filter_type"
                  class="px-4 py-2 bg-white/10 backdrop-blur-md border border-white/20 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-white/30"
                >
                  <option value="all">All Types</option>
                  <option value="image">Images</option>
                  <option value="video">Videos</option>
                  <option value="document">Documents</option>
                  <option value="audio">Audio</option>
                </select>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Content Area -->
      <div class="px-6 pb-8">
        <div class="max-w-7xl mx-auto">
          <!-- Grid View -->
          <div :if={@current_view == :grid} class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            <div
              :for={file <- @filtered_files}
              class="group bg-white/10 backdrop-blur-md rounded-xl p-6 border border-white/20 hover:bg-white/20 transition-all duration-300 hover:scale-105"
            >
              <div class="text-center">
                <div class="text-4xl mb-4"><%= get_file_icon(file.file_type) %></div>
                <h3 class="text-white font-semibold mb-2 truncate"><%= file.filename %></h3>
                <p class="text-white/60 text-sm mb-4"><%= format_file_size(file.file_size) %></p>

                <div class="flex justify-center gap-2">
                  <button class="px-3 py-1 bg-blue-500 hover:bg-blue-600 rounded text-white text-sm transition-colors">
                    📝 Edit
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={file.id}
                    data-confirm="Are you sure you want to delete this file?"
                    class="px-3 py-1 bg-red-500 hover:bg-red-600 rounded text-white text-sm transition-colors"
                  >
                    🗑️ Delete
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- List View -->
          <div :if={@current_view == :list} class="bg-white/10 backdrop-blur-md rounded-xl border border-white/20 overflow-hidden">
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead class="bg-white/5">
                  <tr>
                    <th class="px-6 py-4 text-left text-white font-semibold">File</th>
                    <th class="px-6 py-4 text-left text-white font-semibold">Type</th>
                    <th class="px-6 py-4 text-left text-white font-semibold">Size</th>
                    <th class="px-6 py-4 text-left text-white font-semibold">Uploaded</th>
                    <th class="px-6 py-4 text-left text-white font-semibold">Actions</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-white/10">
                  <tr :for={file <- @filtered_files} class="hover:bg-white/5 transition-colors">
                    <td class="px-6 py-4">
                      <div class="flex items-center gap-3">
                        <span class="text-xl"><%= get_file_icon(file.file_type) %></span>
                        <span class="text-white font-medium"><%= file.filename %></span>
                      </div>
                    </td>
                    <td class="px-6 py-4 text-white/70 capitalize"><%= file.file_type %></td>
                    <td class="px-6 py-4 text-white/70"><%= format_file_size(file.file_size) %></td>
                    <td class="px-6 py-4 text-white/70"><%= Calendar.strftime(file.uploaded_at, "%Y-%m-%d") %></td>
                    <td class="px-6 py-4">
                      <div class="flex gap-2">
                        <button class="px-3 py-1 bg-blue-500 hover:bg-blue-600 rounded text-white text-sm transition-colors">
                          📝 Edit
                        </button>
                        <button
                          phx-click="delete"
                          phx-value-id={file.id}
                          data-confirm="Are you sure you want to delete this file?"
                          class="px-3 py-1 bg-red-500 hover:bg-red-600 rounded text-white text-sm transition-colors"
                        >
                          🗑️ Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Cosmos View -->
          <div :if={@current_view == :cosmos} class="relative min-h-[600px] bg-black/20 backdrop-blur-sm rounded-xl border border-white/20 overflow-hidden">
            <div class="absolute inset-0 flex items-center justify-center">
              <div class="text-center">
                <div class="text-6xl mb-4">🌌</div>
                <h3 class="text-2xl font-bold text-white mb-4">Cosmic Media Explorer</h3>
                <p class="text-white/70 mb-8">Your files floating in digital space</p>

                <!-- Floating Files -->
                <div class="relative w-full h-96">
                  <div
                    :for={{file, index} <- Enum.with_index(@filtered_files)}
                    class="absolute animate-pulse"
                    style={"left: #{rem(index * 137, 80) + 10}%; top: #{rem(index * 97, 60) + 20}%; animation-delay: #{index * 0.5}s;"}
                  >
                    <div class="bg-white/20 backdrop-blur-md rounded-full p-4 border border-white/30 hover:bg-white/30 transition-all cursor-pointer">
                      <div class="text-2xl"><%= get_file_icon(file.file_type) %></div>
                    </div>
                    <div class="text-xs text-white/80 mt-2 text-center max-w-20 truncate">
                      <%= file.filename %>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Analytics View -->
          <div :if={@current_view == :analytics} class="space-y-8">
            <!-- Content Distribution -->
            <div class="bg-white/10 backdrop-blur-md rounded-xl p-6 border border-white/20">
              <h3 class="text-xl font-bold text-white mb-4">📊 Content Distribution</h3>
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div :for={{type, count} <- @analytics.content_distribution} class="text-center">
                  <div class="text-3xl mb-2"><%= get_file_icon(type) %></div>
                  <div class="text-2xl font-bold text-white"><%= count %></div>
                  <div class="text-white/70 capitalize"><%= type %>s</div>
                </div>
              </div>
            </div>

            <!-- Recent Uploads -->
            <div class="bg-white/10 backdrop-blur-md rounded-xl p-6 border border-white/20">
              <h3 class="text-xl font-bold text-white mb-4">⚡ Recent Uploads</h3>
              <div class="space-y-3">
                <div :for={file <- @analytics.recent_uploads} class="flex items-center gap-4 p-3 bg-white/5 rounded-lg">
                  <span class="text-xl"><%= get_file_icon(file.file_type) %></span>
                  <div class="flex-1">
                    <div class="text-white font-medium"><%= file.filename %></div>
                    <div class="text-white/60 text-sm"><%= format_file_size(file.file_size) %> • <%= Calendar.strftime(file.uploaded_at, "%Y-%m-%d") %></div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Floating Upload Button -->
      <button
        phx-click="show_upload_modal"
        class="fixed bottom-8 right-8 bg-gradient-to-r from-pink-500 to-violet-500 hover:from-pink-600 hover:to-violet-600 text-white rounded-full p-4 shadow-2xl hover:scale-110 transition-all duration-300"
      >
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
        </svg>
      </button>

      <!-- Upload Modal -->
      <div :if={@show_upload_modal} class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
        <div class="bg-white/10 backdrop-blur-md rounded-xl p-8 border border-white/20 max-w-md w-full">
          <div class="text-center">
            <div class="text-4xl mb-4">📤</div>
            <h3 class="text-2xl font-bold text-white mb-4">Upload Files</h3>
            <p class="text-white/70 mb-6">Drag and drop files here or click to browse</p>

            <div class="border-2 border-dashed border-white/30 rounded-lg p-8 mb-6 hover:border-white/50 transition-colors cursor-pointer">
              <div class="text-white/60">Click here to select files</div>
            </div>

            <div class="flex gap-4 justify-center">
              <button
                phx-click="hide_upload_modal"
                class="px-6 py-2 bg-gray-500 hover:bg-gray-600 rounded-lg text-white font-medium transition-colors"
              >
                Cancel
              </button>
              <button class="px-6 py-2 bg-gradient-to-r from-pink-500 to-violet-500 hover:from-pink-600 hover:to-violet-600 rounded-lg text-white font-medium transition-all">
                Upload
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
