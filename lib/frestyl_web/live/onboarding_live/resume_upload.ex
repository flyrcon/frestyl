# lib/frestyl_web/live/onboarding_live/resume_upload.ex
defmodule FrestylWeb.OnboardingLive.ResumeUpload do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.ResumeParser
  alias Frestyl.Accounts

  @impl true
  def mount(_params, _session, socket) do
    # Ensure user is in onboarding flow
    if socket.assigns.current_user.onboarding_completed do
      {:ok, push_navigate(socket, to: "/portfolios")}
    else
      socket =
        socket
        |> assign(:page_title, "Transform Your Resume")
        |> assign(:step, 2) # Step 2 of onboarding
        |> assign(:upload_state, :waiting) # :waiting, :processing, :success, :error
        |> assign(:processing_stage, :idle) # :idle, :uploading, :parsing, :enhancing, :creating
        |> assign(:processing_message, "")
        |> assign(:processing_progress, 0)
        |> assign(:parsed_data, nil)
        |> assign(:error_message, nil)
        |> assign(:filename, nil)
        |> assign(:sections_preview, %{})
        |> assign(:show_preview, false)
        |> assign(:creative_enhancements, [])
        |> configure_uploads()

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_upload", _params, socket) do
    case uploaded_entries(socket, :resume) do
      {[entry], _} ->
        socket =
          socket
          |> assign(:upload_state, :processing)
          |> assign(:processing_stage, :uploading)
          |> assign(:processing_message, "Uploading your creative story...")
          |> assign(:processing_progress, 10)
          |> assign(:filename, entry.client_name)

        # Process in background
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          process_resume_creatively(socket, path, entry.client_name)
        end)

      _ ->
        {:noreply, put_flash(socket, :error, "Please select a resume file")}
    end
  end

  @impl true
  def handle_event("create_portfolio", _params, socket) do
    if socket.assigns.parsed_data do
      # Create the user's first portfolio with resume data
      portfolio_attrs = %{
        title: get_creative_portfolio_title(socket.assigns.parsed_data),
        description: get_creative_portfolio_description(socket.assigns.parsed_data),
        slug: generate_creative_slug(socket.assigns.parsed_data),
        template: "creative", # Default creative template
        customization: get_creative_customization(),
        user_id: socket.assigns.current_user.id,
        visibility: :public
      }

      case Portfolios.create_portfolio(portfolio_attrs) do
        {:ok, portfolio} ->
          # Import resume sections
          case import_resume_sections_creatively(portfolio, socket.assigns.parsed_data) do
            {:ok, _sections} ->
              # Mark onboarding as completed
              Accounts.complete_onboarding(socket.assigns.current_user)

              socket =
                socket
                |> put_flash(:info, "🎉 Your creative portfolio has been born! Welcome to Frestyl!")
                |> push_navigate(to: "/portfolios/#{portfolio.id}/hub")

              {:noreply, socket}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Failed to import resume data: #{reason}")}
          end

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to create portfolio")}
      end
    else
      {:noreply, put_flash(socket, :error, "No resume data available")}
    end
  end

  @impl true
  def handle_event("skip_resume", _params, socket) do
    # Create empty portfolio and continue to manual creation
    portfolio_attrs = %{
      title: "My Creative Portfolio",
      description: "A showcase of my creative work and professional journey",
      slug: "creative-portfolio-#{System.unique_integer([:positive])}",
      template: "creative",
      customization: get_creative_customization(),
      user_id: socket.assigns.current_user.id,
      visibility: :public
    }

    case Portfolios.create_portfolio(portfolio_attrs) do
      {:ok, portfolio} ->
        Accounts.complete_onboarding(socket.assigns.current_user)
        {:noreply, push_navigate(socket, to: "/portfolios/#{portfolio.id}/edit")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create portfolio")}
    end
  end

  @impl true
  def handle_event("retry_upload", _params, socket) do
    socket =
      socket
      |> assign(:upload_state, :waiting)
      |> assign(:processing_stage, :idle)
      |> assign(:parsed_data, nil)
      |> assign(:error_message, nil)
      |> assign(:processing_progress, 0)
      |> assign(:show_preview, false)

    {:noreply, socket}
  end

  # Async message handlers
  @impl true
  def handle_info({:processing_update, stage, message, progress}, socket) do
    socket =
      socket
      |> assign(:processing_stage, stage)
      |> assign(:processing_message, message)
      |> assign(:processing_progress, progress)
      |> push_event("update_processing_step", %{stage: stage, progress: progress})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:processing_complete, parsed_data, enhancements}, socket) do
    socket =
      socket
      |> assign(:upload_state, :success)
      |> assign(:processing_stage, :complete)
      |> assign(:processing_message, "Your creative portfolio is ready!")
      |> assign(:processing_progress, 100)
      |> assign(:parsed_data, parsed_data)
      |> assign(:creative_enhancements, enhancements)
      |> assign(:sections_preview, generate_sections_preview(parsed_data))
      |> assign(:show_preview, true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:processing_error, reason}, socket) do
    socket =
      socket
      |> assign(:upload_state, :error)
      |> assign(:error_message, reason)
      |> assign(:processing_progress, 0)

    {:noreply, socket}
  end

  # Private functions

  defp configure_uploads(socket) do
    socket
    |> allow_upload(:resume,
      accept: ~w(.pdf .doc .docx .txt .rtf),
      max_entries: 1,
      max_file_size: 10 * 1_048_576, # 10MB
      auto_upload: false
    )
  end

  defp process_resume_creatively(socket, file_path, filename) do
    Task.start(fn ->
      try do
        # Step 1: Extract (20%)
        send(self(), {:processing_update, :extracting, "Reading your professional story...", 20})
        :timer.sleep(1000)

        case ResumeParser.parse_resume_with_filename(file_path, filename) do
          {:ok, raw_data} ->
            # Step 2: Analyze (50%)
            send(self(), {:processing_update, :analyzing, "Discovering your unique strengths...", 50})
            :timer.sleep(1500)

            # Step 3: Enhance (75%)
            send(self(), {:processing_update, :enhancing, "Adding creative flair to your story...", 75})
            enhanced_data = enhance_resume_for_creatives(raw_data, filename)
            creative_enhancements = generate_creative_enhancements(enhanced_data)
            :timer.sleep(1000)

            # Step 4: Complete (100%)
            send(self(), {:processing_update, :creating, "Crafting your portfolio sections...", 90})
            :timer.sleep(500)

            send(self(), {:processing_complete, enhanced_data, creative_enhancements})

          {:error, reason} ->
            send(self(), {:processing_error, "We couldn't read your resume: #{reason}"})
        end
      rescue
        error ->
          send(self(), {:processing_error, "Something went wrong: #{Exception.message(error)}"})
      end
    end)

    {:noreply, socket}
  end

  defp enhance_resume_for_creatives(raw_data, filename) do
    personal_info = extract_personal_info(raw_data)

    %{
      filename: filename,
      personal_info: personal_info,
      creative_headline: generate_creative_headline(personal_info, raw_data),
      professional_story: enhance_professional_summary(raw_data),
      experience_narrative: transform_experience_creatively(raw_data),
      skills_showcase: categorize_skills_creatively(raw_data),
      education_journey: enhance_education_story(raw_data),
      project_highlights: extract_project_potential(raw_data),
      creative_strengths: identify_creative_strengths(raw_data),
      personality_insights: generate_personality_insights(raw_data)
    }
  end

  defp generate_creative_enhancements(data) do
    [
      %{
        icon: "✨",
        title: "Creative Headline Generated",
        description: "We've crafted a compelling headline that captures your unique value"
      },
      %{
        icon: "🎨",
        title: "Visual Skills Categorization",
        description: "Your skills are organized into beautiful, scannable categories"
      },
      %{
        icon: "📖",
        title: "Story-Driven Experience",
        description: "Your work history tells a compelling professional narrative"
      },
      %{
        icon: "🚀",
        title: "Project Potential Identified",
        description: "We've highlighted experiences that can become portfolio projects"
      }
    ]
  end

  defp generate_creative_headline(personal_info, raw_data) do
    name = Map.get(personal_info, "name", "Creative Professional")

    # Extract industry/role hints from experience
    experience = Map.get(raw_data, "work_experience", [])
    latest_role = case experience do
      [latest | _] -> Map.get(latest, "title", "")
      _ -> ""
    end

    skills = Map.get(raw_data, "skills", [])

    cond do
      Enum.any?(skills, &String.contains?(String.downcase(&1), "design")) ->
        "#{name} • Creative Designer & Visual Storyteller"

      Enum.any?(skills, &String.contains?(String.downcase(&1), "develop")) ->
        "#{name} • Creative Developer & Digital Innovator"

      Enum.any?(skills, &String.contains?(String.downcase(&1), "market")) ->
        "#{name} • Creative Marketer & Brand Strategist"

      latest_role != "" ->
        "#{name} • #{latest_role} & Creative Professional"

      true ->
        "#{name} • Creative Professional & Innovation Driver"
    end
  end

  defp get_creative_portfolio_title(data) do
    personal_info = Map.get(data, :personal_info, %{})
    name = Map.get(personal_info, "name", "Creative Professional")

    "#{name}'s Creative Portfolio"
  end

  defp get_creative_portfolio_description(data) do
    skills = Map.get(data, :skills_showcase, %{})
    top_skills = skills
    |> Map.values()
    |> List.flatten()
    |> Enum.take(3)
    |> Enum.join(", ")

    if top_skills != "" do
      "A creative showcase featuring expertise in #{top_skills} and a passion for innovative solutions."
    else
      "A creative portfolio showcasing professional experience, skills, and innovative projects."
    end
  end

  defp generate_creative_slug(data) do
    personal_info = Map.get(data, :personal_info, %{})
    name = Map.get(personal_info, "name", "creative-professional")

    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.slice(0, 30)
    |> Kernel.<>("-#{System.unique_integer([:positive])}")
  end

  defp get_creative_customization do
    %{
      "template" => "creative",
      "color_scheme" => "creative-gradient",
      "primary_color" => "#667eea",
      "secondary_color" => "#764ba2",
      "accent_color" => "#f093fb",
      "layout_style" => "story_driven",
      "section_spacing" => "generous",
      "font_family" => "Inter",
      "animations" => %{
        "fade_in" => true,
        "slide_up" => true,
        "hover_effects" => true,
        "scroll_reveal" => true
      },
      "card_style" => "glass_morphism",
      "background" => "gradient-creative"
    }
  end

  defp import_resume_sections_creatively(portfolio, parsed_data) do
    sections_to_create = [
      create_intro_section(portfolio.id, parsed_data),
      create_experience_section(portfolio.id, parsed_data),
      create_skills_section(portfolio.id, parsed_data),
      create_education_section(portfolio.id, parsed_data),
      create_contact_section(portfolio.id, parsed_data)
    ]

    case Enum.reduce_while(sections_to_create, [], fn section_result, acc ->
      case section_result do
        {:ok, section} -> {:cont, [section | acc]}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end) do
      {:error, reason} -> {:error, reason}
      sections -> {:ok, Enum.reverse(sections)}
    end
  end

  defp create_intro_section(portfolio_id, data) do
    content = %{
      "headline" => Map.get(data, :creative_headline, "Creative Professional"),
      "summary" => Map.get(data, :professional_story, ""),
      "personality_insights" => Map.get(data, :personality_insights, []),
      "creative_strengths" => Map.get(data, :creative_strengths, [])
    }

    Portfolios.create_section(%{
      portfolio_id: portfolio_id,
      title: "About Me",
      section_type: :intro,
      position: 1,
      content: content,
      visible: true
    })
  end

  defp create_experience_section(portfolio_id, data) do
    content = %{
      "jobs" => Map.get(data, :experience_narrative, []),
      "display_style" => "story_timeline"
    }

    Portfolios.create_section(%{
      portfolio_id: portfolio_id,
      title: "Professional Journey",
      section_type: :experience,
      position: 2,
      content: content,
      visible: true
    })
  end

  defp create_skills_section(portfolio_id, data) do
    content = %{
      "skill_categories" => Map.get(data, :skills_showcase, %{}),
      "display_mode" => "categorized",
      "show_proficiency" => true,
      "visual_style" => "creative_cards"
    }

    Portfolios.create_section(%{
      portfolio_id: portfolio_id,
      title: "Skills & Expertise",
      section_type: :skills,
      position: 3,
      content: content,
      visible: true
    })
  end

  defp create_education_section(portfolio_id, data) do
    content = %{
      "education" => Map.get(data, :education_journey, []),
      "display_style" => "timeline"
    }

    Portfolios.create_section(%{
      portfolio_id: portfolio_id,
      title: "Learning Journey",
      section_type: :education,
      position: 4,
      content: content,
      visible: true
    })
  end

  defp create_contact_section(portfolio_id, data) do
    personal_info = Map.get(data, :personal_info, %{})

    content = %{
      "email" => Map.get(personal_info, "email", ""),
      "phone" => Map.get(personal_info, "phone", ""),
      "location" => Map.get(personal_info, "location", ""),
      "name" => Map.get(personal_info, "name", ""),
      "linkedin" => Map.get(personal_info, "linkedin", ""),
      "website" => Map.get(personal_info, "website", ""),
      "github" => Map.get(personal_info, "github", "")
    }

    Portfolios.create_section(%{
      portfolio_id: portfolio_id,
      title: "Let's Connect",
      section_type: :contact,
      position: 5,
      content: content,
      visible: true
    })
  end

  # Helper functions for creative enhancement
  defp extract_personal_info(raw_data) do
    Map.get(raw_data, "personal_info", %{})
  end

  defp enhance_professional_summary(raw_data) do
    summary = Map.get(raw_data, "professional_summary", "")

    if String.length(summary) > 20 do
      summary
    else
      generate_summary_from_experience(raw_data)
    end
  end

  defp generate_summary_from_experience(raw_data) do
    experience = Map.get(raw_data, "work_experience", [])
    skills = Map.get(raw_data, "skills", [])

    case {length(experience), length(skills)} do
      {exp_count, skill_count} when exp_count > 0 and skill_count > 0 ->
        latest_role = List.first(experience)
        top_skills = Enum.take(skills, 3) |> Enum.join(", ")
        company = Map.get(latest_role, "company", "")

        "Experienced professional with expertise in #{top_skills}. Currently contributing to innovative projects" <>
        if company != "", do: " at #{company}", else: "" <>
        ". Passionate about creative problem-solving and delivering impactful results."

      _ ->
        "Creative professional passionate about innovation and excellence. Committed to continuous learning and making a meaningful impact through thoughtful, strategic work."
    end
  end

  defp transform_experience_creatively(raw_data) do
    Map.get(raw_data, "work_experience", [])
    |> Enum.map(&enhance_job_entry/1)
  end

  defp enhance_job_entry(job) do
    job
    |> Map.put("impact_highlights", extract_impact_from_description(job))
    |> Map.put("creative_achievements", extract_creative_achievements(job))
    |> Map.put("story_narrative", enhance_job_narrative(job))
  end

  defp extract_impact_from_description(job) do
    description = Map.get(job, "description", "")

    # Extract quantified achievements and impact statements
    Regex.scan(~r/\b(?:increased|improved|reduced|achieved|delivered|created|built|designed|implemented|led|managed)[\w\s,]*\b(?:\d+%|\$[\d,]+|\d+[\w\s]*)/i, description)
    |> Enum.map(&List.first/1)
    |> Enum.take(3)
  end

  defp extract_creative_achievements(job) do
    description = Map.get(job, "description", "")
    creative_keywords = ["design", "creative", "innovative", "solution", "strategy", "brand", "visual", "user", "experience"]

    creative_keywords
    |> Enum.filter(fn keyword ->
      String.contains?(String.downcase(description), keyword)
    end)
    |> Enum.take(3)
    |> Enum.map(&String.capitalize/1)
  end

  defp enhance_job_narrative(job) do
    title = Map.get(job, "title", "")
    company = Map.get(job, "company", "")
    description = Map.get(job, "description", "")

    if String.length(description) > 100 do
      description
      |> String.slice(0, 200)
      |> String.replace(~r/\s\w+$/, "...")
    else
      "Contributed to #{company}'s success as #{title}, focusing on innovative solutions and creative problem-solving."
    end
  end

  defp categorize_skills_creatively(raw_data) do
    skills = Map.get(raw_data, "skills", [])

    # Creative categorization
    %{
      "Technical Skills" => filter_skills(skills, ["programming", "development", "software", "code", "technical", "system", "database", "api"]),
      "Creative & Design" => filter_skills(skills, ["design", "creative", "visual", "ui", "ux", "graphic", "brand", "adobe", "figma", "sketch"]),
      "Strategy & Leadership" => filter_skills(skills, ["management", "leadership", "strategy", "planning", "project", "team", "communication", "collaboration"]),
      "Tools & Platforms" => filter_skills(skills, ["excel", "powerpoint", "google", "microsoft", "slack", "trello", "asana", "analytics", "crm"])
    }
    |> Enum.reject(fn {_category, skills} -> Enum.empty?(skills) end)
    |> Enum.into(%{})
  end

  defp filter_skills(skills, keywords) do
    skills
    |> Enum.filter(fn skill ->
      skill_lower = String.downcase(skill)
      Enum.any?(keywords, &String.contains?(skill_lower, &1))
    end)
  end

  defp enhance_education_story(raw_data) do
    Map.get(raw_data, "education", [])
    |> Enum.map(&enhance_education_entry/1)
  end

  defp enhance_education_entry(edu) do
    edu
    |> Map.put("learning_highlights", extract_learning_highlights(edu))
    |> Map.put("relevance_score", calculate_relevance_score(edu))
  end

  defp extract_learning_highlights(edu) do
    degree = Map.get(edu, "degree", "")
    field = Map.get(edu, "field", "")

    highlights = []

    highlights = if String.contains?(String.downcase(degree), "master"),
      do: ["Advanced Studies" | highlights],
      else: highlights

    highlights = if String.contains?(String.downcase(field), "design"),
      do: ["Creative Focus" | highlights],
      else: highlights

    highlights = if String.contains?(String.downcase(field), "business"),
      do: ["Strategic Thinking" | highlights],
      else: highlights

    highlights
  end

  defp calculate_relevance_score(edu) do
    # Simple scoring based on degree level and field relevance
    degree = String.downcase(Map.get(edu, "degree", ""))
    field = String.downcase(Map.get(edu, "field", ""))

    base_score = cond do
      String.contains?(degree, "phd") -> 95
      String.contains?(degree, "master") -> 85
      String.contains?(degree, "bachelor") -> 75
      true -> 60
    end

    field_bonus = cond do
      String.contains?(field, "design") or String.contains?(field, "creative") -> 10
      String.contains?(field, "business") or String.contains?(field, "management") -> 8
      String.contains?(field, "technology") or String.contains?(field, "computer") -> 8
      true -> 0
    end

    min(base_score + field_bonus, 100)
  end

  defp extract_project_potential(raw_data) do
    # Look for project-like experiences in work history
    experience = Map.get(raw_data, "work_experience", [])

    experience
    |> Enum.flat_map(&extract_projects_from_job/1)
    |> Enum.take(3)
  end

  defp extract_projects_from_job(job) do
    description = Map.get(job, "description", "")
    company = Map.get(job, "company", "")

    # Look for project indicators
    project_indicators = ["project", "built", "created", "designed", "developed", "launched", "implemented"]

    if Enum.any?(project_indicators, &String.contains?(String.downcase(description), &1)) do
      [%{
        "title" => "Project at #{company}",
        "description" => String.slice(description, 0, 150),
        "company" => company,
        "potential" => true
      }]
    else
      []
    end
  end

  defp identify_creative_strengths(raw_data) do
    skills = Map.get(raw_data, "skills", [])
    experience = Map.get(raw_data, "work_experience", [])

    creative_indicators = [
      {"Problem Solving", ["problem", "solution", "solve", "troubleshoot", "debug"]},
      {"Innovation", ["innovative", "creative", "new", "novel", "original", "invention"]},
      {"Communication", ["communication", "present", "writing", "documentation", "collaborate"]},
      {"Leadership", ["lead", "manage", "mentor", "guide", "direct", "supervise"]},
      {"Adaptability", ["adapt", "flexible", "change", "learn", "growth", "evolve"]}
    ]

    all_text = (skills ++ Enum.map(experience, &Map.get(&1, "description", "")))
    |> Enum.join(" ")
    |> String.downcase()

    creative_indicators
    |> Enum.filter(fn {_strength, keywords} ->
      Enum.any?(keywords, &String.contains?(all_text, &1))
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.take(3)
  end

  defp generate_personality_insights(raw_data) do
    # Generate personality insights based on resume content
    skills = Map.get(raw_data, "skills", [])
    experience_count = length(Map.get(raw_data, "work_experience", []))

    insights = []

    insights = if length(skills) > 10,
      do: ["Multi-skilled professional with diverse expertise" | insights],
      else: insights

    insights = if experience_count > 3,
      do: ["Experienced professional with proven track record" | insights],
      else: insights

    insights = if Enum.any?(skills, &String.contains?(String.downcase(&1), "team")),
      do: ["Collaborative team player" | insights],
      else: insights

    Enum.take(insights, 2)
  end

  defp generate_sections_preview(data) do
    %{
      intro: %{
        title: "About Me",
        preview: Map.get(data, :creative_headline, ""),
        icon: "👋"
      },
      experience: %{
        title: "Professional Journey",
        preview: "#{length(Map.get(data, :experience_narrative, []))} roles showcased",
        icon: "💼"
      },
      skills: %{
        title: "Skills & Expertise",
        preview: "#{map_size(Map.get(data, :skills_showcase, %{}))} skill categories",
        icon: "⚡"
      },
      education: %{
        title: "Learning Journey",
        preview: "#{length(Map.get(data, :education_journey, []))} educational milestones",
        icon: "🎓"
      }
    }
  end
end
