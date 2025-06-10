# lib/frestyl/portfolios/portfolio_templates.ex - UPDATED with FIXED consultant and new templates

defmodule Frestyl.Portfolios.PortfolioTemplates do
  @moduledoc """
  Portfolio template configurations with subtle, professional color schemes
  """

  def available_templates do
    %{
      "executive" => %{
        name: "Executive",
        description: "Clean corporate design with professional metrics",
        icon: "💼",
        preview_color: "from-slate-700 to-slate-800",
        layout_type: "dashboard",
        features: ["Executive summary", "Leadership metrics", "Board positions", "Strategic initiatives"],
        best_for: "C-level executives, senior management, and business leaders"
      },
      "developer" => %{
        name: "Developer",
        description: "Code-focused interface with technical elements",
        icon: "⚡",
        preview_color: "from-gray-800 to-gray-900",
        layout_type: "terminal",
        features: ["Code repositories", "Technical skills", "Project demos", "GitHub integration"],
        best_for: "Software engineers, programmers, and technical professionals"
      },
      "designer" => %{
        name: "Designer",
        description: "Visual portfolio with clean gallery layout",
        icon: "🎨",
        preview_color: "from-indigo-500 to-indigo-600",
        layout_type: "gallery",
        features: ["Visual portfolio", "Case studies", "Design process", "Creative projects"],
        best_for: "UI/UX designers, graphic designers, and creative professionals"
      },
      # FIXED: Consultant template (was incorrectly mapped to creative)
      "consultant" => %{
        name: "Consultant",
        description: "Professional services with case study focus",
        icon: "📊",
        preview_color: "from-blue-600 to-blue-700",
        layout_type: "case_study",
        features: ["Case studies", "Industry expertise", "Client results", "Methodology"],
        best_for: "Business consultants, advisors, and strategic professionals"
      },
      "academic" => %{
        name: "Academic",
        description: "Research-focused with publication highlights",
        icon: "🎓",
        preview_color: "from-emerald-600 to-emerald-700",
        layout_type: "research",
        features: ["Publications", "Research projects", "Academic background", "Teaching experience"],
        best_for: "Researchers, professors, and academic professionals"
      },
      "freelancer" => %{
        name: "Freelancer",
        description: "Service-oriented with client testimonials",
        icon: "💡",
        preview_color: "from-teal-600 to-teal-700",
        layout_type: "services",
        features: ["Service offerings", "Client testimonials", "Availability", "Pricing"],
        best_for: "Independent contractors, consultants, and service providers"
      },
      # NEW: Photographer template with black background
      "photographer" => %{
        name: "Photographer",
        description: "Visual-first with elegant image galleries",
        icon: "📸",
        preview_color: "from-gray-900 to-black",
        layout_type: "fullscreen",
        features: ["Photo galleries", "Visual stories", "Client work", "Equipment expertise"],
        best_for: "Professional photographers, visual artists, and media creators"
      },
      # NEW: Minimalist templates
      "minimalist" => %{
        name: "Minimalist",
        description: "Clean typography-focused design",
        icon: "📝",
        preview_color: "from-gray-300 to-gray-400",
        layout_type: "typography",
        features: ["Clean layout", "Typography focus", "Minimal distractions", "Content first"],
        best_for: "Writers, academics, and content-focused professionals"
      },
      # NEW: Artist template
      "artist" => %{
        name: "Artist",
        description: "Creative expression with bold visuals",
        icon: "🎭",
        preview_color: "from-purple-600 to-pink-600",
        layout_type: "creative",
        features: ["Artistic portfolio", "Creative projects", "Exhibition history", "Artist statement"],
        best_for: "Fine artists, sculptors, painters, and creative professionals"
      },
      # NEW: Zen minimalist variation
      "zen" => %{
        name: "Zen",
        description: "Ultra-minimal with serene aesthetics",
        icon: "🕯️",
        preview_color: "from-gray-200 to-gray-300",
        layout_type: "zen",
        features: ["Minimal design", "Peaceful colors", "Spacious layout", "Focus on content"],
        best_for: "Mindfulness coaches, wellness professionals, and minimalist creators"
      }
    }
  end

  def get_template_config(theme) do
    case theme do
      "executive" -> executive_config()
      "developer" -> developer_config()
      "designer" -> designer_config()
      "consultant" -> consultant_config()  # FIXED: Now properly maps to consultant
      "academic" -> academic_config()
      "freelancer" -> freelancer_config()
      "photographer" -> photographer_config()  # NEW
      "minimalist" -> minimalist_config()      # NEW
      "artist" -> artist_config()              # NEW
      "zen" -> zen_config()                    # NEW
      _ -> executive_config()
    end
  end

  # EXECUTIVE: Clean Corporate Style
  defp executive_config do
    %{
      layout: "dashboard",
      primary_color: "#334155",  # Slate-700
      secondary_color: "#3b82f6", # Blue-500
      accent_color: "#06b6d4",   # Cyan-500
      background: "clean-white",
      typography: %{
        font_family: "Inter",
        heading_weight: "font-bold",
        body_weight: "font-medium",
        heading_size: "text-2xl lg:text-3xl",
        body_size: "text-base"
      },
      layout_config: %{
        header_style: "corporate_header",
        section_layout: "cards_with_metrics",
        navigation: "sidebar",
        spacing: "comfortable"
      }
    }
  end

  # DEVELOPER: Terminal/Code Style
  defp developer_config do
    %{
      layout: "terminal",
      primary_color: "#1f2937",  # Gray-800
      secondary_color: "#10b981", # Emerald-500
      accent_color: "#6366f1",   # Indigo-500
      background: "subtle-dark",
      typography: %{
        font_family: "JetBrains Mono",
        heading_weight: "font-semibold",
        body_weight: "font-normal",
        heading_size: "text-xl lg:text-2xl",
        body_size: "text-sm"
      },
      layout_config: %{
        header_style: "terminal_header",
        section_layout: "code_blocks",
        navigation: "tabs",
        spacing: "compact"
      }
    }
  end

  # DESIGNER: Clean Visual Style
  defp designer_config do
    %{
      layout: "gallery",
      primary_color: "#4f46e5",  # Indigo-600
      secondary_color: "#8b5cf6", # Violet-500
      accent_color: "#f59e0b",   # Amber-500
      background: "subtle-gradient",
      typography: %{
        font_family: "Playfair Display",
        heading_weight: "font-bold",
        body_weight: "font-normal",
        heading_size: "text-3xl lg:text-4xl",
        body_size: "text-lg"
      },
      layout_config: %{
        header_style: "creative_header",
        section_layout: "masonry_grid",
        navigation: "floating",
        spacing: "spacious"
      }
    }
  end

  # CONSULTANT: Professional Blue (FIXED)
  defp consultant_config do
    %{
      layout: "case_study",
      primary_color: "#2563eb",  # Blue-600
      secondary_color: "#059669", # Emerald-600
      accent_color: "#dc2626",   # Red-600
      background: "professional-subtle",
      typography: %{
        font_family: "Inter",
        heading_weight: "font-semibold",
        body_weight: "font-normal",
        heading_size: "text-2xl lg:text-3xl",
        body_size: "text-base"
      },
      layout_config: %{
        header_style: "professional_header",
        section_layout: "story_blocks",
        navigation: "breadcrumb",
        spacing: "normal"
      }
    }
  end

  # ACADEMIC: Emerald Professional
  defp academic_config do
    %{
      layout: "research",
      primary_color: "#047857",  # Emerald-700
      secondary_color: "#0891b2", # Cyan-600
      accent_color: "#7c3aed",   # Violet-600
      background: "academic-clean",
      typography: %{
        font_family: "Merriweather",
        heading_weight: "font-bold",
        body_weight: "font-normal",
        heading_size: "text-2xl lg:text-3xl",
        body_size: "text-base"
      },
      layout_config: %{
        header_style: "academic_header",
        section_layout: "research_blocks",
        navigation: "academic_nav",
        spacing: "comfortable"
      }
    }
  end

  # FREELANCER: Teal Professional
  defp freelancer_config do
    %{
      layout: "services",
      primary_color: "#0d9488",  # Teal-600
      secondary_color: "#2563eb", # Blue-600
      accent_color: "#ea580c",   # Orange-600
      background: "service-clean",
      typography: %{
        font_family: "Inter",
        heading_weight: "font-semibold",
        body_weight: "font-normal",
        heading_size: "text-2xl lg:text-3xl",
        body_size: "text-base"
      },
      layout_config: %{
        header_style: "service_header",
        section_layout: "service_cards",
        navigation: "sticky_nav",
        spacing: "normal"
      }
    }
  end

  # NEW: PHOTOGRAPHER: Dark Elegant
  defp photographer_config do
    %{
      layout: "fullscreen",
      primary_color: "#ffffff",    # White text on dark
      secondary_color: "#d1d5db",  # Gray-300
      accent_color: "#f59e0b",     # Amber-500
      background: "photo-dark",
      typography: %{
        font_family: "Inter",
        heading_weight: "font-light",
        body_weight: "font-light",
        heading_size: "text-4xl lg:text-5xl",
        body_size: "text-lg"
      },
      layout_config: %{
        header_style: "overlay_header",
        section_layout: "fullscreen_slides",
        navigation: "dots",
        spacing: "none"
      }
    }
  end

  # NEW: MINIMALIST: Ultra Clean
  defp minimalist_config do
    %{
      layout: "typography",
      primary_color: "#374151",  # Gray-700
      secondary_color: "#6b7280", # Gray-500
      accent_color: "#3b82f6",   # Blue-500
      background: "minimal-white",
      typography: %{
        font_family: "Inter",
        heading_weight: "font-normal",
        body_weight: "font-normal",
        heading_size: "text-2xl lg:text-3xl",
        body_size: "text-base"
      },
      layout_config: %{
        header_style: "minimal_header",
        section_layout: "text_blocks",
        navigation: "minimal_nav",
        spacing: "comfortable"
      }
    }
  end

  # NEW: ARTIST: Creative Bold
  defp artist_config do
    %{
      layout: "creative",
      primary_color: "#7c3aed",  # Violet-600
      secondary_color: "#ec4899", # Pink-500
      accent_color: "#f59e0b",   # Amber-500
      background: "creative-gradient",
      typography: %{
        font_family: "Playfair Display",
        heading_weight: "font-bold",
        body_weight: "font-normal",
        heading_size: "text-4xl lg:text-5xl",
        body_size: "text-lg"
      },
      layout_config: %{
        header_style: "artistic_header",
        section_layout: "creative_blocks",
        navigation: "artistic_nav",
        spacing: "spacious"
      }
    }
  end

  # NEW: ZEN: Serene Minimal
  defp zen_config do
    %{
      layout: "zen",
      primary_color: "#4b5563",  # Gray-600
      secondary_color: "#9ca3af", # Gray-400
      accent_color: "#059669",   # Emerald-600
      background: "zen-minimal",
      typography: %{
        font_family: "Inter",
        heading_weight: "font-light",
        body_weight: "font-light",
        heading_size: "text-3xl lg:text-4xl",
        body_size: "text-lg"
      },
      layout_config: %{
        header_style: "zen_header",
        section_layout: "zen_blocks",
        navigation: "zen_nav",
        spacing: "extra-spacious"
      }
    }
  end

  # Helper functions for template styling (existing code continues...)
  def get_background_classes(template_config) do
    case template_config.background do
      "clean-white" -> "bg-white"
      "subtle-dark" -> "bg-gray-50"
      "subtle-gradient" -> "bg-gradient-to-br from-indigo-50 to-violet-50"
      "professional-subtle" -> "bg-gradient-to-br from-blue-50 to-indigo-50"
      "academic-clean" -> "bg-gradient-to-br from-emerald-50 to-teal-50"
      "service-clean" -> "bg-gradient-to-br from-teal-50 to-cyan-50"
      "photo-dark" -> "bg-gray-900 text-white"        # NEW
      "minimal-white" -> "bg-white"
      "creative-gradient" -> "bg-gradient-to-br from-purple-50 to-pink-50"  # NEW
      "zen-minimal" -> "bg-gray-50"                     # NEW
      _ -> "bg-white"
    end
  end

  def get_font_classes(template_config) do
    case template_config.typography.font_family do
      "JetBrains Mono" -> "font-mono"
      "Playfair Display" -> "font-serif"
      "Merriweather" -> "font-serif"
      "Inter" -> "font-sans"
      _ -> "font-sans"
    end
  end

  def get_section_spacing(template_config) do
    case template_config.layout_config.spacing do
      "compact" -> "space-y-4"
      "normal" -> "space-y-6"
      "comfortable" -> "space-y-8"
      "spacious" -> "space-y-12"
      "extra-spacious" -> "space-y-16"  # NEW
      "none" -> ""
      _ -> "space-y-6"
    end
  end
end
