# lib/frestyl_web/live/portfolio_live/edit_live.ex
defmodule FrestylWeb.PortfolioLive.EditLive do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.{Portfolio, PortfolioSection}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    portfolio = Portfolios.get_portfolio!(id)
    sections = Portfolios.list_portfolio_sections(portfolio.id)
    limits = Portfolios.get_portfolio_limits(socket.assigns.current_user)

    # Ensure user owns this portfolio
    if portfolio.user_id != socket.assigns.current_user.id do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to edit this portfolio.")
       |> push_navigate(to: "/portfolios")}
    else
      # Create a form for the portfolio
      form = Portfolio.changeset(portfolio, %{}) |> to_form()

      socket =
        socket
        |> assign(:page_title, "Edit Portfolio")
        |> assign(:portfolio, portfolio)
        |> assign(:sections, sections)
        |> assign(:form, form)
        |> assign(:limits, limits)
        |> assign(:active_tab, :details)
        |> assign(:section_edit_id, nil)
        |> allow_upload(:media,
            accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .webm .mp3 .wav .ogg .pdf .doc .docx),
            max_entries: 5,
            max_file_size: limits.max_media_size_mb * 1_048_576) # Convert MB to bytes

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "details"
    section_id = params["section_id"]

    socket =
      socket
      |> assign(:active_tab, String.to_atom(tab))
      |> assign(:section_edit_id, section_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: "/portfolios/#{socket.assigns.portfolio.id}/edit?tab=#{tab}")}
  end

  @impl true
  def handle_event("update_portfolio", %{"portfolio" => portfolio_params}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, portfolio} ->
        form = Portfolio.changeset(portfolio, %{}) |> to_form()

        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:form, form)
         |> put_flash(:info, "Portfolio updated successfully.")}

      {:error, changeset} ->
        form = changeset |> to_form()
        {:noreply, assign(socket, form: form)}
    end
  end

  @impl true
  def handle_event("add_section", _params, socket) do
    # Find the highest position and add 1
    highest_position =
      socket.assigns.sections
      |> Enum.map(& &1.position)
      |> Enum.max(fn -> 0 end)

    section_params = %{
      portfolio_id: socket.assigns.portfolio.id,
      title: "New Section",
      section_type: :custom,
      position: highest_position + 1,
      content: %{}
    }

    case Portfolios.create_section(section_params) do
      {:ok, section} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

        {:noreply,
         socket
         |> assign(:sections, sections)
         |> push_patch(to: "/portfolios/#{socket.assigns.portfolio.id}/edit?tab=sections&section_id=#{section.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create section.")}
    end
  end

  @impl true
  def handle_event("save_section", %{"section" => section_params}, socket) do
    section_id = socket.assigns.section_edit_id
    section = Portfolios.get_section!(section_id)

    # Preserve content structure for different section types
    content =
      case section_params["section_type"] do
        "intro" ->
          %{
            "headline" => section_params["headline"] || "",
            "summary" => section_params["summary"] || ""
          }

        "experience" ->
          jobs =
            (section_params["jobs"] || [])
            |> Enum.map(fn {_, job} ->
              %{
                "company" => job["company"] || "",
                "title" => job["title"] || "",
                "start_date" => job["start_date"] || "",
                "end_date" => job["end_date"] || "",
                "description" => job["description"] || "",
                "current" => job["current"] == "true"
              }
            end)

          %{"jobs" => jobs}

        "education" ->
          education =
            (section_params["education"] || [])
            |> Enum.map(fn {_, edu} ->
              %{
                "institution" => edu["institution"] || "",
                "degree" => edu["degree"] || "",
                "field" => edu["field"] || "",
                "start_date" => edu["start_date"] || "",
                "end_date" => edu["end_date"] || "",
                "description" => edu["description"] || ""
              }
            end)

          %{"education" => education}

        "skills" ->
          skills =
            (section_params["skills"] || "")
            |> String.split(",")
            |> Enum.map(&String.trim/1)
            |> Enum.filter(&(&1 != ""))

          %{"skills" => skills}

        "contact" ->
          %{
            "email" => section_params["email"] || "",
            "phone" => section_params["phone"] || "",
            "location" => section_params["location"] || ""
          }

        "custom" ->
          %{
            "title" => section_params["custom_title"] || "",
            "content" => section_params["custom_content"] || ""
          }

        _ ->
          section.content
      end

    update_params = %{
      "title" => section_params["title"],
      "section_type" => section_params["section_type"],
      "visible" => section_params["visible"] == "true",
      "content" => content
    }

    case Portfolios.update_section(section, update_params) do
      {:ok, _updated} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

        {:noreply,
         socket
         |> assign(:sections, sections)
         |> assign(:section_edit_id, nil)
         |> put_flash(:info, "Section updated successfully.")
         |> push_patch(to: "/portfolios/#{socket.assigns.portfolio.id}/edit?tab=sections")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update section.")}
    end
  end

  @impl true
  def handle_event("delete_section", %{"id" => id}, socket) do
    section = Portfolios.get_section!(id)

    case Portfolios.delete_section(section) do
      {:ok, _} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

        {:noreply,
         socket
         |> assign(:sections, sections)
         |> put_flash(:info, "Section deleted successfully.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete section.")}
    end
  end

  @impl true
  def handle_event("edit_section", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: "/portfolios/#{socket.assigns.portfolio.id}/edit?tab=sections&section_id=#{id}")}
  end

  @impl true
  def handle_event("cancel_section_edit", _params, socket) do
    {:noreply, push_patch(socket, to: "/portfolios/#{socket.assigns.portfolio.id}/edit?tab=sections")}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_media", %{"media" => media_params}, socket) do
    # Process uploaded files
    {media_entries, socket} = process_uploads(socket)

    # Create media entries for the portfolio
    Enum.each(media_entries, fn entry ->
      media_attrs = %{
        title: entry.title || Path.basename(entry.path, Path.extname(entry.path)),
        description: entry.description || "",
        media_type: entry.media_type,
        file_path: entry.file_path,
        file_size: entry.file_size,
        mime_type: entry.mime_type,
        portfolio_id: socket.assigns.portfolio.id,
        section_id: media_params["section_id"],
        visible: true
      }

      Portfolios.create_media(media_attrs)
    end)

    {:noreply, put_flash(socket, :info, "Media uploaded successfully.")}
  end

  @impl true
  def handle_event("add_job", %{"section-id" => section_id}, socket) do
    section = Portfolios.get_section!(section_id)

    # Get existing jobs or initialize empty list
    existing_jobs = section.content["jobs"] || []

    # Add a new empty job
    new_job = %{
      "company" => "",
      "title" => "",
      "start_date" => "",
      "end_date" => "",
      "description" => "",
      "current" => false
    }

    updated_jobs = existing_jobs ++ [new_job]

    # Update the section
    updated_content = Map.put(section.content, "jobs", updated_jobs)

    case Portfolios.update_section(section, %{"content" => updated_content}) do
      {:ok, _} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

        {:noreply,
        socket
        |> assign(:sections, sections)
        |> put_flash(:info, "Job added successfully.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add job.")}
    end
  end

  @impl true
  def handle_event("remove_job", %{"section-id" => section_id, "job-index" => job_index}, socket) do
    section = Portfolios.get_section!(section_id)
    index = String.to_integer(job_index)

    # Get existing jobs and remove the specified one
    existing_jobs = section.content["jobs"] || []
    updated_jobs = List.delete_at(existing_jobs, index)

    # Update the section
    updated_content = Map.put(section.content, "jobs", updated_jobs)

    case Portfolios.update_section(section, %{"content" => updated_content}) do
      {:ok, _} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

        {:noreply,
        socket
        |> assign(:sections, sections)
        |> put_flash(:info, "Job removed successfully.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove job.")}
    end
  end

  @impl true
  def handle_event("add_education", %{"section-id" => section_id}, socket) do
    section = Portfolios.get_section!(section_id)

    existing_education = section.content["education"] || []

    new_education = %{
      "institution" => "",
      "degree" => "",
      "field" => "",
      "start_date" => "",
      "end_date" => "",
      "description" => ""
    }

    updated_education = existing_education ++ [new_education]
    updated_content = Map.put(section.content, "education", updated_education)

    case Portfolios.update_section(section, %{"content" => updated_content}) do
      {:ok, _} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)
        {:noreply, socket |> assign(:sections, sections) |> put_flash(:info, "Education added.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add education.")}
    end
  end

  @impl true
  def handle_event("remove_education", %{"section-id" => section_id, "education-index" => education_index}, socket) do
    section = Portfolios.get_section!(section_id)
    index = String.to_integer(education_index)

    existing_education = section.content["education"] || []
    updated_education = List.delete_at(existing_education, index)
    updated_content = Map.put(section.content, "education", updated_education)

    case Portfolios.update_section(section, %{"content" => updated_content}) do
      {:ok, _} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)
        {:noreply, socket |> assign(:sections, sections) |> put_flash(:info, "Education removed.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove education.")}
    end
  end

  # Skills handlers
  @impl true
  def handle_event("add_skill", %{"section-id" => section_id}, socket) do
    # Get the skill from the input field (we'll use JS to get the value)
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_skill_on_enter", %{"section-id" => section_id, "value" => skill_value}, socket) do
    if String.trim(skill_value) != "" do
      section = Portfolios.get_section!(section_id)

      existing_skills = section.content["skills"] || []
      new_skill = String.trim(skill_value)

      # Don't add duplicate skills
      updated_skills = if new_skill in existing_skills do
        existing_skills
      else
        existing_skills ++ [new_skill]
      end

      updated_content = Map.put(section.content, "skills", updated_skills)

      case Portfolios.update_section(section, %{"content" => updated_content}) do
        {:ok, _} ->
          sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)
          {:noreply, socket |> assign(:sections, sections) |> put_flash(:info, "Skill added.")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add skill.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_skill", %{"section-id" => section_id, "skill-index" => skill_index}, socket) do
    section = Portfolios.get_section!(section_id)
    index = String.to_integer(skill_index)

    existing_skills = section.content["skills"] || []
    updated_skills = List.delete_at(existing_skills, index)
    updated_content = Map.put(section.content, "skills", updated_skills)

    case Portfolios.update_section(section, %{"content" => updated_content}) do
      {:ok, _} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)
        {:noreply, socket |> assign(:sections, sections) |> put_flash(:info, "Skill removed.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove skill.")}
    end
  end

  @impl true
  def handle_event("validate_portfolio", %{"portfolio" => portfolio_params}, socket) do
    # Create a changeset for validation without saving
    changeset = Portfolio.changeset(socket.assigns.portfolio, portfolio_params)
    form = changeset |> to_form(action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("update_portfolio", %{"portfolio" => portfolio_params}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, portfolio} ->
        form = Portfolio.changeset(portfolio, %{}) |> to_form()

        # Flash message with URL update confirmation
        flash_message = if portfolio_params["slug"] && portfolio_params["slug"] != socket.assigns.portfolio.slug do
          "Portfolio updated successfully! Your new URL is: #{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}"
        else
          "Portfolio updated successfully."
        end

        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:form, form)
        |> put_flash(:info, flash_message)}

      {:error, changeset} ->
        form = changeset |> to_form(action: :validate)
        {:noreply, assign(socket, form: form)}
    end
  end

  defp process_uploads(socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
        dest = Path.join("priv/static/uploads/portfolio", "#{socket.assigns.portfolio.id}_#{entry.client_name}")

        # Make sure the directory exists
        File.mkdir_p!(Path.dirname(dest))

        # Copy the file to destination
        File.cp!(path, dest)

        # Determine media type from content type
        media_type = cond do
          String.starts_with?(entry.client_type, "image/") -> :image
          String.starts_with?(entry.client_type, "video/") -> :video
          String.starts_with?(entry.client_type, "audio/") -> :audio
          true -> :document
        end

        # Return the file metadata
        {:ok, %{
          title: Path.rootname(entry.client_name),
          description: "",
          media_type: media_type,
          file_path: "/uploads/portfolio/#{socket.assigns.portfolio.id}_#{entry.client_name}",
          file_size: entry.client_size,
          mime_type: entry.client_type
        }}
      end)

    {uploaded_files, socket}
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "You've selected too many files"
  defp error_to_string(:not_accepted), do: "You've selected an unacceptable file type"
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
