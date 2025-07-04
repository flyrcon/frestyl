# ============================================================================
# PHASE 2: CREATE PORTFOLIO MODAL FIXES
# Enable all creation options and fix template system
# ============================================================================

# ============================================================================
# FIX 1: Enhanced Create Portfolio Modal Component
# lib/frestyl_web/live/portfolio_live/components/create_portfolio_modal.ex
# ============================================================================

defmodule FrestylWeb.PortfolioLive.Components.CreatePortfolioModal do
  use FrestylWeb, :live_component

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:selected_template, "executive")
      |> assign(:portfolio_title, "")
      |> assign(:creation_method, "template")
      |> assign(:show_advanced_options, false)
      |> assign(:ai_suggestions, [])
      |> assign(:uploading_resume, false)
      |> assign(:processing_ai, false)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Load available templates based on user subscription
    available_templates = get_available_templates(assigns.current_user)

    socket =
      socket
      |> assign(assigns)
      |> assign(:available_templates, available_templates)
      |> assign(:template_previews, generate_template_previews(available_templates))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-6xl max-h-[95vh] overflow-hidden mx-4">

        <!-- Modal Header -->
        <div class="bg-gradient-to-r from-blue-600 to-indigo-600 px-8 py-6">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-2xl font-bold text-white">Create New Portfolio</h2>
              <p class="text-blue-100 mt-1">Choose your method and get started in seconds</p>
            </div>
            <button phx-click="close_modal" phx-target={@myself}
                    class="text-white hover:text-gray-200 transition-colors">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Modal Body -->
        <div class="p-8 overflow-y-auto max-h-[calc(95vh-140px)]">

          <!-- Creation Method Selection -->
          <div class="mb-8">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">How would you like to create your portfolio?</h3>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <!-- Template Method -->
              <button phx-click="select_method" phx-value-method="template" phx-target={@myself}
                      class={[
                        "creation-method-card p-6 border-2 rounded-xl transition-all",
                        if(@creation_method == "template", do: "border-blue-500 bg-blue-50", else: "border-gray-200 hover:border-gray-300")
                      ]}>
                <div class="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center mx-auto mb-3">
                  <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"/>
                  </svg>
                </div>
                <h4 class="font-medium text-gray-900 mb-1">From Template</h4>
                <p class="text-sm text-gray-600">Professional designs ready to customize</p>
              </button>

              <!-- Resume Upload Method -->
              <button phx-click="select_method" phx-value-method="resume" phx-target={@myself}
                      class={[
                        "creation-method-card p-6 border-2 rounded-xl transition-all",
                        if(@creation_method == "resume", do: "border-green-500 bg-green-50", else: "border-gray-200 hover:border-gray-300")
                      ]}>
                <div class="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center mx-auto mb-3">
                  <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                </div>
                <h4 class="font-medium text-gray-900 mb-1">From Resume</h4>
                <p class="text-sm text-gray-600">Upload and auto-populate with AI</p>
              </button>

              <!-- AI Assistant Method -->
              <button phx-click="select_method" phx-value-method="ai" phx-target={@myself}
                      class={[
                        "creation-method-card p-6 border-2 rounded-xl transition-all",
                        if(@creation_method == "ai", do: "border-purple-500 bg-purple-50", else: "border-gray-200 hover:border-gray-300")
                      ]}>
                <div class="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center mx-auto mb-3">
                  <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
                  </svg>
                </div>
                <h4 class="font-medium text-gray-900 mb-1">AI Assistant</h4>
                <p class="text-sm text-gray-600">Let AI guide you step-by-step</p>
              </button>

              <!-- Blank Start Method -->
              <button phx-click="select_method" phx-value-method="blank" phx-target={@myself}
                      class={[
                        "creation-method-card p-6 border-2 rounded-xl transition-all",
                        if(@creation_method == "blank", do: "border-orange-500 bg-orange-50", else: "border-gray-200 hover:border-gray-300")
                      ]}>
                <div class="w-12 h-12 bg-orange-100 rounded-xl flex items-center justify-center mx-auto mb-3">
                  <svg class="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                  </svg>
                </div>
                <h4 class="font-medium text-gray-900 mb-1">Start Blank</h4>
                <p class="text-sm text-gray-600">Complete creative freedom</p>
              </button>
            </div>
          </div>

          <!-- Portfolio Title Input -->
          <div class="mb-8">
            <label class="block text-sm font-semibold text-gray-900 mb-3">Portfolio Title</label>
            <input type="text"
                   phx-change="update_title"
                   phx-target={@myself}
                   value={@portfolio_title}
                   placeholder="e.g. John Doe - Senior Developer"
                   class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-lg" />
            <p class="text-sm text-gray-600 mt-2">This will be the main title displayed on your portfolio</p>
          </div>

          <!-- Method-Specific Content -->
          <%= case @creation_method do %>
            <% "template" -> %>
              <%= render_template_selection(assigns) %>
            <% "resume" -> %>
              <%= render_resume_upload(assigns) %>
            <% "ai" -> %>
              <%= render_ai_assistant(assigns) %>
            <% "blank" -> %>
              <%= render_blank_options(assigns) %>
          <% end %>

          <!-- Advanced Options Toggle -->
          <div class="mt-8 border-t pt-6">
            <button phx-click="toggle_advanced" phx-target={@myself}
                    class="flex items-center text-sm text-gray-600 hover:text-gray-800">
              <svg class={[
                "w-4 h-4 mr-2 transition-transform",
                if(@show_advanced_options, do: "transform rotate-90", else: "")
              ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
              </svg>
              Advanced Options
            </button>

            <%= if @show_advanced_options do %>
              <div class="mt-4 p-4 bg-gray-50 rounded-lg">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Visibility</label>
                    <select class="w-full border border-gray-300 rounded-lg px-3 py-2">
                      <option value="private">Private (Only you)</option>
                      <option value="link_only">Link only</option>
                      <option value="public">Public</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Language</label>
                    <select class="w-full border border-gray-300 rounded-lg px-3 py-2">
                      <option value="en">English</option>
                      <option value="es">Spanish</option>
                      <option value="fr">French</option>
                    </select>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Modal Footer -->
        <div class="bg-gray-50 px-8 py-6 flex items-center justify-between">
          <button phx-click="close_modal" phx-target={@myself}
                  class="px-6 py-2 text-gray-600 hover:text-gray-800 transition-colors">
            Cancel
          </button>

          <button phx-click="create_portfolio" phx-target={@myself}
                  disabled={@portfolio_title == "" || @processing_ai || @uploading_resume}
                  class="px-8 py-3 bg-blue-600 text-white rounded-xl font-semibold hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors">
            <%= if @processing_ai || @uploading_resume do %>
              <svg class="animate-spin h-4 w-4 mr-2 inline-block" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Processing...
            <% else %>
              Create Portfolio
            <% end %>
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # RENDER METHODS FOR EACH CREATION TYPE
  # ============================================================================

  defp render_template_selection(assigns) do
    ~H"""
    <div class="mb-8">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Choose Your Template</h3>

      <!-- Template Categories -->
      <div class="flex space-x-2 mb-6 overflow-x-auto">
        <%= for category <- ["all", "business", "creative", "technical", "academic"] do %>
          <button class="px-4 py-2 text-sm font-medium rounded-lg whitespace-nowrap bg-gray-100 text-gray-700 hover:bg-gray-200">
            <%= String.capitalize(category) %>
          </button>
        <% end %>
      </div>

      <!-- Template Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 max-h-96 overflow-y-auto">
        <%= for {template_key, template_config} <- @available_templates do %>
          <div class="template-card cursor-pointer"
               phx-click="select_template"
               phx-value-template={template_key}
               phx-target={@myself}>
            <div class={[
              "border-2 rounded-xl overflow-hidden transition-all",
              if(@selected_template == template_key, do: "border-blue-500 bg-blue-50", else: "border-gray-200 hover:border-gray-300")
            ]}>
              <!-- Template Preview -->
              <div class={[
                "h-32 flex items-center justify-center text-3xl",
                template_config.preview_bg || "bg-gradient-to-br from-gray-100 to-gray-200"
              ]}>
                <%= template_config.icon || "📄" %>
              </div>

              <!-- Template Info -->
              <div class="p-4">
                <h4 class="font-semibold text-gray-900 mb-1"><%= template_config.name %></h4>
                <p class="text-sm text-gray-600 mb-3"><%= template_config.description %></p>

                <!-- Template Features -->
                <div class="flex flex-wrap gap-1">
                  <%= for feature <- Map.get(template_config, :features, []) do %>
                    <span class="text-xs bg-gray-100 text-gray-600 px-2 py-1 rounded-full">
                      <%= feature %>
                    </span>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_resume_upload(assigns) do
    ~H"""
    <div class="mb-8">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Upload Your Resume</h3>

      <div class="border-2 border-dashed border-gray-300 rounded-xl p-8 text-center hover:border-green-400 transition-colors">
        <%= if @uploading_resume do %>
          <div class="animate-pulse">
            <div class="w-16 h-16 bg-green-100 rounded-xl flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-green-600 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
              </svg>
            </div>
            <p class="text-lg font-medium text-gray-900">Processing your resume...</p>
            <p class="text-gray-600">AI is extracting your experience and skills</p>
          </div>
        <% else %>
          <div class="w-16 h-16 bg-green-100 rounded-xl flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10"/>
            </svg>
          </div>
          <p class="text-lg font-medium text-gray-900 mb-2">Drop your resume here</p>
          <p class="text-gray-600 mb-4">Support for PDF, DOC, DOCX files</p>
          <button phx-click="upload_resume" phx-target={@myself}
                  class="bg-green-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-green-700 transition-colors">
            Choose File
          </button>
        <% end %>
      </div>

      <div class="mt-4 p-4 bg-blue-50 rounded-lg">
        <div class="flex items-start">
          <svg class="w-5 h-5 text-blue-600 mt-0.5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <div>
            <p class="text-sm font-medium text-blue-900">AI Processing</p>
            <p class="text-sm text-blue-700">We'll automatically extract your experience, skills, education, and achievements to populate your portfolio sections.</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_ai_assistant(assigns) do
    ~H"""
    <div class="mb-8">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">AI Portfolio Assistant</h3>

      <%= if @processing_ai do %>
        <div class="text-center py-8">
          <div class="w-16 h-16 bg-purple-100 rounded-xl flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-purple-600 animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
            </svg>
          </div>
          <p class="text-lg font-medium text-gray-900">AI is analyzing your preferences...</p>
          <p class="text-gray-600">Creating personalized suggestions</p>
        </div>
      <% else %>
        <div class="space-y-6">
          <!-- Quick Questions -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">What's your profession?</label>
            <input type="text"
                   placeholder="e.g. Software Developer, Marketing Manager, Designer"
                   class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">What's your main goal?</label>
            <div class="grid grid-cols-2 gap-3">
              <%= for goal <- ["Find a job", "Freelance work", "Showcase projects", "Personal branding"] do %>
                <button class="p-3 border border-gray-200 rounded-lg text-left hover:border-purple-300 hover:bg-purple-50">
                  <div class="font-medium text-gray-900"><%= goal %></div>
                </button>
              <% end %>
            </div>
          </div>

          <button phx-click="analyze_with_ai" phx-target={@myself}
                  class="w-full bg-purple-600 text-white py-3 rounded-lg font-medium hover:bg-purple-700 transition-colors">
            ✨ Generate AI Suggestions
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_blank_options(assigns) do
    ~H"""
    <div class="mb-8">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Blank Portfolio Options</h3>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Minimal Setup -->
        <div class="p-6 border border-gray-200 rounded-xl hover:border-orange-300 hover:bg-orange-50 transition-colors">
          <div class="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center mb-4">
            <svg class="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
          </div>
          <h4 class="font-semibold text-gray-900 mb-2">Quick Start</h4>
          <p class="text-sm text-gray-600 mb-4">Start with basic sections and build as you go</p>
          <ul class="text-sm text-gray-600 space-y-1">
            <li>• Professional Summary</li>
            <li>• Contact Information</li>
            <li>• Basic styling</li>
          </ul>
        </div>

        <!-- Full Setup -->
        <div class="p-6 border border-gray-200 rounded-xl hover:border-orange-300 hover:bg-orange-50 transition-colors">
          <div class="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center mb-4">
            <svg class="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
            </svg>
          </div>
          <h4 class="font-semibold text-gray-900 mb-2">Complete Setup</h4>
          <p class="text-sm text-gray-600 mb-4">Start with all common sections pre-created</p>
          <ul class="text-sm text-gray-600 space-y-1">
            <li>• All portfolio sections</li>
            <li>• Advanced customization</li>
            <li>• Multiple layouts</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("close_modal", _params, socket) do
    send(self(), :close_create_modal)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_method", %{"method" => method}, socket) do
    {:noreply, assign(socket, :creation_method, method)}
  end

  @impl true
  def handle_event("update_title", %{"value" => title}, socket) do
    {:noreply, assign(socket, :portfolio_title, title)}
  end

  @impl true
  def handle_event("select_template", %{"template" => template}, socket) do
    {:noreply, assign(socket, :selected_template, template)}
  end

  @impl true
  def handle_event("toggle_advanced", _params, socket) do
    {:noreply, assign(socket, :show_advanced_options, !socket.assigns.show_advanced_options)}
  end

  @impl true
  def handle_event("upload_resume", _params, socket) do
    socket = assign(socket, :uploading_resume, true)

    # Simulate resume processing
    Process.send_after(self(), {:resume_processed, generate_mock_resume_data()}, 2000)

    {:noreply, socket}
  end

  @impl true
  def handle_event("analyze_with_ai", _params, socket) do
    socket = assign(socket, :processing_ai, true)

    # Simulate AI analysis
    Process.send_after(self(), {:ai_analysis_complete, generate_ai_suggestions()}, 3000)

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_portfolio", _params, socket) do
    case socket.assigns.creation_method do
      "template" -> create_from_template(socket)
      "resume" -> create_from_resume(socket)
      "ai" -> create_with_ai(socket)
      "blank" -> create_blank_portfolio(socket)
    end
  end

  # ============================================================================
  # PORTFOLIO CREATION METHODS
  # ============================================================================

  defp create_from_template(socket) do
    portfolio_attrs = %{
      title: socket.assigns.portfolio_title,
      theme: socket.assigns.selected_template,
      user_id: socket.assigns.current_user.id,
      status: "draft",
      visibility: :private
    }

    case Portfolios.create_portfolio_from_template(portfolio_attrs, socket.assigns.selected_template) do
      {:ok, portfolio} ->
        send(self(), {:portfolio_created, portfolio, "Template portfolio created successfully!"})
        {:noreply, socket}

      {:error, changeset} ->
        send(self(), {:portfolio_creation_failed, extract_errors(changeset)})
        {:noreply, socket}
    end
  end

  defp create_from_resume(socket) do
    # Implementation for resume-based creation
    portfolio_attrs = %{
      title: socket.assigns.portfolio_title,
      theme: "professional",
      user_id: socket.assigns.current_user.id,
      status: "draft",
      visibility: :private
    }

    case Portfolios.create_portfolio_from_resume(portfolio_attrs, socket.assigns.resume_data) do
      {:ok, portfolio} ->
        send(self(), {:portfolio_created, portfolio, "Portfolio created from resume!"})
        {:noreply, socket}

      {:error, reason} ->
        send(self(), {:portfolio_creation_failed, reason})
        {:noreply, socket}
    end
  end

  defp create_with_ai(socket) do
    # Implementation for AI-assisted creation
    portfolio_attrs = %{
      title: socket.assigns.portfolio_title,
      theme: determine_ai_recommended_theme(socket.assigns.ai_suggestions),
      user_id: socket.assigns.current_user.id,
      status: "draft",
      visibility: :private
    }

    case Portfolios.create_portfolio_with_ai(portfolio_attrs, socket.assigns.ai_suggestions) do
      {:ok, portfolio} ->
        send(self(), {:portfolio_created, portfolio, "AI-powered portfolio created!"})
        {:noreply, socket}

      {:error, reason} ->
        send(self(), {:portfolio_creation_failed, reason})
        {:noreply, socket}
    end
  end

  defp create_blank_portfolio(socket) do
    portfolio_attrs = %{
      title: socket.assigns.portfolio_title,
      theme: "minimal",
      user_id: socket.assigns.current_user.id,
      status: "draft",
      visibility: :private
    }

    case Portfolios.create_blank_portfolio(portfolio_attrs) do
      {:ok, portfolio} ->
        send(self(), {:portfolio_created, portfolio, "Blank portfolio created!"})
        {:noreply, socket}

      {:error, changeset} ->
        send(self(), {:portfolio_creation_failed, extract_errors(changeset)})
        {:noreply, socket}
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_available_templates(user) do
    subscription_tier = get_user_subscription_tier(user)

    base_templates = %{
      "minimal" => %{
        name: "Minimal",
        description: "Clean and simple design",
        icon: "📄",
        preview_bg: "bg-gradient-to-br from-gray-100 to-gray-200",
        features: ["Clean Layout", "Typography Focus", "Fast Loading"],
        category: "business"
      },
      "executive" => %{
        name: "Executive",
        description: "Professional business template",
        icon: "💼",
        preview_bg: "bg-gradient-to-br from-blue-100 to-blue-200",
        features: ["Professional", "Corporate", "ATS Friendly"],
        category: "business"
      },
      "creative" => %{
        name: "Creative",
        description: "Bold and expressive design",
        icon: "🎨",
        preview_bg: "bg-gradient-to-br from-purple-100 to-pink-200",
        features: ["Visual Focus", "Gallery Layout", "Creative"],
        category: "creative"
      },
      "developer" => %{
        name: "Developer",
        description: "Technical portfolio with code focus",
        icon: "💻",
        preview_bg: "bg-gradient-to-br from-green-100 to-emerald-200",
        features: ["Code Showcase", "Terminal Style", "Dark Theme"],
        category: "technical"
      }
    }

    premium_templates = %{
      "consultant" => %{
        name: "Consultant",
        description: "Business-focused case studies",
        icon: "📊",
        preview_bg: "bg-gradient-to-br from-indigo-100 to-blue-200",
        features: ["Case Studies", "Metrics", "Client Focus"],
        category: "business"
      },
      "academic" => %{
        name: "Academic",
        description: "Research and publication focused",
        icon: "🎓",
        preview_bg: "bg-gradient-to-br from-green-100 to-teal-200",
        features: ["Publications", "Research", "Citations"],
        category: "academic"
      },
      "designer" => %{
        name: "Designer",
        description: "Visual portfolio showcase",
        icon: "✨",
        preview_bg: "bg-gradient-to-br from-pink-100 to-rose-200",
        features: ["Portfolio Grid", "Visual", "Interactive"],
        category: "creative"
      }
    }

    case subscription_tier do
      tier when tier in ["premium", "professional"] ->
        Map.merge(base_templates, premium_templates)
      _ ->
        base_templates
    end
  end

  defp generate_template_previews(templates) do
    Enum.map(templates, fn {key, config} ->
      {key, %{
        preview_html: generate_template_preview_html(config),
        preview_css: generate_template_preview_css(config)
      }}
    end)
    |> Enum.into(%{})
  end

  defp generate_template_preview_html(config) do
    """
    <div class="template-preview">
      <div class="preview-header">#{config.name}</div>
      <div class="preview-content">
        <div class="preview-section"></div>
        <div class="preview-section"></div>
      </div>
    </div>
    """
  end

  defp generate_template_preview_css(config) do
    primary_color = case config.category do
      "business" -> "#1f2937"
      "creative" -> "#7c3aed"
      "technical" -> "#059669"
      "academic" -> "#0891b2"
      _ -> "#6b7280"
    end

    """
    .template-preview {
      background: #{primary_color};
      border-radius: 8px;
      padding: 1rem;
      color: white;
    }
    """
  end

  defp generate_mock_resume_data do
    %{
      personal_info: %{
        name: "John Doe",
        email: "john@example.com",
        phone: "+1234567890"
      },
      experience: [
        %{
          title: "Senior Developer",
          company: "Tech Corp",
          duration: "2020-Present",
          description: "Led development of web applications"
        }
      ],
      skills: ["JavaScript", "Python", "React", "Node.js"]
    }
  end

  defp generate_ai_suggestions do
    [
      "Based on your profession, we recommend the Developer template",
      "Consider adding a projects section to showcase your work",
      "Include metrics and achievements in your experience"
    ]
  end

  defp determine_ai_recommended_theme(suggestions) do
    # Simple logic to determine theme from AI suggestions
    cond do
      Enum.any?(suggestions, &String.contains?(&1, "Developer")) -> "developer"
      Enum.any?(suggestions, &String.contains?(&1, "Creative")) -> "creative"
      Enum.any?(suggestions, &String.contains?(&1, "Business")) -> "executive"
      true -> "minimal"
    end
  end

  defp get_user_subscription_tier(user) do
    case user do
      %{subscription_tier: tier} when is_binary(tier) -> tier
      %{subscription_tier: tier} when is_atom(tier) -> Atom.to_string(tier)
      _ -> "personal"
    end
  end

  defp extract_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end)
    |> Enum.join(", ")
  end
end

# ============================================================================
# FIX 2: Enhanced Portfolio Creation Functions
# Add these to lib/frestyl/portfolios.ex
# ============================================================================

defmodule Frestyl.Portfolios.CreationHelpers do
  @moduledoc """
  Helper functions for enhanced portfolio creation methods
  """

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.{Portfolio, PortfolioSection}
  alias Frestyl.Repo

  def create_portfolio_from_template(attrs, template_key) do
    with {:ok, portfolio} <- create_base_portfolio(attrs),
         {:ok, _sections} <- create_template_sections(portfolio, template_key),
         {:ok, portfolio} <- apply_template_customization(portfolio, template_key) do
      {:ok, portfolio}
    end
  end

  def create_portfolio_from_resume(attrs, resume_data) do
    with {:ok, portfolio} <- create_base_portfolio(attrs),
         {:ok, _sections} <- create_resume_sections(portfolio, resume_data) do
      {:ok, portfolio}
    end
  end

  def create_portfolio_with_ai(attrs, ai_suggestions) do
    with {:ok, portfolio} <- create_base_portfolio(attrs),
         {:ok, _sections} <- create_ai_recommended_sections(portfolio, ai_suggestions),
         {:ok, portfolio} <- apply_ai_customization(portfolio, ai_suggestions) do
      {:ok, portfolio}
    end
  end

  def create_blank_portfolio(attrs) do
    with {:ok, portfolio} <- create_base_portfolio(attrs),
         {:ok, _sections} <- create_basic_sections(portfolio) do
      {:ok, portfolio}
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp create_base_portfolio(attrs) do
    portfolio_attrs = Map.merge(attrs, %{
      slug: generate_unique_slug(attrs.title),
      customization: %{},
      status: "draft"
    })

    %Portfolio{}
    |> Portfolio.changeset(portfolio_attrs)
    |> Repo.insert()
  end

  defp create_template_sections(portfolio, template_key) do
    sections = get_template_sections(template_key)

    Enum.with_index(sections, fn section_data, index ->
      section_attrs = Map.merge(section_data, %{
        portfolio_id: portfolio.id,
        position: index + 1,
        visible: true
      })

      %PortfolioSection{}
      |> PortfolioSection.changeset(section_attrs)
      |> Repo.insert()
    end)
    |> Enum.reduce_while({:ok, []}, fn result, {:ok, acc} ->
      case result do
        {:ok, section} -> {:cont, {:ok, [section | acc]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp create_resume_sections(portfolio, resume_data) do
    sections = [
      %{
        section_type: :personal_info,
        title: "About Me",
        content: resume_data.personal_info
      },
      %{
        section_type: :work_experience,
        title: "Experience",
        content: %{"experiences" => resume_data.experience}
      },
      %{
        section_type: :skills,
        title: "Skills",
        content: %{"skills" => resume_data.skills}
      }
    ]

    create_sections_from_data(portfolio, sections)
  end

  defp create_ai_recommended_sections(portfolio, ai_suggestions) do
    # Generate sections based on AI analysis
    sections = [
      %{
        section_type: :professional_summary,
        title: "Professional Summary",
        content: %{"summary" => "AI-generated summary based on your profile"}
      },
      %{
        section_type: :projects,
        title: "Projects",
        content: %{"projects" => []}
      }
    ]

    create_sections_from_data(portfolio, sections)
  end

  defp create_basic_sections(portfolio) do
    sections = [
      %{
        section_type: :professional_summary,
        title: "Professional Summary",
        content: %{"summary" => ""}
      },
      %{
        section_type: :contact,
        title: "Contact",
        content: %{}
      }
    ]

    create_sections_from_data(portfolio, sections)
  end

  defp create_sections_from_data(portfolio, sections_data) do
    Enum.with_index(sections_data, fn section_data, index ->
      section_attrs = Map.merge(section_data, %{
        portfolio_id: portfolio.id,
        position: index + 1,
        visible: true
      })

      %PortfolioSection{}
      |> PortfolioSection.changeset(section_attrs)
      |> Repo.insert()
    end)
    |> Enum.reduce_while({:ok, []}, fn result, {:ok, acc} ->
      case result do
        {:ok, section} -> {:cont, {:ok, [section | acc]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp apply_template_customization(portfolio, template_key) do
    customization = get_template_customization(template_key)

    portfolio
    |> Portfolio.changeset(%{customization: customization})
    |> Repo.update()
  end

  defp apply_ai_customization(portfolio, ai_suggestions) do
    customization = generate_ai_customization(ai_suggestions)

    portfolio
    |> Portfolio.changeset(%{customization: customization})
    |> Repo.update()
  end

  defp get_template_sections(template_key) do
    case template_key do
      "executive" -> [
        %{section_type: :professional_summary, title: "Executive Summary"},
        %{section_type: :work_experience, title: "Professional Experience"},
        %{section_type: :education, title: "Education"},
        %{section_type: :skills, title: "Core Competencies"},
        %{section_type: :achievements, title: "Key Achievements"},
        %{section_type: :contact, title: "Contact Information"}
      ]
      "developer" -> [
        %{section_type: :professional_summary, title: "About"},
        %{section_type: :projects, title: "Featured Projects"},
        %{section_type: :skills, title: "Technical Skills"},
        %{section_type: :work_experience, title: "Experience"},
        %{section_type: :education, title: "Education"},
        %{section_type: :contact, title: "Get In Touch"}
      ]
      "creative" -> [
        %{section_type: :professional_summary, title: "Creative Vision"},
        %{section_type: :media_showcase, title: "Portfolio Gallery"},
        %{section_type: :projects, title: "Featured Work"},
        %{section_type: :skills, title: "Creative Skills"},
        %{section_type: :testimonials, title: "Client Testimonials"},
        %{section_type: :contact, title: "Let's Collaborate"}
      ]
      _ -> [
        %{section_type: :professional_summary, title: "About"},
        %{section_type: :work_experience, title: "Experience"},
        %{section_type: :skills, title: "Skills"},
        %{section_type: :contact, title: "Contact"}
      ]
    end
  end

  defp get_template_customization(template_key) do
    case template_key do
      "executive" -> %{
        "primary_color" => "#1f2937",
        "secondary_color" => "#374151",
        "accent_color" => "#3b82f6",
        "layout" => "professional"
      }
      "developer" -> %{
        "primary_color" => "#059669",
        "secondary_color" => "#047857",
        "accent_color" => "#10b981",
        "layout" => "technical"
      }
      "creative" -> %{
        "primary_color" => "#7c3aed",
        "secondary_color" => "#a855f7",
        "accent_color" => "#ec4899",
        "layout" => "artistic"
      }
      _ -> %{
        "primary_color" => "#6b7280",
        "secondary_color" => "#9ca3af",
        "accent_color" => "#374151",
        "layout" => "simple"
      }
    end
  end

  defp generate_ai_customization(ai_suggestions) do
    # Generate customization based on AI suggestions
    %{
      "primary_color" => "#3b82f6",
      "secondary_color" => "#64748b",
      "accent_color" => "#f59e0b",
      "layout" => "modern"
    }
  end

  defp generate_unique_slug(title) do
    base_slug = title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")

    case Repo.get_by(Portfolio, slug: base_slug) do
      nil -> base_slug
      _ -> "#{base_slug}-#{System.unique_integer([:positive])}"
    end
  end
end
