# lib/frestyl/portfolios/portfolio_templates.ex - REDESIGNED TEMPLATE SYSTEM

defmodule Frestyl.Portfolios.PortfolioTemplates do
  @moduledoc """
  Redesigned portfolio template system with category-based templates,
  mobile-first responsive design, and comprehensive customization options.
  """

  def available_templates do
    %{
      "minimalist_clean" => %{
        name: "Clean",
        description: "Ultra-clean design with maximum white space and typography focus",
        features: ["Typography-focused", "Maximum white space", "Distraction-free", "Mobile-optimized"],
        category: "Minimalist",
        icon: "⚪",
        preview_color: "from-gray-100 to-gray-200",
        mobile_optimized: true
      },
      "minimalist_elegant" => %{
        name: "Elegant",
        description: "Sophisticated minimalism with subtle accents and refined spacing",
        features: ["Subtle accents", "Refined typography", "Elegant spacing", "Premium feel"],
        category: "Minimalist",
        icon: "◽",
        preview_color: "from-slate-50 to-slate-100",
        mobile_optimized: true
      },
      "professional_corporate" => %{
        name: "Corporate",
        description: "Traditional business layout with structured sections and formal presentation",
        features: ["Structured layout", "Business metrics", "Professional timeline", "Corporate styling"],
        category: "Professional",
        icon: "🏢",
        preview_color: "from-blue-600 to-blue-700",
        mobile_optimized: true
      },
      "professional_executive" => %{
        name: "Executive",
        description: "Executive dashboard with KPIs, achievements, and leadership focus",
        features: ["Executive summary", "Key metrics", "Leadership showcase", "Results-focused"],
        category: "Professional",
        icon: "📊",
        preview_color: "from-slate-600 to-slate-700",
        mobile_optimized: true
      },
      "creative_artistic" => %{
        name: "Artistic",
        description: "Bold visual design with dynamic layouts and creative expression",
        features: ["Visual storytelling", "Dynamic layouts", "Creative showcase", "Artistic flair"],
        category: "Creative",
        icon: "🎨",
        preview_color: "from-purple-600 to-pink-600",
        mobile_optimized: true
      },
      "creative_designer" => %{
        name: "Designer",
        description: "Designer-focused layout with portfolio showcase and case study emphasis",
        features: ["Portfolio showcase", "Case studies", "Design process", "Visual hierarchy"],
        category: "Creative",
        icon: "✨",
        preview_color: "from-indigo-500 to-purple-600",
        mobile_optimized: true
      },
      "technical_developer" => %{
        name: "Developer",
        description: "Code-focused layout with technical projects and development showcase",
        features: ["Code showcase", "Technical stack", "Project demos", "Development metrics"],
        category: "Technical",
        icon: "💻",
        preview_color: "from-green-600 to-teal-600",
        mobile_optimized: true
      },
      "technical_engineer" => %{
        name: "Engineer",
        description: "Engineering-focused with problem-solving emphasis and technical depth",
        features: ["Problem solving", "Technical depth", "Engineering process", "System design"],
        category: "Technical",
        icon: "⚙️",
        preview_color: "from-gray-700 to-gray-800",
        mobile_optimized: true
      }
    }
  end

  # Also add this function to help with layout selection:
  def get_available_layouts do
    [
      {"dashboard", %{
        name: "Dashboard",
        description: "Modern grid-based layout",
        features: ["Grid Layout", "Card-based", "Responsive", "Professional"]
      }},
      {"gallery", %{
        name: "Gallery",
        description: "Visual masonry-style layout",
        features: ["Masonry", "Image Focus", "Creative"]
      }},
      {"timeline", %{
        name: "Timeline",
        description: "Chronological vertical layout with story features",
        features: ["Timeline", "Chronological", "Story", "Narrative"]
      }},
      {"minimal", %{
        name: "Minimal",
        description: "Clean single-column layout",
        features: ["Single Column", "Clean", "Focus"]
      }},
      {"corporate", %{
        name: "Corporate",
        description: "Structured business layout",
        features: ["Structured", "Professional", "Formal"]
      }},
      {"creative", %{
        name: "Creative",
        description: "Dynamic asymmetric layout",
        features: ["Asymmetric", "Dynamic", "Bold"]
      }},
      {"terminal", %{
        name: "Terminal",
        description: "Developer-focused terminal theme",
        features: ["Code Style", "Dark Theme", "Technical"]
      }}
    ]
  end

  # MINIMALIST CLEAN
  defp minimalist_clean_config do
    %{
      layout: "minimalist_clean",
      category: "minimalist",
      primary_color: "#1f2937",     # Gray-800
      secondary_color: "#6b7280",   # Gray-500
      accent_color: "#3b82f6",      # Blue-500
      background: "minimal_white",
      typography: %{
        font_family: "Inter",
        font_size: "base",
        heading_weight: "light",
        body_weight: "light",
        line_height: "relaxed"
      },
      spacing: "spacious",
      card_style: "minimal_clean",
      header_config: %{
        layout: "centered",
        show_avatar: true,
        show_metrics: false,
        show_social: true,
        video_style: "minimal"
      },
      mobile_config: %{
        header_collapse: true,
        sidebar_style: "minimal",
        card_stacking: "single"
      }
    }
  end

  # MINIMALIST ELEGANT
  defp minimalist_elegant_config do
    %{
      layout: "minimalist_elegant",
      category: "minimalist",
      primary_color: "#0f172a",     # Slate-900
      secondary_color: "#475569",   # Slate-600
      accent_color: "#8b5cf6",      # Violet-500
      background: "minimal_elegant",
      typography: %{
        font_family: "Inter",
        font_size: "base",
        heading_weight: "normal",
        body_weight: "light",
        line_height: "loose"
      },
      spacing: "comfortable",
      card_style: "minimal_elegant",
      header_config: %{
        layout: "split",
        show_avatar: true,
        show_metrics: true,
        show_social: true,
        video_style: "elegant"
      },
      mobile_config: %{
        header_collapse: true,
        sidebar_style: "elegant",
        card_stacking: "single"
      }
    }
  end

  # PROFESSIONAL CORPORATE
  defp professional_corporate_config do
    %{
      layout: "professional_corporate",
      category: "professional",
      primary_color: "#1e40af",     # Blue-800
      secondary_color: "#374151",   # Gray-700
      accent_color: "#059669",      # Emerald-600
      background: "professional_clean",
      typography: %{
        font_family: "Inter",
        font_size: "base",
        heading_weight: "semibold",
        body_weight: "normal",
        line_height: "normal"
      },
      spacing: "normal",
      card_style: "professional_corporate",
      header_config: %{
        layout: "business",
        show_avatar: true,
        show_metrics: true,
        show_social: true,
        video_style: "professional"
      },
      mobile_config: %{
        header_collapse: false,
        sidebar_style: "corporate",
        card_stacking: "double"
      }
    }
  end

  # PROFESSIONAL EXECUTIVE
  defp professional_executive_config do
    %{
      layout: "professional_executive",
      category: "professional",
      primary_color: "#334155",     # Slate-700
      secondary_color: "#1e293b",   # Slate-800
      accent_color: "#dc2626",      # Red-600
      background: "executive_dashboard",
      typography: %{
        font_family: "Inter",
        font_size: "base",
        heading_weight: "bold",
        body_weight: "medium",
        line_height: "tight"
      },
      spacing: "compact",
      card_style: "executive_dashboard",
      header_config: %{
        layout: "executive",
        show_avatar: true,
        show_metrics: true,
        show_social: true,
        video_style: "executive"
      },
      mobile_config: %{
        header_collapse: false,
        sidebar_style: "executive",
        card_stacking: "double"
      }
    }
  end

  # CREATIVE ARTISTIC
  defp creative_artistic_config do
    %{
      layout: "creative_artistic",
      category: "creative",
      primary_color: "#7c3aed",     # Violet-600
      secondary_color: "#ec4899",   # Pink-500
      accent_color: "#f59e0b",      # Amber-500
      background: "creative_bold",
      typography: %{
        font_family: "Playfair Display",
        font_size: "large",
        heading_weight: "bold",
        body_weight: "normal",
        line_height: "relaxed"
      },
      spacing: "dynamic",
      card_style: "creative_artistic",
      header_config: %{
        layout: "creative",
        show_avatar: true,
        show_metrics: false,
        show_social: true,
        video_style: "artistic"
      },
      mobile_config: %{
        header_collapse: true,
        sidebar_style: "creative",
        card_stacking: "masonry"
      }
    }
  end

  # CREATIVE DESIGNER
  defp creative_designer_config do
    %{
      layout: "creative_designer",
      category: "creative",
      primary_color: "#4f46e5",     # Indigo-600
      secondary_color: "#8b5cf6",   # Violet-500
      accent_color: "#06b6d4",      # Cyan-500
      background: "designer_gradient",
      typography: %{
        font_family: "Inter",
        font_size: "base",
        heading_weight: "semibold",
        body_weight: "normal",
        line_height: "normal"
      },
      spacing: "visual",
      card_style: "designer_showcase",
      header_config: %{
        layout: "portfolio",
        show_avatar: true,
        show_metrics: true,
        show_social: true,
        video_style: "showcase"
      },
      mobile_config: %{
        header_collapse: true,
        sidebar_style: "visual",
        card_stacking: "masonry"
      }
    }
  end

  # TECHNICAL DEVELOPER
  defp technical_developer_config do
    %{
      layout: "technical_developer",
      category: "technical",
      primary_color: "#1f2937",     # Gray-800
      secondary_color: "#10b981",   # Emerald-500
      accent_color: "#6366f1",      # Indigo-500
      background: "tech_terminal",
      typography: %{
        font_family: "JetBrains Mono",
        font_size: "base",
        heading_weight: "semibold",
        body_weight: "normal",
        line_height: "normal"
      },
      spacing: "code",
      card_style: "tech_terminal",
      header_config: %{
        layout: "terminal",
        show_avatar: true,
        show_metrics: true,
        show_social: true,
        video_style: "terminal"
      },
      mobile_config: %{
        header_collapse: false,
        sidebar_style: "terminal",
        card_stacking: "stack"
      }
    }
  end

  # TECHNICAL ENGINEER
  defp technical_engineer_config do
    %{
      layout: "technical_engineer",
      category: "technical",
      primary_color: "#374151",     # Gray-700
      secondary_color: "#0891b2",   # Cyan-600
      accent_color: "#f59e0b",      # Amber-500
      background: "engineering_grid",
      typography: %{
        font_family: "Inter",
        font_size: "base",
        heading_weight: "medium",
        body_weight: "normal",
        line_height: "normal"
      },
      spacing: "systematic",
      card_style: "engineering_precise",
      header_config: %{
        layout: "engineering",
        show_avatar: true,
        show_metrics: true,
        show_social: true,
        video_style: "technical"
      },
      mobile_config: %{
        header_collapse: false,
        sidebar_style: "engineering",
        card_stacking: "grid"
      }
    }
  end

  # HELPER FUNCTIONS

  def get_template_config(theme) do
    case theme do
      # Minimalist templates
      "minimalist_clean" -> %{
        "layout" => "minimal",
        "primary_color" => "#000000",
        "secondary_color" => "#6b7280",
        "accent_color" => "#374151"
      }
      "minimalist_elegant" -> %{
        "layout" => "minimal",
        "primary_color" => "#1f2937",
        "secondary_color" => "#6b7280",
        "accent_color" => "#9ca3af"
      }

      # Professional templates
      "professional_corporate" -> %{
        "layout" => "corporate",
        "primary_color" => "#1e40af",
        "secondary_color" => "#64748b",
        "accent_color" => "#3b82f6"
      }
      "professional_executive" -> %{
        "layout" => "dashboard",
        "primary_color" => "#374151",
        "secondary_color" => "#6b7280",
        "accent_color" => "#4f46e5"
      }

      # Creative templates
      "creative_artistic" -> %{
        "layout" => "creative",
        "primary_color" => "#7c3aed",
        "secondary_color" => "#ec4899",
        "accent_color" => "#f59e0b"
      }
      "creative_designer" -> %{
        "layout" => "gallery",
        "primary_color" => "#4f46e5",
        "secondary_color" => "#7c3aed",
        "accent_color" => "#ec4899"
      }

      # Technical templates
      "technical_developer" -> %{
        "layout" => "terminal",
        "primary_color" => "#059669",
        "secondary_color" => "#374151",
        "accent_color" => "#10b981"
      }
      "technical_engineer" -> %{
        "layout" => "dashboard",
        "primary_color" => "#374151",
        "secondary_color" => "#4b5563",
        "accent_color" => "#6b7280"
      }

      # Legacy template names (for backward compatibility)
      "executive" -> %{
        "layout" => "dashboard",
        "primary_color" => "#1e40af",
        "secondary_color" => "#64748b",
        "accent_color" => "#3b82f6"
      }
      "developer" -> %{
        "layout" => "terminal",
        "primary_color" => "#059669",
        "secondary_color" => "#374151",
        "accent_color" => "#10b981"
      }
      "designer" -> %{
        "layout" => "gallery",
        "primary_color" => "#7c3aed",
        "secondary_color" => "#ec4899",
        "accent_color" => "#f59e0b"
      }
      "minimalist" -> %{
        "layout" => "minimal",
        "primary_color" => "#000000",
        "secondary_color" => "#6b7280",
        "accent_color" => "#374151"
      }

      # Default fallback
      _ -> %{
        "layout" => "dashboard",
        "primary_color" => "#3b82f6",
        "secondary_color" => "#64748b",
        "accent_color" => "#f59e0b"
      }
    end
  end

  defp get_available_templates_safe do
    case Code.ensure_loaded(Frestyl.Portfolios.PortfolioTemplates) do
      {:module, _} ->
        try do
          apply(Frestyl.Portfolios.PortfolioTemplates, :available_templates, [])
        rescue
          UndefinedFunctionError ->
            get_fallback_templates()
        end
      {:error, _} ->
        get_fallback_templates()
    end
  end

  defp get_fallback_templates do
    %{
      "executive" => %{name: "Executive", category: "business"},
      "developer" => %{name: "Developer", category: "technical"},
      "designer" => %{name: "Designer", category: "creative"},
      "minimalist" => %{name: "Minimalist", category: "minimal"}
    }
  end

  def get_mobile_layout_classes(config) do
    case config.mobile_config.card_stacking do
      "single" -> "grid grid-cols-1 gap-6"
      "double" -> "grid grid-cols-1 sm:grid-cols-2 gap-6"
      "masonry" -> "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6"
      "stack" -> "flex flex-col gap-6"
      "grid" -> "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6"
      _ -> "grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6"
    end
  end

  def get_desktop_layout_classes(config) do
    base = "grid gap-6 auto-rows-min"

    case config.layout do
      "minimalist_clean" -> "#{base} grid-cols-1 lg:grid-cols-2 max-w-4xl mx-auto"
      "minimalist_elegant" -> "#{base} grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 max-w-6xl mx-auto"
      "professional_corporate" -> "#{base} grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
      "professional_executive" -> "#{base} grid-cols-1 lg:grid-cols-3 xl:grid-cols-4"
      "creative_artistic" -> "#{base} grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
      "creative_designer" -> "#{base} grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
      "technical_developer" -> "#{base} grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
      "technical_engineer" -> "#{base} grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
      _ -> "#{base} grid-cols-1 lg:grid-cols-2 xl:grid-cols-3"
    end
  end

  def get_header_layout_classes(config) do
    case config.header_config.layout do
      "centered" -> "text-center max-w-4xl mx-auto"
      "split" -> "grid lg:grid-cols-2 gap-12 items-center max-w-7xl mx-auto"
      "business" -> "grid lg:grid-cols-3 gap-8 items-start max-w-7xl mx-auto"
      "executive" -> "grid lg:grid-cols-12 gap-8 items-center max-w-7xl mx-auto"
      "creative" -> "text-center max-w-6xl mx-auto"
      "portfolio" -> "grid lg:grid-cols-5 gap-8 items-center max-w-7xl mx-auto"
      "terminal" -> "max-w-6xl mx-auto"
      "engineering" -> "grid lg:grid-cols-2 gap-12 items-start max-w-7xl mx-auto"
      _ -> "max-w-7xl mx-auto"
    end
  end

  def get_card_classes(config) do
    base_mobile = "portfolio-card overflow-hidden transition-all duration-300"

    case config.card_style do
      "minimal_clean" -> "#{base_mobile} bg-white rounded-none border-0 shadow-none hover:shadow-sm"
      "minimal_elegant" -> "#{base_mobile} bg-white rounded-lg border border-gray-100 shadow-sm hover:shadow-md"
      "professional_corporate" -> "#{base_mobile} bg-white rounded-xl border border-gray-200 shadow-lg hover:shadow-xl hover:border-blue-300"
      "executive_dashboard" -> "#{base_mobile} bg-white rounded-xl border border-slate-200 shadow-lg hover:shadow-xl hover:border-slate-400"
      "creative_artistic" -> "#{base_mobile} bg-white/90 backdrop-blur-sm rounded-2xl border border-purple-200 shadow-xl hover:shadow-2xl hover:scale-[1.02]"
      "designer_showcase" -> "#{base_mobile} bg-white rounded-2xl border border-indigo-200 shadow-lg hover:shadow-xl hover:border-indigo-300"
      "tech_terminal" -> "#{base_mobile} bg-gray-900 rounded-lg border border-gray-700 shadow-lg hover:shadow-xl hover:border-green-500"
      "engineering_precise" -> "#{base_mobile} bg-white rounded-lg border border-gray-300 shadow-md hover:shadow-lg hover:border-cyan-400"
      _ -> "#{base_mobile} bg-white rounded-xl border border-gray-200 shadow-lg hover:shadow-xl"
    end
  end

  def get_background_classes(config) do
    case config.background do
      "minimal_white" -> "bg-white"
      "minimal_elegant" -> "bg-gradient-to-br from-slate-50 to-gray-50"
      "professional_clean" -> "bg-gradient-to-br from-blue-50 to-white"
      "executive_dashboard" -> "bg-gradient-to-br from-slate-50 via-white to-blue-50"
      "creative_bold" -> "bg-gradient-to-br from-purple-600 via-pink-600 to-orange-500"
      "designer_gradient" -> "bg-gradient-to-br from-indigo-50 via-purple-50 to-pink-50"
      "tech_terminal" -> "bg-gray-900"
      "engineering_grid" -> "bg-gradient-to-br from-gray-50 to-slate-100"
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

    line_height = case config.typography.line_height do
      "tight" -> "leading-tight"
      "normal" -> "leading-normal"
      "relaxed" -> "leading-relaxed"
      "loose" -> "leading-loose"
      _ -> "leading-normal"
    end

    "#{font} #{size} #{line_height}"
  end

  def get_spacing_classes(config) do
    case config.spacing do
      "compact" -> "space-y-4 p-4"
      "normal" -> "space-y-6 p-6"
      "comfortable" -> "space-y-8 p-6"
      "spacious" -> "space-y-12 p-8"
      "dynamic" -> "space-y-6 sm:space-y-8 lg:space-y-12 p-4 sm:p-6 lg:p-8"
      "visual" -> "space-y-8 p-6"
      "code" -> "space-y-4 p-4"
      "systematic" -> "space-y-6 p-6"
      _ -> "space-y-6 p-6"
    end
  end

  def should_show_header_metrics?(config) do
    config.header_config.show_metrics
  end

  def should_show_header_social?(config) do
    config.header_config.show_social
  end

  def get_video_style_classes(config) do
    case config.header_config.video_style do
      "minimal" -> "rounded-lg border border-gray-200"
      "elegant" -> "rounded-xl border border-slate-200 shadow-lg"
      "professional" -> "rounded-xl border border-blue-200 shadow-xl"
      "executive" -> "rounded-xl border border-slate-300 shadow-2xl"
      "artistic" -> "rounded-2xl border-2 border-purple-300 shadow-2xl"
      "showcase" -> "rounded-2xl border border-indigo-200 shadow-xl"
      "terminal" -> "rounded-lg border border-green-500 shadow-lg"
      "technical" -> "rounded-lg border border-cyan-400 shadow-lg"
      _ -> "rounded-xl border border-gray-200 shadow-lg"
    end
  end

  def get_sidebar_classes(config) do
    case config.mobile_config.sidebar_style do
      "minimal" -> "bg-white/95 backdrop-blur-sm border-r border-gray-100"
      "elegant" -> "bg-slate-50/95 backdrop-blur-sm border-r border-slate-200"
      "corporate" -> "bg-blue-50/95 backdrop-blur-sm border-r border-blue-200"
      "executive" -> "bg-slate-100/95 backdrop-blur-sm border-r border-slate-300"
      "creative" -> "bg-gradient-to-b from-purple-50/95 to-pink-50/95 backdrop-blur-sm border-r border-purple-200"
      "visual" -> "bg-indigo-50/95 backdrop-blur-sm border-r border-indigo-200"
      "terminal" -> "bg-gray-900/95 backdrop-blur-sm border-r border-green-500"
      "engineering" -> "bg-gray-50/95 backdrop-blur-sm border-r border-gray-300"
      _ -> "bg-white/95 backdrop-blur-sm border-r border-gray-200"
    end
  end
end
