# lib/frestyl_web/live/channel_live/media_upload_component.ex
defmodule FrestylWeb.ChannelLive.MediaUploadComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Media

  @impl true
  def mount(socket) do
    {:ok,
      socket
      |> allow_upload(:media,
        accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .mp3 .wav .pdf .doc .docx .xls .xlsx),
        max_file_size: 100_000_000, # 100MB
        max_entries: 10
      )
      |> assign(:uploading, false)
    }
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
      socket
      |> assign(assigns)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="upload-component">
      <form id="upload-form" phx-target={@myself} phx-submit="save" phx-change="validate">
        <div class="upload-header">
          <h3 class="text-lg font-medium text-gray-900 mb-2">Upload Media Files</h3>
          <p class="text-sm text-gray-500 mb-4">
            You can upload images, videos, audio, and documents. Maximum file size: 100MB.
          </p>
        </div>

        <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center"
             phx-drop-target={@uploads.media.ref}
             id="dropzone-container">
          <div class="flex flex-col items-center">
            <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-gray-400 mb-4">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
              <polyline points="17 8 12 3 7 8"></polyline>
              <line x1="12" y1="3" x2="12" y2="15"></line>
            </svg>
            <p class="text-base text-gray-600 mb-4">Drag and drop files here or click to browse</p>
            <label class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-[#DD1155] hover:bg-[#C4134E] cursor-pointer">
              Browse Files
              <.live_file_input upload={@uploads.media} class="sr-only" />
            </label>
          </div>
        </div>

        <%= if !Enum.empty?(@uploads.media.entries) do %>
          <div class="mt-6">
            <h4 class="text-base font-medium text-gray-900 mb-3">Selected Files</h4>

            <div class="space-y-3">
              <%= for entry <- @uploads.media.entries do %>
                <div class="flex items-center bg-gray-50 p-3 rounded-lg">
                  <div class="flex-shrink-0 mr-3">
                    <%= if String.starts_with?(entry.client_type, "image/") do %>
                      <.live_img_preview entry={entry} width="48" height="48" class="object-cover rounded" />
                    <% else %>
                      <div class="w-12 h-12 bg-gray-200 rounded flex items-center justify-center text-gray-500" id={"preview-icon-#{entry.ref}"}>
                        <%= cond do %>
                          <% String.starts_with?(entry.client_type, "video/") -> %>
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                            </svg>
                          <% String.starts_with?(entry.client_type, "audio/") -> %>
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                            </svg>
                          <% true -> %>
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                            </svg>
                        <% end %>
                      </div>
                    <% end %>
                  </div>

                  <div class="flex-grow">
                    <div class="flex items-center justify-between">
                      <p class="text-sm font-medium text-gray-900 truncate" title={entry.client_name}>
                        <%= entry.client_name %>
                      </p>
                      <button
                        type="button"
                        phx-click="cancel-upload"
                        phx-value-ref={entry.ref}
                        phx-target={@myself}
                        class="ml-2 text-gray-400 hover:text-red-500"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>

                    <span class="text-xs text-gray-500">
                      <%= cond do %>
                        <% entry.client_size < 1024 -> %>
                          <%= entry.client_size %> B
                        <% entry.client_size < 1024 * 1024 -> %>
                          <%= Float.round(entry.client_size / 1024, 1) %> KB
                        <% entry.client_size < 1024 * 1024 * 1024 -> %>
                          <%= Float.round(entry.client_size / 1024 / 1024, 1) %> MB
                        <% true -> %>
                          <%= Float.round(entry.client_size / 1024 / 1024 / 1024, 1) %> GB
                      <% end %>
                    </span>

                    <div class="mt-1 relative pt-1">
                      <div class="overflow-hidden h-2 text-xs flex rounded bg-gray-200">
                        <div style={"width: #{entry.progress}%"} class="shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center bg-[#DD1155]"></div>
                      </div>
                      <span class="text-xs text-gray-500 mt-1 inline-block">
                        <%= entry.progress %>%
                      </span>
                    </div>

                    <%= for err <- upload_errors(@uploads.media, entry) do %>
                      <p class="mt-1 text-xs text-red-500"><%= error_to_string(err) %></p>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Upload Button -->
              <div class="mt-4 flex justify-end">
                <button
                  type="submit"
                  class={"inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-[#DD1155] hover:bg-[#C4134E] #{if @uploading, do: "opacity-50 cursor-not-allowed", else: ""}"}
                  disabled={@uploading}
                >
                  <%= if @uploading do %>
                    <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    Uploading...
                  <% else %>
                    Upload Files
                  <% end %>
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  @impl true
  def handle_event("save", params, socket) do
    current_user_id = socket.assigns.current_user.id
    channel_id = socket.assigns.channel_id

    # Get the category from params
    category = case params["category"] do
      nil -> :general
      category when category in ["branding", "presentation", "performance", "general"] ->
        String.to_existing_atom(category)
      _ ->
        :general
    end

    socket = assign(socket, :uploading, true)

    uploaded_files =
      consume_uploaded_entries(socket, :media, fn %{path: path} = upload_entry, entry ->
        # Process the uploaded file with category
        case Media.process_upload(entry, socket.assigns.current_user, channel_id, %{category: category}) do
          {:ok, media_file} -> {:ok, media_file}
          {:error, reason} -> {:error, reason}
        end
      end)

    # Notify parent LiveView to refresh the files list
    send(self(), {:media_updated})

    # Update flash message to include information about the category
    category_name = category |> Atom.to_string() |> String.capitalize()

    {:noreply,
      socket
      |> assign(:uploading, false)
      |> put_flash(:info, "#{length(uploaded_files)} #{category_name} files uploaded successfully.")
    }
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(:not_accepted), do: "Unacceptable file type"
end
