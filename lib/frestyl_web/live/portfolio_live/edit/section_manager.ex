# lib/frestyl_web/live/portfolio_live/edit/section_manager.ex - PART 1 OF 3
defmodule FrestylWeb.PortfolioLive.Edit.SectionManager do
  @moduledoc """
  Handles section-related operations for the portfolio editor.
  COMPLETE VERSION - Part 1: Module setup and core section management
  """

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioSection
  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3]

  # ============================================================================
  # FIXED SECTION REORDERING - Now handles drag-and-drop properly
  # ============================================================================

  def handle_reorder_sections(socket, %{"sections" => section_ids}) when is_list(section_ids) do
    sections = socket.assigns.sections

    # Filter out any invalid section IDs and convert to integers
    valid_section_ids = section_ids
    |> Enum.map(&parse_section_id/1)
    |> Enum.reject(&is_nil/1)

    # Reorder sections based on the new order
    reordered_sections = reorder_sections_by_ids(sections, valid_section_ids)

    # Update positions in database
    case update_section_positions_batch(reordered_sections) do
      {:ok, updated_sections} ->
        socket = socket
        |> assign(:sections, updated_sections)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Sections reordered successfully")
        |> push_event("sections-reordered", %{})

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Failed to reorder sections: #{reason}")

        {:noreply, socket}
    end
  end

  # Fallback for old format
  def handle_reorder_sections(socket, %{"old" => old_index, "new" => new_index}) do
    sections = socket.assigns.sections

    # Convert string indices to integers
    old_idx = String.to_integer(old_index)
    new_idx = String.to_integer(new_index)

    # Validate indices
    if old_idx >= 0 and new_idx >= 0 and old_idx < length(sections) and new_idx < length(sections) do
      # Reorder sections
      reordered_sections = move_section(sections, old_idx, new_idx)

      # Update positions in database
      case update_section_positions_batch(reordered_sections) do
        {:ok, updated_sections} ->
          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Sections reordered successfully")
          |> push_event("sections-reordered", %{})

          {:noreply, socket}

        {:error, reason} ->
          socket = socket
          |> put_flash(:error, "Failed to reorder sections: #{reason}")

          {:noreply, socket}
      end
    else
      socket = socket
      |> put_flash(:error, "Invalid section positions")

      {:noreply, socket}
    end
  end

  # ============================================================================
  # BASIC SECTION MANAGEMENT
  # ============================================================================

  def handle_add_section(socket, %{"type" => type}) do
    sections = socket.assigns.sections
    portfolio = socket.assigns.portfolio
    next_position = length(sections) + 1

    # Create section with default content based on type
    default_content = get_default_content_for_type(type)

    section_attrs = %{
      title: get_default_title_for_type(type),
      section_type: String.to_existing_atom(type),
      position: next_position,
      visible: true,
      content: default_content,
      portfolio_id: portfolio.id
    }

    case Portfolios.create_section(section_attrs) do
      {:ok, section} ->
        updated_sections = sections ++ [section]

        socket = socket
        |> assign(:sections, updated_sections)
        |> assign(:unsaved_changes, false)
        |> assign(:show_add_section_dropdown, false)
        |> put_flash(:info, "Section '#{section.title}' added successfully")
        |> push_event("section-added", %{section_id: section.id, position: section.position})

        {:noreply, socket}

      {:error, changeset} ->
        socket = socket
        |> put_flash(:error, "Failed to add section: #{format_errors(changeset)}")

        {:noreply, socket}
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

  def handle_save_section(socket, params) do
    editing_section = socket.assigns.editing_section

    if editing_section do
      case Portfolios.update_section(editing_section, editing_section) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == editing_section.id, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:section_edit_id, nil)
          |> assign(:editing_section, nil)
          |> assign(:editing_section_media, [])
          |> assign(:section_edit_tab, nil)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Section saved successfully")
          |> push_event("section-saved", %{section_id: updated_section.id})

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to save section: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      socket = socket
      |> put_flash(:error, "No section being edited")

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

  # lib/frestyl_web/live/portfolio_live/edit/section_manager.ex - PART 2 OF 3
# Continue from Part 1...

  def handle_update_section_content(socket, %{"field" => field, "value" => value, "section-id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns.editing_section
    sections = socket.assigns.sections

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      updated_content = Map.put(current_content, field, value)

      case Portfolios.update_section(editing_section, %{content: updated_content}) do
        {:ok, db_updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: db_updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, db_updated_section)
          |> assign(:unsaved_changes, false)
          |> push_event("section-content-updated", %{
            section_id: section_id_int,
            field: field,
            value: value
          })

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

  def handle_add_experience_entry(socket, %{"section-id" => section_id}) do
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
          |> put_flash(:info, "New job entry added")

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to add job entry: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_remove_experience_entry(socket, %{"section-id" => section_id, "index" => index}) do
    section_id_int = String.to_integer(section_id)
    entry_index = String.to_integer(index)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      current_jobs = Map.get(current_content, "jobs", [])

      if entry_index >= 0 and entry_index < length(current_jobs) do
        updated_jobs = List.delete_at(current_jobs, entry_index)
        updated_content = Map.put(current_content, "jobs", updated_jobs)

        case Portfolios.update_section(editing_section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)
            |> put_flash(:info, "Job entry removed")

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to remove job entry: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid entry index")}
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

    # Enhanced reordering functions
  defp parse_section_id(section_id) when is_binary(section_id) do
    case Integer.parse(section_id) do
      {id, ""} -> id
      _ -> nil
    end
  end
  defp parse_section_id(section_id) when is_integer(section_id), do: section_id
  defp parse_section_id(_), do: nil

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
      error_details = Enum.map(errors, fn {:error, changeset} -> format_errors(changeset) end)
      {:error, "Failed to update positions: #{Enum.join(error_details, ", ")}"}
    end
  end

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
