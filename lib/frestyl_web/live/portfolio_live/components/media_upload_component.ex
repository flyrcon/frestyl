# File: lib/frestyl_web/live/portfolio_live/components/media_upload_component.ex
defmodule FrestylWeb.PortfolioLive.Components.MediaUploadComponent do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    socket = socket
    |> assign(:upload_state, :idle)
    |> assign(:upload_progress, 0)
    |> assign(:error_message, nil)
    |> allow_upload(:media_files,
      accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .webm .pdf),
      max_entries: 5,
      max_file_size: 10_000_000  # 10MB
    )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_files", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :media_files, fn %{path: path}, entry ->
        # Process the uploaded file
        case process_media_file(path, entry) do
          {:ok, file_data} -> {:ok, file_data}
          {:error, reason} -> {:postpone, reason}
        end
      end)

    case uploaded_files do
      [] ->
        {:noreply, put_flash(socket, :error, "No files were uploaded")}

      files when is_list(files) ->
        # Send files to parent component
        send(self(), {:media_uploaded, files})

        socket = socket
        |> assign(:upload_state, :complete)
        |> put_flash(:info, "#{length(files)} files uploaded successfully!")

        {:noreply, socket}
    end
  end

  defp process_media_file(path, entry) do
    file_extension = Path.extname(entry.client_name) |> String.downcase()

    # Generate unique filename
    unique_filename = "#{System.unique_integer()}_#{entry.client_name}"

    # Determine file type
    file_type = case file_extension do
      ext when ext in [".jpg", ".jpeg", ".png", ".gif"] -> "image"
      ext when ext in [".mp4", ".mov", ".webm"] -> "video"
      ".pdf" -> "document"
      _ -> "unknown"
    end

    # TODO: Upload to your storage system (S3, local, etc.)
    # For now, we'll simulate with a local copy
    upload_path = "/uploads/#{unique_filename}"

    case File.cp(path, "priv/static#{upload_path}") do
      :ok ->
        {:ok, %{
          original_name: entry.client_name,
          filename: unique_filename,
          url: upload_path,
          file_type: file_type,
          file_size: entry.client_size,
          uploaded_at: DateTime.utc_now()
        }}

      {:error, reason} ->
        {:error, "Failed to save file: #{reason}"}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="media-upload-component">
      <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-gray-400 transition-colors">
        <form id="upload-form" phx-submit="upload_files" phx-change="validate_upload" phx-target={@myself}>
          <.live_file_input upload={@uploads.media_files} class="hidden" />

          <div class="space-y-4">
            <div class="mx-auto h-12 w-12 text-gray-400">
              <svg fill="none" stroke="currentColor" viewBox="0 0 48 48">
                <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>

            <div>
              <label for={@uploads.media_files.ref} class="cursor-pointer">
                <span class="text-sm font-medium text-blue-600 hover:text-blue-500">
                  Click to upload files
                </span>
                <span class="text-sm text-gray-500"> or drag and drop</span>
              </label>
              <p class="text-xs text-gray-500 mt-1">
                Images, videos, or documents up to 10MB each
              </p>
            </div>
          </div>

          <!-- Upload Progress -->
          <%= if @upload_state == :uploading do %>
            <div class="mt-4">
              <div class="bg-gray-200 rounded-full h-2">
                <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{@upload_progress}%"}></div>
              </div>
              <p class="text-sm text-gray-600 mt-2">Uploading... <%= @upload_progress %>%</p>
            </div>
          <% end %>

          <!-- File Previews -->
          <%= for entry <- @uploads.media_files.entries do %>
            <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg mt-3">
              <div class="flex items-center space-x-3">
                <div class="flex-shrink-0">
                  <%= if String.contains?(entry.client_type, "image") do %>
                    <.live_img_preview entry={entry} class="h-10 w-10 rounded object-cover" />
                  <% else %>
                    <div class="h-10 w-10 bg-gray-200 rounded flex items-center justify-center">
                      <svg class="h-5 w-5 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h8a2 2 0 012 2v12a2 2 0 01-2 2H6a2 2 0 01-2-2V4zm2 0v12h8V4H6z" clip-rule="evenodd"/>
                      </svg>
                    </div>
                  <% end %>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-gray-900 truncate">
                    <%= entry.client_name %>
                  </p>
                  <p class="text-xs text-gray-500">
                    <%= format_file_size(entry.client_size) %>
                  </p>
                </div>
              </div>

              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                phx-target={@myself}
                class="text-red-600 hover:text-red-800">
                <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
                </svg>
              </button>
            </div>
          <% end %>

          <!-- Upload Button -->
          <%= if length(@uploads.media_files.entries) > 0 and @upload_state != :uploading do %>
            <button
              type="submit"
              class="mt-4 w-full bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors font-medium">
              Upload <%= length(@uploads.media_files.entries) %> Files
            </button>
          <% end %>
        </form>
      </div>

      <!-- Error Messages -->
      <%= for err <- upload_errors(@uploads.media_files) do %>
        <div class="mt-2 text-sm text-red-600">
          <%= error_to_string(err) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_file_size(size) when is_integer(size) do
    cond do
      size >= 1_048_576 -> "#{Float.round(size / 1_048_576, 1)} MB"
      size >= 1_024 -> "#{Float.round(size / 1_024, 1)} KB"
      true -> "#{size} B"
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(:too_many_files), do: "Too many files (max 5)"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
