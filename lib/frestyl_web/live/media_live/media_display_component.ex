# lib/frestyl_web/live/media_live/media_display_component.ex
defmodule FrestylWeb.MediaLive.MediaDisplayComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Media

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
    <div class="media-display" id={"media-display-#{@media_file.id}"}>
      <div class="media-content">
        <%= case @media_file.media_type do %>
          <% "image" -> %>
            <div class="media-preview image-preview">
              <img src={Media.get_media_url(@media_file)} alt={@media_file.title || @media_file.original_filename} />
            </div>

          <% "video" -> %>
            <div class="media-preview video-preview">
              <video controls width="100%">
                <source src={Media.get_media_url(@media_file)} type={@media_file.content_type} />
                Your browser does not support the video tag.
              </video>
            </div>

          <% "audio" -> %>
            <div class="media-preview audio-preview">
              <audio controls>
                <source src={Media.get_media_url(@media_file)} type={@media_file.content_type} />
                Your browser does not support the audio tag.
              </audio>
            </div>

          <% _ -> %>
            <div class="media-preview document-preview">
              <div class="document-icon">
                <%= if @media_file.content_type == "application/pdf" do %>
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
                  </svg>
                <% else %>
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                <% end %>
              </div>
              <a href={Media.get_media_url(@media_file)} target="_blank" rel="noopener" class="document-link">
                View Document
              </a>
            </div>
        <% end %>
      </div>

      <div class="media-info">
        <h4 class="media-title"><%= @media_file.title || @media_file.original_filename %></h4>
        <div class="media-metadata">
          <p class="media-filename"><%= @media_file.original_filename %></p>
          <p class="media-type"><%= format_content_type(@media_file.content_type) %></p>
          <p class="media-size"><%= human_file_size(@media_file.file_size) %></p>
          <p class="media-date">Uploaded: <%= format_date(@media_file.inserted_at) %></p>
        </div>

        <div class="media-actions">
          <a href={Media.get_media_url(@media_file)} target="_blank" rel="noopener" class="btn btn-sm btn-primary">
            Download
          </a>

          <%= if @current_user.id == @media_file.user_id or @is_admin do %>
            <button class="btn btn-sm btn-danger"
                    phx-click="delete_media"
                    phx-value-id={@media_file.id}
                    phx-target={@myself}
                    data-confirm="Are you sure you want to delete this file?">
              Delete
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("delete_media", %{"id" => id}, socket) do
    file_id = String.to_integer(id)
    media_file = Frestyl.Media.get_media_file!(file_id)

    # Only allow the uploader or admin to delete the file
    if socket.assigns.current_user.id == media_file.user_id or socket.assigns.is_admin do
      {:ok, _} = Frestyl.Media.delete_media_file(media_file)
      send(self(), {:media_deleted, media_file.id})
    end

    {:noreply, socket}
  end

  defp format_content_type(content_type) do
    case content_type do
      "image/" <> type -> "Image (#{String.upcase(type)})"
      "video/" <> type -> "Video (#{String.upcase(type)})"
      "audio/" <> type -> "Audio (#{String.upcase(type)})"
      "application/pdf" -> "PDF Document"
      "application/msword" -> "Word Document"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> "Word Document"
      "application/vnd.ms-excel" -> "Excel Spreadsheet"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -> "Excel Spreadsheet"
      _ -> content_type
    end
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
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end
end
