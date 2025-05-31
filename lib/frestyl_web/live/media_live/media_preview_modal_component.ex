defmodule FrestylWeb.MediaLive.MediaPreviewModalComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Media
  alias FrestylWeb.MediaLive.MediaHelpers

  def mount(socket) do
    {:ok, assign(socket, :comment_form, %{"content" => ""})}
  end

  def update(%{file: file} = assigns, socket) do
    # Subscribe to comments for this file
    Media.subscribe_to_file_comments(file.id)

    # Load existing comments
    comments = Media.list_threaded_comments_for_file(file.id)

    socket =
      socket
      |> assign(assigns)
      |> assign(:comments, comments)
      |> assign(:comment_form, %{"content" => ""})

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div
      id={"media-modal-#{@id}"}
      class="fixed inset-0 z-50 overflow-hidden"
      phx-mounted={show_modal()}
      phx-remove={hide_modal()}
      phx-click="close_modal"
      phx-target={@myself}
      phx-hook="ModalKeyboardNav"
    >
      <!-- Backdrop -->
      <div class="absolute inset-0 bg-black bg-opacity-75 transition-opacity duration-300 modal-backdrop"></div>

      <!-- Modal Container -->
      <div class="relative flex items-center justify-center min-h-screen p-4">
        <div
          class="relative bg-white rounded-2xl shadow-2xl max-w-6xl w-full max-h-[90vh] overflow-hidden transform transition-all duration-300"
          phx-click="prevent_close"
          phx-target={@myself}
        >
          <!-- Header -->
          <div class="flex items-center justify-between p-6 border-b border-gray-200">
            <div class="flex items-center space-x-4">
              <div class={[
                "w-10 h-10 rounded-xl flex items-center justify-center",
                MediaHelpers.media_type_bg(@file.media_type)
              ]}>
                <svg class={["w-5 h-5", MediaHelpers.media_type_color(@file.media_type)]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <%= raw(MediaHelpers.media_type_icon(@file.media_type)) %>
                </svg>
              </div>
              <div>
                <h2 class="text-lg font-semibold text-gray-900 truncate max-w-md">
                  <%= @file.title || @file.original_filename %>
                </h2>
                <p class="text-sm text-gray-500">
                  <%= String.capitalize(@file.media_type) %> • <%= MediaHelpers.format_bytes(@file.file_size) %>
                </p>
              </div>
            </div>

            <div class="flex items-center space-x-3">
              <!-- Navigation with keyboard hints -->
              <%= if @has_prev or @has_next do %>
                <div class="flex items-center space-x-1">
                  <button
                    phx-click="navigate_prev"
                    phx-target={@myself}
                    disabled={!@has_prev}
                    class={[
                      "p-2 rounded-lg transition-colors duration-200 relative group",
                      if(@has_prev, do: "hover:bg-gray-100 text-gray-700", else: "text-gray-300 cursor-not-allowed")
                    ]}
                    title={if @has_prev, do: "Previous (←)", else: "No previous file"}
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                    </svg>
                  </button>
                  <button
                    phx-click="navigate_next"
                    phx-target={@myself}
                    disabled={!@has_next}
                    class={[
                      "p-2 rounded-lg transition-colors duration-200 relative group",
                      if(@has_next, do: "hover:bg-gray-100 text-gray-700", else: "text-gray-300 cursor-not-allowed")
                    ]}
                    title={if @has_next, do: "Next (→)", else: "No next file"}
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                    </svg>
                  </button>
                </div>
              <% end %>

              <!-- Download Button -->
              <a
                href={get_download_url(@file)}
                download={@file.original_filename}
                class="p-2 rounded-lg hover:bg-gray-100 text-gray-700 transition-colors duration-200 relative group"
                title="Download (D)"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
              </a>

              <!-- Close Button -->
              <button
                phx-click="close_modal"
                phx-target={@myself}
                class="p-2 rounded-lg hover:bg-gray-100 text-gray-500 hover:text-gray-700 transition-colors duration-200"
                title="Close (Esc)"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>

          <!-- Content Area -->
          <div class="flex flex-col lg:flex-row max-h-[calc(90vh-80px)]">
            <!-- Media Preview -->
            <div class="flex-1 flex items-center justify-center bg-gray-50 p-8">
              <%= case @file.media_type do %>
                <% "image" -> %>
                  <div class="relative max-w-full max-h-full">
                    <img
                      src={get_file_url(@file)}
                      alt={@file.title || @file.original_filename}
                      class="max-w-full max-h-full object-contain rounded-lg shadow-lg cursor-zoom-in"
                      phx-click="toggle_zoom"
                      phx-target={@myself}
                      phx-hook="ImageZoom"
                      id={"preview-image-#{@file.id}"}
                    />
                  </div>

                <% "video" -> %>
                  <div class="w-full max-w-4xl">
                    <video
                      controls
                      class="w-full h-auto rounded-lg shadow-lg"
                      preload="metadata"
                      phx-hook="VideoPlayer"
                      id={"video-player-#{@file.id}"}
                    >
                      <source src={get_file_url(@file)} type={@file.content_type} />
                      Your browser does not support the video tag.
                    </video>
                  </div>

                <% "audio" -> %>
                  <div class="w-full max-w-md bg-white rounded-xl p-8 shadow-lg">
                    <div class="text-center mb-6">
                      <div class="w-20 h-20 mx-auto bg-green-100 rounded-full flex items-center justify-center mb-4">
                        <svg class="w-10 h-10 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <%= raw(MediaHelpers.media_type_icon("audio")) %>
                        </svg>
                      </div>
                      <h3 class="text-lg font-semibold text-gray-900 truncate">
                        <%= @file.title || @file.original_filename %>
                      </h3>
                    </div>
                    <audio
                      controls
                      class="w-full"
                      preload="metadata"
                      phx-hook="AudioPlayer"
                      id={"audio-player-#{@file.id}"}
                    >
                      <source src={get_file_url(@file)} type={@file.content_type} />
                      Your browser does not support the audio element.
                    </audio>
                  </div>

                <% "document" -> %>
                  <div class="w-full max-w-2xl bg-white rounded-xl p-8 shadow-lg text-center">
                    <div class="w-20 h-20 mx-auto bg-yellow-100 rounded-full flex items-center justify-center mb-6">
                      <svg class="w-10 h-10 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <%= raw(MediaHelpers.media_type_icon("document")) %>
                      </svg>
                    </div>
                    <h3 class="text-lg font-semibold text-gray-900 mb-2 truncate">
                      <%= @file.title || @file.original_filename %>
                    </h3>
                    <p class="text-gray-600 mb-6">
                      Document preview not available
                    </p>
                    <div class="space-y-3">
                      <a
                        href={get_download_url(@file)}
                        download={@file.original_filename}
                        class="inline-flex items-center px-4 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700 transition-colors duration-200"
                      >
                        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                        Download Document
                      </a>
                    </div>
                  </div>

                <% _ -> %>
                  <div class="text-center text-gray-500">
                    <div class="w-20 h-20 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4">
                      <svg class="w-10 h-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <%= raw(MediaHelpers.media_type_icon("document")) %>
                      </svg>
                    </div>
                    <p>Preview not available for this file type</p>
                  </div>
              <% end %>
            </div>

            <!-- Enhanced Sidebar with Comments -->
            <div class="w-full lg:w-96 bg-white border-l border-gray-200 flex flex-col">
              <!-- Engagement Stats -->
              <div class="p-6 border-b border-gray-200">
                <h3 class="text-sm font-semibold text-gray-900 mb-4">Engagement</h3>
                <div class="grid grid-cols-2 gap-4">
                  <div class="text-center">
                    <div class="text-2xl font-bold text-purple-600">
                      <%= MediaHelpers.format_number(get_in(@file.metadata, ["views"]) || 0) %>
                    </div>
                    <div class="text-xs text-gray-500">Views</div>
                  </div>
                  <div class="text-center">
                    <div class="text-2xl font-bold text-blue-600">
                      <%= length(@comments) %>
                    </div>
                    <div class="text-xs text-gray-500">Comments</div>
                  </div>
                  <div class="text-center">
                    <div class="text-2xl font-bold text-red-600">
                      <%= (@file.metadata["reactions"] || %{}) |> Map.values() |> Enum.sum() %>
                    </div>
                    <div class="text-xs text-gray-500">Reactions</div>
                  </div>
                  <div class="text-center">
                    <div class="text-2xl font-bold text-green-600">
                      <%= MediaHelpers.format_bytes(@file.file_size) %>
                    </div>
                    <div class="text-xs text-gray-500">Size</div>
                  </div>
                </div>
              </div>

              <!-- Enhanced Reactions Section -->
              <div class="p-6 border-b border-gray-200" phx-hook="ReactionKeyboard" id="reaction-section">
                <.live_component
                  module={FrestylWeb.MediaLive.ReactionsComponent}
                  id={"reactions-modal-#{@file.id}"}
                  file={@file}
                  current_user={assigns[:current_user]}
                  mode={:full}
                />

                <!-- Reaction Insights -->
                <%= if assigns[:current_user] do %>
                  <div class="mt-4 pt-4 border-t border-gray-100">
                    <button
                      phx-click="show_reaction_details"
                      phx-target={@myself}
                      class="text-xs text-purple-600 hover:text-purple-700 font-medium flex items-center space-x-1"
                    >
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <span>See who reacted</span>
                    </button>
                  </div>
                <% end %>
              </div>


              <!-- Enhanced Comments Section with Threading -->
              <div class="flex-1 flex flex-col">
                <.live_component
                  module={FrestylWeb.MediaLive.EnhancedCommentsComponent}
                  id={"enhanced-comments-#{@file.id}"}
                  file={@file}
                  current_user={assigns[:current_user]}
                />
              </div>


              <!-- File Details -->
              <div class="p-6 border-t border-gray-200">
                <h3 class="text-sm font-semibold text-gray-900 mb-4">Details</h3>
                <div class="space-y-3 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-500">Original Name:</span>
                    <span class="text-gray-900 font-medium truncate ml-2 max-w-32" title={@file.original_filename}>
                      <%= @file.original_filename %>
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-500">Type:</span>
                    <span class="text-gray-900 font-medium">
                      <%= String.capitalize(@file.media_type) %>
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-500">Uploaded:</span>
                    <span class="text-gray-900 font-medium">
                      <%= MediaHelpers.format_relative_time(@file.inserted_at) %>
                    </span>
                  </div>
                  <%= if @file.channel do %>
                    <div class="flex justify-between">
                      <span class="text-gray-500">Channel:</span>
                      <span class="text-gray-900 font-medium truncate ml-2 max-w-32">
                        <%= @file.channel.name %>
                      </span>
                    </div>
                  <% end %>
                  <%= if @file.description do %>
                    <div class="pt-2">
                      <span class="text-gray-500 block mb-1">Description:</span>
                      <p class="text-gray-900 text-sm leading-relaxed">
                        <%= @file.description %>
                      </p>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Actions -->
              <div class="p-6 border-t border-gray-200">
                <div class="space-y-2">
                  <button
                    phx-click="delete_file"
                    phx-target={@myself}
                    data-confirm="Are you sure you want to delete this file?"
                    class="w-full flex items-center justify-center px-4 py-2 border border-red-300 text-red-600 rounded-lg hover:bg-red-50 transition-colors duration-200"
                  >
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                    Delete File
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Event Handlers
  def handle_event("close_modal", _params, socket) do
    send(self(), :close_media_preview)
    {:noreply, socket}
  end

  def handle_event("prevent_close", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_zoom", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("navigate_prev", _params, socket) do
    send(self(), :navigate_prev_media)
    {:noreply, socket}
  end

  def handle_event("navigate_next", _params, socket) do
    send(self(), :navigate_next_media)
    {:noreply, socket}
  end

  def handle_event("add_reaction", %{"type" => reaction_type}, socket) do
    case Media.track_reaction(socket.assigns.file, reaction_type) do
      {:ok, updated_file} ->
        send(self(), {:media_file_updated, updated_file})
        {:noreply, assign(socket, :file, updated_file)}
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("submit_comment", %{"content" => content}, socket) do
    current_user = socket.assigns[:current_user]

    if current_user && String.trim(content) != "" do
      attrs = %{
        "content" => String.trim(content),
        "asset_id" => socket.assigns.file.id
      }

      case Media.create_comment(attrs, current_user) do
        {:ok, _comment} ->
          # Reset form and update comments list
          {:noreply, assign(socket, :comment_form, %{"content" => ""})}
        {:error, _changeset} ->
          # Handle error - could add flash message
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_comment_keydown", %{"key" => "Enter", "shiftKey" => false}, socket) do
    # Submit on Enter (without Shift)
    content = socket.assigns.comment_form["content"] || ""
    if String.trim(content) != "" do
      send_update(self(), __MODULE__, id: socket.assigns.id, action: :submit_comment)
    end
    {:noreply, socket}
  end

  def handle_event("handle_comment_keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("delete_comment", %{"comment-id" => comment_id}, socket) do
    current_user = socket.assigns[:current_user]

    if current_user do
      case Media.get_comment(comment_id) do
        nil -> {:noreply, socket}
        comment ->
          case Media.delete_comment(comment, current_user) do
            {:ok, _} -> {:noreply, socket}  # Real-time update via PubSub
            {:error, :unauthorized} -> {:noreply, socket}
            _ -> {:noreply, socket}
          end
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_file", _params, socket) do
    case Media.delete_media_file(socket.assigns.file) do
      {:ok, _} ->
        send(self(), {:media_file_deleted, socket.assigns.file})
        send(self(), :close_media_preview)
        {:noreply, socket}
      {:error, _} ->
        send(self(), {:put_flash, :error, "Failed to delete file"})
        {:noreply, socket}
    end
  end

  # Handle real-time comment updates
  def handle_info({:comment_created, comment}, socket) do
    if comment.asset_id == socket.assigns.file.id do
      updated_comments = [comment | socket.assigns.comments]
      {:noreply, assign(socket, :comments, updated_comments)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:comment_deleted, comment}, socket) do
    if comment.asset_id == socket.assigns.file.id do
      updated_comments = Enum.reject(socket.assigns.comments, &(&1.id == comment.id))
      {:noreply, assign(socket, :comments, updated_comments)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:comment_updated, comment}, socket) do
    if comment.asset_id == socket.assigns.file.id do
      updated_comments = Enum.map(socket.assigns.comments, fn c ->
        if c.id == comment.id, do: comment, else: c
      end)
      {:noreply, assign(socket, :comments, updated_comments)}
    else
      {:noreply, socket}
    end
  end

  # Helper functions
  defp show_modal do
    JS.show(
      transition: {"transition-all transform ease-out duration-300",
                   "opacity-0 scale-95", "opacity-100 scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
  end

  defp hide_modal do
    JS.hide(
      transition: {"transition-all transform ease-in duration-200",
                   "opacity-100 scale-100", "opacity-0 scale-95"}
    )
    |> JS.remove_class("overflow-hidden", to: "body")
  end

  defp get_file_url(file) do
    Media.get_file_url(file)
  end

  defp get_download_url(file) do
    url = get_file_url(file)
    if String.contains?(url, "?") do
      url <> "&download=1"
    else
      url <> "?download=1"
    end
  end

  defp get_user_initials(user) do
    name = user.name || user.username || "U"
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp format_comment_time(datetime) do
    now = DateTime.utc_now()

    # Convert NaiveDateTime to DateTime if needed
    datetime = case datetime do
      %NaiveDateTime{} -> DateTime.from_naive!(datetime, "Etc/UTC")
      %DateTime{} -> datetime
      _ -> now
    end

    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)}d"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
