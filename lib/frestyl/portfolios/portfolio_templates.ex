# lib/frestyl/portfolios/portfolio_templates.ex - ENHANCED & FIXED

defmodule Frestyl.Portfolios.PortfolioTemplates do
  @moduledoc """
  Enhanced portfolio template system with professional dashboard-style layouts,
  comprehensive styling options, and real-time customization support.
  """

  def available_templates do
    [
      {"executive", %{
        name: "Executive",
        description: "Professional corporate dashboard with metrics and KPIs",
        preview_color: "from-slate-600 to-slate-700",
        features: ["Executive summary", "Key metrics", "Leadership roles", "Strategic initiatives"],
        icon: "👔"
      }},
      {"developer", %{
        name: "Developer",
        description: "Technical dashboard with code portfolio and project metrics",
        preview_color: "from-gray-700 to-gray-800",
        features: ["Code repositories", "Technical stack", "Project demos", "Performance metrics"],
        icon: "💻"
      }},
      {"designer", %{
        name: "Designer",
        description: "Creative dashboard with visual portfolio and case studies",
        preview_color: "from-indigo-500 to-purple-600",
        features: ["Visual portfolio", "Design process", "Case studies", "Client projects"],
        icon: "🎨"
      }},
      {"consultant", %{
        name: "Consultant",
        description: "Professional services dashboard with client results and expertise",
        preview_color: "from-blue-600 to-blue-700",
        features: ["Client results", "Industry expertise", "Case studies", "Success metrics"],
        icon: "📊"
      }},
      {"academic", %{
        name: "Academic",
        description: "Research-focused dashboard with publications and academic achievements",
        preview_color: "from-emerald-600 to-teal-600",
        features: ["Publications", "Research projects", "Academic roles", "Citations"],
        icon: "🎓"
      }},
      {"corporate", %{
        name: "Corporate",
        description: "Traditional business dashboard with structured layout",
        preview_color: "from-gray-500 to-gray-600",
        features: ["Professional timeline", "Company roles", "Industry expertise", "Achievements"],
        icon: "🏢"
      }},
      {"creative", %{
        name: "Creative",
        description: "Bold artistic dashboard with visual storytelling",
        preview_color: "from-purple-600 to-pink-600",
        features: ["Visual portfolio", "Creative projects", "Artistic journey", "Inspiration"],
        icon: "✨"
      }},
      {"minimalist", %{
        name: "Minimalist",
        description: "Clean, typography-focused dashboard with minimal distractions",
        preview_color: "from-gray-300 to-gray-400",
        features: ["Clean layout", "Typography focus", "Essential content", "Distraction-free"],
        icon: "⚪"
      }}
    ]
  end

  def get_template_config(theme) do
    case theme do
      "executive" -> executive_config()
      "developer" -> developer_config()
      "designer" -> designer_config()
      "consultant" -> consultant_config()
      "academic" -> academic_config()
      "corporate" -> corporate_config()
      "creative" -> creative_config()
      "minimalist" -> minimalist_config()
      _ -> executive_config()
    end
  end

  # EXECUTIVE: Professional Corporate Dashboard
  defp executive_config do
    %{
      layout: "dashboard",
      primary_color: "#334155",     # Slate-700
      secondary_color: "#3b82f6",   # Blue-500
      accent_color: "#059669",      # Emerald-600
      background: "corporate-clean",
      typography: %{
        font_family: "Inter",
        font_size: "base",
        heading_weight: "bold",
        body_weight: "medium"
      },
      spacing: "normal",
      card_style: "corporate",
      dashboard_config: %{
        header_type: "executive",
        sidebar_style: "minimal",
        card_layout: "grid",
        metrics_display: true,
        chart_style: "professional"
      },
      css_overrides: %{
        card_shadow: "0 4px 6px -1px rgba(0, 0, 0, 0.1)",
        border_radius: "12px",
        header_bg: "rgba(248, 250, 252, 0.95)"
      }
    }
  end

  # DEVELOPER: Technical Dashboard
  defp developer_config do
    %{
      layout: "dashboard",
      primary_color: "#1f2937",     # Gray-800
      secondary_color: "#10b981",   # Emerald-500
      accent_color: "#6366f1",      # Indigo-500
      background: "tech-dark",
      typography: %{
        font_family: "JetBrains Mono",
        font_size: "base",
        heading_weight: "semibold",
        body_weight: "normal"
      },
      spacing: "compact",
      card_style: "technical",
      dashboard_config: %{
        header_type: "technical",
        sidebar_style: "code",
        card_layout: "masonry",
        metrics_display: true,
        chart_style: "technical"
      },
      css_overrides: %{
        card_shadow: "0 2px 4px rgba(0, 0, 0, 0.2)",
        border_radius: "8px",
        header_bg: "rgba(31, 41, 55, 0.95)"
      }
    }
  end

  # DESIGNER: Creative Dashboard
  defp designer_config do
    %{
      layout: "dashboard",
      primary_color: "#4f46e5",     # Indigo-600
      secondary_color: "#8b5cf6",   # Violet-500
      accent_color: "#f59e0b",      # Amber-500
      background: "creative-gradient",
      typography: %{
        font_family: "Inter",
        font_size: "large",
        heading_weight: "bold",
        body_weight: "normal"
      },
      spacing: "spacious",
      card_style: "creative",
      dashboard_config: %{
        header_type: "creative",
        sidebar_style: "visual",
        card_layout: "featured",
        metrics_display: false,
        chart_style: "visual"
      },
      css_overrides: %{
        card_shadow: "0 8px 25px rgba(0, 0, 0, 0.15)",
        border_radius: "16px",
        header_bg: "rgba(255, 255, 255, 0.1)"
      }
    }
  end

  # CONSULTANT: Professional Services Dashboard
  defp consultant_config do
    %{
      layout: "dashboard",
      primary_color: "#2563eb",     # Blue-600
      secondary_color: "#059669",   # Emerald-600
      accent_color: "#dc2626",      # Red-600
      background: "consulting-professional",
      typography: %{
        font_family: "Inter",
        font_size: "base",
        heading_weight: "semibold",
        body_weight: "normal"
      },
      spacing: "normal",
      card_style: "consulting",
      dashboard_config: %{
        header_type: "consulting",
        sidebar_style: "professional",
        card_layout: "case-study",
        metrics_display: true,
        chart_style: "business"
      },
      css_overrides: %{
        card_shadow: "0 4px 6px -1px rgba(0, 0, 0, 0.1)",
        border_radius: "10px",
        header_bg: "rgba(227, 242, 253, 0.95)"
      }
    }
  end

  # ACADEMIC: Research Dashboard
  defp academic_config do
    %{
      layout: "dashboard",
      primary_color: "#047857",     # Emerald-700
      secondary_color: "#0891b2",   # Cyan-600
      accent_color: "#7c3aed",      # Violet-600
      background: "academic-clean",
      typography: %{
        font_family: "Merriweather",
        font_size: "base",
        heading_weight: "bold",
        body_weight: "normal"
      },
      spacing: "comfortable",
      card_style: "academic",
      dashboard_config: %{
        header_type: "academic",
        sidebar_style: "research",
        card_layout: "publication",
        metrics_display: true,
        chart_style: "academic"
      },
      css_overrides: %{
        card_shadow: "0 2px 8px rgba(0, 0, 0, 0.08)",
        border_radius: "8px",
        header_bg: "rgba(240, 249, 255, 0.95)"
      }
    }
  end

  # CORPORATE: Traditional Business Dashboard
  defp corporate_config do
    %{
      layout: "dashboard",
      primary_color: "#374151",     # Gray-700
      secondary_color: "#1f2937",   # Gray-800
      accent_color: "#3b82f6",      # Blue-500
      background: "corporate-traditional",
      typography: %{
        font_family: "Inter",
        font_size: "base",
        heading_weight: "semibold",
        body_weight: "normal"
      },
      spacing: "normal",
      card_style: "traditional",
      dashboard_config: %{
        header_type: "corporate",
        sidebar_style: "traditional",
        card_layout: "structured",
        metrics_display: true,
        chart_style: "corporate"
      },
      css_overrides: %{
        card_shadow: "0 1px 3px rgba(0, 0, 0, 0.1)",
        border_radius: "6px",
        header_bg: "rgba(249, 250, 251, 0.95)"
      }
    }
  end

  # CREATIVE: Artistic Dashboard
  defp creative_config do
    %{
      layout: "dashboard",
      primary_color: "#7c3aed",     # Violet-600
      secondary_color: "#ec4899",   # Pink-500
      accent_color: "#f59e0b",      # Amber-500
      background: "artistic-bold",
      typography: %{
        font_family: "Playfair Display",
        font_size: "large",
        heading_weight: "bold",
        body_weight: "normal"
      },
      spacing: "spacious",
      card_style: "artistic",
      dashboard_config: %{
        header_type: "artistic",
        sidebar_style: "creative",
        card_layout: "gallery",
        metrics_display: false,
        chart_style: "artistic"
      },
      css_overrides: %{
        card_shadow: "0 10px 30px rgba(0, 0, 0, 0.2)",
        border_radius: "20px",
        header_bg: "rgba(255, 255, 255, 0.15)"
      }
    }
  end

  # MINIMALIST: Clean Dashboard
  defp minimalist_config do
    %{
      layout: "dashboard",
      primary_color: "#374151",     # Gray-700
      secondary_color: "#6b7280",   # Gray-500
      accent_color: "#3b82f6",      # Blue-500
      background: "minimal-white",
      typography: %{
        font_family: "Inter",
        font_size: "base",
        heading_weight: "normal",
        body_weight: "light"
      },
      spacing: "comfortable",
      card_style: "minimal",
      dashboard_config: %{
        header_type: "minimal",
        sidebar_style: "clean",
        card_layout: "simple",
        metrics_display: false,
        chart_style: "minimal"
      },
      css_overrides: %{
        card_shadow: "0 1px 3px rgba(0, 0, 0, 0.05)",
        border_radius: "4px",
        header_bg: "rgba(255, 255, 255, 0.95)"
      }
    }
  end

  # ENHANCED: Helper functions for comprehensive styling

  def get_dashboard_layout_classes(config) do
    base = "grid gap-6 auto-rows-min"

    case config.dashboard_config.card_layout do
      "grid" -> "#{base} grid-cols-1 lg:grid-cols-3 xl:grid-cols-4"
      "masonry" -> "#{base} grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
      "featured" -> "#{base} grid-cols-1 lg:grid-cols-2"
      "case-study" -> "#{base} grid-cols-1 lg:grid-cols-2 xl:grid-cols-3"
      "publication" -> "#{base} grid-cols-1 lg:grid-cols-2"
      "structured" -> "#{base} grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
      "gallery" -> "#{base} grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
      "simple" -> "#{base} grid-cols-1 lg:grid-cols-2 xl:grid-cols-3"
      _ -> "#{base} grid-cols-1 lg:grid-cols-2 xl:grid-cols-3"
    end
  end

  def get_card_classes(config) do
    base = "bg-white rounded-xl shadow-lg border transition-all duration-300 hover:shadow-xl"
    overrides = config[:css_overrides] || %{}

    shadow = overrides[:card_shadow] || "0 4px 6px -1px rgba(0, 0, 0, 0.1)"
    radius = overrides[:border_radius] || "12px"

    case config.card_style do
      "corporate" -> "#{base} border-slate-200 hover:border-slate-300"
      "technical" -> "#{base} border-gray-200 bg-gray-50 hover:border-gray-300"
      "creative" -> "#{base} border-indigo-200 hover:border-indigo-300 hover:scale-[1.02]"
      "consulting" -> "#{base} border-blue-200 hover:border-blue-300"
      "academic" -> "#{base} border-emerald-200 hover:border-emerald-300"
      "traditional" -> "#{base} border-gray-200 hover:border-gray-300"
      "artistic" -> "#{base} border-purple-200 hover:border-purple-300 hover:scale-[1.02]"
      "minimal" -> "#{base} border-gray-100 hover:border-gray-200 shadow-sm hover:shadow-md"
      _ -> "#{base} border-gray-200 hover:border-gray-300"
    end
  end

  def get_header_classes(config) do
    base = "border-b bg-white/95 backdrop-blur-sm sticky top-0 z-40"
    overrides = config[:css_overrides] || %{}
    header_bg = overrides[:header_bg] || "rgba(255, 255, 255, 0.95)"

    case config.dashboard_config.header_type do
      "executive" -> "#{base} border-slate-200 shadow-sm"
      "technical" -> "#{base} border-gray-300 bg-gray-50/95"
      "creative" -> "#{base} border-indigo-200 bg-gradient-to-r from-indigo-50/95 to-violet-50/95"
      "consulting" -> "#{base} border-blue-200 bg-blue-50/95"
      "academic" -> "#{base} border-emerald-200 bg-emerald-50/95"
      "corporate" -> "#{base} border-gray-200 bg-gray-50/95"
      "artistic" -> "#{base} border-purple-200 bg-gradient-to-r from-purple-50/95 to-pink-50/95"
      "minimal" -> "#{base} border-gray-100 shadow-none"
      _ -> "#{base} border-gray-200"
    end
  end

  def get_background_classes(config) do
    case config.background do
      "corporate-clean" -> "bg-slate-50"
      "tech-dark" -> "bg-gray-100"
      "creative-gradient" -> "bg-gradient-to-br from-indigo-50 via-white to-violet-50"
      "consulting-professional" -> "bg-gradient-to-br from-blue-50 to-indigo-50"
      "academic-clean" -> "bg-gradient-to-br from-emerald-50 to-teal-50"
      "corporate-traditional" -> "bg-gray-50"
      "artistic-bold" -> "bg-gradient-to-br from-purple-50 via-white to-pink-50"
      "minimal-white" -> "bg-white"
      _ -> "bg-gray-50"
    end
  end

  def get_typography_classes(config) do
    font = case config.typography.font_family do
      "JetBrains Mono" -> "font-mono"
      "Playfair Display" -> "font-serif"
      "Merriweather" -> "font-serif"
      _ -> "font-sans"
    end

    size = case config.typography.font_size do
      "small" -> "text-sm"
      "base" -> "text-base"
      "large" -> "text-lg"
      _ -> "text-base"
    end

    "#{font} #{size}"
  end

  def get_spacing_classes(config) do
    case config.spacing do
      "compact" -> "space-y-4 p-4"
      "normal" -> "space-y-6 p-6"
      "comfortable" -> "space-y-8 p-6"
      "spacious" -> "space-y-12 p-8"
      _ -> "space-y-6 p-6"
    end
  end

  def get_metrics_config(config) do
    if config.dashboard_config.metrics_display do
      %{
        show_stats: true,
        chart_type: config.dashboard_config.chart_style,
        layout: "dashboard"
      }
    else
      %{
        show_stats: false,
        chart_type: "none",
        layout: "simple"
      }
    end
  end

  # ENHANCED: CSS Generation for real-time updates
  def generate_template_css(template_config, user_overrides \\ %{}) do
    # Merge template config with user customizations
    primary_color = user_overrides["primary_color"] || template_config[:primary_color] || "#3b82f6"
    secondary_color = user_overrides["secondary_color"] || template_config[:secondary_color] || "#64748b"
    accent_color = user_overrides["accent_color"] || template_config[:accent_color] || "#f59e0b"

    # Typography
    typography = user_overrides["typography"] || template_config[:typography] || %{}
    font_family = typography["font_family"] || typography[:font_family] || "Inter"

    # Background
    background = user_overrides["background"] || template_config[:background] || "default"

    # CSS overrides from template
    css_overrides = template_config[:css_overrides] || %{}

    font_family_css = get_font_family_css(font_family)
    background_css = get_background_css_for_template(background, template_config)

    """
    :root {
      --portfolio-primary-color: #{primary_color};
      --portfolio-secondary-color: #{secondary_color};
      --portfolio-accent-color: #{accent_color};
      --portfolio-font-family: #{font_family_css};
      --portfolio-card-shadow: #{css_overrides[:card_shadow] || "0 4px 6px -1px rgba(0, 0, 0, 0.1)"};
      --portfolio-border-radius: #{css_overrides[:border_radius] || "12px"};
      --portfolio-header-bg: #{css_overrides[:header_bg] || "rgba(255, 255, 255, 0.95)"};
    }

    /* Apply template-specific styling */
    .portfolio-card {
      box-shadow: var(--portfolio-card-shadow) !important;
      border-radius: var(--portfolio-border-radius) !important;
    }

    .portfolio-header {
      background: var(--portfolio-header-bg) !important;
      backdrop-filter: blur(8px) !important;
    }

    #{background_css}
    """
  end

  defp get_font_family_css(font_family) do
    case font_family do
      "Inter" -> "'Inter', system-ui, sans-serif"
      "Merriweather" -> "'Merriweather', Georgia, serif"
      "JetBrains Mono" -> "'JetBrains Mono', 'Fira Code', monospace"
      "Playfair Display" -> "'Playfair Display', Georgia, serif"
      _ -> "system-ui, sans-serif"
    end
  end

  defp get_background_css_for_template(background, template_config) do
    case background do
      "gradient-ocean" ->
        ".portfolio-bg { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important; }"
      "gradient-sunset" ->
        ".portfolio-bg { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%) !important; }"
      "dark-mode" ->
        ".portfolio-bg { background: #1a1a1a !important; color: #ffffff !important; }"
      _ ->
        case template_config[:background] do
          "corporate-clean" -> ".portfolio-bg { background: #f8fafc !important; }"
          "tech-dark" -> ".portfolio-bg { background: #1f2937 !important; color: #f9fafb !important; }"
          "creative-gradient" -> ".portfolio-bg { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important; }"
          "consulting-professional" -> ".portfolio-bg { background: linear-gradient(135deg, #e3f2fd 0%, #f3e5f5 100%) !important; }"
          "academic-clean" -> ".portfolio-bg { background: linear-gradient(135deg, #f0f9ff 0%, #ecfdf5 100%) !important; }"
          _ -> ".portfolio-bg { background: #ffffff !important; }"
        end
    end
  end
end
