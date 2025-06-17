# lib/frestyl_web/live/portfolio_live/components/enhanced_skills_display.ex
defmodule FrestylWeb.PortfolioLive.Components.EnhancedSkillsDisplay do
  use Phoenix.Component

  @doc """
  Enhanced skills display with color-coded proficiency levels, tooltips, and years badges.
  Integrates with the resume import system's skills detection.
  """
  def enhanced_skills_section(assigns) do
    content = assigns.section.content || %{}
    skill_categories = Map.get(content, "skill_categories", %{})
    flat_skills = Map.get(content, "skills", [])
    show_proficiency = Map.get(content, "show_proficiency", true)
    show_years = Map.get(content, "show_years", true)
    display_mode = Map.get(content, "skill_display_mode", "categorized")

    assigns = assign(assigns, %{
      skill_categories: skill_categories,
      flat_skills: flat_skills,
      show_proficiency: show_proficiency,
      show_years: show_years,
      display_mode: display_mode
    })

    ~H"""
    <div class="skills-section bg-white rounded-xl shadow-lg border border-gray-100 overflow-hidden">
      <!-- Section Header -->
      <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 bg-white bg-opacity-20 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-bold text-white"><%= @section.title %></h3>
              <p class="text-blue-100 text-sm">Technical and professional expertise</p>
            </div>
          </div>

          <!-- Display Mode Toggle -->
          <div class="flex items-center space-x-2 bg-white bg-opacity-10 rounded-lg p-1">
            <button class={[
              "px-3 py-1 rounded-md text-xs font-medium transition-colors",
              if(@display_mode == "categorized", do: "bg-white text-blue-600", else: "text-white hover:bg-white hover:bg-opacity-20")
            ]}>
              Categorized
            </button>
            <button class={[
              "px-3 py-1 rounded-md text-xs font-medium transition-colors",
              if(@display_mode == "flat", do: "bg-white text-blue-600", else: "text-white hover:bg-white hover:bg-opacity-20")
            ]}>
              All Skills
            </button>
          </div>
        </div>
      </div>

      <!-- Skills Content -->
      <div class="p-6">
        <%= if @display_mode == "categorized" && map_size(@skill_categories) > 0 do %>
          <%= render_categorized_skills(assigns) %>
        <% else %>
          <%= render_flat_skills(assigns) %>
        <% end %>

        <!-- Skills Summary -->
        <%= render_skills_summary(assigns) %>
      </div>
    </div>

    <!-- Skills Enhancement Notice (for imported skills) -->
    <%= if Map.get(@section.content, "imported_from_resume", false) do %>
      <div class="mt-4 bg-emerald-50 border border-emerald-200 rounded-lg p-4">
        <div class="flex items-start">
          <svg class="w-5 h-5 text-emerald-600 mt-0.5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <div>
            <h4 class="font-medium text-emerald-900">Enhanced from Resume</h4>
            <p class="text-sm text-emerald-800 mt-1">
              Skills and proficiency levels were intelligently detected from your resume.
              You can edit these in the section editor to adjust proficiency levels, years, or categories.
            </p>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_categorized_skills(assigns) do
    ~H"""
    <div class="space-y-8">
      <%= for {category, skills} <- @skill_categories do %>
        <div class="skill-category">
          <!-- Category Header -->
          <div class="flex items-center mb-4">
            <div class={[
              "w-3 h-3 rounded-full mr-3",
              get_category_color(category)
            ]}></div>
            <h4 class="text-lg font-semibold text-gray-900"><%= category %></h4>
            <span class="ml-2 px-2 py-1 bg-gray-100 text-gray-600 text-xs font-medium rounded-full">
              <%= length(skills) %> skills
            </span>
          </div>

          <!-- Skills Grid -->
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            <%= for {skill, index} <- Enum.with_index(skills) do %>
              <%= render_enhanced_skill_card(skill, index, category, assigns) %>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_flat_skills(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-wrap gap-3">
        <%= if length(@flat_skills) > 0 do %>
          <%= for {skill, index} <- Enum.with_index(@flat_skills) do %>
            <%= render_simple_skill_tag(skill, index, assigns) %>
          <% end %>
        <% else %>
          <div class="text-center w-full py-8">
            <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
              </svg>
            </div>
            <p class="text-gray-500">No skills added yet</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_enhanced_skill_card(skill, index, category, assigns) do
    {skill_name, proficiency, years} = parse_skill_data(skill)

    assigns = assign(assigns, %{
      skill_name: skill_name,
      proficiency: proficiency,
      years: years,
      index: index,
      category: category
    })

    ~H"""
    <div class={[
      "skill-card group relative p-4 rounded-xl border-2 transition-all duration-300 hover:scale-105 hover:shadow-lg cursor-pointer",
      get_skill_card_style(@proficiency, @category)
    ]}>
      <!-- Skill Header -->
      <div class="flex items-start justify-between mb-2">
        <h5 class="font-semibold text-gray-900 text-sm leading-tight">
          <%= @skill_name %>
        </h5>

        <!-- Proficiency Dots -->
        <%= if @show_proficiency && @proficiency do %>
          <div class="flex space-x-1 ml-2">
            <%= render_proficiency_dots(@proficiency) %>
          </div>
        <% end %>
      </div>

      <!-- Skill Details -->
      <div class="flex items-center justify-between">
        <!-- Proficiency Badge -->
        <%= if @show_proficiency && @proficiency do %>
          <span class={[
            "px-2 py-1 text-xs font-medium rounded-full",
            get_proficiency_badge_style(@proficiency)
          ]}>
            <%= format_proficiency(@proficiency) %>
          </span>
        <% end %>

        <!-- Years Badge -->
        <%= if @show_years && @years && @years > 0 do %>
          <div class="flex items-center space-x-1 text-xs text-gray-600">
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <span class="font-medium"><%= @years %>y</span>
          </div>
        <% end %>
      </div>

      <!-- Enhanced Tooltip -->
      <div class="skill-tooltip absolute bottom-full left-1/2 transform -translate-x-1/2 mb-3 px-4 py-3 bg-gray-900 text-white text-sm rounded-lg opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-20 shadow-xl">
        <div class="text-center">
          <div class="font-semibold"><%= @skill_name %></div>
          <%= if @proficiency do %>
            <div class="text-xs opacity-90 mt-1">
              Proficiency: <span class="font-medium"><%= format_proficiency(@proficiency) %></span>
            </div>
          <% end %>
          <%= if @years && @years > 0 do %>
            <div class="text-xs opacity-90">
              Experience: <span class="font-medium"><%= @years %> years</span>
            </div>
          <% end %>
          <div class="text-xs opacity-75 mt-1"><%= @category %></div>
        </div>
        <!-- Tooltip Arrow -->
        <div class="absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-gray-900"></div>
      </div>
    </div>
    """
  end

  defp render_simple_skill_tag(skill, index, assigns) do
    skill_name = case skill do
      %{"name" => name} -> name
      name when is_binary(name) -> name
      _ -> to_string(skill)
    end

    assigns = assign(assigns, %{skill_name: skill_name, index: index})

    ~H"""
    <span class={[
      "inline-flex items-center px-3 py-2 rounded-lg text-sm font-medium transition-all duration-200 hover:scale-105",
      get_simple_skill_color(@index)
    ]}>
      <%= @skill_name %>
    </span>
    """
  end

  defp render_proficiency_dots(proficiency) do
    level = case String.downcase(proficiency) do
      "expert" -> 4
      "advanced" -> 3
      "intermediate" -> 2
      "beginner" -> 1
      _ -> 2
    end

    assigns = %{level: level}

    ~H"""
    <%= for i <- 1..4 do %>
      <div class={[
        "w-2 h-2 rounded-full transition-colors",
        if(i <= @level, do: "bg-current opacity-100", else: "bg-current opacity-20")
      ]}></div>
    <% end %>
    """
  end

  defp render_skills_summary(assigns) do
    total_skills = calculate_total_skills(assigns.skill_categories, assigns.flat_skills)
    categories_count = map_size(assigns.skill_categories)

    assigns = assign(assigns, %{
      total_skills: total_skills,
      categories_count: categories_count
    })

    ~H"""
    <div class="mt-8 p-4 bg-gradient-to-r from-gray-50 to-blue-50 rounded-xl border border-gray-200">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-6">
          <div class="text-center">
            <div class="text-2xl font-bold text-blue-600"><%= @total_skills %></div>
            <div class="text-xs text-gray-600 uppercase tracking-wide">Total Skills</div>
          </div>

          <%= if @categories_count > 0 do %>
            <div class="text-center">
              <div class="text-2xl font-bold text-purple-600"><%= @categories_count %></div>
              <div class="text-xs text-gray-600 uppercase tracking-wide">Categories</div>
            </div>
          <% end %>

          <%= if @show_proficiency do %>
            <div class="text-center">
              <div class="text-2xl font-bold text-green-600">
                <%= calculate_average_proficiency(@skill_categories) %>
              </div>
              <div class="text-xs text-gray-600 uppercase tracking-wide">Avg Level</div>
            </div>
          <% end %>
        </div>

        <!-- Skills Legend -->
        <div class="flex items-center space-x-4 text-xs">
          <div class="flex items-center space-x-1">
            <div class="w-2 h-2 bg-green-500 rounded-full"></div>
            <span class="text-gray-600">Expert</span>
          </div>
          <div class="flex items-center space-x-1">
            <div class="w-2 h-2 bg-blue-500 rounded-full"></div>
            <span class="text-gray-600">Advanced</span>
          </div>
          <div class="flex items-center space-x-1">
            <div class="w-2 h-2 bg-yellow-500 rounded-full"></div>
            <span class="text-gray-600">Intermediate</span>
          </div>
          <div class="flex items-center space-x-1">
            <div class="w-2 h-2 bg-gray-400 rounded-full"></div>
            <span class="text-gray-600">Beginner</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for styling and data processing

  defp parse_skill_data(skill) do
    case skill do
      %{"name" => name, "proficiency" => prof, "years" => years} -> {name, prof, years}
      %{"name" => name, "proficiency" => prof} -> {name, prof, nil}
      %{"name" => name} -> {name, nil, nil}
      name when is_binary(name) -> {name, nil, nil}
      _ -> {"Unknown Skill", nil, nil}
    end
  end

  defp get_category_color(category) do
    case String.downcase(category) do
      "programming languages" -> "bg-blue-500"
      "frameworks & libraries" -> "bg-purple-500"
      "tools & platforms" -> "bg-green-500"
      "databases" -> "bg-orange-500"
      "design & creative" -> "bg-pink-500"
      "soft skills" -> "bg-emerald-500"
      "data & analytics" -> "bg-red-500"
      "mobile development" -> "bg-indigo-500"
      "devops & cloud" -> "bg-teal-500"
      _ -> "bg-gray-500"
    end
  end

  defp get_skill_card_style(proficiency, category) do
    base_color = get_category_base_color(category)
    intensity = get_proficiency_intensity(proficiency)

    "#{base_color}-#{intensity} border-#{base_color}-#{intensity + 100}"
  end

  defp get_category_base_color(category) do
    case String.downcase(category) do
      "programming languages" -> "blue"
      "frameworks & libraries" -> "purple"
      "tools & platforms" -> "green"
      "databases" -> "orange"
      "design & creative" -> "pink"
      "soft skills" -> "emerald"
      "data & analytics" -> "red"
      "mobile development" -> "indigo"
      "devops & cloud" -> "teal"
      _ -> "gray"
    end
  end

  defp get_proficiency_intensity(proficiency) do
    case String.downcase(proficiency || "intermediate") do
      "expert" -> 600
      "advanced" -> 500
      "intermediate" -> 400
      "beginner" -> 300
      _ -> 400
    end
  end

  defp get_proficiency_badge_style(proficiency) do
    case String.downcase(proficiency) do
      "expert" -> "bg-green-100 text-green-800 border border-green-200"
      "advanced" -> "bg-blue-100 text-blue-800 border border-blue-200"
      "intermediate" -> "bg-yellow-100 text-yellow-800 border border-yellow-200"
      "beginner" -> "bg-gray-100 text-gray-800 border border-gray-200"
      _ -> "bg-purple-100 text-purple-800 border border-purple-200"
    end
  end

  defp get_simple_skill_color(index) do
    colors = [
      "bg-blue-100 text-blue-800 hover:bg-blue-200",
      "bg-purple-100 text-purple-800 hover:bg-purple-200",
      "bg-green-100 text-green-800 hover:bg-green-200",
      "bg-orange-100 text-orange-800 hover:bg-orange-200",
      "bg-pink-100 text-pink-800 hover:bg-pink-200",
      "bg-emerald-100 text-emerald-800 hover:bg-emerald-200",
      "bg-red-100 text-red-800 hover:bg-red-200",
      "bg-indigo-100 text-indigo-800 hover:bg-indigo-200"
    ]

    Enum.at(colors, rem(index, length(colors)))
  end

  defp format_proficiency(proficiency) do
    case String.downcase(proficiency) do
      "expert" -> "Expert"
      "advanced" -> "Advanced"
      "intermediate" -> "Intermediate"
      "beginner" -> "Beginner"
      _ -> String.capitalize(proficiency)
    end
  end

  defp calculate_total_skills(skill_categories, flat_skills) do
    categorized_count = skill_categories
    |> Map.values()
    |> List.flatten()
    |> length()

    if categorized_count > 0, do: categorized_count, else: length(flat_skills)
  end

  defp calculate_average_proficiency(skill_categories) do
    all_skills = skill_categories
    |> Map.values()
    |> List.flatten()

    if length(all_skills) == 0 do
      "N/A"
    else
      proficiency_values = all_skills
      |> Enum.map(fn skill ->
        case Map.get(skill, "proficiency") do
          "expert" -> 4
          "advanced" -> 3
          "intermediate" -> 2
          "beginner" -> 1
          _ -> 2
        end
      end)

      average = Enum.sum(proficiency_values) / length(proficiency_values)

      case round(average) do
        4 -> "Expert"
        3 -> "Advanced"
        2 -> "Intermediate"
        1 -> "Beginner"
        _ -> "Mixed"
      end
    end
  end
end
