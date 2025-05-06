# lib/frestyl_web/live/channel_live/media_viewer_component.ex
defmodule FrestylWeb.ChannelLive.MediaViewerComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Media
  alias Frestyl.Accounts

  @impl true
  def update(%{file_id: file_id} = assigns, socket) do
    file = Media.get_media_file!(file_id)
    user = Accounts.get_user!(file.user_id)

    socket =
      socket
      |> assign(assigns)
      |> assign(:file, file)
      |> assign(:uploader, user)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true"></div>

        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-5xl sm:w-full">
          <div class="bg-white">
            <div class="flex items-center justify-between px-4 py-3 border-b border-gray-200 sm:px-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900" id="modal-title">
                <%= @file.title || @file.filename %>
              </h3>
              <button
                type="button"
                phx-click="close_viewer"
                phx-target={@myself}
                class="bg-white rounded-md text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-brand"
              >
                <span class="sr-only">Close</span>
                <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div class="px-4 py-5 sm:p-6">
              <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <!-- Media Preview -->
                <div class="lg:col-span-2">
                  <%= case @file.media_type do %>
                    <% "image" -> %>
                      <div class="bg-gray-100 rounded-lg overflow-hidden">
                        <img src={Media.get_media_url(@file)} alt={@file.title || @file.filename} class="w-full h-auto" />
                      </div>

                    <% "video" -> %>
                      <div class="bg-black rounded-lg overflow-hidden">
                        <video controls class="w-full h-auto">
                          <source src={Media.get_media_url(@file)} type={@file.content_type}>
                          Your browser does not support the video tag.
                        </video>
                      </div>

                    <% "audio" -> %>
                      <div class="bg-gray-100 rounded-lg p-6">
                        <div class="flex items-center justify-center p-4 mb-4">
                          <div class="rounded-full bg-[#DD1155] p-6">
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                            </svg>
                          </div>
                        </div>
                        <audio controls class="w-full">
                          <source src={Media.get_media_url(@file)} type={@file.content_type}>
                          Your browser does not support the audio tag.
                        </audio>
                      </div>

                    <% "document" -> %>
                      <div class="bg-gray-100 rounded-lg p-6">
                        <div class="flex flex-col items-center justify-center">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-24 w-24 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                          </svg>
                          <p class="mt-4 text-gray-900 font-medium"><%= @file.filename %></p>
                          <p class="text-gray-500 text-sm"><%= human_file_size(@file.file_size) %></p>
                          <a
                            href={Media.get_media_url(@file)}
                            download={@file.filename}
                            class="mt-6 inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-[#DD1155] hover:bg-[#C4134E] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#DD1155]"
                          >
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                            </svg>
                            Download
                          </a>
                        </div>
                      </div>

                    <% _ -> %>
                      <div class="bg-gray-100 rounded-lg p-6">
                        <div class="flex flex-col items-center justify-center">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-24 w-24 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                          </svg>
                          <p class="mt-4 text-gray-900 font-medium"><%= @file.filename %></p>
                          <p class="text-gray-500 text-sm"><%= human_file_size(@file.file_size) %></p>
                        </div>
                      </div>
                  <% end %>
                </div>

                <!-- Media Info -->
                <div class="space-y-6">
                  <!-- File Details -->
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Details</h4>
                    <dl class="mt-2 divide-y divide-gray-200">
                      <div class="py-2 flex justify-between">
                        <dt class="text-sm font-medium text-gray-500">Filename</dt>
                        <dd class="text-sm text-gray-900 text-right"><%= @file.filename %></dd>
                      </div>
                      <div class="py-2 flex justify-between">
                        <dt class="text-sm font-medium text-gray-500">Type</dt>
                        <dd class="text-sm text-gray-900 text-right"><%= String.capitalize(@file.media_type) %></dd>
                      </div>
                      <div class="py-2 flex justify-between">
                        <dt class="text-sm font-medium text-gray-500">Size</dt>
                        <dd class="text-sm text-gray-900 text-right"><%= human_file_size(@file.file_size) %></dd>
                      </div>
                      <div class="py-2 flex justify-between">
                        <dt class="text-sm font-medium text-gray-500">Uploaded by</dt>
                        <dd class="text-sm text-gray-900 text-right"><%= @uploader.email %></dd>
                      </div>
                      <div class="py-2 flex justify-between">
                        <dt class="text-sm font-medium text-gray-500">Date uploaded</dt>
                        <dd class="text-sm text-gray-900 text-right"><%= format_date(@file.inserted_at) %></dd>
                      </div>
                    </dl>
                  </div>

                  <!-- Description -->
                  <%= if @file.description do %>
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Description</h4>
                      <div class="mt-2 p-3 bg-gray-50 rounded-md">
                        <p class="text-sm text-gray-700 whitespace-pre-wrap"><%= @file.description %></p>
                      </div>
                    </div>
                  <% end %>

                  <!-- Actions -->
                  <div class="border-t border-gray-200 pt-4">
                    <h4 class="text-sm font-medium text-gray-500">Actions</h4>
                    <div class="mt-2 flex flex-col space-y-2">
                      <a
                        href={Media.get_media_url(@file)}
                        download={@file.filename}
                        target="_blank"
                        class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#DD1155]"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                        Download
                      </a>

                      <%= if @current_user.id == @file.user_id or @is_admin do %>
                        <button
                          phx-click="delete_media"
                          phx-target={@myself}
                          phx-value-id={@file.id}
                          class="inline-flex items-center px-4 py-2 border border-red-300 rounded-md shadow-sm text-sm font-medium text-red-700 bg-white hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                          data-confirm="Are you sure you want to delete this file? This action cannot be undone."
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                          </svg>
                          Delete
                        </button>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("close_viewer", _params, socket) do
    send(self(), :close_media_viewer)
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_media", %{"id" => id}, socket) do
    file_id = String.to_integer(id)
    file = Media.get_media_file!(file_id)

    # Only allow the uploader or admin to delete the file
    if socket.assigns.current_user.id == file.user_id or socket.assigns.is_admin do
      Media.delete_media_file(file)
      send(self(), {:media_deleted, file})
    end

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

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %H:%M")
  end
end
