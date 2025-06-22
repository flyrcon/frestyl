# lib/frestyl_web/live/portfolio_live/edit.ex - SIMPLIFIED WORKING VERSION

defmodule FrestylWeb.PortfolioLive.Edit do
  use FrestylWeb, :live_view

  # Import all necessary modules
  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.{PortfolioTemplates, Portfolio}
  alias FrestylWeb.PortfolioLive.Edit.{TabRenderer, TemplateManager, SectionManager, MediaManager}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    portfolio = Portfolios.get_portfolio!(id)

    # Verify ownership
    if portfolio.user_id != socket.assigns.current_user.id do
      raise Ecto.NoResultsError, "Portfolio not found"
    end

    # Load sections and media for the portfolio (with fallbacks)
    sections = try do
      Portfolios.list_portfolio_sections(portfolio.id)
    rescue
      _ -> []
    end

    media_files = try do
      Portfolios.list_portfolio_media(portfolio.id)
    rescue
      _ -> []
    end

    # Get current template config
    current_theme = portfolio.theme || "professional_executive"
    template_config = try do
      PortfolioTemplates.get_template_config(current_theme)
    rescue
      _ -> %{primary_color: "#3b82f6", secondary_color: "#64748b", accent_color: "#f59e0b"}
    end

    # Generate initial CSS
    initial_css = generate_portfolio_css(portfolio.customization || %{}, template_config, current_theme)

    # Create form changeset that TabRenderer expects
    form = try do
      portfolio |> Portfolios.change_portfolio() |> to_form()
    rescue
      _ -> to_form(%{})  # Fallback empty form
    end

    # FIXED: Add video intro specific assigns
    socket =
      socket
      |> assign(:page_title, "Edit Portfolio")
      |> assign(:portfolio, portfolio)
      |> assign(:sections, sections)
      |> assign(:media_files, media_files)
      |> assign(:form, form)

      # Tab management
      |> assign(:active_tab, :overview)
      |> assign(:section_edit_id, nil)
      |> assign(:section_edit_tab, "content")
      |> assign(:editing_section, nil)

      # Template management
      |> assign(:available_templates, get_safe_templates())
      |> assign(:template_config, template_config)
      |> assign(:customization, portfolio.customization || %{})
      |> assign(:selected_template, current_theme)
      |> assign(:current_template, current_theme)
      |> assign(:template_layout, get_template_layout(template_config, current_theme))
      |> assign(:preview_css, initial_css)

      # Portfolio limits
      |> assign(:limits, %{max_portfolios: -1})
      |> assign(:current_portfolio_count, 0)
      |> assign(:can_duplicate, true)
      |> assign(:duplicate_disabled_reason, nil)

      # UI state
      |> assign(:unsaved_changes, false)
      |> assign(:show_add_section_dropdown, false)
      |> assign(:show_preview, false)
      |> assign(:show_media_modal, false)
      |> assign(:show_media_library, false)
      |> assign(:media_preview_id, nil)
      |> assign(:active_customization_tab, "templates")
      |> assign(:show_resume_import_modal, false)

      # FIXED: Video intro specific state
      |> assign(:show_video_intro, false)
      |> assign(:video_intro_component_id, "video-intro-#{:rand.uniform(1000)}")
      |> assign(:preview_device, :desktop)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    # Use the comprehensive TabRenderer for the main layout
    TabRenderer.render_main_layout(assigns)
  end

  # ============================================================================
  # EVENT HANDLERS - Delegating to appropriate managers
  # ============================================================================

  # Tab switching
  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end

  # Template-related events - delegate to TemplateManager
  @impl true
  def handle_event("select_template", params, socket) do
    {:noreply, TemplateManager.handle_template_selection(socket, params)}
  end

  @impl true
  def handle_event("apply_template", params, socket) do
    {:noreply, TemplateManager.handle_template_selection(socket, params)}
  end

  @impl true
  def handle_event("update_color", params, socket) do
    TemplateManager.handle_template_event(socket, "update_color", params)
  end

  @impl true
  def handle_event("update_typography", params, socket) do
    TemplateManager.handle_template_event(socket, "update_typography", params)
  end

  @impl true
  def handle_event("update_background", params, socket) do
    TemplateManager.handle_template_event(socket, "update_background", params)
  end

  @impl true
  def handle_event("set_customization_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_customization_tab, tab)}
  end

  # Overview tab form events
  @impl true
  def handle_event("update_portfolio", %{"portfolio" => portfolio_params}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, portfolio} ->
        form = try do
          portfolio |> Portfolios.change_portfolio() |> to_form()
        rescue
          _ -> to_form(%{})
        end

        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:form, form)
         |> assign(:unsaved_changes, false)
         |> put_flash(:info, "Portfolio updated successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update portfolio")}
    end
  end

  @impl true
  def handle_event("validate_portfolio", %{"portfolio" => portfolio_params}, socket) do
    changeset = try do
      socket.assigns.portfolio
      |> Portfolios.change_portfolio(portfolio_params)
      |> Map.put(:action, :validate)
    rescue
      _ -> Ecto.Changeset.change(%Portfolio{}, portfolio_params)
    end

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:unsaved_changes, true)}
  end

  @impl true
  def handle_event("duplicate_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :info, "Portfolio duplication is coming soon!")}
  end

  # Simplified event handlers for missing functionality
  @impl true
  def handle_event("show_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import_modal, true)}
  end

  @impl true
  def handle_event("hide_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import_modal, false)}
  end

  @impl true
  def handle_event("show_video_intro", _params, socket) do
    IO.puts("=== SHOW VIDEO INTRO EVENT ===")
    {:noreply, assign(socket, :show_video_intro, true)}
  end

  # Hide video intro modal
  @impl true
  def handle_event("hide_video_intro", _params, socket) do
    IO.puts("=== HIDE VIDEO INTRO EVENT ===")
    {:noreply, assign(socket, :show_video_intro, false)}
  end

  @impl true
  def handle_event("cancel_recording", _params, socket) do
    IO.puts("=== CANCEL RECORDING EVENT IN EDIT ===")
    {:noreply, assign(socket, :show_video_intro, false)}
  end

  @impl true
  def handle_event("camera_ready", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        camera_ready_params: params
      )
    end
    {:noreply, socket}
  end

    @impl true
  def handle_event("camera_error", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        camera_error_params: params
      )
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("video_blob_ready", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        video_blob_params: params
      )
    end
    {:noreply, socket}
  end

    @impl true
  def handle_event("countdown_update", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        countdown_update_params: params
      )
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_progress", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        recording_progress_params: params
      )
    end
    {:noreply, socket}
  end

    @impl true
  def handle_event("recording_error", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        recording_error_params: params
      )
    end
    {:noreply, socket}
  end

    # CRITICAL: Handle close video modal message from component
  @impl true
  def handle_info({:close_video_intro_modal, _}, socket) do
    IO.puts("=== CLOSE VIDEO INTRO MODAL MESSAGE ===")
    {:noreply, assign(socket, :show_video_intro, false)}
  end

  # CRITICAL: Handle video intro completion
  @impl true
  def handle_info({:video_intro_complete, data}, socket) do
    IO.puts("=== VIDEO INTRO COMPLETE MESSAGE ===")
    IO.inspect(data, label: "Video completion data")

    # Reload sections to include the new video intro section
    updated_sections = try do
      Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)
    rescue
      _ -> socket.assigns.sections
    end

    {:noreply,
     socket
     |> assign(:show_video_intro, false)
     |> assign(:sections, updated_sections)
     |> put_flash(:info, "Video introduction saved successfully! It will appear at the top of your portfolio.")}
  end

  # Handle timer messages that might leak from component
  @impl true
  def handle_info({:recording_tick, _component_id}, socket) do
    # Component handles its own timers, just ignore
    {:noreply, socket}
  end

  @impl true
  def handle_info({:countdown_tick, _component_id}, socket) do
    # Component handles its own timers, just ignore
    {:noreply, socket}
  end

  @impl true
  def handle_event("export_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :info, "PDF export is coming soon!")}
  end

  @impl true
  def handle_event("change_preview_device", %{"device" => device}, socket) do
    {:noreply, assign(socket, :preview_device, String.to_atom(device))}
  end

  @impl true
  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, !socket.assigns.show_preview)}
  end

  # Portfolio settings events (simplified)
  @impl true
  def handle_event("update_visibility", %{"visibility" => visibility}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{visibility: String.to_atom(visibility)}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> put_flash(:info, "Portfolio visibility updated!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update visibility")}
    end
  end

  @impl true
  def handle_event("delete_portfolio", _params, socket) do
    case Portfolios.delete_portfolio(socket.assigns.portfolio) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Portfolio deleted successfully!")
         |> redirect(to: "/portfolios")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete portfolio.")}
    end
  end

  # Design tab specific events
  @impl true
  def handle_event("update_color_scheme", params, socket) do
    TemplateManager.handle_template_event(socket, "update_color_scheme", params)
  end

  @impl true
  def handle_event("update_layout", %{"layout" => layout}, socket) do
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, "layout", layout)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        # Generate updated CSS
        template_config = try do
          PortfolioTemplates.get_template_config(portfolio.theme || "professional_executive")
        rescue
          _ -> %{primary_color: "#3b82f6", secondary_color: "#64748b", accent_color: "#f59e0b"}
        end

        updated_css = generate_portfolio_css(updated_customization, template_config, portfolio.theme)

        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:template_layout, layout)
        |> assign(:preview_css, updated_css)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Layout updated successfully!")
        |> push_event("customization-changed", %{layout: layout})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update layout.")}
    end
  end

  @impl true
  def handle_event("refresh_preview", params, socket) do
    TemplateManager.handle_template_event(socket, "refresh_preview", params)
  end

  # Catch-all for section events (delegate to SectionManager if available)
  @impl true
  def handle_event(event_name, params, socket) when is_binary(event_name) do
    IO.puts("⚠️  Unhandled event: #{event_name}")
    IO.inspect(params, label: "Event params")
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_add_section_dropdown", params, socket) do
    IO.puts("🔧 Toggle dropdown called with params: #{inspect(params)}")
    current_state = socket.assigns[:show_add_section_dropdown] || false
    new_state = !current_state

    IO.puts("Dropdown state: #{current_state} -> #{new_state}")

    socket = assign(socket, :show_add_section_dropdown, new_state)

    # Add some visual feedback
    if new_state do
      IO.puts("✅ Dropdown should now be OPEN")
    else
      IO.puts("✅ Dropdown should now be CLOSED")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_add_section_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_add_section_dropdown, false)}
  end

  # Section creation
  @impl true
  def handle_event("add_section", %{"type" => section_type}, socket) do
    try do
      # Create new section
      section_attrs = %{
        portfolio_id: socket.assigns.portfolio.id,
        title: get_default_title_for_type(section_type),
        section_type: section_type,
        content: get_default_content_for_type(section_type),
        position: length(socket.assigns.sections) + 1,
        visible: true
      }

      case Portfolios.create_section(section_attrs) do
        {:ok, section} ->
          updated_sections = socket.assigns.sections ++ [section]

          {:noreply,
          socket
          |> assign(:sections, updated_sections)
          |> assign(:show_add_section_dropdown, false)
          |> put_flash(:info, "Section added successfully!")
          |> push_event("section-added", %{section_id: section.id, section_type: section_type})}

        {:error, changeset} ->
          error_msg = format_changeset_errors(changeset)
          {:noreply, put_flash(socket, :error, "Failed to add section: #{error_msg}")}
      end
    rescue
      error ->
        IO.puts("❌ Add section error: #{Exception.message(error)}")
        {:noreply, put_flash(socket, :error, "Failed to add section")}
    end
  end

  # Section editing
  @impl true
  def handle_event("edit_section", %{"id" => section_id}, socket) do
    try do
      section_id_int = String.to_integer(section_id)
      section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

      if section do
        # Get section media if it exists
        section_media = try do
          Portfolios.list_section_media(section_id_int)
        rescue
          _ -> []
        end

        {:noreply,
        socket
        |> assign(:section_edit_id, section_id)
        |> assign(:editing_section, section)
        |> assign(:editing_section_media, section_media)
        |> assign(:section_edit_tab, "content")
        |> assign(:active_tab, :sections)
        |> push_event("section-edit-started", %{section_id: section_id_int})}
      else
        {:noreply, put_flash(socket, :error, "Section not found")}
      end
    rescue
      error ->
        IO.puts("❌ Edit section error: #{Exception.message(error)}")
        {:noreply, put_flash(socket, :error, "Failed to edit section")}
    end
  end

  # Section deletion
  @impl true
  def handle_event("delete_section", %{"id" => section_id}, socket) do
    try do
      section_id_int = String.to_integer(section_id)
      section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

      if section do
        case Portfolios.delete_section(section) do
          {:ok, _} ->
            updated_sections = Enum.reject(socket.assigns.sections, &(&1.id == section_id_int))

            {:noreply,
            socket
            |> assign(:sections, updated_sections)
            |> assign(:section_edit_id, nil)
            |> assign(:editing_section, nil)
            |> put_flash(:info, "Section deleted successfully")
            |> push_event("section-deleted", %{section_id: section_id_int})}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to delete section")}
        end
      else
        {:noreply, put_flash(socket, :error, "Section not found")}
      end
    rescue
      error ->
        IO.puts("❌ Delete section error: #{Exception.message(error)}")
        {:noreply, put_flash(socket, :error, "Failed to delete section")}
    end
  end

  # Section visibility toggle
  @impl true
  def handle_event("toggle_section_visibility", %{"id" => section_id}, socket) do
    try do
      section_id_int = String.to_integer(section_id)
      section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

      if section do
        case Portfolios.update_section(section, %{visible: !section.visible}) do
          {:ok, updated_section} ->
            updated_sections = Enum.map(socket.assigns.sections, fn s ->
              if s.id == section_id_int, do: updated_section, else: s
            end)

            {:noreply,
            socket
            |> assign(:sections, updated_sections)
            |> put_flash(:info, "Section visibility updated")
            |> push_event("section-visibility-toggled", %{
              section_id: section_id_int,
              visible: updated_section.visible
            })}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update section visibility")}
        end
      else
        {:noreply, put_flash(socket, :error, "Section not found")}
      end
    rescue
      error ->
        IO.puts("❌ Toggle visibility error: #{Exception.message(error)}")
        {:noreply, put_flash(socket, :error, "Failed to toggle visibility")}
    end
  end

  # Section save/cancel
  @impl true
  def handle_event("save_section", %{"id" => section_id}, socket) do
    try do
      section_id_int = String.to_integer(section_id)

      case Portfolios.get_section!(section_id_int) do
        nil ->
          {:noreply, put_flash(socket, :error, "Section not found")}

        current_section ->
          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == section_id_int, do: current_section, else: s
          end)

          {:noreply,
          socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, current_section)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Section saved successfully!")
          |> push_event("section-saved", %{section_id: section_id_int})}
      end
    rescue
      error ->
        IO.puts("❌ Save section error: #{Exception.message(error)}")
        {:noreply, put_flash(socket, :error, "Failed to save section")}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
    socket
    |> assign(:section_edit_id, nil)
    |> assign(:editing_section, nil)
    |> assign(:editing_section_media, [])
    |> assign(:section_edit_tab, nil)
    |> push_event("section-edit-cancelled", %{})}
  end

  # Section tab switching
  @impl true
  def handle_event("switch_section_edit_tab", %{"tab" => tab}, socket) do
    {:noreply,
    socket
    |> assign(:section_edit_tab, tab)
    |> push_event("section-edit-tab-changed", %{tab: tab})}
  end

  # Helper functions
  defp get_default_title_for_type(type) do
    case type do
      "intro" -> "Introduction"
      "experience" -> "Professional Experience"
      "education" -> "Education"
      "skills" -> "Skills & Expertise"
      "projects" -> "Projects"
      "featured_project" -> "Featured Project"
      "case_study" -> "Case Study"
      "achievements" -> "Achievements"
      "testimonial" -> "Testimonials"
      "media_showcase" -> "Media Gallery"
      "code_showcase" -> "Code Showcase"
      "contact" -> "Contact Information"
      "custom" -> "Custom Section"
      _ -> "New Section"
    end
  end

  defp get_default_content_for_type(type) do
    case type do
      "intro" -> %{
        "headline" => "Hello, I'm [Your Name]",
        "summary" => "A brief introduction about yourself and your professional journey."
      }
      "experience" -> %{"jobs" => []}
      "education" -> %{"education" => []}
      "skills" -> %{"skills" => []}
      "projects" -> %{"projects" => []}
      _ -> %{}
    end
  end

  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  defp get_template_layout(config, theme) do
    case config do
      %{"layout" => layout} when is_binary(layout) -> layout
      %{:layout => layout} when is_binary(layout) -> layout
      _ ->
        case theme do
          "executive" -> "dashboard"
          "developer" -> "terminal"
          "designer" -> "gallery"
          "consultant" -> "case_study"
          "academic" -> "academic"
          "creative" -> "gallery"
          "minimalist" -> "minimal"
          _ -> "dashboard"
        end
    end
  end

  defp get_available_templates_with_config do
    [
      {"executive", %{
        name: "Executive",
        description: "Professional corporate portfolio with dashboard layout",
        category: "business",
        color_preview: ["#1e40af", "#64748b", "#3b82f6"],
        features: ["Dashboard Layout", "Corporate Styling", "Professional Typography", "Metrics Display"]
      }},
      {"developer", %{
        name: "Developer",
        description: "Technical portfolio with terminal-inspired design",
        category: "technical",
        color_preview: ["#059669", "#374151", "#10b981"],
        features: ["Terminal Style", "Code Showcase", "Dark Theme", "Technical Layout"]
      }},
      {"designer", %{
        name: "Designer",
        description: "Creative visual portfolio with gallery layout",
        category: "creative",
        color_preview: ["#7c3aed", "#ec4899", "#f59e0b"],
        features: ["Gallery Layout", "Visual Focus", "Creative Colors", "Portfolio Showcase"]
      }},
      {"minimalist", %{
        name: "Minimalist",
        description: "Ultra-clean design focused on content and typography",
        category: "minimal",
        color_preview: ["#000000", "#666666", "#333333"],
        features: ["Minimal Design", "Typography Focus", "Clean Layout", "Distraction-Free"]
      }},
      {"clean", %{
        name: "Clean",
        description: "Modern organized layout with subtle visual elements",
        category: "modern",
        color_preview: ["#2563eb", "#64748b", "#3b82f6"],
        features: ["Modern Design", "Organized Grid", "Subtle Shadows", "Professional"]
      }},
      {"elegant", %{
        name: "Elegant",
        description: "Sophisticated design with premium typography and spacing",
        category: "premium",
        color_preview: ["#4c1d95", "#7c3aed", "#c084fc"],
        features: ["Luxury Design", "Premium Typography", "Elegant Spacing", "Sophisticated"]
      }},
      {"consultant", %{
        name: "Consultant",
        description: "Business-focused design for case studies and presentations",
        category: "business",
        color_preview: ["#0891b2", "#0284c7", "#6366f1"],
        features: ["Case Studies", "Business Layout", "Professional", "Structured"]
      }},
      {"academic", %{
        name: "Academic",
        description: "Research-focused design for publications and education",
        category: "academic",
        color_preview: ["#059669", "#047857", "#10b981"],
        features: ["Publication Ready", "Research Focus", "Clean Typography", "Academic Style"]
      }}
    ]
  end

  defp get_template_preview_bg(template_config) do
    case template_config.category do
      "business" -> "linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%)"
      "technical" -> "linear-gradient(135deg, #1f2937 0%, #374151 100%)"
      "creative" -> "linear-gradient(135deg, #fdf2f8 0%, #fce7f3 100%)"
      "minimal" -> "#ffffff"
      "modern" -> "linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)"
      "premium" -> "linear-gradient(135deg, #faf5ff 0%, #f3e8ff 100%)"
      "academic" -> "linear-gradient(135deg, #f0fdfa 0%, #ccfbf1 100%)"
      _ -> "linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%)"
    end
  end

  defp render_template_preview_content(template_key, template_config) do
    case template_key do
      "executive" ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full flex flex-col justify-between">
          <div class="space-y-2">
            <div class="h-2 bg-blue-600 rounded w-3/4"></div>
            <div class="h-1 bg-blue-400 rounded w-1/2"></div>
          </div>
          <div class="grid grid-cols-3 gap-1">
            <div class="h-6 bg-blue-200 rounded"></div>
            <div class="h-6 bg-blue-300 rounded"></div>
            <div class="h-6 bg-blue-200 rounded"></div>
          </div>
        </div>
        """)

      "developer" ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full bg-gray-900 text-green-400 font-mono text-xs">
          <div class="space-y-1">
            <div class="text-green-500">$ whoami</div>
            <div class="text-green-300">developer</div>
            <div class="text-green-500">$ ls -la projects/</div>
            <div class="text-green-300">portfolio.js</div>
            <div class="text-green-300">awesome-app.py</div>
          </div>
        </div>
        """)

      "designer" ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full">
          <div class="grid grid-cols-2 gap-2 h-full">
            <div class="bg-purple-400 rounded-lg"></div>
            <div class="space-y-2">
              <div class="bg-pink-400 rounded h-1/2"></div>
              <div class="bg-orange-400 rounded h-1/3"></div>
            </div>
          </div>
        </div>
        """)

      "minimalist" ->
        Phoenix.HTML.raw("""
        <div class="p-6 h-full flex flex-col justify-center items-center space-y-3">
          <div class="h-1 bg-black rounded w-16"></div>
          <div class="h-1 bg-gray-600 rounded w-12"></div>
          <div class="h-1 bg-gray-400 rounded w-14"></div>
        </div>
        """)

      "clean" ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full">
          <div class="space-y-3">
            <div class="h-2 bg-blue-500 rounded w-full"></div>
            <div class="grid grid-cols-2 gap-2">
              <div class="h-8 bg-blue-100 rounded shadow-sm"></div>
              <div class="h-8 bg-blue-100 rounded shadow-sm"></div>
            </div>
            <div class="h-6 bg-blue-50 rounded"></div>
          </div>
        </div>
        """)

      "elegant" ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full bg-gradient-to-br from-purple-50 to-purple-100">
          <div class="space-y-4 text-center">
            <div class="h-2 bg-purple-600 rounded w-20 mx-auto"></div>
            <div class="space-y-1">
              <div class="h-1 bg-purple-400 rounded w-16 mx-auto"></div>
              <div class="h-1 bg-purple-300 rounded w-12 mx-auto"></div>
            </div>
            <div class="w-8 h-8 bg-purple-600 rounded-full mx-auto"></div>
          </div>
        </div>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full flex items-center justify-center">
          <div class="w-8 h-8 bg-gray-400 rounded"></div>
        </div>
        """)
    end
  end

    # ============================================================================
    # MESSAGE HANDLERS - Template component communication
    # ============================================================================

  @impl true
  def handle_event("select_template", %{"template" => template_key}, socket) do
    IO.puts("🔥 Template selection: #{template_key}")
    IO.puts("🔥 Current theme: #{socket.assigns.portfolio.theme}")

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{theme: template_key}) do
      {:ok, portfolio} ->
        IO.puts("✅ Template updated to: #{portfolio.theme}")

        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> put_flash(:info, "Template changed to #{String.capitalize(template_key)}")}

      {:error, changeset} ->
        IO.puts("❌ Template update failed: #{inspect(changeset.errors)}")

        {:noreply,
        socket
        |> put_flash(:error, "Failed to update template")}
    end
  end

  @impl true
  def handle_info({:preview_template, template_key}, socket) do
    {:noreply,
     socket
     |> assign(:show_template_preview, true)
     |> assign(:preview_template, template_key)}
  end

  @impl true
  def handle_info({:apply_template, template_key}, socket) do
    {:noreply, TemplateManager.handle_template_selection(socket, %{"template" => template_key})}
  end

  # Handle file uploads (if available)
  @impl true
  def handle_info({:file_uploaded, file_info}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_template_layout(config, theme) do
    case config do
      %{"layout" => layout} when is_binary(layout) -> layout
      %{:layout => layout} when is_binary(layout) -> layout
      _ ->
        case theme do
          "executive" -> "dashboard"
          "developer" -> "terminal"
          "designer" -> "gallery"
          "consultant" -> "case_study"
          "academic" -> "academic"
          "creative" -> "gallery"
          "minimalist" -> "minimal"
          _ -> "dashboard"
        end
    end
  end

  defp get_safe_templates do
    try do
      PortfolioTemplates.available_templates()
    rescue
      _ ->
        # Fallback templates if module doesn't exist
        [
          {"executive", %{name: "Executive", category: "professional", icon: "💼"}},
          {"developer", %{name: "Developer", category: "technical", icon: "💻"}},
          {"designer", %{name: "Designer", category: "creative", icon: "🎨"}},
          {"consultant", %{name: "Consultant", category: "professional", icon: "📊"}}
        ]
    end
  end

  defp generate_portfolio_css(customization, template_config, theme) do
    # Generate CSS from customization and template config
    primary_color = customization["primary_color"] || template_config[:primary_color] || "#3b82f6"
    secondary_color = customization["secondary_color"] || template_config[:secondary_color] || "#64748b"
    accent_color = customization["accent_color"] || template_config[:accent_color] || "#f59e0b"

    # Extract typography
    typography = customization["typography"] || template_config[:typography] || %{}
    font_family = typography["font_family"] || typography[:font_family] || "Inter"

    font_family_css = case font_family do
      "Inter" -> "'Inter', system-ui, sans-serif"
      "Merriweather" -> "'Merriweather', Georgia, serif"
      "JetBrains Mono" -> "'JetBrains Mono', 'Fira Code', monospace"
      "Playfair Display" -> "'Playfair Display', Georgia, serif"
      _ -> "system-ui, sans-serif"
    end

    """
    <style>
    :root {
      --portfolio-primary-color: #{primary_color};
      --portfolio-secondary-color: #{secondary_color};
      --portfolio-accent-color: #{accent_color};
      --portfolio-font-family: #{font_family_css};
    }

    .portfolio-primary { color: var(--portfolio-primary-color) !important; }
    .portfolio-secondary { color: var(--portfolio-secondary-color) !important; }
    .portfolio-accent { color: var(--portfolio-accent-color) !important; }
    .portfolio-bg-primary { background-color: var(--portfolio-primary-color) !important; }
    .portfolio-bg-secondary { background-color: var(--portfolio-secondary-color) !important; }
    .portfolio-bg-accent { background-color: var(--portfolio-accent-color) !important; }

    .portfolio-preview {
      font-family: var(--portfolio-font-family) !important;
    }
    </style>
    """
  end
end
