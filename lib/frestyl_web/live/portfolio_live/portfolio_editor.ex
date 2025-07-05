# lib/frestyl_web/live/portfolio_live/portfolio_editor.ex
# UNIFIED PORTFOLIO EDITOR - Replaces all manager modules

defmodule FrestylWeb.PortfolioLive.PortfolioEditor do
  use FrestylWeb, :live_view

  import Ecto.Query
  alias Frestyl.Repo

  alias Frestyl.{Accounts, Analytics, Channels, Portfolios, Streaming}
  alias Frestyl.Portfolios.ContentBlock
  alias Frestyl.Stories.MediaBinding
  alias Frestyl.Accounts.{User, Account}
  alias FrestylWeb.PortfolioLive.PortfolioPerformance
  alias FrestylWeb.PortfolioLive.Edit.ResumeImportModal

  alias FrestylWeb.PortfolioLive.Components.{ContentRenderer, SectionEditor, MediaLibrary, VideoRecorder}

  # ============================================================================
  # MOUNT - Account-Aware Foundation
  # ============================================================================

  @impl true
  def mount(%{"id" => portfolio_id}, _session, socket) do
    start_time = System.monotonic_time(:millisecond)
    user = socket.assigns.current_user

    # Fix 1: Remove the wrong function call - params doesn't exist here
    # portfolio = get_portfolio_from_params(params, user)  # REMOVE THIS LINE

    # Load portfolio with account context
    case load_portfolio_with_account_and_blocks(portfolio_id, user) do
      {:ok, portfolio, account, content_blocks} ->
        # Account-based feature permissions
        features = get_account_features(account)
        limits = get_account_limits(account)

        # Load portfolio data
        sections = load_portfolio_sections(portfolio.id)
        media_library = load_portfolio_media(portfolio.id)

        # Monetization & streaming data (account-dependent)
        monetization_data = load_monetization_data(portfolio, account)
        streaming_config = load_streaming_config(portfolio, account)

        # Template system with brand control hooks
        available_layouts = get_available_layouts(account)
        brand_constraints = get_brand_constraints(account)

        # Fix 2: Remove duplicate account loading since you already have it from the case statement
        # account = case Frestyl.Accounts.list_user_accounts(user.id) do
        #   [account | _] -> Map.put_new(account, :subscription_tier, "personal")
        #   [] -> %{subscription_tier: "personal"}
        # end

        socket = socket
        |> assign(:portfolio, portfolio)
        |> assign(:current_user, user)
        |> assign(:can_edit, can_edit_portfolio?(portfolio, user))
        |> assign(:show_resume_import, false)  # ADD THIS LINE
        |> assign(:active_section, "basic_info")
        |> assign(:unsaved_changes, false)
        |> assign(:page_title, "Edit #{portfolio.title || 'Portfolio'}")
        |> assign_core_data(portfolio, account, user)
        |> assign_features_and_limits(features, limits)
        |> assign(:active_tab, :overview)
        |> assign_content_data(sections, media_library, content_blocks)
        |> assign_monetization_data(monetization_data, streaming_config)
        # Fix 3: Pass the correct parameters to assign_design_system
        |> assign_design_system(portfolio, account)  # Changed from (available_layouts, brand_constraints)
        |> assign_ui_state()
        |> assign_live_preview_state()
        |> assign(:show_custom_fields_modal, false)
        |> assign(:custom_fields_section, nil)
        |> assign(:custom_field_definitions, [])
        |> assign(:custom_field_values, [])

        load_time = System.monotonic_time(:millisecond) - start_time
        # Fix 4: Add safe call for performance tracking
        track_portfolio_editor_load_safe(portfolio_id, load_time)

        socket = if socket.assigns.show_live_preview do
          broadcast_preview_update(socket)
          socket
        else
          socket
        end

        {:ok, socket}

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/portfolios")}

      {:error, :unauthorized} ->
        {:ok, socket |> put_flash(:error, "Access denied") |> redirect(to: "/portfolios")}
    end
  end

  defp assign_live_preview_state(socket) do
    portfolio = socket.assigns.portfolio

    socket
    |> assign(:show_live_preview, true)
    |> assign(:preview_token, generate_preview_token(portfolio.id))
    |> assign(:preview_mobile_view, false)
    |> assign(:pending_changes, %{})
    |> assign(:debounce_timer, nil)
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    valid_tabs = [:overview, :content, :design, :monetization, :streaming, :analytics]
    tab_atom = String.to_existing_atom(tab)

    if tab_atom in valid_tabs do
      {:noreply, assign(socket, :active_tab, tab_atom)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_live_preview", _params, socket) do
    show_preview = !Map.get(socket.assigns, :show_live_preview, false)

    socket =
      socket
      |> assign(:show_live_preview, show_preview)
      |> assign(:preview_mobile_view, false)

    # Generate preview URL if enabling
    if show_preview do
      preview_url = build_preview_url(socket.assigns.portfolio, socket.assigns.customization)
      socket = assign(socket, :preview_url, preview_url)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_preview_mobile", _params, socket) do
    mobile_view = !Map.get(socket.assigns, :preview_mobile_view, false)

    # Broadcast viewport change to preview iframe
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{socket.assigns.portfolio.id}",
      {:viewport_change, mobile_view}
    )

    {:noreply, assign(socket, :preview_mobile_view, mobile_view)}
  end

  @impl true
  def handle_event("update_color", %{"field" => field, "value" => color}, socket) do
    portfolio = socket.assigns.portfolio
    customization = Map.get(portfolio, :customization, %{})

    # Update customization
    updated_customization = Map.put(customization, field, color)

    # Save to database
    case Portfolios.update_portfolio_customization(portfolio, updated_customization) do
      {:ok, updated_portfolio} ->
        # Generate new CSS
        css = generate_live_preview_css(updated_customization, portfolio.theme)

        # Broadcast to live preview
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "portfolio_preview:#{portfolio.id}",
          {:preview_update, updated_customization, css}
        )

        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)
          |> assign(:unsaved_changes, false)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save color change")}
    end
  end

  @impl true
  def handle_event("update_layout", %{"value" => layout}, socket) do
    portfolio = socket.assigns.portfolio
    customization = Map.get(portfolio, :customization, %{})

    # Update layout in customization
    updated_customization = Map.put(customization, "layout", layout)

    case Portfolios.update_portfolio_customization(portfolio, updated_customization) do
      {:ok, updated_portfolio} ->
        # Generate new CSS
        css = generate_live_preview_css(updated_customization, portfolio.theme)

        # Broadcast to live preview
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "portfolio_preview:#{portfolio.id}",
          {:preview_update, updated_customization, css}
        )

        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)
          |> assign(:unsaved_changes, false)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save layout change")}
    end
  end

  @impl true
  def handle_event("update_template", %{"template" => template}, socket) do
    portfolio = socket.assigns.portfolio

    case Portfolios.update_portfolio_theme(portfolio, template) do
      {:ok, updated_portfolio} ->
        # Get template config
        template_config = get_template_config(template)

        # Generate CSS for new template
        css = generate_live_preview_css(updated_portfolio.customization || %{}, template)

        # Broadcast template change
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "portfolio_preview:#{portfolio.id}",
          {:template_change, template, css}
        )

        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:selected_template, template)
          |> assign(:template_config, template_config)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Template updated successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update template")}
    end
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    IO.puts("🔧 SHOW: Switching to tab: #{tab}")
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end

  @impl true
  def handle_event("change_theme", %{"theme" => theme}, socket) do
    IO.puts("🎭 CHANGE THEME: #{theme} (no refresh)")

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{theme: theme}) do
      {:ok, updated_portfolio} ->
        IO.puts("✅ Theme saved: #{theme}")

        # DON'T redirect or refresh, just update socket
        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:current_theme, theme)
        |> assign(:unsaved_changes, false)

        {:noreply, socket}  # NO push_event or redirects

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to save theme: #{error_msg}")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import, true)}
  end

  @impl true
  def handle_event("hide_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import, false)}
  end

  @impl true
  def handle_event("change-section", %{"section" => section_type, "value" => value}, socket) do
    case section_type do
      "experience" ->
        handle_experience_section_change(value, socket)

      "education" ->
        handle_education_section_change(value, socket)

      "skills" ->
        handle_skills_section_change(value, socket)

      "projects" ->
        handle_projects_section_change(value, socket)

      "custom" ->
        handle_custom_section_change(value, socket)

      _ ->
        {:noreply, put_flash(socket, :error, "Unknown section type: #{section_type}")}
    end
  end

  @impl true
  def handle_event("save_portfolio", %{"portfolio" => portfolio_params}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, updated_portfolio} ->
        # Broadcast update via PubSub for real-time sync with show page
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "portfolio:#{updated_portfolio.id}",
          {:portfolio_updated, updated_portfolio}
        )

        {:noreply,
         socket
         |> assign(:portfolio, updated_portfolio)
         |> assign(:unsaved_changes, false)
         |> put_flash(:info, "Portfolio updated successfully!")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save portfolio")
         |> assign(:changeset, changeset)}
    end
  end

  @impl true
  def handle_event("portfolio_changed", _params, socket) do
    {:noreply, assign(socket, :unsaved_changes, true)}
  end

  defp get_available_layout_keys(available_layouts) when is_map(available_layouts) do
    Map.keys(available_layouts)
  end
  defp get_available_layout_keys(_), do: ["minimal", "professional", "creative"]


  @impl true
  def handle_event("toggle_add_section_dropdown", _params, socket) do
    current_state = socket.assigns[:show_add_section_dropdown] || false
    {:noreply, assign(socket, :show_add_section_dropdown, !current_state)}
  end

  @impl true
  def handle_event("close_add_section_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_add_section_dropdown, false)}
  end

  @impl true
  def handle_event("add_section", params, socket) do
    # Handle different parameter formats
    section_type = case params do
      %{"section_type" => type} -> type
      %{"type" => type} -> type
      _ -> nil
    end

    cond do
      # No section type provided - show error or dropdown
      is_nil(section_type) ->
        {:noreply, put_flash(socket, :error, "Please select a section type")}

      # Check if user can add more sections
      !can_add_section?(socket) ->
        {:noreply, put_flash(socket, :error, "Section limit reached for your subscription")}

      # Valid section type - create the section
      true ->
        portfolio = socket.assigns.portfolio
        sections = socket.assigns.sections
        next_position = length(sections) + 1

        # Enhanced section attributes with custom fields support
        section_attrs = build_section_attrs(section_type, portfolio.id, next_position)

        case Portfolios.create_section(section_attrs) do
          {:ok, new_section} ->
            updated_sections = sections ++ [new_section]

            # Enhanced success response with better messaging
            success_message = get_section_creation_message(section_type)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:show_add_section_dropdown, false)
            |> assign(:editing_section, new_section)
            |> assign(:editing_mode, :section_edit)
            |> put_flash(:info, success_message)
            |> assign(:unsaved_changes, false)

            {:noreply, socket}

          {:error, changeset} ->
            error_msg = format_changeset_errors(changeset)
            {:noreply, put_flash(socket, :error, "Failed to add section: #{error_msg}")}
        end
    end
  end

  @impl true
  def handle_event("enable_dynamic_cards", _params, socket) do
    portfolio_id = socket.assigns.portfolio.id

    # Redirect to dynamic card editor
    {:noreply,
    socket
    |> put_flash(:info, "Switching to Dynamic Card Layout Editor...")
    |> push_navigate(to: "/portfolios/#{portfolio_id}/dynamic_edit")}
  end

  # Helper function to build section attributes based on type
  defp build_section_attrs(section_type, portfolio_id, position) do
    base_attrs = %{
      portfolio_id: portfolio_id,
      section_type: normalize_section_type(section_type),
      title: get_default_title_for_type(section_type),
      content: get_default_content_for_type(section_type),
      visible: true,
      position: position
    }

    # Add custom fields support for custom sections
    case section_type do
      "custom" ->
        Map.merge(base_attrs, %{
          custom_fields_enabled: true,
          custom_field_template: nil
        })

      type when type in ["certifications", "languages", "awards", "social_metrics"] ->
        # These could benefit from custom fields templates
        Map.merge(base_attrs, %{
          custom_fields_enabled: true,
          custom_field_template: type
        })

      _ ->
        base_attrs
    end
  end

  # Normalize section type to ensure it's an atom
  defp normalize_section_type(section_type) when is_binary(section_type) do
    case section_type do
      "intro" -> :intro
      "experience" -> :experience
      "education" -> :education
      "skills" -> :skills
      "projects" -> :projects
      "featured_project" -> :featured_project
      "case_study" -> :case_study
      "achievements" -> :achievements
      "testimonial" -> :testimonial
      "media_showcase" -> :media_showcase
      "code_showcase" -> :code_showcase
      "contact" -> :contact
      "custom" -> :custom
      "story" -> :story
      "timeline" -> :timeline
      "narrative" -> :narrative
      "journey" -> :journey
      "certifications" -> :custom  # Use custom type with template
      "languages" -> :custom       # Use custom type with template
      "awards" -> :custom         # Use custom type with template
      "social_metrics" -> :custom # Use custom type with template
      _ -> :custom
    end
  end

  defp normalize_section_type(section_type) when is_atom(section_type), do: section_type

  # Enhanced messaging based on section type
  defp get_section_creation_message(section_type) do
    case section_type do
      "custom" ->
        "Custom section added! You can now add custom fields to capture unique information."

      "certifications" ->
        "Certifications section added with custom fields template! Add your professional credentials."

      "languages" ->
        "Languages section added with proficiency tracking! List your language skills."

      "awards" ->
        "Awards section added! Showcase your recognition and achievements."

      "social_metrics" ->
        "Social metrics section added! Track your online presence and engagement."

      type when type in ["experience", "education", "skills", "projects"] ->
        "#{format_section_type(type)} section added successfully!"

      _ ->
        "#{format_section_type(section_type)} section added successfully!"
    end
  end

  # Update get_default_content_for_type to handle new section types
  defp get_default_content_for_type("certifications") do
    %{
      "title" => "Certifications & Licenses",
      "content" => "Professional certifications and licenses will be displayed here using custom fields.",
      "custom_fields" => %{},
      "layout" => "list",
      "show_expiry_dates" => true,
      "show_credential_urls" => true
    }
  end

  defp get_default_content_for_type("languages") do
    %{
      "title" => "Languages",
      "content" => "Language skills and proficiency levels will be displayed here.",
      "custom_fields" => %{},
      "layout" => "grid",
      "show_proficiency_levels" => true,
      "proficiency_scale" => "standard" # beginner, intermediate, advanced, fluent, native
    }
  end

  defp get_default_content_for_type("awards") do
    %{
      "title" => "Awards & Recognition",
      "content" => "Awards, honors, and recognition will be displayed here.",
      "custom_fields" => %{},
      "layout" => "timeline",
      "show_award_dates" => true,
      "show_descriptions" => true
    }
  end

  defp get_default_content_for_type("social_metrics") do
    %{
      "title" => "Social Media Presence",
      "content" => "Social media metrics and online presence will be tracked here.",
      "custom_fields" => %{},
      "layout" => "cards",
      "show_follower_counts" => true,
      "show_engagement_rates" => true,
      "platforms" => []
    }
  end

  defp get_default_content_for_type(section_type) do
    # Fall back to your existing function
    case Frestyl.Portfolios.PortfolioSection.default_content_for_type(normalize_section_type(section_type)) do
      %{} = content -> content
      _ -> %{"title" => get_default_title_for_type(section_type), "content" => ""}
    end
  end

  # Update get_default_title_for_type to handle new section types
  defp get_default_title_for_type("certifications"), do: "Certifications"
  defp get_default_title_for_type("languages"), do: "Languages"
  defp get_default_title_for_type("awards"), do: "Awards & Recognition"
  defp get_default_title_for_type("social_metrics"), do: "Social Media"

  defp get_default_title_for_type(section_type) do
    case section_type do
      "intro" -> "Introduction"
      "experience" -> "Work Experience"
      "education" -> "Education"
      "skills" -> "Skills"
      "projects" -> "Projects"
      "featured_project" -> "Featured Project"
      "case_study" -> "Case Study"
      "achievements" -> "Achievements"
      "testimonial" -> "Testimonials"
      "media_showcase" -> "Media Gallery"
      "code_showcase" -> "Code Showcase"
      "contact" -> "Contact Information"
      "custom" -> "Custom Section"
      "story" -> "My Story"
      "timeline" -> "Timeline"
      "narrative" -> "Narrative"
      "journey" -> "Journey"
      _ -> String.capitalize(section_type)
    end
  end

  # Enhanced format_section_type function
  defp format_section_type(section_type) do
    case section_type do
      "certifications" -> "Certifications"
      "languages" -> "Languages"
      "awards" -> "Awards"
      "social_metrics" -> "Social Metrics"
      _ ->
        section_type
        |> String.replace("_", " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
    end
  end

  # Add hook to apply custom field templates after section creation
  defp maybe_apply_custom_field_template(section, socket) do
    case section.custom_field_template do
      nil ->
        {:ok, section}

      template_name when is_binary(template_name) ->
        case Portfolios.apply_field_template(section.portfolio_id, template_name) do
          {:ok, _results} ->
            IO.puts("✅ Applied custom field template: #{template_name}")
            {:ok, section}

          {:error, reason} ->
            IO.puts("⚠️ Failed to apply template #{template_name}: #{reason}")
            # Don't fail section creation if template application fails
            {:ok, section}
        end
    end
  end

  # Helper function to check if user can add more sections
  defp can_add_section?(socket) do
    current_count = length(socket.assigns.sections)
    max_sections = get_in(socket.assigns, [:limits, :max_sections]) || 10

    current_count < max_sections
  end

  # Enhanced error formatting
  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  @impl true
  def handle_event("edit_section", %{"section_id" => section_id}, socket) do
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == String.to_integer(section_id)))

    if section do
      socket =
        socket
        |> assign(:editing_section, section)
        |> assign(:section_edit_mode, true)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("save_section", %{"section" => section_params}, socket) do
    case socket.assigns.editing_section do
      nil ->
        {:noreply, put_flash(socket, :error, "No section being edited")}

      section ->
        case Portfolios.update_portfolio_section(section, section_params) do
          {:ok, updated_section} ->
            # Update sections list
            updated_sections =
              socket.assigns.sections
              |> Enum.map(fn s ->
                if s.id == updated_section.id, do: updated_section, else: s
              end)

            # Broadcast section update to live preview
            Phoenix.PubSub.broadcast(
              Frestyl.PubSub,
              "portfolio_preview:#{socket.assigns.portfolio.id}",
              {:section_update, updated_section}
            )

            socket =
              socket
              |> assign(:sections, updated_sections)
              |> assign(:editing_section, nil)
              |> assign(:section_edit_mode, false)
              |> assign(:unsaved_changes, false)
              |> put_flash(:info, "Section updated successfully")

            {:noreply, socket}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to save section: #{inspect(changeset.errors)}")}
        end
    end
  end

  @impl true
  def handle_event("cancel_section_edit", _params, socket) do
    socket =
      socket
      |> assign(:editing_section, nil)
      |> assign(:section_edit_mode, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_section_visibility", %{"section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      case Portfolios.update_section(section, %{visible: !section.visible}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          visibility_text = if updated_section.visible, do: "shown", else: "hidden"

          socket = socket
          |> assign(:sections, updated_sections)
          |> put_flash(:info, "Section \"#{updated_section.title}\" is now #{visibility_text}")
          |> assign(:unsaved_changes, false)

          # Broadcast to live preview
          if socket.assigns.show_live_preview do
            Phoenix.PubSub.broadcast(
              Frestyl.PubSub,
              "portfolio_preview:#{socket.assigns.portfolio.id}",
              {:sections_updated, updated_sections}
            )
          end

          {:noreply, socket}

        {:error, changeset} ->
          error_msg = format_changeset_errors(changeset)
          {:noreply, put_flash(socket, :error, "Failed to update visibility: #{error_msg}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("duplicate_section", %{"section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      next_position = length(sections) + 1

      duplicate_attrs = %{
        portfolio_id: section.portfolio_id,
        section_type: section.section_type,
        title: "#{section.title} (Copy)",
        content: section.content,
        visible: false,
        position: next_position
      }

      case Portfolios.create_section(duplicate_attrs) do
        {:ok, new_section} ->
          updated_sections = sections ++ [new_section]

          socket = socket
          |> assign(:sections, updated_sections)
          |> put_flash(:info, "Section duplicated successfully! The copy is hidden by default.")
          |> assign(:unsaved_changes, false)

          {:noreply, socket}

        {:error, changeset} ->
          error_msg = format_changeset_errors(changeset)
          {:noreply, put_flash(socket, :error, "Failed to duplicate section: #{error_msg}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("share_portfolio", _params, socket) do
    portfolio = socket.assigns.portfolio
    share_url = "#{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}"

    socket = socket
    |> assign(:share_url, share_url)
    |> assign(:show_share_modal, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, false)}
  end

  @impl true
  def handle_event("reset_design", _params, socket) do
    default_customization = get_default_customization()

    socket = socket
    |> assign(:customization, default_customization)
    |> assign(:primary_color, default_customization["primary_color"])
    |> assign(:secondary_color, default_customization["secondary_color"])
    |> assign(:accent_color, default_customization["accent_color"])
    |> assign(:background_color, default_customization["background_color"])
    |> assign(:text_color, default_customization["text_color"])
    |> assign(:portfolio_layout, default_customization["layout"])

    if socket.assigns.show_live_preview do
      broadcast_preview_update(socket)
    end

    case save_portfolio_customization(socket.assigns.portfolio.id, default_customization) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Design reset to defaults")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reset design")}
    end
  end

  @impl true
  def handle_event("open_media_library", _params, socket) do
    socket = socket
    |> assign(:show_media_library, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("import_resume", _params, socket) do
    socket = socket
    |> assign(:show_resume_import_modal, true)

    {:noreply, socket}
  end

  @impl true
def handle_event("show_resume_import", _params, socket) do
  {:noreply, assign(socket, :show_resume_import, true)}
end

@impl true
def handle_event("hide_resume_import", _params, socket) do
  {:noreply, assign(socket, :show_resume_import, false)}
end

  @impl true
  def handle_event("add_video_intro", _params, socket) do
    socket = socket
    |> assign(:show_video_intro, true)
    |> assign(:video_intro_editing, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_intro, true)}
  end

  @impl true
  def handle_event("close_media_library", _params, socket) do
    {:noreply, assign(socket, :show_media_library, false)}
  end

  @impl true
  def handle_event("close_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import_modal, false)}
  end

  @impl true
  def handle_event("close_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_intro, false)}
  end

@impl true
def handle_event("reorder_sections", %{"sections" => section_ids}, socket) when is_list(section_ids) do
  sections = socket.assigns.sections

  # Reorder sections based on new order
  ordered_sections = section_ids
  |> Enum.with_index(1)
  |> Enum.map(fn {section_id_str, new_position} ->
    section_id = String.to_integer(section_id_str)
    section = Enum.find(sections, &(&1.id == section_id))

    if section && section.position != new_position do
      case Portfolios.update_section(section, %{position: new_position}) do
        {:ok, updated_section} -> updated_section
        {:error, _} -> section
      end
    else
      section
    end
  end)
  |> Enum.filter(& &1)  # Remove any nils
  |> Enum.sort_by(& &1.position)

  {:noreply, socket
  |> assign(:sections, ordered_sections)
  |> put_flash(:info, "Section order updated")}
end

@impl true
def handle_event("reorder_sections", %{"old_index" => old_index, "new_index" => new_index}, socket) do
  old_idx = String.to_integer(old_index)
  new_idx = String.to_integer(new_index)
  sections = socket.assigns.sections |> Enum.sort_by(& &1.position)

  if old_idx != new_idx and old_idx < length(sections) and new_idx < length(sections) do
    # Reorder the list
    section_to_move = Enum.at(sections, old_idx)
    reordered_sections = sections
    |> List.delete_at(old_idx)
    |> List.insert_at(new_idx, section_to_move)

    # Update positions in database
    updated_sections = reordered_sections
    |> Enum.with_index(1)
    |> Enum.map(fn {section, position} ->
      if section.position != position do
        case Portfolios.update_section(section, %{position: position}) do
          {:ok, updated} -> updated
          {:error, _} -> section
        end
      else
        section
      end
    end)

    {:noreply, socket
    |> assign(:sections, updated_sections)
    |> put_flash(:info, "Section order updated")}
  else
    {:noreply, socket}
  end
end

  @impl true
  def handle_event("save_section", %{"section_id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      # The section should already be saved from content updates
      updated_sections = Enum.map(socket.assigns.sections, fn s ->
        if s.id == section_id_int, do: editing_section, else: s
      end)

      socket = socket
      |> assign(:sections, updated_sections)
      |> assign(:editing_section, editing_section)
      |> assign(:unsaved_changes, false)
      |> put_flash(:info, "Section '#{editing_section.title}' saved successfully!")

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Section not found or not being edited")}
    end
  end

  @impl true
  def handle_event("update_section_field", %{"section_id" => section_id, "field" => field, "value" => value}, socket) do
    IO.puts("🔥 UPDATE SECTION FIELD: section_id=#{section_id}, field=#{field}, value=#{inspect(value)}")

    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section_to_update = Enum.find(sections, &(&1.id == section_id_int))

    if section_to_update do
      # Handle different field types
      update_params = case field do
        "title" ->
          %{title: value}
        "description" ->
          current_content = section_to_update.content || %{}
          updated_content = Map.put(current_content, "description", value)
          %{content: updated_content}
        "headline" ->
          current_content = section_to_update.content || %{}
          updated_content = Map.put(current_content, "headline", value)
          %{content: updated_content}
        "summary" ->
          current_content = section_to_update.content || %{}
          updated_content = Map.put(current_content, "summary", value)
          %{content: updated_content}
        "location" ->
          current_content = section_to_update.content || %{}
          updated_content = Map.put(current_content, "location", value)
          %{content: updated_content}
        "visible" ->
          %{visible: String.to_existing_atom(value)}
        _ ->
          current_content = section_to_update.content || %{}
          updated_content = Map.put(current_content, field, value)
          %{content: updated_content}
      end

      case Portfolios.update_section(section_to_update, update_params) do
        {:ok, updated_section} ->
          IO.puts("✅ Section updated successfully in database")

          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          # Update editing_section if it's the same section
          editing_section = if socket.assigns[:editing_section] &&
                              socket.assigns.editing_section.id == section_id_int do
            updated_section
          else
            socket.assigns[:editing_section]
          end

          # Broadcast to live preview
          if socket.assigns.show_live_preview do
            Phoenix.PubSub.broadcast(
              Frestyl.PubSub,
              "portfolio_preview:#{socket.assigns.portfolio.id}",
              {:sections_updated, updated_sections}
            )
          end

          {:noreply, socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, editing_section)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Section updated successfully")}

        {:error, changeset} ->
          error_msg = format_changeset_errors(changeset)
          {:noreply, put_flash(socket, :error, "Failed to update section: #{error_msg}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_event("update_portfolio_field", %{"field" => "visibility", "value" => visibility}, socket) do
    portfolio = socket.assigns.portfolio

    case Portfolios.update_portfolio_visibility(portfolio.id, visibility, socket.assigns.current_user.id) do
      {:ok, updated_portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "Portfolio visibility updated successfully")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to update this portfolio")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update visibility: #{format_changeset_errors(changeset)}")}
    end
  end

  def handle_event("update_portfolio_field", %{"field" => field, "value" => value}, socket) do
    portfolio = socket.assigns.portfolio
    updates = %{String.to_atom(field) => value}

    case Portfolios.update_portfolio(portfolio, updates) do
      {:ok, updated_portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:unsaved_changes, false)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update #{field}: #{format_changeset_errors(changeset)}")}
    end
  end

  # ============================================================================
  # CUSTOM FIELDS EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("toggle_custom_fields", %{"section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    if section do
      case Portfolios.update_section(section, %{custom_fields_enabled: !section.custom_fields_enabled}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          {:noreply, socket
          |> assign(:sections, updated_sections)
          |> put_flash(:info, "Custom fields #{if updated_section.custom_fields_enabled, do: "enabled", else: "disabled"}")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update custom fields setting")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("manage_custom_fields", %{"section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    if section do
      # Load custom field definitions and values
      field_definitions = Portfolios.list_custom_field_definitions(socket.assigns.portfolio.id)
      field_values = Portfolios.list_custom_field_values(socket.assigns.portfolio.id, section_id_int)

      socket = socket
      |> assign(:show_custom_fields_modal, true)
      |> assign(:custom_fields_section, section)
      |> assign(:custom_field_definitions, field_definitions)
      |> assign(:custom_field_values, field_values)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("close_custom_fields_modal", _params, socket) do
    {:noreply, socket
    |> assign(:show_custom_fields_modal, false)
    |> assign(:custom_fields_section, nil)
    |> assign(:custom_field_definitions, [])
    |> assign(:custom_field_values, [])}
  end

  @impl true
  def handle_event("save_field_values", %{"field_values" => field_values_params}, socket) do
    section = socket.assigns.custom_fields_section
    portfolio_id = socket.assigns.portfolio.id

    results = Enum.map(field_values_params, fn {field_name, value} ->
      # Find or create field value
      existing_value = Enum.find(socket.assigns.custom_field_values, &(&1.field_name == field_name))

      processed_value = process_field_value(field_name, value, socket.assigns.custom_field_definitions)

      attrs = %{
        field_name: field_name,
        value: processed_value,
        value_text: extract_searchable_text(processed_value),
        portfolio_id: portfolio_id,
        section_id: section.id,
        field_definition_id: get_definition_id(field_name, socket.assigns.custom_field_definitions)
      }

      if existing_value do
        Portfolios.update_custom_field_value(existing_value, attrs)
      else
        Portfolios.create_custom_field_value(attrs)
      end
    end)

    case Enum.all?(results, &match?({:ok, _}, &1)) do
      true ->
        # Reload field values
        updated_field_values = Portfolios.list_custom_field_values(portfolio_id, section.id)

        {:noreply, socket
        |> assign(:custom_field_values, updated_field_values)
        |> put_flash(:info, "Custom field values saved successfully!")}

      false ->
        errors = results
        |> Enum.filter(&match?({:error, _}, &1))
        |> Enum.map(fn {:error, changeset} -> format_changeset_errors(changeset) end)
        |> Enum.join(", ")

        {:noreply, put_flash(socket, :error, "Failed to save some values: #{errors}")}
    end
  end

  # Handle custom field events delegated from the component
  @impl true
  def handle_info({:custom_fields_updated, updated_definitions}, socket) do
    {:noreply, assign(socket, :custom_field_definitions, updated_definitions)}
  end

  # Helper functions for custom fields
  defp process_field_value(field_name, value, definitions) do
    case Enum.find(definitions, &(&1.field_name == field_name)) do
      %{field_type: "list"} when is_binary(value) ->
        # Convert comma-separated string to list
        %{"items" => String.split(value, ",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))}

      %{field_type: "object"} when is_binary(value) ->
        # Parse JSON string
        case Jason.decode(value) do
          {:ok, decoded} -> decoded
          {:error, _} -> %{"raw" => value}
        end

      %{field_type: "boolean"} ->
        %{"value" => value == "true"}

      %{field_type: "number"} when is_binary(value) ->
        case Float.parse(value) do
          {num, _} -> %{"value" => num}
          :error -> %{"value" => 0}
        end

      _ ->
        %{"content" => value}
    end
  end

  defp get_definition_id(field_name, definitions) do
    case Enum.find(definitions, &(&1.field_name == field_name)) do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp extract_searchable_text(%{"content" => content}) when is_binary(content), do: content
  defp extract_searchable_text(%{"items" => items}) when is_list(items), do: Enum.join(items, " ")
  defp extract_searchable_text(%{"value" => value}) when is_binary(value), do: value
  defp extract_searchable_text(%{"value" => value}), do: "#{value}"
  defp extract_searchable_text(map) when is_map(map) do
    map
    |> Map.values()
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
  end
  defp extract_searchable_text(_), do: ""

  defp handle_experience_section_change(value, socket) do
    # Handle experience section updates
    case socket.assigns[:editing_section] do
      %{id: section_id} = section ->
        content = section.content || %{}
        updated_content = Map.put(content, "experience_data", value)

        case Portfolios.update_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = Enum.map(socket.assigns.sections, fn s ->
              if s.id == section_id, do: updated_section, else: s
            end)

            {:noreply, socket
            |> assign(:sections, sections)
            |> assign(:editing_section, updated_section)
            |> assign(:unsaved_changes, false)}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update section: #{format_changeset_errors(changeset)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No section currently being edited")}
    end
  end

  defp handle_education_section_change(value, socket) do
    # Similar to experience but for education
    case socket.assigns[:editing_section] do
      %{id: section_id} = section ->
        content = section.content || %{}
        updated_content = Map.put(content, "education_data", value)

        case Portfolios.update_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = Enum.map(socket.assigns.sections, fn s ->
              if s.id == section_id, do: updated_section, else: s
            end)

            {:noreply, socket
            |> assign(:sections, sections)
            |> assign(:editing_section, updated_section)
            |> assign(:unsaved_changes, false)}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update section: #{format_changeset_errors(changeset)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No section currently being edited")}
    end
  end

  defp handle_skills_section_change(value, socket) do
    # Skills section handler
    case socket.assigns[:editing_section] do
      %{id: section_id} = section ->
        content = section.content || %{}
        updated_content = Map.put(content, "skills_data", value)

        case Portfolios.update_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = Enum.map(socket.assigns.sections, fn s ->
              if s.id == section_id, do: updated_section, else: s
            end)

            {:noreply, socket
            |> assign(:sections, sections)
            |> assign(:editing_section, updated_section)
            |> assign(:unsaved_changes, false)}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update section: #{format_changeset_errors(changeset)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No section currently being edited")}
    end
  end

  defp handle_projects_section_change(value, socket) do
    # Projects section handler
    case socket.assigns[:editing_section] do
      %{id: section_id} = section ->
        content = section.content || %{}
        updated_content = Map.put(content, "projects_data", value)

        case Portfolios.update_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = Enum.map(socket.assigns.sections, fn s ->
              if s.id == section_id, do: updated_section, else: s
            end)

            {:noreply, socket
            |> assign(:sections, sections)
            |> assign(:editing_section, updated_section)
            |> assign(:unsaved_changes, false)}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update section: #{format_changeset_errors(changeset)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No section currently being edited")}
    end
  end

  defp handle_custom_section_change(value, socket) do
    # Custom section handler - this is where flexible custom fields will be handled
    case socket.assigns[:editing_section] do
      %{id: section_id} = section ->
        content = section.content || %{}

        # Parse the value as JSON if it's a string, otherwise use as-is
        parsed_value = case value do
          value_string when is_binary(value_string) ->
            case Jason.decode(value_string) do
              {:ok, decoded} -> decoded
              {:error, _} -> %{"raw_content" => value_string}
            end
          value_map when is_map(value_map) -> value_map
          _ -> %{"content" => value}
        end

        updated_content = Map.put(content, "custom_data", parsed_value)

        case Portfolios.update_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = Enum.map(socket.assigns.sections, fn s ->
              if s.id == section_id, do: updated_section, else: s
            end)

            {:noreply, socket
            |> assign(:sections, sections)
            |> assign(:editing_section, updated_section)
            |> assign(:unsaved_changes, false)}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update section: #{format_changeset_errors(changeset)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No section currently being edited")}
    end
  end

  defp get_template_config(template) do
    case template do
      "minimal" -> %{
        name: "Minimal",
        description: "Clean and simple design",
        primary_color: "#374151",
        layout: "single_column"
      }
      "executive" -> %{
        name: "Executive",
        description: "Professional business template",
        primary_color: "#1f2937",
        layout: "structured"
      }
      "creative" -> %{
        name: "Creative",
        description: "Bold and expressive design",
        primary_color: "#7c3aed",
        layout: "grid"
      }
      "developer" -> %{
        name: "Developer",
        description: "Technical portfolio with code focus",
        primary_color: "#059669",
        layout: "terminal"
      }
      _ -> %{
        name: "Default",
        description: "Standard template",
        primary_color: "#6b7280",
        layout: "single_column"
      }
    end
  end

  defp get_default_customization do
    %{
      "layout" => "minimal",
      "primary_color" => "#374151",
      "secondary_color" => "#6b7280",
      "accent_color" => "#059669",
      "background_color" => "#ffffff",
      "text_color" => "#1f2937"
    }
  end

  defp get_user_account_safe(user) do
    try do
      # Try the function that we know exists from project knowledge
      case Frestyl.Accounts.list_user_accounts(user.id) do
        [account | _] ->
          # Ensure subscription_tier is present
          account
          |> Map.put_new(:subscription_tier, "personal")
          |> ensure_subscription_tier_is_string()
        [] ->
          %{subscription_tier: "personal"}
      end
    rescue
      _ ->
        # Fallback: try user's direct fields
        %{
          subscription_tier: get_user_subscription_tier(user)
        }
    end
  end

  # Helper to ensure subscription_tier is a string
  defp ensure_subscription_tier_is_string(account) do
    case Map.get(account, :subscription_tier) do
      tier when is_atom(tier) -> Map.put(account, :subscription_tier, Atom.to_string(tier))
      tier when is_binary(tier) -> account
      _ -> Map.put(account, :subscription_tier, "personal")
    end
  end

  # Helper to get subscription tier from user
  defp get_user_subscription_tier(user) do
    cond do
      Map.has_key?(user, :subscription_tier) && user.subscription_tier ->
        case user.subscription_tier do
          tier when is_atom(tier) -> Atom.to_string(tier)
          tier when is_binary(tier) -> tier
          _ -> "personal"
        end
      Map.has_key?(user, :account) && user.account ->
        get_user_subscription_tier(user.account)
      true ->
        "personal"
    end
  end

  # Add this helper function for safe performance tracking
  defp track_portfolio_editor_load_safe(portfolio_id, load_time) do
    if Code.ensure_loaded?(PortfolioPerformance) do
      PortfolioPerformance.track_portfolio_editor_load(portfolio_id, load_time)
    end
  rescue
    _ -> :ok
  end

  defp assign_core_data(socket, portfolio, account, user) do
    socket
    |> assign(:portfolio, portfolio)
    |> assign(:account, account)
    |> assign(:current_user, user)
    |> assign(:page_title, "Edit #{portfolio.title}")
  end

  defp assign_features_and_limits(socket, features, limits) do
    socket
    |> assign(:features, features)
    |> assign(:limits, limits)
  end

  defp assign_content_data(socket, sections, media_library, content_blocks) do
    socket
    |> assign(:sections, sections)
    |> assign(:media_library, media_library)
    |> assign(:content_blocks, content_blocks)
  end

  defp assign_monetization_data(socket, monetization_data, streaming_config) do
    socket
    |> assign(:monetization_data, monetization_data)
    |> assign(:streaming_config, streaming_config)
  end

  defp assign_design_system(socket, portfolio, account) do
    customization = portfolio.customization || %{}

    # Extract design values with fallbacks
    portfolio_layout = customization["layout"] || "minimal"
    primary_color = customization["primary_color"] || "#374151"
    secondary_color = customization["secondary_color"] || "#6b7280"
    accent_color = customization["accent_color"] || "#059669"
    background_color = customization["background_color"] || "#ffffff"
    text_color = customization["text_color"] || "#1f2937"

    # Get available layouts and brand constraints based on account
    available_layouts = get_available_layouts(account)
    brand_constraints = get_brand_constraints(account)

    socket
    |> assign(:portfolio_layout, portfolio_layout)
    |> assign(:primary_color, primary_color)
    |> assign(:secondary_color, secondary_color)
    |> assign(:accent_color, accent_color)
    |> assign(:background_color, background_color)
    |> assign(:text_color, text_color)
    |> assign(:customization, customization)
    |> assign(:available_layouts, available_layouts)
    |> assign(:brand_constraints, brand_constraints)
    |> assign(:design_tokens, generate_design_tokens(portfolio, brand_constraints))
  end


  defp assign_ui_state(socket) do
    timestamp = System.system_time(:millisecond)

    socket
    |> assign(:active_tab, :overview)
    |> assign(:show_preview, false)
    |> assign(:unsaved_changes, false)
    |> assign(:show_add_section_dropdown, false)
    |> assign(:show_share_modal, false)
    |> assign(:show_media_library, false)
    |> assign(:show_resume_import_modal, false)
    |> assign(:show_video_intro, false)
    |> assign(:show_main_menu, false)
    |> assign(:editing_section, nil)
    |> assign(:section_edit_mode, false)
    |> assign(:pending_changes, %{})
    |> assign(:debounce_timer, nil)
    |> assign(:media_section_id, nil)
    |> assign(:last_updated, timestamp)
    |> assign(:force_render, 0)
    |> assign(:refresh_count, 0)
    |> assign(:current_theme, nil)
    |> assign(:current_layout, nil)
  end

  # ============================================================================
  # ACCOUNT & PERMISSION HELPERS
  # ============================================================================

  defp load_portfolio_with_account_and_blocks(portfolio_id, user) do
    # Use the basic get_portfolio function that definitely exists
    case Portfolios.get_portfolio(portfolio_id) do
      nil ->
        {:error, :not_found}

      portfolio ->
        if can_edit_portfolio?(portfolio, user) do
          # Load account information safely
          accounts = try do
            Frestyl.Accounts.list_user_accounts(user.id)
          rescue
            _ -> []
          end

          account = case accounts do
            [account | _] -> account
            [] -> %{subscription_tier: "personal"}
          end

          # Load content blocks safely
          content_blocks = try do
            load_portfolio_content_blocks(portfolio.id)
          rescue
            _ -> %{}
          end

          {:ok, portfolio, account, content_blocks}
        else
          {:error, :unauthorized}
        end
    end
  end

  defp can_edit_portfolio?(portfolio, user) do
    cond do
      user && portfolio.user_id == user.id -> true
      user && user.role == "admin" -> true
      true -> false
    end
  end

  defp load_portfolio_content_blocks(portfolio_id) do
    try do
      Portfolios.list_portfolio_content_blocks(portfolio_id)
    rescue
      _ -> %{}
    end
  end

  defp get_subscription_tier(account) do
    case account do
      %{subscription_tier: tier} when is_binary(tier) -> tier
      %{subscription_tier: tier} when is_atom(tier) -> Atom.to_string(tier)
      _ -> "personal"
    end
  end

  defp get_subscription_tier(_), do: "personal"

  defp load_content_blocks_by_section(portfolio_id) do
    try do
      # Load portfolio sections with their content
      sections = Portfolios.list_portfolio_sections(portfolio_id)

      # Organize content blocks by section
      Enum.reduce(sections, %{}, fn section, acc ->
        Map.put(acc, section.id, format_content_blocks(section))
      end)
    rescue
      _ -> %{}
    end
  end

  defp format_content_blocks(section) do
    content = section.content || %{}

    # Extract different types of content blocks
    %{
      text_blocks: extract_text_blocks(content),
      media_blocks: extract_media_blocks(content),
      list_blocks: extract_list_blocks(content),
      custom_blocks: extract_custom_blocks(content)
    }
  end

  defp extract_text_blocks(content) do
    [
      %{type: "description", content: content["description"] || ""},
      %{type: "summary", content: content["summary"] || ""},
      %{type: "bio", content: content["bio"] || ""}
    ]
    |> Enum.filter(fn block -> String.length(block.content) > 0 end)
  end

  defp extract_media_blocks(content) do
    content["media_items"] || []
  end

  defp extract_list_blocks(content) do
    %{
      skills: content["skills"] || [],
      achievements: content["achievements"] || [],
      responsibilities: content["responsibilities"] || []
    }
  end

  defp extract_custom_blocks(content) do
    # Handle any custom content structures
    content
    |> Map.drop(["description", "summary", "bio", "media_items", "skills", "achievements", "responsibilities"])
    |> Enum.map(fn {key, value} -> %{type: key, content: value} end)
  end

  defp get_account_features(account) do
    subscription_tier = get_subscription_tier(account)

    case subscription_tier do
      "premium" -> %{
        monetization_enabled: true,
        streaming_enabled: true,
        advanced_analytics: true,
        collaboration: true,
        custom_domains: true
      }
      "professional" -> %{
        monetization_enabled: true,
        streaming_enabled: false,
        advanced_analytics: true,
        collaboration: true,
        custom_domains: false
      }
      "basic" -> %{
        monetization_enabled: false,
        streaming_enabled: false,
        advanced_analytics: false,
        collaboration: false,
        custom_domains: false
      }
      _ -> %{
        monetization_enabled: false,
        streaming_enabled: false,
        advanced_analytics: false,
        collaboration: false,
        custom_domains: false
      }
    end
  end

  defp get_account_limits(account) do
    subscription_tier = get_subscription_tier(account)

    case subscription_tier do
      "premium" -> %{
        max_portfolios: -1,
        max_sections: -1,
        max_media_files: -1,
        max_collaborators: -1
      }
      "professional" -> %{
        max_portfolios: 10,
        max_sections: 50,
        max_media_files: 1000,
        max_collaborators: 5
      }
      "basic" -> %{
        max_portfolios: 3,
        max_sections: 15,
        max_media_files: 100,
        max_collaborators: 1
      }
      _ -> %{
        max_portfolios: 1,
        max_sections: 5,
        max_media_files: 10,
        max_collaborators: 0
      }
    end
  end

  defp get_account_limits(account) do
    subscription_tier = Map.get(account, :subscription_tier, "personal")
    case subscription_tier do
      "enterprise" -> %{max_sections: -1, max_media: -1, max_templates: -1}
      "professional" -> %{max_sections: 20, max_media: 1000, max_templates: -1}
      "creator" -> %{max_sections: 10, max_media: 100, max_templates: 10}
      _ -> %{max_sections: 5, max_media: 50, max_templates: 3}
    end
  end

  defp get_available_layouts(account) do
    subscription_tier = get_subscription_tier(account)

    base_layouts = ["minimal", "executive", "creative"]

    case subscription_tier do
      "premium" -> base_layouts ++ ["developer", "consultant", "academic", "gallery"]
      "professional" -> base_layouts ++ ["developer", "consultant"]
      _ -> base_layouts
    end
  end

  defp get_brand_constraints(account) do
    subscription_tier = get_subscription_tier(account)

    case subscription_tier do
      "premium" -> %{
        primary_colors: ["#1e40af", "#7c3aed", "#059669", "#dc2626", "#ea580c", "#ca8a04"],
        secondary_colors: ["#64748b", "#6b7280", "#9ca3af"],
        accent_colors: ["#f59e0b", "#ef4444", "#8b5cf6", "#06b6d4"],
        allowed_fonts: ["Inter", "Merriweather", "JetBrains Mono", "Playfair Display", "Source Sans Pro"],
        font_size_scale: %{min: 0.75, max: 3.0},
        max_sections: -1,
        spacing_scale: [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4, 6],
        enforce_brand: false,
        brand_locked_elements: []
      }

      "professional" -> %{
        primary_colors: ["#1e40af", "#7c3aed", "#059669", "#dc2626"],
        secondary_colors: ["#64748b", "#6b7280", "#9ca3af"],
        accent_colors: ["#f59e0b", "#ef4444", "#8b5cf6"],
        allowed_fonts: ["Inter", "Merriweather", "JetBrains Mono"],
        font_size_scale: %{min: 0.875, max: 2.5},
        max_sections: 50,
        spacing_scale: [0.5, 1, 1.5, 2, 3, 4],
        enforce_brand: false,
        brand_locked_elements: []
      }

      _ -> %{
        primary_colors: ["#374151", "#1f2937"],
        secondary_colors: ["#64748b", "#6b7280"],
        accent_colors: ["#059669", "#3b82f6"],
        allowed_fonts: ["Inter"],
        font_size_scale: %{min: 0.875, max: 2.0},
        max_sections: 10,
        spacing_scale: [0.5, 1, 1.5, 2],
        enforce_brand: false,
        brand_locked_elements: []
      }
    end
  end

  def handle_info(:save_pending_changes, socket) do
    case Map.get(socket.assigns, :pending_changes) do
      changes when map_size(changes) > 0 ->
        portfolio = socket.assigns.portfolio
        current_customization = Map.get(portfolio, :customization, %{})
        updated_customization = Map.merge(current_customization, changes)

        case Portfolios.update_portfolio_customization(portfolio, updated_customization) do
          {:ok, updated_portfolio} ->
            css = generate_live_preview_css(updated_customization, portfolio.theme)

            Phoenix.PubSub.broadcast(
              Frestyl.PubSub,
              "portfolio_preview:#{portfolio.id}",
              {:preview_update, updated_customization, css}
            )

            socket =
              socket
              |> assign(:portfolio, updated_portfolio)
              |> assign(:customization, updated_customization)
              |> assign(:pending_changes, %{})
              |> assign(:debounce_timer, nil)
              |> assign(:unsaved_changes, false)

            {:noreply, socket}

          {:error, _changeset} ->
            socket =
              socket
              |> assign(:debounce_timer, nil)
              |> put_flash(:error, "Failed to save changes")

            {:noreply, socket}
        end

      _ ->
        {:noreply, assign(socket, :debounce_timer, nil)}
    end
  end

  @impl true
  def handle_info({:close_video_intro_modal}, socket) do
    {:noreply, assign(socket, :show_video_intro, false)}
  end

  @impl true
  def handle_info({:video_intro_complete, video_section}, socket) do
    # Reload sections to include the new video intro
    updated_sections = load_portfolio_sections(socket.assigns.portfolio.id)

    socket =
      socket
      |> assign(:show_video_intro, false)
      |> assign(:sections, updated_sections)
      |> put_flash(:info, "Video introduction added successfully!")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:close_modal, :resume_import}, socket) do
    {:noreply, assign(socket, :show_resume_import, false)}
  end

  @impl true
  def handle_info({:portfolio_updated, updated_portfolio}, socket) do
    # Handle real-time updates from resume import
    {:noreply,
    socket
    |> assign(:portfolio, updated_portfolio)
    |> assign(:unsaved_changes, false)}
  end

    @impl true
  def render(assigns) do
    ~H"""
    <div class="portfolio-editor-container">
      <!-- Editor Header -->
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Edit Portfolio</h1>
          <p class="text-gray-600 mt-2">Customize your portfolio content and sections</p>
        </div>

        <div class="flex items-center space-x-4">
          <!-- Unsaved Changes Indicator -->
          <div :if={@unsaved_changes} class="flex items-center text-amber-600">
            <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
            </svg>
            Unsaved changes
          </div>

          <!-- Resume Import Button -->
          <button
            phx-click="show-resume-import"
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-blue-700 bg-blue-100 border border-blue-300 rounded-md hover:bg-blue-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10"></path>
            </svg>
            Import Resume
          </button>

          <!-- Preview Button -->
          <.link
            navigate={~p"/portfolio/#{@portfolio}"}
            target="_blank"
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
            </svg>
            Preview
          </.link>

          <!-- Save Button -->
          <button
            phx-click="save-portfolio"
            disabled={!@unsaved_changes}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-400 disabled:cursor-not-allowed"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"></path>
            </svg>
            Save Changes
          </button>
        </div>
      </div>

      <!-- Editor Layout -->
      <div class="grid grid-cols-1 lg:grid-cols-4 gap-8">
        <!-- Sidebar Navigation -->
        <div class="lg:col-span-1">
          <nav class="space-y-2">
            <button
              :for={{section_key, section_info} <- get_editor_sections()}
              phx-click="change-section"
              phx-value-section={section_key}
              class={[
                "w-full text-left px-4 py-3 rounded-lg text-sm font-medium transition-colors",
                if(@active_section == section_key,
                  do: "bg-blue-100 text-blue-700 border border-blue-300",
                  else: "text-gray-700 hover:bg-gray-100")
              ]}
            >
              <div class="flex items-center">
                <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <%= render_section_icon(section_info.icon) %>
                </svg>
                {section_info.title}
              </div>
            </button>
          </nav>
        </div>

        <!-- Main Editor Content -->
        <div class="lg:col-span-3">
          <div class="bg-white rounded-lg shadow-sm border border-gray-200">
            <!-- Section Content -->
            <div class="p-6">
              <%= render_editor_section(assigns) %>
            </div>
          </div>
        </div>
      </div>

      <!-- Resume Import Modal -->
      <div :if={@show_resume_import}>
        <.live_component
          module={ResumeImportModal}
          id="resume-import-modal"
          portfolio={@portfolio}
        />
      </div>

      <!-- Auto-save indicator -->
      <div class="fixed bottom-4 right-4 z-40">
        <div :if={@unsaved_changes} class="bg-white border border-gray-300 rounded-lg shadow-lg p-3">
          <div class="flex items-center text-sm text-gray-600">
            <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Unsaved changes
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_editor_sections do
    %{
      "basic_info" => %{title: "Basic Information", icon: "user"},
      "contact" => %{title: "Contact Details", icon: "mail"},
      "summary" => %{title: "Professional Summary", icon: "document-text"},
      "experience" => %{title: "Work Experience", icon: "briefcase"},
      "education" => %{title: "Education", icon: "academic-cap"},
      "skills" => %{title: "Skills", icon: "chip"},
      "projects" => %{title: "Projects", icon: "code-bracket"},
      "settings" => %{title: "Portfolio Settings", icon: "cog"}
    }
  end

    defp render_section_icon(icon_name) do
    case icon_name do
      "user" ->
        raw("""
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
        """)

      "mail" ->
        raw("""
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
        """)

      "document-text" ->
        raw("""
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
        """)

      "briefcase" ->
        raw("""
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0H8m8 0v2a2 2 0 002 2h2a2 2 0 002-2V8a2 2 0 00-2-2h-2z"></path>
        """)

      "academic-cap" ->
        raw("""
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5z M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z"></path>
        """)

      "chip" ->
        raw("""
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
        """)

      "code-bracket" ->
        raw("""
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 16.5"></path>
        """)

      "cog" ->
        raw("""
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.343 3.94c.09-.542.56-.94 1.11-.94h1.093c.55 0 1.02.398 1.11.94l.149.894c.07.424.384.764.78.93.398.164.855.142 1.205-.108l.737-.527a1.125 1.125 0 011.45.12l.773.774c.39.389.44 1.002.12 1.45l-.527.737c-.25.35-.272.806-.107 1.204.165.397.505.71.93.78l.893.15c.543.09.94.56.94 1.109v1.094c0 .55-.397 1.02-.94 1.11l-.893.149c-.425.07-.765.383-.93.78-.165.398-.143.854.107 1.204l.527.738c.32.447.269 1.06-.12 1.45l-.774.773a1.125 1.125 0 01-1.449.12l-.738-.527c-.35-.25-.806-.272-1.203-.107-.397.165-.71.505-.781.929l-.149.894c-.09.542-.56.94-1.11.94h-1.094c-.55 0-1.019-.398-1.11-.94l-.148-.894c-.071-.424-.384-.764-.781-.93-.398-.164-.854-.142-1.204.108l-.738.527c-.447.32-1.06.269-1.45-.12l-.773-.774a1.125 1.125 0 01-.12-1.45l.527-.737c.25-.35.273-.806.108-1.204-.165-.397-.505-.71-.93-.78l-.894-.15c-.542-.09-.94-.56-.94-1.109v-1.094c0-.55.398-1.02.94-1.11l.894-.149c.424-.07.765-.383.93-.78.165-.398.143-.854-.107-1.204l-.527-.738a1.125 1.125 0 01.12-1.45l.773-.773a1.125 1.125 0 011.45-.12l.737.527c.35.25.807.272 1.204.107.397-.165.71-.505.78-.929l.15-.894z M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
        """)

      _ ->
        raw("""
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path>
        """)
    end
  end

  defp render_editor_section(assigns) do
    case assigns.active_section do
      "basic_info" -> render_basic_info_section(assigns)
      "contact" -> render_contact_section(assigns)
      "summary" -> render_summary_section(assigns)
      "experience" -> render_experience_section(assigns)
      "education" -> render_education_section(assigns)
      "skills" -> render_skills_section(assigns)
      "projects" -> render_projects_section(assigns)
      "settings" -> render_settings_section(assigns)
      "custom" -> render_custom_section(assigns)
      _ -> render_basic_info_section(assigns)
    end
  end

  defp render_contact_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-medium text-gray-900 mb-4">Contact Information</h3>
        <p class="text-sm text-gray-600 mb-6">
          Add your contact details so potential employers and collaborators can reach you.
        </p>
      </div>

      <form phx-change="portfolio-changed" phx-submit="save-portfolio">
        <div class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label for="contact_email" class="block text-sm font-medium text-gray-700">
                Email Address
              </label>
              <div class="mt-1">
                <input
                  type="email"
                  name="portfolio[contact_email]"
                  id="contact_email"
                  value={@portfolio.contact_email}
                  class="shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md"
                  placeholder="your.email@example.com"
                />
              </div>
            </div>

            <div>
              <label for="contact_phone" class="block text-sm font-medium text-gray-700">
                Phone Number
              </label>
              <div class="mt-1">
                <input
                  type="tel"
                  name="portfolio[contact_phone]"
                  id="contact_phone"
                  value={@portfolio.contact_phone}
                  class="shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md"
                  placeholder="+1 (555) 123-4567"
                />
              </div>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label for="linkedin_url" class="block text-sm font-medium text-gray-700">
                LinkedIn Profile
              </label>
              <div class="mt-1">
                <input
                  type="url"
                  name="portfolio[linkedin_url]"
                  id="linkedin_url"
                  value={@portfolio.linkedin_url}
                  class="shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md"
                  placeholder="https://linkedin.com/in/yourprofile"
                />
              </div>
            </div>

            <div>
              <label for="github_url" class="block text-sm font-medium text-gray-700">
                GitHub Profile
              </label>
              <div class="mt-1">
                <input
                  type="url"
                  name="portfolio[github_url]"
                  id="github_url"
                  value={@portfolio.github_url}
                  class="shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md"
                  placeholder="https://github.com/yourusername"
                />
              </div>
            </div>
          </div>

          <div>
            <label for="location" class="block text-sm font-medium text-gray-700">
              Location
            </label>
            <div class="mt-1">
              <input
                type="text"
                name="portfolio[location]"
                id="location"
                value={@portfolio.location}
                class="shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md"
                placeholder="City, State/Country"
              />
            </div>
          </div>

          <div class="flex items-center">
            <input
              id="contact_visible"
              name="portfolio[contact_visible]"
              type="checkbox"
              checked={@portfolio.contact_visible}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <label for="contact_visible" class="ml-2 block text-sm text-gray-700">
              Show contact information on portfolio
            </label>
          </div>
        </div>
      </form>
    </div>
    """
  end

  defp render_summary_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-medium text-gray-900 mb-4">Professional Summary</h3>
        <p class="text-sm text-gray-600 mb-6">
          Write a compelling summary that highlights your key skills, experience, and career objectives.
        </p>
      </div>

      <form phx-change="portfolio-changed" phx-submit="save-portfolio">
        <div class="space-y-6">
          <div>
            <label for="summary" class="block text-sm font-medium text-gray-700">
              Summary
            </label>
            <div class="mt-1">
              <textarea
                name="portfolio[summary]"
                id="summary"
                rows="6"
                class="shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md"
                placeholder="Write a brief professional summary that highlights your key skills, experience, and what you're looking for in your next role..."
              >{@portfolio.summary}</textarea>
            </div>
            <p class="mt-2 text-sm text-gray-500">
              Aim for 2-3 sentences that capture your professional essence
            </p>
          </div>

          <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-blue-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <h4 class="text-sm font-medium text-blue-800">
                  Tips for a great summary:
                </h4>
                <div class="mt-2 text-sm text-blue-700">
                  <ul class="list-disc pl-5 space-y-1">
                    <li>Start with your current role or years of experience</li>
                    <li>Mention 2-3 key technical skills or areas of expertise</li>
                    <li>Include what type of opportunities you're seeking</li>
                    <li>Keep it concise but impactful</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </div>
      </form>
    </div>
    """
  end

  # Placeholder functions for other sections - implement based on your portfolio schema
  defp render_experience_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-medium text-gray-900 mb-4">Work Experience</h3>
        <p class="text-sm text-gray-600 mb-6">
          Add your professional experience, including job titles, companies, and key achievements.
        </p>
      </div>

      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
          <path d="M34 40h10v-4a6 6 0 00-10.712-3.714M34 40H14m20 0v-4a9.971 9.971 0 00-.712-3.714M14 40H4v-4a6 6 0 0110.713-3.714M14 40v-4c0-1.313.253-2.566.713-3.714m0 0A9.971 9.971 0 0124 24c4.004 0 7.625 2.371 9.287 6m-9.287-6H4l5.35-5.35C6.788 15.944 4.639 12.207 4 8h40c-.639 4.207-2.788 7.944-5.35 10.65L44 24H24z" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No experience added yet</h3>
        <p class="mt-1 text-sm text-gray-500">Get started by adding your first work experience.</p>
        <div class="mt-6">
          <button type="button" class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700">
            Add Experience
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp render_education_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-medium text-gray-900 mb-4">Education</h3>
        <p class="text-sm text-gray-600 mb-6">
          Add your educational background including degrees, certifications, and relevant coursework.
        </p>
      </div>

      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
          <path d="M12 14l9-5 9 5M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No education added yet</h3>
        <p class="mt-1 text-sm text-gray-500">Add your educational background and qualifications.</p>
        <div class="mt-6">
          <button type="button" class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700">
            Add Education
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp render_skills_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-medium text-gray-900 mb-4">Skills</h3>
        <p class="text-sm text-gray-600 mb-6">
          Showcase your technical and professional skills. Organize them by categories for better presentation.
        </p>
      </div>

      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
          <path d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No skills added yet</h3>
        <p class="mt-1 text-sm text-gray-500">Add your technical and professional skills.</p>
        <div class="mt-6">
          <button type="button" class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700">
            Add Skills
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp render_projects_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-medium text-gray-900 mb-4">Projects</h3>
        <p class="text-sm text-gray-600 mb-6">
          Showcase your best work including personal projects, open source contributions, and professional achievements.
        </p>
      </div>

      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
          <path d="M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 16.5" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No projects added yet</h3>
        <p class="mt-1 text-sm text-gray-500">Showcase your work and achievements.</p>
        <div class="mt-6">
          <button type="button" class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700">
            Add Project
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp render_settings_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-medium text-gray-900 mb-4">Portfolio Settings</h3>
        <p class="text-sm text-gray-600 mb-6">
          Configure advanced settings for your portfolio including themes, SEO, and sharing options.
        </p>
      </div>

      <form phx-change="portfolio-changed" phx-submit="save-portfolio">
        <div class="space-y-8">
          <!-- Theme Settings -->
          <div>
            <h4 class="text-base font-medium text-gray-900 mb-4">Theme & Appearance</h4>
            <div class="grid grid-cols-3 gap-4">
              <div class="border-2 border-gray-200 rounded-lg p-4 cursor-pointer hover:border-blue-500">
                <div class="w-full h-20 bg-gradient-to-r from-blue-500 to-purple-600 rounded mb-2"></div>
                <p class="text-sm font-medium text-center">Modern</p>
              </div>
              <div class="border-2 border-blue-500 rounded-lg p-4 cursor-pointer">
                <div class="w-full h-20 bg-white border rounded mb-2"></div>
                <p class="text-sm font-medium text-center">Minimal</p>
              </div>
              <div class="border-2 border-gray-200 rounded-lg p-4 cursor-pointer hover:border-blue-500">
                <div class="w-full h-20 bg-gradient-to-r from-gray-800 to-gray-900 rounded mb-2"></div>
                <p class="text-sm font-medium text-center">Dark</p>
              </div>
            </div>
          </div>

          <!-- SEO Settings -->
          <div>
            <h4 class="text-base font-medium text-gray-900 mb-4">SEO & Meta</h4>
            <div class="space-y-4">
              <div>
                <label for="meta_description" class="block text-sm font-medium text-gray-700">
                  Meta Description
                </label>
                <div class="mt-1">
                  <textarea
                    name="portfolio[meta_description]"
                    id="meta_description"
                    rows="3"
                    class="shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md"
                    placeholder="A brief description of your portfolio for search engines..."
                  >{@portfolio.meta_description}</textarea>
                </div>
                <p class="mt-2 text-sm text-gray-500">
                  Recommended length: 150-160 characters
                </p>
              </div>

              <div>
                <label for="keywords" class="block text-sm font-medium text-gray-700">
                  Keywords
                </label>
                <div class="mt-1">
                  <input
                    type="text"
                    name="portfolio[keywords]"
                    id="keywords"
                    value={@portfolio.keywords}
                    class="shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md"
                    placeholder="software engineer, react, javascript, full-stack"
                  />
                </div>
                <p class="mt-2 text-sm text-gray-500">
                  Separate keywords with commas
                </p>
              </div>
            </div>
          </div>

          <!-- Analytics -->
          <div>
            <h4 class="text-base font-medium text-gray-900 mb-4">Analytics</h4>
            <div class="flex items-center">
              <input
                id="analytics_enabled"
                name="portfolio[analytics_enabled]"
                type="checkbox"
                checked={@portfolio.analytics_enabled}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label for="analytics_enabled" class="ml-2 block text-sm text-gray-700">
                Enable portfolio analytics
              </label>
            </div>
            <p class="mt-2 text-sm text-gray-500">
              Track visits, popular sections, and user engagement
            </p>
          </div>
        </div>
      </form>
    </div>
    """
  end

  defp render_custom_section(assigns) do
    content = assigns.content || %{}
    custom_data = Map.get(content, "custom_data", %{})

    # Load custom field definitions and values if available
    field_definitions = if assigns[:field_definitions] do
      assigns.field_definitions
    else
      []
    end

    field_values = if assigns[:field_values] do
      assigns.field_values
    else
      []
    end

    assigns = assign(assigns, :custom_data, custom_data)
    assigns = assign(assigns, :field_definitions, field_definitions)
    assigns = assign(assigns, :field_values, field_values)

    ~H"""
    <div class="custom-section">
      <!-- Basic Content -->
      <%= if Map.get(@content, "title") do %>
        <h3 class="text-xl font-bold text-gray-900 mb-4"><%= Map.get(@content, "title") %></h3>
      <% end %>

      <%= if Map.get(@content, "content") do %>
        <div class="prose prose-sm max-w-none mb-6">
          <%= raw Map.get(@content, "content") %>
        </div>
      <% end %>

      <!-- Custom Fields Display -->
      <%= if Enum.any?(@field_values) do %>
        <div class="custom-fields-display space-y-4">
          <%= for field_value <- @field_values do %>
            <%= if field_value.field_definition && field_value.field_definition.is_public do %>
              <div class="custom-field-item">
                <dt class="text-sm font-medium text-gray-700 mb-1">
                  <%= field_value.field_definition.field_label %>
                </dt>
                <dd class="text-sm text-gray-900">
                  <%= render_custom_field_value(field_value) %>
                </dd>
              </div>
            <% end %>
          <% end %>
        </div>
      <% end %>

      <!-- Fallback Content -->
      <%= if Enum.empty?(@field_values) && !Map.get(@content, "content") do %>
        <%= render_empty_state("puzzle-piece", "Custom section", "Custom content will appear here") %>
      <% end %>
    </div>
    """
  end

  # Helper function to render custom field values
  defp render_custom_field_value(field_value) do
    case field_value.field_definition.field_type do
      "url" ->
        case field_value.value do
          %{"content" => url} when is_binary(url) and url != "" ->
            Phoenix.HTML.raw(~s(<a href="#{url}" target="_blank" class="text-blue-600 hover:text-blue-700 underline">#{url}</a>))
          _ -> ""
        end

      "email" ->
        case field_value.value do
          %{"content" => email} when is_binary(email) and email != "" ->
            Phoenix.HTML.raw(~s(<a href="mailto:#{email}" class="text-blue-600 hover:text-blue-700">#{email}</a>))
          _ -> ""
        end

      "list" ->
        case field_value.value do
          %{"items" => items} when is_list(items) ->
            items
            |> Enum.join(", ")
            |> Phoenix.HTML.html_escape()
          _ -> ""
        end

      "boolean" ->
        case field_value.value do
          %{"value" => true} -> "Yes"
          %{"value" => false} -> "No"
          _ -> ""
        end

      "date" ->
        case field_value.value do
          %{"content" => date_string} when is_binary(date_string) ->
            case Date.from_iso8601(date_string) do
              {:ok, date} -> Calendar.strftime(date, "%B %d, %Y")
              _ -> date_string
            end
          _ -> ""
        end

      "object" ->
        case field_value.value do
          map when is_map(map) ->
            map
            |> Jason.encode!(pretty: true)
            |> Phoenix.HTML.raw()
            |> then(fn content -> Phoenix.HTML.raw("<pre class=\"bg-gray-100 p-2 rounded text-xs overflow-x-auto\">#{content}</pre>") end)
          _ -> ""
        end

      _ ->
        # Default text rendering
        case field_value.value do
          %{"content" => content} when is_binary(content) -> Phoenix.HTML.html_escape(content)
          %{"value" => value} -> Phoenix.HTML.html_escape("#{value}")
          _ -> ""
        end
    end
  end

  defp render_empty_state(icon, title, description) do
    Phoenix.HTML.raw("""
    <div class="text-center py-12 bg-gray-50 rounded-xl border-2 border-dashed border-gray-300">
      <div class="w-16 h-16 bg-gray-200 rounded-xl flex items-center justify-center mx-auto mb-4">
        #{get_icon_svg(icon)}
      </div>
      <h3 class="text-lg font-medium text-gray-900 mb-2">#{Phoenix.HTML.html_escape(title)}</h3>
      <p class="text-gray-600 max-w-sm mx-auto">
        #{Phoenix.HTML.html_escape(description)}
      </p>
    </div>
    """)
  end

  # Helper function to get SVG icons
  defp get_icon_svg("puzzle-piece") do
    """
    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 4a2 2 0 114 0v1a1 1 0 001 1h3a1 1 0 011 1v3a1 1 0 01-1 1h-1a2 2 0 100 4h1a1 1 0 011 1v3a1 1 0 01-1 1h-3a1 1 0 01-1-1v-1a2 2 0 10-4 0v1a1 1 0 01-1 1H7a1 1 0 01-1-1v-3a1 1 0 00-1-1H4a1 1 0 01-1-1V9a1 1 0 011-1h1a2 2 0 100-4H4a1 1 0 01-1-1V4a1 1 0 011-1h3a1 1 0 001-1v1z"/>
    </svg>
    """
  end

  defp get_icon_svg("briefcase") do
    """
    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H6a2 2 0 01-2-2V8a2 2 0 012-2V6z"/>
    </svg>
    """
  end

  defp get_icon_svg("academic-cap") do
    """
    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5z"/>
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z"/>
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5zm0 0l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z"/>
    </svg>
    """
  end

  defp get_icon_svg("star") do
    """
    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
    </svg>
    """
  end

  defp get_icon_svg("code") do
    """
    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"/>
    </svg>
    """
  end

  defp get_icon_svg("photograph") do
    """
    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
    </svg>
    """
  end

  # Fallback icon for unknown types
  defp get_icon_svg(_) do
    """
    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
    </svg>
    """
  end

  # ============================================================================
  # MONETIZATION & STREAMING FOUNDATION
  # ============================================================================

  defp load_monetization_data(portfolio, account) do
    if get_account_features(account).monetization_enabled do
      %{
        services: load_portfolio_services(portfolio.id),
        pricing: load_portfolio_pricing(portfolio.id),
        calendar: load_booking_calendar(portfolio.id),
        analytics: load_revenue_analytics(portfolio.id),
        payment_config: load_payment_config(portfolio.id)
      }
    else
      %{
        services: [],
        pricing: %{},
        calendar: %{},
        analytics: %{},
        payment_config: %{}
      }
    end
  end

  defp load_streaming_config(portfolio, account) do
    if get_account_features(account).streaming_enabled do
      %{
        streaming_key: generate_streaming_key(portfolio.id),
        scheduled_streams: load_scheduled_streams(portfolio.id),
        stream_analytics: load_stream_analytics(portfolio.id),
        rtmp_config: load_rtmp_config(portfolio.id)
      }
    else
      %{
        streaming_key: nil,
        scheduled_streams: [],
        stream_analytics: %{},
        rtmp_config: %{}
      }
    end
  end

  defp get_monetization_features_for_tier(subscription_tier) do
    case subscription_tier do
      "personal" -> [:tip_jar]
      "creator" -> [:tip_jar, :booking_fees, :digital_products]
      "creator_plus" -> [:tip_jar, :booking_fees, :digital_products, :subscription_content, :commission_free]
      _ -> []
    end
  end

  defp get_portfolio_revenue_streams(_portfolio_id) do
    # Stub - implement based on your revenue system
    []
  end

  defp get_account_payment_methods(_account_id) do
    # Stub - implement based on your payment system
    []
  end

  defp calculate_portfolio_earnings(_portfolio_id) do
    # Stub - implement based on your earnings system
    %{total: 0, this_month: 0}
  end

  defp get_payout_schedule(_account_id) do
    # Stub - implement based on your payout system
    nil
  end

  defp get_commission_rate(subscription_tier) do
    case subscription_tier do
      "personal" -> 0.15  # 15% commission
      "creator" -> 0.10   # 10% commission
      "creator_plus" -> 0.0  # No commission
      _ -> 0.15
    end
  end


  # ============================================================================
  # BRAND CONTROL SYSTEM
  # ============================================================================

  defp get_default_brand_constraints do
    %{
      # Ready for brand enforcement
      primary_colors: ["#1e40af", "#7c3aed", "#059669", "#dc2626"], # Can be locked to single brand color
      secondary_colors: ["#64748b", "#6b7280", "#9ca3af"],
      accent_colors: ["#f59e0b", "#ef4444", "#8b5cf6", "#06b6d4"],

      # Typography constraints
      allowed_fonts: ["Inter", "Merriweather", "JetBrains Mono"],
      font_size_scale: %{min: 0.875, max: 2.25},

      # Layout constraints
      max_sections: 20,
      spacing_scale: [0.5, 1, 1.5, 2, 3, 4],

      # Future brand enforcement hook
      enforce_brand: false, # Can be flipped to true
      brand_locked_elements: [] # Can include ["primary_color", "typography", "layout"]
    }
  end

  defp generate_design_tokens(portfolio, brand_constraints) do
    customization = portfolio.customization || %{}

    %{
      # Color tokens (brand-controllable)
      primary: get_constrained_color(customization["primary_color"], brand_constraints.primary_colors),
      secondary: get_constrained_color(customization["secondary_color"], brand_constraints.secondary_colors),
      accent: get_constrained_color(customization["accent_color"], brand_constraints.accent_colors),

      # Typography tokens
      font_family: get_constrained_font(customization["font_family"], brand_constraints.allowed_fonts),
      font_scale: brand_constraints.font_size_scale,

      # Layout tokens
      spacing_scale: brand_constraints.spacing_scale,
      max_width: "1200px",

      # Component tokens
      border_radius: "0.5rem",
      shadow_scale: ["sm", "md", "lg", "xl"]
    }
  end

  defp get_constrained_color(user_color, allowed_colors) do
    if user_color in allowed_colors do
      user_color
    else
      List.first(allowed_colors)
    end
  end

  defp get_constrained_font(user_font, allowed_fonts) do
    if user_font in allowed_fonts do
      user_font
    else
      List.first(allowed_fonts)
    end
  end

  # ============================================================================
  # UNIFIED EVENT HANDLING
  # ============================================================================

  def debug_portfolio_customization(portfolio_id) do
    case Portfolios.get_portfolio(portfolio_id) do
      nil -> IO.inspect("Portfolio not found")
      portfolio ->
        IO.inspect(portfolio.customization, label: "📊 Database customization")
        IO.inspect(portfolio.theme, label: "📊 Database theme")
    end
  end

  defp save_portfolio_customization(portfolio_id, customization) do
    case Portfolios.get_portfolio(portfolio_id) do
      nil ->
        {:error, :not_found}

      portfolio ->
        Portfolios.update_portfolio(portfolio, %{customization: customization})
    end
  end

  defp track_portfolio_editor_load_safe(portfolio_id, load_time) do
    if Code.ensure_loaded?(PortfolioPerformance) do
      PortfolioPerformance.track_portfolio_editor_load(portfolio_id, load_time)
    end
  rescue
    _ -> :ok
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    IO.inspect(tab, label: "📋 Tab changed to")
    IO.inspect(socket.assigns.customization, label: "📋 Customization when changing tab")

    tab_atom = String.to_atom(tab)
    {:noreply, assign(socket, :active_tab, tab_atom)}
  end

  @impl true
  def handle_event("change-section", %{"section" => tab, "value" => _value}, socket) do
    IO.puts("🔧 PORTFOLIO_EDITOR: Switching to tab: #{tab}")
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end


  @impl true
  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, !socket.assigns[:show_preview])}
  end

  @impl true
  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, false)}
  end

  @impl true
  def handle_event("update_title", %{"value" => title}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{title: title}) do
      {:ok, portfolio} ->
        {:noreply, socket |> assign(:portfolio, portfolio) |> assign(:unsaved_changes, false)}
      {:error, _} ->
        {:noreply, socket |> assign(:unsaved_changes, true)}
    end
  end

  @impl true
  def handle_event("update_description", %{"value" => description}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{description: description}) do
      {:ok, portfolio} ->
        {:noreply, socket |> assign(:portfolio, portfolio) |> assign(:unsaved_changes, false)}
      {:error, _} ->
        {:noreply, socket |> assign(:unsaved_changes, true)}
    end
  end

  @impl true
  def handle_event("update_visibility", %{"value" => visibility}, socket) do
    visibility_atom = String.to_atom(visibility)
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{visibility: visibility_atom}) do
      {:ok, portfolio} ->
        {:noreply, socket |> assign(:portfolio, portfolio) |> assign(:unsaved_changes, false)}
      {:error, _} ->
        {:noreply, socket |> assign(:unsaved_changes, true)}
    end
  end

  @impl true
  def handle_event("update_color", %{"field" => field, "value" => color}, socket) do
    IO.puts("🎨 UPDATE COLOR (immediate): #{field} = #{color}")

    # Get current customization and update immediately
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, field, color)

    # IMMEDIATE UI update first (prevents reversion)
    socket = socket
    |> assign(:customization, updated_customization)
    |> assign(:unsaved_changes, true)

    # Update individual color assigns for immediate UI feedback
    socket = case field do
      "primary_color" -> assign(socket, :primary_color, color)
      "accent_color" -> assign(socket, :accent_color, color)
      "secondary_color" -> assign(socket, :secondary_color, color)
      _ -> socket
    end

    # IMMEDIATE database save (no debouncing for colors to prevent reversion)
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        IO.puts("✅ Color saved to database immediately")

        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:unsaved_changes, false)

        # IMMEDIATE live preview update
        if socket.assigns.show_live_preview do
          css = generate_simple_preview_css(updated_customization, updated_portfolio.theme)

          IO.puts("🔥 BROADCASTING COLOR UPDATE...")
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "portfolio_preview:#{socket.assigns.portfolio.id}",
            {:preview_update, updated_customization, css}
          )
        end

        {:noreply, socket}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        IO.puts("❌ Failed to save color: #{error_msg}")
        {:noreply, put_flash(socket, :error, "Failed to save color: #{error_msg}")}
    end
  end

  @impl true
  def handle_event("update_layout", %{"value" => layout_value}, socket) do
    IO.puts("🎨 UPDATE LAYOUT (debounced): #{layout_value}")

    # Store pending changes
    pending_changes = Map.put(socket.assigns[:pending_changes] || %{}, "layout", layout_value)
    socket = assign(socket, :pending_changes, pending_changes)

    # Cancel existing timer
    if socket.assigns[:debounce_timer] do
      Process.cancel_timer(socket.assigns.debounce_timer)
    end

    # Set new debounce timer
    timer = Process.send_after(self(), :save_pending_changes, 300)
    socket = assign(socket, :debounce_timer, timer)

    # Immediate UI update (optimistic)
    updated_customization = Map.merge(socket.assigns.customization || %{}, pending_changes)

    socket = socket
    |> assign(:customization, updated_customization)
    |> assign(:portfolio_layout, layout_value)
    |> assign(:unsaved_changes, true)

    # Broadcast to live preview immediately
    if socket.assigns.show_live_preview do
      css = generate_simple_preview_css(updated_customization, socket.assigns.portfolio.theme)

      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "portfolio_preview:#{socket.assigns.portfolio.id}",
        {:preview_update, updated_customization, css}
      )
    end

    {:noreply, socket}
  end


  # Add placeholder handlers for other events

  @impl true
  def handle_event("publish_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :info, "Portfolio published successfully!")}
  end

  @impl true
  def handle_event("delete_portfolio", _params, socket) do
    case Portfolios.delete_portfolio(socket.assigns.portfolio) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Portfolio deleted") |> redirect(to: "/portfolios")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete portfolio")}
    end
  end

  @impl true
  def handle_event("update_section", params, socket) do
    case update_section_content(params, socket) do
      {:ok, updated_socket} ->
        {:noreply, updated_socket |> assign(:unsaved_changes, false)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update section: #{format_errors(changeset)}")}
    end
  end

  @impl true
  def handle_event("delete_section", %{"section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section_to_delete = Enum.find(sections, &(&1.id == section_id_int))

    if section_to_delete do
      case Portfolios.delete_section(section_to_delete) do
        {:ok, _deleted_section} ->
          updated_sections = Enum.reject(sections, &(&1.id == section_id_int))

          # Reindex positions
          updated_sections = updated_sections
          |> Enum.with_index(1)
          |> Enum.map(fn {section, index} ->
            if section.position != index do
              {:ok, updated} = Portfolios.update_section(section, %{position: index})
              updated
            else
              section
            end
          end)

          # Broadcast to live preview
          if socket.assigns.show_live_preview do
            Phoenix.PubSub.broadcast(
              Frestyl.PubSub,
              "portfolio_preview:#{socket.assigns.portfolio.id}",
              {:sections_updated, updated_sections}
            )
          end

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, nil)
          |> assign(:section_edit_mode, false)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Section '#{section_to_delete.title}' deleted successfully")

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete section")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end


  @impl true
  def handle_event("toggle_monetization", %{"section_id" => section_id}, socket) do
    if socket.assigns.can_monetize do
      case toggle_section_monetization(section_id, socket) do
        {:ok, updated_socket} ->
          {:noreply, updated_socket |> put_flash(:info, "Monetization settings updated")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    else
      {:noreply, put_flash(socket, :error, "Upgrade to Creator to enable monetization")}
    end
  end

    defp debounce_save_customization(socket, customization) do
    # Cancel existing timer
    if socket.assigns.debounce_timer do
      Process.cancel_timer(socket.assigns.debounce_timer)
    end

    # Set new timer
    timer = Process.send_after(self(), {:save_customization, customization}, 500)
    assign(socket, :debounce_timer, timer)
  end

  @impl true
  def handle_info({:save_customization, customization}, socket) do
    case save_portfolio_customization(socket.assigns.portfolio.id, customization) do
      {:ok, updated_portfolio} ->
        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:debounce_timer, nil)
        |> put_flash(:info, "Design changes saved")

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> assign(:debounce_timer, nil)
        |> put_flash(:error, "Failed to save changes: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("create_content_block", %{"section_id" => section_id, "block_type" => block_type}, socket) do
    # Check if user can create this block type
    if can_create_block_type?(block_type, socket) do
      case create_new_content_block(section_id, block_type, socket.assigns.user) do
        {:ok, block} ->
          updated_blocks = update_section_blocks_cache(socket.assigns.content_blocks, section_id, block)

          {:noreply,
          socket
          |> assign(:content_blocks, updated_blocks)
          |> assign(:editing_block, block)
          |> assign(:editing_mode, :block_detail)
          |> put_flash(:info, "Content block created successfully")}

        {:error, changeset} ->
          errors = format_errors(changeset)
          {:noreply, put_flash(socket, :error, "Failed to create block: #{errors}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Block type not available for your subscription tier")}
    end
  end

  @impl true
  def handle_event("edit_content_block", %{"block_id" => block_id}, socket) do
    try do
      block = ContentBlock.get_with_media!(block_id)
      {:noreply,
      socket
      |> assign(:editing_block, block)
      |> assign(:editing_mode, :block_detail)}
    rescue
      Ecto.NoResultsError ->
        {:noreply, put_flash(socket, :error, "Content block not found")}
    end
  end

  @impl true
  def handle_event("open_block_builder", %{"section_id" => section_id}, socket) do
    available_blocks = get_available_block_types_for_account(socket)

    {:noreply,
    socket
    |> assign(:block_builder_open, true)
    |> assign(:block_builder_section_id, section_id)
    |> assign(:available_block_types, available_blocks)}
  end

    @impl true
  def handle_event("add_media_to_block", %{"block_id" => block_id, "media_file_id" => media_file_id, "binding_type" => binding_type}, socket) do
    block = ContentBlock.get_with_media!(block_id)
    media_file = Portfolios.get_media_file!(media_file_id)

    result = case binding_type do
      "simple" ->
        # Simple portfolio media attachment
        ContentBlock.add_portfolio_media(block, media_file)

      binding_type when binding_type in ["background_audio", "hover_audio", "modal_image"] ->
        # Interactive story-style media binding
        binding_config = %{
          type: String.to_atom(binding_type),
          selector: "#block-#{block.id}",
          sync_data: %{},
          trigger_config: get_default_trigger_config(binding_type),
          display_config: get_default_display_config(binding_type)
        }
        ContentBlock.add_media_binding(block, media_file, binding_config)

      _ ->
        {:error, "Invalid binding type"}
    end

    case result do
      {:ok, _binding} ->
        updated_block = ContentBlock.get_with_media!(block_id)
        {:noreply,
         socket
         |> assign(:editing_block, updated_block)
         |> put_flash(:info, "Media added to block successfully")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add media: #{format_errors(changeset)}")}
    end
  end

  @impl true
  def handle_event("close_block_builder", _params, socket) do
    {:noreply, assign(socket, :block_builder_open, false)}
  end

  @impl true
  def handle_event("create_enhancement_channel", %{"type" => enhancement_type}, socket) do
    portfolio = socket.assigns.portfolio
    user = socket.assigns.current_user

    case Channels.create_portfolio_enhancement_channel(portfolio, enhancement_type, user) do
      {:ok, channel} ->
        # Redirect to new channel with portfolio context
        {:noreply,
        socket
        |> put_flash(:info, "Collaboration channel created!")
        |> redirect(to: ~p"/channels/#{channel.id}?source=portfolio&portfolio_id=#{portfolio.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create collaboration channel")}
    end
  end

  @impl true
  def handle_event("apply_story_template", %{"template_type" => template_type}, socket) do
    portfolio = socket.assigns.portfolio
    user = socket.assigns.current_user

    case Lab.Templates.apply_to_portfolio(portfolio, template_type, user) do
      {:ok, updated_portfolio} ->
        # Update portfolio with story structure
        story_fields = %{
          story_type: updated_portfolio.story_type,
          narrative_structure: updated_portfolio.narrative_structure,
          target_audience: updated_portfolio.target_audience || "professional"
        }

        case Portfolios.update_portfolio(portfolio, story_fields) do
          {:ok, portfolio_with_story} ->
            {:noreply,
            socket
            |> assign(:portfolio, portfolio_with_story)
            |> put_flash(:info, "Story template applied! Your portfolio now follows #{template_type} structure.")
            |> push_event("story_template_applied", %{template: template_type})}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to apply story template: #{format_errors(changeset)}")}
        end

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Story template not available: #{reason}")}
    end
  end

  @impl true
  def handle_event("add_studio_content", %{"content_type" => content_type, "studio_url" => url}, socket) do
    portfolio = socket.assigns.portfolio

    case content_type do
      "background_music" ->
        audio_settings = Map.merge(portfolio.audio_settings || %{}, %{
          "background_music_enabled" => true,
          "background_music_url" => url,
          "auto_play_policy" => "hover"
        })

        case Portfolios.update_portfolio(portfolio, %{audio_settings: audio_settings}) do
          {:ok, updated_portfolio} ->
            {:noreply,
            socket
            |> assign(:portfolio, updated_portfolio)
            |> put_flash(:info, "Background music added!")
            |> push_event("audio_added", %{type: "background", url: url})}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to add music: #{format_errors(changeset)}")}
        end

      "voice_intro" ->
        audio_settings = Map.merge(portfolio.audio_settings || %{}, %{
          "voice_intro_enabled" => true,
          "voice_intro_url" => url
        })

        case Portfolios.update_portfolio(portfolio, %{audio_settings: audio_settings}) do
          {:ok, updated_portfolio} ->
            {:noreply,
            socket
            |> assign(:portfolio, updated_portfolio)
            |> put_flash(:info, "Voice introduction added!")
            |> push_event("audio_added", %{type: "voice_intro", url: url})}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to add voice intro: #{format_errors(changeset)}")}
        end
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp generate_simple_preview_css(customization, theme) do
    primary_color = Map.get(customization, "primary_color", "#374151")
    accent_color = Map.get(customization, "accent_color", "#059669")
    secondary_color = Map.get(customization, "secondary_color", "#6b7280")
    layout = Map.get(customization, "layout", "minimal")

    """
    <style>
    :root {
      --primary-color: #{primary_color};
      --accent-color: #{accent_color};
      --secondary-color: #{secondary_color};
    }

    body {
      font-family: #{get_theme_font(theme)};
      line-height: 1.6;
      margin: 0;
      padding: 0;
    }

    .portfolio-container {
      background: var(--primary-color);
      color: #ffffff;
      min-height: 100vh;
      padding: 2rem;
    }

    .portfolio-header h1 {
      color: #ffffff;
      margin-bottom: 0.5rem;
    }

    .portfolio-header p {
      color: rgba(255, 255, 255, 0.9);
    }

    .section {
      margin-bottom: 2rem;
      padding: 1.5rem;
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.1);
      #{get_layout_css(layout)}
    }

    .section h2.accent {
      color: var(--accent-color);
    }

    .section-content {
      color: rgba(255, 255, 255, 0.95);
      line-height: 1.6;
    }

    /* Smooth transitions for live updates */
    * {
      transition: background-color 0.3s ease,
                  color 0.3s ease,
                  border-color 0.3s ease;
    }

    @media (max-width: 768px) {
      .portfolio-container {
        padding: 1rem;
      }
      .section {
        margin-bottom: 1rem;
        padding: 1rem;
      }
    }
    </style>
    """
  end

  defp get_theme_font("minimal"), do: "'Inter', sans-serif"
  defp get_theme_font("professional"), do: "'Merriweather', serif"
  defp get_theme_font("creative"), do: "'Poppins', sans-serif"
  defp get_theme_font(_), do: "'Inter', sans-serif"

  defp get_theme_base_css(theme) do
    case theme do
      "minimal" -> """
        .portfolio-container { max-width: 800px; margin: 0 auto; padding: 2rem; }
        .portfolio-section { margin-bottom: 3rem; padding: 2rem; border-radius: 8px; }
        .portfolio-header h1 { font-size: 2.5rem; font-weight: 300; }
      """
      "executive" -> """
        .portfolio-container { max-width: 1200px; margin: 0 auto; padding: 3rem; }
        .portfolio-section { margin-bottom: 4rem; padding: 3rem; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .portfolio-header h1 { font-size: 3rem; font-weight: 700; }
      """
      "creative" -> """
        .portfolio-container { max-width: 1400px; margin: 0 auto; padding: 2rem; }
        .portfolio-section { margin-bottom: 2rem; padding: 2rem; border-radius: 16px; }
        .portfolio-header h1 { font-size: 4rem; font-weight: 900; }
      """
      _ -> """
        .portfolio-container { max-width: 1000px; margin: 0 auto; padding: 2rem; }
        .portfolio-section { margin-bottom: 2rem; padding: 2rem; }
      """
    end
  end

  defp get_layout_css(layout) do
    case layout do
      "grid" -> """
        .portfolio-sections { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem; }
      """
      "columns" -> """
        .portfolio-sections { display: grid; grid-template-columns: 1fr 1fr; gap: 3rem; }
        @media (max-width: 768px) { .portfolio-sections { grid-template-columns: 1fr; } }
      """
      "masonry" -> """
        .portfolio-sections { columns: 2; column-gap: 2rem; }
        .portfolio-section { break-inside: avoid; margin-bottom: 2rem; }
        @media (max-width: 768px) { .portfolio-sections { columns: 1; } }
      """
      _ -> """
        .portfolio-sections { display: flex; flex-direction: column; gap: 2rem; }
      """
    end
  end

  defp get_advanced_layout_css("gallery") do
    """
    .portfolio-sections {
      columns: 3;
      column-gap: 1rem;
    }

    .section {
      break-inside: avoid;
      margin-bottom: 1rem;
    }

    @media (max-width: 768px) {
      .portfolio-sections {
        columns: 1;
      }
    }
    """
  end

  defp get_advanced_layout_css(_), do: ""

  # Helper function to darken colors (simple version)
  defp darken_color(hex_color, _percentage) do
    # Simple darkening - in production you might want a more sophisticated approach
    case hex_color do
      "#374151" -> "#1f2937"
      "#1e40af" -> "#1e3a8a"
      _ -> "#1f2937"
    end
  end

  defp generate_live_preview_css(customization, theme) do
    primary_color = Map.get(customization, "primary_color", "#374151")
    secondary_color = Map.get(customization, "secondary_color", "#6b7280")
    accent_color = Map.get(customization, "accent_color", "#059669")
    background_color = Map.get(customization, "background_color", "#ffffff")
    text_color = Map.get(customization, "text_color", "#1f2937")
    layout = Map.get(customization, "layout", "minimal")

    base_css = get_theme_base_css(theme)

    """
    <style id="portfolio-preview-css">
    :root {
      --primary-color: #{primary_color};
      --secondary-color: #{secondary_color};
      --accent-color: #{accent_color};
      --background-color: #{background_color};
      --text-color: #{text_color};
    }

    #{base_css}

    /* Layout specific styles */
    #{get_layout_css(layout)}

    /* Apply custom colors */
    .portfolio-header {
      background-color: var(--primary-color);
      color: white;
    }

    .portfolio-section {
      color: var(--text-color);
    }

    .portfolio-accent {
      color: var(--accent-color);
    }

    .portfolio-secondary {
      color: var(--secondary-color);
    }

    .portfolio-bg {
      background-color: var(--background-color);
    }

    .btn-primary {
      background-color: var(--primary-color);
      border-color: var(--primary-color);
    }

    .btn-accent {
      background-color: var(--accent-color);
      border-color: var(--accent-color);
    }

    /* Ensure text is readable */
    .portfolio-content {
      background-color: var(--background-color);
      color: var(--text-color);
    }
    </style>
    """
  end

  defp broadcast_preview_update(socket) do
    portfolio = socket.assigns.portfolio
    customization = socket.assigns.customization || %{}

    css = generate_live_preview_css(customization, portfolio.theme)

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:preview_update, customization, css}
    )

    socket
  end

  defp can_add_section?(socket) do
    current_count = socket.assigns.section_count
    max_sections = socket.assigns.max_sections

    max_sections == -1 or current_count < max_sections
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp create_new_content_block(section_id, block_type, user) do
    next_position = get_next_block_position(section_id)

    ContentBlock.create_for_portfolio_section(section_id, %{
      block_uuid: Ecto.UUID.generate(),
      block_type: String.to_atom(block_type),
      position: next_position,
      content_data: get_default_content_for_block_type(block_type),
      layout_config: get_default_layout_config(block_type),
      media_limit: get_default_media_limit(block_type),
      requires_subscription_tier: get_required_tier_for_block(block_type),
      is_premium_feature: is_premium_block_type?(block_type)
    })
  end

  defp get_available_block_types do
    base_blocks = [
      %{type: "text", name: "Text Block", description: "Rich text content", category: "basic"},
      %{type: "responsibility", name: "Responsibility", description: "Job responsibility with media", category: "portfolio"},
      %{type: "skill_item", name: "Skill", description: "Individual skill with proficiency", category: "portfolio"},
      %{type: "project_card", name: "Project", description: "Project showcase card", category: "portfolio"},
      %{type: "achievement", name: "Achievement", description: "Award or accomplishment", category: "portfolio"},
      %{type: "testimonial_item", name: "Testimonial", description: "Client testimonial", category: "portfolio"},

      # Story blocks (merged from Stories.ContentBlock)
      %{type: "image", name: "Image Block", description: "Single image with caption", category: "story"},
      %{type: "gallery", name: "Image Gallery", description: "Multiple images in grid", category: "story"},
      %{type: "video", name: "Video Block", description: "Embedded video content", category: "story"},
      %{type: "quote", name: "Quote Block", description: "Highlighted quotation", category: "story"},
      %{type: "timeline", name: "Timeline", description: "Chronological timeline", category: "story"},
      %{type: "bullet_list", name: "Bullet List", description: "Structured list with bullets", category: "story"},

      # Layout blocks
      %{type: "grid_container", name: "Grid Layout", description: "Custom grid layout", category: "layout"},
      %{type: "card_stack", name: "Card Stack", description: "Stackable cards", category: "layout"},
      %{type: "feature_highlight", name: "Feature Highlight", description: "Prominent feature display", category: "layout"}
    ]

    # Add monetization blocks if user can monetize
    monetization_blocks = [
      %{type: "service_package", name: "Service Package", description: "Packaged service offering", category: "monetization"},
      %{type: "booking_widget", name: "Booking Widget", description: "Calendar booking integration", category: "monetization"},
      %{type: "pricing_tier", name: "Pricing Tier", description: "Service pricing tier", category: "monetization"},
      %{type: "hourly_rate", name: "Hourly Rate", description: "Hourly service pricing", category: "monetization"},
      %{type: "consultation_offer", name: "Consultation", description: "Free consultation offer", category: "monetization"},
      %{type: "payment_button", name: "Payment Button", description: "Direct payment integration", category: "monetization"}
    ]

    # Add streaming blocks if user can stream
    streaming_blocks = [
      %{type: "live_session_embed", name: "Live Session", description: "Embedded live streaming", category: "streaming"},
      %{type: "scheduled_stream", name: "Scheduled Stream", description: "Upcoming stream announcement", category: "streaming"},
      %{type: "recording_showcase", name: "Recording Showcase", description: "Past recording display", category: "streaming"},
      %{type: "availability_calendar", name: "Availability Calendar", description: "Live session booking", category: "streaming"},
      %{type: "stream_archive", name: "Stream Archive", description: "Collection of past streams", category: "streaming"}
    ]

    # Return blocks based on account capabilities - this will need socket.assigns access
    base_blocks ++ monetization_blocks ++ streaming_blocks
  end

  def get_available_block_types_for_account(socket) do
    all_blocks = get_available_block_types()

    # Filter based on account features
    Enum.filter(all_blocks, fn block ->
      case block.category do
        "monetization" -> socket.assigns.can_monetize
        "streaming" -> socket.assigns.can_stream
        _ -> true  # Basic, portfolio, story, and layout blocks always available
      end
    end)
  end

  defp update_section_blocks_cache(cache, section_id, new_block) do
    current_blocks = Map.get(cache, section_id, [])
    Map.put(cache, section_id, [new_block | current_blocks])
  end

  defp count_total_blocks(content_blocks) do
    content_blocks
    |> Map.values()
    |> List.flatten()
    |> length()
  end

  defp get_next_block_position(section_id) do
    blocks = Portfolios.list_content_blocks_for_section(section_id)
    case blocks do
      [] -> 0
      blocks ->
        blocks
        |> Enum.map(& &1.position)
        |> Enum.max()
        |> Kernel.+(1)
    end
  end

  defp get_streaming_key(user_id) do
    # Generate a streaming key based on user ID
    "sk_user_#{user_id}_" <>
      (:crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16))
  end

  defp get_scheduled_streams(user_id) do
    case Streaming.get_scheduled_streams(user_id) do
      {:ok, streams} -> streams
      _ -> []
    end
  rescue
    _ -> []
  end

  defp get_stream_analytics(user_id) do
    case Analytics.get_stream_analytics(user_id) do
      {:ok, analytics} -> analytics
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  defp load_streaming_config(portfolio, account) do
    subscription_tier = Map.get(account, :subscription_tier, "personal")

    case subscription_tier do
      tier when tier in ["professional", "creator", "enterprise"] ->
        %{
          streaming_key: get_portfolio_streaming_key(portfolio.id),
          scheduled_streams: load_scheduled_streams(portfolio.id),
          stream_analytics: load_stream_analytics(portfolio.id),
          rtmp_config: get_portfolio_rtmp_config(portfolio.id),
          subscription_tier: tier,
          streaming_enabled: true
        }
      _ ->
        %{
          streaming_key: nil,
          scheduled_streams: [],
          stream_analytics: %{},
          rtmp_config: %{},
          subscription_tier: "personal",
          streaming_enabled: false,
          upgrade_required: true
        }
    end
  end

  # Safe implementations of the missing functions
  defp load_scheduled_streams(portfolio_id) do
    try do
      # Try to get scheduled streams for this portfolio
      # This would typically query a database table
      case get_portfolio_scheduled_streams(portfolio_id) do
        {:ok, streams} -> streams
        _ -> []
      end
    rescue
      _ -> []
    end
  end

  defp load_stream_analytics(portfolio_id) do
    try do
      # Try to get stream analytics for this portfolio
      case get_portfolio_stream_analytics(portfolio_id) do
        {:ok, analytics} -> analytics
        _ -> %{}
      end
    rescue
      _ -> %{}
    end
  end

  # Helper functions for database queries (implement these based on your schema)
  defp get_portfolio_streaming_key(portfolio_id) do
    # Generate or retrieve streaming key for portfolio
    "sk_portfolio_#{portfolio_id}_" <>
      (:crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16))
  end

  defp get_portfolio_scheduled_streams(portfolio_id) do
    # If you have a ScheduledStreams table/schema
    try do
      if Code.ensure_loaded?(Frestyl.Streaming.ScheduledStream) do
        # Example query - adjust based on your schema
        streams = Frestyl.Repo.all(
          from s in Frestyl.Streaming.ScheduledStream,
          where: s.portfolio_id == ^portfolio_id,
          where: s.scheduled_at > ^DateTime.utc_now(),
          order_by: [asc: s.scheduled_at]
        )
        {:ok, streams}
      else
        {:ok, []}
      end
    rescue
      _ -> {:ok, []}
    end
  end

  defp get_portfolio_stream_analytics(portfolio_id) do
    # If you have a StreamAnalytics table/schema
    try do
      if Code.ensure_loaded?(Frestyl.Analytics.StreamAnalytics) do
        # Example query - adjust based on your schema
        analytics = Frestyl.Repo.one(
          from a in Frestyl.Analytics.StreamAnalytics,
          where: a.portfolio_id == ^portfolio_id,
          select: %{
            total_streams: a.total_streams,
            total_viewers: a.total_viewers,
            average_duration: a.average_duration,
            last_stream: a.last_stream_at
          }
        )
        {:ok, analytics || %{}}
      else
        {:ok, %{}}
      end
    rescue
      _ -> {:ok, %{}}
    end
  end

  defp get_portfolio_rtmp_config(portfolio_id) do
    # Basic RTMP configuration for portfolio streaming
    %{
      server: "rtmp://stream.frestyl.com/live/",
      stream_key: get_portfolio_streaming_key(portfolio_id),
      backup_server: "rtmp://backup.frestyl.com/live/"
    }
  end

  defp get_rtmp_config(user_id) do
    case Streaming.get_rtmp_config(user_id) do
      {:ok, config} -> config
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  defp get_default_content_for_block_type("text"), do: %{"content" => ""}
  defp get_default_content_for_block_type("responsibility"), do: %{"text" => "", "impact_metrics" => []}
  defp get_default_content_for_block_type("skill_item"), do: %{"name" => "", "proficiency" => "intermediate"}
  defp get_default_content_for_block_type("service_package"), do: %{"name" => "", "price" => 0}
  defp get_default_content_for_block_type(_), do: %{}

  defp get_default_media_limit("text"), do: 2
  defp get_default_media_limit("project_card"), do: 8
  defp get_default_media_limit(_), do: 3


  # Placeholder functions for implementation in subsequent prompts
  defp load_portfolio_sections(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
  end

  defp load_portfolio_media(portfolio_id) do
    try do
      Portfolios.list_portfolio_media(portfolio_id)
    rescue
      _ -> []
    end
  end

  defp load_portfolio_services(_portfolio_id), do: []
  defp load_portfolio_pricing(_portfolio_id), do: %{}
  defp load_booking_calendar(_portfolio_id), do: %{}
  defp load_revenue_analytics(_portfolio_id), do: %{}
  defp load_payment_config(_portfolio_id), do: %{}

  defp generate_streaming_key(_portfolio_id), do: nil
  defp load_scheduled_streams(_portfolio_id), do: []
  defp load_stream_analytics(_portfolio_id), do: %{}
  defp load_rtmp_config(_portfolio_id), do: %{}


  defp load_pricing_config(portfolio_id), do: %{}

  defp get_custom_brand_config(account_id), do: nil

  defp update_section_content(params, socket) do
    # Implementation for next prompt
    {:ok, socket}
  end

  defp create_new_section(section_type, socket) do
    # Implementation for next prompt
    {:ok, %{id: 1, type: section_type, title: "New Section"}}
  end

  defp delete_section_by_id(section_id, socket) do
    # Implementation for next prompt
    {:ok, socket.assigns.sections}
  end

  defp toggle_section_monetization(section_id, socket) do
    # Implementation for next prompt
    {:ok, socket}
  end

  # Helper function to determine if portfolio needs story enhancement
  defp missing_story_structure?(portfolio) do
    is_nil(portfolio.story_type) || is_nil(portfolio.narrative_structure)
  end

  defp text_heavy_without_audio?(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    has_text_content = Enum.any?(sections, fn section ->
      content = section.content || %{}
      text_fields = ["summary", "description", "content", "about"]

      Enum.any?(text_fields, fn field ->
        text = Map.get(content, field, "")
        String.length(text) > 200
      end)
    end)

    has_audio = portfolio.audio_settings["background_music_enabled"] ||
                portfolio.audio_settings["voice_intro_enabled"]

    has_text_content && !has_audio
  end

    defp can_create_block_type?(block_type, socket) do
    block_atom = String.to_atom(block_type)

    cond do
      ContentBlock.is_monetization_block?(block_atom) ->
        socket.assigns.can_monetize

      ContentBlock.is_streaming_block?(block_atom) ->
        socket.assigns.can_stream

      true ->
        true  # Basic blocks always allowed
    end
  end

  defp get_required_tier_for_block(block_type) do
    block_atom = String.to_atom(block_type)

    cond do
      ContentBlock.is_monetization_block?(block_atom) -> "creator"
      ContentBlock.is_streaming_block?(block_atom) -> "creator"
      block_type in ["media_showcase", "timeline", "gallery"] -> "professional"
      true -> nil
    end
  end

  defp is_premium_block_type?(block_type) do
    block_atom = String.to_atom(block_type)
    ContentBlock.is_monetization_block?(block_atom) || ContentBlock.is_streaming_block?(block_atom)
  end

  defp get_default_layout_config("grid_container"), do: %{"columns" => 2, "gap" => "1rem"}
  defp get_default_layout_config("gallery"), do: %{"layout" => "masonry", "columns" => 3}
  defp get_default_layout_config("timeline"), do: %{"orientation" => "vertical", "show_dates" => true}
  defp get_default_layout_config(_), do: %{}

  defp get_default_trigger_config("hover_audio"), do: %{"event" => "mouseenter", "delay" => 0}
  defp get_default_trigger_config("background_audio"), do: %{"autoplay" => false, "loop" => true}
  defp get_default_trigger_config("modal_image"), do: %{"event" => "click", "overlay" => true}
  defp get_default_trigger_config(_), do: %{}

  defp get_default_display_config("modal_image"), do: %{"size" => "large", "position" => "center"}
  defp get_default_display_config("background_audio"), do: %{"volume" => 0.3, "fade_in" => true}
  defp get_default_display_config(_), do: %{}

  # UPDATED: Enhanced content defaults for merged block types
  defp get_default_content_for_block_type("text"), do: %{"content" => ""}
  defp get_default_content_for_block_type("responsibility"), do: %{"text" => "", "impact_metrics" => []}
  defp get_default_content_for_block_type("skill_item"), do: %{"name" => "", "proficiency" => "intermediate"}
  defp get_default_content_for_block_type("service_package"), do: %{"name" => "", "price" => 0, "description" => ""}
  defp get_default_content_for_block_type("image"), do: %{"caption" => "", "alt_text" => ""}
  defp get_default_content_for_block_type("gallery"), do: %{"images" => [], "caption" => ""}
  defp get_default_content_for_block_type("video"), do: %{"url" => "", "title" => "", "description" => ""}
  defp get_default_content_for_block_type("quote"), do: %{"text" => "", "author" => "", "source" => ""}
  defp get_default_content_for_block_type("timeline"), do: %{"events" => []}
  defp get_default_content_for_block_type("bullet_list"), do: %{"items" => [""]}
  defp get_default_content_for_block_type("booking_widget"), do: %{"calendar_id" => "", "duration" => 30}
  defp get_default_content_for_block_type("live_session_embed"), do: %{"stream_key" => "", "title" => ""}
  defp get_default_content_for_block_type(_), do: %{}

  # UPDATED: Media limits for merged block types
  defp get_default_media_limit("text"), do: 2
  defp get_default_media_limit("project_card"), do: 8
  defp get_default_media_limit("gallery"), do: 20
  defp get_default_media_limit("image"), do: 1
  defp get_default_media_limit("video"), do: 1
  defp get_default_media_limit("media_showcase"), do: 15
  defp get_default_media_limit(_), do: 3

  defp get_next_block_position(section_id) do
    blocks = ContentBlock.list_for_section(section_id)
    case blocks do
      [] -> 0
      blocks ->
        blocks
        |> Enum.map(& &1.position)
        |> Enum.max()
        |> Kernel.+(1)
    end
  end

  defp get_monetization_analytics(portfolio_id, account_id) do
    # Stub implementation - replace with actual analytics logic
    %{
      revenue_trend: get_revenue_trend(portfolio_id),
      top_products: get_top_selling_products(portfolio_id),
      conversion_rate: calculate_conversion_rate(portfolio_id),
      visitor_to_customer: calculate_visitor_conversion(portfolio_id),
      total_views: get_portfolio_views(portfolio_id),
      total_purchases: get_total_purchases(portfolio_id)
    }
  end

  defp get_revenue_trend(_portfolio_id) do
    # Return last 30 days of revenue data
    # Stub implementation
    []
  end

  defp get_top_selling_products(_portfolio_id) do
    # Return top selling products/services
    # Stub implementation
    []
  end

  defp calculate_conversion_rate(_portfolio_id) do
    # Calculate conversion rate from views to purchases
    # Stub implementation
    0.0
  end

  defp calculate_visitor_conversion(_portfolio_id) do
    # Calculate visitor to customer conversion
    # Stub implementation
    0.0
  end

  defp get_portfolio_views(portfolio_id) do
    try do
      Frestyl.Portfolios.get_total_visits(portfolio_id)
    rescue
      _ -> 0
    end
  end

  defp get_total_purchases(_portfolio_id) do
    # Get total purchases for this portfolio
    # Stub implementation
    0
  end

  defp get_revenue_summary(monetization_data) do
    earnings = Map.get(monetization_data, :earnings, %{total: 0, this_month: 0})
    analytics = Map.get(monetization_data, :analytics, %{})

    %{
      total_revenue: Map.get(earnings, :total, 0),
      monthly_revenue: Map.get(earnings, :this_month, 0),
      conversion_rate: Map.get(analytics, :conversion_rate, 0.0),
      total_transactions: Map.get(analytics, :total_purchases, 0)
    }
  end

  # Alternative quick fix - just use safe access:
  defp assign_monetization_data(socket, user, account) do
    try do
      monetization_data = load_monetization_data(user, account)
      assign(socket, :monetization_data, monetization_data)
    rescue
      error ->
        Logger.error("Failed to load monetization data: #{inspect(error)}")
        # Assign default monetization data
        default_data = %{
          streaming_key: nil,
          scheduled_streams: [],
          stream_analytics: %{},
          rtmp_config: %{},
          subscription_tier: get_subscription_tier(account),
          error: true
        }
        assign(socket, :monetization_data, default_data)
    end
  end

  defp get_default_title_for_type("intro"), do: "Introduction"
  defp get_default_title_for_type("experience"), do: "Professional Experience"
  defp get_default_title_for_type("education"), do: "Education"
  defp get_default_title_for_type("skills"), do: "Skills & Expertise"
  defp get_default_title_for_type("projects"), do: "Projects"
  defp get_default_title_for_type("featured_project"), do: "Featured Project"
  defp get_default_title_for_type("achievements"), do: "Achievements"
  defp get_default_title_for_type("testimonial"), do: "Testimonials"
  defp get_default_title_for_type("contact"), do: "Contact Information"
  defp get_default_title_for_type(_), do: "New Section"

  defp get_default_content_for_type("intro") do
    %{
      "headline" => "Hello, I'm [Your Name]",
      "summary" => "A passionate professional focused on creating exceptional experiences.",
      "cta_text" => "Get in touch"
    }
  end

  defp get_default_content_for_type("experience") do
    %{
      "experiences" => [
        %{
          "title" => "Your Job Title",
          "company" => "Company Name",
          "duration" => "Start Date - End Date",
          "description" => "Brief description of your role and achievements."
        }
      ]
    }
  end

  defp get_default_content_for_type("skills") do
    %{
      "skill_categories" => %{
        "Technical" => [
          %{"name" => "Your Skill", "proficiency" => "advanced", "years" => 3}
        ]
      }
    }
  end

  defp get_default_content_for_type("projects") do
    %{
      "projects" => [
        %{
          "title" => "Project Title",
          "description" => "Brief description of the project and your role.",
          "technologies" => [],
          "links" => %{"github" => "", "live" => ""}
        }
      ]
    }
  end

  defp get_default_content_for_type(_type) do
    %{"main_content" => "Add your content here..."}
  end

  defp format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      :experience -> "Experience"
      :skills -> "Skills"
      :education -> "Education"
      :projects -> "Projects"
      :featured_project -> "Featured Project"
      :case_study -> "Case Study"
      :contact -> "Contact"
      :testimonial -> "Testimonial"
      :achievements -> "Achievements"
      :media_showcase -> "Media Showcase"
      "intro" -> "Introduction"
      "experience" -> "Experience"
      "skills" -> "Skills"
      "education" -> "Education"
      "projects" -> "Projects"
      "featured_project" -> "Featured Project"
      "case_study" -> "Case Study"
      "contact" -> "Contact"
      "testimonial" -> "Testimonial"
      "achievements" -> "Achievements"
      "media_showcase" -> "Media Showcase"
      _ -> "Section"
    end
  end

  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  defp move_section(sections, old_index, new_index) do
    if old_index >= 0 and old_index < length(sections) and
      new_index >= 0 and new_index < length(sections) and
      old_index != new_index do

      section = Enum.at(sections, old_index)
      sections_without_moved = List.delete_at(sections, old_index)
      reordered_sections = List.insert_at(sections_without_moved, new_index, section)

      {:ok, reordered_sections}
    else
      {:error, "Invalid indices for section reordering"}
    end
  end

  defp update_section_positions(sections) do
    sections
    |> Enum.with_index(1)
    |> Enum.map(fn {section, index} ->
      case Portfolios.update_section(section, %{position: index}) do
        {:ok, updated_section} -> updated_section
        {:error, _} -> section
      end
    end)
  end

  # ============================================================================
  # SECTION TYPE HELPERS - ADD THESE AT THE END OF YOUR FILE
  # ============================================================================

  defp get_section_types do
    %{
      "intro" => %{
        title: "Introduction",
        description: "Welcome message and personal summary",
        emoji: "👋"
      },
      "experience" => %{
        title: "Professional Experience",
        description: "Work history and job experience",
        emoji: "💼"
      },
      "education" => %{
        title: "Education",
        description: "Academic background and qualifications",
        emoji: "🎓"
      },
      "skills" => %{
        title: "Skills & Expertise",
        description: "Technical and professional skills",
        emoji: "⚡"
      },
      "projects" => %{
        title: "Projects",
        description: "Portfolio of work and projects",
        emoji: "🛠️"
      },
      "featured_project" => %{
        title: "Featured Project",
        description: "Highlight a specific project",
        emoji: "🚀"
      },
      "achievements" => %{
        title: "Achievements",
        description: "Awards, certifications, and accomplishments",
        emoji: "🏆"
      },
      "testimonial" => %{
        title: "Testimonials",
        description: "Client and colleague recommendations",
        emoji: "💬"
      },
      "contact" => %{
        title: "Contact Information",
        description: "How to get in touch",
        emoji: "📧"
      }
    }
  end

  defp get_section_emoji(section_type) do
    section_type_string = case section_type do
      atom when is_atom(atom) -> Atom.to_string(atom)
      string when is_binary(string) -> string
      _ -> "unknown"
    end

    case section_type_string do
      "intro" -> "👋"
      "experience" -> "💼"
      "education" -> "🎓"
      "skills" -> "⚡"
      "projects" -> "🛠️"
      "featured_project" -> "🚀"
      "media_showcase" -> "🖼️"
      "achievements" -> "🏆"
      "testimonial" -> "💬"
      "contact" -> "📧"
      "case_study" -> "📊"
      "timeline" -> "📅"
      "story" -> "📖"
      "custom" -> "📝"
      _ -> "📄"
    end
  end

  defp get_section_preview(section) do
    content = section.content || %{}

    section_type_string = case section.section_type do
      atom when is_atom(atom) -> Atom.to_string(atom)
      string when is_binary(string) -> string
      _ -> "unknown"
    end

    case section_type_string do
      "intro" ->
        content["headline"] || content["summary"] || "Introduction section"
      "experience" ->
        experiences = content["experiences"] || []
        case experiences do
          [first | _] when is_map(first) ->
            "#{Map.get(first, "title", "")} at #{Map.get(first, "company", "")}"
          [] -> "Professional experience"
          _ -> "Professional experience"
        end
      "skills" ->
        skill_categories = content["skill_categories"] || %{}
        skill_count = skill_categories |> Map.values() |> List.flatten() |> length()
        "#{skill_count} skills across #{map_size(skill_categories)} categories"
      "projects" ->
        projects = content["projects"] || []
        case projects do
          [first | _] when is_map(first) -> Map.get(first, "title", "Project showcase")
          [] -> "Project portfolio"
          _ -> "Project portfolio"
        end
      "media_showcase" ->
        "Media gallery and showcase"
      "case_study" ->
        Map.get(content, "title", "Detailed case study")
      "timeline" ->
        events = Map.get(content, "events", [])
        event_count = if is_list(events), do: length(events), else: 0
        "Timeline with #{event_count} events"
      _ ->
        content["main_content"] || content["description"] || content["summary"] || "Content section"
    end
  end

  defp format_relative_time(datetime) do
    try do
      # Convert NaiveDateTime to DateTime if needed
      utc_datetime = case datetime do
        %DateTime{} = dt -> dt
        %NaiveDateTime{} = ndt -> DateTime.from_naive!(ndt, "Etc/UTC")
        _ -> DateTime.utc_now()
      end

      case DateTime.diff(DateTime.utc_now(), utc_datetime, :second) do
        diff when diff < 60 -> "Just now"
        diff when diff < 3600 -> "#{div(diff, 60)}m ago"
        diff when diff < 86400 -> "#{div(diff, 3600)}h ago"
        diff when diff < 604800 -> "#{div(diff, 86400)}d ago"
        _ ->
          # For older dates, show actual date
          Calendar.strftime(utc_datetime, "%b %d, %Y")
      end
    rescue
      _ -> "Recently"
    end
  end

  defp build_preview_url(portfolio, customization) do
    base_url = FrestylWeb.Endpoint.url()
    preview_token = generate_preview_token(portfolio.id)

    query_params = [
      {"preview", "true"},
      {"token", preview_token}
    ]

    # Add customization params for immediate reflection
    customization_params =
      customization
      |> Enum.map(fn {key, value} -> {"custom_#{key}", to_string(value)} end)

    all_params = query_params ++ customization_params
    query_string = URI.encode_query(all_params)

    "#{base_url}/p/#{portfolio.slug}?#{query_string}"
  end

  defp generate_preview_token(portfolio_id) do
    :crypto.hash(:sha256, "preview_#{portfolio_id}_#{Date.utc_today()}")
    |> Base.encode16(case: :lower)
  end

  # ============================================================================
  # MISSING EVENT HANDLERS - ADD THESE TO YOUR handle_event FUNCTIONS
  # ============================================================================

  @impl true
  def handle_event("toggle_main_menu", _params, socket) do
    current_state = socket.assigns[:show_main_menu] || false
    {:noreply, assign(socket, :show_main_menu, !current_state)}
  end

  @impl true
  def handle_event("close_main_menu", _params, socket) do
    {:noreply, assign(socket, :show_main_menu, false)}
  end

  @impl true
  def handle_event("manage_section_media", %{"section-id" => section_id}, socket) do
    socket = socket
    |> assign(:show_media_library, true)
    |> assign(:media_section_id, section_id)

    {:noreply, socket}
  end

  defp render_basic_info_section(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-gray-200 shadow-sm">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">Portfolio Information</h3>
        <p class="text-sm text-gray-600 mt-1">Basic details about your portfolio</p>
      </div>

      <div class="p-6 space-y-6">
        <!-- Title -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Portfolio Title</label>
          <input
            type="text"
            value={@portfolio.title}
            phx-change="update_title"
            phx-debounce="300"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Enter your portfolio title">
        </div>

        <!-- Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
          <textarea
            phx-change="update_description"
            phx-debounce="300"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Brief description of your portfolio"><%= @portfolio.description %></textarea>
        </div>

        <!-- Visibility -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Visibility</label>
          <select
            phx-change="update_visibility"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            <option value="public" selected={@portfolio.visibility == :public}>
              Public - Discoverable by everyone
            </option>
            <option value="link_only" selected={@portfolio.visibility == :link_only}>
              Link Only - Accessible via direct URL
            </option>
            <option value="request_only" selected={@portfolio.visibility == :request_only}>
              Request Only - Requires approval to view
            </option>
            <option value="private" selected={@portfolio.visibility == :private}>
              Private - Only you and collaborators
            </option>
          </select>

          <!-- Visibility Help Text -->
          <p class="mt-2 text-xs text-gray-500">
            <%= case @portfolio.visibility do %>
              <% :public -> %>🌍 Your portfolio is publicly discoverable and accessible to everyone
              <% :link_only -> %>🔗 Your portfolio is accessible to anyone with the direct link
              <% :request_only -> %>🔐 Visitors must request access to view your portfolio
              <% :private -> %>👤 Only you and invited collaborators can view this portfolio
            <% end %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  # Test if custom fields are working properly
  def test_custom_fields_functionality(portfolio_id) do
    IO.puts("🧪 Testing Custom Fields for Portfolio #{portfolio_id}")

    # Test field definition creation
    test_field = %{
      portfolio_id: portfolio_id,
      field_name: "test_certification",
      field_type: "text",
      field_label: "Test Certification",
      field_description: "A test certification field",
      validation_rules: %{"min_length" => 3, "max_length" => 100},
      is_required: true,
      is_public: true
    }

    case Portfolios.create_custom_field_definition(test_field) do
      {:ok, definition} ->
        IO.puts("✅ Field definition created: #{definition.field_label}")

        # Test field value creation
        test_value = %{
          portfolio_id: portfolio_id,
          field_definition_id: definition.id,
          field_name: "test_certification",
          value: %{"content" => "AWS Solutions Architect"},
          value_text: "AWS Solutions Architect"
        }

        case Portfolios.create_custom_field_value(test_value) do
          {:ok, value} ->
            IO.puts("✅ Field value created: #{value.value_text}")
            {:ok, %{definition: definition, value: value}}

          {:error, changeset} ->
            IO.puts("❌ Field value creation failed: #{inspect(changeset.errors)}")
            {:error, :value_creation_failed}
        end

      {:error, changeset} ->
        IO.puts("❌ Field definition creation failed: #{inspect(changeset.errors)}")
        {:error, :definition_creation_failed}
    end
  end

  # Cleanup test data
  def cleanup_test_custom_fields(portfolio_id) do
    definitions = Portfolios.list_custom_field_definitions(portfolio_id)

    test_definitions = Enum.filter(definitions, &String.starts_with?(&1.field_name, "test_"))

    Enum.each(test_definitions, fn definition ->
      case Portfolios.delete_custom_field_definition(definition) do
        {:ok, _} -> IO.puts("🧹 Cleaned up test definition: #{definition.field_name}")
        {:error, _} -> IO.puts("❌ Failed to cleanup: #{definition.field_name}")
      end
    end)

    IO.puts("🧹 Custom fields cleanup completed")
  end

  # Validate portfolio custom fields integrity
  def validate_custom_fields_integrity(portfolio_id) do
    definitions = Portfolios.list_custom_field_definitions(portfolio_id)
    values = Portfolios.list_custom_field_values(portfolio_id)

    issues = []

    # Check for orphaned values
    orphaned_values = Enum.filter(values, fn value ->
      !Enum.any?(definitions, &(&1.id == value.field_definition_id))
    end)

    if !Enum.empty?(orphaned_values) do
      issues = [{"Orphaned field values found", length(orphaned_values)} | issues]
    end

    # Check for missing required values
    required_definitions = Enum.filter(definitions, & &1.is_required)
    missing_required = Enum.filter(required_definitions, fn definition ->
      !Enum.any?(values, &(&1.field_definition_id == definition.id))
    end)

    if !Enum.empty?(missing_required) do
      issues = [{"Missing required field values", length(missing_required)} | issues]
    end

    # Check validation rule compliance
    validation_issues = Enum.reduce(values, [], fn value, acc ->
      case value.field_definition do
        nil -> acc
        definition ->
          case Portfolios.validate_custom_field_value(value.value, definition) do
            {:ok, _} -> acc
            {:error, error} -> [{value.field_name, error} | acc]
          end
      end
    end)

    if !Enum.empty?(validation_issues) do
      issues = [{"Validation rule violations", length(validation_issues)} | issues]
    end

    case issues do
      [] ->
        IO.puts("✅ Custom fields integrity check passed")
        {:ok, :valid}
      issues ->
        IO.puts("⚠️  Custom fields integrity issues found:")
        Enum.each(issues, fn {issue, count} ->
          IO.puts("   - #{issue}: #{count}")
        end)
        {:warning, issues}
    end
  end

  # Export custom fields data for backup/migration
  def export_custom_fields_data(portfolio_id) do
    definitions = Portfolios.list_custom_field_definitions(portfolio_id)
    values = Portfolios.list_custom_field_values(portfolio_id)

    export_data = %{
      portfolio_id: portfolio_id,
      exported_at: DateTime.utc_now(),
      definitions: Enum.map(definitions, fn def ->
        Map.take(def, [:field_name, :field_type, :field_label, :field_description, :validation_rules, :display_options, :position, :is_required, :is_public])
      end),
      values: Enum.map(values, fn val ->
        %{
          field_name: val.field_name,
          value: val.value,
          section_id: val.section_id
        }
      end)
    }

    case Jason.encode(export_data, pretty: true) do
      {:ok, json} ->
        IO.puts("📤 Custom fields data exported successfully")
        {:ok, json}
      {:error, error} ->
        IO.puts("❌ Export failed: #{inspect(error)}")
        {:error, error}
    end
  end


end
