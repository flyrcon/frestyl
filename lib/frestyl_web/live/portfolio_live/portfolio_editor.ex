# lib/frestyl_web/live/portfolio_live/portfolio_editor.ex
# UNIFIED PORTFOLIO EDITOR - Replaces all manager modules

defmodule FrestylWeb.PortfolioLive.PortfolioEditor do
  use FrestylWeb, :live_view

  alias Frestyl.{Portfolios, Accounts, Billing}
  alias FrestylWeb.PortfolioLive.Components.{SectionEditor, MediaLibrary, VideoRecorder}

  # ============================================================================
  # MOUNT - Account-Aware Foundation
  # ============================================================================

  @impl true
  def mount(%{"id" => portfolio_id}, _session, socket) do
    user = socket.assigns.current_user

    # Load portfolio with account context
    case load_portfolio_with_account(portfolio_id, user) do
      {:ok, portfolio, account} ->
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

        socket = socket
        |> assign_core_data(portfolio, account, user)
        |> assign_features_and_limits(features, limits)
        |> assign_content_data(sections, media_library)
        |> assign_monetization_data(monetization_data, streaming_config)
        |> assign_design_system(available_layouts, brand_constraints)
        |> assign_ui_state()

        {:ok, socket}

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/portfolios")}

      {:error, :unauthorized} ->
        {:ok, socket |> put_flash(:error, "Access denied") |> redirect(to: "/portfolios")}
    end
  end

  # ============================================================================
  # UNIFIED STATE MANAGEMENT
  # ============================================================================

  defp assign_core_data(socket, portfolio, account, user) do
    socket
    |> assign(:portfolio, portfolio)
    |> assign(:account, account)
    |> assign(:user, user)
    |> assign(:page_title, "Edit #{portfolio.title}")
  end

  defp assign_features_and_limits(socket, features, limits) do
    socket
    |> assign(:features, features)
    |> assign(:limits, limits)
    |> assign(:can_monetize, features.monetization_enabled)
    |> assign(:can_stream, features.streaming_enabled)
    |> assign(:can_schedule, features.scheduling_enabled)
    |> assign(:max_sections, limits.max_sections)
    |> assign(:max_media_size, limits.max_media_size_mb)
  end

  defp assign_content_data(socket, sections, media_library) do
    socket
    |> assign(:sections, sections)
    |> assign(:media_library, media_library)
    |> assign(:section_count, length(sections))
    |> assign(:editing_section, nil)
    |> assign(:editing_mode, :overview)
  end

  defp assign_monetization_data(socket, monetization_data, streaming_config) do
    socket
    |> assign(:monetization_data, monetization_data)
    |> assign(:streaming_config, streaming_config)
    |> assign(:revenue_analytics, monetization_data.analytics)
    |> assign(:booking_calendar, monetization_data.calendar)
  end

  defp assign_design_system(socket, available_layouts, brand_constraints) do
    socket
    |> assign(:available_layouts, available_layouts)
    |> assign(:brand_constraints, brand_constraints)
    |> assign(:current_layout, socket.assigns.portfolio.layout || "professional_service")
    |> assign(:design_tokens, generate_design_tokens(socket.assigns.portfolio, brand_constraints))
  end

  defp assign_ui_state(socket) do
    socket
    |> assign(:active_tab, :content)
    |> assign(:show_video_recorder, false)
    |> assign(:show_media_library, false)
    |> assign(:unsaved_changes, false)
    |> assign(:auto_save_enabled, true)
  end

  # ============================================================================
  # ACCOUNT & PERMISSION HELPERS
  # ============================================================================

  defp load_portfolio_with_account(portfolio_id, user) do
    case Portfolios.get_portfolio_with_account(portfolio_id) do
      nil ->
        {:error, :not_found}

      %{portfolio: portfolio, account: account} ->
        if can_edit_portfolio?(portfolio, account, user) do
          {:ok, portfolio, account}
        else
          {:error, :unauthorized}
        end
    end
  end

  defp can_edit_portfolio?(portfolio, account, user) do
    # Owner check
    portfolio.account_id == account.id and account.user_id == user.id
    # TODO: Add collaboration permissions here
  end

  defp get_account_features(account) do
    case account.subscription_tier do
      "personal" -> %{
        monetization_enabled: false,
        streaming_enabled: false,
        scheduling_enabled: false,
        advanced_analytics: false,
        custom_branding: false,
        api_access: false
      }

      "creator" -> %{
        monetization_enabled: true,
        streaming_enabled: true,
        scheduling_enabled: true,
        advanced_analytics: false,
        custom_branding: false,
        api_access: false
      }

      "professional" -> %{
        monetization_enabled: true,
        streaming_enabled: true,
        scheduling_enabled: true,
        advanced_analytics: true,
        custom_branding: true,
        api_access: false
      }

      "enterprise" -> %{
        monetization_enabled: true,
        streaming_enabled: true,
        scheduling_enabled: true,
        advanced_analytics: true,
        custom_branding: true,
        api_access: true
      }
    end
  end

  defp get_account_limits(account) do
    case account.subscription_tier do
      "personal" -> %{
        max_portfolios: 2,
        max_sections: 10,
        max_media_size_mb: 50,
        max_video_length: 60,
        max_streaming_hours: 0
      }

      "creator" -> %{
        max_portfolios: 5,
        max_sections: 25,
        max_media_size_mb: 200,
        max_video_length: 300,
        max_streaming_hours: 10
      }

      "professional" -> %{
        max_portfolios: 15,
        max_sections: 50,
        max_media_size_mb: 500,
        max_video_length: 600,
        max_streaming_hours: 50
      }

      "enterprise" -> %{
        max_portfolios: -1,
        max_sections: -1,
        max_media_size_mb: 1000,
        max_video_length: -1,
        max_streaming_hours: -1
      }
    end
  end

  # ============================================================================
  # MONETIZATION & STREAMING FOUNDATION
  # ============================================================================

  defp load_monetization_data(portfolio, account) do
    %{
      services: load_portfolio_services(portfolio.id),
      pricing: load_pricing_config(portfolio.id),
      calendar: load_booking_calendar(portfolio.id),
      analytics: load_revenue_analytics(portfolio.id, account),
      payment_config: load_payment_config(account.id)
    }
  end

  defp load_streaming_config(portfolio, account) do
    %{
      streaming_key: get_streaming_key(portfolio.id),
      scheduled_streams: load_scheduled_streams(portfolio.id),
      stream_analytics: load_stream_analytics(portfolio.id),
      rtmp_config: get_rtmp_config(account)
    }
  end

  # ============================================================================
  # BRAND CONTROL SYSTEM
  # ============================================================================

  defp get_brand_constraints(account) do
    case account.subscription_tier do
      tier when tier in ["enterprise"] ->
        # Enterprise can override brand constraints
        case get_custom_brand_config(account.id) do
          nil -> get_default_brand_constraints()
          custom -> custom
        end

      _ ->
        # All other tiers use default brand constraints
        get_default_brand_constraints()
    end
  end

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
  def handle_event("add_section", %{"type" => section_type}, socket) do
    if can_add_section?(socket) do
      case create_new_section(section_type, socket) do
        {:ok, new_section} ->
          updated_sections = socket.assigns.sections ++ [new_section]

          {:noreply,
           socket
           |> assign(:sections, updated_sections)
           |> assign(:editing_section, new_section)
           |> assign(:editing_mode, :section_edit)
           |> put_flash(:info, "Section added successfully")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to add section: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section limit reached for your subscription")}
    end
  end

  @impl true
  def handle_event("delete_section", %{"id" => section_id}, socket) do
    case delete_section_by_id(section_id, socket) do
      {:ok, updated_sections} ->
        {:noreply,
         socket
         |> assign(:sections, updated_sections)
         |> assign(:editing_section, nil)
         |> assign(:editing_mode, :overview)
         |> put_flash(:info, "Section deleted")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete section: #{reason}")}
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

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

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

  # Placeholder functions for implementation in subsequent prompts
  defp load_portfolio_sections(portfolio_id), do: Portfolios.list_portfolio_sections(portfolio_id)
  defp load_portfolio_media(portfolio_id), do: Portfolios.list_portfolio_media(portfolio_id)
  defp load_portfolio_services(portfolio_id), do: []
  defp load_pricing_config(portfolio_id), do: %{}
  defp load_booking_calendar(portfolio_id), do: %{}
  defp load_revenue_analytics(portfolio_id, account), do: %{}
  defp load_payment_config(account_id), do: %{}
  defp get_streaming_key(portfolio_id), do: nil
  defp load_scheduled_streams(portfolio_id), do: []
  defp load_stream_analytics(portfolio_id), do: %{}
  defp get_rtmp_config(account), do: %{}
  defp get_custom_brand_config(account_id), do: nil
  defp get_available_layouts(account), do: ["professional_service", "creative_showcase", "corporate_executive"]

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
end
