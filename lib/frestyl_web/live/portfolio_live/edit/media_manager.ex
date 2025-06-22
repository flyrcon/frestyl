# lib/frestyl_web/live/portfolio_live/edit/media_manager.ex - NEW FILE
defmodule FrestylWeb.PortfolioLive.Edit.MediaManager do
  @moduledoc """
  Handles all media-related operations for portfolio sections
  """

  alias Frestyl.Portfolios
  alias Frestyl.Media
  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3]

  # ============================================================================
  # MEDIA LIBRARY MANAGEMENT
  # ============================================================================

  def handle_show_section_media_library(socket, section_id) do
    section_id_int = String.to_integer(section_id)
    portfolio_id = socket.assigns.portfolio.id

    # Get available media for this portfolio that's not attached to sections
    available_media = get_available_portfolio_media(portfolio_id)

    # Get currently attached media for this section
    section_media = get_section_media(section_id_int)

    socket = socket
    |> assign(:show_media_library, true)
    |> assign(:media_library_section_id, section_id_int)
    |> assign(:available_media, available_media)
    |> assign(:section_media, section_media)

    {:noreply, socket}
  end

  def handle_hide_section_media_library(socket) do
    socket = socket
    |> assign(:show_media_library, false)
    |> assign(:media_library_section_id, nil)
    |> assign(:available_media, [])
    |> assign(:section_media, [])

    {:noreply, socket}
  end

  # ============================================================================
  # MEDIA ATTACHMENT/DETACHMENT
  # ============================================================================

  def handle_attach_media_to_section(socket, %{"section_id" => section_id, "media_id" => media_id}) do
    section_id_int = String.to_integer(section_id)
    media_id_int = String.to_integer(media_id)

    case attach_media_to_section(section_id_int, media_id_int) do
      {:ok, _attachment} ->
        # Refresh media lists
        portfolio_id = socket.assigns.portfolio.id
        available_media = get_available_portfolio_media(portfolio_id)
        section_media = get_section_media(section_id_int)

        # Update editing section media if this is the section being edited
        editing_section_media = if socket.assigns[:editing_section] &&
                                   socket.assigns.editing_section.id == section_id_int do
          section_media
        else
          socket.assigns[:editing_section_media] || []
        end

        socket = socket
        |> assign(:available_media, available_media)
        |> assign(:section_media, section_media)
        |> assign(:editing_section_media, editing_section_media)
        |> put_flash(:info, "Media attached to section successfully")
        |> push_event("media-attached", %{
          section_id: section_id_int,
          media_id: media_id_int
        })

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Failed to attach media: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  def handle_detach_media_from_section(socket, %{"media_id" => media_id}) do
    media_id_int = String.to_integer(media_id)

    case detach_media_from_section(media_id_int) do
      {:ok, _media} ->
        # Refresh media lists
        portfolio_id = socket.assigns.portfolio.id
        available_media = get_available_portfolio_media(portfolio_id)

        # Refresh section media if we're in a section context
        section_media = if socket.assigns[:media_library_section_id] do
          get_section_media(socket.assigns.media_library_section_id)
        else
          []
        end

        # Update editing section media if applicable
        editing_section_media = if socket.assigns[:editing_section] do
          get_section_media(socket.assigns.editing_section.id)
        else
          []
        end

        socket = socket
        |> assign(:available_media, available_media)
        |> assign(:section_media, section_media)
        |> assign(:editing_section_media, editing_section_media)
        |> put_flash(:info, "Media detached from section")
        |> push_event("media-detached", %{media_id: media_id_int})

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Failed to detach media: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  # ============================================================================
  # MEDIA LAYOUT MANAGEMENT
  # ============================================================================

  def handle_update_section_media_layout(socket, %{"layout" => layout, "section-id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    # Find the section to update
    section_to_update = Enum.find(sections, &(&1.id == section_id_int))

    if section_to_update do
      current_content = section_to_update.content || %{}
      updated_content = Map.put(current_content, "media_layout", layout)

      case Portfolios.update_section(section_to_update, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          # Update editing section if it matches
          editing_section = if socket.assigns[:editing_section] &&
                               socket.assigns.editing_section.id == section_id_int do
            updated_section
          else
            socket.assigns[:editing_section]
          end

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, editing_section)
          |> put_flash(:info, "Media layout updated to #{layout}")
          |> push_event("media-layout-updated", %{
            section_id: section_id_int,
            layout: layout
          })

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to update media layout: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      socket = socket
      |> put_flash(:error, "Section not found")

      {:noreply, socket}
    end
  end

  # ============================================================================
  # MEDIA UPLOAD HANDLING
  # ============================================================================

  def handle_upload_media_for_section(socket, section_id, uploaded_files) do
    section_id_int = String.to_integer(section_id)
    portfolio_id = socket.assigns.portfolio.id

    # Process each uploaded file
    results = Enum.map(uploaded_files, fn file_info ->
      # Create media record
      media_attrs = %{
        portfolio_id: portfolio_id,
        title: Path.basename(file_info.filename, Path.extname(file_info.filename)),
        description: "",
        media_type: determine_media_type(file_info.content_type),
        file_path: file_info.path,
        file_size: file_info.size,
        mime_type: file_info.content_type,
        visible: true,
        position: 0
      }

      case Portfolios.create_portfolio_media(media_attrs) do
        {:ok, media} ->
          # Attach to section
          case attach_media_to_section(section_id_int, media.id) do
            {:ok, _attachment} -> {:ok, media}
            {:error, reason} -> {:error, {:attachment_failed, media, reason}}
          end
        {:error, changeset} ->
          {:error, {:creation_failed, changeset}}
      end
    end)

    {successes, errors} = Enum.split_with(results, &match?({:ok, _}, &1))
    success_count = length(successes)
    error_count = length(errors)

    if success_count > 0 do
      # Refresh media data
      portfolio_id = socket.assigns.portfolio.id
      available_media = get_available_portfolio_media(portfolio_id)
      section_media = get_section_media(section_id_int)

      # Update editing section media if applicable
      editing_section_media = if socket.assigns[:editing_section] &&
                                 socket.assigns.editing_section.id == section_id_int do
        section_media
      else
        socket.assigns[:editing_section_media] || []
      end

      message = if error_count > 0 do
        "#{success_count} files uploaded successfully, #{error_count} failed"
      else
        "#{success_count} files uploaded and attached successfully"
      end

      socket = socket
      |> assign(:available_media, available_media)
      |> assign(:section_media, section_media)
      |> assign(:editing_section_media, editing_section_media)
      |> put_flash(:info, message)
      |> push_event("media-uploaded", %{
        section_id: section_id_int,
        success_count: success_count,
        error_count: error_count
      })

      {:noreply, socket}
    else
      socket = socket
      |> put_flash(:error, "Failed to upload files: #{format_upload_errors(errors)}")

      {:noreply, socket}
    end
  end

  # ============================================================================
  # MEDIA REORDERING
  # ============================================================================

  def handle_reorder_section_media(socket, %{"section_id" => section_id, "media_ids" => media_ids}) do
    section_id_int = String.to_integer(section_id)

    # Parse media IDs
    parsed_ids = Enum.map(media_ids, fn id ->
      case Integer.parse(to_string(id)) do
        {int_id, ""} -> int_id
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    case reorder_section_media(section_id_int, parsed_ids) do
      {:ok, _updated_media} ->
        # Refresh section media
        section_media = get_section_media(section_id_int)

        # Update editing section media if applicable
        editing_section_media = if socket.assigns[:editing_section] &&
                                   socket.assigns.editing_section.id == section_id_int do
          section_media
        else
          socket.assigns[:editing_section_media] || []
        end

        socket = socket
        |> assign(:section_media, section_media)
        |> assign(:editing_section_media, editing_section_media)
        |> put_flash(:info, "Media reordered successfully")
        |> push_event("media-reordered", %{section_id: section_id_int})

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Failed to reorder media: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp get_available_portfolio_media(portfolio_id) do
    try do
      Portfolios.list_unattached_portfolio_media(portfolio_id)
    rescue
      UndefinedFunctionError ->
        # Fallback if function doesn't exist yet
        Portfolios.list_portfolio_media(portfolio_id)
        |> Enum.filter(fn media ->
          # Check if media is not attached to any section
          case Map.get(media, :section_id) do
            nil -> true
            _ -> false
          end
        end)
    end
  end

  defp get_section_media(section_id) do
    try do
      Portfolios.list_section_media(section_id)
    rescue
      UndefinedFunctionError ->
        # Fallback implementation
        Portfolios.list_portfolio_media_by_section(section_id)
    end
  end

  defp attach_media_to_section(section_id, media_id) do
    try do
      Portfolios.attach_media_to_section(section_id, media_id)
    rescue
      UndefinedFunctionError ->
        # Fallback implementation
        case Portfolios.get_portfolio_media(media_id) do
          nil -> {:error, :not_found}
          media ->
            Portfolios.update_portfolio_media(media, %{section_id: section_id})
        end
    end
  end

  defp detach_media_from_section(media_id) do
    try do
      Portfolios.detach_media_from_section(media_id)
    rescue
      UndefinedFunctionError ->
        # Fallback implementation
        case Portfolios.get_portfolio_media(media_id) do
          nil -> {:error, :not_found}
          media ->
            Portfolios.update_portfolio_media(media, %{section_id: nil})
        end
    end
  end

  defp reorder_section_media(section_id, media_ids) do
    try do
      # Update positions based on order
      media_ids
      |> Enum.with_index(1)
      |> Enum.map(fn {media_id, position} ->
        case Portfolios.get_portfolio_media(media_id) do
          nil -> {:error, :not_found}
          media -> Portfolios.update_portfolio_media(media, %{position: position})
        end
      end)
      |> Enum.reduce({:ok, []}, fn
        {:ok, media}, {:ok, acc} -> {:ok, [media | acc]}
        {:error, reason}, _ -> {:error, reason}
        _, {:error, reason} -> {:error, reason}
      end)
      |> case do
        {:ok, updated_media} -> {:ok, Enum.reverse(updated_media)}
        error -> error
      end
    rescue
      _ -> {:error, :reorder_failed}
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

  defp format_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  defp format_upload_errors(errors) do
    errors
    |> Enum.map(fn
      {:error, {:creation_failed, changeset}} ->
        "Creation failed: #{format_errors(changeset)}"
      {:error, {:attachment_failed, _media, reason}} ->
        "Attachment failed: #{inspect(reason)}"
      {:error, reason} ->
        "Upload failed: #{inspect(reason)}"
    end)
    |> Enum.join(", ")
  end
end
