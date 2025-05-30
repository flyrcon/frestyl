# lib/frestyl_web/live/portfolio_live/edit_live.ex
defmodule FrestylWeb.PortfolioLive.Edit do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.{Portfolio, PortfolioSection}

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
      form = Portfolios.change_portfolio(portfolio, %{}) |> to_form()

      # Load customization from portfolio with proper defaults
      customization = portfolio.customization || %{
        "color_scheme" => "purple-pink",
        "layout_style" => "single_page",
        "section_spacing" => "normal",
        "font_style" => "inter",
        "fixed_navigation" => true,
        "dark_mode_support" => false
      }

      socket =
        socket
        |> assign(:page_title, "Edit Portfolio")
        |> assign(:portfolio, portfolio)
        |> assign(:sections, sections)
        |> assign(:form, form)
        |> assign(:customization, customization)
        |> assign(:limits, %{
            max_media_size_mb: limits.max_media_size_mb || 50,
            max_media_size: limits.max_media_size_mb * 1_048_576 || 52_428_800
          })
        |> assign(:active_tab, :details)
        |> assign(:section_edit_id, nil)
        |> allow_upload(:media,
            accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .webm .mp3 .wav .ogg .pdf .doc .docx),
            max_entries: 10,
            max_file_size: limits.max_media_size_mb * 1_048_576,
            auto_upload: false)

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
    tab_atom = String.to_existing_atom(tab)
    {:noreply, assign(socket, active_tab: tab_atom)}
  end

  def handle_event("validate_portfolio", %{"portfolio" => portfolio_params}, socket) do
    changeset =
      socket.assigns.portfolio
      |> Portfolios.change_portfolio(portfolio_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save_section", %{"section" => section_params}, socket) do
    section_id = socket.assigns.section_edit_id

    if section_id do
      section = Portfolios.get_section!(section_id)

      # Preserve content structure for different section types
      content = build_section_content(section_params, section.section_type)

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
    else
      {:noreply, put_flash(socket, :error, "No section selected for editing.")}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

    @impl true
  def handle_event("cancel_section_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:section_edit_id, nil)
     |> push_patch(to: "/portfolios/#{socket.assigns.portfolio.id}/edit?tab=sections")}
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
    existing_jobs = section.content["jobs"] || []

    new_job = %{
      "company" => "",
      "title" => "",
      "start_date" => "",
      "end_date" => "",
      "description" => "",
      "current" => false
    }

    updated_jobs = existing_jobs ++ [new_job]
    updated_content = Map.put(section.content, "jobs", updated_jobs)

    case Portfolios.update_section(section, %{"content" => updated_content}) do
      {:ok, _} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)
        {:noreply, socket |> assign(:sections, sections) |> put_flash(:info, "Job added successfully.")}
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

  @impl true
  def handle_event("select_theme", %{"theme" => theme}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{theme: theme}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> put_flash(:info, "Theme updated successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update theme")}
    end
  end

    @impl true
  def handle_event("edit_section", %{"id" => section_id}, socket) do
    # Set the section edit ID and navigate to sections tab
    {:noreply,
     socket
     |> assign(:section_edit_id, section_id)
     |> assign(:active_tab, :sections)
     |> push_patch(to: "/portfolios/#{socket.assigns.portfolio.id}/edit?tab=sections&section_id=#{section_id}")}
  end

  @impl true
  def handle_event("add_section", _params, socket) do
    # For now, navigate to a dedicated section creation page or show modal
    {:noreply, push_navigate(socket, to: "/portfolios/#{socket.assigns.portfolio.id}/sections/new")}
  end

  @impl true
  def handle_event("delete_section", %{"id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)

    case Portfolios.delete_portfolio_section(section_id_int) do
      {:ok, _section} ->
        # Remove the deleted section from the assigns
        updated_sections = Enum.reject(socket.assigns.sections, &(&1.id == section_id_int))

        {:noreply,
         socket
         |> assign(sections: updated_sections)
         |> put_flash(:info, "Section deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete section")}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  # Handle successful uploads
  @impl true
  def handle_event("save_uploads", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :media, fn %{path: path}, _entry ->
        # Move file to permanent location and create media record
        # This depends on your file storage setup
        dest = Path.join(["priv", "static", "uploads", Path.basename(path)])
        File.cp!(path, dest)
        {:ok, "/uploads/" <> Path.basename(path)}
      end)

    # Create media records in database
    Enum.each(uploaded_files, fn file_url ->
      Portfolios.create_media(%{
        portfolio_id: socket.assigns.portfolio.id,
        url: file_url,
        media_type: :image  # Determine type from file extension
      })
    end)

    {:noreply,
    socket
    |> put_flash(:info, "Files uploaded successfully")
    |> push_navigate(to: ~p"/portfolios/#{socket.assigns.portfolio.id}/edit")}
  end

  @impl true
  def handle_event("update_section_spacing", %{"spacing" => spacing}, socket) do
    updated_customization = Map.put(socket.assigns.customization, :section_spacing, spacing)

    case update_portfolio_customization(socket.assigns.portfolio, updated_customization) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:customization, updated_customization)
         |> put_flash(:info, "Section spacing updated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update spacing")}
    end
  end

  @impl true
  def handle_event("update_font_style", %{"font" => font}, socket) do
    updated_customization = Map.put(socket.assigns.customization, :font_style, font)

    case update_portfolio_customization(socket.assigns.portfolio, updated_customization) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:customization, updated_customization)
         |> put_flash(:info, "Font style updated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update font")}
    end
  end

  @impl true
  def handle_event("update_color", %{"color" => color, "name" => name}, socket) do
    IO.inspect("Color update event: #{color} (#{name})") # Debug log

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{theme_color: color}) do
      {:ok, updated_portfolio} ->
        IO.inspect("Portfolio updated successfully") # Debug log
        {:noreply,
        socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "Theme color updated to #{name}")
        }

      {:error, changeset} ->
        IO.inspect("Portfolio update failed: #{inspect(changeset)}") # Debug log
        {:noreply,
        socket
        |> put_flash(:error, "Failed to update theme color")
        }
    end
  end

  @impl true
  def handle_event("update_color_text", %{"value" => color, "field" => "theme_color"}, socket) do
    IO.inspect("Text color update: #{color}") # Debug log

    # Validate hex color format
    if Regex.match?(~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/, color) do
      case Portfolios.update_portfolio(socket.assigns.portfolio, %{theme_color: color}) do
        {:ok, updated_portfolio} ->
          {:noreply, assign(socket, :portfolio, updated_portfolio)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Invalid color format")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please enter a valid hex color (e.g., #8b5cf6)")}
    end
  end

  @impl true
  def handle_event("update_color_scheme", %{"scheme" => scheme}, socket) do
    updated_customization = Map.put(socket.assigns.customization, "color_scheme", scheme)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:customization, updated_customization)
         |> put_flash(:info, "Color scheme updated! Preview your changes.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update color scheme")}
    end
  end

  @impl true
  def handle_event("update_layout_option", %{"option" => option, "value" => value}, socket) do
    # Convert string value to appropriate type
    converted_value = case value do
      "true" -> true
      "false" -> false
      other -> other
    end

    updated_customization = Map.put(socket.assigns.customization, option, converted_value)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:customization, updated_customization)
         |> put_flash(:info, "Layout option updated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update layout option")}
    end
  end

  @impl true
  def handle_event("update_section_spacing", %{"spacing" => spacing}, socket) do
    updated_customization = Map.put(socket.assigns.customization, "section_spacing", spacing)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> put_flash(:info, "Section spacing updated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update spacing")}
    end
  end

  @impl true
  def handle_event("update_font_style", %{"font" => font}, socket) do
    updated_customization = Map.put(socket.assigns.customization, "font_style", font)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> put_flash(:info, "Font style updated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update font")}
    end
  end

    @impl true
  def handle_event("apply_custom_color", _params, socket) do
    # This is handled by the text input change event
    {:noreply, put_flash(socket, :info, "Custom color applied")}
  end

  @impl true
  def handle_event("apply_theme_changes", _params, socket) do
    # This could trigger additional processing or validation
    {:noreply, put_flash(socket, :info, "All theme changes have been applied and saved!")}
  end

  @impl true
  def handle_event("reset_customization", _params, socket) do
    default_customization = %{
      "color_scheme" => "purple-pink",
      "layout_style" => "single_page",
      "section_spacing" => "normal",
      "font_style" => "inter",
      "fixed_navigation" => true,
      "dark_mode_support" => false
    }

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: default_customization}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, default_customization)
        |> put_flash(:info, "Customization reset to defaults!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reset customization")}
    end
  end

  defp build_section_content(section_params, section_type) do
    case section_type do
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
        %{}
    end
  end

  # Helper function to update portfolio customization
  defp update_portfolio_customization(portfolio, customization) do
    # For now, we'll store customization in the portfolio's custom_css field as JSON
    # Later, you might want to add a proper customization field to the schema
    customization_json = Jason.encode!(customization)

    Portfolios.update_portfolio(portfolio, %{custom_css: customization_json})
  end

  # Helper functions for getting description from section content
  defp get_section_description(section) do
    case section.section_type do
      :intro ->
        get_in(section.content, ["summary"]) || "Introduction section"
      :experience ->
        jobs_count = length(get_in(section.content, ["jobs"]) || [])
        "#{jobs_count} work experiences"
      :education ->
        edu_count = length(get_in(section.content, ["education"]) || [])
        "#{edu_count} educational backgrounds"
      :skills ->
        skills_count = length(get_in(section.content, ["skills"]) || [])
        "#{skills_count} skills listed"
      _ ->
        "Portfolio section"
    end
  end

  # Section styling helper functions
  defp section_gradient_class(section_type) do
    case section_type do
      :intro -> "bg-gradient-to-r from-blue-600 to-cyan-600"
      :experience -> "bg-gradient-to-r from-green-600 to-teal-600"
      :education -> "bg-gradient-to-r from-purple-600 to-indigo-600"
      :skills -> "bg-gradient-to-r from-orange-600 to-red-600"
      :featured_project -> "bg-gradient-to-r from-pink-600 to-purple-600"
      :contact -> "bg-gradient-to-r from-gray-600 to-gray-800"
      _ -> "bg-gradient-to-r from-gray-600 to-gray-700"
    end
  end

  defp section_color_class(section_type) do
    case section_type do
      :intro -> "bg-blue-500"
      :experience -> "bg-green-500"
      :education -> "bg-purple-500"
      :skills -> "bg-orange-500"
      :featured_project -> "bg-pink-500"
      :contact -> "bg-gray-500"
      _ -> "bg-gray-400"
    end
  end

  defp section_type_label(section_type) do
    case section_type do
      :intro -> "Introduction"
      :experience -> "Work Experience"
      :education -> "Education"
      :skills -> "Skills & Expertise"
      :featured_project -> "Featured Project"
      :contact -> "Contact Information"
      :media_showcase -> "Media Showcase"
      :case_study -> "Case Study"
      _ -> String.capitalize(to_string(section_type))
    end
  end

  defp section_button_class(section_type) do
    case section_type do
      :intro -> "text-blue-600 border-blue-300 hover:bg-blue-600 focus:ring-blue-500"
      :experience -> "text-green-600 border-green-300 hover:bg-green-600 focus:ring-green-500"
      :education -> "text-purple-600 border-purple-300 hover:bg-purple-600 focus:ring-purple-500"
      :skills -> "text-orange-600 border-orange-300 hover:bg-orange-600 focus:ring-orange-500"
      :featured_project -> "text-pink-600 border-pink-300 hover:bg-pink-600 focus:ring-pink-500"
      _ -> "text-gray-600 border-gray-300 hover:bg-gray-600 focus:ring-gray-500"
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

  defp error_to_string(:too_large), do: "File is too large (max #{div(@socket.assigns.limits.max_media_size, 1_048_576)}MB)"
  defp error_to_string(:too_many_files), do: "Too many files selected (max 10)"
  defp error_to_string(:not_accepted), do: "Invalid file type. Supported: images, videos, audio, documents"
  defp error_to_string(:external_client_failure), do: "Upload failed, please try again"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

end
