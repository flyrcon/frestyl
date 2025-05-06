# lib/frestyl_web/live/channel_live/media_upload_component.ex
defmodule FrestylWeb.ChannelLive.MediaUploadComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Media

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> allow_upload(:media_file,
       accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .mp3 .wav .pdf .doc .docx .xls .xlsx .txt),
       max_file_size: 100_000_000, # 100MB
       auto_upload: true
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="media-upload-form">
      <div class="border-2 border-dashed border-gray-300 rounded-lg p-6">
        <div class="flex flex-col items-center justify-center space-y-2">
          <.form for={%{}} id="upload-form" phx-change="validate" phx-submit="save" phx-target={@myself}>
            <div class="flex flex-col items-center">
              <label for={@uploads.media_file.ref} class="cursor-pointer bg-brand hover:bg-brand-dark text-white font-bold py-2 px-4 rounded">
                Select File
              </label>
              <.live_file_input upload={@uploads.media_file} class="hidden" />
              <p class="mt-2 text-sm text-gray-500">or drag and drop</p>
              <p class="text-xs text-gray-400">Max file size: 100MB</p>
            </div>

            <%= for entry <- @uploads.media_file.entries do %>
              <div class="mt-4 bg-white p-4 rounded-md shadow-sm">
                <div class="flex items-center justify-between">
                  <div class="flex items-center space-x-2">
                    <div class="text-brand">
                      <%= if String.starts_with?(entry.client_type, "image/") do %>
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                      <% else %>
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
                        </svg>
                      <% end %>
                    </div>
                    <div>
                      <p class="text-sm font-medium text-gray-900 truncate"><%= entry.client_name %></p>
                      <p class="text-xs text-gray-500"><%= human_file_size(entry.client_size) %></p>
                    </div>
                  </div>

                  <button type="button" phx-click="cancel-upload" phx-target={@myself} phx-value-ref={entry.ref} class="text-gray-400 hover:text-gray-500">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>

                <!-- Progress bar -->
                <div class="mt-2">
                  <div class="bg-gray-200 rounded-full h-2.5 dark:bg-gray-700 w-full">
                    <div class="bg-brand h-2.5 rounded-full" style={"width: #{entry.progress}%"}></div>
                  </div>
                </div>

                <!-- Error messages -->
                <%= for err <- upload_errors(@uploads.media_file, entry) do %>
                  <p class="mt-1 text-sm text-red-500"><%= error_message(err) %></p>
                <% end %>
              </div>
            <% end %>

            <!-- Form fields for metadata -->
            <%= if @uploads.media_file.entries != [] do %>
              <div class="mt-4 space-y-4">
                <div>
                  <label for="title" class="block text-sm font-medium text-gray-700">Title</label>
                  <input type="text" name="title" id="title" class="mt-1 focus:ring-brand focus:border-brand block w-full sm:text-sm border-gray-300 rounded-md" />
                </div>

                <div>
                  <label for="description" class="block text-sm font-medium text-gray-700">Description</label>
                  <textarea name="description" id="description" rows="3" class="mt-1 focus:ring-brand focus:border-brand block w-full sm:text-sm border-gray-300 rounded-md"></textarea>
                </div>

                <button type="submit" class="w-full bg-brand hover:bg-brand-dark text-white font-bold py-2 px-4 rounded">
                  Upload
                </button>
              </div>
            <% end %>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media_file, ref)}
  end

  @impl true
  def handle_event("save", %{"title" => title, "description" => description}, socket) do
    channel_id = socket.assigns.channel_id
    user_id = socket.assigns.current_user.id

    uploaded_files =
      consume_uploaded_entries(socket, :media_file, fn %{path: path}, entry ->
        # Create a media file entry in the database
        attrs = %{
          filename: entry.client_name,
          original_filename: entry.client_name,
          content_type: entry.client_type,
          file_size: entry.client_size,
          user_id: user_id,
          channel_id: channel_id,
          title: if(title == "", do: nil, else: title),
          description: if(description == "", do: nil, else: description)
        }

        # Load the file data and create the media file
        file_data = %{path: path}
        Media.create_media_file(attrs, file_data)
      end)

    # Send a message to the parent LiveView to refresh media list
    send(self(), {:media_uploaded, uploaded_files})

    {:noreply, socket}
  end

  defp human_file_size(bytes) do
    cond do
      bytes < 1_024 -> "#{bytes} B"
      bytes < 1_024 * 1_024 -> "#{Float.round(bytes / 1_024, 1)} KB"
      bytes < 1_024 * 1_024 * 1_024 -> "#{Float.round(bytes / (1_024 * 1_024), 1)} MB"
      true -> "#{Float.round(bytes / (1_024 * 1_024 * 1_024), 1)} GB"
    end
  end

  defp error_message(:too_large), do: "File is too large (max 100MB)"
  defp error_message(:not_accepted), do: "File type not accepted"
  defp error_message(:too_many_files), do: "Too many files"
  defp error_message(_), do: "An error occurred during upload"
end
