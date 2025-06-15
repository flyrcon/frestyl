# lib/frestyl/portfolios/portfolio_templates.ex - COMPLETELY FIXED VERSION

defmodule Frestyl.Portfolios.PortfolioTemplates do
  @moduledoc """
  Portfolio template configurations with professional dashboard-style layouts
  """

  def available_templates do
    [
      {"executive", %{
        name: "Executive",
        description: "Professional corporate dashboard with metrics and KPIs",
        preview_color: "from-slate-600 to-slate-700",
        features: ["Executive summary", "Key metrics", "Leadership roles", "Strategic initiatives"]
      }},
      {"developer", %{
        name: "Developer",
        description: "Technical dashboard with code portfolio and project metrics",
        preview_color: "from-gray-700 to-gray-800",
        features: ["Code repositories", "Technical stack", "Project demos", "Performance metrics"]
      }},
      {"designer", %{
        name: "Designer",
        description: "Creative dashboard with visual portfolio and case studies",
        preview_color: "from-indigo-500 to-purple-600",
        features: ["Visual portfolio", "Design process", "Case studies", "Client projects"]
      }},
      {"consultant", %{
        name: "Consultant",
        description: "Professional services dashboard with client results and expertise",
        preview_color: "from-blue-600 to-blue-700",
        features: ["Client results", "Industry expertise", "Case studies", "Success metrics"]
      }},
      {"academic", %{
        name: "Academic",
        description: "Research-focused dashboard with publications and academic achievements",
        preview_color: "from-emerald-600 to-teal-600",
        features: ["Publications", "Research projects", "Academic roles", "Citations"]
      }},
      {"corporate", %{
        name: "Corporate",
        description: "Traditional business dashboard with structured layout",
        preview_color: "from-gray-500 to-gray-600",
        features: ["Professional timeline", "Company roles", "Industry expertise", "Achievements"]
      }},
      {"creative", %{
        name: "Creative",
        description: "Bold artistic dashboard with visual storytelling",
        preview_color: "from-purple-600 to-pink-600",
        features: ["Visual portfolio", "Creative projects", "Artistic journey", "Inspiration"]
      }},
      {"minimalist", %{
        name: "Minimalist",
        description: "Clean, typography-focused dashboard with minimal distractions",
        preview_color: "from-gray-300 to-gray-400",
        features: ["Clean layout", "Typography focus", "Essential content", "Distraction-free"]
      }}
    ]
  end

  def get_template_config(theme) do
    case theme do
      "executive" -> executive_config()
      "developer" -> developer_config()
      "designer" -> designer_config()
      "consultant" -> consultant_config()  # FIXED: Now properly maps
      "academic" -> academic_config()
      "corporate" -> corporate_config()   # NEW
      "creative" -> creative_config()     # NEW
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
      }
    }
  end

  # CONSULTANT: Professional Services Dashboard (FIXED)
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
      }
    }
  end

  # NEW: CORPORATE: Traditional Business Dashboard
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
      }
    }
  end

  # NEW: CREATIVE: Artistic Dashboard
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
      }
    }
  end

  # Helper functions for styling

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
end
