# lib/frestyl_web/live/media_live/index.ex
defmodule FrestylWeb.MediaLive.Index do
  use FrestylWeb, :live_view

  alias Frestyl.Media
  alias Frestyl.Channels

  @per_page 12

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Media.subscribe()

    socket =
      socket
      |> assign(:page, 1)
      |> assign(:search_query, "")
      |> assign(:filter_type, "all")
      |> assign(:filter_channel, "all")
      |> assign(:sort_by, "recent")
      |> assign(:sort_direction, :desc)
      |> assign(:selected_files, [])
      |> assign(:view_mode, "grid")
      |> assign(:loading, false)
      |> assign(:user_channels, get_user_channels(socket.assigns.current_user))
      |> load_files()

    {:ok, socket, temporary_assigns: [files: []]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Media Library")
  end

  # New search and filter event handlers
  @impl true
  def handle_event("search", %{"search" => search_query}, socket) do
    socket =
      socket
      |> assign(:search_query, search_query)
      |> assign(:page, 1)
      |> load_files()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    socket =
      socket
      |> assign(:filter_type, type)
      |> assign(:page, 1)
      |> load_files()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_channel", %{"channel" => channel_id}, socket) do
    socket =
      socket
      |> assign(:filter_channel, channel_id)
      |> assign(:page, 1)
      |> load_files()

    {:noreply, socket}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    current_field = socket.assigns.sort_by
    direction = if current_field == field and socket.assigns.sort_direction == :asc,
                do: :desc,
                else: :asc

    socket =
      socket
      |> assign(:sort_by, field)
      |> assign(:sort_direction, direction)
      |> load_files()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_view", _params, socket) do
    view_mode = if socket.assigns.view_mode == "grid", do: "list", else: "grid"

    socket =
      socket
      |> assign(:view_mode, view_mode)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_file", %{"id" => file_id}, socket) do
    selected_files = socket.assigns.selected_files

    selected_files =
      if file_id in selected_files do
        List.delete(selected_files, file_id)
      else
        [file_id | selected_files]
      end

    {:noreply, assign(socket, :selected_files, selected_files)}
  end

  @impl true
  def handle_event("select_all", _params, socket) do
    file_ids = Enum.map(socket.assigns.files, & &1.id)
    selected_files = if length(socket.assigns.selected_files) == length(file_ids),
                     do: [],
                     else: file_ids

    {:noreply, assign(socket, :selected_files, selected_files)}
  end

  @impl true
  def handle_event("bulk_delete", _params, socket) do
    selected_files = socket.assigns.selected_files

    if selected_files == [] do
      socket = put_flash(socket, :info, "No files selected")
      {:noreply, socket}
    else
      case Media.delete_files(selected_files) do
        {:ok, count} ->
          socket =
            socket
            |> put_flash(:info, "Deleted #{count} files")
            |> assign(:selected_files, [])
            |> load_files()
          {:noreply, socket}

        {:error, reason} ->
          socket = put_flash(socket, :error, "Failed to delete files: #{reason}")
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    socket =
      socket
      |> assign(:page, socket.assigns.page + 1)
      |> load_files()

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_file", %{"id" => file_id}, socket) do
    case Media.delete_file(file_id) do
      {:ok, _file} ->
        socket =
          socket
          |> put_flash(:info, "File deleted successfully")
          |> load_files()
        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to delete file: #{reason}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("show_media_upload", _params, socket) do
    {:noreply, assign(socket, :show_media_upload, true)}
  end

  def handle_event("hide_media_upload", _params, socket) do
    {:noreply, assign(socket, :show_media_upload, false)}
  end

  defp reload_media(socket) do
    filters = %{
      search: socket.assigns.search_query,
      file_type: file_type_filter(socket.assigns.filter_type),
      channel_id: channel_id_filter(socket.assigns.filter_channel),
      sort_by: socket.assigns.sort_by,
      sort_direction: socket.assigns.sort_direction
    }

    case Media.list_files_with_metadata(
      socket.assigns.current_user,
      socket.assigns.page,
      @per_page,
      filters
    ) do
      {files, has_more?} ->
        socket
        |> assign(:files, files)
        |> assign(:has_more?, has_more?)
        |> assign(:loading, false)

      :error ->
        socket
        |> put_flash(:error, "Failed to load files")
        |> assign(:loading, false)
    end
  end

  def handle_info(:show_media_upload, socket) do
    {:noreply, assign(socket, :show_media_upload, true)}
  end

  def handle_info(:close_media_viewer, socket) do
    {:noreply, assign(socket, :viewing_media, nil)}
  end

  def handle_info({:view_media, file_id}, socket) do
    {:noreply, assign(socket, :viewing_media, file_id)}
  end

  def handle_info({:media_uploaded, files}, socket) do
    {:noreply, socket
      |> put_flash(:info, "#{length(files)} file(s) uploaded successfully")
      |> assign(:show_media_upload, false)
      |> reload_media()}
  end

  def handle_info({:media_deleted, _file}, socket) do
    {:noreply, socket
      |> put_flash(:info, "File deleted successfully")
      |> assign(:viewing_media, nil)
      |> reload_media()}
  end

  defp load_files(socket) do
    filters = %{
      search: socket.assigns.search_query,
      file_type: file_type_filter(socket.assigns.filter_type),
      channel_id: channel_id_filter(socket.assigns.filter_channel),
      sort_by: socket.assigns.sort_by,
      sort_direction: socket.assigns.sort_direction
    }

    case Media.list_files_with_metadata(
      socket.assigns.current_user,
      socket.assigns.page,
      @per_page,
      filters
    ) do
      {files, has_more?} ->
        socket
        |> assign(:files, files)
        |> assign(:has_more?, has_more?)
        |> assign(:loading, false)

      :error ->
        socket
        |> put_flash(:error, "Failed to load files")
        |> assign(:loading, false)
    end
  end

  defp get_user_channels(user) do
    Channels.list_user_channels(user)
  end

  defp file_type_filter("all"), do: nil
  defp file_type_filter(type), do: type

  defp channel_id_filter("all"), do: nil
  defp channel_id_filter(id), do: id

  defp file_size(file) do
    format_bytes(file.file_size)
  end

  # Use the format_bytes helper from your upload module
  def format_bytes(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 1)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp file_type_icon(content_type) do
    case content_type do
      "image/" <> _ -> "photograph"
      "video/" <> _ -> "video-camera"
      "audio/" <> _ -> "volume-up"
      "application/pdf" -> "document-text"
      "application/" <> _ -> "document"
      _ -> "document"
    end
  end

  defp get_file_url(file) do
    Frestyl.Media.get_file_url(file)
  end

  defp sort_icon(socket, field) do
    if socket.assigns.sort_by == field do
      if socket.assigns.sort_direction == :asc do
        "arrow-up"
      else
        "arrow-down"
      end
    else
      nil
    end
  end

  # Helper function for formatting relative time
  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604800 -> "#{div(diff, 86400)}d ago"
      diff < 2592000 -> "#{div(diff, 604800)}w ago"
      true -> "#{div(diff, 2592000)}mo ago"
    end
  end
end
