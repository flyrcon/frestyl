# lib/frestyl_web/live/channel_live/media_gallery_component.ex
defmodule FrestylWeb.ChannelLive.MediaGalleryComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Media

  @impl true
  def update(assigns, socket) do
    files = Media.list_channel_files(assigns.channel_id)

    socket =
      socket
      |> assign(assigns)
      |> assign(:files, files)
      |> assign(:filter, "all")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg overflow-hidden">
      <div class="border-b border-gray-200">
        <nav class="flex -mb-px">
          <button
            phx-click="filter"
            phx-value-type="all"
            phx-target={@myself}
            class={[
              "py-4 px-6 text-center border-b-2 font-medium text-sm",
              @filter == "all" && "border-[#DD1155] text-[#DD1155]",
              @filter != "all" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
            ]}
          >
            All
          </button>
          <button
            phx-click="filter"
            phx-value-type="image"
            phx-target={@myself}
            class={[
              "py-4 px-6 text-center border-b-2 font-medium text-sm",
              @filter == "image" && "border-[#DD1155] text-[#DD1155]",
              @filter != "image" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
            ]}
          >
            Images
          </button>
          <button
            phx-click="filter"
            phx-value-type="video"
            phx-target={@myself}
            class={[
              "py-4 px-6 text-center border-b-2 font-medium text-sm",
              @filter == "video" && "border-[#DD1155] text-[#DD1155]",
              @filter != "video" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
            ]}
          >
            Videos
          </button>
          <button
            phx-click="filter"
            phx-value-type="audio"
            phx-target={@myself}
            class={[
              "py-4 px-6 text-center border-b-2 font-medium text-sm",
              @filter == "audio" && "border-[#DD1155] text-[#DD1155]",
              @filter != "audio" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
            ]}
          >
            Audio
          </button>
          <button
            phx-click="filter"
            phx-value-type="document"
            phx-target={@myself}
            class={[
              "py-4 px-6 text-center border-b-2 font-medium text-sm",
              @filter == "document" && "border-[#DD1155] text-[#DD1155]",
              @filter != "document" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
            ]}
          >
            Documents
          </button>
        </nav>
      </div>

      <div class="p-6">
        <%= if filtered_files(@files, @filter) == [] do %>
          <div class="text-center py-8">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m-9 1V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z" />
            </svg>
            <p class="mt-2 text-sm text-gray-500">No media files found</p>

            <button
              phx-click="show_upload_modal"
              phx-target={@myself}
              class="mt-4 inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-[#DD1155] hover:bg-[#C4134E] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#DD1155]"
            >
              Upload Media
            </button>
          </div>
        <% else %>
          <div class={media_grid_class(@filter)}>
            <%= for file <- filtered_files(@files, @filter) do %>
              <div
                phx-click="view_media"
                phx-value-id={file.id}
                phx-target={@myself}
                class="relative overflow-hidden group cursor-pointer"
              >
                <%= case file.media_type do %>
                  <% "image" -> %>
                    <div class="aspect-w-16 aspect-h-9 bg-gray-100">
                      <img src={Media.get_media_url(file)} alt={file.title || file.filename} class="object-cover" />
                    </div>

                  <% "video" -> %>
                    <div class="aspect-w-16 aspect-h-9 bg-gray-800 flex items-center justify-center">
                      <div class="rounded-full bg-white bg-opacity-75 p-3">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-[#DD1155]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                      </div>
                    </div>

                  <% "audio" -> %>
                    <div class="aspect-w-16 aspect-h-9 bg-gray-100 flex items-center justify-center">
                      <div class="rounded-full bg-[#DD1155] p-4">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                        </svg>
                      </div>
                    </div>

                  <% "document" -> %>
                    <div class="aspect-w-16 aspect-h-9 bg-gray-100 flex items-center justify-center">
                      <div class="p-4">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                        </svg>
                      </div>
                    </div>

                  <% _ -> %>
                    <div class="aspect-w-16 aspect-h-9 bg-gray-100 flex items-center justify-center">
                      <div class="p-4">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                        </svg>
                      </div>
                    </div>
                <% end %>

                <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-40 transition-all duration-200"></div>

                <div class="absolute bottom-0 left-0 right-0 p-3 bg-gradient-to-t from-black to-transparent opacity-100">
                  <h3 class="text-white text-sm font-medium truncate">
                    <%= file.title || file.filename %>
                  </h3>
                  <p class="text-gray-300 text-xs truncate">
                    <%= human_file_size(file.file_size) %> • <%= format_date(file.inserted_at) %>
                  </p>
                </div>
              </div>
            <% end %>
          </div>

          <div class="mt-6 text-center">
            <button
              phx-click="show_upload_modal"
              phx-target={@myself}
              class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-[#DD1155] hover:bg-[#C4134E] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#DD1155]"
            >
              Upload More Media
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("filter", %{"type" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("view_media", %{"id" => id}, socket) do
    # Convert string ID to integer
    file_id = String.to_integer(id)

    # Notify the parent LiveView about the media selection
    send(self(), {:view_media, file_id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_upload_modal", _params, socket) do
    send(self(), :show_media_upload)
    {:noreply, socket}
  end

  # Helper functions

  defp filtered_files(files, "all"), do: files
  defp filtered_files(files, type), do: Enum.filter(files, &(&1.media_type == type))

  defp media_grid_class("image"), do: "grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4"
  defp media_grid_class(_), do: "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"

  defp human_file_size(bytes) do
    cond do
      bytes < 1_024 -> "#{bytes} B"
      bytes < 1_024 * 1_024 -> "#{Float.round(bytes / 1_024, 1)} KB"
      bytes < 1_024 * 1_024 * 1_024 -> "#{Float.round(bytes / (1_024 * 1_024), 1)} MB"
      true -> "#{Float.round(bytes / (1_024 * 1_024 * 1_024), 1)} GB"
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
