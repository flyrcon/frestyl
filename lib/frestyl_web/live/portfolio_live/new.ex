# Update lib/frestyl_web/live/portfolio_live/new.ex
defmodule FrestylWeb.PortfolioLive.New do
  use FrestylWeb, :live_view
  alias Frestyl.{Portfolios, Stories, Accounts}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    accounts = Accounts.list_user_accounts(user.id)
    current_account = List.first(accounts)

    changeset = Portfolios.change_portfolio(%Frestyl.Portfolios.Portfolio{})

    socket = socket
    |> assign(:page_title, "Create New Story")
    |> assign(:changeset, changeset)
    |> assign(:accounts, accounts)
    |> assign(:current_account, current_account)
    |> assign(:step, :basics)  # :basics, :template, :customize
    |> assign(:selected_story_type, nil)
    |> assign(:selected_narrative_structure, nil)
    |> assign(:available_templates, %{})

    {:ok, socket}
  end

  def handle_event("story_type_selected", %{"story_type" => story_type}, socket) do
    story_type_atom = String.to_atom(story_type)
    available_structures = get_available_structures(story_type_atom)

    socket = socket
    |> assign(:selected_story_type, story_type_atom)
    |> assign(:available_structures, available_structures)
    |> assign(:selected_narrative_structure, nil)

    {:noreply, socket}
  end

  def handle_event("narrative_structure_selected", %{"structure" => structure}, socket) do
    structure_atom = String.to_atom(structure)
    template = Stories.Templates.get_template(socket.assigns.selected_story_type, structure_atom)

    socket = socket
    |> assign(:selected_narrative_structure, structure_atom)
    |> assign(:template_preview, template)
    |> assign(:step, :template)

    {:noreply, socket}
  end

  def handle_event("create_story_with_template", params, socket) do
    story_attrs = %{
      title: params["title"],
      description: params["description"],
      story_type: socket.assigns.selected_story_type,
      narrative_structure: socket.assigns.selected_narrative_structure,
      account_id: socket.assigns.current_account.id
    }

    case Portfolios.create_portfolio(socket.assigns.current_user.id, story_attrs) do
      {:ok, portfolio} ->
        # Apply template
        template = socket.assigns.template_preview
        Stories.Templates.apply_template_to_story(portfolio, template)

        {:noreply,
         socket
         |> put_flash(:info, "Story created with #{template.name} structure!")
         |> push_navigate(to: ~p"/portfolios/#{portfolio.id}/edit")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
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
end
