# lib/frestyl_web/live/portfolio_live/edit.ex - Part 1
defmodule FrestylWeb.PortfolioLive.Edit do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.{Portfolio, PortfolioSection, PortfolioTemplates}
  alias FrestylWeb.PortfolioLive.VideoIntroComponent

  def mount(%{"id" => id}, _session, socket) do
    portfolio = Portfolios.get_portfolio!(id)
    sections = Portfolios.list_portfolio_sections(id)
    limits = Portfolios.get_portfolio_limits(socket.assigns.current_user)

    # Ensure user owns this portfolio
    if portfolio.user_id != socket.assigns.current_user.id do
      {:ok,
      socket
      |> put_flash(:error, "You don't have permission to edit this portfolio.")
      |> push_navigate(to: "/portfolios")}
    else
      form = Portfolios.change_portfolio(portfolio, %{}) |> to_form()

      # Load customization with proper defaults
      default_customization = PortfolioTemplates.get_template_config(portfolio.theme || "executive")
      current_customization = portfolio.customization || default_customization
      normalized_customization = normalize_customization(current_customization)

      socket =
        socket
        |> assign(:page_title, "Edit #{portfolio.title}")
        |> assign(:portfolio, portfolio)
        |> assign(:sections, sections)
        |> assign(:form, to_form(Portfolios.change_portfolio(portfolio)))
        |> assign(:customization, normalized_customization)
        |> assign(:available_templates, PortfolioTemplates.available_templates())
        |> assign(:limits, %{
            max_media_size_mb: limits.max_media_size_mb || 50,
            max_media_size: limits.max_media_size_mb * 1_048_576 || 52_428_800
          })
        |> allow_upload(:resume,
            accept: ~w(.pdf .doc .docx .txt),
            max_entries: 1,
            max_file_size: 10 * 1_048_576) # 10MB
        |> assign(:active_tab, :overview)
        |> assign(:section_edit_id, nil)
        |> assign(:show_preview, false)
        |> assign(:preview_device, :desktop)
        |> assign(:unsaved_changes, false)
        |> assign(:show_video_intro_modal, false)
        |> allow_upload(:media,
            accept: [
              # Images
              "image/jpeg", "image/png", "image/gif",
              # Videos
              "video/mp4", "video/quicktime", "video/webm",
              # Audio
              "audio/mpeg", "audio/wav", "audio/ogg",
              # Documents
              "application/pdf",
              "application/msword",
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            ],
            max_entries: 10,
            max_file_size: limits.max_media_size_mb * 1_048_576,
            auto_upload: false)
        |> assign(:show_resume_import_modal, false)
        |> assign(:parsed_resume_data, nil)
        |> assign(:resume_parsing_state, :idle)
        |> assign(:resume_error_message, nil)
        |> assign(:section_mappings, %{})
        |> allow_upload(:resume,
            accept: ~w(.pdf .doc .docx),
            max_entries: 1,
            max_file_size: 10_000_000)
        |> allow_upload(:media,
            accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .pdf .doc .docx),
            max_entries: 10,
            max_file_size: 50_000_000)


      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "overview"
    section_id = params["section_id"]

    socket =
      socket
      |> assign(:active_tab, String.to_atom(tab))
      |> assign(:section_edit_id, section_id)

    {:noreply, socket}
  end

  # Portfolio Edit LiveView - Part 2: Basic Event Handlers

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    tab_atom = String.to_existing_atom(tab)

    # Warn about unsaved changes if switching away from sections tab
    if socket.assigns.unsaved_changes and socket.assigns.active_tab == :sections and tab_atom != :sections do
      {:noreply,
       socket
       |> put_flash(:warning, "You have unsaved changes in the sections tab.")
       |> assign(active_tab: tab_atom)}
    else
      {:noreply, assign(socket, active_tab: tab_atom)}
    end
  end

  # Add this function to your edit.ex file (after the existing handle_event functions):

  @impl true
  def handle_event("update_portfolio", %{"portfolio" => portfolio_params}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, portfolio} ->
        form = Portfolios.change_portfolio(portfolio, %{}) |> to_form()

        flash_message = if portfolio_params["slug"] && portfolio_params["slug"] != socket.assigns.portfolio.slug do
          "Portfolio updated! Your new URL is: #{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}"
        else
          "Portfolio updated successfully."
        end

        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:form, form)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, flash_message)}

      {:error, changeset} ->
        form = changeset |> to_form(action: :validate)
        {:noreply, assign(socket, form: form)}
    end
  end

  @impl true
  def handle_event("validate_portfolio", %{"portfolio" => portfolio_params}, socket) do
    changeset =
      socket.assigns.portfolio
      |> Portfolios.change_portfolio(portfolio_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("update_color", %{"color" => color_value, "name" => color_name}, socket) do
    IO.puts("Color update event: #{color_name} = #{color_value}")

    # Use the SAME structure as templates - just update "primary_color" at root level
    current_customization = stringify_keys(socket.assigns.customization || %{})
    updated_customization = Map.put(current_customization, "primary_color", color_value)

    IO.puts("Updated customization: #{inspect(updated_customization)}")

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> put_flash(:info, "Color updated to #{color_name}!")}

      {:error, changeset} ->
        IO.puts("Color update failed: #{inspect(changeset.errors)}")
        {:noreply, put_flash(socket, :error, "Failed to update color")}
    end
  end

  # Update your helper function to check for primary_color instead of nested structure:
  defp get_current_primary_color(customization) do
    normalized = stringify_keys(customization || %{})
    # Check template structure first
    Map.get(normalized, "primary_color", "#6366f1")
  end

  @impl true
  def handle_event("select_template", %{"template" => template}, socket) do
    IO.puts("Template selection event received: #{template}")

    template_config = PortfolioTemplates.get_template_config(template)
    IO.puts("Template config loaded: #{inspect(template_config)}")

    # FORCE template config to use string keys ONLY
    normalized_config = stringify_keys(template_config)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{
      theme: template,
      customization: normalized_config
    }) do
      {:ok, portfolio} ->
        IO.puts("Portfolio updated successfully with template: #{template}")

        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, normalized_config)
        |> put_flash(:info, "Template '#{template}' applied successfully!")}

      {:error, changeset} ->
        IO.puts("Template update failed: #{inspect(changeset.errors)}")
        {:noreply, put_flash(socket, :error, "Failed to update template")}
    end
  end

  @impl true
  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, !socket.assigns.show_preview)}
  end

  @impl true
  def handle_event("change_preview_device", %{"device" => device}, socket) do
    device_atom = String.to_atom(device)
    {:noreply, assign(socket, :preview_device, device_atom)}
  end

  # Portfolio Edit LiveView - Part 3: Video Intro and Section Management Events

  # Video intro events
  @impl true
  def handle_event("show_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_intro_modal, true)}
  end

  @impl true
  def handle_event("hide_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_intro_modal, false)}
  end

  # Handle escape key in video modal:
  @impl true
  def handle_event("video_modal_escape", _params, socket) do
    {:noreply, assign(socket, :show_video_intro_modal, false)}
  end

  # Resume parsing
  def handle_event("hide_resume_import", _params, socket) do
    socket =
      socket
      |> assign(:show_resume_import_modal, false)
      |> assign(:parsed_resume_data, nil)
      |> assign(:resume_parsing_state, :idle)
      |> assign(:resume_error_message, nil)

    {:noreply, socket}
  end

  def handle_event("upload_resume", _params, socket) do
    # Check if file was uploaded
    if socket.assigns.uploads.resume.entries == [] do
      socket =
        socket
        |> assign(:resume_parsing_state, :error)
        |> assign(:resume_error_message, "Please select a file to upload")

      {:noreply, socket}
    else
      socket = assign(socket, :resume_parsing_state, :parsing)

      # Process the uploaded file
      uploaded_files = upload_and_consume_files(socket, :resume)

      case uploaded_files do
        [{file_path, _original_filename}] ->
          # Parse the resume file in a separate process to avoid blocking
          Task.start(fn ->
            case Frestyl.ResumeParser.parse_resume(file_path) do
              {:ok, parsed_data} ->
                send(self(), {:resume_parsed, parsed_data})

              {:error, reason} ->
                send(self(), {:resume_parse_error, reason})
            end

            # Clean up temporary file
            File.rm(file_path)
          end)

          {:noreply, socket}

        [] ->
          socket =
            socket
            |> assign(:resume_parsing_state, :error)
            |> assign(:resume_error_message, "No file was uploaded")

          {:noreply, socket}

        {:error, reason} ->
          socket =
            socket
            |> assign(:resume_parsing_state, :error)
            |> assign(:resume_error_message, "Upload failed: #{reason}")

          {:noreply, socket}
      end
    end
  end

  # Handle file validation
  def handle_event("validate_resume", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("import_resume_sections", params, socket) do
    portfolio = socket.assigns.portfolio
    parsed_data = socket.assigns.parsed_resume_data

    # Extract section mappings from form data (if any)
    section_mappings = Map.get(params, "mapping", %{})

    # Create sections based on parsed data
    case create_sections_from_resume_data(portfolio, parsed_data, section_mappings) do
      {:ok, created_sections} ->
        # Reload the portfolio with new sections
        updated_portfolio = Portfolios.get_portfolio!(portfolio.id)
        updated_sections = Portfolios.list_portfolio_sections(portfolio.id)

        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:sections, updated_sections)
          |> assign(:show_resume_import_modal, false)
          |> assign(:parsed_resume_data, nil)
          |> assign(:resume_parsing_state, :idle)
          |> put_flash(:info, "Successfully imported #{length(created_sections)} sections from resume!")

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to import sections: #{reason}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_resume_import", _params, socket) do
    IO.inspect("=== BEFORE ASSIGN ===")
    IO.inspect(socket.assigns, label: "Current assigns")

    try do
      updated_socket = assign(socket, :show_resume_import_modal, true)
      IO.inspect("=== AFTER ASSIGN ===")
      IO.inspect(updated_socket.assigns.show_resume_import_modal, label: "New assign value")

      {:noreply, updated_socket}
    rescue
      error ->
        IO.inspect(error, label: "ERROR in handle_event")
        {:noreply, put_flash(socket, :error, "Failed to show import modal")}
    end
  end

  @impl true
  def handle_event("process_resume", _params, socket) do
    case uploaded_entries(socket, :resume) do
      {[entry], _} ->
        # Process the resume file
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          process_resume_file(socket, path, entry.client_name)
        end)

      _ ->
        {:noreply, put_flash(socket, :error, "Please upload a resume file.")}
    end
  end

  def handle_info({:resume_parsed, parsed_data}, socket) do
    socket =
      socket
      |> assign(:parsed_resume_data, parsed_data)
      |> assign(:resume_parsing_state, :parsed)

    {:noreply, socket}
  end

  def handle_info({:resume_parse_error, reason}, socket) do
    socket =
      socket
      |> assign(:resume_parsing_state, :error)
      |> assign(:resume_error_message, reason)

    {:noreply, socket}
  end

  # Helper function to upload and consume files:
  defp upload_and_consume_files(socket, upload_name) do
    uploaded_files =
      consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
        # Create a temporary file with the original extension
        temp_dir = System.tmp_dir!()
        file_extension = Path.extname(entry.client_name)
        temp_filename = "resume_#{System.unique_integer()}_#{entry.client_name}"
        temp_path = Path.join(temp_dir, temp_filename)

        # Copy the uploaded file to temp location
        case File.cp(path, temp_path) do
          :ok -> {:ok, {temp_path, entry.client_name}}
          {:error, reason} -> {:error, reason}
        end
      end)

    case uploaded_files do
      [file_info] -> file_info
      [] -> []
      multiple -> List.first(multiple) # Take first file if multiple
    end
  end

  defp parse_resume_file(%{"path" => path}) do
    # This is a placeholder - you'll need to implement actual resume parsing
    # For now, return mock data
    {:ok, %{
      "experience" => "Software Engineer at Company XYZ...",
      "education" => "Bachelor of Science in Computer Science...",
      "skills" => "JavaScript, Elixir, Phoenix, React..."
    }}
  end

  def handle_info(:mock_parse_complete, socket) do
    # Mock parsed data
    mock_data = %{
      "professional_summary" => "Experienced software engineer with 5+ years developing web applications using modern technologies including React, Node.js, and Python.",
      "work_experience" => "Software Engineer at TechCorp (2020-2025): Led development of customer-facing web applications, improved system performance by 40%.",
      "education" => "Bachelor of Science in Computer Science, State University (2016-2020). GPA: 3.8/4.0",
      "skills" => "JavaScript, Python, React, Node.js, PostgreSQL, AWS, Docker, Git",
      "certifications" => "AWS Certified Developer Associate, Google Cloud Professional"
    }

    socket =
      socket
      |> assign(:parsed_resume_data, mock_data)
      |> assign(:resume_parsing_state, :parsed)

    {:noreply, socket}
  end

  defp create_default_mappings(parsed_data) do
    # Create default section mappings
    Enum.reduce(parsed_data, %{}, fn {section_type, _content}, acc ->
      Map.put(acc, section_type, "new")
    end)
  end

  defp import_sections_to_portfolio(portfolio, parsed_data, params) do
    # This is a placeholder - implement the actual import logic
    # You'll want to create new portfolio sections based on the parsed data
    {:ok, portfolio}
  end


  # Add this helper function:
  defp process_resume_file(socket, file_path, filename) do
    # Simple text extraction for demo - in production you'd use AI/ML
    parsed_data = extract_resume_data(file_path, filename)

    socket =
      socket
      |> assign(:parsed_resume_data, parsed_data)
      |> assign(:show_resume_import_modal, true)

    {:noreply, socket}
  end

  defp extract_resume_data(_file_path, _filename) do
    # Mock data - replace with actual parsing logic
    %{
      personal_info: %{
        name: "John Doe",
        email: "john.doe@example.com",
        phone: "555-123-4567",
        location: "New York, NY"
      },
      experience: [
        %{
          title: "Senior Developer",
          company: "Tech Corp",
          start_date: "2020-01",
          end_date: "Present",
          description: "Led development team on various projects"
        }
      ],
      education: [
        %{
          degree: "Bachelor of Science",
          field: "Computer Science",
          school: "University of Example",
          graduation_year: "2019"
        }
      ],
      skills: ["JavaScript", "Python", "React", "Node.js"],
      unknown_sections: [
        %{
          title: "Certifications",
          content: "AWS Certified Developer, Google Cloud Professional"
        },
        %{
          title: "Languages",
          content: "English (Native), Spanish (Fluent)"
        }
      ]
    }
  end

  defp create_section_from_resume_data(portfolio_id, section_type, data) do
    # Map resume data to portfolio section format
    section_attrs = case section_type do
      "contact" ->
        %{
          title: "Contact Information",
          section_type: :contact,
          content: %{
            "email" => data["email"],
            "phone" => data["phone"],
            "location" => data["location"]
          }
        }

      "experience" ->
        %{
          title: "Work Experience",
          section_type: :experience,
          content: %{"jobs" => data}
        }

      "education" ->
        %{
          title: "Education",
          section_type: :education,
          content: %{"education" => data}
        }

      "skills" ->
        %{
          title: "Skills & Expertise",
          section_type: :skills,
          content: %{"skills" => data}
        }

      "custom" ->
        %{
          title: data["title"] || "Additional Information",
          section_type: :custom,
          content: %{"content" => data["content"]}
        }
    end

    section_attrs = Map.merge(section_attrs, %{
      portfolio_id: portfolio_id,
      position: get_next_section_position(portfolio_id),
      visible: true
    })

    Portfolios.create_section(section_attrs)
  end

  defp get_next_section_position(portfolio_id) do
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    case sections do
      [] -> 1
      sections -> Enum.max_by(sections, & &1.position).position + 1
    end
  end

  defp extract_section_mappings(params) do
    # Extract mapping data from form params
    # params will contain something like %{"mapping" => %{"experience" => "new", "education" => "skip"}}
    Map.get(params, "mapping", %{})
  end

  defp create_sections_from_resume_data(portfolio, parsed_data, section_mappings) do
    created_sections = []

    # Get current max position
    existing_sections = Portfolios.list_portfolio_sections(portfolio.id)
    max_position = case existing_sections do
      [] -> 0
      sections -> Enum.map(sections, & &1.position) |> Enum.max()
    end

    results =
      Enum.reduce(parsed_data, {:ok, created_sections, max_position}, fn
        {section_type, content}, {:ok, acc, position} ->
          mapping = Map.get(section_mappings, to_string(section_type), "new")

          case mapping do
            "skip" ->
              {:ok, acc, position}

            "new" ->
              case create_portfolio_section_from_resume_data(portfolio, section_type, content, position + 1) do
                {:ok, section} -> {:ok, [section | acc], position + 1}
                {:error, reason} -> {:error, reason}
              end

            _existing_section_id ->
              # For now, just create new sections. Later you can implement merging
              case create_portfolio_section_from_resume_data(portfolio, section_type, content, position + 1) do
                {:ok, section} -> {:ok, [section | acc], position + 1}
                {:error, reason} -> {:error, reason}
              end
          end

        {_section_type, _content}, {:error, reason} ->
          {:error, reason}
      end)

    case results do
      {:ok, sections, _final_position} -> {:ok, Enum.reverse(sections)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_portfolio_section_from_resume_data(portfolio, section_type, content, position) do
    # Map resume section types to your portfolio section types
    {portfolio_section_type, section_title} = map_resume_section_type(section_type)

    # Format content according to your schema
    formatted_content = format_resume_content_for_section(portfolio_section_type, content)

    section_attrs = %{
      portfolio_id: portfolio.id,
      title: section_title,
      section_type: portfolio_section_type,
      content: formatted_content,
      position: position,
      visible: true
    }

    # Use your existing context function
    Portfolios.create_section(section_attrs)
  end

  defp format_section_title(section_type) do
    section_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp map_resume_section_type(resume_section_type) do
    case to_string(resume_section_type) do
      "professional_summary" -> {:intro, "Professional Summary"}
      "work_experience" -> {:experience, "Work Experience"}
      "education" -> {:education, "Education"}
      "skills" -> {:skills, "Skills"}
      "certifications" -> {:achievements, "Certifications"}
      "projects" -> {:projects, "Projects"}
      _ -> {:custom, format_section_title(resume_section_type)}
    end
  end

  defp format_resume_content_for_section(section_type, raw_content) do
    case section_type do
      :intro ->
        %{
          "headline" => "Professional Summary",
          "summary" => to_string(raw_content),
          "location" => "",
          "website" => "",
          "social_links" => %{},
          "availability" => "",
          "call_to_action" => ""
        }

      :experience ->
        # Try to parse work experience into structured format
        jobs = parse_work_experience(raw_content)
        %{"jobs" => jobs}

      :education ->
        # Try to parse education into structured format
        education = parse_education(raw_content)
        %{"education" => education}

      :skills ->
        # Parse skills - could be comma-separated or structured
        skills = parse_skills(raw_content)
        %{"skills" => skills}

      :achievements ->
        # Parse certifications/achievements
        achievements = parse_achievements(raw_content)
        %{"achievements" => achievements}

      :projects ->
        # Parse projects if any
        projects = parse_projects(raw_content)
        %{"projects" => projects}

      :custom ->
        %{
          "title" => "",
          "content" => to_string(raw_content),
          "layout" => "default",
          "custom_fields" => %{}
        }

      _ ->
        # Fallback for any other section type
        %{"description" => to_string(raw_content)}
    end
  end

  defp parse_work_experience(content) do
    # For now, create a single job entry with the content
    # Later you could use AI/NLP to extract multiple jobs
    [%{
      "company" => "",
      "position" => "",
      "start_date" => "",
      "end_date" => "",
      "description" => to_string(content),
      "highlights" => [],
      "technologies" => []
    }]
  end

  defp parse_education(content) do
    # Create a single education entry
    [%{
      "school" => "",
      "degree" => "",
      "field" => "",
      "start_date" => "",
      "end_date" => "",
      "gpa" => "",
      "description" => to_string(content),
      "highlights" => []
    }]
  end

  defp parse_skills(content) do
    content_str = to_string(content)

    if String.contains?(content_str, ",") do
      # Parse comma-separated skills
      content_str
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn skill ->
        %{
          "name" => skill,
          "level" => "intermediate",
          "category" => "general"
        }
      end)
    else
      # Single skill or paragraph - create one entry
      [%{
        "name" => content_str,
        "level" => "intermediate",
        "category" => "general"
      }]
    end
  end

  defp parse_achievements(content) do
    # Create a single achievement entry
    [%{
      "title" => "Certification",
      "description" => to_string(content),
      "date" => "",
      "issuer" => "",
      "credential_id" => "",
      "credential_url" => ""
    }]
  end

  defp parse_projects(content) do
    # Create a single project entry
    [%{
      "title" => "Project",
      "description" => to_string(content),
      "technologies" => [],
      "role" => "",
      "start_date" => "",
      "end_date" => "",
      "url" => "",
      "github_url" => ""
    }]
  end


  defp get_next_section_order(portfolio) do
    # Get the highest order number and add 1
    case Portfolios.get_portfolio_sections(portfolio.id) do
      [] -> 1
      sections ->
        max_order = Enum.map(sections, & &1.order) |> Enum.max()
        max_order + 1
    end
  end

  defp update_existing_section_with_resume_data(section_id, content) do
    # Implement if you want to support merging with existing sections
    {:error, "Merging with existing sections not implemented yet"}
  end

  @impl true
  def handle_info({:close_video_modal, _}, socket) do
    {:noreply, assign(socket, :show_video_intro_modal, false)}
  end

  @impl true
  def handle_info({:video_intro_complete, data}, socket) do
    {:noreply,
    socket
    |> assign(:show_video_intro_modal, false)
    |> put_flash(:info, "Video introduction saved successfully!")}
  end

  # Catch-all for unhandled messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:video_intro_complete, %{"media_file_id" => media_file_id, "file_path" => file_path}}, socket) do
    {:noreply,
     socket
     |> assign(:show_video_intro_modal, false)
     |> put_flash(:info, "Video introduction saved! You can now view it in your portfolio.")}
  end

  # Section management events
  @impl true
  def handle_event("add_section", %{"type" => section_type}, socket) do
    section_attrs = %{
      portfolio_id: socket.assigns.portfolio.id,
      title: get_default_section_title(section_type),
      section_type: String.to_atom(section_type),
      position: length(socket.assigns.sections) + 1,
      content: PortfolioSection.default_content_for_type(String.to_atom(section_type)),
      visible: true
    }

    case Portfolios.create_section(section_attrs) do
      {:ok, _section} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

        {:noreply,
         socket
         |> assign(:sections, sections)
         |> assign(:unsaved_changes, true)
         |> put_flash(:info, "Section added successfully.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add section.")}
    end
  end

  @impl true
  def handle_event("edit_section", %{"id" => section_id}, socket) do
    {:noreply,
     socket
     |> assign(:section_edit_id, section_id)
     |> assign(:active_tab, :sections)
     |> push_patch(to: "/portfolios/#{socket.assigns.portfolio.id}/edit?tab=sections&section_id=#{section_id}")}
  end

  @impl true
  def handle_event("delete_section", %{"id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    section = Portfolios.get_section!(section_id_int)

    case Portfolios.delete_section(section) do
      {:ok, _section} ->
        updated_sections = Enum.reject(socket.assigns.sections, &(&1.id == section_id_int))

        {:noreply,
         socket
         |> assign(sections: updated_sections)
         |> assign(:unsaved_changes, true)
         |> put_flash(:info, "Section deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete section")}
    end
  end

  @impl true
  def handle_event("toggle_section_visibility", %{"id" => section_id}, socket) do
    section = Portfolios.get_section!(section_id)

    case Portfolios.update_section(section, %{"visible" => !section.visible}) do
      {:ok, _updated_section} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

        {:noreply,
         socket
         |> assign(:sections, sections)
         |> assign(:unsaved_changes, true)
         |> put_flash(:info, "Section visibility updated.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update section visibility.")}
    end
  end

  @impl true
  def handle_event("reorder_sections", %{"sections" => section_order}, socket) do
    # Update section positions based on new order
    Enum.with_index(section_order, 1)
    |> Enum.each(fn {section_id_str, position} ->
      section_id = String.to_integer(section_id_str)
      section = Portfolios.get_section!(section_id)
      Portfolios.update_section(section, %{"position" => position})
    end)

    sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

    {:noreply,
     socket
     |> assign(:sections, sections)
     |> assign(:unsaved_changes, true)
     |> put_flash(:info, "Section order updated.")}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    IO.puts("Validating upload...")

    errors = []

    # Check each uploaded entry
    upload_errors = for entry <- socket.assigns.uploads.media.entries do
      cond do
        entry.client_size > socket.assigns.limits.max_media_size ->
          "File #{entry.client_name} is too large (max #{socket.assigns.limits.max_media_size_mb}MB)"

        not valid_media_type?(entry.client_type) ->
          "File #{entry.client_name} has unsupported format"

        true ->
          nil
      end
    end
    |> Enum.filter(&(!is_nil(&1)))

    if length(upload_errors) > 0 do
      {:noreply, put_flash(socket, :error, Enum.join(upload_errors, ", "))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("upload_media", %{"section_id" => section_id}, socket) do
    IO.puts("Upload media event for section: #{section_id}")

    section = Portfolios.get_section!(section_id)

    # Verify section belongs to this portfolio
    if section.portfolio_id == socket.assigns.portfolio.id do
      # Process uploads
      uploaded_files = consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
        upload_media_file(path, entry, section, socket.assigns.portfolio)
      end)

      case uploaded_files do
        [] ->
          {:noreply, put_flash(socket, :error, "No files were uploaded")}

        files when length(files) > 0 ->
          success_count = Enum.count(files, fn
            {:ok, _} -> true
            _ -> false
          end)

          error_count = length(files) - success_count

          # Refresh sections to show new media
          sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

          socket = assign(socket, :sections, sections)

          cond do
            success_count > 0 and error_count == 0 ->
              {:noreply, put_flash(socket, :info, "#{success_count} file(s) uploaded successfully!")}

            success_count > 0 and error_count > 0 ->
              {:noreply, put_flash(socket, :warning, "#{success_count} file(s) uploaded, #{error_count} failed")}

            true ->
              {:noreply, put_flash(socket, :error, "Failed to upload files")}
          end
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action")}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    # Check which upload type to cancel based on what's available
    socket =
      cond do
        # Check if this ref belongs to resume upload
        Enum.any?(socket.assigns.uploads.resume.entries, &(&1.ref == ref)) ->
          cancel_upload(socket, :resume, ref)

        # Check if this ref belongs to media upload
        Enum.any?(socket.assigns.uploads.media.entries, &(&1.ref == ref)) ->
          cancel_upload(socket, :media, ref)

        # Fallback - try both (one will succeed, one will be ignored)
        true ->
          socket
          |> cancel_upload(:media, ref)
          |> cancel_upload(:resume, ref)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_media", %{"media_id" => media_id}, socket) do
    media = Portfolios.get_media!(media_id)

    # Verify media belongs to this portfolio
    if media.portfolio_id == socket.assigns.portfolio.id do
      case Portfolios.delete_media(media) do
        {:ok, _} ->
          # Delete physical file if file_path exists
          if media.file_path do
            file_path = Path.join([Application.app_dir(:frestyl, "priv"), "static", media.file_path])
            File.rm(file_path)
          end

          # Refresh sections
          sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

          {:noreply,
          socket
          |> assign(:sections, sections)
          |> put_flash(:info, "Media file deleted successfully")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete media file")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action")}
    end
  end

  # Helper function to normalize customization data to use string keys consistently
  defp normalize_customization(customization) when is_map(customization) do
    customization
    |> Enum.map(fn
      # Convert atom keys to strings
      {key, value} when is_atom(key) -> {to_string(key), normalize_value(value)}
      # Keep string keys as-is but normalize values
      {key, value} when is_binary(key) -> {key, normalize_value(value)}
    end)
    |> Enum.into(%{})
  end

  defp normalize_customization(_), do: %{}

  # Helper function to normalize nested values
  defp normalize_value(value) when is_map(value) do
    value
    |> Enum.map(fn
      {key, val} when is_atom(key) -> {to_string(key), normalize_value(val)}
      {key, val} when is_binary(key) -> {key, normalize_value(val)}
    end)
    |> Enum.into(%{})
  end

  defp normalize_value(value), do: value

  # Update the media upload section in render_section_editor function:

  # Replace the media upload section with this enhanced version:
  defp render_media_upload_section(assigns) do
    ~H"""
    <div class="border-t border-gray-200 pt-6">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Media Files</h3>

      <!-- Enhanced File Upload Area -->
      <div class="mb-6">
        <form phx-submit="upload_media"
              phx-value-section_id={@editing_section.id}
              phx-change="validate_upload"
              class="space-y-4">

          <!-- Drag and Drop Upload Zone -->
          <div class="upload-zone"
              phx-drop-target={@uploads.media.ref}
              phx-hook="FileUploadZone"
              id={"upload-zone-#{@editing_section.id}"}>

            <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-gray-400 transition-colors bg-gray-50 hover:bg-gray-100">
              <div class="space-y-4">
                <!-- Upload Icon -->
                <div class="mx-auto w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center">
                  <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
                  </svg>
                </div>

                <!-- Upload Text -->
                <div class="text-gray-600">
                  <label for={"media-upload-#{@editing_section.id}"} class="cursor-pointer">
                    <span class="font-medium text-blue-600 hover:text-blue-500">
                      Click to upload
                    </span>
                    <span> or drag and drop</span>
                  </label>
                  <input id={"media-upload-#{@editing_section.id}"}
                        type="file"
                        phx-hook="FileUpload"
                        multiple
                        accept="image/*,video/*,audio/*,.pdf,.doc,.docx,.txt"
                        class="sr-only"
                        {%{phx_value_section_id: @editing_section.id}} />
                </div>

                <!-- File Type Info -->
                <div class="text-sm text-gray-500">
                  <p>Images, videos, audio, or documents</p>
                  <p>Maximum size: <%= @limits.max_media_size_mb %>MB per file</p>
                </div>
              </div>
            </div>
          </div>

          <!-- Upload Progress and File List -->
          <%= if length(@uploads.media.entries) > 0 do %>
            <div class="space-y-3">
              <h4 class="font-medium text-gray-900">Files to Upload</h4>

              <%= for entry <- @uploads.media.entries do %>
                <div class="flex items-center justify-between p-4 bg-white border border-gray-200 rounded-lg">
                  <div class="flex items-center space-x-3">
                    <!-- File Type Icon -->
                    <div class="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center">
                      <%= get_file_type_icon(entry.client_type) %>
                    </div>

                    <!-- File Info -->
                    <div>
                      <div class="font-medium text-gray-900"><%= entry.client_name %></div>
                      <div class="text-sm text-gray-500">
                        <%= format_file_size(entry.client_size) %> •
                        <%= get_file_type_label(entry.client_type) %>
                      </div>
                    </div>
                  </div>

                  <!-- Progress and Actions -->
                  <div class="flex items-center space-x-3">
                    <!-- Progress Bar -->
                    <div class="w-24 bg-gray-200 rounded-full h-2">
                      <div class="bg-blue-600 h-2 rounded-full transition-all duration-300"
                          style={"width: #{entry.progress}%"}></div>
                    </div>

                    <!-- Remove Button -->
                    <button type="button"
                            phx-click="cancel_upload"
                            phx-value-ref={entry.ref}
                            class="text-red-600 hover:text-red-800 p-1">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                      </svg>
                    </button>
                  </div>
                </div>
              <% end %>

              <!-- Upload Button -->
              <button type="submit"
                      disabled={length(@uploads.media.entries) == 0}
                      class="w-full action-button primary disabled:opacity-50 disabled:cursor-not-allowed">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
                </svg>
                Upload <%= length(@uploads.media.entries) %> File(s)
              </button>
            </div>
          <% end %>

          <!-- Upload Errors -->
          <%= for err <- upload_errors(@uploads.media) do %>
            <div class="error-message">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              <%= error_to_string(err) %>
            </div>
          <% end %>
        </form>
      </div>

      <!-- Existing Media Files Grid -->
      <%= if length(@section_media) > 0 do %>
        <div class="space-y-4">
          <h4 class="font-medium text-gray-900">Uploaded Media</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
              id={"media-list-#{@editing_section.id}"}
              phx-hook="MediaSortable"
              data-section-id={@editing_section.id}>
            <%= for media <- Enum.sort_by(@section_media, & &1.position) do %>
              <div class="media-item border border-gray-200 rounded-lg overflow-hidden bg-white cursor-move"
                  data-media-id={media.id}>

                <!-- Media Preview -->
                <div class="aspect-video bg-gray-100 relative">
                  <%= case media.media_type do %>
                    <% "image" -> %>
                      <img src={media.file_path}
                          alt={media.title || "Image"}
                          class="w-full h-full object-cover" />

                    <% "video" -> %>
                      <video class="w-full h-full object-cover" controls preload="metadata">
                        <source src={media.file_path} type={media.mime_type} />
                      </video>

                    <% "audio" -> %>
                      <div class="w-full h-full bg-gray-200 flex items-center justify-center">
                        <div class="text-center">
                          <svg class="w-12 h-12 text-gray-400 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"/>
                          </svg>
                          <p class="text-sm text-gray-600">Audio File</p>
                        </div>
                      </div>
                      <audio controls class="absolute bottom-2 left-2 right-2">
                        <source src={media.file_path} type={media.mime_type} />
                      </audio>

                    <% _ -> %>
                      <div class="w-full h-full bg-gray-200 flex items-center justify-center">
                        <div class="text-center">
                          <svg class="w-12 h-12 text-gray-400 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                          </svg>
                          <p class="text-sm text-gray-600">Document</p>
                        </div>
                      </div>
                  <% end %>

                  <!-- Visibility Toggle Overlay -->
                  <div class="absolute top-2 right-2">
                    <button phx-click="toggle_media_visibility"
                            phx-value-media_id={media.id}
                            class={[
                              "p-2 rounded-full backdrop-blur-sm border",
                              if(media.visible,
                                do: "bg-green-500 bg-opacity-90 text-white border-green-600",
                                else: "bg-red-500 bg-opacity-90 text-white border-red-600")
                            ]}
                            title={if(media.visible, do: "Click to hide", else: "Click to show")}>
                      <%= if media.visible do %>
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                        </svg>
                      <% else %>
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
                        </svg>
                      <% end %>
                    </button>
                  </div>
                </div>

                <!-- Media Details Form -->
                <div class="p-4 space-y-3">
                  <input type="text"
                        value={media.title || ""}
                        phx-blur="update_media"
                        phx-value-media_id={media.id}
                        phx-value-field="title"
                        placeholder="Media title"
                        class="w-full text-sm px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />

                  <textarea phx-blur="update_media"
                            phx-value-media_id={media.id}
                            phx-value-field="description"
                            placeholder="Description..."
                            rows="2"
                            class="w-full text-sm px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= media.description || "" %></textarea>

                  <!-- Media Info and Actions -->
                  <div class="flex items-center justify-between text-xs text-gray-500">
                    <span><%= format_file_size(media.file_size || 0) %></span>
                    <div class="flex items-center space-x-2">
                      <span class={[
                        "px-2 py-1 rounded text-xs font-medium",
                        if(media.visible, do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-500")
                      ]}>
                        <%= if media.visible, do: "Visible", else: "Hidden" %>
                      </span>
                      <button phx-click="delete_media"
                              phx-value-media_id={media.id}
                              data-confirm="Are you sure you want to delete this media file?"
                              class="text-red-600 hover:text-red-800 font-medium">
                        Delete
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="text-center py-12 text-gray-500">
          <svg class="mx-auto h-16 w-16 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
          <h3 class="mt-4 text-lg font-medium">No media files yet</h3>
          <p class="mt-2">Upload images, videos, or documents to enhance this section</p>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper function to validate media types
  defp valid_media_type?(mime_type) do
    allowed_types = [
      # Images
      "image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp",
      # Videos
      "video/mp4", "video/quicktime", "video/webm", "video/avi",
      # Audio
      "audio/mpeg", "audio/mp3", "audio/wav", "audio/ogg", "audio/aac",
      # Documents
      "application/pdf", "application/msword",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "text/plain"
    ]

    mime_type in allowed_types
  end

  # Enhanced media upload function
  defp upload_media_file(temp_path, entry, section, portfolio) do
    try do
      IO.puts("Uploading media file: #{entry.client_name}")

      # Create upload directory structure
      upload_base = Path.join([Application.app_dir(:frestyl, "priv"), "static", "uploads"])
      portfolio_dir = Path.join(upload_base, "portfolio_#{portfolio.id}")
      section_dir = Path.join(portfolio_dir, "section_#{section.id}")

      # Ensure directories exist
      with :ok <- File.mkdir_p(section_dir) do
        # Generate unique filename
        timestamp = DateTime.utc_now() |> DateTime.to_unix()
        extension = Path.extname(entry.client_name)
        safe_filename = entry.client_name
                      |> Path.basename(extension)
                      |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")
                      |> String.slice(0, 50)

        filename = "#{timestamp}_#{safe_filename}#{extension}"
        dest_path = Path.join(section_dir, filename)
        public_path = "/uploads/portfolio_#{portfolio.id}/section_#{section.id}/#{filename}"

        # Copy file to destination
        with :ok <- File.cp(temp_path, dest_path) do
          IO.puts("File copied successfully to: #{dest_path}")

          # Create media record in database
          media_attrs = %{
            title: Path.basename(entry.client_name, extension),
            description: "",
            media_type: determine_media_type(entry.client_type),
            file_path: public_path,
            file_size: entry.client_size,
            mime_type: entry.client_type,
            visible: true,
            position: get_next_media_position(section.id),
            portfolio_id: portfolio.id,
            section_id: section.id
          }

          case Portfolios.create_media(media_attrs) do
            {:ok, media} ->
              IO.puts("Media record created successfully: #{media.id}")
              {:ok, media}
            {:error, changeset} ->
              # Clean up file if database save fails
              File.rm(dest_path)
              IO.puts("Database save failed: #{inspect(changeset.errors)}")
              {:error, changeset}
          end
        else
          {:error, reason} ->
            IO.puts("File copy failed: #{inspect(reason)}")
            {:error, "File copy failed: #{inspect(reason)}"}
        end
      else
        {:error, reason} ->
          IO.puts("Directory creation failed: #{inspect(reason)}")
          {:error, "Directory creation failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        IO.puts("Upload failed with exception: #{Exception.message(error)}")
        {:error, "Upload failed: #{Exception.message(error)}"}
    end
  end

  # Helper function to get next media position
  defp get_next_media_position(section_id) do
    try do
      case Portfolios.list_section_media(section_id) do
        [] -> 0
        media_list when is_list(media_list) ->
          max_position = Enum.max_by(media_list, & &1.position, fn -> %{position: -1} end).position
          max_position + 1
        _ -> 0
      end
    rescue
      _ -> 0
    end
  end

  # Add the missing helper:
  defp determine_media_type(content_type) do
    cond do
      String.starts_with?(content_type, "image/") -> "image"
      String.starts_with?(content_type, "video/") -> "video"
      String.starts_with?(content_type, "audio/") -> "audio"
      true -> "document"
    end
  end

  @impl true
  def handle_event("delete_media", %{"media_id" => media_id}, socket) do
    media = Portfolios.get_media!(media_id)

    # Verify media belongs to this portfolio
    if media.portfolio_id == socket.assigns.portfolio.id do
      case Portfolios.delete_media(media) do
        {:ok, _} ->
          # Delete physical file if file_path exists
          if media.file_path do
            file_path = Path.join([Application.app_dir(:frestyl, "priv"), "static", media.file_path])
            File.rm(file_path)
          end

          # Refresh sections
          sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

          {:noreply,
          socket
          |> assign(:sections, sections)
          |> put_flash(:info, "Media file deleted successfully")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete media file")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action")}
    end
  end

  @impl true
  def handle_event("update_media", %{"media_id" => media_id, "field" => field, "value" => value}, socket) do
    media = Portfolios.get_media!(media_id)

    if media.portfolio_id == socket.assigns.portfolio.id do
      # Convert field name to atom and prepare update attrs
      field_atom = String.to_existing_atom(field)
      update_attrs = %{field_atom => value}

      case Portfolios.update_media(media, update_attrs) do
        {:ok, _} ->
          sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)
          {:noreply, assign(socket, :sections, sections)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update media")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action")}
    end
  end

  @impl true
  def handle_event("toggle_media_visibility", %{"media_id" => media_id}, socket) do
    media = Portfolios.get_media!(media_id)

    if media.portfolio_id == socket.assigns.portfolio.id do
      case Portfolios.update_media(media, %{visible: !media.visible}) do
        {:ok, _} ->
          sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)
          {:noreply, assign(socket, :sections, sections)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update media visibility")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action")}
    end
  end

  @impl true
  def handle_event("reorder_media", %{"section_id" => section_id, "media_order" => media_order}, socket) do
    section = Portfolios.get_section!(section_id)

    if section.portfolio_id == socket.assigns.portfolio.id do
      # Update media positions based on new order
      Enum.with_index(media_order, 0)
      |> Enum.each(fn {media_id_str, position} ->
        media_id = String.to_integer(media_id_str)
        media = Portfolios.get_media!(media_id)
        Portfolios.update_media(media, %{position: position})
      end)

      sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

      {:noreply,
      socket
      |> assign(:sections, sections)
      |> put_flash(:info, "Media order updated")}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action")}
    end
  end

  # Portfolio settings events
  @impl true
  def handle_event("update_visibility", %{"visibility" => visibility}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{visibility: String.to_atom(visibility)}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> put_flash(:info, "Visibility updated to #{visibility}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update visibility")}
    end
  end

  @impl true
  def handle_event("toggle_approval_required", _params, socket) do
    new_value = !socket.assigns.portfolio.require_approval

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{require_approval: new_value}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> put_flash(:info, "Approval requirement updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update setting")}
    end
  end

  @impl true
  def handle_event("toggle_resume_export", _params, socket) do
    new_value = !socket.assigns.portfolio.allow_resume_export

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{allow_resume_export: new_value}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> put_flash(:info, "Resume export setting updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update setting")}
    end
  end

  # Add visibility toggle handler:
  @impl true
  def handle_event("toggle_visibility", %{"visibility" => visibility}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{visibility: String.to_atom(visibility)}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> put_flash(:info, "Visibility updated to #{visibility}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update visibility")}
    end
  end

  @impl true
  def handle_event("export_portfolio", _params, socket) do
    # This would trigger a portfolio export (PDF, etc.)
    {:noreply, put_flash(socket, :info, "Export feature coming soon!")}
  end

  @impl true
  def handle_event("duplicate_portfolio", _params, socket) do
    portfolio_attrs = %{
      title: "Copy of #{socket.assigns.portfolio.title}",
      description: socket.assigns.portfolio.description,
      theme: socket.assigns.portfolio.theme,
      customization: socket.assigns.portfolio.customization,
      visibility: :private
    }

    case Portfolios.create_portfolio(socket.assigns.current_user.id, portfolio_attrs) do
      {:ok, new_portfolio} ->
        {:noreply,
        socket
        |> put_flash(:info, "Portfolio duplicated successfully!")
        |> push_navigate(to: "/portfolios/#{new_portfolio.id}/edit")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to duplicate portfolio")}
    end
  end

  @impl true
  def handle_event("export_portfolio", _params, socket) do
    # For now, just show a coming soon message
    {:noreply, put_flash(socket, :info, "Export feature coming soon!")}
  end

  @impl true
  def handle_event("delete_portfolio", _params, socket) do
    case Portfolios.delete_portfolio(socket.assigns.portfolio) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Portfolio deleted successfully")
         |> push_navigate(to: "/portfolios")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete portfolio")}
    end
  end

  @impl true
  def handle_event("preview_changes", _params, socket) do
    {:noreply,
    socket
    |> assign(:show_preview, true)
    |> put_flash(:info, "Preview mode activated. Changes are automatically saved.")}
  end

  @impl true
  def handle_event("save_customization", _params, socket) do
    # This is mainly for user feedback since changes are auto-saved
    {:noreply, put_flash(socket, :info, "All customizations have been saved!")}
  end

  @impl true
  def handle_event("select_theme", %{"theme" => theme}, socket) do
    # Redirect to the proper template selection handler
    handle_event("select_template", %{"template" => theme}, socket)
  end

  @impl true
  def handle_event("update_color", %{"color" => color_value, "name" => color_name}, socket) do
    IO.puts("Color update event: #{color_name} = #{color_value}")

    # Get current customization with safe defaults - ALWAYS use string keys
    current_customization = normalize_customization(socket.assigns.customization || %{})

    # Update the color scheme with string keys
    color_scheme = Map.get(current_customization, "color_scheme", %{})
    updated_color_scheme = Map.put(color_scheme, "primary", color_value)
    updated_customization = Map.put(current_customization, "color_scheme", updated_color_scheme)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> put_flash(:info, "Color updated to #{color_name}!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update color")}
    end
  end

  @impl true
  def handle_event("update_color_text", %{"field" => "theme_color", "value" => color_value}, socket) do
    # Redirect to the proper color update handler
    handle_event("update_color", %{"color" => color_value, "name" => "Custom"}, socket)
  end

  # Fix the layout option handler:
  @impl true
  def handle_event("update_layout_option", %{"option" => option, "value" => value}, socket) do
    IO.puts("Layout option update event: #{option} = #{value}")

    # Convert string values properly
    converted_value = case value do
      "true" -> true
      "false" -> false
      val when is_binary(val) -> val
      val -> val
    end

    current_customization = stringify_keys(socket.assigns.customization || %{})
    updated_customization = Map.put(current_customization, option, converted_value)

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
    IO.puts("Section spacing update event: #{spacing}")

    current_customization = stringify_keys(socket.assigns.customization || %{})
    updated_customization = Map.put(current_customization, "section_spacing", spacing)

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
    IO.puts("Font style update event: #{font}")

    current_customization = stringify_keys(socket.assigns.customization || %{})
    updated_customization = Map.put(current_customization, "font_style", font)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> put_flash(:info, "Font updated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update font")}
    end
  end

  @impl true
  def handle_event("reset_customization", _params, socket) do
    default_customization = PortfolioTemplates.get_template_config(socket.assigns.portfolio.theme || "executive")

    # FORCE default customization to use string keys
    normalized_config = stringify_keys(default_customization)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: normalized_config}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, normalized_config)
        |> put_flash(:info, "Customization reset to template defaults!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reset customization")}
    end
  end

  @impl true
  def handle_info({:countdown_tick, component_id}, socket) do
    # This message is meant for the component, but sent to parent LiveView
    # We don't need to forward it - the component handles its own timers
    {:noreply, socket}
  end

  @impl true
  def handle_info({:recording_tick, component_id}, socket) do
    # Same here - component handles its own recording timers
    {:noreply, socket}
  end

  @impl true
  def handle_info({:video_intro_complete, data}, socket) do
    # Handle successful video upload
    {:noreply,
    socket
    |> assign(:show_video_intro_modal, false)
    |> put_flash(:info, "Video introduction saved successfully!")}
  end

  # Catch-all for any other unhandled messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # CRITICAL: This function converts ALL keys to strings recursively
  defp stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {to_string(key), stringify_keys(value)}
      {key, value} when is_binary(key) -> {key, stringify_keys(value)}
    end)
    |> Enum.into(%{})
  end

  defp stringify_keys(value), do: value

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
    socket
    |> assign(:section_edit_id, nil)
    |> push_patch(to: "/portfolios/#{socket.assigns.portfolio.id}/edit?tab=sections")}
  end

  @impl true
  def handle_event("update_section_field", %{"field" => field, "section-id" => section_id, "value" => value}, socket) do
    section = Portfolios.get_section!(section_id)

    case Portfolios.update_section(section, %{field => value}) do
      {:ok, _updated_section} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

        {:noreply,
        socket
        |> assign(:sections, sections)
        |> assign(:unsaved_changes, true)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update section")}
    end
  end

  @impl true
  def handle_event("update_section_content", %{"field" => field, "section-id" => section_id, "value" => value}, socket) do
    section = Portfolios.get_section!(section_id)

    # Update the content map
    updated_content = Map.put(section.content || %{}, field, value)

    case Portfolios.update_section(section, %{content: updated_content}) do
      {:ok, _updated_section} ->
        sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

        {:noreply,
        socket
        |> assign(:sections, sections)
        |> assign(:unsaved_changes, true)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update section content")}
    end
  end

  @impl true
  def handle_event("save_section", %{"id" => section_id}, socket) do
    {:noreply,
    socket
    |> assign(:section_edit_id, nil)
    |> assign(:unsaved_changes, false)
    |> put_flash(:info, "Section updated successfully!")
    |> push_patch(to: "/portfolios/#{socket.assigns.portfolio.id}/edit?tab=sections")}
  end

  @impl true
  def handle_event("update_stats", %{"stat_name" => stat_name, "value" => value}, socket) do
    current_customization = normalize_customization(socket.assigns.customization || %{})

    # Update stats in customization
    current_stats = Map.get(current_customization, "stats", %{})
    updated_stats = Map.put(current_stats, stat_name, value)
    updated_customization = Map.put(current_customization, "stats", updated_stats)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> put_flash(:info, "Stat updated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update stat")}
    end
  end

  @impl true
  def handle_event("add_stat", %{"name" => name, "value" => value, "label" => label}, socket) do
    current_customization = normalize_customization(socket.assigns.customization || %{})

    # Add new stat
    current_stats = Map.get(current_customization, "stats", %{})
    new_stat = %{
      "value" => value,
      "label" => label,
      "id" => System.unique_integer([:positive])
    }
    updated_stats = Map.put(current_stats, name, new_stat)
    updated_customization = Map.put(current_customization, "stats", updated_stats)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> put_flash(:info, "New stat added!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add stat")}
    end
  end

  @impl true
  def handle_event("remove_stat", %{"stat_name" => stat_name}, socket) do
    current_customization = normalize_customization(socket.assigns.customization || %{})

    # Remove stat
    current_stats = Map.get(current_customization, "stats", %{})
    updated_stats = Map.delete(current_stats, stat_name)
    updated_customization = Map.put(current_customization, "stats", updated_stats)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> put_flash(:info, "Stat removed!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove stat")}
    end
  end

  # Add this helper function to render the stats editor
  defp render_stats_editor(assigns) do
    ~H"""
    <div class="stats-editor bg-gray-50 rounded-lg p-6 mb-6">
      <h4 class="text-lg font-semibold text-gray-900 mb-4">Portfolio Statistics</h4>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <%= for {stat_name, stat_data} <- get_portfolio_stats(@customization) do %>
          <div class="stat-item bg-white p-4 rounded-lg border border-gray-200">
            <div class="flex items-center justify-between mb-2">
              <label class="block text-sm font-medium text-gray-700">
                <%= Map.get(stat_data, "label", String.capitalize(stat_name)) %>
              </label>
              <button phx-click="remove_stat"
                      phx-value-stat_name={stat_name}
                      class="text-red-600 hover:text-red-800 text-sm">
                Remove
              </button>
            </div>

            <input type="text"
                  value={Map.get(stat_data, "value", "")}
                  phx-blur="update_stats"
                  phx-value-stat_name={stat_name}
                  placeholder="Enter value (e.g., 150, $2.5M, 95%)"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
          </div>
        <% end %>
      </div>

      <!-- Add New Stat Form -->
      <div class="border-t border-gray-200 pt-4">
        <h5 class="text-md font-medium text-gray-900 mb-3">Add New Statistic</h5>
        <form phx-submit="add_stat" class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <input type="text"
                name="name"
                placeholder="Stat name (e.g., total_sales)"
                required
                class="px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />

          <input type="text"
                name="label"
                placeholder="Display label (e.g., Total Sales)"
                required
                class="px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />

          <div class="flex space-x-2">
            <input type="text"
                  name="value"
                  placeholder="Value (e.g., $2.5M)"
                  required
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />

            <button type="submit"
                    class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium">
              Add
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  # Helper function to get portfolio stats
  defp get_portfolio_stats(customization) do
    normalized = normalize_customization(customization || %{})
    stats = Map.get(normalized, "stats", %{})

    # Default stats for executive template
    default_stats = %{
      "portfolio_views" => %{"label" => "Portfolio Views", "value" => "1,234"},
      "projects_completed" => %{"label" => "Projects Completed", "value" => "47"},
      "years_experience" => %{"label" => "Years Experience", "value" => "8"},
      "client_satisfaction" => %{"label" => "Client Satisfaction", "value" => "98%"}
    }

    Map.merge(default_stats, stats)
  end

  # Portfolio Edit LiveView - Part 5: Main Render Function

  @impl true
  def render(assigns) do
    theme_classes = get_theme_classes(assigns.customization, assigns.portfolio)
    assigns = assign(assigns, :theme_classes, theme_classes)

    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <header class="bg-white shadow-sm border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-4">
            <div class="flex items-center space-x-4">
              <.link navigate="/portfolios" class="text-gray-500 hover:text-gray-700">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
                </svg>
              </.link>

              <div>
                <h1 class="text-2xl font-bold text-gray-900">Edit Portfolio</h1>
                <p class="text-sm text-gray-600 mt-1">
                  <span class="font-medium"><%= @portfolio.title %></span>
                  <%= if @unsaved_changes do %>
                    <span class="ml-2 inline-flex items-center px-2 py-1 bg-yellow-100 text-yellow-800 text-xs font-medium rounded-full">
                      <div class="w-2 h-2 bg-yellow-400 rounded-full mr-1"></div>
                      Unsaved changes
                    </span>
                  <% end %>
                </p>
              </div>
            </div>

            <div class="flex items-center space-x-4">
              <!-- Preview Toggle -->
              <button phx-click="toggle_preview"
                      class={[
                        "inline-flex items-center px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium transition-colors",
                        if(@show_preview, do: "bg-blue-600 text-white border-blue-600", else: "bg-white text-gray-700 hover:bg-gray-50")
                      ]}>
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                </svg>
                <%= if @show_preview, do: "Hide Preview", else: "Show Preview" %>
              </button>

              <!-- View Live Portfolio -->
              <.link href={"/p/#{@portfolio.slug}"} target="_blank"
                     class="inline-flex items-center px-4 py-2 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700 transition-colors">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                </svg>
                View Live
              </.link>
            </div>
          </div>

          <!-- Navigation Tabs -->
          <nav class="flex space-x-8 border-t border-gray-200 pt-4">
            <%= for {tab_key, tab_label, tab_icon} <- [
              {:overview, "Overview", "M9 5H7a2 2 0 00-2 2v6a2 2 0 002 2h6a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"},
              {:sections, "Sections", "M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"},
              {:design, "Design", "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01"},
              {:settings, "Settings", "M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"}
            ] do %>
              <button phx-click="change_tab" phx-value-tab={tab_key}
                      class={[
                        "flex items-center space-x-2 py-2 px-1 border-b-2 font-medium text-sm transition-colors",
                        if(@active_tab == tab_key,
                           do: "border-blue-500 text-blue-600",
                           else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                      ]}>
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={tab_icon}/>
                </svg>
                <span><%= tab_label %></span>
                <%= if tab_key == :sections and @unsaved_changes do %>
                  <div class="w-2 h-2 bg-yellow-400 rounded-full"></div>
                <% end %>
              </button>
            <% end %>
          </nav>
        </div>
      </header>

      <!-- Main Content -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= if @show_preview do %>
          <!-- Preview Mode -->
          <div class="mb-8">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-semibold text-gray-900">Portfolio Preview</h2>

              <!-- Device Preview Toggles -->
              <div class="flex items-center space-x-2 bg-gray-100 rounded-lg p-1">
                <%= for {device, icon, label} <- [
                  {:desktop, "M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z", "Desktop"},
                  {:tablet, "M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z", "Tablet"},
                  {:mobile, "M12 18h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z", "Mobile"}
                ] do %>
                  <button phx-click="change_preview_device" phx-value-device={device}
                          class={[
                            "p-2 rounded text-sm font-medium transition-colors",
                            if(@preview_device == device,
                               do: "bg-white text-blue-600 shadow-sm",
                               else: "text-gray-600 hover:text-gray-900")
                          ]}
                          title={label}>
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={icon}/>
                    </svg>
                  </button>
                <% end %>
              </div>
            </div>

            <!-- Preview Frame Continued -->
            <div class={[
              "bg-gray-800 rounded-xl p-4 mx-auto",
              case @preview_device do
                :desktop -> "max-w-full"
                :tablet -> "max-w-3xl"
                :mobile -> "max-w-sm"
              end
            ]}>
              <div class={[
                "bg-white rounded-lg overflow-hidden shadow-lg",
                case @preview_device do
                  :desktop -> "aspect-[16/10]"
                  :tablet -> "aspect-[4/3]"
                  :mobile -> "aspect-[9/16]"
                end
              ]}>
                <iframe src={"/p/#{@portfolio.slug}?preview=true"}
                        class="w-full h-full border-0"></iframe>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Tab Content -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
          <%= case @active_tab do %>
            <% :overview -> %>
              <%= render_overview_tab(assigns) %>

            <% :sections -> %>
              <%= render_sections_tab(assigns) %>

            <% :design -> %>
              <%= render_design_tab(assigns) %>

            <% :settings -> %>
              <%= render_settings_tab(assigns) %>
          <% end %>
        </div>
      </main>

      <!-- Video Intro Modal -->
      <%= if @show_video_intro_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
            phx-window-keydown="hide_video_intro"
            phx-key="escape">
          <div class="max-w-4xl w-full mx-4">
            <.live_component
              module={VideoIntroComponent}
              id="video-intro"
              portfolio={@portfolio}
              current_user={@current_user}
              on_complete={&send(self(), {:video_intro_complete, &1})}
              on_cancel="hide_video_intro" />
          </div>
        </div>
      <% end %>

      <!-- Resume Import Modal -->
      <div :if={@show_resume_import_modal} class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
        <div class="bg-white rounded-xl shadow-2xl max-w-2xl w-full mx-4 max-h-[80vh] overflow-y-auto">

          <!-- Modal Header -->
          <div class="bg-gradient-to-r from-emerald-600 to-green-600 px-6 py-4 rounded-t-xl">
            <div class="flex items-center justify-between">
              <h3 class="text-xl font-bold text-white flex items-center">
                <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
                Import Resume Data
              </h3>
              <button phx-click="hide_resume_import"
                      class="text-white hover:text-gray-200 transition-colors">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
          </div>

          <!-- Modal Content -->
          <div class="p-6">
            <!-- Step 1: Upload Form -->
            <div :if={@resume_parsing_state == :idle} class="space-y-6">
              <div class="text-center">
                <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-emerald-100">
                  <svg class="h-6 w-6 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
                  </svg>
                </div>
                <h3 class="mt-2 text-lg font-medium text-gray-900">Upload Your Resume</h3>
                <p class="mt-1 text-sm text-gray-500">
                  Upload a PDF, DOC, or DOCX file to automatically extract and organize your information
                </p>
              </div>

              <form phx-submit="upload_resume" phx-change="validate_resume" class="space-y-4">
                <div class="space-y-4">
                  <!-- File Upload Area -->
                  <div phx-drop-target={@uploads.resume.ref}
                      class="flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md hover:border-emerald-400 transition-colors">
                    <div class="space-y-1 text-center">
                      <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                        <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                      </svg>
                      <div class="flex text-sm text-gray-600">
                        <div class="relative cursor-pointer bg-white rounded-md font-medium text-emerald-600 hover:text-emerald-500">
                          <span>Upload a file</span>
                          <.live_file_input upload={@uploads.resume} class="absolute inset-0 w-full h-full opacity-0 cursor-pointer" />
                        </div>
                        <p class="pl-1">or drag and drop</p>
                      </div>
                      <p class="text-xs text-gray-500">PDF, DOC, DOCX up to 10MB</p>
                    </div>
                  </div>

                  <!-- File List -->
                  <div :if={@uploads.resume.entries != []} class="space-y-2">
                    <h4 class="text-sm font-medium text-gray-900">Selected Files:</h4>
                    <div :for={entry <- @uploads.resume.entries} class="flex items-center justify-between bg-gray-50 rounded-md p-3">
                      <div class="flex items-center">
                        <svg class="h-5 w-5 text-gray-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clip-rule="evenodd"/>
                        </svg>
                        <span class="text-sm text-gray-900">{entry.client_name}</span>
                        <span class="text-xs text-gray-500 ml-2">({Float.round(entry.client_size / 1024 / 1024, 1)} MB)</span>
                      </div>

                      <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref}
                              class="text-red-500 hover:text-red-700">
                        <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                        </svg>
                      </button>
                    </div>
                  </div>

                  <!-- Upload Progress -->
                  <div :for={entry <- @uploads.resume.entries} :if={entry.progress > 0} class="space-y-2">
                    <div class="flex justify-between text-sm">
                      <span class="text-gray-600">Uploading...</span>
                      <span class="text-gray-600">{entry.progress}%</span>
                    </div>
                    <div class="w-full bg-gray-200 rounded-full h-2">
                      <div class="bg-emerald-600 h-2 rounded-full transition-all duration-300" style={"width: #{entry.progress}%"}></div>
                    </div>
                  </div>

                  <!-- Upload Errors -->
                  <div :for={err <- upload_errors(@uploads.resume)} class="text-red-600 text-sm">
                    {error_to_string(err)}
                  </div>
                </div>

                <div class="flex justify-end space-x-3">
                  <button type="button" phx-click="hide_resume_import"
                          class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50">
                    Cancel
                  </button>
                  <button type="submit"
                          disabled={@uploads.resume.entries == []}
                          class="px-4 py-2 text-sm font-medium text-white bg-emerald-600 border border-transparent rounded-md shadow-sm hover:bg-emerald-700 disabled:bg-gray-400 disabled:cursor-not-allowed">
                    Parse Resume
                  </button>
                </div>
              </form>
            </div>

            <!-- Step 2: Parsing State -->
            <div :if={@resume_parsing_state == :parsing} class="text-center py-8">
              <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600 mx-auto"></div>
              <h3 class="mt-4 text-lg font-medium text-gray-900">Processing Resume</h3>
              <p class="mt-2 text-sm text-gray-500">Extracting information from your resume...</p>
            </div>

            <!-- Step 3: Parsed Results -->
            <div :if={@resume_parsing_state == :parsed and @parsed_resume_data} class="space-y-6">
              <div class="text-center">
                <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-green-100">
                  <svg class="h-6 w-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                </div>
                <h3 class="mt-2 text-lg font-medium text-gray-900">Resume Parsed Successfully</h3>
                <p class="mt-1 text-sm text-gray-500">Review the extracted sections below and choose how to import them</p>
              </div>

              <div class="space-y-4">
                <div :for={{section_type, content} <- @parsed_resume_data} class="border border-gray-200 rounded-lg p-4 hover:border-emerald-300 transition-colors">
                  <div class="flex justify-between items-start mb-3">
                    <h4 class="font-medium text-gray-900 capitalize flex items-center">
                      <svg class="w-4 h-4 mr-2 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                      </svg>
                      {String.replace(to_string(section_type), "_", " ")}
                    </h4>
                    <select name={"mapping[#{section_type}]"}
                            class="text-sm border-gray-300 rounded-md shadow-sm focus:border-emerald-500 focus:ring-emerald-500">
                      <option value="new">Create New Section</option>
                      <option value="skip">Skip This Section</option>
                    </select>
                  </div>

                  <div class="text-sm text-gray-600 bg-gray-50 rounded-md p-3 max-h-24 overflow-y-auto">
                    {String.slice(to_string(content), 0, 150)}<span :if={String.length(to_string(content)) > 150}>...</span>
                  </div>
                </div>
              </div>

              <div class="flex justify-end space-x-3 pt-4 border-t border-gray-200">
                <button phx-click="hide_resume_import"
                        class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50">
                  Cancel
                </button>
                <button phx-click="import_resume_sections"
                        class="px-4 py-2 text-sm font-medium text-white bg-emerald-600 border border-transparent rounded-md shadow-sm hover:bg-emerald-700">
                  Import Selected Sections
                </button>
              </div>
            </div>

            <!-- Step 4: Error State -->
            <div :if={@resume_parsing_state == :error} class="text-center py-8">
              <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-100">
                <svg class="h-6 w-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"/>
                </svg>
              </div>
              <h3 class="mt-2 text-lg font-medium text-gray-900">Parsing Failed</h3>
              <p class="mt-1 text-sm text-gray-500">{@resume_error_message || "Unable to parse the resume file"}</p>
              <button phx-click="reset_resume_import"
                      class="mt-4 px-4 py-2 text-sm font-medium text-emerald-600 bg-emerald-50 border border-emerald-200 rounded-md hover:bg-emerald-100">
                Try Again
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Tab rendering functions
  defp render_overview_tab(assigns) do
    ~H"""
    <div class="p-8">
      <h2 class="text-xl font-bold text-gray-900 mb-6">Portfolio Overview</h2>

      <.form for={@form} phx-submit="update_portfolio" phx-change="validate_portfolio" class="space-y-6">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Basic Information -->
          <div class="space-y-6">
            <div>
              <.input field={@form[:title]} label="Portfolio Title"
                       placeholder="My Professional Portfolio"
                       class="text-lg font-semibold" />
            </div>

            <div>
              <.input field={@form[:slug]} label="Portfolio URL"
                      placeholder="my-portfolio-url" />
              <p class="mt-2 text-sm text-gray-600">
                Your portfolio will be available at:
                <code class="text-blue-600">frestyl.com/p/<span id="slug-preview"><%= @portfolio.slug %></span></code>
              </p>
            </div>

            <div>
              <.input field={@form[:description]} type="textarea" label="Description"
                       placeholder="Brief description of your portfolio..."
                       rows="4" />
            </div>

            <div class="flex items-center space-x-4">
              <button type="submit"
                      class="bg-blue-600 text-white px-6 py-2 rounded-lg font-semibold hover:bg-blue-700 transition-colors">
                Save Changes
              </button>

              <button type="button" phx-click="duplicate_portfolio"
                      class="bg-gray-600 text-white px-6 py-2 rounded-lg font-semibold hover:bg-gray-700 transition-colors">
                Duplicate Portfolio
              </button>
            </div>
          </div>

          <!-- Portfolio Stats & Actions -->
          <div class="space-y-6">
            <div class="bg-gray-50 rounded-xl p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Portfolio Statistics</h3>

              <div class="grid grid-cols-2 gap-4">
                <div class="text-center">
                  <div class="text-2xl font-bold text-blue-600">
                    <%= get_portfolio_view_count(@portfolio) %>
                  </div>
                  <div class="text-sm text-gray-600">Total Views</div>
                </div>

                <div class="text-center">
                  <div class="text-2xl font-bold text-green-600">
                    <%= length(@sections) %>
                  </div>
                  <div class="text-sm text-gray-600">Sections</div>
                </div>

                <div class="text-center">
                  <div class="text-2xl font-bold text-purple-600">
                    <%= get_portfolio_media_count(@portfolio) %>
                  </div>
                  <div class="text-sm text-gray-600">Media Files</div>
                </div>

                <div class="text-center">
                  <div class="text-2xl font-bold text-orange-600">
                    <%= format_date(@portfolio.updated_at) %>
                  </div>
                  <div class="text-sm text-gray-600">Last Updated</div>
                </div>
              </div>
            </div>

            <!-- Quick Actions -->
            <div class="bg-white rounded-lg border border-gray-200 p-4">
              <h3 class="text-base font-semibold text-gray-900 mb-3 flex items-center">
                <svg class="w-4 h-4 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                </svg>
                Quick Actions
              </h3>

              <div class="grid grid-cols-2 gap-2">
                <!-- Import Resume -->
                <button phx-click="show_resume_import"
                        class="group flex items-center justify-center px-3 py-2 text-xs font-medium text-emerald-700 bg-emerald-50 border border-emerald-200 rounded-md hover:bg-emerald-100 hover:border-emerald-300 transition-all duration-200">
                  <svg class="w-4 h-4 mr-1.5 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  Import Resume
                </button>

                <!-- Record Video -->
                <button phx-click="show_video_intro"
                        class="group flex items-center justify-center px-3 py-2 text-xs font-medium text-purple-700 bg-purple-50 border border-purple-200 rounded-md hover:bg-purple-100 hover:border-purple-300 transition-all duration-200">
                  <svg class="w-4 h-4 mr-1.5 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                  </svg>
                  Video Intro
                </button>

                <!-- View Live -->
                <.link href={"/p/#{@portfolio.slug}"} target="_blank"
                      class="group flex items-center justify-center px-3 py-2 text-xs font-medium text-blue-700 bg-blue-50 border border-blue-200 rounded-md hover:bg-blue-100 hover:border-blue-300 transition-all duration-200">
                  <svg class="w-4 h-4 mr-1.5 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                  </svg>
                  View Live
                </.link>

                <!-- Export PDF -->
                <button phx-click="export_portfolio"
                        class="group flex items-center justify-center px-3 py-2 text-xs font-medium text-gray-700 bg-gray-50 border border-gray-200 rounded-md hover:bg-gray-100 hover:border-gray-300 transition-all duration-200">
                  <svg class="w-4 h-4 mr-1.5 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  Export PDF
                </button>
              </div>
            </div>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  # Portfolio Edit LiveView - Part 7: Sections Tab Rendering

  defp render_sections_tab(assigns) do
    ~H"""
    <div class="p-8">
      <!-- Check if we're editing a section -->
      <%= if @section_edit_id do %>
        <%= render_section_editor(assigns) %>
      <% else %>
        <%= render_sections_list(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_sections_list(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <h2 class="text-xl font-bold text-gray-900">Portfolio Sections</h2>

      <!-- Add Section Dropdown -->
      <div class="relative" data-dropdown>
        <button class="bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 transition-colors flex items-center space-x-2"
                onclick="toggleDropdown(event)">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
          </svg>
          <span>Add Section</span>
        </button>

        <div class="absolute right-0 mt-2 w-56 bg-white rounded-lg shadow-lg border border-gray-200 z-10 hidden"
            data-dropdown-menu>
          <%= for {section_type, icon, title, description} <- [
            {:intro, "👋", "Introduction", "Personal summary and overview"},
            {:experience, "💼", "Work Experience", "Professional work history"},
            {:education, "🎓", "Education", "Academic background and qualifications"},
            {:skills, "⚡", "Skills & Expertise", "Technical and soft skills"},
            {:projects, "🚀", "Projects", "Collection of your work"},
            {:featured_project, "⭐", "Featured Project", "Showcase your best work"},
            {:case_study, "📊", "Case Study", "Detailed project analysis"},
            {:achievements, "🏆", "Achievements", "Awards and recognitions"},
            {:testimonial, "💬", "Testimonials", "Client and colleague feedback"},
            {:media_showcase, "🎨", "Media Showcase", "Visual portfolio of your work"},
            {:code_showcase, "💻", "Code Showcase", "Display your best code"},
            {:contact, "📧", "Contact Information", "How people can reach you"},
            {:custom, "📋", "Custom Section", "Create your own content"}
          ] do %>
            <button phx-click="add_section" phx-value-type={section_type}
                    class="w-full text-left px-4 py-3 hover:bg-gray-50 flex items-start space-x-3"
                    onclick="closeDropdown()">
              <div class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center mt-0.5">
                <span class="text-sm"><%= icon %></span>
              </div>
              <div>
                <div class="font-medium text-gray-900"><%= title %></div>
                <div class="text-sm text-gray-500"><%= description %></div>
              </div>
            </button>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Enhanced Sortable Sections List -->
    <%= if length(@sections) > 0 do %>
      <div class="mb-4 text-sm text-gray-600 bg-blue-50 border border-blue-200 rounded-lg p-3">
        <div class="flex items-center space-x-2">
          <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <span><strong>Tip:</strong> Drag sections by the grip handle to reorder them</span>
        </div>
      </div>

      <div class="space-y-4"
          id="sections-list"
          phx-hook="SectionSortable"
          data-group="sections">
        <%= for section <- Enum.sort_by(@sections, & &1.position) do %>
          <div class="section-item bg-white rounded-xl border-2 border-gray-200 hover:border-gray-300 transition-all duration-200 relative"
              data-section-id={section.id}>

            <!-- Dragging State Overlay -->
            <div class="dragging-overlay absolute inset-0 bg-blue-50 border-2 border-blue-300 rounded-xl opacity-0 pointer-events-none transition-opacity duration-200"></div>

            <div class="p-6">
              <div class="flex items-center space-x-4">
                <!-- Enhanced Drag Handle -->
                <div class="drag-handle cursor-move text-gray-400 hover:text-gray-600 transition-colors p-2 -m-2 rounded-lg hover:bg-gray-100">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16"/>
                  </svg>
                </div>

                <!-- Section Info -->
                <div class="flex-1 min-w-0">
                  <div class="flex items-center space-x-3">
                    <!-- Section Type Icon -->
                    <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center flex-shrink-0">
                      <span class="text-lg"><%= get_section_emoji(section.section_type) %></span>
                    </div>

                    <div class="flex-1 min-w-0">
                      <h3 class="text-lg font-semibold text-gray-900 truncate"><%= section.title %></h3>
                      <div class="flex items-center space-x-4 mt-1">
                        <p class="text-sm text-gray-600">
                          <%= format_section_type(section.section_type) %>
                        </p>
                        <span class="text-gray-300">•</span>
                        <p class="text-sm text-gray-500">
                          <%= get_section_content_summary(section) %>
                        </p>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Visibility Toggle -->
                <div class="flex items-center space-x-4">
                  <div class="toggle-with-label">
                    <label class="toggle-switch">
                      <input type="checkbox"
                            checked={section.visible}
                            phx-click="toggle_section_visibility"
                            phx-value-id={section.id} />
                      <span class="toggle-slider"></span>
                    </label>
                    <span class={[
                      "toggle-label text-sm",
                      section.visible && "active"
                    ]}>
                      <%= if section.visible, do: "Visible", else: "Hidden" %>
                    </span>
                  </div>

                  <!-- Section Actions -->
                  <div class="flex items-center space-x-2">
                    <button phx-click="edit_section" phx-value-id={section.id}
                            class="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                            title="Edit section">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                      </svg>
                    </button>

                    <button phx-click="delete_section" phx-value-id={section.id}
                            data-confirm="Are you sure you want to delete this section? This action cannot be undone."
                            class="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                            title="Delete section">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                      </svg>
                    </button>
                  </div>
                </div>
              </div>

              <!-- Media Preview (if any) -->
              <%= if get_section_media_count(section) > 0 do %>
                <div class="mt-4 pt-4 border-t border-gray-100">
                  <div class="flex items-center space-x-2 text-sm text-gray-500">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                    </svg>
                    <span><%= get_section_media_count(section) %> media file(s)</span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <!-- Enhanced Empty State -->
      <div class="text-center py-16">
        <div class="w-32 h-32 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-8">
          <svg class="w-16 h-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
          </svg>
        </div>
        <h3 class="text-2xl font-semibold text-gray-900 mb-4">No sections yet</h3>
        <p class="text-gray-600 mb-8 max-w-md mx-auto">
          Start building your portfolio by adding your first section. You can always reorder them later by dragging.
        </p>
        <button class="action-button primary"
                onclick="document.querySelector('[data-dropdown] button').click()">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
          </svg>
          Add Your First Section
        </button>
      </div>
    <% end %>

    <script>
      function toggleDropdown(event) {
        event.stopPropagation();
        const menu = event.target.closest('[data-dropdown]').querySelector('[data-dropdown-menu]');
        menu.classList.toggle('hidden');
      }

      function closeDropdown() {
        document.querySelectorAll('[data-dropdown-menu]').forEach(menu => {
          menu.classList.add('hidden');
        });
      }

      // Close dropdown when clicking outside
      document.addEventListener('click', closeDropdown);
    </script>
    """
  end

  # FIXED section editor to prevent showing markup in input boxes:
  defp render_section_content_editor(section, assigns) do
    assigns =
      assigns
      |> assign(:section, section)
      |> assign(:main_content, get_section_main_content(section))
      |> assign(:formatted_type, format_section_type(section.section_type))

    ~H"""
    <div class="space-y-4">
      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Content</label>
        <textarea phx-blur="update_section_content"
                  phx-value-field="main_content"
                  phx-value-section-id={@section.id}
                  rows="6"
                  placeholder="Add content for this section..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">{@main_content}</textarea>
      </div>

      <div class="text-sm text-gray-600 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <p><strong>Section Type:</strong> {@formatted_type}</p>
        <p class="mt-1">This is a simplified editor. For advanced customization, specific editors for each section type can be implemented.</p>
      </div>
    </div>
    """
  end

  defp render_section_content_editor(%{section_type: :contact} = section, assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-semibold text-gray-800 mb-2">Email</label>
          <input type="email"
                value={get_in(section.content, ["email"]) || ""}
                phx-blur="update_section_content"
                phx-value-field="email"
                phx-value-section-id={section.id}
                placeholder="your.email@example.com"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-800 mb-2">Phone</label>
          <input type="tel"
                value={get_in(section.content, ["phone"]) || ""}
                phx-blur="update_section_content"
                phx-value-field="phone"
                phx-value-section-id={section.id}
                placeholder="+1 (555) 123-4567"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Location</label>
        <input type="text"
              value={get_in(section.content, ["location"]) || ""}
              phx-blur="update_section_content"
              phx-value-field="location"
              phx-value-section-id={section.id}
              placeholder="City, State/Country"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      </div>
    </div>
    """
  end

  # FIXED: Generic editor that shows user-friendly content instead of raw JSON
  defp render_section_content_editor(section, assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Content</label>
        <textarea phx-blur="update_section_content"
                  phx-value-field="main_content"
                  phx-value-section-id={section.id}
                  rows="6"
                  placeholder="Add content for this section..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= get_section_main_content(section) %></textarea>
      </div>

      <div class="text-sm text-gray-600 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <p><strong>Section Type:</strong> <%= format_section_type(section.section_type) %></p>
        <p class="mt-1">This is a simplified editor. For advanced customization, specific editors for each section type can be implemented.</p>
      </div>
    </div>
    """
  end

  # Helper function to extract main content in a user-friendly way
  defp get_section_main_content(section) do
    case section.section_type do
      :intro ->
        summary = get_in(section.content, ["summary"]) || ""
        headline = get_in(section.content, ["headline"]) || ""
        if String.length(headline) > 0 and String.length(summary) > 0 do
          "#{headline}\n\n#{summary}"
        else
          headline <> summary
        end

      :experience ->
        jobs = get_in(section.content, ["jobs"]) || []
        if length(jobs) > 0 do
          Enum.map_join(jobs, "\n\n", fn job ->
            "#{Map.get(job, "title", "")} at #{Map.get(job, "company", "")}\n#{Map.get(job, "description", "")}"
          end)
        else
          ""
        end

      :education ->
        education = get_in(section.content, ["education"]) || []
        if length(education) > 0 do
          Enum.map_join(education, "\n\n", fn edu ->
            "#{Map.get(edu, "degree", "")} from #{Map.get(edu, "school", "")}\n#{Map.get(edu, "description", "")}"
          end)
        else
          ""
        end

      :skills ->
        skills = get_in(section.content, ["skills"]) || []
        if length(skills) > 0 do
          Enum.map_join(skills, "\n", fn skill ->
            case skill do
              %{"name" => name, "level" => level} -> "#{name} - #{level}"
              %{"name" => name} -> name
              skill when is_binary(skill) -> skill
              _ -> ""
            end
          end)
        else
          ""
        end

      :featured_project ->
        title = get_in(section.content, ["title"]) || ""
        description = get_in(section.content, ["description"]) || ""
        if String.length(title) > 0 and String.length(description) > 0 do
          "#{title}\n\n#{description}"
        else
          title <> description
        end

      :contact ->
        email = get_in(section.content, ["email"]) || ""
        phone = get_in(section.content, ["phone"]) || ""
        location = get_in(section.content, ["location"]) || ""
        [email, phone, location] |> Enum.filter(&(String.length(&1) > 0)) |> Enum.join("\n")

      _ ->
        # For other section types, try to extract any text content
        case section.content do
          %{"content" => content} when is_binary(content) -> content
          %{"description" => desc} when is_binary(desc) -> desc
          %{"summary" => summary} when is_binary(summary) -> summary
          _ -> ""
        end
    end
  end

  # Replace the render_design_tab function with this enhanced version:
  defp render_design_tab(assigns) do
    ~H"""
    <div class="p-8 bg-gray-50 min-h-screen">
      <div class="max-w-5xl mx-auto">
        <h2 class="text-3xl font-bold text-gray-900 mb-8">Design & Templates</h2>

        <!-- Current Template Display -->
        <div class="mb-8 p-6 bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-xl">
          <div class="flex items-center space-x-4">
            <div class="w-16 h-16 bg-blue-600 rounded-xl flex items-center justify-center">
              <%= Map.get(@available_templates, @portfolio.theme || "executive", %{icon: "💼"}).icon %>
            </div>
            <div>
              <h3 class="text-xl font-semibold text-blue-900 mb-1">
                Current Template: <%= String.capitalize(@portfolio.theme || "executive") %>
              </h3>
              <p class="text-blue-700">
                <%= Map.get(@available_templates, @portfolio.theme || "executive", %{description: "Professional template"}).description %>
              </p>
            </div>
          </div>
        </div>

        <!-- Template Selection Grid -->
        <div class="mb-12">
          <h3 class="text-2xl font-semibold text-gray-900 mb-6">Choose Template</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            <%= for {template_key, template_info} <- @available_templates do %>
              <div class="template-card-wrapper">
                <input type="radio"
                      name="template_selection"
                      value={template_key}
                      id={"template-#{template_key}"}
                      checked={@portfolio.theme == template_key}
                      phx-click="select_template"
                      phx-value-template={template_key}
                      class="sr-only" />

                <label for={"template-#{template_key}"} class="template-card block cursor-pointer">
                  <!-- Selected badge -->
                  <div class="template-selected-badge absolute top-3 right-3 z-10">
                    <div class="w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-sm font-bold">
                      ✓
                    </div>
                  </div>

                  <!-- Template preview -->
                  <div class={[
                    "template-preview h-24 rounded-t-lg bg-gradient-to-br flex items-center justify-center relative overflow-hidden",
                    template_info.preview_color
                  ]}>
                    <div class="template-icon text-2xl z-10 relative">
                      <%= template_info.icon %>
                    </div>
                    <!-- Decorative overlay -->
                    <div class="absolute inset-0 bg-black bg-opacity-20"></div>
                  </div>

                  <!-- Template info -->
                  <div class="p-4 bg-white rounded-b-lg">
                    <h4 class="font-semibold text-gray-900 mb-2"><%= template_info.name %></h4>
                    <p class="text-sm text-gray-600 mb-3 line-clamp-2"><%= template_info.description %></p>

                    <div class="flex flex-wrap gap-1">
                      <%= for feature <- Enum.take(template_info.features || [], 2) do %>
                        <span class="inline-block px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded-full">
                          <%= feature %>
                        </span>
                      <% end %>
                    </div>
                  </div>
                </label>
              </div>
            <% end %>
          </div>
        </div>

        <%= if @portfolio.theme == "executive" do %>
          <div class="stats-editor bg-gray-50 rounded-lg p-6 mb-8">
            <h4 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
              <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 002 2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
              </svg>
              Executive Dashboard Statistics
            </h4>
            <p class="text-gray-600 mb-6">Customize the key metrics displayed on your executive dashboard.</p>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <%= for {stat_name, stat_value} <- get_executive_stats(@customization) do %>
                <div class="stat-item bg-white p-4 rounded-lg border border-gray-200">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    <%= format_stat_label(stat_name) %>
                  </label>

                  <input type="text"
                        value={stat_value}
                        phx-blur="update_stats"
                        phx-value-stat_name={stat_name}
                        placeholder="Enter value (e.g., 150, $2.5M, 95%)"
                        class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Customization Panel -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-8">
            <%= if @portfolio.theme == "executive" do %>
              <%= render_stats_editor(assigns) %>
            <% end %>
          <h3 class="text-2xl font-semibold text-gray-900 mb-8">Customization Options</h3>

          <div class="space-y-10">
            <!-- Color Scheme Section -->
            <div class="pb-8 border-b border-gray-200">
              <h4 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                <div class="w-8 h-8 bg-gradient-to-r from-pink-500 to-purple-500 rounded-lg mr-3"></div>
                Color Scheme
              </h4>
              <p class="text-gray-600 mb-6">Choose your primary brand color to customize the template appearance.</p>

              <div class="grid grid-cols-3 sm:grid-cols-6 lg:grid-cols-9 gap-4">
                <%= for {color_name, color_value} <- [
                  {"Purple", "#8b5cf6"}, {"Blue", "#3b82f6"}, {"Green", "#10b981"},
                  {"Red", "#ef4444"}, {"Orange", "#f97316"}, {"Pink", "#ec4899"},
                  {"Indigo", "#6366f1"}, {"Teal", "#14b8a6"}, {"Cyan", "#06b6d4"},
                  {"Emerald", "#059669"}, {"Amber", "#f59e0b"}, {"Rose", "#f43f5e"}
                ] do %>
                  <label class="color-option relative cursor-pointer group">
                    <input type="radio"
                          name="primary_color"
                          value={color_value}
                          checked={get_current_primary_color(@customization) == color_value}
                          phx-click="update_color"
                          phx-value-color={color_value}
                          phx-value-name={color_name}
                          class="sr-only" />

                    <div class="color-swatch w-12 h-12 rounded-xl border-4 border-transparent group-hover:scale-110 transition-all duration-200"
                        style={"background-color: #{color_value}"}>
                      <div class="w-full h-full rounded-lg flex items-center justify-center">
                        <svg class="w-4 h-4 text-white opacity-0 group-hover:opacity-100 transition-opacity"
                            fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                        </svg>
                      </div>
                    </div>

                    <div class="text-center mt-2">
                      <span class="text-xs text-gray-600 font-medium"><%= color_name %></span>
                    </div>
                  </label>
                <% end %>
              </div>
            </div>

            <!-- Typography Section -->
            <div class="pb-8 border-b border-gray-200">
              <h4 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                <div class="w-8 h-8 bg-gradient-to-r from-gray-700 to-gray-900 rounded-lg mr-3 flex items-center justify-center">
                  <span class="text-white text-sm font-bold">Aa</span>
                </div>
                Typography
              </h4>
              <p class="text-gray-600 mb-6">Select the font style that best represents your professional brand.</p>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <%= for {font_key, font_name, sample_text, preview_class} <- [
                  {"inter", "Inter", "Modern and professional", "font-sans"},
                  {"merriweather", "Merriweather", "Classic and readable", "font-serif"},
                  {"roboto", "Roboto Mono", "Technical and precise", "font-mono"},
                  {"playfair", "Playfair Display", "Elegant and creative", "font-serif"}
                ] do %>
                  <label class="font-option cursor-pointer">
                    <input type="radio"
                          name="font_style"
                          value={font_key}
                          checked={get_current_font_style(@customization) == font_key}
                          phx-click="update_font_style"
                          phx-value-font={font_key}
                          class="sr-only" />

                    <div class="font-sample p-6 border-2 border-gray-200 rounded-xl hover:border-blue-300 transition-all duration-200 bg-white hover:shadow-md">
                      <div class="flex items-center justify-between mb-3">
                        <h5 class="font-semibold text-gray-900"><%= font_name %></h5>
                        <div class="w-5 h-5 border-2 border-gray-300 rounded-full flex items-center justify-center">
                          <div class="w-2 h-2 bg-blue-600 rounded-full opacity-0 transition-opacity"></div>
                        </div>
                      </div>
                      <div class={["text-gray-600 mb-2", preview_class]}>
                        <%= sample_text %>
                      </div>
                      <div class={["text-sm text-gray-500", preview_class]}>
                        The quick brown fox jumps over the lazy dog
                      </div>
                    </div>
                  </label>
                <% end %>
              </div>
            </div>

            <!-- Layout Options Section -->
            <div class="pb-8 border-b border-gray-200">
              <h4 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                <div class="w-8 h-8 bg-gradient-to-r from-blue-500 to-indigo-500 rounded-lg mr-3 flex items-center justify-center">
                  <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"/>
                  </svg>
                </div>
                Layout Options
              </h4>
              <p class="text-gray-600 mb-6">Configure layout behavior and spacing preferences.</p>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                <!-- Section Spacing -->
                <div>
                  <label class="block text-sm font-semibold text-gray-800 mb-4">Section Spacing</label>
                  <div class="space-y-3">
                    <%= for {spacing_key, spacing_label, spacing_desc} <- [
                      {"compact", "Compact", "Tight spacing for content-heavy portfolios"},
                      {"normal", "Normal", "Balanced spacing for most use cases"},
                      {"spacious", "Spacious", "Generous spacing for visual impact"}
                    ] do %>
                      <label class="spacing-option flex items-center cursor-pointer">
                        <input type="radio"
                              name="section_spacing"
                              value={spacing_key}
                              checked={get_current_section_spacing(@customization) == spacing_key}
                              phx-click="update_section_spacing"
                              phx-value-spacing={spacing_key}
                              class="sr-only" />

                        <div class="spacing-button flex items-center p-4 border-2 border-gray-200 rounded-lg hover:border-blue-300 transition-all duration-200 w-full">
                          <div class="spacing-visual mr-4">
                            <div class={["flex flex-col",
                              case spacing_key do
                                "compact" -> "space-y-1"
                                "normal" -> "space-y-2"
                                "spacious" -> "space-y-3"
                              end
                            ]}>
                              <div class="w-8 h-1 bg-current opacity-60 rounded"></div>
                              <div class="w-8 h-1 bg-current opacity-60 rounded"></div>
                              <div class="w-8 h-1 bg-current opacity-60 rounded"></div>
                            </div>
                          </div>
                          <div class="flex-1">
                            <div class="font-medium text-gray-900 mb-1"><%= spacing_label %></div>
                            <div class="text-sm text-gray-600"><%= spacing_desc %></div>
                          </div>
                          <div class="w-5 h-5 border-2 border-gray-300 rounded-full flex items-center justify-center ml-3">
                            <div class="w-2 h-2 bg-blue-600 rounded-full opacity-0 transition-opacity"></div>
                          </div>
                        </div>
                      </label>
                    <% end %>
                  </div>
                </div>

                <!-- Advanced Options -->
                <div>
                  <label class="block text-sm font-semibold text-gray-800 mb-4">Advanced Options</label>
                  <div class="space-y-4">
                    <!-- Fixed Navigation Toggle -->
                    <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
                      <div class="flex-1">
                        <h5 class="font-medium text-gray-900 mb-1">Fixed Navigation</h5>
                        <p class="text-sm text-gray-600">Keep navigation visible while scrolling</p>
                      </div>
                      <label class="toggle-switch">
                        <input type="checkbox"
                              checked={get_current_layout_option(@customization, "fixed_navigation", true)}
                              phx-click="update_layout_option"
                              phx-value-option="fixed_navigation"
                              phx-value-value={!get_current_layout_option(@customization, "fixed_navigation", true)} />

                        <input type="checkbox"
                              checked={get_current_layout_option(@customization, "dark_mode_support", false)}
                              phx-click="update_layout_option"
                              phx-value-option="dark_mode_support"
                              phx-value-value={!get_current_layout_option(@customization, "dark_mode_support", false)} />
                        <span class="toggle-slider"></span>
                      </label>
                    </div>

                    <!-- Dark Mode Support Toggle -->
                    <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
                      <div class="flex-1">
                        <h5 class="font-medium text-gray-900 mb-1">Dark Mode Support</h5>
                        <p class="text-sm text-gray-600">Enable automatic dark mode detection</p>
                      </div>
                      <label class="toggle-switch">
                        <input type="checkbox"
                              checked={Map.get(@customization, "dark_mode_support", false)}
                              phx-click="update_layout_option"
                              phx-value-option="dark_mode_support"
                              phx-value-value={!Map.get(@customization, "dark_mode_support", false)} />
                        <span class="toggle-slider"></span>
                      </label>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Action Buttons -->
            <div class="flex justify-between items-center pt-6">
              <button phx-click="reset_customization"
                      class="inline-flex items-center px-6 py-3 border border-gray-300 rounded-lg text-gray-700 font-semibold hover:bg-gray-50 transition-all duration-200">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                </svg>
                Reset to Defaults
              </button>

              <div class="flex space-x-3">
                <button phx-click="preview_changes"
                        class="inline-flex items-center px-6 py-3 border border-blue-300 rounded-lg text-blue-700 font-semibold hover:bg-blue-50 transition-all duration-200">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                  </svg>
                  Preview Changes
                </button>

                <button phx-click="save_customization"
                        class="inline-flex items-center px-6 py-3 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700 transition-all duration-200">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                  Save Changes
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <style>
      .template-card-wrapper {
        position: relative;
      }

      .template-card {
        border: 2px solid #e5e7eb;
        border-radius: 12px;
        overflow: hidden;
        transition: all 0.3s ease;
        transform: translateY(0);
      }

      .template-card:hover {
        border-color: #3b82f6;
        transform: translateY(-4px);
        box-shadow: 0 8px 25px rgba(59, 130, 246, 0.15);
      }

      input[type="radio"]:checked + .template-card {
        border-color: #3b82f6;
        background: #f8fafc;
        box-shadow: 0 8px 25px rgba(59, 130, 246, 0.15);
      }

      .template-selected-badge {
        opacity: 0;
        transition: opacity 0.3s ease;
      }

      input[type="radio"]:checked + .template-card .template-selected-badge {
        opacity: 1;
      }

      .color-option input:checked + .color-swatch {
        border-color: #1f2937;
        box-shadow: 0 0 0 2px #1f2937;
        transform: scale(1.1);
      }

      .font-option input:checked + .font-sample {
        border-color: #3b82f6;
        background: #f8fafc;
        box-shadow: 0 4px 12px rgba(59, 130, 246, 0.15);
      }

      .font-option input:checked + .font-sample .w-2 {
        opacity: 1;
      }

      .spacing-option input:checked + .spacing-button {
        border-color: #3b82f6;
        background: #f8fafc;
        color: #3b82f6;
      }

      .spacing-option input:checked + .spacing-button .w-2 {
        opacity: 1;
      }

      .line-clamp-2 {
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
      }
    </style>
    """
  end

  defp render_settings_tab(assigns) do
    ~H"""
    <div class="p-8">
      <h2 class="text-xl font-bold text-gray-900 mb-6">Portfolio Settings</h2>

      <div class="space-y-8">
        <!-- Visibility Settings -->
        <div>
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Visibility & Privacy</h3>
          <div class="bg-gray-50 rounded-lg p-6">
            <div class="space-y-4">
              <%= for {visibility_key, title, description, icon} <- [
                {:public, "Public", "Anyone can find and view your portfolio", "M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064"},
                {:link_only, "Link Only", "Only people with the link can view", "M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"},
                {:private, "Private", "Only you can view (portfolio is hidden)", "M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"}
              ] do %>
                <label class="flex items-start space-x-3 cursor-pointer">
                  <input type="radio"
                         name="visibility"
                         value={visibility_key}
                         checked={@portfolio.visibility == visibility_key}
                         phx-click="update_visibility"
                         phx-value-visibility={visibility_key}
                         class="mt-1 text-blue-600" />
                  <div class="flex-1">
                    <div class="flex items-center space-x-2">
                      <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={icon}/>
                      </svg>
                      <span class="font-medium text-gray-900"><%= title %></span>
                    </div>
                    <p class="text-sm text-gray-600 mt-1"><%= description %></p>
                  </div>
                </label>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Export Settings -->
        <div>
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Export & Sharing</h3>
          <div class="bg-gray-50 rounded-lg p-6">
            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <div>
                  <h4 class="font-medium text-gray-900">Allow Resume Export</h4>
                  <p class="text-sm text-gray-600">Let visitors download a PDF version of your portfolio</p>
                </div>
                <label class="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox"
                         checked={@portfolio.allow_resume_export}
                         phx-click="toggle_resume_export"
                         class="sr-only peer" />
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                </label>
              </div>

              <div class="flex items-center justify-between">
                <div>
                  <h4 class="font-medium text-gray-900">Require Approval for Comments</h4>
                  <p class="text-sm text-gray-600">Review feedback before it appears publicly</p>
                </div>
                <label class="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox"
                         checked={@portfolio.require_approval}
                         phx-click="toggle_approval_required"
                         class="sr-only peer" />
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                </label>
              </div>
            </div>
          </div>
        </div>

        <!-- Danger Zone -->
        <div>
          <h3 class="text-lg font-semibold text-red-900 mb-4">Danger Zone</h3>
          <div class="bg-red-50 border border-red-200 rounded-lg p-6">
            <div class="space-y-4">
              <div>
                <h4 class="font-medium text-red-900 mb-2">Delete Portfolio</h4>
                <p class="text-sm text-red-700 mb-4">
                  Once you delete a portfolio, there is no going back. Please be certain.
                </p>
                <button phx-click="delete_portfolio"
                        data-confirm="Are you absolutely sure? This action cannot be undone."
                        class="bg-red-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-red-700 transition-colors">
                  Delete This Portfolio
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_section_editor(assigns) do
    # Get the section being edited
    section = Enum.find(assigns.sections, &(to_string(&1.id) == assigns.section_edit_id))
    section_media = Portfolios.list_section_media(section.id)

    # FIXED: Use assign/3 multiple times instead of assign/5
    assigns =
      assigns
      |> assign(:editing_section, section)
      |> assign(:section_media, section_media)

    ~H"""
    <div>
      <!-- Editor Header -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <h2 class="text-xl font-bold text-gray-900">Edit Section</h2>
          <p class="text-sm text-gray-600 mt-1">
            Editing: <span class="font-medium"><%= @editing_section.title %></span>
            (<%= format_section_type(@editing_section.section_type) %>)
          </p>
        </div>

        <div class="flex items-center space-x-3">
          <button phx-click="save_section" phx-value-id={@editing_section.id}
                  class="bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 transition-colors">
            Save Changes
          </button>

          <button phx-click="cancel_edit"
                  class="bg-gray-300 text-gray-700 px-4 py-2 rounded-lg font-semibold hover:bg-gray-400 transition-colors">
            Cancel
          </button>
        </div>
      </div>

      <!-- Section Form -->
      <div class="bg-white rounded-xl border border-gray-200 p-6 space-y-8">
        <!-- Basic Section Info -->
        <div>
          <label class="block text-sm font-semibold text-gray-800 mb-2">Section Title</label>
          <input type="text"
                value={@editing_section.title}
                phx-blur="update_section_field"
                phx-value-field="title"
                phx-value-section-id={@editing_section.id}
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
        </div>

        <!-- Section-specific content editor -->
        <%= render_section_content_editor(@editing_section, assigns) %>

        <!-- Media Management Section -->
        <div class="border-t border-gray-200 pt-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Media Files</h3>

          <!-- File Upload Area -->
          <div class="mb-6">
            <form phx-submit="upload_media" phx-value-section_id={@editing_section.id} phx-change="validate_upload">
              <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-gray-400 transition-colors">
                <div class="space-y-2">
                  <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                    <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                  </svg>
                  <div class="text-gray-600">
                    <label for="media-upload" class="cursor-pointer">
                      <span class="mt-2 block text-sm font-medium text-gray-900">
                        Click to upload or drag and drop
                      </span>
                      <span class="mt-1 block text-xs text-gray-500">
                        Images, videos, audio, or documents up to <%= @limits.max_media_size_mb %>MB
                      </span>
                    </label>
                    <input id="media-upload"
                          type="file"
                          phx-hook="FileUpload"
                          multiple
                          accept="image/*,video/*,audio/*,.pdf,.doc,.docx"
                          class="sr-only" />
                  </div>
                </div>
              </div>

              <!-- Upload progress -->
              <%= for entry <- @uploads.media.entries do %>
                <div class="mt-2 flex items-center">
                  <div class="flex-1">
                    <div class="text-sm text-gray-600"><%= entry.client_name %></div>
                    <div class="w-full bg-gray-200 rounded-full h-2">
                      <div class="bg-blue-600 h-2 rounded-full transition-all duration-300"
                          style={"width: #{entry.progress}%"}></div>
                    </div>
                  </div>
                  <button type="button"
                          phx-click="cancel_upload"
                          phx-value-ref={entry.ref}
                          class="ml-2 text-red-600 hover:text-red-800">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                  </button>
                </div>
              <% end %>

              <%= if length(@uploads.media.entries) > 0 do %>
                <button type="submit"
                        class="mt-4 w-full bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors">
                  Upload <%= length(@uploads.media.entries) %> File(s)
                </button>
              <% end %>
            </form>
          </div>

          <!-- Existing Media Files -->
          <%= if length(@section_media) > 0 do %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
                id={"media-list-#{@editing_section.id}"}
                phx-hook="MediaSortable"
                data-section-id={@editing_section.id}>
              <%= for media <- Enum.sort_by(@section_media, & &1.position) do %>
                <div class="border border-gray-200 rounded-lg p-4 bg-gray-50 cursor-move" data-media-id={media.id}>
                  <!-- Media Preview -->
                  <div class="mb-3 relative">
                    <%= case media.media_type do %>
                      <% "image" -> %>
                        <img src={media.file_path}
                            alt={media.title || "Image"}
                            class="w-full h-32 object-cover rounded" />

                      <% "video" -> %>
                        <video class="w-full h-32 object-cover rounded" controls>
                          <source src={media.file_path} type={media.mime_type} />
                        </video>

                      <% "audio" -> %>
                        <div class="w-full h-32 bg-gray-200 rounded flex items-center justify-center">
                          <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"/>
                          </svg>
                        </div>
                        <audio controls class="w-full mt-2">
                          <source src={media.file_path} type={media.mime_type} />
                        </audio>

                      <% _ -> %>
                        <div class="w-full h-32 bg-gray-200 rounded flex items-center justify-center">
                          <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                          </svg>
                        </div>
                    <% end %>

                    <!-- Visibility Toggle -->
                    <div class="absolute top-2 right-2">
                      <button phx-click="toggle_media_visibility"
                              phx-value-media_id={media.id}
                              class={[
                                "p-1 rounded-full text-xs",
                                if(media.visible, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800")
                              ]}
                              title={if(media.visible, do: "Click to hide", else: "Click to show")}>
                        <%= if media.visible do %>
                          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                          </svg>
                        <% else %>
                          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
                          </svg>
                        <% end %>
                      </button>
                    </div>
                  </div>

                  <!-- Media Info -->
                  <div class="space-y-2">
                    <input type="text"
                          value={media.title || ""}
                          phx-blur="update_media"
                          phx-value-media_id={media.id}
                          phx-value-field="title"
                          placeholder="Media title"
                          class="w-full text-sm px-2 py-1 border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />

                    <textarea phx-blur="update_media"
                              phx-value-media_id={media.id}
                              phx-value-field="description"
                              placeholder="Description..."
                              rows="2"
                              class="w-full text-sm px-2 py-1 border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"><%= media.description || "" %></textarea>

                    <div class="flex items-center justify-between text-xs text-gray-500">
                      <span><%= format_file_size(media.file_size || 0) %></span>
                      <div class="flex items-center space-x-2">
                        <span class={[
                          "px-2 py-1 rounded text-xs",
                          if(media.visible, do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-500")
                        ]}>
                          <%= if media.visible, do: "Visible", else: "Hidden" %>
                        </span>
                        <button phx-click="delete_media"
                                phx-value-media_id={media.id}
                                data-confirm="Are you sure you want to delete this media file?"
                                class="text-red-600 hover:text-red-800">
                          Delete
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <div class="text-center py-8 text-gray-500">
              <svg class="mx-auto h-12 w-12 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
              </svg>
              <p class="mt-2">No media files uploaded yet</p>
              <p class="text-sm">Upload images, videos, or documents to enhance this section</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_section_content_editor(%{section_type: :intro} = section, assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Headline</label>
        <input type="text"
              value={get_in(section.content, ["headline"]) || ""}
              phx-blur="update_section_content"
              phx-value-field="headline"
              phx-value-section-id={section.id}
              placeholder="Hello, I'm [Your Name]"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Summary</label>
        <textarea phx-blur="update_section_content"
                  phx-value-field="summary"
                  phx-value-section-id={section.id}
                  rows="4"
                  placeholder="A brief introduction about yourself and your professional journey..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= get_in(section.content, ["summary"]) || "" %></textarea>
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Location</label>
        <input type="text"
              value={get_in(section.content, ["location"]) || ""}
              phx-blur="update_section_content"
              phx-value-field="location"
              phx-value-section-id={section.id}
              placeholder="City, State/Country"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      </div>
    </div>
    """
  end

  # CONTACT section editor
  defp render_section_content_editor(%{section_type: :contact} = section, assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-semibold text-gray-800 mb-2">Email</label>
          <input type="email"
                value={get_in(section.content, ["email"]) || ""}
                phx-blur="update_section_content"
                phx-value-field="email"
                phx-value-section-id={section.id}
                placeholder="your.email@example.com"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-800 mb-2">Phone</label>
          <input type="tel"
                value={get_in(section.content, ["phone"]) || ""}
                phx-blur="update_section_content"
                phx-value-field="phone"
                phx-value-section-id={section.id}
                placeholder="+1 (555) 123-4567"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Location</label>
        <input type="text"
              value={get_in(section.content, ["location"]) || ""}
              phx-blur="update_section_content"
              phx-value-field="location"
              phx-value-section-id={section.id}
              placeholder="City, State/Country"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      </div>
    </div>
    """
  end

  # EXPERIENCE section editor
  defp render_section_content_editor(%{section_type: :experience} = section, assigns) do
    jobs = get_in(section.content, ["jobs"]) || []
    assigns = assign(assigns, :jobs, jobs)

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <label class="block text-sm font-semibold text-gray-800">Work Experience</label>
        <button type="button"
                class="text-sm bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700"
                onclick="addJob()">
          Add Job
        </button>
      </div>

      <div id="jobs-list" class="space-y-4">
        <%= for {job, index} <- Enum.with_index(@jobs) do %>
          <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-3">
              <input type="text"
                    value={Map.get(job, "title", "")}
                    placeholder="Job Title"
                    phx-blur="update_job_field"
                    phx-value-section-id={section.id}
                    phx-value-job-index={index}
                    phx-value-field="title"
                    class="px-3 py-2 border border-gray-300 rounded focus:ring-2 focus:ring-blue-500" />

              <input type="text"
                    value={Map.get(job, "company", "")}
                    placeholder="Company Name"
                    phx-blur="update_job_field"
                    phx-value-section-id={section.id}
                    phx-value-job-index={index}
                    phx-value-field="company"
                    class="px-3 py-2 border border-gray-300 rounded focus:ring-2 focus:ring-blue-500" />
            </div>

            <textarea placeholder="Job description and key achievements..."
                      phx-blur="update_job_field"
                      phx-value-section-id={section.id}
                      phx-value-job-index={index}
                      phx-value-field="description"
                      rows="3"
                      class="w-full px-3 py-2 border border-gray-300 rounded focus:ring-2 focus:ring-blue-500"><%= Map.get(job, "description", "") %></textarea>
          </div>
        <% end %>
      </div>

      <%= if length(@jobs) == 0 do %>
        <div class="text-center py-8 text-gray-500">
          <p>No work experience added yet.</p>
          <button type="button"
                  class="mt-2 bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
                  onclick="addJob()">
            Add Your First Job
          </button>
        </div>
      <% end %>
    </div>

    <script>
      function addJob() {
        // This would be handled by a LiveView event in a real implementation
        console.log('Add job functionality - implement with LiveView event');
      }
    </script>
    """
  end

  # SKILLS section editor
  defp render_section_content_editor(%{section_type: :skills} = section, assigns) do
    skills = get_in(section.content, ["skills"]) || []
    assigns = assign(assigns, :skills, skills)

    ~H"""
    <div class="space-y-4">
      <label class="block text-sm font-semibold text-gray-800">Skills & Expertise</label>

      <div>
        <textarea phx-blur="update_section_content"
                  phx-value-field="skills_text"
                  phx-value-section-id={section.id}
                  rows="6"
                  placeholder="Enter your skills, one per line or separated by commas..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= format_skills_for_editing(@skills) %></textarea>
      </div>

      <div class="text-sm text-gray-600 bg-blue-50 border border-blue-200 rounded-lg p-3">
        <p><strong>Tips:</strong> Enter each skill on a new line or separate with commas. You can include proficiency levels like "JavaScript - Expert" or "Project Management - Advanced".</p>
      </div>

      <%= if length(@skills) > 0 do %>
        <div class="mt-4">
          <p class="text-sm font-medium text-gray-700 mb-2">Current skills:</p>
          <div class="flex flex-wrap gap-2">
            <%= for skill <- @skills do %>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                <%= format_skill_display(skill) %>
              </span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # PROJECTS section editor
  defp render_section_content_editor(%{section_type: :projects} = section, assigns) do
    projects = get_in(section.content, ["projects"]) || []
    assigns = assign(assigns, :projects, projects)

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <label class="block text-sm font-semibold text-gray-800">Projects</label>
      </div>

      <div>
        <textarea phx-blur="update_section_content"
                  phx-value-field="projects_summary"
                  phx-value-section-id={section.id}
                  rows="6"
                  placeholder="Describe your key projects and achievements..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= get_projects_summary(section) %></textarea>
      </div>

      <div class="text-sm text-gray-600 bg-blue-50 border border-blue-200 rounded-lg p-3">
        <p><strong>Projects Section:</strong> Describe your key projects, what technologies you used, and what impact they had. Include links to demos or repositories if available.</p>
      </div>
    </div>
    """
  end

  # Generic editor for other section types
  defp render_section_content_editor(section, assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Content</label>
        <textarea phx-blur="update_section_content"
                  phx-value-field="main_content"
                  phx-value-section-id={section.id}
                  rows="6"
                  placeholder="Add content for this section..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= get_section_main_content(section) %></textarea>
      </div>

      <div class="text-sm text-gray-600 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <p><strong>Section Type:</strong> <%= format_section_type(section.section_type) %></p>
        <p class="mt-1">This is a simplified editor. For advanced customization, specific editors for each section type can be implemented.</p>
      </div>
    </div>
    """
  end

  defp render_resume_upload_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="text-center">
        <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
          <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">Upload Resume</h3>
        <p class="mt-1 text-sm text-gray-500">Select a PDF, DOC, or DOCX file to import</p>
      </div>

      <form phx-submit="upload_resume" phx-change="validate_resume" class="mt-4">
        <input type="file" name="resume" accept=".pdf,.doc,.docx" required class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100" />

        <div class="mt-4 flex justify-end">
          <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
            Parse Resume
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp render_parsed_resume_data(assigns) do
    ~H"""
    <div class="space-y-6">
      <h4 class="text-lg font-medium text-gray-900">Parsed Resume Sections</h4>

      <div :for={{section_type, content} <- @parsed_resume_data} class="border border-gray-200 rounded-lg p-4">
        <div class="flex justify-between items-start mb-3">
          <h5 class="font-medium text-gray-800 capitalize">{String.replace(section_type, "_", " ")}</h5>
          <select name={"mapping[#{section_type}]"} class="text-sm border rounded px-2 py-1">
            <option value="new">Create New Section</option>
            <option value="skip">Skip This Section</option>
            <!-- Add existing section options here -->
          </select>
        </div>

        <div class="text-sm text-gray-600 bg-gray-50 rounded p-3 max-h-32 overflow-y-auto">
          {String.slice(content, 0, 200)}<span :if={String.length(content) > 200}>...</span>
        </div>
      </div>

      <div class="flex justify-end space-x-3 pt-4 border-t">
        <button phx-click="hide_resume_import" class="px-4 py-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors">
          Cancel
        </button>
        <button phx-click="import_resume_sections" class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors">
          Import Sections
        </button>
      </div>
    </div>
    """
  end

  # Helper functions for section editors
  defp get_section_main_content(section) do
    case section.section_type do
      :intro ->
        summary = get_in(section.content, ["summary"]) || ""
        headline = get_in(section.content, ["headline"]) || ""
        if String.length(headline) > 0 and String.length(summary) > 0 do
          "#{headline}\n\n#{summary}"
        else
          headline <> summary
        end

      :experience ->
        jobs = get_in(section.content, ["jobs"]) || []
        if length(jobs) > 0 do
          Enum.map_join(jobs, "\n\n", fn job ->
            "#{Map.get(job, "title", "")} at #{Map.get(job, "company", "")}\n#{Map.get(job, "description", "")}"
          end)
        else
          ""
        end

      :skills ->
        skills = get_in(section.content, ["skills"]) || []
        format_skills_for_editing(skills)

      :projects ->
        get_projects_summary(section)

      :contact ->
        email = get_in(section.content, ["email"]) || ""
        phone = get_in(section.content, ["phone"]) || ""
        location = get_in(section.content, ["location"]) || ""
        [email, phone, location] |> Enum.filter(&(String.length(&1) > 0)) |> Enum.join("\n")

      _ ->
        # For other section types, try to extract any text content
        case section.content do
          %{"content" => content} when is_binary(content) -> content
          %{"description" => desc} when is_binary(desc) -> desc
          %{"summary" => summary} when is_binary(summary) -> summary
          _ -> ""
        end
    end
  end

  defp format_skills_for_editing(skills) when is_list(skills) do
    Enum.map_join(skills, "\n", fn skill ->
      case skill do
        %{"name" => name, "level" => level} -> "#{name} - #{level}"
        %{"name" => name} -> name
        skill when is_binary(skill) -> skill
        _ -> ""
      end
    end)
  end
  defp format_skills_for_editing(_), do: ""

  defp format_skill_display(skill) do
    case skill do
      %{"name" => name, "level" => level} -> "#{name} (#{level})"
      %{"name" => name} -> name
      skill when is_binary(skill) -> skill
      _ -> "Skill"
    end
  end

  defp get_projects_summary(section) do
    projects = get_in(section.content, ["projects"]) || []
    case projects do
      [] -> get_in(section.content, ["description"]) || ""
      projects when is_list(projects) ->
        Enum.map_join(projects, "\n\n", fn project ->
          case project do
            %{"name" => name, "description" => desc} -> "#{name}\n#{desc}"
            %{"title" => title, "description" => desc} -> "#{title}\n#{desc}"
            project when is_binary(project) -> project
            _ -> ""
          end
        end)
      _ -> ""
    end
  end

  # Helper functions
  defp get_default_section_title(section_type) do
    case section_type do
      "intro" -> "Introduction"
      "experience" -> "Work Experience"
      "education" -> "Education"
      "skills" -> "Skills & Expertise"
      "featured_project" -> "Featured Project"
      "case_study" -> "Case Study"
      "media_showcase" -> "Media Showcase"
      "contact" -> "Contact Information"
      _ -> "New Section"
    end
  end

  defp format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      :experience -> "Work Experience"
      :education -> "Education"
      :skills -> "Skills & Expertise"
      :featured_project -> "Featured Project"
      :case_study -> "Case Study"
      :media_showcase -> "Media Showcase"
      :testimonial -> "Testimonials"
      :contact -> "Contact Information"
      _ -> String.capitalize(to_string(section_type)) |> String.replace("_", " ")
    end
  end

  defp get_section_content_summary(section) do
    case section.section_type do
      :intro ->
        summary = get_in(section.content, ["summary"]) || get_in(section.content, ["headline"])
        if summary && String.length(summary) > 50 do
          "#{String.slice(summary, 0, 50)}..."
        else
          summary || "No content yet"
        end

      :experience ->
        jobs_count = length(get_in(section.content, ["jobs"]) || [])
        "#{jobs_count} work experiences"

      :education ->
        edu_count = length(get_in(section.content, ["education"]) || [])
        "#{edu_count} educational backgrounds"

      :skills ->
        skills_count = length(get_in(section.content, ["skills"]) || [])
        "#{skills_count} skills listed"

      :projects ->
        projects_count = length(get_in(section.content, ["projects"]) || [])
        "#{projects_count} projects"

      :featured_project ->
        title = get_in(section.content, ["title"])
        if title && String.length(title) > 0, do: title, else: "Project details"

      :case_study ->
        client = get_in(section.content, ["client"]) || get_in(section.content, ["project_title"])
        if client && String.length(client) > 0 do
          "Case study: #{client}"
        else
          "Case study details"
        end

      :achievements ->
        achievements_count = length(get_in(section.content, ["achievements"]) || [])
        "#{achievements_count} achievements"

      :testimonial ->
        testimonials_count = length(get_in(section.content, ["testimonials"]) || [])
        "#{testimonials_count} testimonials"

      :media_showcase ->
        title = get_in(section.content, ["title"])
        if title && String.length(title) > 0 do
          "Media: #{title}"
        else
          "Media showcase"
        end

      :code_showcase ->
        title = get_in(section.content, ["title"])
        language = get_in(section.content, ["language"])
        if title && String.length(title) > 0 do
          language_part = if language && String.length(language) > 0, do: " (#{language})", else: ""
          "#{title}#{language_part}"
        else
          "Code showcase"
        end

      :contact ->
        email = get_in(section.content, ["email"])
        phone = get_in(section.content, ["phone"])
        contact_count = Enum.count([email, phone], &(&1 && String.length(&1) > 0))
        "#{contact_count} contact methods"

      :custom ->
        title = get_in(section.content, ["title"])
        if title && String.length(title) > 0 do
          title
        else
          "Custom content"
        end

      _ ->
        "Portfolio section"
    end
  end

  defp get_section_emoji(section_type) do
    case section_type do
      :intro -> "👋"
      :experience -> "💼"
      :education -> "🎓"
      :skills -> "⚡"
      :projects -> "🚀"
      :featured_project -> "⭐"
      :case_study -> "📊"
      :achievements -> "🏆"
      :testimonial -> "💬"
      :media_showcase -> "🎨"
      :code_showcase -> "💻"
      :contact -> "📧"
      :custom -> "📋"
      _ -> "📄"
    end
  end

  # Enhanced reorder sections handler
  @impl true
  def handle_event("reorder_sections", %{"sections" => section_order}, socket) do
    IO.puts("Reordering sections: #{inspect(section_order)}")

    # Update section positions based on new order
    results = Enum.with_index(section_order, 1)
    |> Enum.map(fn {section_id_str, position} ->
      try do
        section_id = String.to_integer(section_id_str)
        section = Portfolios.get_section!(section_id)

        # Verify section belongs to this portfolio
        if section.portfolio_id == socket.assigns.portfolio.id do
          case Portfolios.update_section(section, %{"position" => position}) do
            {:ok, _} -> {:ok, section_id}
            {:error, reason} -> {:error, {section_id, reason}}
          end
        else
          {:error, {section_id, "unauthorized"}}
        end
      rescue
        e -> {:error, {section_id_str, Exception.message(e)}}
      end
    end)

    # Check results
    errors = Enum.filter(results, &match?({:error, _}, &1))

    if length(errors) > 0 do
      IO.puts("Section reordering errors: #{inspect(errors)}")
      {:noreply, put_flash(socket, :error, "Failed to reorder some sections")}
    else
      # Refresh sections with new order
      sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

      {:noreply,
      socket
      |> assign(:sections, sections)
      |> assign(:unsaved_changes, true)
      |> put_flash(:info, "Section order updated successfully")}
    end
  end

  defp determine_media_type(content_type) do
    cond do
      String.starts_with?(content_type, "image/") -> "image"
      String.starts_with?(content_type, "video/") -> "video"
      String.starts_with?(content_type, "audio/") -> "audio"
      true -> "document"
    end
  end

  defp format_file_size(size) when size > 1_048_576 do
    "#{Float.round(size / 1_048_576, 1)} MB"
  end
  defp format_file_size(size) when size > 1024 do
    "#{Float.round(size / 1024, 1)} KB"
  end
  defp format_file_size(size) do
    "#{size} bytes"
  end

  defp has_section_media?(section) do
    media_files = get_section_media_preview(section)
    length(media_files) > 0
  end

  defp get_section_media_preview(section) do
    # This should integrate with your actual media system
    # For now, returning empty list as placeholder
    case Portfolios.list_section_media(section.id) do
      media_list when is_list(media_list) -> Enum.take(media_list, 4)
      _ -> []
    end
  rescue
    _ -> []
  end

  defp get_section_media_count(section) do
    length(get_section_media_preview(section))
  end

  defp get_media_url(media) do
    # This should integrate with your actual media URL generation
    case media do
      %{file_path: file_path} when not is_nil(file_path) -> file_path
      %{filename: filename} when not is_nil(filename) -> "/uploads/#{filename}"
      _ -> "/images/placeholder.jpg"
    end
  end

  defp get_portfolio_view_count(portfolio) do
    # This should integrate with your actual analytics
    case Portfolios.get_portfolio_analytics(portfolio.id, portfolio.user_id) do
      %{total_visits: count} -> count
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp get_portfolio_media_count(portfolio) do
    # This should integrate with your actual media counting
    case Portfolios.list_portfolio_media(portfolio.id) do
      media_list when is_list(media_list) -> length(media_list)
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp get_theme_gradient(theme) do
    case theme do
      "executive" -> "from-slate-800 to-slate-900"
      "developer" -> "from-indigo-600 to-purple-600"
      "designer" -> "from-pink-500 to-rose-500"
      "consultant" -> "from-blue-600 to-cyan-600"
      "academic" -> "from-emerald-600 to-teal-600"
      "artist" -> "from-violet-600 to-purple-600"
      "entrepreneur" -> "from-orange-600 to-red-600"
      "freelancer" -> "from-green-600 to-emerald-600"
      "photographer" -> "from-gray-800 to-black"
      "writer" -> "from-amber-600 to-orange-600"
      "marketing" -> "from-fuchsia-600 to-pink-600"
      "healthcare" -> "from-blue-500 to-blue-700"
      "minimalist" -> "from-gray-600 to-gray-800"
      "creative" -> "from-purple-600 to-pink-600"
      "corporate" -> "from-blue-600 to-indigo-600"
      _ -> "from-gray-600 to-gray-800"
    end
  end

  # File type helpers
  defp get_file_type_icon(mime_type) do
    case mime_type do
      "image/" <> _ -> "🖼️"
      "video/" <> _ -> "🎥"
      "audio/" <> _ -> "🎵"
      "application/pdf" -> "📄"
      "text/" <> _ -> "📝"
      _ -> "📎"
    end
  end

  defp get_file_type_label(mime_type) do
    case mime_type do
      "image/" <> _ -> "Image"
      "video/" <> _ -> "Video"
      "audio/" <> _ -> "Audio"
      "application/pdf" -> "PDF"
      "text/" <> _ -> "Text"
      _ -> "Document"
    end
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:external_client_failure), do: "Upload failed"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

  defp format_file_size(size) when size > 1_048_576 do
    "#{Float.round(size / 1_048_576, 1)} MB"
  end

  defp format_file_size(size) when size > 1024 do
    "#{Float.round(size / 1024, 1)} KB"
  end

  defp format_file_size(size) do
    "#{size} bytes"
  end

  defp get_current_font_style(customization) do
    normalized = stringify_keys(customization || %{})
    Map.get(normalized, "font_style", "inter")
  end

  defp get_current_section_spacing(customization) do
    normalized = stringify_keys(customization || %{})
    Map.get(normalized, "section_spacing", "normal")
  end

  defp get_current_layout_option(customization, option, default) do
    normalized = stringify_keys(customization || %{})
    Map.get(normalized, option, default)
  end

  defp get_theme_classes(customization, portfolio) do
    # Normalize customization first
    normalized = normalize_customization(customization || %{})

    # Always use string keys when accessing
    primary_color = get_in(normalized, ["color_scheme", "primary"]) || "#6366f1"
    font_style = Map.get(normalized, "font_style", "inter")
    spacing = Map.get(normalized, "section_spacing", "normal")

    %{
      primary_color: primary_color,
      font_class: font_class(font_style),
      spacing_class: spacing_class(spacing),
      theme: portfolio.theme || "executive"
    }
  end

  defp font_class(font_style) do
    case font_style do
      "inter" -> "font-sans"
      "merriweather" -> "font-serif"
      "roboto" -> "font-mono"
      "playfair" -> "font-serif"
      _ -> "font-sans"
    end
  end

  defp spacing_class(spacing) do
    case spacing do
      "compact" -> "space-y-4"
      "normal" -> "space-y-6"
      "spacious" -> "space-y-8"
      _ -> "space-y-6"
    end
  end

  defp get_executive_stats(customization) do
    normalized = normalize_customization(customization || %{})
    current_stats = Map.get(normalized, "stats", %{})

    # Default executive stats
    default_stats = %{
      "portfolio_views" => "1,234",
      "projects_completed" => "47",
      "years_experience" => "8",
      "client_satisfaction" => "98%",
      "team_size" => "12",
      "revenue_generated" => "$2.5M"
    }

    Map.merge(default_stats, current_stats)
  end

  defp format_stat_label(stat_name) do
    case stat_name do
      "portfolio_views" -> "Portfolio Views"
      "projects_completed" -> "Projects Completed"
      "years_experience" -> "Years Experience"
      "client_satisfaction" -> "Client Satisfaction"
      "team_size" -> "Team Size"
      "revenue_generated" -> "Revenue Generated"
      _ -> String.capitalize(String.replace(stat_name, "_", " "))
    end
  end
end
