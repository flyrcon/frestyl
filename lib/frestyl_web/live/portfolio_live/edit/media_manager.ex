# lib/frestyl_web/live/portfolio_live/edit/media_manager.ex - CORRECTED VERSION
defmodule FrestylWeb.PortfolioLive.Edit.MediaManager do
  @moduledoc """
  Phase 4: Enhanced media management with upload progress tracking,
  file validation, and seamless section integration.
  """

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioMedia

  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3, consume_uploaded_entries: 3, allow_upload: 3]

  # ============================================================================
  # MEDIA UPLOAD HANDLING
  # ============================================================================

  def handle_upload_media(socket, %{"section_id" => section_id} = _params) do
    section = Enum.find(socket.assigns.sections, &(to_string(&1.id) == section_id))

    if section do
      uploaded_files =
        consume_uploaded_entries(socket, :media, fn %{path: path} = entry, socket ->
          # Upload with progress tracking
          result = upload_media_file_with_progress(path, entry, section, socket.assigns.portfolio, socket)

          case result do
            {:ok, media} ->
              # Broadcast upload progress completion
              send(self(), {:upload_complete, entry.ref, media})
              {:ok, media}

            {:error, reason} ->
              # Broadcast upload error
              send(self(), {:upload_error, entry.ref, reason})
              {:postpone, reason}
          end
        end)

      case uploaded_files do
        [] ->
          {:noreply, put_flash(socket, :error, "No files were uploaded")}

        files when length(files) > 0 ->
          # Refresh section media
          socket = refresh_section_media(socket, section_id)

          {:noreply,
           socket
           |> put_flash(:info, "Successfully uploaded #{length(files)} file(s)")
           |> push_event("upload-complete", %{section_id: section_id, count: length(files)})}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # ============================================================================
  # CORE UPLOAD FUNCTION WITH PROGRESS TRACKING
  # ============================================================================

  def upload_media_file_with_progress(temp_path, entry, section, portfolio, socket) do
    try do
      # Validate file
      case validate_upload_file(entry) do
        :ok ->
          # Generate file paths
          file_extension = Path.extname(entry.client_name)
          filename = generate_unique_filename(entry.client_name)
          upload_dir = get_upload_directory(portfolio.id, section.id)
          final_path = Path.join(upload_dir, filename)

          # Ensure upload directory exists
          File.mkdir_p!(upload_dir)

          # Copy file to final location
          case File.cp(temp_path, final_path) do
            :ok ->
              # Get file info
              %{size: file_size} = File.stat!(final_path)

              # Determine media type
              media_type = determine_media_type(entry.client_type)

              # Generate thumbnail if it's an image
              thumbnail_path = maybe_generate_thumbnail(final_path, media_type, upload_dir)

              # Create database record
              media_attrs = %{
                title: Path.basename(entry.client_name, file_extension),
                description: "",
                file_path: get_public_path(final_path),
                thumbnail_path: thumbnail_path && get_public_path(thumbnail_path),
                file_size: file_size,
                media_type: media_type,
                mime_type: entry.client_type,
                position: get_next_media_position(section.id),
                visible: true,
                portfolio_section_id: section.id,
                portfolio_id: portfolio.id
              }

              case Portfolios.create_portfolio_media(media_attrs) do
                {:ok, media} ->
                  # Send progress update
                  send(socket.assigns.live_view_pid || self(),
                       {:upload_progress, entry.ref, 100})

                  {:ok, media}

                {:error, changeset} ->
                  # Clean up uploaded file on database error
                  File.rm(final_path)
                  if thumbnail_path, do: File.rm(thumbnail_path)

                  {:error, "Database error: #{inspect(changeset.errors)}"}
              end

            {:error, reason} ->
              {:error, "File copy failed: #{inspect(reason)}"}
          end

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        {:error, "Upload failed: #{Exception.message(e)}"}
    end
  end

  # ============================================================================
  # FILE VALIDATION
  # ============================================================================

  defp validate_upload_file(entry) do
    cond do
      entry.client_size > get_max_file_size() ->
        {:error, "File too large (max #{format_file_size(get_max_file_size())})"}

      not valid_file_type?(entry.client_type) ->
        {:error, "File type '#{entry.client_type}' not supported"}

      String.contains?(entry.client_name, ["../", "..\\"]) ->
        {:error, "Invalid filename"}

      true ->
        :ok
    end
  end

  defp get_max_file_size, do: 50 * 1024 * 1024 # 50MB

  defp valid_file_type?(mime_type) do
    mime_type in [
      # Images
      "image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp", "image/svg+xml",
      # Videos
      "video/mp4", "video/webm", "video/mov", "video/avi", "video/quicktime",
      # Audio
      "audio/mp3", "audio/mpeg", "audio/wav", "audio/ogg", "audio/m4a",
      # Documents
      "application/pdf", "text/plain", "text/markdown",
      "application/msword",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "application/vnd.ms-excel",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    ]
  end

  # ============================================================================
  # FILE MANAGEMENT
  # ============================================================================

  defp generate_unique_filename(original_name) do
    timestamp = System.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    extension = Path.extname(original_name)
    basename = Path.basename(original_name, extension)

    # Sanitize basename
    sanitized_basename = basename
    |> String.replace(~r/[^a-zA-Z0-9\-_]/, "_")
    |> String.slice(0, 50)

    "#{timestamp}_#{random}_#{sanitized_basename}#{extension}"
  end

  defp get_upload_directory(portfolio_id, section_id) do
    base_dir = Application.get_env(:frestyl, :upload_directory, "priv/static/uploads")
    Path.join([base_dir, "portfolios", to_string(portfolio_id), "sections", to_string(section_id)])
  end

  defp get_public_path(full_path) do
    # Convert full system path to public URL path
    upload_dir = Application.get_env(:frestyl, :upload_directory, "priv/static/uploads")

    case String.split(full_path, upload_dir, parts: 2) do
      [_prefix, relative_path] -> "/uploads" <> relative_path
      _ -> full_path # Fallback
    end
  end

  defp determine_media_type(mime_type) do
    cond do
      String.starts_with?(mime_type, "image/") -> "image"
      String.starts_with?(mime_type, "video/") -> "video"
      String.starts_with?(mime_type, "audio/") -> "audio"
      true -> "document"
    end
  end

  defp get_next_media_position(section_id) do
    case Portfolios.get_section_media_count(section_id) do
      count when is_integer(count) -> count + 1
      _ -> 1
    end
  end

  # ============================================================================
  # THUMBNAIL GENERATION
  # ============================================================================

  defp maybe_generate_thumbnail(file_path, "image", upload_dir) do
    try do
      thumbnail_filename = "thumb_" <> Path.basename(file_path)
      thumbnail_path = Path.join(upload_dir, thumbnail_filename)

      case generate_image_thumbnail(file_path, thumbnail_path) do
        :ok -> thumbnail_path
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  defp maybe_generate_thumbnail(_file_path, _media_type, _upload_dir), do: nil

  defp generate_image_thumbnail(source_path, thumbnail_path) do
    # Basic thumbnail generation using ImageMagick (if available)
    # You can replace this with your preferred image processing library
    case System.cmd("convert", [
      source_path,
      "-thumbnail", "300x300>",
      "-quality", "85",
      thumbnail_path
    ], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      _ -> :error
    end
  rescue
    _ -> :error
  end

  # ============================================================================
  # MEDIA MANAGEMENT FUNCTIONS
  # ============================================================================

  def handle_delete_media(socket, media_id) do
    case Portfolios.get_portfolio_media(media_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Media not found")}

      media ->
        # Verify ownership
        if media.portfolio_id == socket.assigns.portfolio.id do
          case Portfolios.delete_portfolio_media(media) do
            {:ok, _deleted_media} ->
              # Clean up files
              cleanup_media_files(media)

              # Refresh section media if we're editing a section
              socket = if socket.assigns[:section_edit_id] do
                refresh_section_media(socket, to_string(media.portfolio_section_id))
              else
                socket
              end

              {:noreply,
               socket
               |> put_flash(:info, "Media deleted successfully")
               |> push_event("media-deleted", %{media_id: media_id})}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to delete media")}
          end
        else
          {:noreply, put_flash(socket, :error, "Unauthorized")}
        end
    end
  end

  def handle_reorder_media(socket, %{"section_id" => section_id, "media_ids" => media_ids}) do
    section = Enum.find(socket.assigns.sections, &(to_string(&1.id) == section_id))

    if section do
      case Portfolios.reorder_section_media(section_id, media_ids) do
        {:ok, _updated_media} ->
          socket = refresh_section_media(socket, section_id)

          {:noreply,
           socket
           |> put_flash(:info, "Media reordered successfully")
           |> push_event("media-reorder-complete", %{section_id: section_id})}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to reorder media")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_update_media_metadata(socket, %{"media_id" => media_id, "metadata" => metadata}) do
    case Portfolios.get_portfolio_media(media_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Media not found")}

      media ->
        if media.portfolio_id == socket.assigns.portfolio.id do
          case Portfolios.update_portfolio_media(media, metadata) do
            {:ok, updated_media} ->
              # Refresh section media if editing
              socket = if socket.assigns[:section_edit_id] do
                refresh_section_media(socket, to_string(media.portfolio_section_id))
              else
                socket
              end

              {:noreply,
               socket
               |> put_flash(:info, "Media updated successfully")
               |> push_event("media-updated", %{media: updated_media})}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to update media")}
          end
        else
          {:noreply, put_flash(socket, :error, "Unauthorized")}
        end
    end
  end

  def handle_bulk_delete_media(socket, media_ids) when is_list(media_ids) do
    # Get all media items
    media_items = Enum.map(media_ids, &Portfolios.get_portfolio_media/1)
    |> Enum.filter(& &1 != nil)
    |> Enum.filter(&(&1.portfolio_id == socket.assigns.portfolio.id))

    if length(media_items) > 0 do
      # Delete all media items
      deleted_count = Enum.reduce(media_items, 0, fn media, acc ->
        case Portfolios.delete_portfolio_media(media) do
          {:ok, _} ->
            cleanup_media_files(media)
            acc + 1
          {:error, _} ->
            acc
        end
      end)

      # Refresh section media if editing
      socket = if socket.assigns[:section_edit_id] do
        section_id = hd(media_items).portfolio_section_id
        refresh_section_media(socket, to_string(section_id))
      else
        socket
      end

      {:noreply,
       socket
       |> put_flash(:info, "Deleted #{deleted_count} media file(s)")
       |> push_event("bulk-media-deleted", %{count: deleted_count})}
    else
      {:noreply, put_flash(socket, :error, "No valid media items to delete")}
    end
  end

  def handle_detach_all_media(socket, section_id) do
    section = Enum.find(socket.assigns.sections, &(to_string(&1.id) == section_id))

    if section do
      case Portfolios.detach_all_section_media(section_id) do
        {:ok, count} ->
          socket = refresh_section_media(socket, section_id)

          {:noreply,
           socket
           |> put_flash(:info, "Detached #{count} media file(s) from section")
           |> push_event("section-media-cleared", %{section_id: section_id})}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to detach media")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_update_section_media_layout(socket, %{"section-id" => section_id, "layout" => layout}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    case Enum.find(sections, &(&1.id == section_id_int)) do
      nil ->
        socket = socket
        |> put_flash(:error, "Section not found")

        {:noreply, socket}

      section ->
        # Update the section's content to include the media layout
        current_content = section.content || %{}
        updated_content = Map.put(current_content, "media_layout", layout)

        case Frestyl.Portfolios.update_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            # Update sections list
            updated_sections = Enum.map(sections, fn s ->
              if s.id == section_id_int, do: updated_section, else: s
            end)

            # Update editing section if it's the same one
            editing_section = if socket.assigns[:editing_section] && socket.assigns.editing_section.id == section_id_int do
              updated_section
            else
              socket.assigns[:editing_section]
            end

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, editing_section)
            |> put_flash(:info, "Media layout updated to #{layout}")
            |> push_event("media-layout-updated", %{section_id: section_id_int, layout: layout})

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to update media layout: #{inspect(changeset.errors)}")

            {:noreply, socket}
        end
    end
  end

  def handle_toggle_section_media_support(socket, %{"id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    case Enum.find(sections, &(&1.id == section_id_int)) do
      nil ->
        socket = socket
        |> put_flash(:error, "Section not found")

        {:noreply, socket}

      section ->
        # Toggle the allow_media setting (stored in content for now)
        current_content = section.content || %{}
        current_allow_media = Map.get(current_content, "allow_media", true)
        updated_content = Map.put(current_content, "allow_media", !current_allow_media)

        case Frestyl.Portfolios.update_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            # Update sections list
            updated_sections = Enum.map(sections, fn s ->
              if s.id == section_id_int, do: updated_section, else: s
            end)

            # Update editing section if it's the same one
            editing_section = if socket.assigns[:editing_section] && socket.assigns.editing_section.id == section_id_int do
              updated_section
            else
              socket.assigns[:editing_section]
            end

            status = if !current_allow_media, do: "enabled", else: "disabled"

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, editing_section)
            |> put_flash(:info, "Media support #{status} for this section")
            |> push_event("media-support-toggled", %{section_id: section_id_int, enabled: !current_allow_media})

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to update media support: #{inspect(changeset.errors)}")

            {:noreply, socket}
        end
    end
  end

  def handle_show_media_preview(socket, %{"media-id" => media_id}) do
    socket = socket
    |> assign(:media_preview_id, media_id)
    |> push_event("media-preview-shown", %{media_id: media_id})

    {:noreply, socket}
  end

  def handle_toggle_metadata_editing(socket, %{"media-id" => media_id}) do
    current_editing = socket.assigns[:editing_media_id]

    new_editing_id = if current_editing == media_id do
      nil  # Close if already editing this one
    else
      media_id  # Start editing this one
    end

    socket = socket
    |> assign(:editing_media_id, new_editing_id)
    |> push_event("metadata-editing-toggled", %{media_id: media_id, editing: new_editing_id != nil})

    {:noreply, socket}
  end

  def handle_detach_all_media(socket, %{"section-id" => section_id}) do
    # This would detach all media from a section without deleting the files
    # For now, just show a placeholder message
    socket = socket
    |> put_flash(:info, "Detach all media functionality would be implemented here")

    {:noreply, socket}
  end

  def handle_bulk_delete_media(socket, %{"media_ids" => media_ids}) when is_list(media_ids) do
    # This would delete multiple media files at once
    # For now, just show a placeholder message
    socket = socket
    |> put_flash(:info, "Bulk delete functionality would be implemented here for #{length(media_ids)} items")

    {:noreply, socket}
  end

  def handle_toggle_media_selection(socket, %{"media-id" => media_id}) do
    current_selected = socket.assigns[:selected_media_ids] || []

    new_selected = if media_id in current_selected do
      List.delete(current_selected, media_id)
    else
      [media_id | current_selected]
    end

    socket = socket
    |> assign(:selected_media_ids, new_selected)
    |> push_event("media-selection-changed", %{media_id: media_id, selected: media_id in new_selected})

    {:noreply, socket}
  end

  def handle_attach_media_to_section(socket, %{"section_id" => section_id, "media_ids" => media_ids}) do
    # This would attach existing media files to a section
    # For now, just show a placeholder message
    socket = socket
    |> put_flash(:info, "Attach media functionality would be implemented here")

    {:noreply, socket}
  end

  def handle_update_media_metadata(socket, %{"media_id" => media_id, "metadata" => metadata}) do
    # This would update media file metadata (title, description, etc.)
    # For now, just show a placeholder message
    socket = socket
    |> put_flash(:info, "Update media metadata functionality would be implemented here")

    {:noreply, socket}
  end

  # ============================================================================
  # MEDIA LIBRARY FUNCTIONS
  # ============================================================================

  def handle_show_section_media_library(socket, section_id) do
    section = Enum.find(socket.assigns.sections, &(to_string(&1.id) == section_id))

    if section do
      # Get all portfolio media (not just section media)
      portfolio_media = Portfolios.list_portfolio_media(socket.assigns.portfolio.id)
      section_media = Portfolios.list_section_media(section_id)

      socket = socket
      |> assign(:show_media_library, true)
      |> assign(:media_modal_section, section)
      |> assign(:media_modal_section_id, section_id)
      |> assign(:portfolio_media, portfolio_media)
      |> assign(:section_media, section_media)
      |> assign(:selected_media_ids, [])
      |> assign(:media_search_query, "")
      |> assign(:media_filter, "all")
      |> assign(:media_sort, "recent")
      |> assign(:media_view_mode, "grid")

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_hide_section_media_library(socket) do
    socket = socket
    |> assign(:show_media_library, false)
    |> assign(:media_modal_section, nil)
    |> assign(:media_modal_section_id, nil)
    |> assign(:portfolio_media, [])
    |> assign(:section_media, [])
    |> assign(:selected_media_ids, [])

    {:noreply, socket}
  end

  def handle_toggle_media_selection(socket, media_id) do
    selected_ids = socket.assigns[:selected_media_ids] || []

    new_selected_ids = if media_id in selected_ids do
      List.delete(selected_ids, media_id)
    else
      [media_id | selected_ids]
    end

    socket = assign(socket, :selected_media_ids, new_selected_ids)
    {:noreply, socket}
  end

  def handle_attach_media_to_section(socket, %{"section_id" => section_id, "media_ids" => media_ids_json}) do
    with {:ok, media_ids} <- Jason.decode(media_ids_json),
         section when not is_nil(section) <- Enum.find(socket.assigns.sections, &(to_string(&1.id) == section_id)) do

      case Portfolios.attach_media_to_section(section_id, media_ids) do
        {:ok, count} ->
          socket = socket
          |> refresh_section_media(section_id)
          |> assign(:selected_media_ids, [])

          {:noreply,
           socket
           |> put_flash(:info, "Attached #{count} media file(s) to section")
           |> push_event("media-attached", %{section_id: section_id, count: count})}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to attach media")}
      end
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid request")}
    end
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp refresh_section_media(socket, section_id) do
    section_media = Portfolios.list_section_media(section_id)
    assign(socket, :editing_section_media, section_media)
  end

  defp cleanup_media_files(media) do
    # Clean up main file
    if media.file_path do
      full_path = get_full_path_from_public(media.file_path)
      File.rm(full_path)
    end

    # Clean up thumbnail
    if media.thumbnail_path do
      full_thumbnail_path = get_full_path_from_public(media.thumbnail_path)
      File.rm(full_thumbnail_path)
    end
  end

  defp get_full_path_from_public(public_path) do
    upload_dir = Application.get_env(:frestyl, :upload_directory, "priv/static/uploads")
    relative_path = String.replace_prefix(public_path, "/uploads", "")
    Path.join(upload_dir, relative_path)
  end

  def format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  def format_file_size(bytes) when bytes < 1024 * 1024 do
    "#{Float.round(bytes / 1024, 1)} KB"
  end
  def format_file_size(bytes) when bytes < 1024 * 1024 * 1024 do
    "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  end
  def format_file_size(bytes) do
    "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
  end

  # ============================================================================
  # UPLOAD CONFIGURATION
  # ============================================================================

  def configure_uploads(socket) do
    allow_upload(socket, :media,
      accept: get_accepted_file_types(),
      max_entries: 10,
      max_file_size: get_max_file_size(),
      progress: &handle_upload_progress/3,
      auto_upload: false
    )
  end

  defp get_accepted_file_types do
    [
      # Images
      ".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg",
      # Videos
      ".mp4", ".webm", ".mov", ".avi",
      # Audio
      ".mp3", ".wav", ".ogg", ".m4a",
      # Documents
      ".pdf", ".txt", ".md", ".doc", ".docx", ".xls", ".xlsx"
    ]
  end

  defp handle_upload_progress(entry, socket, progress) do
    # Send progress update to client
    send(self(), {:upload_progress, entry.ref, progress})
    socket
  end

  # ============================================================================
  # ERROR HANDLING
  # ============================================================================

  def handle_upload_errors(socket, errors) do
    error_messages = Enum.map(errors, fn
      {_ref, :too_large} -> "File is too large"
      {_ref, :too_many_files} -> "Too many files selected"
      {_ref, :not_accepted} -> "File type not supported"
      {_ref, error} -> "Upload error: #{inspect(error)}"
    end)

    message = case error_messages do
      [single_error] -> single_error
      multiple_errors -> "Multiple errors: " <> Enum.join(multiple_errors, ", ")
    end

    {:noreply, put_flash(socket, :error, message)}
  end
end
