# lib/frestyl_web/live/portfolio_live/show.ex - Enhanced Portfolio Show with Export
defmodule FrestylWeb.PortfolioLive.Show do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.PdfExport
  alias FrestylWeb.PortfolioLive.PdfExportComponent

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
      {:ok, portfolio} ->
        # Track visit if not the owner
        unless owns_portfolio?(portfolio, socket.assigns.current_user) do
          track_portfolio_visit(portfolio, socket)
        end

        # Check if user can export
        can_export = can_export_portfolio?(portfolio, socket.assigns.current_user)

        socket =
          socket
          |> assign(:page_title, portfolio.title)
          |> assign(:portfolio, portfolio)
          |> assign(:can_export, can_export)
          |> assign(:show_export_modal, false)
          |> assign(:export_processing, false)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Portfolio not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Portfolio Header with Export Options -->
      <header class="bg-white shadow-sm border-b border-gray-200 sticky top-0 z-40">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-4">
            <!-- Portfolio Info -->
            <div class="flex items-center space-x-4">
              <div class="w-12 h-12 bg-gradient-to-br from-blue-500 to-purple-600 rounded-xl flex items-center justify-center">
                <span class="text-white font-bold text-lg">
                  <%= String.first(@portfolio.title) %>
                </span>
              </div>
              <div>
                <h1 class="text-xl font-bold text-gray-900"><%= @portfolio.title %></h1>
                <p class="text-sm text-gray-600">
                  <%= if @portfolio.user do %>
                    by <%= @portfolio.user.name || @portfolio.user.username %>
                  <% end %>
                </p>
              </div>
            </div>

            <!-- Action Buttons -->
            <div class="flex items-center space-x-3">
              <!-- Share Button -->
              <button phx-click="show_share_options"
                      class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors shadow-md hover:shadow-lg">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"/>
                </svg>
                Share
              </button>

              <!-- Export Button (only if allowed) -->
              <%= if @can_export do %>
                <.live_component
                  module={FrestylWeb.PortfolioLive.PdfExportComponent}
                  id="portfolio-export"
                  portfolio={@portfolio}
                  current_user={@current_user}
                />
              <% end %>

              <!-- Print Button -->
              <button onclick="window.print()"
                      class="inline-flex items-center px-4 py-2 bg-gray-600 text-white rounded-lg font-medium hover:bg-gray-700 transition-colors">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
                </svg>
                Print
              </button>
            </div>
          </div>
        </div>
      </header>

      <!-- Portfolio Content -->
      <main class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= render_portfolio_content(assigns) %>
      </main>

      <!-- Share Modal -->
      <%= if assigns[:show_share_modal] do %>
        <%= render_share_modal(assigns) %>
      <% end %>

      <!-- Print Styles -->
      <style media="print">
        header, .no-print { display: none !important; }
        body { margin: 0; padding: 20px; }
        .portfolio-section { break-inside: avoid; margin-bottom: 20px; }
        .portfolio-section h2 { color: #1f2937 !important; }
      </style>
    </div>
    """
  end

  defp render_portfolio_content(assigns) do
    ~H"""
    <div class="space-y-8">
      <%= for section <- @portfolio.sections do %>
        <%= if section.visible do %>
          <div class="portfolio-section bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
            <div class="p-8">
              <%= if section.title do %>
                <h2 class="text-2xl font-bold text-gray-900 mb-6"><%= section.title %></h2>
              <% end %>

              <%= render_section_content(section, assigns) %>
            </div>
          </div>
        <% end %>
      <% end %>

      <!-- Portfolio Footer -->
      <div class="text-center py-8 border-t border-gray-200">
        <p class="text-gray-600">
          Created with <span class="text-blue-600 font-semibold">Frestyl</span> •
          Professional Portfolio Platform
        </p>
      </div>
    </div>
    """
  end

  defp render_section_content(section, assigns) do
    case section.section_type do
      :intro -> render_intro_section(section, assigns)
      :experience -> render_experience_section(section, assigns)
      :education -> render_education_section(section, assigns)
      :skills -> render_skills_section(section, assigns)
      :projects -> render_projects_section(section, assigns)
      :contact -> render_contact_section(section, assigns)
      _ -> render_generic_section(section, assigns)
    end
  end

  defp render_intro_section(section, assigns) do
    content = section.content || %{}

    ~H"""
    <div class="space-y-6">
      <%= if content["headline"] do %>
        <h3 class="text-3xl font-bold text-gray-900"><%= content["headline"] %></h3>
      <% end %>

      <%= if content["summary"] do %>
        <div class="prose prose-lg max-w-none text-gray-700">
          <%= Phoenix.HTML.raw(String.replace(content["summary"], "\n", "<br>")) %>
        </div>
      <% end %>

      <%= if content["location"] do %>
        <div class="flex items-center text-gray-600">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
          <%= content["location"] %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_experience_section(section, assigns) do
    jobs = get_in(section.content, ["jobs"]) || []

    ~H"""
    <div class="space-y-8">
      <%= for job <- jobs do %>
        <div class="border-l-4 border-blue-500 pl-6">
          <div class="flex flex-col lg:flex-row lg:justify-between lg:items-start mb-2">
            <div>
              <h4 class="text-xl font-semibold text-gray-900"><%= job["title"] || "Position" %></h4>
              <p class="text-lg text-blue-600 font-medium"><%= job["company"] || "Company" %></p>
            </div>
            <div class="text-sm text-gray-500 lg:text-right">
              <%= job["start_date"] || "" %>
              <%= if job["end_date"] || job["current"] do %>
                - <%= if job["current"], do: "Present", else: job["end_date"] %>
              <% end %>
            </div>
          </div>

          <%= if job["description"] do %>
            <div class="prose max-w-none text-gray-700 mt-3">
              <%= Phoenix.HTML.raw(String.replace(job["description"], "\n", "<br>")) %>
            </div>
          <% end %>

          <%= if job["skills"] && length(job["skills"]) > 0 do %>
            <div class="flex flex-wrap gap-2 mt-4">
              <%= for skill <- job["skills"] do %>
                <span class="px-3 py-1 bg-blue-100 text-blue-800 text-sm font-medium rounded-full">
                  <%= skill %>
                </span>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_education_section(section, assigns) do
    education = get_in(section.content, ["education"]) || []

    ~H"""
    <div class="space-y-6">
      <%= for edu <- education do %>
        <div class="border-l-4 border-purple-500 pl-6">
          <div class="flex flex-col lg:flex-row lg:justify-between lg:items-start">
            <div>
              <h4 class="text-xl font-semibold text-gray-900">
                <%= edu["degree"] || "Degree" %>
                <%= if edu["field"] do %>
                  <span class="text-purple-600">in <%= edu["field"] %></span>
                <% end %>
              </h4>
              <p class="text-lg text-purple-600 font-medium"><%= edu["institution"] || "Institution" %></p>
            </div>
            <div class="text-sm text-gray-500">
              <%= edu["start_date"] || edu["year"] %>
              <%= if edu["end_date"] do %>
                - <%= edu["end_date"] %>
              <% end %>
            </div>
          </div>

          <%= if edu["gpa"] do %>
            <p class="text-gray-600 mt-2">GPA: <%= edu["gpa"] %></p>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_skills_section(section, assigns) do
    skills = get_in(section.content, ["skills"]) || []

    ~H"""
    <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
      <%= for skill <- skills do %>
        <div class="bg-gray-50 rounded-lg px-4 py-3 text-center border border-gray-200 hover:border-blue-300 transition-colors">
          <span class="font-medium text-gray-900">
            <%= if is_binary(skill), do: skill, else: skill["name"] || "Skill" %>
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_projects_section(section, assigns) do
    projects = get_in(section.content, ["projects"]) || []

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
      <%= for project <- projects do %>
        <div class="bg-gray-50 rounded-xl p-6 border border-gray-200">
          <h4 class="text-xl font-semibold text-gray-900 mb-3">
            <%= project["title"] || "Project" %>
          </h4>

          <%= if project["description"] do %>
            <p class="text-gray-700 mb-4">
              <%= project["description"] %>
            </p>
          <% end %>

          <%= if project["technologies"] && length(project["technologies"]) > 0 do %>
            <div class="flex flex-wrap gap-2 mb-4">
              <%= for tech <- project["technologies"] do %>
                <span class="px-2 py-1 bg-blue-100 text-blue-800 text-xs font-medium rounded">
                  <%= tech %>
                </span>
              <% end %>
            </div>
          <% end %>

          <div class="flex space-x-4">
            <%= if project["url"] do %>
              <a href={project["url"]} target="_blank"
                 class="text-blue-600 hover:text-blue-700 font-medium text-sm">
                View Project →
              </a>
            <% end %>

            <%= if project["github_url"] do %>
              <a href={project["github_url"]} target="_blank"
                 class="text-gray-600 hover:text-gray-700 font-medium text-sm">
                GitHub →
              </a>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_contact_section(section, assigns) do
    content = section.content || %{}

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <%= if content["email"] do %>
        <div class="flex items-center space-x-3 p-4 bg-gray-50 rounded-lg">
          <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
          </svg>
          <div>
            <p class="text-sm text-gray-500">Email</p>
            <a href={"mailto:#{content["email"]}"} class="text-blue-600 hover:text-blue-700 font-medium">
              <%= content["email"] %>
            </a>
          </div>
        </div>
      <% end %>

      <%= if content["phone"] do %>
        <div class="flex items-center space-x-3 p-4 bg-gray-50 rounded-lg">
          <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
          </svg>
          <div>
            <p class="text-sm text-gray-500">Phone</p>
            <a href={"tel:#{content["phone"]}"} class="text-green-600 hover:text-green-700 font-medium">
              <%= content["phone"] %>
            </a>
          </div>
        </div>
      <% end %>

      <%= if content["location"] do %>
        <div class="flex items-center space-x-3 p-4 bg-gray-50 rounded-lg">
          <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
          <div>
            <p class="text-sm text-gray-500">Location</p>
            <p class="text-purple-600 font-medium">
              <%= content["location"] %>
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_generic_section(section, assigns) do
    content = section.content || %{}

    ~H"""
    <div class="prose max-w-none">
      <%= if content["content"] do %>
        <%= Phoenix.HTML.raw(String.replace(content["content"], "\n", "<br>")) %>
      <% else %>
        <p class="text-gray-600">Content for this section is being updated.</p>
      <% end %>
    </div>
    """
  end

  defp render_share_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 backdrop-blur-sm"
         phx-click="hide_share_modal">
      <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4" phx-click-away="hide_share_modal">
        <!-- Modal Header -->
        <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-4 rounded-t-2xl">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-bold text-white">Share Portfolio</h3>
            <button phx-click="hide_share_modal" class="text-white hover:text-gray-200">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Modal Content -->
        <div class="p-6 space-y-4">
          <!-- Copy Link -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Portfolio URL</label>
            <div class="flex">
              <input type="text"
                     value={portfolio_url(@portfolio.slug)}
                     readonly
                     class="flex-1 px-3 py-2 border border-gray-300 rounded-l-lg text-sm"
                     id="portfolio-url" />
              <button onclick="copyToClipboard('portfolio-url')"
                      class="px-4 py-2 bg-blue-600 text-white rounded-r-lg hover:bg-blue-700 transition-colors">
                Copy
              </button>
            </div>
          </div>

          <!-- Social Share Buttons -->
          <div class="space-y-3">
            <p class="text-sm font-medium text-gray-700">Share on social media</p>

            <div class="grid grid-cols-2 gap-3">
              <a href={linkedin_share_url(@portfolio)}
                 target="_blank"
                 class="flex items-center justify-center px-4 py-2 bg-blue-700 text-white rounded-lg hover:bg-blue-800 transition-colors">
                <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451c.969 0 1.771-.773 1.771-1.729V1.729C24 .774 23.194 0 22.225 0z"/>
                </svg>
                LinkedIn
              </a>

              <a href={twitter_share_url(@portfolio)}
                 target="_blank"
                 class="flex items-center justify-center px-4 py-2 bg-blue-400 text-white rounded-lg hover:bg-blue-500 transition-colors">
                <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
                </svg>
                Twitter
              </a>
            </div>
          </div>

          <!-- Email Share -->
          <div>
            <a href={email_share_url(@portfolio)}
               class="w-full flex items-center justify-center px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
              Share via Email
            </a>
          </div>
        </div>
      </div>
    </div>

    <script>
      function copyToClipboard(elementId) {
        const element = document.getElementById(elementId);
        element.select();
        element.setSelectionRange(0, 99999);
        document.execCommand('copy');

        // Show feedback
        const button = element.nextElementSibling;
        const originalText = button.textContent;
        button.textContent = 'Copied!';
        button.classList.add('bg-green-600');
        button.classList.remove('bg-blue-600');

        setTimeout(() => {
          button.textContent = originalText;
          button.classList.remove('bg-green-600');
          button.classList.add('bg-blue-600');
        }, 2000);
      }
    </script>
    """
  end

  @impl true
  def handle_event("show_share_options", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, true)}
  end

  @impl true
  def handle_event("hide_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, false)}
  end

  @impl true
  def handle_info({:start_pdf_export, format}, socket) do
    portfolio = socket.assigns.portfolio

    # Start PDF generation in background
    Task.start(fn ->
      case PdfExport.export_portfolio(portfolio.slug, format: format) do
        {:ok, result} ->
          send(self(), {:pdf_export_complete, result.url})
        {:error, reason} ->
          send(self(), {:pdf_export_failed, reason})
      end
    end)

    {:noreply, assign(socket, :export_processing, true)}
  end

  @impl true
  def handle_info({:pdf_export_complete, download_url}, socket) do
    send_update(FrestylWeb.PortfolioLive.PdfExportComponent,
                id: "portfolio-export",
                export_complete: download_url)

    {:noreply, assign(socket, :export_processing, false)}
  end

  @impl true
  def handle_info({:pdf_export_failed, reason}, socket) do
    send_update(FrestylWeb.PortfolioLive.PdfExportComponent,
                id: "portfolio-export",
                export_failed: reason)

    {:noreply,
     socket
     |> assign(:export_processing, false)
     |> put_flash(:error, "Export failed: #{reason}")}
  end

  # Helper functions

  defp owns_portfolio?(portfolio, user) do
    user && portfolio.user_id == user.id
  end

  defp can_export_portfolio?(portfolio, user) do
    # Portfolio owner can always export
    # Public portfolios can be exported by anyone
    # Check if portfolio allows resume export
    owns_portfolio?(portfolio, user) ||
    (portfolio.visibility == :public && portfolio.allow_resume_export)
  end

  defp track_portfolio_visit(portfolio, socket) do
    # Track portfolio visit for analytics
    attrs = %{
      portfolio_id: portfolio.id,
      ip_address: get_connect_info(socket, :peer_data).address |> :inet.ntoa() |> to_string(),
      user_agent: get_connect_info(socket, :user_agent) || "",
      referrer: get_connect_info(socket, :x_headers)["referer"] || ""
    }

    Portfolios.create_visit(attrs)
  rescue
    _ -> :ok  # Fail silently for analytics
  end

  defp portfolio_url(slug) do
    FrestylWeb.Endpoint.url() <> "/p/#{slug}"
  end

  defp linkedin_share_url(portfolio) do
    url = portfolio_url(portfolio.slug)
    title = portfolio.title
    summary = portfolio.description || "Check out my professional portfolio"

    "https://www.linkedin.com/sharing/share-offsite/?url=#{URI.encode(url)}&title=#{URI.encode(title)}&summary=#{URI.encode(summary)}"
  end

  defp twitter_share_url(portfolio) do
    url = portfolio_url(portfolio.slug)
    text = "Check out my portfolio: #{portfolio.title}"

    "https://twitter.com/intent/tweet?url=#{URI.encode(url)}&text=#{URI.encode(text)}"
  end

  defp email_share_url(portfolio) do
    url = portfolio_url(portfolio.slug)
    subject = "Portfolio: #{portfolio.title}"
    body = "I'd like to share my professional portfolio with you: #{url}"

    "mailto:?subject=#{URI.encode(subject)}&body=#{URI.encode(body)}"
  end
end
