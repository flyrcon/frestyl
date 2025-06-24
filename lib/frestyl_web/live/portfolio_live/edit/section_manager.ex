# lib/frestyl_web/live/portfolio_live/edit/section_manager.ex - CRITICAL FIXES
defmodule FrestylWeb.PortfolioLive.Edit.SectionManager do
  @moduledoc """
  FIXED: Section management with proper content handling and no HTML markup issues
  """

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioSection
  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3]

  # ============================================================================
  # SECTION MOVEMENT HANDLERS - Move up/down arrows
  # ============================================================================

  def handle_move_section_up(socket, %{"id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    # Find current section and its index
    current_index = Enum.find_index(sections, &(&1.id == section_id_int))

    if current_index && current_index > 0 do
      # Can move up
      new_sections = move_section(sections, current_index, current_index - 1)

      case update_section_positions_batch(new_sections) do
        {:ok, updated_sections} ->
          socket = socket
          |> assign(:sections, updated_sections)
          |> put_flash(:info, "Section moved up")
          |> push_event("section-reordered", %{section_id: section_id_int, direction: "up"})

          {:noreply, socket}

        {:error, _reason} ->
          socket = socket
          |> put_flash(:error, "Failed to move section")

          {:noreply, socket}
      end
    else
      socket = socket
      |> put_flash(:info, "Section is already at the top")

      {:noreply, socket}
    end
  end

  def handle_move_section_down(socket, %{"id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    # Find current section and its index
    current_index = Enum.find_index(sections, &(&1.id == section_id_int))

    if current_index && current_index < length(sections) - 1 do
      # Can move down
      new_sections = move_section(sections, current_index, current_index + 1)

      case update_section_positions_batch(new_sections) do
        {:ok, updated_sections} ->
          socket = socket
          |> assign(:sections, updated_sections)
          |> put_flash(:info, "Section moved down")
          |> push_event("section-reordered", %{section_id: section_id_int, direction: "down"})

          {:noreply, socket}

        {:error, _reason} ->
          socket = socket
          |> put_flash(:error, "Failed to move section")

          {:noreply, socket}
      end
    else
      socket = socket
      |> put_flash(:info, "Section is already at the bottom")

      {:noreply, socket}
    end
  end

  # ============================================================================
  # ENHANCED DRAG & DROP REORDERING - Fixed for SortableJS
  # ============================================================================

  def handle_reorder_sections(socket, %{"sections" => section_ids}) when is_list(section_ids) do
    IO.puts("🔄 Reordering sections with IDs: #{inspect(section_ids)}")

    sections = socket.assigns.sections

    # Parse section IDs to integers
    parsed_ids = Enum.map(section_ids, fn id ->
      case Integer.parse(to_string(id)) do
        {int_id, ""} -> int_id
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    IO.puts("🔄 Parsed section IDs: #{inspect(parsed_ids)}")

    if length(parsed_ids) == length(sections) do
      # Reorder sections based on the new order
      reordered_sections = reorder_sections_by_ids(sections, parsed_ids)

      IO.puts("🔄 Reordered sections: #{inspect(Enum.map(reordered_sections, & &1.id))}")

      # Update positions in database
      case update_section_positions_batch(reordered_sections) do
        {:ok, updated_sections} ->
          socket = socket
          |> assign(:sections, updated_sections)
          |> put_flash(:info, "Sections reordered successfully")
          |> push_event("sections-reordered", %{count: length(updated_sections)})

          {:noreply, socket}

        {:error, reason} ->
          IO.puts("❌ Failed to update section positions: #{inspect(reason)}")

          socket = socket
          |> put_flash(:error, "Failed to save new section order")

          {:noreply, socket}
      end
    else
      IO.puts("❌ Section count mismatch - expected: #{length(sections)}, got: #{length(parsed_ids)}")

      socket = socket
      |> put_flash(:error, "Invalid section order received")

      {:noreply, socket}
    end
  end

  def handle_reorder_sections(socket, params) do
    IO.puts("❌ Invalid reorder_sections params: #{inspect(params)}")

    socket = socket
    |> put_flash(:error, "Invalid reorder request")

    {:noreply, socket}
  end

  # ============================================================================
  # BULK SECTION OPERATIONS
  # ============================================================================

  def handle_reorder_sections_alphabetically(socket, _params) do
    sections = socket.assigns.sections

    # Sort sections alphabetically by title
    sorted_sections = Enum.sort_by(sections, & String.downcase(&1.title))

    case update_section_positions_batch(sorted_sections) do
      {:ok, updated_sections} ->
        socket = socket
        |> assign(:sections, updated_sections)
        |> put_flash(:info, "Sections sorted alphabetically")

        {:noreply, socket}

      {:error, _reason} ->
        socket = socket
        |> put_flash(:error, "Failed to sort sections")

        {:noreply, socket}
    end
  end

  def handle_reset_section_positions(socket, _params) do
    sections = socket.assigns.sections

    # Reset to original creation order
    reset_sections = Enum.sort_by(sections, & &1.inserted_at)

    case update_section_positions_batch(reset_sections) do
      {:ok, updated_sections} ->
        socket = socket
        |> assign(:sections, updated_sections)
        |> put_flash(:info, "Section order reset to original")

        {:noreply, socket}

      {:error, _reason} ->
        socket = socket
        |> put_flash(:error, "Failed to reset section order")

        {:noreply, socket}
    end
  end

  # ============================================================================
  # ENHANCED HELPER FUNCTIONS
  # ============================================================================

  defp reorder_sections_by_ids(sections, section_ids) do
    # Create a map for quick lookup
    sections_map = Map.new(sections, &{&1.id, &1})

    # Reorder based on the provided IDs, then append any missing sections
    ordered_sections = Enum.map(section_ids, &Map.get(sections_map, &1))
                      |> Enum.reject(&is_nil/1)

    missing_sections = sections -- ordered_sections
    ordered_sections ++ missing_sections
  end

  defp move_section(sections, old_index, new_index) do
    section = Enum.at(sections, old_index)
    sections
    |> List.delete_at(old_index)
    |> List.insert_at(new_index, section)
  end

  defp update_section_positions_batch(sections) do
    # Use a transaction to update all positions atomically
    results = sections
    |> Enum.with_index(1)
    |> Enum.map(fn {section, index} ->
      case Portfolios.update_section(section, %{position: index}) do
        {:ok, updated_section} -> {:ok, updated_section}
        {:error, changeset} -> {:error, changeset}
      end
    end)

    # Check if all updates succeeded
    {successes, errors} = Enum.split_with(results, &match?({:ok, _}, &1))

    if length(errors) == 0 do
      updated_sections = Enum.map(successes, fn {:ok, section} -> section end)
      {:ok, updated_sections}
    else
      IO.puts("❌ Some section position updates failed: #{inspect(errors)}")
      {:error, :batch_update_failed}
    end
  end

  # ============================================================================
  # MEDIA ATTACHMENT HANDLERS - Fixed for section media
  # ============================================================================

  def handle_attach_media_to_section(socket, %{"section_id" => section_id, "media_ids" => media_ids}) when is_list(media_ids) do
    section_id_int = case Integer.parse(to_string(section_id)) do
      {id, ""} -> id
      _ -> nil
    end

    if section_id_int do
      # Find the section
      section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

      if section do
        # Attach media files to section
        results = Enum.map(media_ids, fn media_id ->
          case Integer.parse(to_string(media_id)) do
            {id, ""} ->
              case Portfolios.attach_media_to_section(section_id_int, id) do
                {:ok, _association} -> {:ok, id}
                {:error, reason} -> {:error, {id, reason}}
              end
            _ ->
              {:error, {media_id, :invalid_id}}
          end
        end)

        {successes, errors} = Enum.split_with(results, &match?({:ok, _}, &1))

        success_count = length(successes)
        error_count = length(errors)

        cond do
          success_count > 0 && error_count == 0 ->
            # Refresh section media
            socket = refresh_section_media(socket, to_string(section_id_int))

            socket = socket
            |> put_flash(:info, "#{success_count} media file(s) attached to section")
            |> push_event("media-attached", %{section_id: section_id_int, count: success_count})

            {:noreply, socket}

          success_count > 0 && error_count > 0 ->
            socket = refresh_section_media(socket, to_string(section_id_int))

            socket = socket
            |> put_flash(:info, "#{success_count} media file(s) attached, #{error_count} failed")

            {:noreply, socket}

          true ->
            socket = socket
            |> put_flash(:error, "Failed to attach media files to section")

            {:noreply, socket}
        end
      else
        socket = socket
        |> put_flash(:error, "Section not found")

        {:noreply, socket}
      end
    else
      socket = socket
      |> put_flash(:error, "Invalid section ID")

      {:noreply, socket}
    end
  end

  # Helper function to refresh section media after changes
  defp refresh_section_media(socket, section_id) do
    section_id_int = String.to_integer(section_id)

    try do
      section_media = Portfolios.list_section_media(section_id_int)
      assign(socket, :editing_section_media, section_media)
    rescue
      _ -> socket
    end
  end


  # ============================================================================
  # BASIC SECTION MANAGEMENT
  # ============================================================================

  defp get_default_content_for_section_type("intro") do
    %{
      "headline" => "Hello, I'm [Your Name]",
      "summary" => "A brief introduction about yourself and your professional journey.",
      "location" => "",
      "website" => "",
      "social_links" => %{
        "linkedin" => "",
        "github" => "",
        "twitter" => ""
      }
    }
  end

  defp get_default_content_for_section_type("experience") do
    %{
      "jobs" => []
    }
  end

  defp get_default_content_for_section_type("education") do
    %{
      "education" => []
    }
  end

  defp get_default_content_for_section_type("skills") do
    %{
      "skills" => [],
      "skill_categories" => %{}
    }
  end

  defp get_default_content_for_section_type("projects") do
    %{
      "projects" => []
    }
  end

  defp get_default_content_for_section_type("featured_project") do
    %{
      "title" => "",
      "description" => "",
      "technologies" => [],
      "url" => "",
      "github_url" => ""
    }
  end

  defp get_default_content_for_section_type("case_study") do
    %{
      "title" => "",
      "client" => "",
      "timeline" => "",
      "challenge" => "",
      "solution" => "",
      "results" => ""
    }
  end

  defp get_default_content_for_section_type("contact") do
    %{
      "email" => "",
      "phone" => "",
      "location" => "",
      "website" => "",
      "social_links" => %{}
    }
  end

  defp get_default_content_for_section_type(_), do: %{}

  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  @impl true
  def handle_event("add_education_entry", params, socket) do
    handle_add_education_entry(socket, params)
  end

  @impl true
  def handle_event("remove_education_entry", params, socket) do
    handle_remove_education_entry(socket, params)
  end

  @impl true
  def handle_event("update_education_field", params, socket) do
    handle_update_education_field(socket, params)
  end

  def handle_add_education_entry(socket, %{"section-id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_education = Map.get(current_content, "education", [])

      new_education = %{
        "degree" => "",
        "field" => "",
        "institution" => "",
        "location" => "",
        "start_date" => "",
        "end_date" => "",
        "status" => "Completed",
        "gpa" => "",
        "description" => "",
        "relevant_coursework" => [],
        "activities" => []
      }

      updated_education = current_education ++ [new_education]
      updated_content = Map.put(current_content, "education", updated_education)

      case Portfolios.update_section(editing_section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, updated_section)
          |> put_flash(:info, "New education entry added")

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to add education entry: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_remove_education_entry(socket, %{"section-id" => section_id, "index" => index}) do
    section_id_int = String.to_integer(section_id)
    entry_index = String.to_integer(index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_education = Map.get(current_content, "education", [])

      if entry_index >= 0 and entry_index < length(current_education) do
        updated_education = List.delete_at(current_education, entry_index)
        updated_content = Map.put(current_content, "education", updated_education)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Education entry removed")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to remove education entry: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid entry index")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_update_education_field(socket, %{"field" => field, "value" => value, "section-id" => section_id, "index" => index}) do
    section_id_int = String.to_integer(section_id)
    entry_index = String.to_integer(index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_education = Map.get(current_content, "education", [])

      if entry_index >= 0 and entry_index < length(current_education) do
        updated_education = List.update_at(current_education, entry_index, fn entry ->
          Map.put(entry, field, value)
        end)
        updated_content = Map.put(current_content, "education", updated_education)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> assign(:unsaved_changes, false)

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to update education field: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid entry index")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_reorder_education_entries(socket, %{"section-id" => section_id, "old_index" => old_index, "new_index" => new_index}) do
    section_id_int = String.to_integer(section_id)
    old_idx = String.to_integer(old_index)
    new_idx = String.to_integer(new_index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_education = Map.get(current_content, "education", [])

      if old_idx >= 0 and new_idx >= 0 and old_idx < length(current_education) and new_idx < length(current_education) do
        # Reorder the education array
        edu_to_move = Enum.at(current_education, old_idx)
        updated_education = current_education
        |> List.delete_at(old_idx)
        |> List.insert_at(new_idx, edu_to_move)

        updated_content = Map.put(current_content, "education", updated_education)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Education entries reordered")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to reorder education entries: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid indices for reordering")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_delete_section(socket, %{"id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    case Portfolios.get_section!(section_id_int) do
      nil ->
        socket = socket
        |> put_flash(:error, "Section not found")

        {:noreply, socket}

      section ->
        case Portfolios.delete_section(section) do
          {:ok, _} ->
            updated_sections = Enum.reject(sections, &(&1.id == section_id_int))

            # Update positions of remaining sections
            updated_sections = reindex_sections(updated_sections)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:section_edit_id, nil)
            |> assign(:editing_section, nil)
            |> assign(:editing_section_media, [])
            |> assign(:unsaved_changes, false)
            |> put_flash(:info, "Section deleted successfully")
            |> push_event("section-deleted", %{section_id: section_id_int})

            {:noreply, socket}

          {:error, _changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to delete section")

            {:noreply, socket}
        end
    end
  end

  def handle_toggle_visibility(socket, %{"id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    case Enum.find(sections, &(&1.id == section_id_int)) do
      nil ->
        socket = socket
        |> put_flash(:error, "Section not found")

        {:noreply, socket}

      section ->
        case Portfolios.update_section(section, %{visible: !section.visible}) do
          {:ok, updated_section} ->
            updated_sections =
              Enum.map(sections, fn s ->
                if s.id == section_id_int, do: updated_section, else: s
              end)

            editing_section = if socket.assigns[:editing_section] && socket.assigns.editing_section.id == section_id_int do
              updated_section
            else
              socket.assigns[:editing_section]
            end

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, editing_section)
            |> assign(:unsaved_changes, false)
            |> put_flash(:info, "Section visibility updated")
            |> push_event("section-visibility-toggled", %{
              section_id: section_id_int,
              visible: updated_section.visible
            })

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to update section visibility: #{format_errors(changeset)}")

            {:noreply, socket}
        end
    end
  end

    def handle_edit_section(socket, %{"id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      # Get section media if it exists
      section_media = try do
        Portfolios.list_section_media(section_id_int)
      rescue
        _ -> []
      end

      socket = socket
      |> assign(:section_edit_id, to_string(section_id_int))
      |> assign(:editing_section, section)
      |> assign(:editing_section_media, section_media)
      |> assign(:section_edit_tab, "content")
      |> assign(:active_tab, :sections)
      |> push_event("section-edit-started", %{section_id: section_id_int})

      {:noreply, socket}
    else
      socket = socket
      |> put_flash(:error, "Section not found")

      {:noreply, socket}
    end
  end

  def handle_save_section(socket, %{"id" => section_id}) do
    section_id_int = String.to_integer(section_id)

    # Get the latest section data from database to ensure we have current data
    case Portfolios.get_section!(section_id_int) do
      nil ->
        socket = socket
        |> put_flash(:error, "Section not found")

        {:noreply, socket}

      current_section ->
        # Update the sections list with the current data
        updated_sections = Enum.map(socket.assigns.sections, fn s ->
          if s.id == section_id_int, do: current_section, else: s
        end)

        socket = socket
        |> assign(:sections, updated_sections)
        |> assign(:editing_section, current_section)  # CRITICAL: Keep editing with latest data
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Section saved successfully!")
        |> push_event("section-saved", %{section_id: section_id_int})

        # DON'T close the edit mode - stay in the same tab
        {:noreply, socket}
    end
  end

  def handle_cancel_edit(socket, _params) do
    socket = socket
    |> assign(:section_edit_id, nil)
    |> assign(:editing_section, nil)
    |> assign(:editing_section_media, [])
    |> assign(:section_edit_tab, nil)
    |> push_event("section-edit-cancelled", %{})

    {:noreply, socket}
  end

  def handle_update_section_field(socket, %{"field" => field, "value" => value, "section-id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns.editing_section
    sections = socket.assigns.sections

    if editing_section && editing_section.id == section_id_int do
      case Portfolios.update_section(editing_section, %{String.to_atom(field) => value}) do
        {:ok, db_updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: db_updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, db_updated_section)
          |> assign(:unsaved_changes, false)
          |> push_event("section-field-updated", %{
            section_id: section_id_int,
            field: field,
            value: value
          })

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to update section: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      socket = socket
      |> put_flash(:error, "Section not found or not being edited")

      {:noreply, socket}
    end
  end

  def handle_update_section_content(socket, %{"field" => field, "value" => value, "section-id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    # Find the section to update from the sections list
    section_to_update = Enum.find(sections, &(&1.id == section_id_int))

    if section_to_update do
      current_content = section_to_update.content || %{}

      # CRITICAL: Handle different field types and clean HTML
      updated_content = case field do
        "technologies_string" ->
          # Convert comma-separated string to list
          tech_list = value
          |> strip_html()  # Remove any HTML tags
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          Map.put(current_content, "technologies", tech_list)

        "main_content" ->
          # Clean HTML and map to content field
          cleaned_value = strip_html(value)
          Map.put(current_content, "content", cleaned_value)

        "summary" ->
          # Clean HTML from summary
          cleaned_value = strip_html(value)
          Map.put(current_content, "summary", cleaned_value)

        "headline" ->
          # Clean HTML from headline
          cleaned_value = strip_html(value)
          Map.put(current_content, "headline", cleaned_value)

        "description" ->
          # Clean HTML from descriptions
          cleaned_value = strip_html(value)
          Map.put(current_content, "description", cleaned_value)

        # Handle experience job entries
        "job_" <> job_field ->
          update_job_field(current_content, job_field, strip_html(value))

        # Handle education entries
        "edu_" <> edu_field ->
          update_education_field(current_content, edu_field, strip_html(value))

        _ ->
          # Regular field updates with HTML cleaning
          cleaned_value = if is_binary(value), do: strip_html(value), else: value
          Map.put(current_content, field, cleaned_value)
      end

      case Portfolios.update_section(section_to_update, %{content: updated_content}) do
        {:ok, db_updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: db_updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)
          |> assign(:unsaved_changes, false)
          |> push_event("section-content-updated", %{
            section_id: section_id_int,
            field: field,
            value: cleaned_value_for_event(value)
          })

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to update section content: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_remove_education_entry(socket, %{"section-id" => section_id, "index" => index}) do
    section_id_int = String.to_integer(section_id)
    entry_index = String.to_integer(index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_education = Map.get(current_content, "education", [])

      if entry_index >= 0 and entry_index < length(current_education) do
        updated_education = List.delete_at(current_education, entry_index)
        updated_content = Map.put(current_content, "education", updated_education)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Education entry removed")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to remove education entry: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid entry index")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_add_skill(socket, %{"section-id" => section_id, "skill" => skill_name}) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int and String.trim(skill_name) != "" do
      current_content = editing_section.content || %{}
      current_skills = Map.get(current_content, "skills", [])

      # Avoid duplicates
      if skill_name not in current_skills do
        updated_skills = current_skills ++ [String.trim(skill_name)]
        updated_content = Map.put(current_content, "skills", updated_skills)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Skill added")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to add skill: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :info, "Skill already exists")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid skill name or section not found")}
    end
  end

  def handle_remove_skill(socket, %{"section-id" => section_id, "index" => index}) do
    section_id_int = String.to_integer(section_id)
    skill_index = String.to_integer(index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_skills = Map.get(current_content, "skills", [])

      if skill_index >= 0 and skill_index < length(current_skills) do
        updated_skills = List.delete_at(current_skills, skill_index)
        updated_content = Map.put(current_content, "skills", updated_skills)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Skill removed")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to remove skill: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid skill index")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_reorder_experience_entry(socket, %{"section-id" => section_id, "index" => index, "direction" => direction}) do
    section_id_int = String.to_integer(section_id)
    index_int = String.to_integer(index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_jobs = Map.get(current_content, "jobs", [])

      new_index = case direction do
        "up" -> max(0, index_int - 1)
        "down" -> min(length(current_jobs) - 1, index_int + 1)
        _ -> index_int
      end

      if new_index != index_int and new_index >= 0 and new_index < length(current_jobs) do
        # Reorder the jobs array
        job_to_move = Enum.at(current_jobs, index_int)
        updated_jobs = current_jobs
        |> List.delete_at(index_int)
        |> List.insert_at(new_index, job_to_move)

        updated_content = Map.put(current_content, "jobs", updated_jobs)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Experience entries reordered")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to reorder experience entries: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

    def handle_update_experience_field(socket, %{"field" => field, "section-id" => section_id, "index" => index} = params) do
    section_id_int = String.to_integer(section_id)
    index_int = String.to_integer(index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_jobs = Map.get(current_content, "jobs", [])

      if index_int >= 0 and index_int < length(current_jobs) do
        job = Enum.at(current_jobs, index_int)

        # Get the value and handle special field types
        updated_job = case field do
          "current" ->
            # Toggle current status
            current_value = Map.get(job, "current", false)
            new_job = Map.put(job, "current", !current_value)
            # If marking as current, clear end_date
            if !current_value do
              Map.put(new_job, "end_date", "")
            else
              new_job
            end

          "responsibilities_text" ->
            # Convert text to list
            text = Map.get(params, "value", "")
            responsibilities = text
            |> String.split("\n")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))
            Map.put(job, "responsibilities", responsibilities)

          "achievements_text" ->
            # Convert text to list
            text = Map.get(params, "value", "")
            achievements = text
            |> String.split("\n")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))
            Map.put(job, "achievements", achievements)

          "skills_text" ->
            # Convert comma-separated text to list
            text = Map.get(params, "value", "")
            skills = text
            |> String.split(",")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))
            Map.put(job, "skills", skills)

          _ ->
            # Regular field update
            value = Map.get(params, "value", "")
            Map.put(job, field, value)
        end

        updated_jobs = List.replace_at(current_jobs, index_int, updated_job)
        updated_content = Map.put(current_content, "jobs", updated_jobs)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to update experience field: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid experience entry index")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # ============================================================================
  # UI STATE MANAGEMENT
  # ============================================================================

  def handle_toggle_add_section_dropdown(socket, _params) do
    current_state = socket.assigns[:show_add_section_dropdown] || false

    socket = socket
    |> assign(:show_add_section_dropdown, !current_state)

    {:noreply, socket}
  end

  def handle_switch_section_edit_tab(socket, %{"tab" => tab}) do
    socket = socket
    |> assign(:section_edit_tab, tab)
    |> push_event("section-edit-tab-changed", %{tab: tab})

    {:noreply, socket}
  end

  # ============================================================================
  # SECTION DUPLICATION
  # ============================================================================

  def handle_duplicate_section(socket, %{"id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    case Enum.find(sections, &(&1.id == section_id_int)) do
      nil ->
        socket = socket
        |> put_flash(:error, "Section not found")

        {:noreply, socket}

      section ->
        next_position = length(sections) + 1
        duplicate_attrs = %{
          title: "#{section.title} (Copy)",
          section_type: section.section_type,
          content: section.content,
          position: next_position,
          visible: section.visible,
          portfolio_id: section.portfolio_id
        }

        case Portfolios.create_section(duplicate_attrs) do
          {:ok, new_section} ->
            updated_sections = sections ++ [new_section]

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:unsaved_changes, false)
            |> put_flash(:info, "Section duplicated successfully")
            |> push_event("section-duplicated", %{
              original_id: section_id_int,
              new_id: new_section.id
            })

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to duplicate section: #{format_errors(changeset)}")

            {:noreply, socket}
        end
    end
  end

  # ============================================================================
  # ENHANCED CONTENT MANAGEMENT - Support for multiple entries
  # ============================================================================

  def add_experience_entry(socket, %{"section-id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_jobs = Map.get(current_content, "jobs", [])

      new_job = %{
        "title" => "",
        "company" => "",
        "location" => "",
        "employment_type" => "Full-time",
        "start_date" => "",
        "end_date" => "",
        "current" => false,
        "description" => "",
        "responsibilities" => [],
        "achievements" => [],
        "skills" => []
      }

      updated_jobs = current_jobs ++ [new_job]
      updated_content = Map.put(current_content, "jobs", updated_jobs)

      case Portfolios.update_section(editing_section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, updated_section)
          |> put_flash(:info, "New work experience entry added")

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to add experience entry: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_remove_experience_entry(socket, %{"section-id" => section_id, "index" => index}) do
    section_id_int = String.to_integer(section_id)
    index_int = String.to_integer(index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_jobs = Map.get(current_content, "jobs", [])

      if index_int >= 0 and index_int < length(current_jobs) do
        updated_jobs = List.delete_at(current_jobs, index_int)
        updated_content = Map.put(current_content, "jobs", updated_jobs)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Work experience entry removed")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to remove experience entry: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid experience entry index")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_add_education_entry(socket, %{"section-id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_education = Map.get(current_content, "education", [])

      new_education = %{
        "degree" => "",
        "field" => "",
        "institution" => "",
        "location" => "",
        "start_date" => "",
        "end_date" => "",
        "status" => "Completed",
        "gpa" => "",
        "description" => "",
        "relevant_coursework" => [],
        "activities" => []
      }

      updated_education = current_education ++ [new_education]
      updated_content = Map.put(current_content, "education", updated_education)

      case Portfolios.update_section(editing_section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, updated_section)
          |> put_flash(:info, "New education entry added")

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to add education entry: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_remove_education_entry(socket, %{"section-id" => section_id, "index" => index}) do
    section_id_int = String.to_integer(section_id)
    entry_index = String.to_integer(index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_education = Map.get(current_content, "education", [])

      if entry_index >= 0 and entry_index < length(current_education) do
        updated_education = List.delete_at(current_education, entry_index)
        updated_content = Map.put(current_content, "education", updated_education)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Education entry removed")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to remove education entry: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid entry index")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_add_skill(socket, %{"section-id" => section_id, "skill" => skill_name}) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int and String.trim(skill_name) != "" do
      current_content = editing_section.content || %{}
      current_skills = Map.get(current_content, "skills", [])

      # Avoid duplicates
      if skill_name not in current_skills do
        updated_skills = current_skills ++ [String.trim(skill_name)]
        updated_content = Map.put(current_content, "skills", updated_skills)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Skill added")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to add skill: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :info, "Skill already exists")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid skill name or section not found")}
    end
  end

  def handle_remove_skill(socket, %{"section-id" => section_id, "index" => index}) do
    section_id_int = String.to_integer(section_id)
    skill_index = String.to_integer(index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_skills = Map.get(current_content, "skills", [])

      if skill_index >= 0 and skill_index < length(current_skills) do
        updated_skills = List.delete_at(current_skills, skill_index)
        updated_content = Map.put(current_content, "skills", updated_skills)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Skill removed")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to remove skill: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid skill index")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_reorder_experience_entries(socket, %{"section-id" => section_id, "old_index" => old_index, "new_index" => new_index}) do
    section_id_int = String.to_integer(section_id)
    old_idx = String.to_integer(old_index)
    new_idx = String.to_integer(new_index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_jobs = Map.get(current_content, "jobs", [])

      if old_idx >= 0 and new_idx >= 0 and old_idx < length(current_jobs) and new_idx < length(current_jobs) do
        # Reorder the jobs array
        job_to_move = Enum.at(current_jobs, old_idx)
        updated_jobs = current_jobs
        |> List.delete_at(old_idx)
        |> List.insert_at(new_idx, job_to_move)

        updated_content = Map.put(current_content, "jobs", updated_jobs)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Experience entries reordered")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to reorder experience entries: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid indices for reordering")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_reorder_education_entries(socket, %{"section-id" => section_id, "old_index" => old_index, "new_index" => new_index}) do
    section_id_int = String.to_integer(section_id)
    old_idx = String.to_integer(old_index)
    new_idx = String.to_integer(new_index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_education = Map.get(current_content, "education", [])

      if old_idx >= 0 and new_idx >= 0 and old_idx < length(current_education) and new_idx < length(current_education) do
        # Reorder the education array
        edu_to_move = Enum.at(current_education, old_idx)
        updated_education = current_education
        |> List.delete_at(old_idx)
        |> List.insert_at(new_idx, edu_to_move)

        updated_content = Map.put(current_content, "education", updated_education)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Education entries reordered")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to reorder education entries: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid indices for reordering")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # Helper function to update editing_section if it exists
  defp maybe_update_editing_section(socket, updated_sections, section_id) do
    case socket.assigns[:editing_section] do
      %{id: ^section_id} ->
        # Update the editing section if it matches the updated section
        updated_section = Enum.find(updated_sections, &(&1.id == section_id))
        assign(socket, :editing_section, updated_section)
      _ ->
        # No editing section or different section, don't update
        socket
    end
  end

  # Toggle section media support
  def handle_toggle_section_media_support(socket, %{"id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    # Find the section to update
    section_to_update = Enum.find(sections, &(&1.id == section_id_int))

    if section_to_update do
      current_allow_media = Map.get(section_to_update, :allow_media, true)
      new_allow_media = !current_allow_media

      case Portfolios.update_section(section_to_update, %{allow_media: new_allow_media}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)
          |> put_flash(:info, "Media support #{if new_allow_media, do: "enabled", else: "disabled"}")

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to update media support: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

    @impl true
  def handle_event("toggle_section_visibility", %{"id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    case Enum.find(sections, &(&1.id == section_id_int)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        case Portfolios.update_section(section, %{visible: !section.visible}) do
          {:ok, updated_section} ->
            updated_sections = Enum.map(sections, fn s ->
              if s.id == section_id_int, do: updated_section, else: s
            end)

            socket = socket
            |> assign(:sections, updated_sections)
            |> put_flash(:info, "Section visibility updated")
            |> push_event("section-visibility-toggled", %{
              section_id: section_id_int,
              visible: updated_section.visible
            })

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update section visibility")}
        end
    end
  end

  def handle_show_media_library(socket, %{"section-id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    portfolio_id = socket.assigns.portfolio.id

    # Get available media for this portfolio
    available_media = Portfolios.list_unattached_portfolio_media(portfolio_id)

    socket = socket
    |> assign(:show_media_library, true)
    |> assign(:media_library_section_id, section_id_int)
    |> assign(:available_media, available_media)

    {:noreply, socket}
  end

  def handle_hide_media_library(socket, _params) do
    socket = socket
    |> assign(:show_media_library, false)
    |> assign(:media_library_section_id, nil)
    |> assign(:available_media, [])

    {:noreply, socket}
  end

  def handle_attach_media_to_section(socket, %{"section_id" => section_id, "media_id" => media_id}) do
    section_id_int = String.to_integer(section_id)
    media_id_int = String.to_integer(media_id)

    case Portfolios.attach_media_to_section(section_id_int, media_id_int) do
      {:ok, _updated_media} ->
        # Refresh section media and available media
        section_media = Portfolios.list_section_media(section_id_int)
        available_media = Portfolios.list_unattached_portfolio_media(socket.assigns.portfolio.id)

        socket = socket
        |> assign(:editing_section_media, section_media)
        |> assign(:available_media, available_media)
        |> put_flash(:info, "Media attached to section successfully")
        |> push_event("media-attached", %{section_id: section_id_int, media_id: media_id_int})

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Failed to attach media: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  def handle_detach_media_from_section(socket, %{"media_id" => media_id}) do
    media_id_int = String.to_integer(media_id)

    case Portfolios.detach_media_from_section(media_id_int) do
      {:ok, _updated_media} ->
        # Refresh section media if we're editing a section
        section_media = if socket.assigns[:editing_section] do
          Portfolios.list_section_media(socket.assigns.editing_section.id)
        else
          []
        end

        available_media = Portfolios.list_unattached_portfolio_media(socket.assigns.portfolio.id)

        socket = socket
        |> assign(:editing_section_media, section_media)
        |> assign(:available_media, available_media)
        |> put_flash(:info, "Media detached from section")
        |> push_event("media-detached", %{media_id: media_id_int})

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Failed to detach media: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  # Add media upload handler for sections:
  def handle_upload_media_to_section(socket, %{"section_id" => section_id}, uploaded_files) do
    section_id_int = String.to_integer(section_id)
    portfolio_id = socket.assigns.portfolio.id

    # Process uploaded files
    results = Enum.map(uploaded_files, fn file_info ->
      media_attrs = %{
        portfolio_id: portfolio_id,
        section_id: section_id_int,
        title: file_info.filename,
        description: "",
        media_type: determine_media_type(file_info.filename),
        file_path: file_info.path,
        file_size: file_info.size,
        mime_type: file_info.content_type,
        position: 0
      }

      case Portfolios.create_media(media_attrs) do
        {:ok, media} -> {:ok, media}
        {:error, changeset} -> {:error, changeset}
      end
    end)

    {successes, errors} = Enum.split_with(results, &match?({:ok, _}, &1))

    if length(successes) > 0 do
      # Refresh section media
      section_media = Portfolios.list_section_media(section_id_int)

      socket = socket
      |> assign(:editing_section_media, section_media)
      |> put_flash(:info, "#{length(successes)} file(s) uploaded successfully")
      |> push_event("media-uploaded", %{section_id: section_id_int, count: length(successes)})

      {:noreply, socket}
    else
      socket = socket
      |> put_flash(:error, "Failed to upload files")

      {:noreply, socket}
    end
  end

  # Add helper to determine media type from filename:
  defp determine_media_type(filename) do
    extension = Path.extname(filename) |> String.downcase()

    case extension do
      ext when ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg"] -> "image"
      ext when ext in [".mp4", ".webm", ".mov", ".avi"] -> "video"
      ext when ext in [".mp3", ".wav", ".ogg"] -> "audio"
      ext when ext in [".pdf", ".doc", ".docx", ".txt"] -> "document"
      _ -> "document"
    end
  end


  def handle_show_media_library(socket, %{"section-id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    portfolio_id = socket.assigns.portfolio.id

    # Get available media for this portfolio
    available_media = Portfolios.list_unattached_portfolio_media(portfolio_id)

    socket = socket
    |> assign(:show_media_library, true)
    |> assign(:media_library_section_id, section_id_int)
    |> assign(:available_media, available_media)

    {:noreply, socket}
  end

  def handle_hide_media_library(socket, _params) do
    socket = socket
    |> assign(:show_media_library, false)
    |> assign(:media_library_section_id, nil)
    |> assign(:available_media, [])

    {:noreply, socket}
  end

  def handle_attach_media_to_section(socket, %{"section_id" => section_id, "media_id" => media_id}) do
    section_id_int = String.to_integer(section_id)
    media_id_int = String.to_integer(media_id)

    case Portfolios.attach_media_to_section(section_id_int, media_id_int) do
      {:ok, _updated_media} ->
        # Refresh section media and available media
        section_media = Portfolios.list_section_media(section_id_int)
        available_media = Portfolios.list_unattached_portfolio_media(socket.assigns.portfolio.id)

        socket = socket
        |> assign(:editing_section_media, section_media)
        |> assign(:available_media, available_media)
        |> put_flash(:info, "Media attached to section successfully")
        |> push_event("media-attached", %{section_id: section_id_int, media_id: media_id_int})

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Failed to attach media: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  def handle_detach_media_from_section(socket, %{"media_id" => media_id}) do
    media_id_int = String.to_integer(media_id)

    case Portfolios.detach_media_from_section(media_id_int) do
      {:ok, _updated_media} ->
        # Refresh section media if we're editing a section
        section_media = if socket.assigns[:editing_section] do
          Portfolios.list_section_media(socket.assigns.editing_section.id)
        else
          []
        end

        available_media = Portfolios.list_unattached_portfolio_media(socket.assigns.portfolio.id)

        socket = socket
        |> assign(:editing_section_media, section_media)
        |> assign(:available_media, available_media)
        |> put_flash(:info, "Media detached from section")
        |> push_event("media-detached", %{media_id: media_id_int})

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Failed to detach media: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  # Apply section template
  def handle_apply_section_template(socket, %{"section-id" => section_id, "template" => template}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    # Find the section to update
    section_to_update = Enum.find(sections, &(&1.id == section_id_int))

    if section_to_update do
      # Get default content for the section type
      default_content = get_default_content_for_section_type(section_to_update.section_type, template)

      case Portfolios.update_section(section_to_update, %{content: default_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)
          |> put_flash(:info, "Template applied successfully")

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to apply template: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # Export section template
  def handle_export_section_template(socket, %{"section-id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections

    # Find the section to export
    section_to_export = Enum.find(sections, &(&1.id == section_id_int))

    if section_to_export do
      template_data = %{
        section_type: section_to_export.section_type,
        title: section_to_export.title,
        content: section_to_export.content,
        created_at: DateTime.utc_now()
      }

      # Convert to JSON for download
      json_data = Jason.encode!(template_data, pretty: true)

      socket = socket
      |> push_event("download-template", %{
        filename: "#{section_to_export.title |> String.replace(" ", "_")}_template.json",
        data: json_data,
        content_type: "application/json"
      })
      |> put_flash(:info, "Template export ready for download")

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # Show/Hide Add Skill Form
  @impl true
  def handle_event("show_add_skill_form", _params, socket) do
    {:noreply, assign(socket, :show_add_skill_form, true)}
  end

  @impl true
  def handle_event("hide_add_skill_form", _params, socket) do
    {:noreply, assign(socket, :show_add_skill_form, false)}
  end

  # Add Individual Skill
  @impl true
  def handle_event("add_skill", params, socket) do
    %{
      "skill_name" => name,
      "proficiency" => proficiency,
      "years" => years_str,
      "category" => category
    } = params

    # Parse years (handle empty string)
    years = case years_str do
      "" -> nil
      str -> String.to_integer(str)
    end

    new_skill = %{
      "name" => String.trim(name),
      "proficiency" => proficiency,
      "years" => years,
      "category" => category
    }

    # Get current content
    section = socket.assigns.editing_section
    current_content = section.content || %{}
    skill_categories = get_in(current_content, ["skill_categories"]) || %{}

    # Add skill to appropriate category
    updated_categories = Map.update(skill_categories, category, [new_skill], fn existing_skills ->
      existing_skills ++ [new_skill]
    end)

    # Update section content
    updated_content = Map.put(current_content, "skill_categories", updated_categories)

    case Portfolios.update_section(section, %{content: updated_content}) do
      {:ok, updated_section} ->
        # Update sections list
        updated_sections = Enum.map(socket.assigns.sections, fn s ->
          if s.id == updated_section.id, do: updated_section, else: s
        end)

        {:noreply,
        socket
        |> assign(:sections, updated_sections)
        |> assign(:editing_section, updated_section)
        |> assign(:show_add_skill_form, false)
        |> put_flash(:info, "Skill '#{name}' added successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add skill.")}
    end
  end

  # Bulk Import Skills
  @impl true
  def handle_event("toggle_bulk_import_skills", _params, socket) do
    current_state = socket.assigns[:show_bulk_import] || false
    {:noreply, assign(socket, :show_bulk_import, !current_state)}
  end

  @impl true
  def handle_event("hide_bulk_import", _params, socket) do
    {:noreply, assign(socket, :show_bulk_import, false)}
  end

  @impl true
  def handle_event("bulk_import_skills", %{"skills_text" => skills_text}, socket) do
    # Parse the bulk import text
    imported_skills = parse_bulk_skills_text(skills_text)

    if length(imported_skills) == 0 do
      {:noreply, put_flash(socket, :error, "No valid skills found to import.")}
    else
      # Get current content
      section = socket.assigns.editing_section
      current_content = section.content || %{}
      skill_categories = get_in(current_content, ["skill_categories"]) || %{}

      # Group imported skills by category
      updated_categories = Enum.reduce(imported_skills, skill_categories, fn skill, acc ->
        category = skill["category"] || "Other"
        Map.update(acc, category, [skill], fn existing_skills ->
          existing_skills ++ [skill]
        end)
      end)

      # Update section content
      updated_content = Map.put(current_content, "skill_categories", updated_categories)

      case Portfolios.update_section(section, %{content: updated_content}) do
        {:ok, updated_section} ->
          # Update sections list
          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == updated_section.id, do: updated_section, else: s
          end)

          {:noreply,
          socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, updated_section)
          |> assign(:show_bulk_import, false)
          |> put_flash(:info, "Successfully imported #{length(imported_skills)} skills!")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to import skills.")}
      end
    end
  end

  # Update Individual Skill Properties
  @impl true
  def handle_event("update_skill_name", params, socket) do
    %{"value" => new_name, "category" => category, "index" => index_str} = params
    index = String.to_integer(index_str)

    update_skill_property(socket, category, index, "name", String.trim(new_name))
  end

  @impl true
  def handle_event("update_skill_proficiency", params, socket) do
    %{"value" => proficiency, "category" => category, "index" => index_str} = params
    index = String.to_integer(index_str)

    update_skill_property(socket, category, index, "proficiency", proficiency)
  end

  @impl true
  def handle_event("update_skill_years", params, socket) do
    %{"value" => years_str, "category" => category, "index" => index_str} = params
    index = String.to_integer(index_str)

    years = case years_str do
      "" -> nil
      str -> String.to_integer(str)
    end

    update_skill_property(socket, category, index, "years", years)
  end

  # Remove Individual Skill
  @impl true
  def handle_event("remove_skill", params, socket) do
    %{"category" => category, "index" => index_str} = params
    index = String.to_integer(index_str)

    section = socket.assigns.editing_section
    current_content = section.content || %{}
    skill_categories = get_in(current_content, ["skill_categories"]) || %{}

    case Map.get(skill_categories, category) do
      nil ->
        {:noreply, put_flash(socket, :error, "Category not found.")}

      category_skills ->
        # Remove skill at index
        updated_skills = List.delete_at(category_skills, index)

        # Update or remove category
        updated_categories = if length(updated_skills) == 0 do
          Map.delete(skill_categories, category)
        else
          Map.put(skill_categories, category, updated_skills)
        end

        # Update section content
        updated_content = Map.put(current_content, "skill_categories", updated_categories)

        case Portfolios.update_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            # Update sections list
            updated_sections = Enum.map(socket.assigns.sections, fn s ->
              if s.id == updated_section.id, do: updated_section, else: s
            end)

            {:noreply,
            socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Skill removed successfully!")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to remove skill.")}
        end
    end
  end

  # Remove Entire Category
  @impl true
  def handle_event("remove_category", %{"category" => category}, socket) do
    section = socket.assigns.editing_section
    current_content = section.content || %{}
    skill_categories = get_in(current_content, ["skill_categories"]) || %{}

    updated_categories = Map.delete(skill_categories, category)
    updated_content = Map.put(current_content, "skill_categories", updated_categories)

    case Portfolios.update_section(section, %{content: updated_content}) do
      {:ok, updated_section} ->
        # Update sections list
        updated_sections = Enum.map(socket.assigns.sections, fn s ->
          if s.id == updated_section.id, do: updated_section, else: s
        end)

        {:noreply,
        socket
        |> assign(:sections, updated_sections)
        |> assign(:editing_section, updated_section)
        |> put_flash(:info, "Category '#{category}' removed successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove category.")}
    end
  end

  # Clear All Skills
  @impl true
  def handle_event("clear_all_skills", _params, socket) do
    section = socket.assigns.editing_section
    current_content = section.content || %{}

    updated_content = Map.merge(current_content, %{
      "skills" => [],
      "skill_categories" => %{}
    })

    case Portfolios.update_section(section, %{content: updated_content}) do
      {:ok, updated_section} ->
        # Update sections list
        updated_sections = Enum.map(socket.assigns.sections, fn s ->
          if s.id == updated_section.id, do: updated_section, else: s
        end)

        {:noreply,
        socket
        |> assign(:sections, updated_sections)
        |> assign(:editing_section, updated_section)
        |> put_flash(:info, "All skills cleared successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to clear skills.")}
    end
  end

  # Auto-organize skills by category
  @impl true
  def handle_event("organize_by_category", _params, socket) do
    section = socket.assigns.editing_section
    current_content = section.content || %{}

    # Get all skills from both sources
    skills = get_in(current_content, ["skills"]) || []
    skill_categories = get_in(current_content, ["skill_categories"]) || %{}

    # Flatten all skills
    all_skills = if map_size(skill_categories) > 0 do
      skill_categories |> Map.values() |> List.flatten()
    else
      Enum.map(skills, fn skill ->
        case skill do
          %{"name" => _} = s -> s
          skill_string -> %{"name" => skill_string, "proficiency" => "intermediate"}
        end
      end)
    end

    # Auto-categorize skills
    organized_categories = Enum.group_by(all_skills, &auto_categorize_skill/1)

    updated_content = Map.merge(current_content, %{
      "skills" => [],
      "skill_categories" => organized_categories
    })

    case Portfolios.update_section(section, %{content: updated_content}) do
      {:ok, updated_section} ->
        # Update sections list
        updated_sections = Enum.map(socket.assigns.sections, fn s ->
          if s.id == updated_section.id, do: updated_section, else: s
        end)

        {:noreply,
        socket
        |> assign(:sections, updated_sections)
        |> assign(:editing_section, updated_section)
        |> put_flash(:info, "Skills organized by category automatically!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to organize skills.")}
    end
  end

  defp get_default_content_for_type("story") do
    %{
      "title" => "My Story",
      "narrative" => "Tell your professional journey in a compelling narrative format.",
      "chapters" => [
        %{
          "title" => "The Beginning",
          "content" => "Where your story starts...",
          "year" => "2020"
        },
        %{
          "title" => "The Journey",
          "content" => "Key milestones and growth...",
          "year" => "2022"
        },
        %{
          "title" => "Today",
          "content" => "Where you are now...",
          "year" => "2024"
        }
      ]
    }
  end

  defp get_default_content_for_type("timeline") do
    %{
      "title" => "Career Timeline",
      "events" => [
        %{
          "date" => "2024",
          "title" => "Current Role",
          "description" => "Your current position and achievements"
        },
        %{
          "date" => "2022",
          "title" => "Career Milestone",
          "description" => "A significant career achievement"
        },
        %{
          "date" => "2020",
          "title" => "Professional Start",
          "description" => "Beginning of your professional journey"
        }
      ]
    }
  end
  # Helper Functions

    # Update specific job fields in experience content
  defp update_job_field(content, job_field, value) do
    [job_index_str, field_name] = String.split(job_field, "_", parts: 2)
    job_index = String.to_integer(job_index_str)

    jobs = Map.get(content, "jobs", [])

    if job_index < length(jobs) do
      updated_jobs = List.update_at(jobs, job_index, fn job ->
        Map.put(job, field_name, value)
      end)
      Map.put(content, "jobs", updated_jobs)
    else
      content
    end
  rescue
    _ -> content  # If parsing fails, return original content
  end

  # Update specific education fields
  defp update_education_field(content, edu_field, value) do
    [edu_index_str, field_name] = String.split(edu_field, "_", parts: 2)
    edu_index = String.to_integer(edu_index_str)

    education = Map.get(content, "education", [])

    if edu_index < length(education) do
      updated_education = List.update_at(education, edu_index, fn edu ->
        Map.put(edu, field_name, value)
      end)
      Map.put(content, "education", updated_education)
    else
      content
    end
  rescue
    _ -> content  # If parsing fails, return original content
  end

  defp update_skill_property(socket, category, index, property, value) do
    section = socket.assigns.editing_section
    current_content = section.content || %{}
    skill_categories = get_in(current_content, ["skill_categories"]) || %{}

    case Map.get(skill_categories, category) do
      nil ->
        {:noreply, put_flash(socket, :error, "Category not found.")}

      category_skills ->
        case Enum.at(category_skills, index) do
          nil ->
            {:noreply, put_flash(socket, :error, "Skill not found.")}

          skill ->
            # Update the skill property
            updated_skill = Map.put(skill, property, value)
            updated_skills = List.replace_at(category_skills, index, updated_skill)
            updated_categories = Map.put(skill_categories, category, updated_skills)
            updated_content = Map.put(current_content, "skill_categories", updated_categories)

            case Portfolios.update_section(section, %{content: updated_content}) do
              {:ok, updated_section} ->
                # Update sections list
                updated_sections = Enum.map(socket.assigns.sections, fn s ->
                  if s.id == updated_section.id, do: updated_section, else: s
                end)

                {:noreply,
                socket
                |> assign(:sections, updated_sections)
                |> assign(:editing_section, updated_section)}

              {:error, _changeset} ->
                {:noreply, put_flash(socket, :error, "Failed to update skill.")}
            end
        end
    end
  end

  defp strip_html(content) when is_binary(content) do
    content
    |> String.replace(~r/<[^>]*>/, "")  # Remove HTML tags
    |> String.replace(~r/&nbsp;/, " ")  # Replace &nbsp; with spaces
    |> String.replace(~r/&amp;/, "&")   # Replace &amp; with &
    |> String.replace(~r/&lt;/, "<")    # Replace &lt; with <
    |> String.replace(~r/&gt;/, ">")    # Replace &gt; with >
    |> String.replace(~r/&quot;/, "\"") # Replace &quot; with "
    |> String.replace(~r/&#39;/, "'")   # Replace &#39; with '
    |> String.trim()
    |> String.replace(~r/\s+/, " ")     # Normalize whitespace
  end
  defp strip_html(content), do: content

  # Clean value for JavaScript events (remove sensitive data)
  defp cleaned_value_for_event(value) when is_binary(value) do
    if String.length(value) > 100 do
      String.slice(value, 0, 100) <> "..."
    else
      value
    end
  end
  defp cleaned_value_for_event(value), do: value


  defp parse_bulk_skills_text(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_skill_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_skill_line(line) do
    case String.split(line, ",") |> Enum.map(&String.trim/1) do
      [name] when name != "" ->
        %{
          "name" => name,
          "proficiency" => "intermediate",
          "years" => nil,
          "category" => auto_categorize_skill_name(name)
        }

      [name, proficiency] when name != "" ->
        %{
          "name" => name,
          "proficiency" => normalize_proficiency(proficiency),
          "years" => nil,
          "category" => auto_categorize_skill_name(name)
        }

      [name, proficiency, years] when name != "" ->
        parsed_years = case Integer.parse(years) do
          {num, _} -> num
          _ -> nil
        end

        %{
          "name" => name,
          "proficiency" => normalize_proficiency(proficiency),
          "years" => parsed_years,
          "category" => auto_categorize_skill_name(name)
        }

      [name, proficiency, years, category] when name != "" ->
        parsed_years = case Integer.parse(years) do
          {num, _} -> num
          _ -> nil
        end

        %{
          "name" => name,
          "proficiency" => normalize_proficiency(proficiency),
          "years" => parsed_years,
          "category" => category
        }

      _ ->
        nil
    end
  end

  defp normalize_proficiency(prof_str) do
    case prof_str |> String.downcase() |> String.trim() do
      p when p in ["beginner", "basic", "novice", "learning", "1"] -> "beginner"
      p when p in ["intermediate", "competent", "developing", "2", "3"] -> "intermediate"
      p when p in ["advanced", "proficient", "skilled", "4"] -> "advanced"
      p when p in ["expert", "master", "specialist", "guru", "5"] -> "expert"
      _ -> "intermediate"
    end
  end

  defp auto_categorize_skill(%{"name" => name}) do
    auto_categorize_skill_name(name)
  end

  defp auto_categorize_skill_name(name) do
    name_lower = String.downcase(name)

    cond do
      # Programming Languages
      name_lower in ["javascript", "python", "java", "c++", "c#", "ruby", "go", "rust", "swift", "kotlin", "php", "typescript", "scala", "r", "matlab", "sql"] ->
        "Programming Languages"

      # Frameworks & Libraries
      name_lower in ["react", "vue", "angular", "node.js", "express", "django", "flask", "spring", "laravel", "rails", "next.js", "gatsby", "nuxt", "svelte"] ->
        "Frameworks & Libraries"

      # Tools & Platforms
      name_lower in ["git", "docker", "kubernetes", "aws", "azure", "gcp", "jenkins", "gitlab", "github", "npm", "webpack", "babel", "eslint", "jest", "cypress"] ->
        "Tools & Platforms"

      # Databases
      name_lower in ["mysql", "postgresql", "mongodb", "redis", "elasticsearch", "sqlite", "oracle", "sql server", "dynamodb", "firebase"] ->
        "Databases"

      # Design & Creative
      name_lower in ["photoshop", "illustrator", "figma", "sketch", "adobe xd", "canva", "ui design", "ux design", "graphic design", "web design"] ->
        "Design & Creative"

      # Soft Skills
      name_lower in ["leadership", "communication", "teamwork", "project management", "time management", "problem solving", "critical thinking", "presentation", "negotiation", "mentoring"] ->
        "Soft Skills"

      # Data & Analytics
      name_lower in ["excel", "tableau", "power bi", "analytics", "data analysis", "statistics", "machine learning", "ai", "data science", "big data"] ->
        "Data & Analytics"

      # Default category
      true ->
        "Other"
    end
  end

  # Helper function to get default content for section types with templates
  defp get_default_content_for_section_type(section_type, template \\ "default")

  defp get_default_content_for_section_type(section_type, template) do
    base_content = case section_type do
      :intro -> %{
        "headline" => "Your Professional Headline",
        "summary" => "A compelling summary of your background and expertise.",
        "location" => "Your City, State"
      }
      :experience -> %{
        "jobs" => [
          %{
            "title" => "Your Position",
            "company" => "Company Name",
            "start_date" => "Month Year",
            "end_date" => "Present",
            "current" => true,
            "description" => "Key responsibilities and achievements in this role."
          }
        ]
      }
      :skills -> %{
        "skills" => ["Skill 1", "Skill 2", "Skill 3"]
      }
      _ -> %{}
    end

    # Apply template-specific modifications
    case template do
      "professional" -> apply_professional_template(base_content, section_type)
      "creative" -> apply_creative_template(base_content, section_type)
      "technical" -> apply_technical_template(base_content, section_type)
      _ -> base_content
    end
  end

  defp apply_professional_template(content, :intro) do
    Map.merge(content, %{
      "headline" => "Experienced Professional",
      "summary" => "Results-driven professional with a proven track record of success."
    })
  end

  defp apply_professional_template(content, _), do: content

  defp apply_creative_template(content, :intro) do
    Map.merge(content, %{
      "headline" => "Creative Professional",
      "summary" => "Innovative thinker bringing creativity to every project."
    })
  end

  defp apply_creative_template(content, _), do: content

  defp apply_technical_template(content, :intro) do
    Map.merge(content, %{
      "headline" => "Technical Expert",
      "summary" => "Technology specialist with deep expertise in modern solutions."
    })
  end

  defp apply_technical_template(content, _), do: content

  # Helper function to format errors
  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end

    # Enhanced reordering functions
  defp parse_section_id(section_id) when is_binary(section_id) do
    case Integer.parse(section_id) do
      {id, ""} -> id
      _ -> nil
    end
  end
  defp parse_section_id(section_id) when is_integer(section_id), do: section_id
  defp parse_section_id(_), do: nil



  defp reindex_sections(sections) do
    sections
    |> Enum.with_index(1)
    |> Enum.map(fn {section, index} ->
      case Portfolios.update_section(section, %{position: index}) do
        {:ok, updated_section} -> updated_section
        {:error, _} -> section
      end
    end)
  end

  defp update_section_in_list(sections, updated_section) do
    Enum.map(sections, fn section ->
      if section.id == updated_section.id, do: updated_section, else: section
    end)
  end

  # Default content generators - Enhanced for multiple entries
  defp get_default_title_for_type(type) do
    case type do
      "intro" -> "Introduction"
      "experience" -> "Professional Experience"
      "education" -> "Education"
      "skills" -> "Skills & Expertise"
      "projects" -> "Projects"
      "featured_project" -> "Featured Project"
      "case_study" -> "Case Study"
      "achievements" -> "Achievements"
      "testimonial" -> "Testimonials"
      "media_showcase" -> "Media Gallery"
      "code_showcase" -> "Code Showcase"
      "contact" -> "Contact Information"
      "story" -> "My Story"           # Added
      "timeline" -> "Timeline"        # Added
      "narrative" -> "Narrative"      # Added
      "journey" -> "My Journey"       # Added
      "custom" -> "Custom Section"
      _ -> "New Section"
    end
  end

  defp get_default_content_for_type("intro") do
    %{
      "headline" => "Hello, I'm [Your Name]",
      "summary" => "A brief introduction about yourself and your professional journey.",
      "location" => "",
      "website" => "",
      "social_links" => %{
        "linkedin" => "",
        "github" => "",
        "twitter" => "",
        "portfolio" => ""
      },
      "availability" => "Available for new opportunities",
      "call_to_action" => "Let's connect and discuss opportunities"
    }
  end

  defp get_default_content_for_type("experience") do
    %{
      "jobs" => [
        %{
          "title" => "Your Current Position",
          "company" => "Company Name",
          "location" => "City, State",
          "employment_type" => "Full-time",
          "start_date" => "Month Year",
          "end_date" => "",
          "current" => true,
          "description" => "Brief description of your role and key responsibilities.",
          "responsibilities" => [
            "Led cross-functional teams to deliver key projects",
            "Developed and implemented strategic initiatives"
          ],
          "achievements" => [
            "Increased team productivity by 25%",
            "Successfully launched 3 major product features"
          ],
          "skills" => ["Leadership", "Project Management", "Strategic Planning"]
        }
      ]
    }
  end

  defp get_default_content_for_type("education") do
    %{
      "education" => [
        %{
          "degree" => "Bachelor of Science",
          "field" => "Your Field of Study",
          "institution" => "University Name",
          "location" => "City, State",
          "start_date" => "Year",
          "end_date" => "Year",
          "status" => "Completed",
          "gpa" => "",
          "description" => "Relevant details about your educational experience.",
          "relevant_coursework" => [
            "Data Structures and Algorithms",
            "Database Systems",
            "Software Engineering"
          ],
          "activities" => [
            "Computer Science Club Member",
            "Dean's List (3 semesters)",
            "Undergraduate Research Assistant"
          ]
        }
      ]
    }
  end

  defp get_default_content_for_type("skills") do
    %{
      "skills" => ["JavaScript", "Python", "React", "Node.js", "SQL", "Git", "Docker", "AWS"],
      "skill_categories" => %{
        "Programming Languages" => [
          %{"name" => "JavaScript", "proficiency" => "Expert", "years" => 5},
          %{"name" => "Python", "proficiency" => "Advanced", "years" => 4}
        ],
        "Frameworks & Libraries" => [
          %{"name" => "React", "proficiency" => "Expert", "years" => 4},
          %{"name" => "Node.js", "proficiency" => "Advanced", "years" => 3}
        ],
        "Tools & Platforms" => [
          %{"name" => "Git", "proficiency" => "Expert", "years" => 5},
          %{"name" => "Docker", "proficiency" => "Advanced", "years" => 2}
        ]
      }
    }
  end

  defp get_default_content_for_type("projects") do
    %{
      "projects" => [
        %{
          "title" => "Project Name",
          "description" => "Brief description of the project and its purpose.",
          "technologies" => ["React", "Node.js", "PostgreSQL"],
          "role" => "Full-Stack Developer",
          "start_date" => "Month Year",
          "end_date" => "Month Year",
          "status" => "Completed",
          "demo_url" => "",
          "github_url" => ""
        }
      ]
    }
  end

  defp get_default_content_for_type("featured_project") do
    %{
      "title" => "Featured Project Name",
      "description" => "Comprehensive description of your most impressive project.",
      "challenge" => "The main challenge or problem this project addressed.",
      "solution" => "Your innovative approach to solving the challenge.",
      "technologies" => ["React", "Node.js", "PostgreSQL", "Docker"],
      "role" => "Lead Full-Stack Developer",
      "timeline" => "6 months",
      "impact" => "Delivered 40% performance improvement and enhanced user experience.",
      "key_insights" => [
        "Learned advanced optimization techniques",
        "Gained experience with microservices architecture"
      ],
      "demo_url" => "",
      "github_url" => ""
    }
  end

  defp get_default_content_for_type("case_study") do
    %{
      "client" => "Client/Company Name",
      "project_title" => "Project Title",
      "overview" => "Executive summary of the project and its objectives.",
      "problem_statement" => "Clear definition of the business problem to be solved.",
      "approach" => "Detailed methodology and approach to solving the problem.",
      "process" => [
        "Discovery and Requirements Gathering",
        "Design and Architecture Planning",
        "Development and Implementation",
        "Testing and Quality Assurance"
      ],
      "results" => "Measurable outcomes and business impact achieved.",
      "metrics" => [
        %{"label" => "Performance Improvement", "value" => "50%"},
        %{"label" => "User Satisfaction", "value" => "95%"}
      ],
      "learnings" => "Key insights and lessons learned from the project.",
      "next_steps" => "Future recommendations and planned enhancements."
    }
  end

  defp get_default_content_for_type("achievements") do
    %{
      "achievements" => [
        %{
          "title" => "Achievement Title",
          "description" => "Description of the achievement and its significance.",
          "date" => "Month Year",
          "organization" => "Awarding Organization"
        }
      ]
    }
  end

  defp get_default_content_for_type("testimonial") do
    %{
      "testimonials" => [
        %{
          "quote" => "This professional consistently delivers high-quality work.",
          "name" => "Client Name",
          "title" => "Senior Manager",
          "company" => "Company Name",
          "rating" => 5
        }
      ]
    }
  end

  defp get_default_content_for_type("media_showcase") do
    %{
      "title" => "Media Gallery",
      "description" => "A curated collection of visual work and project demonstrations.",
      "context" => "Context about when and why this media was created.",
      "what_to_notice" => "Key elements viewers should pay attention to.",
      "techniques_used" => ["Photography", "Video Editing", "Graphic Design"]
    }
  end

  defp get_default_content_for_type("code_showcase") do
    %{
      "title" => "Code Example",
      "description" => "Demonstration of coding skills and problem-solving approach.",
      "language" => "JavaScript",
      "key_features" => [
        "Clean, readable code structure",
        "Efficient algorithm implementation"
      ],
      "explanation" => "Detailed explanation of the code logic and design decisions.",
      "line_highlights" => [],
      "repository_url" => ""
    }
  end

  defp get_default_content_for_type("contact") do
    %{
      "email" => "",
      "phone" => "",
      "location" => "",
      "availability" => "Available for new opportunities",
      "preferred_contact" => "email",
      "timezone" => "",
      "response_time" => "Within 24 hours",
      "social_links" => %{
        "linkedin" => "",
        "github" => "",
        "twitter" => ""
      }
    }
  end

  defp get_default_content_for_type("custom") do
    %{
      "title" => "Custom Section",
      "content" => "Add your custom content here.",
      "layout" => "default",
      "custom_fields" => %{}
    }
  end

  defp get_default_content_for_type(_), do: %{}

  defp format_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

end
