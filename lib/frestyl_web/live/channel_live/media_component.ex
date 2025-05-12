# lib/frestyl_web/live/channel_live/media_component.ex
defmodule FrestylWeb.ChannelLive.MediaComponent do
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
    media_files = Media.list_channel_files(assigns.channel_id)

    socket =
      socket
      |> assign(assigns)
      |> assign(:media_files, media_files)
      |> assign(:filter, "all")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg overflow-hidden">
      <div class="px-4 py-5 sm:px-6 flex justify-between items-center">
        <h3 class="text-lg leading-6 font-medium text-gray-900">Media Files</h3>

        <label
          class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-[#DD1155] hover:bg-[#C4134E] cursor-pointer"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
          </svg>
          Upload Media
          <form phx-change="validate" phx-submit="save" phx-target={@myself}>
            <.live_file_input upload={@uploads.media} class="sr-only" />
          </form>
        </label>
      </div>

      <!-- Upload Preview (shows only when files are selected) -->
      <%= if !Enum.empty?(@uploads.media.entries) do %>
        <div class="px-4 py-4 sm:px-6 border-b border-gray-200">
          <h4 class="text-base font-medium text-gray-900 mb-3">Selected Files</h4>

          <div class="space-y-3">
            <%= for entry <- @uploads.media.entries do %>
              <div class="flex items-center bg-gray-50 p-3 rounded-lg">
                <div class="flex-shrink-0 mr-3">
                  <%= if String.starts_with?(entry.client_type, "image/") do %>
                    <.live_img_preview entry={entry} width="48" height="48" class="object-cover rounded" />
                  <% else %>
                    <div class="w-12 h-12 bg-gray-200 rounded flex items-center justify-center text-gray-500">
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
            <div class="mt-3 flex justify-end">
            # In the media_component.ex file, replace the button with this:
              <button
                type="button"
                phx-click="save"
                phx-target={@myself}
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

      <div class="px-4 py-5 sm:px-6">
        <!-- Filter tabs -->
        <div class="flex space-x-2 border-b border-gray-200 mb-4">
          <button
            phx-click="filter_media"
            phx-value-type="all"
            phx-target={@myself}
            class={[
              "px-3 py-2 text-sm font-medium border-b-2",
              @filter == "all" && "border-[#DD1155] text-[#DD1155]",
              @filter != "all" && "border-transparent text-gray-500 hover:text-gray-700"
            ]}
          >
            All
          </button>
          <button
            phx-click="filter_media"
            phx-value-type="image"
            phx-target={@myself}
            class={[
              "px-3 py-2 text-sm font-medium border-b-2",
              @filter == "image" && "border-[#DD1155] text-[#DD1155]",
              @filter != "image" && "border-transparent text-gray-500 hover:text-gray-700"
            ]}
          >
            Images
          </button>
          <button
            phx-click="filter_media"
            phx-value-type="video"
            phx-target={@myself}
            class={[
              "px-3 py-2 text-sm font-medium border-b-2",
              @filter == "video" && "border-[#DD1155] text-[#DD1155]",
              @filter != "video" && "border-transparent text-gray-500 hover:text-gray-700"
            ]}
          >
            Videos
          </button>
          <button
            phx-click="filter_media"
            phx-value-type="audio"
            phx-target={@myself}
            class={[
              "px-3 py-2 text-sm font-medium border-b-2",
              @filter == "audio" && "border-[#DD1155] text-[#DD1155]",
              @filter != "audio" && "border-transparent text-gray-500 hover:text-gray-700"
            ]}
          >
            Audio
          </button>
          <button
            phx-click="filter_media"
            phx-value-type="document"
            phx-target={@myself}
            class={[
              "px-3 py-2 text-sm font-medium border-b-2",
              @filter == "document" && "border-[#DD1155] text-[#DD1155]",
              @filter != "document" && "border-transparent text-gray-500 hover:text-gray-700"
            ]}
          >
            Documents
          </button>
        </div>

        <!-- Media grid -->
        <%= if filtered_files(@media_files, @filter) == [] do %>
          <div class="text-center py-12">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m-9 1V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z" />
            </svg>
            <p class="mt-2 text-sm text-gray-500">No media files found</p>
            <p class="text-sm text-gray-500">Upload a file to get started</p>
          </div>
        <% else %>
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            <%= for file <- filtered_files(@media_files, @filter) do %>
              <div
                id={"media-preview-#{file.id}"}
                phx-hook="MediaPreview"
                data-media-type={file.media_type}
                data-media-url={Media.get_media_url(file)}
                class="relative overflow-hidden rounded-lg cursor-pointer group"
              >
                <%= if file.media_type == "image" do %>
                  <div class="aspect-w-16 aspect-h-9 bg-gray-100">
                    <img src={Media.get_media_url(file)} alt={file.title || file.filename} class="object-cover" />
                  </div>
                <% else %>
                  <div class="aspect-w-16 aspect-h-9 bg-gray-100 flex items-center justify-center">
                    <%= if file.media_type == "video" do %>
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 text-[#DD1155]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    <% end %>
                    <%= if file.media_type == "audio" do %>
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 text-[#DD1155]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                      </svg>
                    <% end %>
                    <%= if file.media_type == "document" do %>
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                    <% end %>
                  </div>
                <% end %>

                <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-40 transition-all duration-200"></div>

                <div class="absolute bottom-0 left-0 right-0 p-2 bg-gradient-to-t from-black to-transparent">
                  <p class="text-white text-sm truncate"><%= file.title || file.filename %></p>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("filter_media", %{"type" => type}, socket) do
    {:noreply, assign(socket, :filter, type)}
  end

  @impl true
  def handle_event("view_media", %{"id" => id}, socket) do
    # Notify the parent LiveView about the media selection
    send(self(), {:view_media, String.to_integer(id)})
    {:noreply, socket}
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
  def handle_event("save", _params, socket) do
    channel_id = socket.assigns.channel_id
    current_user = socket.assigns.current_user

    socket = assign(socket, :uploading, true)

    uploaded_files =
      consume_uploaded_entries(socket, :media, fn %{path: path} = upload_entry, entry ->
        # Process the uploaded file
        case Media.process_upload(entry, current_user, channel_id) do
          {:ok, media_file} -> {:ok, media_file}
          {:error, reason} -> {:error, reason}
        end
      end)

    # Notify parent LiveView to refresh the files list
    send(self(), {:media_updated})

    {:noreply,
      socket
      |> assign(:uploading, false)
      |> put_flash(:info, "#{length(uploaded_files)} files uploaded successfully.")
    }
  end

  defp filtered_files(files, "all"), do: files
  defp filtered_files(files, type), do: Enum.filter(files, &(&1.media_type == type))

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(:not_accepted), do: "Unacceptable file type"
end
