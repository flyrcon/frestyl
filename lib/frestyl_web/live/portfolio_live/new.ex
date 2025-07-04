# Update lib/frestyl_web/live/portfolio_live/new.ex
defmodule FrestylWeb.PortfolioLive.New do
  use FrestylWeb, :live_view
  alias Frestyl.{Portfolios, Stories, Accounts}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Safely load accounts - handle if list_user_accounts doesn't exist
    accounts = try do
      Accounts.list_user_accounts(user.id)
    rescue
      _ -> []
    end

    # Set current_account to nil if no accounts exist - we'll handle this in the event handler
    current_account = List.first(accounts)

    changeset = Portfolios.change_portfolio(%Frestyl.Portfolios.Portfolio{})

    socket = socket
    |> assign(:page_title, "Create New Story")
    |> assign(:changeset, changeset)
    |> assign(:accounts, accounts)
    |> assign(:current_account, current_account)  # This can be nil
    |> assign(:step, :basics)
    |> assign(:selected_story_type, nil)
    |> assign(:selected_narrative_structure, nil)
    |> assign(:available_templates, %{})
    |> assign(:mode, :portfolio)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Create Portfolio")
    |> assign(:mode, :portfolio)
  end

  defp apply_action(socket, :story, _params) do
    socket
    |> assign(:page_title, "Create Story")
    |> assign(:mode, :story)
  end

  def handle_event("story_type_selected", %{"story_type" => story_type}, socket) do
    story_type_atom = String.to_atom(story_type)
    available_structures = get_available_structures(story_type_atom)

    # Debug logs
    IO.inspect(story_type_atom, label: "Selected story type")
    IO.inspect(available_structures, label: "Available structures")

    socket = socket
    |> assign(:selected_story_type, story_type_atom)
    |> assign(:available_structures, available_structures)
    |> assign(:selected_narrative_structure, nil)

    {:noreply, socket}
  end

  def handle_event("narrative_structure_selected", %{"structure" => structure}, socket) do
    structure_atom = String.to_atom(structure)

    # Create a mock template based on the story type and structure
    template = create_mock_template(socket.assigns.selected_story_type, structure_atom)

    socket = socket
    |> assign(:selected_narrative_structure, structure_atom)
    |> assign(:template_preview, template)
    |> assign(:step, :template)

    {:noreply, socket}
  end

  def handle_event("create_story_with_template", params, socket) do
    user = socket.assigns.current_user

    # Build story attributes with user_id (integer), not user struct
    story_attrs = %{
      title: String.trim(params["title"]),
      description: String.trim(params["description"]),
      slug: generate_slug_from_title(params["title"]),
      theme: "executive",  # Default theme
      visibility: :private,
      user_id: user.id,  # ← Use user.id, not user
      story_type: socket.assigns[:selected_story_type] || :professional_showcase,
      narrative_structure: socket.assigns[:selected_narrative_structure] || :chronological
    }

    # Only add account_id if we have a current_account
    story_attrs = case socket.assigns[:current_account] do
      %{id: account_id} -> Map.put(story_attrs, :account_id, account_id)
      _ -> story_attrs  # Skip account_id if no account
    end

    # Use the correct function signature: create_portfolio(user_id, attrs)
    case Portfolios.create_portfolio(user.id, story_attrs) do
      {:ok, portfolio} ->
        # Apply template if available
        if template = socket.assigns[:template_preview] do
          try do
            # Only apply template if Stories.Templates module exists
            if Code.ensure_loaded?(Stories.Templates) do
              Stories.Templates.apply_template_to_story(portfolio, template)
            end
          rescue
            _ -> :ok  # Continue even if template application fails
          end
        end

        {:noreply,
        socket
        |> put_flash(:info, "Story '#{portfolio.title}' created successfully!")
        |> push_navigate(to: ~p"/portfolios/#{portfolio.id}/edit")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
        socket
        |> assign(:changeset, changeset)
        |> put_flash(:error, "Failed to create story")}

      {:error, reason} ->
        {:noreply,
        socket
        |> put_flash(:error, "Failed to create story: #{inspect(reason)}")}
    end
  end

  # Add this helper function at the bottom of the file
  defp generate_slug_from_title(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.slice(0, 50)
  end

  # Add this helper function if it doesn't exist
  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  def handle_event("create_portfolio", %{"portfolio" => portfolio_params}, socket) do
    # Get the current user from socket assigns
    user = socket.assigns.current_user

    # Prepare portfolio attributes with user association
    portfolio_attrs = portfolio_params
    |> Map.put("user_id", user.id)
    |> Map.put("theme", portfolio_params["theme"] || "executive")

    # Create the portfolio
    case Portfolios.create_portfolio(user, portfolio_attrs) do
      {:ok, portfolio} ->
        {:noreply, socket
        |> put_flash(:info, "Portfolio created successfully!")
        |> push_navigate(to: ~p"/portfolios/#{portfolio.id}/edit")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket
        |> assign(:changeset, changeset)
        |> put_flash(:error, "Failed to create portfolio")}
    end
  end

  def handle_event("back_to_basics", _params, socket) do
    socket = socket
    |> assign(:step, :basics)
    |> assign(:selected_narrative_structure, nil)
    |> assign(:template_preview, nil)

    {:noreply, socket}
  end

  def handle_event("change_template", _params, socket) do
    socket = socket
    |> assign(:step, :basics)
    |> assign(:selected_narrative_structure, nil)
    |> assign(:template_preview, nil)

    {:noreply, socket}
  end

  defp create_template_sections(portfolio, template) do
    template.chapters
    |> Enum.with_index()
    |> Enum.each(fn {chapter, index} ->
      section_attrs = %{
        portfolio_id: portfolio.id,
        title: chapter.title,
        section_type: chapter.type,
        position: index,
        content: get_default_content_for_chapter(chapter),
        visible: true
      }

      Portfolios.create_section(section_attrs)
    end)
  end

  defp get_default_content_for_chapter(chapter) do
    case chapter.type do
      :intro -> %{
        "headline" => "Welcome to my portfolio",
        "summary" => "Add your professional summary here...",
        "location" => "",
        "website" => ""
      }
      :experience -> %{
        "jobs" => []
      }
      :skills -> %{
        "skills" => [],
        "skill_categories" => %{}
      }
      :projects -> %{
        "projects" => []
      }
      :story -> %{
        "narrative" => "Tell your story here...",
        "chapters" => []
      }
      :conclusion -> %{
        "summary" => "Wrap up your story...",
        "call_to_action" => "Get in touch to learn more"
      }
      _ -> %{}
    end
  end

  defp create_mock_template(story_type, structure) do
    %{
      name: get_template_name(story_type, structure),
      description: get_template_description(story_type, structure),
      chapters: get_template_chapters(story_type, structure)
    }
  end

  defp get_template_name(story_type, structure) do
    "#{humanize_atom(story_type)} - #{humanize_atom(structure)}"
  end

  defp get_template_description(story_type, structure) do
    case {story_type, structure} do
      {:professional_showcase, :skills_first} ->
        "Start with your technical skills and capabilities, then build your professional narrative around them."
      {:professional_showcase, :chronological} ->
        "Tell your professional story chronologically, from your early career to your current achievements."
      {:personal_narrative, :hero_journey} ->
        "Frame your personal story as a transformative journey with challenges and growth."
      {:personal_narrative, :chronological} ->
        "Share your personal story in chronological order, highlighting key life moments."
      {:case_study, :problem_solution} ->
        "Present your work as a systematic approach to solving important problems."
      {:case_study, :before_after} ->
        "Showcase the dramatic improvements and transformations you've achieved."
      {:brand_story, :hero_journey} ->
        "Tell your brand's story as an inspiring journey of overcoming challenges."
      {:brand_story, :chronological} ->
        "Chronicle your brand's evolution and growth over time."
      _ ->
        "A structured approach to telling your story effectively."
    end
  end

  defp get_template_chapters(story_type, structure) do
    case {story_type, structure} do
      {:professional_showcase, :skills_first} -> [
        %{title: "Core Skills & Expertise", type: :skills, purpose: :showcase},
        %{title: "Professional Experience", type: :experience, purpose: :context},
        %{title: "Key Projects & Achievements", type: :projects, purpose: :evidence},
        %{title: "Goals & Future Vision", type: :conclusion, purpose: :forward_looking}
      ]
      {:professional_showcase, :chronological} -> [
        %{title: "Professional Introduction", type: :intro, purpose: :opening},
        %{title: "Career Journey", type: :experience, purpose: :main_content},
        %{title: "Skills & Capabilities", type: :skills, purpose: :evidence},
        %{title: "Looking Forward", type: :conclusion, purpose: :forward_looking}
      ]
      {:personal_narrative, :hero_journey} -> [
        %{title: "The Call to Adventure", type: :intro, purpose: :opening},
        %{title: "Challenges & Trials", type: :story, purpose: :conflict},
        %{title: "Transformation & Growth", type: :story, purpose: :resolution},
        %{title: "Wisdom Gained", type: :conclusion, purpose: :forward_looking}
      ]
      {:case_study, :problem_solution} -> [
        %{title: "The Problem", type: :intro, purpose: :problem_definition},
        %{title: "The Solution Approach", type: :story, purpose: :methodology},
        %{title: "Implementation & Results", type: :projects, purpose: :evidence},
        %{title: "Lessons & Impact", type: :conclusion, purpose: :reflection}
      ]
      _ -> [
        %{title: "Introduction", type: :intro, purpose: :opening},
        %{title: "Main Content", type: :story, purpose: :main_content},
        %{title: "Conclusion", type: :conclusion, purpose: :forward_looking}
      ]
    end
  end

  defp humanize_atom(atom) do
    atom
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_available_structures(:personal_narrative) do
    [:chronological, :hero_journey]
  end

  defp get_available_structures(:case_study) do
    [:problem_solution, :before_after]
  end

  defp get_available_structures(:professional_showcase) do
    [:chronological, :skills_first]
  end

  defp get_available_structures(_) do
    [:chronological]
  end

  defp story_type_options do
    %{
      "personal_narrative" => %{
        name: "Personal Story",
        description: "Share your personal journey, experiences, and growth",
        examples: "Life story, career transition, personal transformation",
        icon: """
        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
        </svg>
        """
      },
      "professional_showcase" => %{
        name: "Professional Portfolio",
        description: "Highlight your skills, experience, and career achievements",
        examples: "Resume portfolio, career highlights, professional bio",
        icon: """
        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H6a2 2 0 01-2-2V8a2 2 0 012-2V6" />
        </svg>
        """
      },
      "case_study" => %{
        name: "Case Study",
        description: "Document a project, problem-solving process, or business outcome",
        examples: "Project showcase, problem-solution narrative, business results",
        icon: """
        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
        </svg>
        """
      },
      "brand_story" => %{
        name: "Brand Story",
        description: "Tell the story of your company, product, or personal brand",
        examples: "Company origin, product journey, brand values narrative",
        icon: """
        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
        </svg>
        """
      }
    }
  end

  defp render_structure_option(assigns, structure) do
    config = structure_config(structure)

    assigns = assign(assigns, :structure, structure) |> assign(:config, config)

    ~H"""
    <button
      type="button"
      phx-click="narrative_structure_selected"
      phx-value-structure={@structure}
      class={[
        "p-4 border rounded-lg text-left transition-all",
        if(@selected_narrative_structure == @structure,
          do: "border-blue-500 bg-blue-50",
          else: "border-gray-200 hover:border-gray-300")
      ]}
    >
      <h4 class="font-medium text-gray-900"><%= @config.name %></h4>
      <p class="text-sm text-gray-600 mt-1"><%= @config.description %></p>
      <%= if @config.best_for do %>
        <div class="mt-2">
          <span class="text-xs text-green-600 font-medium">Best for:</span>
          <span class="text-xs text-gray-600"><%= @config.best_for %></span>
        </div>
      <% end %>
    </button>
    """
  end

  defp structure_config(:chronological) do
    %{
      name: "Chronological",
      description: "Tell your story in time order from past to present",
      best_for: "Career progression, life journeys, step-by-step processes"
    }
  end

  defp structure_config(:hero_journey) do
    %{
      name: "Hero's Journey",
      description: "Frame your story as overcoming challenges and transformation",
      best_for: "Personal growth stories, career pivots, overcoming obstacles"
    }
  end

  defp structure_config(:problem_solution) do
    %{
      name: "Problem → Solution",
      description: "Start with a challenge and walk through your solution",
      best_for: "Project showcases, consulting work, technical solutions"
    }
  end

  defp structure_config(:before_after) do
    %{
      name: "Before & After",
      description: "Show dramatic transformation or improvement",
      best_for: "Redesigns, business turnarounds, personal transformations"
    }
  end

  defp structure_config(:skills_first) do
    %{
      name: "Skills First",
      description: "Lead with your technical capabilities and expertise",
      best_for: "Technical professionals, developers, consultants"
    }
  end

  # Add this complete get_available_structures function to cover all story types:
  defp get_available_structures(:personal_narrative) do
    [:chronological, :hero_journey]
  end

  defp get_available_structures(:case_study) do
    [:problem_solution, :before_after]
  end

  defp get_available_structures(:professional_showcase) do
    [:chronological, :skills_first]
  end

  defp get_available_structures(:brand_story) do
    [:chronological, :hero_journey]
  end

  # Catch-all for any missing story types
  defp get_available_structures(_) do
    [:chronological]
  end

  # Add a catch-all structure_config to prevent future crashes:
  defp structure_config(unknown_structure) do
    IO.warn("Unknown structure: #{inspect(unknown_structure)}")
    %{
      name: "Default Structure",
      description: "A balanced approach to presenting your content",
      best_for: "General use cases"
    }
  end
end
