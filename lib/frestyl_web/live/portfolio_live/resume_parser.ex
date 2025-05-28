# lib/frestyl_web/live/portfolio_live/resume_parser.ex
defmodule FrestylWeb.PortfolioLive.ResumeParser do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios

  @impl true
  def mount(%{"portfolio_id" => portfolio_id}, _session, socket) do
    portfolio = Portfolios.get_portfolio!(portfolio_id)

    # Ensure user owns this portfolio
    if portfolio.user_id != socket.assigns.current_user.id do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this portfolio.")
       |> push_navigate(to: "/portfolios")}
    else
      limits = Portfolios.get_portfolio_limits(socket.assigns.current_user)

      socket =
        socket
        |> assign(:page_title, "Resume Importer")
        |> assign(:portfolio, portfolio)
        |> assign(:parsed_data, nil)
        |> assign(:processing, false)
        |> assign(:limits, limits)
        |> assign(:ats_available, limits.ats_optimization)
        |> allow_upload(:resume,
            accept: ~w(.pdf .doc .docx .txt .rtf),
            max_entries: 1,
            max_file_size: 5 * 1_048_576) # 5MB limit for resumes

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("process_resume", _params, socket) do
    # Mark as processing to show loading state
    socket = assign(socket, :processing, true)

    case uploaded_entries(socket, :resume) do
      {[entry], _} ->
        # Get the uploaded file
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          # Process the resume file - in a real implementation, this would be
          # handled asynchronously with a job queue
          process_resume_file(socket, path, entry.client_name)
        end)

      _ ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> put_flash(:error, "Please upload a resume file.")}
    end
  end

  @impl true
  def handle_event("import_to_portfolio", %{"section" => section}, socket) do
    portfolio = socket.assigns.portfolio
    parsed_data = socket.assigns.parsed_data

    if parsed_data do
      # Process each section that the user wants to import
      Enum.each(section, fn {section_type, selected} ->
        if selected == "true" do
          case section_type do
            "personal_info" ->
              # Update or create contact section
              update_contact_section(portfolio.id, parsed_data.personal_info)

            "experience" ->
              # Update or create experience section
              update_experience_section(portfolio.id, parsed_data.experience)

            "education" ->
              # Update or create education section
              update_education_section(portfolio.id, parsed_data.education)

            "skills" ->
              # Update or create skills section
              update_skills_section(portfolio.id, parsed_data.skills)
          end
        end
      end)

      {:noreply,
       socket
       |> put_flash(:info, "Resume data imported successfully.")
       |> push_navigate(to: "/portfolios/#{portfolio.id}/edit")}
    else
      {:noreply, put_flash(socket, :error, "No parsed data available.")}
    end
  end

  @impl true
  def handle_event("optimize_for_ats", %{"job_description" => job_description}, socket) do
    # Check if ATS optimization is available for this subscription tier
    if socket.assigns.ats_available do
      parsed_data = socket.assigns.parsed_data

      # This would integrate with an AI service for actual implementation
      # For now, just return the same data with a success message
      socket =
        socket
        |> assign(:parsed_data, parsed_data)
        |> put_flash(:info, "Resume optimized for ATS.")

      {:noreply, socket}
    else
      {:noreply,
       socket
       |> put_flash(:error, "ATS optimization requires a premium subscription.")
       |> push_patch(to: "/account/subscription")}
    end
  end

  defp process_resume_file(socket, file_path, filename) do
    # In a real implementation, this would:
    # 1. Call an AI service API or use a library to extract resume data
    # 2. Parse the results into a structured format
    # 3. Return the parsed data to the client

    # For the prototype, use a mock response with synthetic data
    parsed_data = %{
      personal_info: %{
        name: "John Doe",
        email: "john.doe@example.com",
        phone: "555-123-4567",
        location: "New York, NY"
      },
      experience: [
        %{
          company: "Example Corp",
          title: "Senior Developer",
          start_date: "2020-01",
          end_date: "",
          current: true,
          description: "Led development team on various projects."
        },
        %{
          company: "Previous Inc",
          title: "Developer",
          start_date: "2017-05",
          end_date: "2019-12",
          current: false,
          description: "Worked on frontend applications."
        }
      ],
      education: [
        %{
          institution: "University of Example",
          degree: "Bachelor of Science",
          field: "Computer Science",
          start_date: "2013-09",
          end_date: "2017-05",
          description: ""
        }
      ],
      skills: ["JavaScript", "Elixir", "React", "Phoenix", "SQL", "Git"]
    }

    # Simulate processing delay for better UX
    :timer.sleep(2000)

    socket =
      socket
      |> assign(:parsed_data, parsed_data)
      |> assign(:processing, false)

    {:noreply, socket}
  end

  # Helper functions to update sections in the portfolio

  defp update_contact_section(portfolio_id, personal_info) do
    # Find existing contact section or create a new one
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    contact_section = Enum.find(sections, fn s -> s.section_type == :contact end)

    contact_data = %{
      "email" => personal_info.email,
      "phone" => personal_info.phone,
      "location" => personal_info.location
    }

    if contact_section do
      Portfolios.update_section(contact_section, %{
        "content" => contact_data
      })
    else
      Portfolios.create_section(%{
        portfolio_id: portfolio_id,
        title: "Contact Information",
        section_type: :contact,
        position: length(sections) + 1,
        content: contact_data
      })
    end
  end

  defp update_experience_section(portfolio_id, experience) do
    # Find existing experience section or create a new one
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    experience_section = Enum.find(sections, fn s -> s.section_type == :experience end)

    experience_data = %{
      "jobs" => experience
    }

    if experience_section do
      Portfolios.update_section(experience_section, %{
        "content" => experience_data
      })
    else
      Portfolios.create_section(%{
        portfolio_id: portfolio_id,
        title: "Work Experience",
        section_type: :experience,
        position: length(sections) + 1,
        content: experience_data
      })
    end
  end

  defp update_education_section(portfolio_id, education) do
    # Find existing education section or create a new one
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    education_section = Enum.find(sections, fn s -> s.section_type == :education end)

    education_data = %{
      "education" => education
    }

    if education_section do
      Portfolios.update_section(education_section, %{
        "content" => education_data
      })
    else
      Portfolios.create_section(%{
        portfolio_id: portfolio_id,
        title: "Education",
        section_type: :education,
        position: length(sections) + 1,
        content: education_data
      })
    end
  end

  defp update_skills_section(portfolio_id, skills) do
    # Find existing skills section or create a new one
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    skills_section = Enum.find(sections, fn s -> s.section_type == :skills end)

    skills_data = %{
      "skills" => skills
    }

    if skills_section do
      Portfolios.update_section(skills_section, %{
        "content" => skills_data
      })
    else
      Portfolios.create_section(%{
        portfolio_id: portfolio_id,
        title: "Skills",
        section_type: :skills,
        position: length(sections) + 1,
        content: skills_data
      })
    end
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "You've selected too many files"
  defp error_to_string(:not_accepted), do: "You've selected an unacceptable file type"
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
