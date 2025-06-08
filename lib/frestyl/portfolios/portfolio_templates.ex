# Update lib/frestyl/portfolios/portfolio_templates.ex - Part 1

defmodule Frestyl.Portfolios.PortfolioTemplates do
  @moduledoc """
  Portfolio template configurations and utilities with distinct visual themes
  """

  def available_templates do
    %{
      "executive" => %{
        name: "Executive",
        description: "Corporate leadership dashboard with metrics focus",
        icon: "💼",
        preview_color: "from-slate-900 via-slate-800 to-blue-900",
        layout_type: "dashboard",
        features: ["Executive summary", "Leadership metrics", "Board positions", "Strategic initiatives"],
        best_for: "C-level executives, senior management, and business leaders"
      },
      "developer" => %{
        name: "Developer",
        description: "Code-focused terminal-style interface",
        icon: "⚡",
        preview_color: "from-gray-900 via-green-900 to-black",
        layout_type: "terminal",
        features: ["Code repositories", "Technical skills", "Project demos", "GitHub integration"],
        best_for: "Software engineers, programmers, and technical professionals"
      },
      "designer" => %{
        name: "Designer",
        description: "Visual portfolio with gallery focus",
        icon: "🎨",
        preview_color: "from-pink-400 via-purple-500 to-indigo-600",
        layout_type: "gallery",
        features: ["Visual portfolio", "Case studies", "Design process", "Creative projects"],
        best_for: "UI/UX designers, graphic designers, and creative professionals"
      },
      "consultant" => %{
        name: "Consultant",
        description: "Professional services with case study focus",
        icon: "📊",
        preview_color: "from-blue-600 via-indigo-600 to-purple-700",
        layout_type: "case_study",
        features: ["Case studies", "Industry expertise", "Client results", "Methodology"],
        best_for: "Business consultants, advisors, and strategic professionals"
      },
      "photographer" => %{
        name: "Photographer",
        description: "Full-screen visual storytelling",
        icon: "📸",
        preview_color: "from-black via-gray-800 to-gray-900",
        layout_type: "fullscreen",
        features: ["Photo galleries", "Visual stories", "Client work", "Equipment expertise"],
        best_for: "Professional photographers, visual artists, and media creators"
      },
      "freelancer" => %{
        name: "Freelancer",
        description: "Service-focused with availability calendar",
        icon: "💡",
        preview_color: "from-emerald-400 via-teal-500 to-blue-600",
        layout_type: "services",
        features: ["Service offerings", "Client testimonials", "Availability", "Pricing"],
        best_for: "Independent contractors, consultants, and service providers"
      },
      "artist" => %{
        name: "Artist",
        description: "Creative showcase with exhibition focus",
        icon: "🎭",
        preview_color: "from-purple-600 via-pink-600 to-red-600",
        layout_type: "exhibition",
        features: ["Gallery showcase", "Exhibition history", "Artistic statement", "Collection"],
        best_for: "Visual artists, painters, sculptors, and creative professionals"
      },
      "minimalist" => %{
        name: "Minimalist",
        description: "Clean typography-focused design",
        icon: "📝",
        preview_color: "from-gray-100 via-white to-gray-200",
        layout_type: "typography",
        features: ["Clean layout", "Typography focus", "Minimal distractions", "Content first"],
        best_for: "Writers, academics, and content-focused professionals"
      }
    }
  end

  def get_template_config(theme) do
    case theme do
      "executive" -> executive_config()
      "developer" -> developer_config()
      "designer" -> designer_config()
      "consultant" -> consultant_config()
      "photographer" -> photographer_config()
      "freelancer" -> freelancer_config()
      "artist" -> artist_config()
      "minimalist" -> minimalist_config()
      _ -> executive_config()
    end
  end

  # EXECUTIVE: Corporate Dashboard Style
  defp executive_config do
    %{
      layout: "dashboard",
      primary_color: "#1e293b",
      secondary_color: "#3b82f6",
      accent_color: "#06b6d4",
      background: "gradient-dark",
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
      primary_color: "#0f172a",
      secondary_color: "#22c55e",
      accent_color: "#3b82f6",
      background: "terminal-dark",
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

  # DESIGNER: Visual Gallery Style
  defp designer_config do
    %{
      layout: "gallery",
      primary_color: "#ec4899",
      secondary_color: "#8b5cf6",
      accent_color: "#f59e0b",
      background: "gradient-vibrant",
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

  # CONSULTANT: Case Study Focus
  defp consultant_config do
    %{
      layout: "case_study",
      primary_color: "#1e40af",
      secondary_color: "#059669",
      accent_color: "#dc2626",
      background: "professional-blue",
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

  # PHOTOGRAPHER: Full-screen Visual Style
  defp photographer_config do
    %{
      layout: "fullscreen",
      primary_color: "#000000",
      secondary_color: "#374151",
      accent_color: "#f59e0b",
      background: "dark-minimal",
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

  # FREELANCER: Service-focused Style
  defp freelancer_config do
    %{
      layout: "services",
      primary_color: "#059669",
      secondary_color: "#0891b2",
      accent_color: "#ea580c",
      background: "gradient-teal",
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

  # ARTIST: Exhibition Style
  defp artist_config do
    %{
      layout: "exhibition",
      primary_color: "#7c3aed",
      secondary_color: "#ec4899",
      accent_color: "#f59e0b",
      background: "artistic-gradient",
      typography: %{
        font_family: "Playfair Display",
        heading_weight: "font-normal",
        body_weight: "font-light",
        heading_size: "text-3xl lg:text-4xl",
        body_size: "text-lg"
      },
      layout_config: %{
        header_style: "artistic_header",
        section_layout: "exhibition_grid",
        navigation: "artistic_nav",
        spacing: "generous"
      }
    }
  end

  # MINIMALIST: Typography-focused Style
  defp minimalist_config do
    %{
      layout: "typography",
      primary_color: "#374151",
      secondary_color: "#6b7280",
      accent_color: "#3b82f6",
      background: "white-clean",
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

  # Helper functions for template styling
  def get_background_classes(template_config) do
    case template_config.background do
      "gradient-dark" -> "bg-gradient-to-br from-slate-900 via-slate-800 to-blue-900"
      "terminal-dark" -> "bg-gray-900 font-mono text-green-400"
      "gradient-vibrant" -> "bg-gradient-to-br from-pink-400 via-purple-500 to-indigo-600"
      "professional-blue" -> "bg-gradient-to-br from-blue-50 to-indigo-100"
      "dark-minimal" -> "bg-black text-white"
      "gradient-teal" -> "bg-gradient-to-br from-emerald-400 to-teal-600"
      "artistic-gradient" -> "bg-gradient-to-br from-purple-600 via-pink-600 to-red-600"
      "white-clean" -> "bg-white text-gray-900"
      _ -> "bg-white"
    end
  end

  def get_font_classes(template_config) do
    case template_config.typography.font_family do
      "JetBrains Mono" -> "font-mono"
      "Playfair Display" -> "font-serif"
      "Inter" -> "font-sans"
      _ -> "font-sans"
    end
  end
end
