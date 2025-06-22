# lib/frestyl_web/live/portfolio_live/edit/section_content_manager.ex - NEW FILE
defmodule FrestylWeb.PortfolioLive.Edit.SectionContentManager do
  @moduledoc """
  Manages content for different section types with proper CMS-like functionality
  """

  alias Frestyl.Portfolios
  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3]

  # ============================================================================
  # CONTACT SECTION MANAGEMENT
  # ============================================================================

  def handle_update_contact_field(socket, %{"field" => field, "value" => value, "section_id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      current_content = section.content || %{}

      # Handle nested social links
      updated_content = case field do
        "social_" <> social_platform ->
          social_links = Map.get(current_content, "social_links", %{})
          updated_social_links = Map.put(social_links, social_platform, value)
          Map.put(current_content, "social_links", updated_social_links)

        _ ->
          Map.put(current_content, field, value)
      end

      case Portfolios.update_section(section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)
          |> push_event("contact-field-updated", %{
            section_id: section_id_int,
            field: field,
            value: value
          })

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to update contact info: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_add_contact_method(socket, %{"section_id" => section_id, "method_type" => method_type}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      current_content = section.content || %{}
      contact_methods = Map.get(current_content, "contact_methods", [])

      new_method = %{
        "type" => method_type,
        "value" => "",
        "label" => get_default_contact_label(method_type),
        "primary" => false,
        "visible" => true
      }

      updated_methods = contact_methods ++ [new_method]
      updated_content = Map.put(current_content, "contact_methods", updated_methods)

      case Portfolios.update_section(section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)
          |> put_flash(:info, "Contact method added")

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to add contact method: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # ============================================================================
  # MEDIA SHOWCASE SECTION MANAGEMENT
  # ============================================================================

  def handle_update_media_showcase_settings(socket, %{"section_id" => section_id, "settings" => settings}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      current_content = section.content || %{}

      # Update media showcase specific settings
      updated_content = Map.merge(current_content, %{
        "gallery_layout" => Map.get(settings, "gallery_layout", "grid"),
        "show_captions" => Map.get(settings, "show_captions", true),
        "show_descriptions" => Map.get(settings, "show_descriptions", false),
        "enable_lightbox" => Map.get(settings, "enable_lightbox", true),
        "autoplay_videos" => Map.get(settings, "autoplay_videos", false),
        "grid_columns" => Map.get(settings, "grid_columns", "3"),
        "aspect_ratio" => Map.get(settings, "aspect_ratio", "16:9")
      })

      case Portfolios.update_section(section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)
          |> put_flash(:info, "Media showcase settings updated")
          |> push_event("media-showcase-updated", %{
            section_id: section_id_int,
            settings: settings
          })

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to update media showcase: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_update_media_caption(socket, %{"media_id" => media_id, "caption" => caption, "section_id" => section_id}) do
    media_id_int = String.to_integer(media_id)

    case Portfolios.get_portfolio_media(media_id_int) do
      nil ->
        {:noreply, put_flash(socket, :error, "Media not found")}

      media ->
        case Portfolios.update_portfolio_media(media, %{description: caption}) do
          {:ok, _updated_media} ->
            socket = socket
            |> put_flash(:info, "Caption updated")
            |> push_event("media-caption-updated", %{
              media_id: media_id_int,
              caption: caption
            })

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to update caption: #{format_errors(changeset)}")

            {:noreply, socket}
        end
    end
  end

  # ============================================================================
  # CASE STUDY SECTION MANAGEMENT
  # ============================================================================

  def handle_update_case_study_field(socket, %{"field" => field, "value" => value, "section_id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      current_content = section.content || %{}

      # Handle different case study field types
      updated_content = case field do
        "metrics_" <> metric_index ->
          update_case_study_metric(current_content, metric_index, value)

        "process_step_" <> step_index ->
          update_case_study_process_step(current_content, step_index, value)

        "technologies_used" ->
          # Convert comma-separated string to list
          tech_list = value
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          Map.put(current_content, "technologies_used", tech_list)

        _ ->
          Map.put(current_content, field, value)
      end

      case Portfolios.update_section(section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to update case study: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_add_case_study_metric(socket, %{"section_id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      current_content = section.content || %{}
      metrics = Map.get(current_content, "metrics", [])

      new_metric = %{
        "label" => "",
        "value" => "",
        "description" => "",
        "improvement" => true,
        "unit" => ""
      }

      updated_metrics = metrics ++ [new_metric]
      updated_content = Map.put(current_content, "metrics", updated_metrics)

      case Portfolios.update_section(section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)
          |> put_flash(:info, "Metric added")

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to add metric: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # ============================================================================
  # TESTIMONIAL SECTION MANAGEMENT
  # ============================================================================

  def handle_add_testimonial(socket, %{"section_id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      current_content = section.content || %{}
      testimonials = Map.get(current_content, "testimonials", [])

      new_testimonial = %{
        "quote" => "",
        "author_name" => "",
        "author_title" => "",
        "author_company" => "",
        "author_image" => "",
        "rating" => 5,
        "date" => Date.utc_today() |> Date.to_string(),
        "featured" => false,
        "project" => "",
        "relationship" => "client"
      }

      updated_testimonials = testimonials ++ [new_testimonial]
      updated_content = Map.put(current_content, "testimonials", updated_testimonials)

      case Portfolios.update_section(section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)
          |> put_flash(:info, "Testimonial added")

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to add testimonial: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_update_testimonial_field(socket, %{"field" => field, "value" => value, "index" => index, "section_id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    testimonial_index = String.to_integer(index)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      current_content = section.content || %{}
      testimonials = Map.get(current_content, "testimonials", [])

      if testimonial_index >= 0 and testimonial_index < length(testimonials) do
        updated_testimonials = List.update_at(testimonials, testimonial_index, fn testimonial ->
          case field do
            "rating" ->
              Map.put(testimonial, field, String.to_integer(value))
            "featured" ->
              Map.put(testimonial, field, value == "true")
            _ ->
              Map.put(testimonial, field, value)
          end
        end)

        updated_content = Map.put(current_content, "testimonials", updated_testimonials)

        case Portfolios.update_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = Enum.map(sections, fn s ->
              if s.id == section_id_int, do: updated_section, else: s
            end)

            socket = socket
            |> assign(:sections, updated_sections)
            |> maybe_update_editing_section(updated_sections, section_id_int)

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to update testimonial: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid testimonial index")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # ============================================================================
  # PROJECTS SECTION MANAGEMENT
  # ============================================================================

  def handle_add_project(socket, %{"section_id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      current_content = section.content || %{}
      projects = Map.get(current_content, "projects", [])

      new_project = %{
        "title" => "",
        "description" => "",
        "role" => "",
        "client" => "",
        "duration" => "",
        "status" => "completed",
        "technologies" => [],
        "key_features" => [],
        "challenges" => "",
        "solutions" => "",
        "results" => "",
        "demo_url" => "",
        "github_url" => "",
        "case_study_url" => "",
        "featured" => false,
        "category" => "web_development",
        "team_size" => 1,
        "start_date" => "",
        "end_date" => ""
      }

      updated_projects = projects ++ [new_project]
      updated_content = Map.put(current_content, "projects", updated_projects)

      case Portfolios.update_section(section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)
          |> put_flash(:info, "Project added")

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to add project: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_update_project_field(socket, %{"field" => field, "value" => value, "index" => index, "section_id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    project_index = String.to_integer(index)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      current_content = section.content || %{}
      projects = Map.get(current_content, "projects", [])

      if project_index >= 0 and project_index < length(projects) do
        updated_projects = List.update_at(projects, project_index, fn project ->
          case field do
            "technologies" ->
              # Convert comma-separated string to list
              tech_list = value
              |> String.split(",")
              |> Enum.map(&String.trim/1)
              |> Enum.reject(&(&1 == ""))
              Map.put(project, field, tech_list)

            "key_features" ->
              # Convert newline-separated string to list
              features_list = value
              |> String.split("\n")
              |> Enum.map(&String.trim/1)
              |> Enum.reject(&(&1 == ""))
              Map.put(project, field, features_list)

            "featured" ->
              Map.put(project, field, value == "true")

            "team_size" ->
              Map.put(project, field, String.to_integer(value))

            _ ->
              Map.put(project, field, value)
          end
        end)

        updated_content = Map.put(current_content, "projects", updated_projects)

        case Portfolios.update_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            updated_sections = Enum.map(sections, fn s ->
              if s.id == section_id_int, do: updated_section, else: s
            end)

            socket = socket
            |> assign(:sections, updated_sections)
            |> maybe_update_editing_section(updated_sections, section_id_int)

            {:noreply, socket}

          {:error, changeset} ->
            socket = socket
            |> put_flash(:error, "Failed to update project: #{format_errors(changeset)}")

            {:noreply, socket}
        end
      else
        {:noreply, put_flash(socket, :error, "Invalid project index")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # ============================================================================
  # ACHIEVEMENTS SECTION MANAGEMENT
  # ============================================================================

  def handle_add_achievement(socket, %{"section_id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      current_content = section.content || %{}
      achievements = Map.get(current_content, "achievements", [])

      new_achievement = %{
        "title" => "",
        "description" => "",
        "date" => Date.utc_today() |> Date.to_string(),
        "organization" => "",
        "category" => "professional",
        "level" => "recognition",
        "verification_url" => "",
        "skills_demonstrated" => [],
        "impact" => "",
        "featured" => false
      }

      updated_achievements = achievements ++ [new_achievement]
      updated_content = Map.put(current_content, "achievements", updated_achievements)

      case Portfolios.update_section(section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)
          |> put_flash(:info, "Achievement added")

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to add achievement: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # ============================================================================
  # CODE SHOWCASE SECTION MANAGEMENT
  # ============================================================================

  def handle_update_code_showcase(socket, %{"section_id" => section_id, "code_data" => code_data}) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      current_content = section.content || %{}

      updated_content = Map.merge(current_content, %{
        "code" => Map.get(code_data, "code", ""),
        "language" => Map.get(code_data, "language", "javascript"),
        "explanation" => Map.get(code_data, "explanation", ""),
        "key_concepts" => Map.get(code_data, "key_concepts", []),
        "complexity" => Map.get(code_data, "complexity", "intermediate"),
        "execution_time" => Map.get(code_data, "execution_time", ""),
        "memory_usage" => Map.get(code_data, "memory_usage", ""),
        "github_gist" => Map.get(code_data, "github_gist", ""),
        "runnable" => Map.get(code_data, "runnable", false),
        "test_cases" => Map.get(code_data, "test_cases", [])
      })

      case Portfolios.update_section(section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> maybe_update_editing_section(updated_sections, section_id_int)
          |> put_flash(:info, "Code showcase updated")
          |> push_event("code-showcase-updated", %{
            section_id: section_id_int,
            language: Map.get(code_data, "language")
          })

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to update code showcase: #{format_errors(changeset)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # ============================================================================
  # SECTION CAPABILITIES & PERMISSIONS
  # ============================================================================

  def get_section_capabilities(section_type) do
    case section_type do
      "intro" -> %{
        supports_media: false,
        supports_links: true,
        max_entries: 1,
        required_fields: ["headline"],
        optional_fields: ["summary", "location", "social_links"]
      }

      "experience" -> %{
        supports_media: true,
        supports_links: true,
        max_entries: :unlimited,
        required_fields: ["jobs"],
        optional_fields: ["summary"]
      }

      "education" -> %{
        supports_media: true,
        supports_links: true,
        max_entries: :unlimited,
        required_fields: ["education"],
        optional_fields: ["summary"]
      }

      "skills" -> %{
        supports_media: false,
        supports_links: false,
        max_entries: :unlimited,
        required_fields: ["skills"],
        optional_fields: ["skill_categories", "proficiency_levels"]
      }

      "projects" -> %{
        supports_media: true,
        supports_links: true,
        max_entries: :unlimited,
        required_fields: ["projects"],
        optional_fields: ["featured_count", "categories"]
      }

      "featured_project" -> %{
        supports_media: true,
        supports_links: true,
        max_entries: 1,
        required_fields: ["title", "description"],
        optional_fields: ["technologies", "demo_url", "github_url"]
      }

      "case_study" -> %{
        supports_media: true,
        supports_links: true,
        max_entries: 1,
        required_fields: ["problem_statement", "solution"],
        optional_fields: ["metrics", "process", "technologies_used"]
      }

      "media_showcase" -> %{
        supports_media: true,
        supports_links: false,
        max_entries: :unlimited,
        required_fields: [],
        optional_fields: ["gallery_layout", "captions", "categories"]
      }

      "testimonial" -> %{
        supports_media: true,
        supports_links: false,
        max_entries: :unlimited,
        required_fields: ["testimonials"],
        optional_fields: ["featured_count", "display_format"]
      }

      "achievements" -> %{
        supports_media: true,
        supports_links: true,
        max_entries: :unlimited,
        required_fields: ["achievements"],
        optional_fields: ["categories", "verification"]
      }

      "code_showcase" -> %{
        supports_media: false,
        supports_links: true,
        max_entries: 1,
        required_fields: ["code", "language"],
        optional_fields: ["explanation", "test_cases"]
      }

      "contact" -> %{
        supports_media: false,
        supports_links: true,
        max_entries: 1,
        required_fields: [],
        optional_fields: ["email", "phone", "social_links", "contact_methods"]
      }

      "custom" -> %{
        supports_media: true,
        supports_links: true,
        max_entries: :unlimited,
        required_fields: [],
        optional_fields: ["custom_fields"]
      }

      _ -> %{
        supports_media: false,
        supports_links: false,
        max_entries: 1,
        required_fields: [],
        optional_fields: []
      }
    end
  end

  def section_supports_media?(section_type) do
    capabilities = get_section_capabilities(section_type)
    Map.get(capabilities, :supports_media, false)
  end

  def get_default_content_for_section_type(section_type) do
    case section_type do
      "contact" -> %{
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
          "twitter" => "",
          "website" => ""
        },
        "contact_methods" => [],
        "contact_form_enabled" => true,
        "show_calendar_link" => false,
        "calendar_url" => ""
      }

      "media_showcase" -> %{
        "title" => "Media Gallery",
        "description" => "A curated collection of visual work and demonstrations",
        "gallery_layout" => "grid",
        "grid_columns" => "3",
        "show_captions" => true,
        "show_descriptions" => false,
        "enable_lightbox" => true,
        "autoplay_videos" => false,
        "aspect_ratio" => "16:9",
        "media_categories" => [],
        "featured_media" => []
      }

      "case_study" -> %{
        "client" => "",
        "project_title" => "",
        "overview" => "",
        "problem_statement" => "",
        "approach" => "",
        "process" => [],
        "technologies_used" => [],
        "challenges" => "",
        "solutions" => "",
        "results" => "",
        "metrics" => [],
        "learnings" => "",
        "next_steps" => "",
        "timeline" => "",
        "team_size" => 1,
        "role" => ""
      }

      "testimonial" -> %{
        "testimonials" => [],
        "display_format" => "cards",
        "show_ratings" => true,
        "show_photos" => true,
        "auto_rotate" => false,
        "featured_count" => 3
      }

      "achievements" -> %{
        "achievements" => [],
        "categories" => ["Professional", "Academic", "Personal"],
        "show_verification" => true,
        "group_by_category" => false
      }

      "code_showcase" -> %{
        "title" => "Code Example",
        "description" => "",
        "code" => "",
        "language" => "javascript",
        "explanation" => "",
        "key_concepts" => [],
        "complexity" => "intermediate",
        "execution_time" => "",
        "memory_usage" => "",
        "github_gist" => "",
        "runnable" => false,
        "test_cases" => []
      }

      _ -> %{}
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp maybe_update_editing_section(socket, updated_sections, section_id) do
    case socket.assigns[:editing_section] do
      %{id: ^section_id} ->
        updated_section = Enum.find(updated_sections, &(&1.id == section_id))
        assign(socket, :editing_section, updated_section)
      _ ->
        socket
    end
  end

  defp get_default_contact_label(method_type) do
    case method_type do
      "email" -> "Email"
      "phone" -> "Phone"
      "whatsapp" -> "WhatsApp"
      "telegram" -> "Telegram"
      "linkedin" -> "LinkedIn"
      "twitter" -> "Twitter"
      "website" -> "Website"
      "calendar" -> "Schedule a Call"
      _ -> String.capitalize(method_type)
    end
  end

  defp update_case_study_metric(content, metric_index, value) do
    metrics = Map.get(content, "metrics", [])
    index = String.to_integer(metric_index)

    if index >= 0 and index < length(metrics) do
      updated_metrics = List.update_at(metrics, index, fn metric ->
        # Parse the field from the value (assuming format: "field:value")
        case String.split(value, ":", parts: 2) do
          [field, field_value] -> Map.put(metric, field, field_value)
          _ -> metric
        end
      end)
      Map.put(content, "metrics", updated_metrics)
    else
      content
    end
  end

  defp update_case_study_process_step(content, step_index, value) do
    process_steps = Map.get(content, "process", [])
    index = String.to_integer(step_index)

    if index >= 0 and index < length(process_steps) do
      updated_steps = List.replace_at(process_steps, index, value)
      Map.put(content, "process", updated_steps)
    else
      content
    end
  end

  defp format_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end
end
