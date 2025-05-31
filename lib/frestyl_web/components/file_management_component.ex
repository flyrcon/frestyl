# lib/frestyl_web/live/components/file_management_component.ex

defmodule FrestylWeb.MediaLive.FileManagementComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Media

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:show_upload_modal, false)
      |> assign(:uploading, false)
      |> assign(:selected_files, MapSet.new())
      |> assign(:drag_over, false)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="file-management" id={"file-mgmt-#{@id}"}>
      <!-- Quick Actions Bar -->
      <div class="flex items-center justify-between p-4 bg-white/5 backdrop-blur-sm rounded-xl border border-white/10 mb-6">
        <div class="flex items-center space-x-4">
          <!-- Upload Button -->
          <button
            phx-click="show_upload_modal"
            phx-target={@myself}
            class="inline-flex items-center px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-all duration-300 hover:scale-105"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
            </svg>
            Upload Files
          </button>

          <!-- Bulk Actions (when files selected) -->
          <%= if MapSet.size(@selected_files) > 0 do %>
            <div class="flex items-center space-x-2 pl-4 border-l border-white/20">
              <span class="text-sm text-white/70">
                <%= MapSet.size(@selected_files) %> selected
              </span>
              <button
                phx-click="bulk_delete"
                phx-target={@myself}
                data-confirm="Delete selected files?"
                class="px-3 py-1 bg-red-600 hover:bg-red-700 text-white text-sm rounded transition-colors"
              >
                Delete
              </button>
              <button
                phx-click="clear_selection"
                phx-target={@myself}
                class="px-3 py-1 bg-gray-600 hover:bg-gray-700 text-white text-sm rounded transition-colors"
              >
                Clear
              </button>
            </div>
          <% end %>
        </div>

        <!-- View Options -->
        <div class="flex items-center space-x-2">
          <button
            phx-click="toggle_view"
            phx-value-view="grid"
            phx-target={@myself}
            class={[
              "p-2 rounded transition-colors",
              if(@view_mode == "grid", do: "bg-purple-600 text-white", else: "text-white/70 hover:text-white")
            ]}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>
            </svg>
          </button>
          <button
            phx-click="toggle_view"
            phx-value-view="list"
            phx-target={@myself}
            class={[
              "p-2 rounded transition-colors",
              if(@view_mode == "list", do: "bg-purple-600 text-white", else: "text-white/70 hover:text-white")
            ]}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- File Grid/List -->
      <div
        class="file-drop-zone"
        phx-hook="FileDropZone"
        id={"drop-zone-#{@id}"}
        phx-drop-target={@myself}
      >
        <%= case @view_mode do %>
          <% "grid" -> %>
            <.file_grid files={@files} selected_files={@selected_files} myself={@myself} />
          <% "list" -> %>
            <.file_list files={@files} selected_files={@selected_files} myself={@myself} />
        <% end %>
      </div>

      <!-- Upload Modal -->
      <%= if @show_upload_modal do %>
        <.upload_modal myself={@myself} uploading={@uploading} />
      <% end %>
    </div>
    """
  end

  # File List View
  defp file_list(assigns) do
    ~H"""
    <div class="bg-white/10 backdrop-blur-sm rounded-xl border border-white/20 overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-white/5">
            <tr>
              <th class="px-6 py-4 text-left">
                <input
                  type="checkbox"
                  class="rounded border-white/30 bg-white/10 text-purple-600"
                  phx-click="toggle_all_selection"
                  phx-target={@myself}
                />
              </th>
              <th class="px-6 py-4 text-left text-white font-semibold">File</th>
              <th class="px-6 py-4 text-left text-white font-semibold">Type</th>
              <th class="px-6 py-4 text-left text-white font-semibold">Size</th>
              <th class="px-6 py-4 text-left text-white font-semibold">Modified</th>
              <th class="px-6 py-4 text-left text-white font-semibold">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-white/10">
            <%= for file <- @files do %>
              <tr class="hover:bg-white/5 transition-colors">
                <td class="px-6 py-4">
                  <input
                    type="checkbox"
                    checked={MapSet.member?(@selected_files, file.id)}
                    phx-click="toggle_file_selection"
                    phx-value-file-id={file.id}
                    phx-target={@myself}
                    class="rounded border-white/30 bg-white/10 text-purple-600 focus:ring-purple-500"
                  />
                </td>
                <td class="px-6 py-4">
                  <div class="flex items-center space-x-3">
                    <div class={[
                      "w-8 h-8 rounded-lg flex items-center justify-center",
                      get_file_type_bg(file.file_type)
                    ]}>
                      <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <%= raw(get_file_type_icon(file.file_type)) %>
                      </svg>
                    </div>
                    <div>
                      <div class="text-white font-medium truncate max-w-48" title={file.original_filename}>
                        <%= file.original_filename %>
                      </div>
                      <%= if file.title && file.title != file.original_filename do %>
                        <div class="text-xs text-white/60 truncate max-w-48" title={file.title}>
                          <%= file.title %>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 text-white/70 capitalize"><%= file.file_type %></td>
                <td class="px-6 py-4 text-white/70"><%= format_file_size(file.file_size) %></td>
                <td class="px-6 py-4 text-white/70">
                  <%= format_date(file.updated_at) %>
                </td>
                <td class="px-6 py-4">
                  <div class="flex items-center space-x-2">
                    <button
                      phx-click="download_file"
                      phx-value-file-id={file.id}
                      phx-target={@myself}
                      class="p-1 bg-blue-600 hover:bg-blue-700 rounded text-white transition-colors"
                      title="Download"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
                      </svg>
                    </button>
                    <button
                      phx-click="delete_file"
                      phx-value-file-id={file.id}
                      phx-target={@myself}
                      data-confirm="Delete this file?"
                      class="p-1 bg-red-600 hover:bg-red-700 rounded text-white transition-colors"
                      title="Delete"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                      </svg>
                    </button>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # File Grid View
  defp file_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
      <%= for file <- @files do %>
        <div class={[
          "file-card relative bg-white/10 backdrop-blur-sm rounded-xl p-4 border transition-all duration-300",
          "hover:bg-white/20 hover:scale-105 cursor-pointer",
          if(MapSet.member?(@selected_files, file.id), do: "border-purple-400 bg-purple-500/20", else: "border-white/20")
        ]}>
          <!-- Selection Checkbox -->
          <div class="absolute top-2 left-2">
            <input
              type="checkbox"
              checked={MapSet.member?(@selected_files, file.id)}
              phx-click="toggle_file_selection"
              phx-value-file-id={file.id}
              phx-target={@myself}
              class="rounded border-white/30 bg-white/10 text-purple-600 focus:ring-purple-500"
            />
          </div>

          <!-- File Icon -->
          <div class="text-center mb-3">
            <div class={[
              "w-16 h-16 mx-auto rounded-xl flex items-center justify-center mb-2",
              get_file_type_bg(file.file_type)
            ]}>
              <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <%= raw(get_file_type_icon(file.file_type)) %>
              </svg>
            </div>
            <h3 class="text-sm font-medium text-white truncate" title={file.original_filename}>
              <%= file.original_filename %>
            </h3>
            <p class="text-xs text-white/60">
              <%= format_file_size(file.file_size) %>
            </p>
          </div>

          <!-- Quick Actions -->
          <div class="flex items-center justify-center space-x-2 mt-3 opacity-0 group-hover:opacity-100 transition-opacity">
            <button
              phx-click="download_file"
              phx-value-file-id={file.id}
              phx-target={@myself}
              class="p-1 bg-blue-600 hover:bg-blue-700 rounded text-white transition-colors"
              title="Download"
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
              </svg>
            </button>
            <button
              phx-click="delete_file"
              phx-value-file-id={file.id}
              phx-target={@myself}
              data-confirm="Delete this file?"
              class="p-1 bg-red-600 hover:bg-red-700 rounded text-white transition-colors"
              title="Delete"
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Upload Modal
  defp upload_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-xl p-6 max-w-md w-full">
        <div class="text-center">
          <div class="w-16 h-16 mx-auto bg-purple-100 rounded-full flex items-center justify-center mb-4">
            <svg class="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
            </svg>
          </div>

          <h3 class="text-lg font-semibold text-gray-900 mb-2">Upload Files</h3>

          <%= if @uploading do %>
            <div class="mb-4">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600 mx-auto"></div>
              <p class="text-sm text-gray-600 mt-2">Uploading files...</p>
            </div>
          <% else %>
            <p class="text-gray-600 mb-6">Drag and drop files here or click to browse</p>

            <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 mb-6 hover:border-purple-400 transition-colors cursor-pointer">
              <input
                type="file"
                multiple
                class="hidden"
                id="file-input"
                phx-change="handle_file_upload"
                phx-target={@myself}
              />
              <label for="file-input" class="cursor-pointer">
                <div class="text-gray-500">
                  <svg class="w-8 h-8 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                  </svg>
                  Click to select files
                </div>
              </label>
            </div>
          <% end %>

          <div class="flex space-x-3 justify-center">
            <button
              phx-click="hide_upload_modal"
              phx-target={@myself}
              class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Event Handlers
  def handle_event("show_upload_modal", _params, socket) do
    {:noreply, assign(socket, :show_upload_modal, true)}
  end

  def handle_event("hide_upload_modal", _params, socket) do
    {:noreply, assign(socket, :show_upload_modal, false)}
  end

  def handle_event("toggle_all_selection", _params, socket) do
    files = socket.assigns.files
    selected_files = socket.assigns.selected_files
    all_file_ids = MapSet.new(Enum.map(files, & &1.id))

    new_selected = if MapSet.equal?(selected_files, all_file_ids) do
      MapSet.new() # Deselect all
    else
      all_file_ids # Select all
    end

    {:noreply, assign(socket, :selected_files, new_selected)}
  end

  def handle_event("toggle_file_selection", %{"file-id" => file_id}, socket) do
    file_id_int = String.to_integer(file_id)
    selected_files = socket.assigns.selected_files

    new_selected = if MapSet.member?(selected_files, file_id_int) do
      MapSet.delete(selected_files, file_id_int)
    else
      MapSet.put(selected_files, file_id_int)
    end

    {:noreply, assign(socket, :selected_files, new_selected)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_files, MapSet.new())}
  end

  def handle_event("bulk_delete", _params, socket) do
    file_ids = MapSet.to_list(socket.assigns.selected_files)

    case Media.bulk_delete_files(file_ids, socket.assigns.current_user) do
      {:ok, _} ->
        send(self(), {:files_deleted, file_ids})
        {:noreply, assign(socket, :selected_files, MapSet.new())}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete some files")}
    end
  end

  def handle_event("delete_file", %{"file-id" => file_id}, socket) do
    case Media.delete_media_file(String.to_integer(file_id), socket.assigns.current_user) do
      {:ok, _} ->
        send(self(), {:file_deleted, String.to_integer(file_id)})
        {:noreply, socket}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete file")}
    end
  end

  def handle_event("download_file", %{"file-id" => file_id}, socket) do
    # Trigger download via JavaScript
    file = Media.get_media_file!(file_id)
    {:noreply, push_event(socket, "download", %{url: Media.get_file_url(file), filename: file.original_filename})}
  end

  def handle_event("toggle_view", %{"view" => view}, socket) do
    send(self(), {:view_mode_changed, view})
    {:noreply, assign(socket, :view_mode, view)}
  end

  def handle_event("handle_file_upload", _params, socket) do
    # Handle file upload logic here
    # This would integrate with your existing upload system
    {:noreply, assign(socket, :uploading, true)}
  end

  # Helper Functions
  defp get_file_type_bg(file_type) do
    case file_type do
      "image" -> "bg-pink-600"
      "video" -> "bg-red-600"
      "audio" -> "bg-purple-600"
      "document" -> "bg-blue-600"
      _ -> "bg-gray-600"
    end
  end

  defp get_file_type_icon(file_type) do
    case file_type do
      "image" -> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z\"/>"
      "video" -> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z\"/>"
      "audio" -> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3\"/>"
      _ -> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z\"/>"
    end
  end

  defp format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_file_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_file_size(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  defp format_file_size(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"

  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp format_date(%NaiveDateTime{} = ndt), do: Calendar.strftime(ndt, "%b %d, %Y")
  defp format_date(_), do: "Unknown"
end
