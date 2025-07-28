# lib/frestyl_web/live/portfolio_live/layouts/professional_layout_component.ex

defmodule FrestylWeb.PortfolioLive.Layouts.ProfessionalLayoutComponent do
  @moduledoc """
  Traditional professional layout for standard business portfolios
  """
  use FrestylWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="professional-portfolio bg-white min-h-screen">
      <!-- Traditional hero section -->
      <section class="py-16 bg-gray-900 text-white">
        <div class="max-w-4xl mx-auto px-4 text-center">
          <h1 class="text-5xl font-bold mb-6"><%= @portfolio.title %></h1>
          <p class="text-xl text-gray-300"><%= @portfolio.description %></p>
        </div>
      </section>

      <!-- Sections rendered in order -->
      <div class="max-w-4xl mx-auto px-4 py-12 space-y-16">
        <%= for section <- @sections do %>
          <%= if section.visible do %>
            <section class="prose prose-lg max-w-none">
              <h2 class="text-3xl font-bold text-gray-900 mb-8"><%= section.title %></h2>
              <div class="bg-white rounded-lg border border-gray-200 p-8">
                <%= render_section_content(section) %>
              </div>
            </section>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_section_content(section) do
    # Basic content rendering - can be enhanced with specific renderers
    content = section.content || %{}

    case section.section_type do
      :experience ->
        render_experience_items(Map.get(content, "items", []))
      :skills ->
        render_skills_list(Map.get(content, "skill_categories", []))
      :projects ->
        render_projects_list(Map.get(content, "items", []))
      _ ->
        raw(Map.get(content, "description", Map.get(content, "content", "")))
    end
  end

  defp render_experience_items(items) do
    assigns = %{items: items}

    ~H"""
    <div class="space-y-6">
      <%= for item <- @items do %>
        <div class="border-l-4 border-blue-500 pl-6">
          <h3 class="font-semibold text-lg"><%= Map.get(item, "title", "") %></h3>
          <p class="text-blue-600 font-medium"><%= Map.get(item, "company", "") %></p>
          <p class="text-gray-600 text-sm"><%= Map.get(item, "start_date", "") %> - <%= Map.get(item, "end_date", "") %></p>
          <p class="mt-2"><%= Map.get(item, "description", "") %></p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_skills_list(categories) do
    assigns = %{categories: categories}

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <%= for category <- @categories do %>
        <div>
          <h3 class="font-semibold mb-3"><%= Map.get(category, "name", "") %></h3>
          <div class="flex flex-wrap gap-2">
            <%= for skill <- Map.get(category, "skills", []) do %>
              <span class="bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm">
                <%= if is_map(skill), do: Map.get(skill, "name", skill), else: skill %>
              </span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_projects_list(items) do
    assigns = %{items: items}

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <%= for item <- @items do %>
        <div class="border border-gray-200 rounded-lg p-6">
          <h3 class="font-semibold text-lg mb-2"><%= Map.get(item, "title", "") %></h3>
          <p class="text-gray-600 mb-4"><%= Map.get(item, "description", "") %></p>
          <%= if Map.get(item, "demo_url", "") != "" do %>
            <a href={Map.get(item, "demo_url")} target="_blank" class="text-blue-600 hover:underline">
              View Project →
            </a>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
