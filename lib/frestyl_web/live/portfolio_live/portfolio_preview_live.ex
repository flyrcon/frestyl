# lib/frestyl_web/live/portfolio_live/portfolio_preview_live.ex
defmodule FrestylWeb.PortfolioLive.PortfolioPreviewLive do
  @moduledoc """
  Real-time preview component for portfolio editor.
  Renders portfolio sections with live updates from the editor.
  """

  use FrestylWeb, :live_view
  import Phoenix.HTML, only: [raw: 1]

  alias Frestyl.Portfolios
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => portfolio_id}, _session, socket) do
    IO.puts("🔥 PREVIEW MOUNT: Starting...")

    if connected?(socket) do
      PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}")
    end

    case Portfolios.get_portfolio_with_sections(portfolio_id) do
      {:ok, portfolio} ->
        IO.puts("🔥 PREVIEW MOUNT: Got portfolio with keys: #{inspect(Map.keys(portfolio))}")

        socket = socket |> assign_portfolio_data(portfolio)
        IO.puts("🔥 PREVIEW MOUNT: After assign_portfolio_data")

        socket = socket |> assign_preview_state()
        IO.puts("🔥 PREVIEW MOUNT: After assign_preview_state")

        {:ok, socket}

      {:error, _} ->
        {:ok, socket
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: ~p"/portfolios")}
    end
  end

  @impl true
  def handle_info({:preview_update, data}, socket) do
    IO.puts("🔥 LivePreview handling preview_update")

    {:noreply, socket
    |> assign(:sections, Map.get(data, :sections, socket.assigns.sections))
    |> assign(:customization, Map.get(data, :customization, socket.assigns.customization))
    |> assign(:last_updated, Map.get(data, :updated_at, DateTime.utc_now()))}
  end

  defp assign_preview_state(socket) do
    socket
    |> assign(:preview_mode, true)
    |> assign(:last_updated, DateTime.utc_now())
  end

  defp assign_portfolio_data(socket, portfolio) do
    sections = Map.get(portfolio, :sections, [])
    customization = Map.get(portfolio, :customization, %{})
    hero_section = find_hero_section(sections)

    socket
    |> assign(:portfolio, portfolio)
    |> assign(:sections, sections)
    |> assign(:customization, customization)
    |> assign(:hero_section, hero_section)
  end

  # Also add this helper function:
  defp find_hero_section(sections) when is_list(sections) do
    Enum.find(sections, fn section ->
      section_type = Map.get(section, :section_type) || Map.get(section, "section_type")
      section_type == :hero or section_type == "hero"
    end)
  end
  defp find_hero_section(_), do: nil

  @impl true
  def handle_info(msg, socket) do
    IO.puts("🔥 LivePreview received unhandled message: #{inspect(msg)}")
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    # FIXED: Make sure portfolio is available or provide defaults
    portfolio = Map.get(assigns, :portfolio, %{title: "Portfolio Preview"})
    customization = Map.get(assigns, :customization, %{})
    sections = Map.get(assigns, :sections, [])
    hero_section = Map.get(assigns, :hero_section)

    # Safely assign these to the template
    assigns = assigns
    |> Map.put(:portfolio, portfolio)
    |> Map.put(:customization, customization)
    |> Map.put(:sections, sections)
    |> Map.put(:hero_section, hero_section)

    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="h-full">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title><%= @portfolio.title %> - Preview</title>
        <style>
          <%= generate_preview_css(@customization) %>
        </style>
        <script src="https://cdn.tailwindcss.com"></script>
      </head>
      <body class="h-full bg-gray-50 portfolio-preview">

        <!-- Preview Header -->
        <div class="bg-blue-600 text-white px-4 py-2 text-sm font-medium text-center">
          <div class="flex items-center justify-center space-x-2">
            <svg class="w-4 h-4 animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 616 0z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
            </svg>
            <span>Live Preview</span>
          </div>
        </div>

        <!-- Portfolio Content -->
        <div class="portfolio-content">
          <.render_portfolio_preview
            layout_style={Map.get(@customization, "layout_style", "modern")}
            visible_sections={filter_visible_sections(@sections)}
            visible_non_hero_sections={filter_visible_non_hero_sections(@sections)}
            hero_section={@hero_section}
            customization={@customization}
            sections={@sections} />
        </div>

      </body>
    </html>
    """
  end

defp render_portfolio_preview(assigns) do
  # Get the layout from customization
  layout_style = Map.get(assigns.customization, "portfolio_layout", "dashboard")

  ~H"""
  <div class={["portfolio-container", "layout-#{layout_style}"]}>
    <!-- Hero Section (same for all layouts) -->
    <%= if @hero_section && @hero_section.visible do %>
      <.render_hero_preview hero_section={@hero_section} customization={@customization} />
    <% end %>

    <!-- Render sections based on layout -->
    <%= case layout_style do %>
      <% "single_column" -> %>
        <main class="portfolio-sections max-w-4xl mx-auto px-6 py-8">
          <%= for section <- @visible_non_hero_sections do %>
            <div class="mb-16">
              <.render_section_preview section={section} customization={@customization} />
            </div>
          <% end %>
        </main>

      <% "dashboard" -> %>
        <main class="portfolio-sections max-w-7xl mx-auto px-6 py-8">
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            <%= for section <- @visible_non_hero_sections do %>
              <div class="bg-white rounded-xl shadow-lg border p-6 hover:shadow-xl transition-shadow">
                <.render_section_preview section={section} customization={@customization} />
              </div>
            <% end %>
          </div>
        </main>

      <% "grid" -> %>
        <main class="portfolio-sections max-w-7xl mx-auto px-6 py-8">
          <div class="columns-1 md:columns-2 lg:columns-3 gap-8 space-y-8">
            <%= for section <- @visible_non_hero_sections do %>
              <div class="break-inside-avoid bg-white rounded-xl shadow-lg border p-6 mb-8">
                <.render_section_preview section={section} customization={@customization} />
              </div>
            <% end %>
          </div>
        </main>

      <% "timeline" -> %>
        <main class="portfolio-sections max-w-4xl mx-auto px-6 py-8">
          <div class="relative">
            <!-- Timeline line -->
            <div class="absolute left-8 top-0 bottom-0 w-1 bg-blue-300"></div>
            <%= for {section, index} <- Enum.with_index(@visible_non_hero_sections) do %>
              <div class="relative flex items-start mb-12">
                <!-- Timeline dot -->
                <div class="flex-shrink-0 w-16 h-16 bg-blue-600 rounded-full flex items-center justify-center text-white font-bold text-lg z-10">
                  <%= index + 1 %>
                </div>
                <!-- Content -->
                <div class="ml-8 flex-1 bg-white rounded-xl shadow-lg border p-6">
                  <.render_section_preview section={section} customization={@customization} />
                </div>
              </div>
            <% end %>
          </div>
        </main>

      <% _ -> %>
        <!-- Default fallback -->
        <main class="portfolio-sections max-w-6xl mx-auto px-6 py-8">
          <%= for section <- @visible_non_hero_sections do %>
            <div class="mb-12">
              <.render_section_preview section={section} customization={@customization} />
            </div>
          <% end %>
        </main>
    <% end %>
  </div>
  """
end

  defp render_hero_preview(assigns) do
    assigns = assign(assigns, :content, assigns.hero_section.content || %{})
    assigns = assign(assigns, :hero_style, Map.get(assigns.customization, "hero_style", "gradient"))

    ~H"""
    <section class={["hero-section", "hero-#{@hero_style}"]}>
      <div class="hero-container max-w-6xl mx-auto px-6 py-20 text-center">

        <!-- Headline -->
        <%= if Map.get(@content, "headline") do %>
          <h1 class="hero-headline text-4xl md:text-6xl font-bold text-white mb-6 drop-shadow-lg">
            <%= Map.get(@content, "headline") %>
          </h1>
        <% end %>

        <!-- Tagline -->
        <%= if Map.get(@content, "tagline") do %>
          <p class="hero-tagline text-xl md:text-2xl text-white/90 mb-8 drop-shadow">
            <%= Map.get(@content, "tagline") %>
          </p>
        <% end %>

        <!-- Description -->
        <%= if Map.get(@content, "description") do %>
          <p class="hero-description text-lg text-white/80 max-w-2xl mx-auto mb-12 drop-shadow">
            <%= Map.get(@content, "description") %>
          </p>
        <% end %>

        <!-- CTA Button -->
        <%= if Map.get(@content, "cta_text") && Map.get(@content, "cta_link") do %>
          <a
            href={Map.get(@content, "cta_link")}
            class="hero-cta inline-flex items-center px-8 py-4 bg-white text-gray-900 font-semibold rounded-lg hover:bg-gray-100 transition-all transform hover:scale-105 shadow-lg">
            <%= Map.get(@content, "cta_text") %>
            <svg class="w-5 h-5 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"/>
            </svg>
          </a>
        <% end %>

        <!-- Social Links -->
        <%= if Map.get(@content, "show_social") do %>
          <div class="hero-social mt-12 flex justify-center space-x-6">
            <!-- Mock social links for preview -->
            <a href="#" class="text-white/70 hover:text-white transition-colors">
              <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                <path d="M24 4.557c-.883.392-1.832.656-2.828.775 1.017-.609 1.798-1.574 2.165-2.724-.951.564-2.005.974-3.127 1.195-.897-.957-2.178-1.555-3.594-1.555-3.179 0-5.515 2.966-4.797 6.045-4.091-.205-7.719-2.165-10.148-5.144-1.29 2.213-.669 5.108 1.523 6.574-.806-.026-1.566-.247-2.229-.616-.054 2.281 1.581 4.415 3.949 4.89-.693.188-1.452.232-2.224.084.626 1.956 2.444 3.379 4.6 3.419-2.07 1.623-4.678 2.348-7.29 2.04 2.179 1.397 4.768 2.212 7.548 2.212 9.142 0 14.307-7.721 13.995-14.646.962-.695 1.797-1.562 2.457-2.549z"/>
              </svg>
            </a>
            <a href="#" class="text-white/70 hover:text-white transition-colors">
              <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
              </svg>
            </a>
          </div>
        <% end %>

      </div>
    </section>
    """
  end

  defp render_section_preview(assigns) do
    # Make sure section data is properly assigned
    assigns = assign(assigns, :content, assigns.section.content || %{})
    assigns = assign(assigns, :section_data, assigns.section)  # Add this line

    ~H"""
    <section class={["portfolio-section", "section-#{@section.section_type}"]} id={"section-#{@section.id}"}>
      <div class="max-w-6xl mx-auto px-6 py-16">
        <!-- Section Header -->
        <div class="text-center mb-12">
          <h2 class="section-title text-3xl md:text-4xl font-bold text-gray-900 mb-4">
            <%= @section.title %>
          </h2>
          <div class="w-24 h-1 bg-gradient-to-r from-blue-600 to-purple-600 mx-auto rounded-full"></div>
        </div>

        <!-- Section Content -->
        <div class="section-content">
          <.render_section_content_by_type section={@section} content={@content} customization={@customization} />
        </div>
      </div>
    </section>
    """
  end

  defp render_section_content_by_type(assigns) do
    ~H"""
    <%= case to_string(@section.section_type) do %>
      <% "about" -> %>
        <.render_about_content content={@content} customization={@customization} />
      <% "experience" -> %>
        <.render_experience_content content={@content} customization={@customization} />
      <% "education" -> %>
        <.render_education_content content={@content} customization={@customization} />
      <% "skills" -> %>
        <.render_skills_content content={@content} customization={@customization} />
      <% "projects" -> %>
        <.render_projects_content content={@content} customization={@customization} />
      <% "testimonials" -> %>
        <.render_testimonials_content content={@content} customization={@customization} />
      <% "contact" -> %>
        <.render_contact_content content={@content} customization={@customization} />
      <% "custom" -> %>
        <.render_custom_content content={@content} customization={@customization} />
      <% "certifications" -> %>
        <.render_certifications_content content={@content} customization={@customization} />
      <% "achievements" -> %>
        <.render_achievements_content content={@content} customization={@customization} />
      <% "services" -> %>
        <.render_services_content content={@content} customization={@customization} />
      <% "blog" -> %>
        <.render_blog_content content={@content} customization={@customization} />
      <% "gallery" -> %>
        <.render_gallery_content content={@content} customization={@customization} />
      <% _ -> %>
        <.render_default_content content={@content} customization={@customization} />
    <% end %>
    """
  end

  defp render_about_content(assigns) do
    assigns = assign(assigns, :highlights, Map.get(assigns.content, "highlights", []))

    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
      <!-- Profile Image -->
      <%= if Map.get(@content, "image_url") do %>
        <div class="order-2 lg:order-1">
          <img
            src={Map.get(@content, "image_url")}
            alt="Profile"
            class="w-full max-w-md mx-auto rounded-2xl shadow-lg" />
        </div>
      <% end %>

      <!-- About Text -->
      <div class={["order-1", if(Map.get(@content, "image_url"), do: "lg:order-2", else: "lg:col-span-2")]}>
        <%= if Map.get(@content, "content") do %>
          <div class="prose prose-lg max-w-none text-gray-700">
            <%= format_content_with_paragraphs(Map.get(@content, "content")) %>
          </div>
        <% end %>

        <!-- Highlights -->
        <%= if length(@highlights) > 0 do %>
          <div class="mt-8">
            <h4 class="text-lg font-semibold text-gray-900 mb-4">Key Highlights</h4>
            <ul class="space-y-2">
              <%= for highlight <- @highlights do %>
                <li class="flex items-center text-gray-700">
                  <svg class="w-5 h-5 text-blue-600 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                  <%= highlight %>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_education_content(%{content: content} = assigns) do
    items = Map.get(content, "items", [])

    ~H"""
    <%= if length(items) > 0 do %>
      <div class="space-y-8">
        <%= for item <- items do %>
          <div class="flex space-x-4">
            <div class="flex-shrink-0">
              <div class="w-12 h-12 bg-green-600 rounded-full flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                </svg>
              </div>
            </div>
            <div class="flex-1">
              <h4 class="text-xl font-semibold text-gray-900">
                <%= Map.get(item, "degree", "Degree") %>
              </h4>
              <p class="text-green-600 font-medium">
                <%= Map.get(item, "school", "Institution") %>
              </p>
              <p class="text-gray-600 text-sm mb-3">
                <%= Map.get(item, "duration", "Duration") %>
              </p>
              <%= if Map.get(item, "description") do %>
                <p class="text-gray-700">
                  <%= Map.get(item, "description") %>
                </p>
              <% end %>
              <%= if Map.get(item, "gpa") do %>
                <p class="text-sm text-gray-600 mt-2">
                  GPA: <%= Map.get(item, "gpa") %>
                </p>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No education items added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_certifications_content(%{content: content} = assigns) do
    items = Map.get(content, "items", [])

    ~H"""
    <%= if length(items) > 0 do %>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for item <- items do %>
          <div class="bg-white rounded-lg p-6 shadow-sm border hover:shadow-md transition-shadow">
            <div class="flex items-start justify-between mb-4">
              <div class="flex-1">
                <h4 class="text-lg font-semibold text-gray-900 mb-2">
                  <%= Map.get(item, "name", "Certification") %>
                </h4>
                <p class="text-blue-600 font-medium mb-1">
                  <%= Map.get(item, "issuer", "Issuing Organization") %>
                </p>
                <p class="text-gray-600 text-sm">
                  <%= Map.get(item, "date", "Issue Date") %>
                </p>
              </div>
              <%= if Map.get(item, "badge_url") do %>
                <img src={Map.get(item, "badge_url")} alt="Certification Badge" class="w-12 h-12 rounded" />
              <% end %>
            </div>

            <%= if Map.get(item, "description") do %>
              <p class="text-gray-700 text-sm mb-4">
                <%= Map.get(item, "description") %>
              </p>
            <% end %>

            <%= if Map.get(item, "credential_id") do %>
              <p class="text-xs text-gray-500 mb-3">
                Credential ID: <%= Map.get(item, "credential_id") %>
              </p>
            <% end %>

            <%= if Map.get(item, "verification_url") do %>
              <a href={Map.get(item, "verification_url")}
                 target="_blank"
                 class="inline-flex items-center text-blue-600 hover:text-blue-700 text-sm font-medium">
                Verify Certificate
                <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                </svg>
              </a>
            <% end %>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No certifications added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_achievements_content(%{content: content} = assigns) do
    items = Map.get(content, "items", [])

    ~H"""
    <%= if length(items) > 0 do %>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <%= for item <- items do %>
          <div class="bg-gradient-to-r from-yellow-50 to-orange-50 rounded-lg p-6 border border-yellow-200">
            <div class="flex items-start space-x-4">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-yellow-500 rounded-full flex items-center justify-center">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
                  </svg>
                </div>
              </div>
              <div class="flex-1">
                <h4 class="text-xl font-semibold text-gray-900 mb-2">
                  <%= Map.get(item, "title", "Achievement") %>
                </h4>
                <p class="text-yellow-700 font-medium mb-2">
                  <%= Map.get(item, "organization", "Organization") %>
                </p>
                <p class="text-gray-600 text-sm mb-3">
                  <%= Map.get(item, "date", "Date") %>
                </p>
                <%= if Map.get(item, "description") do %>
                  <p class="text-gray-700">
                    <%= Map.get(item, "description") %>
                  </p>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No achievements added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_services_content(%{content: content} = assigns) do
    items = Map.get(content, "items", [])

    ~H"""
    <%= if length(items) > 0 do %>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        <%= for item <- items do %>
          <div class="bg-white rounded-lg p-6 shadow-sm border hover:shadow-lg transition-shadow">
            <div class="text-center">
              <%= if Map.get(item, "icon") do %>
                <div class="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <span class="text-2xl"><%= Map.get(item, "icon") %></span>
                </div>
              <% else %>
                <div class="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg class="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2"/>
                  </svg>
                </div>
              <% end %>

              <h4 class="text-xl font-semibold text-gray-900 mb-3">
                <%= Map.get(item, "title", "Service") %>
              </h4>

              <p class="text-gray-600 mb-4">
                <%= Map.get(item, "description", "Service description...") %>
              </p>

              <%= if Map.get(item, "price") do %>
                <p class="text-2xl font-bold text-purple-600 mb-4">
                  <%= Map.get(item, "price") %>
                </p>
              <% end %>

              <%= if Map.get(item, "features") do %>
                <ul class="text-sm text-gray-600 space-y-1 mb-4">
                  <%= for feature <- String.split(Map.get(item, "features", ""), ",") do %>
                    <li class="flex items-center justify-center">
                      <svg class="w-4 h-4 text-green-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                      </svg>
                      <%= String.trim(feature) %>
                    </li>
                  <% end %>
                </ul>
              <% end %>

              <%= if Map.get(item, "cta_text") && Map.get(item, "cta_link") do %>
                <a href={Map.get(item, "cta_link")}
                   class="inline-block bg-purple-600 text-white px-6 py-2 rounded-lg hover:bg-purple-700 transition-colors">
                  <%= Map.get(item, "cta_text") %>
                </a>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No services added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_blog_content(%{content: content} = assigns) do
    items = Map.get(content, "items", [])

    ~H"""
    <%= if length(items) > 0 do %>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        <%= for item <- items do %>
          <article class="bg-white rounded-lg shadow-sm border overflow-hidden hover:shadow-lg transition-shadow">
            <%= if Map.get(item, "featured_image") do %>
              <img src={Map.get(item, "featured_image")}
                   alt={Map.get(item, "title", "Blog Post")}
                   class="w-full h-48 object-cover" />
            <% else %>
              <div class="w-full h-48 bg-gradient-to-r from-gray-400 to-gray-600 flex items-center justify-center">
                <svg class="w-12 h-12 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/>
                </svg>
              </div>
            <% end %>

            <div class="p-6">
              <div class="flex items-center text-sm text-gray-500 mb-3">
                <time datetime={Map.get(item, "published_date")}>
                  <%= Map.get(item, "published_date", "Recent") %>
                </time>
                <%= if Map.get(item, "category") do %>
                  <span class="mx-2">•</span>
                  <span class="bg-blue-100 text-blue-800 px-2 py-1 rounded-full text-xs">
                    <%= Map.get(item, "category") %>
                  </span>
                <% end %>
              </div>

              <h4 class="text-xl font-semibold text-gray-900 mb-3">
                <%= Map.get(item, "title", "Blog Post Title") %>
              </h4>

              <p class="text-gray-600 mb-4">
                <%= Map.get(item, "excerpt", "Blog post excerpt...") %>
              </p>

              <%= if Map.get(item, "url") do %>
                <a href={Map.get(item, "url")}
                   target="_blank"
                   class="inline-flex items-center text-blue-600 hover:text-blue-700 font-medium">
                  Read More
                  <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                  </svg>
                </a>
              <% end %>
            </div>
          </article>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No blog posts added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_gallery_content(%{content: content} = assigns) do
    items = Map.get(content, "items", [])

    ~H"""
    <%= if length(items) > 0 do %>
      <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        <%= for item <- items do %>
          <div class="group relative overflow-hidden rounded-lg bg-gray-100 aspect-square hover:shadow-lg transition-shadow">
            <%= if Map.get(item, "image_url") do %>
              <img src={Map.get(item, "image_url")}
                   alt={Map.get(item, "caption", "Gallery Image")}
                   class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />

              <!-- Overlay -->
              <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-40 transition-opacity duration-300 flex items-end">
                <%= if Map.get(item, "caption") do %>
                  <div class="p-4 text-white opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                    <p class="text-sm font-medium"><%= Map.get(item, "caption") %></p>
                    <%= if Map.get(item, "description") do %>
                      <p class="text-xs text-gray-200 mt-1"><%= Map.get(item, "description") %></p>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="w-full h-full flex items-center justify-center">
                <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No gallery images added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_experience_content(%{content: content} = assigns) do
    items = Map.get(content, "items", [])

    ~H"""
    <%= if length(items) > 0 do %>
      <div class="space-y-8">
        <%= for item <- items do %>
          <div class="flex space-x-4">
            <div class="flex-shrink-0">
              <div class="w-12 h-12 bg-blue-600 rounded-full flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2"/>
                </svg>
              </div>
            </div>
            <div class="flex-1">
              <h4 class="text-xl font-semibold text-gray-900">
                <%= Map.get(item, "title", "Position Title") %>
              </h4>
              <p class="text-blue-600 font-medium">
                <%= Map.get(item, "company", "Company Name") %>
              </p>
              <p class="text-gray-600 text-sm mb-3">
                <%= Map.get(item, "duration", "Duration") %>
              </p>
              <p class="text-gray-700">
                <%= Map.get(item, "description", "Role description...") %>
              </p>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No experience items added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_skills_content(%{content: content} = assigns) do
    categories = Map.get(content, "categories", [])

    ~H"""
    <%= if length(categories) > 0 do %>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for category <- categories do %>
          <div class="bg-white rounded-lg p-6 shadow-sm border">
            <h4 class="text-lg font-semibold text-gray-900 mb-4">
              <%= Map.get(category, "name", "Skill Category") %>
            </h4>
            <div class="flex flex-wrap gap-2">
              <%= for skill <- Map.get(category, "skills", []) do %>
                <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
                  <%= skill %>
                </span>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No skill categories added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_projects_content(%{content: content} = assigns) do
    items = Map.get(content, "items", [])

    ~H"""
    <%= if length(items) > 0 do %>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        <%= for item <- items do %>
          <div class="bg-white rounded-lg shadow-sm border overflow-hidden hover:shadow-lg transition-shadow">
            <%= if Map.get(item, "image_url") do %>
              <img
                src={Map.get(item, "image_url")}
                alt={Map.get(item, "title", "Project")}
                class="w-full h-48 object-cover" />
            <% else %>
              <div class="w-full h-48 bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center">
                <svg class="w-12 h-12 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                </svg>
              </div>
            <% end %>

            <div class="p-6">
              <h4 class="text-xl font-semibold text-gray-900 mb-2">
                <%= Map.get(item, "title", "Project Title") %>
              </h4>
              <p class="text-gray-600 mb-4">
                <%= Map.get(item, "description", "Project description...") %>
              </p>
              <%= if Map.get(item, "technologies") do %>
                <div class="flex flex-wrap gap-1 mb-4">
                  <%= for tech <- String.split(Map.get(item, "technologies", ""), ",") do %>
                    <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-800">
                      <%= String.trim(tech) %>
                    </span>
                  <% end %>
                </div>
              <% end %>
              <%= if Map.get(item, "url") do %>
                <a
                  href={Map.get(item, "url")}
                  target="_blank"
                  class="inline-flex items-center text-blue-600 hover:text-blue-700 font-medium">
                  View Project
                  <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                  </svg>
                </a>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No projects added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_testimonials_content(%{content: content} = assigns) do
    items = Map.get(content, "items", [])

    ~H"""
    <%= if length(items) > 0 do %>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <%= for item <- items do %>
          <div class="bg-white rounded-lg p-6 shadow-sm border">
            <div class="flex items-center mb-4">
              <div class="flex text-yellow-400">
                <%= for _ <- 1..5 do %>
                  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
                  </svg>
                <% end %>
              </div>
            </div>
            <blockquote class="text-gray-700 mb-4">
              "<%= Map.get(item, "content", "Testimonial content...") %>"
            </blockquote>
            <div class="flex items-center">
              <%= if Map.get(item, "avatar_url") do %>
                <img
                  src={Map.get(item, "avatar_url")}
                  alt={Map.get(item, "name", "Client")}
                  class="w-12 h-12 rounded-full mr-4" />
              <% else %>
                <div class="w-12 h-12 bg-gray-300 rounded-full mr-4 flex items-center justify-center">
                  <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                  </svg>
                </div>
              <% end %>
              <div>
                <div class="font-semibold text-gray-900">
                  <%= Map.get(item, "name", "Client Name") %>
                </div>
                <div class="text-gray-600 text-sm">
                  <%= Map.get(item, "title", "Position") %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No testimonials added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_contact_content(%{content: content} = assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">

        <!-- Contact Info -->
        <div class="space-y-4">
          <h4 class="text-lg font-semibold text-gray-900 mb-4">Get In Touch</h4>

          <%= if Map.get(@content, "email") do %>
            <div class="flex items-center space-x-3">
              <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
              <span class="text-gray-700"><%= Map.get(@content, "email") %></span>
            </div>
          <% end %>

          <%= if Map.get(@content, "phone") do %>
            <div class="flex items-center space-x-3">
              <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
              </svg>
              <span class="text-gray-700"><%= Map.get(@content, "phone") %></span>
            </div>
          <% end %>

          <%= if Map.get(@content, "location") do %>
            <div class="flex items-center space-x-3">
              <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
              </svg>
              <span class="text-gray-700"><%= Map.get(@content, "location") %></span>
            </div>
          <% end %>
        </div>

        <!-- Contact Form (if enabled) -->
        <%= if Map.get(@content, "contact_form_enabled") do %>
          <div>
            <form class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <input type="email" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Message</label>
                <textarea rows="4" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"></textarea>
              </div>
              <button type="submit" class="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg transition-colors">
                Send Message
              </button>
            </form>
          </div>
        <% end %>

      </div>
    </div>
    """
  end

  defp render_default_content(%{content: content} = assigns) do
    ~H"""
    <%= if Map.get(@content, "content") do %>
      <div class="prose prose-lg max-w-none text-gray-700">
        <%= format_content_with_paragraphs(Map.get(@content, "content")) %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No content added yet.</p>
      </div>
    <% end %>
    """
  end

  # Helper functions for content formatting and styling

  defp format_content_with_paragraphs(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&("<p class=\"mb-4\">#{&1}</p>"))
    |> Enum.join("")
    |> raw()
  end
  defp format_content_with_paragraphs(_), do: ""

  defp get_custom_section_styles(content) do
    bg_color = Map.get(content, "background_color", "#ffffff")
    "background-color: #{bg_color};"
  end

  defp get_custom_text_color(content) do
    text_color = Map.get(content, "text_color", "#000000")
    "color: #{text_color};"
  end

  defp get_custom_padding_class(padding) do
    case padding do
      "compact" -> "p-4"
      "spacious" -> "p-12"
      _ -> "p-8"
    end
  end

  defp get_font_preview_style(font) do
    case font do
      "inter" -> "font-family: 'Inter', sans-serif;"
      "serif" -> "font-family: 'Times New Roman', serif;"
      "mono" -> "font-family: 'Monaco', monospace;"
      "system" -> "font-family: -apple-system, BlinkMacSystemFont, sans-serif;"
      _ -> ""
    end
  end

  defp get_theme_css(theme) do
    case theme do
      "minimal" -> """
      .portfolio-section { padding: 1rem !important; margin: 0.5rem 0 !important; }
      .section-title { font-size: 1.5rem !important; }
      """
      "creative" -> """
      .portfolio-section { padding: 3rem !important; border-radius: 20px !important; }
      .section-title { font-size: 2.5rem !important; font-weight: 800 !important; }
      """
      "professional" -> """
      .portfolio-section { padding: 2.5rem !important; border: 2px solid #e5e7eb !important; }
      .section-title { font-size: 2rem !important; text-transform: uppercase !important; }
      """
      _ -> """
      .portfolio-section { padding: 2rem !important; }
      .section-title { font-size: 2rem !important; }
      """
    end
  end

  defp get_embed_url(url) do
    cond do
      String.contains?(url, "youtube.com/watch") ->
        video_id = url |> URI.parse() |> Map.get(:query) |> URI.decode_query() |> Map.get("v")
        "https://www.youtube.com/embed/#{video_id}"

      String.contains?(url, "youtu.be/") ->
        video_id = url |> String.split("/") |> List.last()
        "https://www.youtube.com/embed/#{video_id}"

      String.contains?(url, "vimeo.com/") ->
        video_id = url |> String.split("/") |> List.last()
        "https://player.vimeo.com/video/#{video_id}"

      true -> url
    end
  end

  defp filter_visible_sections(sections) do
    Enum.filter(sections, & &1.visible)
  end

  defp filter_visible_non_hero_sections(sections) do
    sections
    |> Enum.filter(& &1.visible)
    |> Enum.reject(&(&1.section_type == :hero or &1.section_type == "hero"))
  end

  defp generate_preview_css(customization) do
    primary_color = Map.get(customization, "primary_color", "#1e40af")
    secondary_color = Map.get(customization, "secondary_color", "#64748b")
    accent_color = Map.get(customization, "accent_color", "#3b82f6")
    hero_style = Map.get(customization, "hero_style", "gradient")
    layout_style = Map.get(customization, "portfolio_layout", "dashboard")
    font_family = Map.get(customization, "font_family", "inter")

    base_css = """
    :root {
      --primary-color: #{primary_color};
      --secondary-color: #{secondary_color};
      --accent-color: #{accent_color};
    }

    body {
      #{get_font_family_css(font_family)}
    }

    .hero-section {
      #{get_hero_background_css(hero_style, primary_color, accent_color)}
      min-height: 60vh;
      display: flex;
      align-items: center;
      position: relative;
    }

    .section-title {
      color: var(--primary-color) !important;
    }

    .portfolio-section {
      border-color: var(--secondary-color);
    }

    #{get_theme_css(Map.get(customization, "layout_style", "modern"))}
    """

    # Keep existing layout CSS
    layout_css = case layout_style do
      "dashboard" -> """
      .layout-dashboard .portfolio-sections .bg-white:hover {
        transform: translateY(-4px);
        box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
      }
      """
      "timeline" -> """
      .layout-timeline .bg-blue-600 {
        background-color: var(--primary-color) !important;
        box-shadow: 0 0 0 4px white, 0 0 0 8px var(--primary-color);
      }
      """
      _ -> ""
    end

    base_css <> layout_css
  end

  defp get_font_family_css(font_family) do
    case font_family do
      "inter" -> """
      * { font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important; }
      """
      "serif" -> """
      * { font-family: 'Times New Roman', Times, serif !important; }
      """
      "mono" -> """
      * { font-family: 'Monaco', 'Courier New', monospace !important; }
      """
      "system" -> """
      * { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important; }
      """
      _ -> ""
    end
  end

  defp get_hero_background_css(hero_style, primary_color, accent_color) do
    case hero_style do
      "gradient" ->
        "background: linear-gradient(135deg, #{primary_color}, #{accent_color});"

      "minimal" ->
        "background: #{primary_color};"

      "image" ->
        "background: linear-gradient(135deg, #{primary_color}aa, #{accent_color}aa), url('/images/hero-bg.jpg');
         background-size: cover;
         background-position: center;"

      _ ->
        "background: linear-gradient(135deg, #{primary_color}, #{accent_color});"
    end
  end

  defp render_custom_content(assigns) do
    assigns = assign(assigns, :layout_type, Map.get(assigns.content, "layout_type", "text"))
    assigns = assign(assigns, :custom_padding_class, get_custom_padding_class(Map.get(assigns.content, "padding", "normal")))
    assigns = assign(assigns, :show_border, Map.get(assigns.content, "show_border"))
    assigns = assign(assigns, :custom_section_styles, get_custom_section_styles(assigns.content))
    assigns = assign(assigns, :custom_text_color, get_custom_text_color(assigns.content))

    ~H"""
    <div class={[
      "custom-section",
      "rounded-lg",
      @custom_padding_class,
      if(@show_border, do: "border border-gray-200", else: "")
    ]}
    style={@custom_section_styles}>

      <!-- Custom Title -->
      <%= if Map.get(@content, "title") do %>
        <h3 class="text-2xl font-bold mb-6" style={@custom_text_color}>
          <%= Map.get(@content, "title") %>
        </h3>
      <% end %>

      <!-- Content by Layout Type -->
      <%= case @layout_type do %>
        <% "text" -> %>
          <%= if Map.get(@content, "content") do %>
            <div class="prose max-w-none" style={@custom_text_color}>
              <%= format_content_with_paragraphs(Map.get(@content, "content")) %>
            </div>
          <% end %>

        <% "image_text" -> %>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
            <!-- Add image handling here -->
            <div class="prose max-w-none" style={@custom_text_color}>
              <%= format_content_with_paragraphs(Map.get(@content, "content")) %>
            </div>
          </div>

        <% "video" -> %>
          <%= if Map.get(@content, "video_url") do %>
            <div class="aspect-video mb-6">
              <iframe
                src={get_embed_url(Map.get(@content, "video_url"))}
                class="w-full h-full rounded-lg"
                frameborder="0"
                allowfullscreen>
              </iframe>
            </div>
          <% end %>
          <%= if Map.get(@content, "content") do %>
            <div class="prose max-w-none" style={@custom_text_color}>
              <%= format_content_with_paragraphs(Map.get(@content, "content")) %>
            </div>
          <% end %>

        <% "embed" -> %>
          <%= if Map.get(@content, "embed_code") do %>
            <div class="mb-6">
              <%= raw(Map.get(@content, "embed_code")) %>
            </div>
          <% end %>
          <%= if Map.get(@content, "content") do %>
            <div class="prose max-w-none" style={@custom_text_color}>
              <%= format_content_with_paragraphs(Map.get(@content, "content")) %>
            </div>
          <% end %>

        <% _ -> %>
          <%= if Map.get(@content, "content") do %>
            <div class="prose max-w-none" style={@custom_text_color}>
              <%= format_content_with_paragraphs(Map.get(@content, "content")) %>
            </div>
          <% end %>
      <% end %>

      <!-- Custom CSS -->
      <%= if Map.get(@content, "custom_css") do %>
        <style>
          <%= raw(Map.get(@content, "custom_css")) %>
        </style>
      <% end %>

    </div>
    """
  end

  defp render_about_content(assigns) do
    assigns = assign(assigns, :highlights, Map.get(assigns.content, "highlights", []))

    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
      <!-- Profile Image -->
      <%= if Map.get(@content, "image_url") do %>
        <div class="order-2 lg:order-1">
          <img
            src={Map.get(@content, "image_url")}
            alt="Profile"
            class="w-full max-w-md mx-auto rounded-2xl shadow-lg" />
        </div>
      <% end %>

      <!-- About Text -->
      <div class={["order-1", if(Map.get(@content, "image_url"), do: "lg:order-2", else: "lg:col-span-2")]}>
        <%= if Map.get(@content, "content") do %>
          <div class="prose prose-lg max-w-none text-gray-700">
            <%= format_content_with_paragraphs(Map.get(@content, "content")) %>
          </div>
        <% end %>

        <!-- Highlights -->
        <%= if length(@highlights) > 0 do %>
          <div class="mt-8">
            <h4 class="text-lg font-semibold text-gray-900 mb-4">Key Highlights</h4>
            <ul class="space-y-2">
              <%= for highlight <- @highlights do %>
                <li class="flex items-center text-gray-700">
                  <svg class="w-5 h-5 text-blue-600 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                  <%= highlight %>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
