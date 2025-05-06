# lib/frestyl_web/live/channel_live/media_component.ex
defmodule FrestylWeb.ChannelLive.MediaComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Media

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

        <button
          phx-click="show_media_upload"
          class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-[#DD1155] hover:bg-[#C4134E]"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
          </svg>
          Upload Media
        </button>
      </div>

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
                phx-click="view_media"
                phx-value-id={file.id}
                phx-target={@myself}
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

  defp filtered_files(files, "all"), do: files
  defp filtered_files(files, type), do: Enum.filter(files, &(&1.media_type == type))
end
