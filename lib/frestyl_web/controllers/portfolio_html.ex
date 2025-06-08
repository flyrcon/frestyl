# Update lib/frestyl_web/controllers/portfolio_html.ex - Part 1

defmodule FrestylWeb.PortfolioHTML do
  use FrestylWeb, :html
  alias Frestyl.Portfolios.PortfolioTemplates

  use Gettext, backend: FrestylWeb.Gettext

  def show(assigns) do
    # Get template config based on portfolio theme
    template_config = PortfolioTemplates.get_template_config(assigns.portfolio.theme || "executive")

    # Add template config to assigns (this is the correct way in HTML modules)
    assigns = Map.put(assigns, :template_config, template_config)
    assigns = Map.put(assigns, :background_classes, PortfolioTemplates.get_background_classes(template_config))
    assigns = Map.put(assigns, :font_classes, PortfolioTemplates.get_font_classes(template_config))

    case template_config.layout do
      "dashboard" -> render_executive_layout(assigns)
      "terminal" -> render_developer_layout(assigns)
      "gallery" -> render_designer_layout(assigns)
      "case_study" -> render_consultant_layout(assigns)
      "fullscreen" -> render_photographer_layout(assigns)  # This should render for your "photographer" theme
      "services" -> render_freelancer_layout(assigns)
      "exhibition" -> render_artist_layout(assigns)
      "typography" -> render_minimalist_layout(assigns)
      _ -> render_default_layout(assigns)
    end
  end

  # EXECUTIVE: Corporate Dashboard Layout
  defp render_executive_layout(assigns) do
    ~H"""
    <div class={[@background_classes, @font_classes, "min-h-screen"]}>
      <!-- Corporate Header with Metrics -->
      <header class="relative overflow-hidden bg-slate-900 text-white">
        <div class="absolute inset-0 bg-gradient-to-r from-blue-600/20 to-cyan-600/20"></div>
        <div class="relative max-w-7xl mx-auto px-6 py-12">
          <div class="grid lg:grid-cols-3 gap-8 items-center">
            <div class="lg:col-span-2">
              <h1 class="text-4xl lg:text-5xl font-bold mb-4"><%= @portfolio.title %></h1>
              <p class="text-xl text-blue-100 mb-6"><%= @portfolio.description %></p>

              <!-- Executive Metrics -->
              <div class="grid grid-cols-3 gap-6">
                <div class="text-center">
                  <div class="text-3xl font-bold text-cyan-400"><%= get_portfolio_metric(@portfolio, :experience_years, "10+") %></div>
                  <div class="text-sm text-gray-300">Years Experience</div>
                </div>
                <div class="text-center">
                  <div class="text-3xl font-bold text-blue-400"><%= get_portfolio_metric(@portfolio, :team_size, "50+") %></div>
                  <div class="text-sm text-gray-300">Team Members</div>
                </div>
                <div class="text-center">
                  <div class="text-3xl font-bold text-green-400"><%= get_portfolio_metric(@portfolio, :revenue_growth, "150%") %></div>
                  <div class="text-sm text-gray-300">Growth</div>
                </div>
              </div>
            </div>

            <!-- Executive Photo -->
            <div class="lg:justify-self-end">
              <div class="w-64 h-64 bg-gradient-to-br from-blue-500 to-cyan-600 rounded-xl shadow-2xl flex items-center justify-center">
                <span class="text-6xl font-bold text-white">
                  <%= String.first(@portfolio.title) %>
                </span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <!-- Navigation Sidebar -->
      <div class="flex">
        <nav class="w-64 bg-slate-800 min-h-screen p-6">
          <div class="space-y-3">
            <%= for section <- @sections do %>
              <a href={"#section-#{section.id}"}
                 class="block px-4 py-2 text-gray-300 hover:text-white hover:bg-slate-700 rounded-lg transition-colors">
                <%= section.title %>
              </a>
            <% end %>
          </div>
        </nav>

        <!-- Main Content -->
        <main class="flex-1 p-8 bg-slate-50">
          <%= render_executive_sections(assigns) %>
        </main>
      </div>
    </div>
    """
  end

  # DEVELOPER: Terminal-style Layout
  defp render_developer_layout(assigns) do
    ~H"""
    <div class={[@background_classes, @font_classes, "min-h-screen text-green-400"]}>
      <!-- Terminal Header -->
      <header class="border-b border-green-800 bg-gray-900">
        <div class="max-w-7xl mx-auto px-6 py-4">
          <div class="flex items-center space-x-4">
            <div class="flex space-x-2">
              <div class="w-3 h-3 bg-red-500 rounded-full"></div>
              <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
              <div class="w-3 h-3 bg-green-500 rounded-full"></div>
            </div>
            <span class="text-gray-400">~/portfolio/<%= String.downcase(String.replace(@portfolio.title, " ", "_")) %></span>
          </div>
        </div>
      </header>

      <!-- Terminal Navigation Tabs -->
      <nav class="bg-gray-800 border-b border-green-800">
        <div class="max-w-7xl mx-auto px-6">
          <div class="flex space-x-1">
            <%= for section <- @sections do %>
              <a href={"#section-#{section.id}"}
                 class="px-4 py-2 text-sm text-green-400 hover:bg-gray-700 border-r border-green-800 transition-colors">
                <%= section.title |> String.downcase() |> String.replace(" ", "_") %>.md
              </a>
            <% end %>
          </div>
        </div>
      </nav>

      <!-- Terminal Content -->
      <main class="max-w-7xl mx-auto px-6 py-8">
        <div class="mb-6">
          <div class="text-green-400 mb-2">
            <span class="text-blue-400">$</span> cat README.md
          </div>
          <div class="bg-gray-800 rounded-lg p-6 border border-green-800">
            <h1 class="text-2xl font-bold text-white mb-4"># <%= @portfolio.title %></h1>
            <p class="text-gray-300 mb-4"><%= @portfolio.description %></p>
            <div class="text-green-400">
              ```bash<br/>
              git clone https://github.com/developer/<%= String.downcase(String.replace(@portfolio.title, " ", "-")) %><br/>
              cd portfolio && npm install<br/>
              npm start<br/>
              ```
            </div>
          </div>
        </div>

        <%= render_developer_sections(assigns) %>
      </main>
    </div>
    """
  end

  # Continue lib/frestyl_web/controllers/portfolio_html.ex - Part 2

  # DESIGNER: Gallery/Masonry Layout
  defp render_designer_layout(assigns) do
    ~H"""
    <div class={[@background_classes, @font_classes, "min-h-screen text-white"]}>
      <!-- Creative Header with Floating Navigation -->
      <header class="relative h-screen flex items-center justify-center overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-br from-pink-400 via-purple-500 to-indigo-600"></div>
        <div class="absolute inset-0 bg-black bg-opacity-30"></div>

        <!-- Floating Navigation -->
        <nav class="fixed top-6 left-1/2 transform -translate-x-1/2 z-50 bg-white bg-opacity-10 backdrop-blur-md rounded-full px-6 py-3">
          <div class="flex space-x-6">
            <%= for section <- @sections do %>
              <a href={"#section-#{section.id}"}
                 class="text-white hover:text-pink-200 transition-colors text-sm font-medium">
                <%= section.title %>
              </a>
            <% end %>
          </div>
        </nav>

        <!-- Hero Content -->
        <div class="relative text-center z-10">
          <h1 class="text-6xl lg:text-8xl font-bold mb-6 bg-gradient-to-r from-pink-400 to-purple-600 bg-clip-text text-transparent">
            <%= @portfolio.title %>
          </h1>
          <p class="text-2xl lg:text-3xl text-white opacity-90 max-w-4xl mx-auto leading-relaxed">
            <%= @portfolio.description %>
          </p>

          <!-- Creative CTA -->
          <div class="mt-12">
            <button class="bg-white bg-opacity-20 backdrop-blur-md border border-white border-opacity-30 rounded-full px-8 py-4 text-white font-semibold hover:bg-opacity-30 transition-all">
              Explore My Work ↓
            </button>
          </div>
        </div>

        <!-- Animated Background Elements -->
        <div class="absolute inset-0 overflow-hidden">
          <div class="absolute -top-40 -right-40 w-80 h-80 bg-pink-500 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-blob"></div>
          <div class="absolute -bottom-40 -left-40 w-80 h-80 bg-purple-500 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-blob animation-delay-2000"></div>
          <div class="absolute top-40 left-40 w-80 h-80 bg-indigo-500 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-blob animation-delay-4000"></div>
        </div>
      </header>

      <!-- Masonry Grid Content -->
      <main class="px-6 py-16 bg-gradient-to-b from-transparent to-black">
        <div class="max-w-7xl mx-auto">
          <%= render_designer_masonry_sections(assigns) %>
        </div>
      </main>
    </div>
    """
  end

  # CONSULTANT: Case Study Layout
  defp render_consultant_layout(assigns) do
    ~H"""
    <div class={[@background_classes, @font_classes, "min-h-screen"]}>
      <!-- Professional Header -->
      <header class="bg-gradient-to-r from-blue-600 to-indigo-700 text-white">
        <div class="max-w-6xl mx-auto px-6 py-16">
          <div class="grid lg:grid-cols-2 gap-12 items-center">
            <div>
              <h1 class="text-4xl lg:text-5xl font-semibold mb-6"><%= @portfolio.title %></h1>
              <p class="text-xl text-blue-100 mb-8 leading-relaxed"><%= @portfolio.description %></p>

              <!-- Consultant Credentials -->
              <div class="grid grid-cols-2 gap-6">
                <div class="bg-white bg-opacity-10 rounded-lg p-4">
                  <div class="text-2xl font-bold text-cyan-300"><%= get_portfolio_metric(@portfolio, :clients, "200+") %></div>
                  <div class="text-blue-100">Clients Served</div>
                </div>
                <div class="bg-white bg-opacity-10 rounded-lg p-4">
                  <div class="text-2xl font-bold text-green-300"><%= get_portfolio_metric(@portfolio, :success_rate, "95%") %></div>
                  <div class="text-blue-100">Success Rate</div>
                </div>
              </div>
            </div>

            <div class="lg:justify-self-end">
              <div class="w-80 h-80 bg-white bg-opacity-10 rounded-2xl backdrop-blur-sm flex items-center justify-center">
                <div class="text-center">
                  <div class="text-6xl mb-4">📊</div>
                  <div class="text-xl font-semibold">Strategic Consulting</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </header>

      <!-- Breadcrumb Navigation -->
      <nav class="bg-white shadow-sm sticky top-0 z-40">
        <div class="max-w-6xl mx-auto px-6 py-4">
          <div class="flex space-x-8 overflow-x-auto">
            <%= for section <- @sections do %>
              <a href={"#section-#{section.id}"}
                 class="whitespace-nowrap text-gray-600 hover:text-blue-600 font-medium transition-colors">
                <%= section.title %>
              </a>
            <% end %>
          </div>
        </div>
      </nav>

      <!-- Case Study Content -->
      <main class="max-w-6xl mx-auto px-6 py-12">
        <%= render_consultant_sections(assigns) %>
      </main>
    </div>
    """
  end

  # PHOTOGRAPHER: Full-screen Layout
  defp render_photographer_layout(assigns) do
    ~H"""
    <div class={[@background_classes, @font_classes, "min-h-screen"]}>
      <!-- Overlay Header -->
      <header class="fixed inset-x-0 top-0 z-50 bg-gradient-to-b from-black to-transparent">
        <div class="max-w-7xl mx-auto px-6 py-8">
          <div class="flex items-center justify-between">
            <h1 class="text-3xl font-light text-white"><%= @portfolio.title %></h1>

            <!-- Dot Navigation -->
            <nav class="hidden lg:flex space-x-4">
              <%= for {section, index} <- Enum.with_index(@sections) do %>
                <a href={"#section-#{section.id}"}
                   class="w-3 h-3 rounded-full bg-white bg-opacity-30 hover:bg-opacity-100 transition-all"
                   title={section.title}>
                </a>
              <% end %>
            </nav>
          </div>
        </div>
      </header>

      <!-- Full-screen Slides -->
      <main class="snap-y snap-mandatory h-screen overflow-y-auto">
        <!-- Hero Slide -->
        <section class="snap-start h-screen flex items-center justify-center bg-black relative">
          <div class="absolute inset-0 bg-gradient-to-b from-transparent via-black/50 to-black"></div>
          <div class="relative text-center text-white z-10">
            <h2 class="text-5xl lg:text-7xl font-light mb-6"><%= @portfolio.title %></h2>
            <p class="text-2xl lg:text-3xl font-light opacity-80 max-w-4xl mx-auto">
              <%= @portfolio.description %>
            </p>
          </div>
        </section>

        <%= render_photographer_sections(assigns) %>
      </main>

      <!-- Mobile Navigation -->
      <nav class="lg:hidden fixed bottom-6 left-1/2 transform -translate-x-1/2 bg-black bg-opacity-50 backdrop-blur-md rounded-full px-6 py-3">
        <div class="flex space-x-4">
          <%= for section <- @sections do %>
            <a href={"#section-#{section.id}"}
               class="text-white text-sm">
              <%= String.slice(section.title, 0..2) %>
            </a>
          <% end %>
        </div>
      </nav>
    </div>
    """
  end

  # FREELANCER: Services Layout
  defp render_freelancer_layout(assigns) do
    ~H"""
    <div class={[@background_classes, @font_classes, "min-h-screen text-white"]}>
      <!-- Service Header -->
      <header class="bg-gradient-to-r from-emerald-400 to-teal-600">
        <div class="max-w-6xl mx-auto px-6 py-16">
          <div class="text-center">
            <h1 class="text-4xl lg:text-5xl font-semibold mb-6"><%= @portfolio.title %></h1>
            <p class="text-xl text-emerald-100 mb-8 max-w-3xl mx-auto"><%= @portfolio.description %></p>

            <!-- Service Highlights -->
            <div class="grid md:grid-cols-3 gap-6 mt-12">
              <div class="bg-white bg-opacity-10 rounded-xl p-6">
                <div class="text-3xl mb-4">⚡</div>
                <div class="font-semibold mb-2">Fast Delivery</div>
                <div class="text-emerald-100 text-sm">Projects completed on time</div>
              </div>
              <div class="bg-white bg-opacity-10 rounded-xl p-6">
                <div class="text-3xl mb-4">💎</div>
                <div class="font-semibold mb-2">Premium Quality</div>
                <div class="text-emerald-100 text-sm">Attention to every detail</div>
              </div>
              <div class="bg-white bg-opacity-10 rounded-xl p-6">
                <div class="text-3xl mb-4">🎯</div>
                <div class="font-semibold mb-2">Results Focused</div>
                <div class="text-emerald-100 text-sm">Measurable outcomes</div>
              </div>
            </div>
          </div>
        </div>
      </header>

      <!-- Sticky Navigation -->
      <nav class="sticky top-0 z-40 bg-teal-700 shadow-lg">
        <div class="max-w-6xl mx-auto px-6">
          <div class="flex space-x-8 overflow-x-auto py-4">
            <%= for section <- @sections do %>
              <a href={"#section-#{section.id}"}
                 class="whitespace-nowrap text-teal-100 hover:text-white font-medium transition-colors">
                <%= section.title %>
              </a>
            <% end %>
          </div>
        </div>
      </nav>

      <!-- Service Cards Content -->
      <main class="bg-gradient-to-b from-teal-600 to-emerald-600 px-6 py-12">
        <div class="max-w-6xl mx-auto">
          <%= render_freelancer_sections(assigns) %>
        </div>
      </main>
    </div>
    """
  end

  # Continue lib/frestyl_web/controllers/portfolio_html.ex - Part 3

  # ARTIST: Exhibition Layout
  defp render_artist_layout(assigns) do
    ~H"""
    <div class={[@background_classes, @font_classes, "min-h-screen text-white"]}>
      <!-- Artistic Header -->
      <header class="relative h-screen flex items-center justify-center overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-br from-purple-600 via-pink-600 to-red-600"></div>
        <div class="absolute inset-0 bg-black bg-opacity-40"></div>

        <!-- Artistic Navigation -->
        <nav class="fixed top-8 right-8 z-50">
          <div class="bg-black bg-opacity-30 backdrop-blur-md rounded-2xl p-6">
            <div class="space-y-4">
              <%= for section <- @sections do %>
                <a href={"#section-#{section.id}"}
                   class="block text-white hover:text-pink-200 transition-colors text-sm font-light text-right">
                  <%= section.title %>
                </a>
              <% end %>
            </div>
          </div>
        </nav>

        <!-- Hero Content -->
        <div class="relative text-center z-10 max-w-4xl mx-auto px-6">
          <div class="mb-8">
            <div class="w-32 h-32 mx-auto bg-white bg-opacity-20 rounded-full flex items-center justify-center backdrop-blur-sm mb-6">
              <span class="text-4xl">🎨</span>
            </div>
          </div>
          <h1 class="text-5xl lg:text-7xl font-normal mb-6 leading-tight">
            <%= @portfolio.title %>
          </h1>
          <p class="text-xl lg:text-2xl font-light opacity-90 leading-relaxed italic">
            "<%= @portfolio.description %>"
          </p>

          <!-- Artist Statement -->
          <div class="mt-12 text-center">
            <div class="inline-block bg-white bg-opacity-10 backdrop-blur-md rounded-lg px-8 py-4">
              <span class="text-sm uppercase tracking-wider font-light">Current Exhibition</span>
            </div>
          </div>
        </div>

        <!-- Decorative Elements -->
        <div class="absolute top-20 left-20 w-2 h-2 bg-white rounded-full opacity-60"></div>
        <div class="absolute bottom-40 right-32 w-3 h-3 bg-pink-300 rounded-full opacity-40"></div>
        <div class="absolute top-1/3 right-20 w-1 h-1 bg-purple-300 rounded-full opacity-80"></div>
      </header>

      <!-- Exhibition Grid -->
      <main class="bg-gradient-to-b from-purple-900 to-black px-6 py-16">
        <div class="max-w-7xl mx-auto">
          <%= render_artist_sections(assigns) %>
        </div>
      </main>
    </div>
    """
  end

  # MINIMALIST: Typography-focused Layout
  defp render_minimalist_layout(assigns) do
    ~H"""
    <div class={[@background_classes, @font_classes, "min-h-screen bg-white text-gray-900"]}>
      <!-- Minimal Header -->
      <header class="border-b border-gray-200">
        <div class="max-w-4xl mx-auto px-6 py-16">
          <div class="text-center">
            <h1 class="text-4xl lg:text-5xl font-normal text-gray-900 mb-6 leading-tight">
              <%= @portfolio.title %>
            </h1>
            <p class="text-xl text-gray-600 max-w-2xl mx-auto leading-relaxed">
              <%= @portfolio.description %>
            </p>
          </div>
        </div>
      </header>

      <!-- Minimal Navigation -->
      <nav class="sticky top-0 z-40 bg-white border-b border-gray-100">
        <div class="max-w-4xl mx-auto px-6">
          <div class="flex justify-center space-x-12 py-6">
            <%= for section <- @sections do %>
              <a href={"#section-#{section.id}"}
                 class="text-gray-600 hover:text-gray-900 transition-colors text-sm uppercase tracking-wider font-medium">
                <%= section.title %>
              </a>
            <% end %>
          </div>
        </div>
      </nav>

      <!-- Clean Content -->
      <main class="max-w-4xl mx-auto px-6 py-16">
        <%= render_minimalist_sections(assigns) %>
      </main>
    </div>
    """
  end

  # DEFAULT: Fallback Layout
  defp render_default_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <header class="bg-white shadow-sm">
        <div class="max-w-6xl mx-auto px-6 py-12">
          <h1 class="text-3xl font-bold text-gray-900 mb-4"><%= @portfolio.title %></h1>
          <p class="text-xl text-gray-600"><%= @portfolio.description %></p>
        </div>
      </header>

      <nav class="bg-white border-b">
        <div class="max-w-6xl mx-auto px-6 py-4">
          <div class="flex space-x-8">
            <%= for section <- @sections do %>
              <a href={"#section-#{section.id}"} class="text-gray-600 hover:text-gray-900">
                <%= section.title %>
              </a>
            <% end %>
          </div>
        </div>
      </nav>

      <main class="max-w-6xl mx-auto px-6 py-12">
        <%= for section <- @sections do %>
          <section id={"section-#{section.id}"} class="mb-12">
            <h2 class="text-2xl font-bold mb-4"><%= section.title %></h2>
            <%= render_section_content(section, assigns) %>
          </section>
        <% end %>
      </main>
    </div>
    """
  end

  # Continue lib/frestyl_web/controllers/portfolio_html.ex - Part 4

  # EXECUTIVE: Dashboard-style sections
  defp render_executive_sections(assigns) do
    ~H"""
    <div class="space-y-8">
      <%= for section <- @sections do %>
        <section id={"section-#{section.id}"} class="bg-white rounded-xl shadow-lg p-8">
          <div class="flex items-center justify-between mb-6">
            <h2 class="text-2xl font-bold text-gray-900"><%= section.title %></h2>
            <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <%= get_section_icon(section.section_type) %>
            </div>
          </div>

          <div class="grid lg:grid-cols-3 gap-6">
            <div class="lg:col-span-2">
              <%= render_section_content(section, assigns) %>
            </div>
            <div class="space-y-4">
              <%= render_executive_metrics(section) %>
            </div>
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  # DEVELOPER: Terminal-style sections
  defp render_developer_sections(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= for section <- @sections do %>
        <section id={"section-#{section.id}"} class="bg-gray-800 rounded-lg border border-green-800">
          <!-- Terminal Header -->
          <div class="border-b border-green-800 px-6 py-3 bg-gray-900 rounded-t-lg">
            <div class="flex items-center space-x-3">
              <span class="text-blue-400">$</span>
              <span class="text-green-400">cat</span>
              <span class="text-white"><%= section.title |> String.downcase() |> String.replace(" ", "_") %>.md</span>
            </div>
          </div>

          <!-- Terminal Content -->
          <div class="p-6">
            <div class="font-mono text-sm">
              <div class="text-gray-400 mb-2"># <%= section.title %></div>
              <div class="text-green-400">
                <%= render_section_content_as_code(section, assigns) %>
              </div>
            </div>
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  # DESIGNER: Masonry-style sections
  defp render_designer_masonry_sections(assigns) do
    ~H"""
    <div class="columns-1 md:columns-2 lg:columns-3 gap-8 space-y-8">
      <%= for section <- @sections do %>
        <section id={"section-#{section.id}"} class="break-inside-avoid bg-white bg-opacity-10 backdrop-blur-md rounded-2xl p-8 text-white">
          <h2 class="text-2xl font-bold mb-6 bg-gradient-to-r from-pink-400 to-purple-600 bg-clip-text text-transparent">
            <%= section.title %>
          </h2>

          <%= render_section_content(section, assigns) %>

          <!-- Visual Enhancement -->
          <div class="mt-6 h-1 bg-gradient-to-r from-pink-400 to-purple-600 rounded-full"></div>
        </section>
      <% end %>
    </div>
    """
  end

  # CONSULTANT: Story-driven sections
  defp render_consultant_sections(assigns) do
    ~H"""
    <div class="space-y-16">
      <%= for {section, index} <- Enum.with_index(@sections) do %>
        <section id={"section-#{section.id}"} class="relative">
          <!-- Timeline Connector -->
          <%= if index < length(@sections) - 1 do %>
            <div class="absolute left-8 top-16 w-0.5 h-full bg-gradient-to-b from-blue-500 to-transparent"></div>
          <% end %>

          <div class="flex items-start space-x-8">
            <!-- Timeline Dot -->
            <div class="w-16 h-16 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-xl flex-shrink-0">
              <%= index + 1 %>
            </div>

            <!-- Content -->
            <div class="flex-1 bg-white rounded-xl shadow-lg p-8">
              <h2 class="text-3xl font-semibold text-gray-900 mb-6"><%= section.title %></h2>
              <%= render_section_content(section, assigns) %>
            </div>
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  # Continue lib/frestyl_web/controllers/portfolio_html.ex - Part 5

  # PHOTOGRAPHER: Full-screen slide sections
  defp render_photographer_sections(assigns) do
    ~H"""
    <%= for section <- @sections do %>
      <section id={"section-#{section.id}"} class="snap-start h-screen flex items-center justify-center relative">
        <div class="absolute inset-0 bg-gradient-to-b from-transparent via-black/30 to-black/60"></div>

        <!-- Content overlay -->
        <div class="relative z-10 text-center text-white max-w-4xl mx-auto px-6">
          <h2 class="text-4xl lg:text-6xl font-light mb-8"><%= section.title %></h2>

          <div class="text-lg lg:text-xl font-light opacity-90 leading-relaxed">
            <%= render_section_content(section, assigns) %>
          </div>

          <!-- Photo grid for media sections -->
          <%= if has_section_media?(section) do %>
            <div class="grid grid-cols-2 lg:grid-cols-3 gap-4 mt-12 max-w-2xl mx-auto">
              <%= for media <- get_section_media_preview(section) do %>
                <div class="aspect-square bg-white bg-opacity-10 rounded-lg overflow-hidden">
                  <img src={get_media_url(media)} alt="" class="w-full h-full object-cover" />
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </section>
    <% end %>
    """
  end

  # FREELANCER: Service card sections
  defp render_freelancer_sections(assigns) do
    ~H"""
    <div class="grid md:grid-cols-2 gap-8">
      <%= for section <- @sections do %>
        <section id={"section-#{section.id}"} class="bg-white bg-opacity-10 backdrop-blur-md rounded-2xl p-8 text-white">
          <div class="flex items-center space-x-4 mb-6">
            <div class="w-12 h-12 bg-emerald-400 rounded-xl flex items-center justify-center text-white">
              <%= get_section_icon(section.section_type) %>
            </div>
            <h2 class="text-2xl font-semibold"><%= section.title %></h2>
          </div>

          <div class="space-y-4">
            <%= render_section_content(section, assigns) %>

            <!-- Service CTA -->
            <div class="pt-6 border-t border-white border-opacity-20">
              <button class="bg-white text-emerald-600 px-6 py-3 rounded-lg font-semibold hover:bg-opacity-90 transition-all">
                Learn More
              </button>
            </div>
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  # ARTIST: Exhibition grid sections
  defp render_artist_sections(assigns) do
    ~H"""
    <div class="space-y-20">
      <%= for section <- @sections do %>
        <section id={"section-#{section.id}"} class="relative">
          <!-- Artistic separator -->
          <div class="absolute -top-10 left-1/2 transform -translate-x-1/2 w-32 h-0.5 bg-gradient-to-r from-transparent via-pink-400 to-transparent"></div>

          <div class="text-center mb-12">
            <h2 class="text-4xl lg:text-5xl font-normal text-white mb-6">
              <%= section.title %>
            </h2>
            <div class="w-24 h-0.5 bg-pink-400 mx-auto"></div>
          </div>

          <!-- Exhibition-style content -->
          <div class="max-w-4xl mx-auto">
            <%= if has_section_media?(section) do %>
              <!-- Gallery view for media sections -->
              <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-8 mb-12">
                <%= for media <- get_section_media_preview(section) do %>
                  <div class="group relative">
                    <div class="aspect-square bg-white bg-opacity-5 rounded-lg overflow-hidden">
                      <img src={get_media_url(media)} alt=""
                           class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
                    </div>
                    <div class="absolute inset-0 bg-gradient-to-t from-black via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-lg flex items-end p-6">
                      <p class="text-white text-sm"><%= media.title || "Untitled" %></p>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>

            <!-- Text content with artistic styling -->
            <div class="bg-black bg-opacity-30 backdrop-blur-sm rounded-2xl p-8 text-white text-center">
              <div class="font-light text-lg leading-relaxed italic">
                <%= render_section_content(section, assigns) %>
              </div>
            </div>
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  # MINIMALIST: Clean text sections
  defp render_minimalist_sections(assigns) do
    ~H"""
    <div class="space-y-24">
      <%= for section <- @sections do %>
        <section id={"section-#{section.id}"} class="relative">
          <div class="max-w-2xl mx-auto">
            <h2 class="text-3xl font-normal text-gray-900 mb-8 text-center">
              <%= section.title %>
            </h2>

            <div class="prose prose-lg prose-gray max-w-none text-center">
              <%= render_section_content(section, assigns) %>
            </div>

            <!-- Minimal visual separator -->
            <div class="mt-12 flex justify-center">
              <div class="w-12 h-0.5 bg-gray-300"></div>
            </div>
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  # Continue lib/frestyl_web/controllers/portfolio_html.ex - Part 6

  # Helper function to get section icons
  defp get_section_icon(section_type) do
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
      _ -> "📋"
    end
  end

  # Enhanced section content renderer
  defp render_section_content(section, _assigns) do
    case section.section_type do
      :intro -> render_intro_content(section)
      :experience -> render_experience_content(section)
      :education -> render_education_content(section)
      :skills -> render_skills_content(section)
      :projects -> render_projects_content(section)
      :featured_project -> render_featured_project_content(section)
      :achievements -> render_achievements_content(section)
      :testimonial -> render_testimonial_content(section)
      :contact -> render_contact_content(section)
      _ -> render_generic_content(section)
    end
  end

  # Specific content renderers
  defp render_intro_content(section) do
    headline = get_in(section.content, ["headline"]) || ""
    summary = get_in(section.content, ["summary"]) || ""
    location = get_in(section.content, ["location"]) || ""

    assigns = %{headline: headline, summary: summary, location: location}

    ~H"""
    <div class="space-y-4">
      <%= if String.length(@headline) > 0 do %>
        <h3 class="text-xl font-semibold mb-3"><%= @headline %></h3>
      <% end %>
      <%= if String.length(@summary) > 0 do %>
        <p class="leading-relaxed"><%= @summary %></p>
      <% end %>
      <%= if String.length(@location) > 0 do %>
        <p class="text-sm opacity-75 flex items-center">
          📍 <%= @location %>
        </p>
      <% end %>
    </div>
    """
  end

  defp render_experience_content(section) do
    jobs = get_in(section.content, ["jobs"]) || []
    assigns = %{jobs: jobs}

    ~H"""
    <div class="space-y-6">
      <%= for job <- @jobs do %>
        <div class="border-l-4 border-blue-500 pl-6">
          <h4 class="font-semibold text-lg"><%= Map.get(job, "title", "") %></h4>
          <p class="text-blue-600 font-medium"><%= Map.get(job, "company", "") %></p>
          <p class="text-sm opacity-75 mb-2"><%= Map.get(job, "duration", "") %></p>
          <p class="leading-relaxed"><%= Map.get(job, "description", "") %></p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_skills_content(section) do
    skills = get_in(section.content, ["skills"]) || []
    assigns = %{skills: skills}

    ~H"""
    <div class="flex flex-wrap gap-3">
      <%= for skill <- @skills do %>
        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
          <%= case skill do %>
            <% %{"name" => name, "level" => level} -> %>
              <%= name %> <span class="ml-1 text-blue-600">(<%= level %>)</span>
            <% %{"name" => name} -> %>
              <%= name %>
            <% skill when is_binary(skill) -> %>
              <%= skill %>
            <% _ -> %>
              Skill
          <% end %>
        </span>
      <% end %>
    </div>
    """
  end

  defp render_contact_content(section) do
    email = get_in(section.content, ["email"]) || ""
    phone = get_in(section.content, ["phone"]) || ""
    location = get_in(section.content, ["location"]) || ""

    assigns = %{email: email, phone: phone, location: location}

    ~H"""
    <div class="space-y-4">
      <%= if String.length(@email) > 0 do %>
        <div class="flex items-center space-x-3">
          <span>📧</span>
          <a href={"mailto:#{@email}"} class="text-blue-600 hover:text-blue-800"><%= @email %></a>
        </div>
      <% end %>
      <%= if String.length(@phone) > 0 do %>
        <div class="flex items-center space-x-3">
          <span>📞</span>
          <a href={"tel:#{@phone}"} class="text-blue-600 hover:text-blue-800"><%= @phone %></a>
        </div>
      <% end %>
      <%= if String.length(@location) > 0 do %>
        <div class="flex items-center space-x-3">
          <span>📍</span>
          <span><%= @location %></span>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_education_content(section) do
    education = get_in(section.content, ["education"]) || []
    assigns = %{education: education}

    ~H"""
    <div class="space-y-6">
      <%= for edu <- @education do %>
        <div class="border-l-4 border-green-500 pl-6">
          <h4 class="font-semibold text-lg"><%= Map.get(edu, "degree", "") %></h4>
          <p class="text-green-600 font-medium"><%= Map.get(edu, "school", "") %></p>
          <p class="text-sm opacity-75 mb-2">
            <%= Map.get(edu, "start_year", "") %>
            <%= if Map.get(edu, "end_year"), do: "- #{Map.get(edu, "end_year")}", else: "" %>
          </p>
          <%= if Map.get(edu, "description") && String.length(Map.get(edu, "description")) > 0 do %>
            <p class="leading-relaxed"><%= Map.get(edu, "description", "") %></p>
          <% end %>
          <%= if Map.get(edu, "gpa") && String.length(Map.get(edu, "gpa")) > 0 do %>
            <p class="text-sm font-medium text-gray-600 mt-2">GPA: <%= Map.get(edu, "gpa") %></p>
          <% end %>
        </div>
      <% end %>

      <%= if length(@education) == 0 do %>
        <div class="text-center py-6 text-gray-500">
          <p class="italic">Education details coming soon...</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_projects_content(section) do
    projects = get_in(section.content, ["projects"]) || []
    assigns = %{projects: projects, section: section}

    ~H"""
    <div class="space-y-8">
      <%= if length(@projects) > 0 do %>
        <%= for project <- @projects do %>
          <div class="bg-gray-50 rounded-lg p-6 border border-gray-200">
            <div class="flex items-start justify-between mb-4">
              <div class="flex-1">
                <h4 class="font-bold text-xl text-gray-900 mb-2">
                  <%= Map.get(project, "name", Map.get(project, "title", "Untitled Project")) %>
                </h4>
                <%= if Map.get(project, "technologies") do %>
                  <div class="flex flex-wrap gap-2 mb-3">
                    <%= for tech <- Map.get(project, "technologies", []) do %>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        <%= tech %>
                      </span>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <%= if Map.get(project, "status") do %>
                <span class={[
                  "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                  case Map.get(project, "status") do
                    "completed" -> "bg-green-100 text-green-800"
                    "in-progress" -> "bg-yellow-100 text-yellow-800"
                    "planned" -> "bg-gray-100 text-gray-800"
                    _ -> "bg-blue-100 text-blue-800"
                  end
                ]}>
                  <%= String.capitalize(Map.get(project, "status", "")) %>
                </span>
              <% end %>
            </div>

            <%= if Map.get(project, "description") do %>
              <p class="text-gray-700 leading-relaxed mb-4">
                <%= Map.get(project, "description") %>
              </p>
            <% end %>

            <%= if Map.get(project, "highlights") do %>
              <div class="mb-4">
                <h5 class="font-semibold text-gray-900 mb-2">Key Highlights:</h5>
                <ul class="list-disc list-inside space-y-1 text-gray-700">
                  <%= for highlight <- Map.get(project, "highlights", []) do %>
                    <li><%= highlight %></li>
                  <% end %>
                </ul>
              </div>
            <% end %>

            <!-- Project Links -->
            <div class="flex flex-wrap gap-3 mt-4">
              <%= if Map.get(project, "demo_url") && String.length(Map.get(project, "demo_url")) > 0 do %>
                <a href={Map.get(project, "demo_url")}
                  target="_blank"
                  class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 transition-colors">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                  </svg>
                  Live Demo
                </a>
              <% end %>

              <%= if Map.get(project, "github_url") && String.length(Map.get(project, "github_url")) > 0 do %>
                <a href={Map.get(project, "github_url")}
                  target="_blank"
                  class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 transition-colors">
                  <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z" clip-rule="evenodd"/>
                  </svg>
                  Source Code
                </a>
              <% end %>

              <%= if Map.get(project, "case_study_url") && String.length(Map.get(project, "case_study_url")) > 0 do %>
                <a href={Map.get(project, "case_study_url")}
                  target="_blank"
                  class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 transition-colors">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  Case Study
                </a>
              <% end %>
            </div>
          </div>
        <% end %>
      <% else %>
        <!-- Fallback to text content if no structured projects -->
        <%= case @section.content do %>
          <% %{"description" => desc} when is_binary(desc) and byte_size(desc) > 0 -> %>
            <div class="prose max-w-none">
              <p class="leading-relaxed text-gray-700"><%= desc %></p>
            </div>
          <% %{"summary" => summary} when is_binary(summary) and byte_size(summary) > 0 -> %>
            <div class="prose max-w-none">
              <p class="leading-relaxed text-gray-700"><%= summary %></p>
            </div>
          <% %{"content" => content} when is_binary(content) and byte_size(content) > 0 -> %>
            <div class="prose max-w-none">
              <p class="leading-relaxed text-gray-700"><%= content %></p>
            </div>
          <% _ -> %>
            <div class="text-center py-8 text-gray-500">
              <svg class="mx-auto h-12 w-12 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
              </svg>
              <p class="mt-2 text-lg font-medium">Projects section coming soon</p>
              <p class="text-sm">Add some amazing projects to showcase your work</p>
            </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_featured_project_content(section) do
    title = get_in(section.content, ["title"]) || ""
    description = get_in(section.content, ["description"]) || ""
    challenge = get_in(section.content, ["challenge"]) || ""
    solution = get_in(section.content, ["solution"]) || ""
    technologies = get_in(section.content, ["technologies"]) || []
    demo_url = get_in(section.content, ["demo_url"]) || ""
    github_url = get_in(section.content, ["github_url"]) || ""

    assigns = %{
      title: title, description: description, challenge: challenge,
      solution: solution, technologies: technologies,
      demo_url: demo_url, github_url: github_url
    }

    ~H"""
    <div class="space-y-6">
      <%= if String.length(@title) > 0 do %>
        <div>
          <h3 class="text-2xl font-bold text-gray-900 mb-3"><%= @title %></h3>
          <%= if length(@technologies) > 0 do %>
            <div class="flex flex-wrap gap-2 mb-4">
              <%= for tech <- @technologies do %>
                <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
                  <%= tech %>
                </span>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if String.length(@description) > 0 do %>
        <div>
          <h4 class="font-semibold text-gray-900 mb-2">Project Overview</h4>
          <p class="text-gray-700 leading-relaxed"><%= @description %></p>
        </div>
      <% end %>

      <%= if String.length(@challenge) > 0 do %>
        <div>
          <h4 class="font-semibold text-gray-900 mb-2">Challenge</h4>
          <p class="text-gray-700 leading-relaxed"><%= @challenge %></p>
        </div>
      <% end %>

      <%= if String.length(@solution) > 0 do %>
        <div>
          <h4 class="font-semibold text-gray-900 mb-2">Solution</h4>
          <p class="text-gray-700 leading-relaxed"><%= @solution %></p>
        </div>
      <% end %>

      <!-- Project Links -->
      <%= if String.length(@demo_url) > 0 or String.length(@github_url) > 0 do %>
        <div class="flex flex-wrap gap-3 pt-4 border-t border-gray-200">
          <%= if String.length(@demo_url) > 0 do %>
            <a href={@demo_url} target="_blank"
              class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
              </svg>
              View Project
            </a>
          <% end %>

          <%= if String.length(@github_url) > 0 do %>
            <a href={@github_url} target="_blank"
              class="inline-flex items-center px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
              <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z" clip-rule="evenodd"/>
              </svg>
              Source Code
            </a>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_achievements_content(section) do
    achievements = get_in(section.content, ["achievements"]) || []
    assigns = %{achievements: achievements}

    ~H"""
    <div class="space-y-4">
      <%= if length(@achievements) > 0 do %>
        <%= for achievement <- @achievements do %>
          <div class="flex items-start space-x-4 p-4 bg-yellow-50 rounded-lg border border-yellow-200">
            <div class="flex-shrink-0">
              <div class="w-10 h-10 bg-yellow-500 rounded-full flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
                </svg>
              </div>
            </div>
            <div class="flex-1">
              <h4 class="font-semibold text-gray-900">
                <%= Map.get(achievement, "title", Map.get(achievement, "name", "Achievement")) %>
              </h4>
              <%= if Map.get(achievement, "organization") do %>
                <p class="text-yellow-700 font-medium"><%= Map.get(achievement, "organization") %></p>
              <% end %>
              <%= if Map.get(achievement, "date") do %>
                <p class="text-sm text-gray-600 mb-2"><%= Map.get(achievement, "date") %></p>
              <% end %>
              <%= if Map.get(achievement, "description") do %>
                <p class="text-gray-700"><%= Map.get(achievement, "description") %></p>
              <% end %>
            </div>
          </div>
        <% end %>
      <% else %>
        <div class="text-center py-6 text-gray-500">
          <p class="italic">Achievements and awards coming soon...</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_testimonial_content(section) do
    testimonials = get_in(section.content, ["testimonials"]) || []
    assigns = %{testimonials: testimonials}

    ~H"""
    <div class="space-y-6">
      <%= if length(@testimonials) > 0 do %>
        <%= for testimonial <- @testimonials do %>
          <div class="bg-gray-50 rounded-lg p-6 border-l-4 border-blue-500">
            <blockquote class="text-gray-700 italic text-lg leading-relaxed mb-4">
              "<%= Map.get(testimonial, "content", Map.get(testimonial, "quote", "")) %>"
            </blockquote>
            <div class="flex items-center space-x-4">
              <%= if Map.get(testimonial, "avatar_url") do %>
                <img src={Map.get(testimonial, "avatar_url")}
                    alt={Map.get(testimonial, "name", "Person")}
                    class="w-12 h-12 rounded-full object-cover" />
              <% else %>
                <div class="w-12 h-12 bg-blue-500 rounded-full flex items-center justify-center">
                  <span class="text-white font-bold text-lg">
                    <%= String.first(Map.get(testimonial, "name", "?")) %>
                  </span>
                </div>
              <% end %>
              <div>
                <p class="font-semibold text-gray-900"><%= Map.get(testimonial, "name", "Anonymous") %></p>
                <%= if Map.get(testimonial, "title") && Map.get(testimonial, "company") do %>
                  <p class="text-sm text-gray-600">
                    <%= Map.get(testimonial, "title") %> at <%= Map.get(testimonial, "company") %>
                  </p>
                <% else %>
                  <%= if Map.get(testimonial, "title") do %>
                    <p class="text-sm text-gray-600"><%= Map.get(testimonial, "title") %></p>
                  <% end %>
                  <%= if Map.get(testimonial, "company") do %>
                    <p class="text-sm text-gray-600"><%= Map.get(testimonial, "company") %></p>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      <% else %>
        <div class="text-center py-6 text-gray-500">
          <p class="italic">Client testimonials coming soon...</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_generic_content(section) do
    content = case section.content do
      %{"summary" => summary} when is_binary(summary) -> summary
      %{"description" => desc} when is_binary(desc) -> desc
      %{"content" => content} when is_binary(content) -> content
      _ -> "Content coming soon..."
    end

    assigns = %{content: content}

    ~H"""
    <div class="prose max-w-none">
      <%= if String.length(@content) > 0 do %>
        <p class="leading-relaxed"><%= @content %></p>
      <% else %>
        <p class="italic opacity-60">This section is being developed.</p>
      <% end %>
    </div>
    """
  end

  # Terminal-style content renderer
  defp render_section_content_as_code(section, _assigns) do
    content = case section.content do
      %{"summary" => summary} -> summary
      %{"description" => desc} -> desc
      %{"content" => content} -> content
      _ -> "// Section content coming soon..."
    end

    # Format as code comments
    content
    |> String.split("\n")
    |> Enum.map(&"// #{&1}")
    |> Enum.join("\n")
  end

  # Executive metrics renderer
  defp render_executive_metrics(section) do
    assigns = %{section: section}

    ~H"""
    <div class="space-y-4">
      <div class="bg-blue-50 rounded-lg p-4">
        <div class="text-2xl font-bold text-blue-600">85%</div>
        <div class="text-sm text-gray-600">Completion Rate</div>
      </div>
      <div class="bg-green-50 rounded-lg p-4">
        <div class="text-2xl font-bold text-green-600">+120%</div>
        <div class="text-sm text-gray-600">Growth Impact</div>
      </div>
      <div class="bg-purple-50 rounded-lg p-4">
        <div class="text-2xl font-bold text-purple-600">24/7</div>
        <div class="text-sm text-gray-600">Availability</div>
      </div>
    </div>
    """
  end

  # Portfolio metrics helper
  defp get_portfolio_metric(portfolio, metric, default) do
    # This would integrate with your analytics system
    case Map.get(portfolio, :metrics, %{}) do
      %{^metric => value} -> value
      _ -> default
    end
  end

  # Media helpers (placeholder implementations)
  defp has_section_media?(_section), do: false
  defp get_section_media_preview(_section), do: []
  defp get_media_url(_media), do: "/images/placeholder.jpg"


end
