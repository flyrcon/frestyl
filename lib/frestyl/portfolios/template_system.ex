# lib/frestyl/portfolios/template_system.ex
defmodule Frestyl.Portfolios.TemplateSystem do
  @moduledoc """
  New template system focused on layout diversity with standardized design.
  Less colorful customization, more dynamic card layouts.
  """

  @layout_templates %{
    # Professional layouts
    "executive_grid" => %{
      name: "Executive Grid",
      description: "Clean grid layout for C-level professionals",
      layout_config: %{
        "grid_type" => "masonry",
        "card_style" => "elevated_minimal",
        "spacing" => "generous",
        "max_columns" => 3,
        "responsive_breakpoints" => %{
          "mobile" => 1,
          "tablet" => 2,
          "desktop" => 3
        }
      },
      color_scheme: %{
        "primary" => "#1f2937",
        "secondary" => "#f3f4f6",
        "accent" => "#3b82f6",
        "text" => "#111827"
      },
      section_layouts: %{
        "intro" => "hero_banner",
        "experience" => "timeline_cards",
        "skills" => "progress_grid",
        "projects" => "featured_showcase"
      }
    },

    "creative_portfolio" => %{
      name: "Creative Portfolio",
      description: "Visual-first layout for designers and creatives",
      layout_config: %{
        "grid_type" => "pinterest",
        "card_style" => "borderless_hover",
        "spacing" => "tight",
        "max_columns" => 4,
        "image_ratios" => "dynamic"
      },
      color_scheme: %{
        "primary" => "#0f172a",
        "secondary" => "#f8fafc",
        "accent" => "#6366f1",
        "text" => "#1e293b"
      },
      section_layouts: %{
        "intro" => "split_media",
        "experience" => "story_cards",
        "skills" => "icon_badges",
        "projects" => "gallery_grid"
      }
    },

    "consultant_showcase" => %{
      name: "Consultant Showcase",
      description: "Service-focused layout with clear pricing",
      layout_config: %{
        "grid_type" => "service_oriented",
        "card_style" => "pricing_focused",
        "spacing" => "balanced",
        "max_columns" => 2,
        "monetization_prominent" => true
      },
      color_scheme: %{
        "primary" => "#059669",
        "secondary" => "#f0fdf4",
        "accent" => "#10b981",
        "text" => "#065f46"
      },
      section_layouts: %{
        "intro" => "value_proposition",
        "experience" => "results_timeline",
        "skills" => "service_matrix",
        "services" => "pricing_tiers"
      }
    },

    "developer_portfolio" => %{
      name: "Developer Portfolio",
      description: "Code-focused layout with project showcases",
      layout_config: %{
        "grid_type" => "code_centric",
        "card_style" => "terminal_inspired",
        "spacing" => "compact",
        "max_columns" => 3,
        "code_highlighting" => true
      },
      color_scheme: %{
        "primary" => "#1e1b4b",
        "secondary" => "#f1f5f9",
        "accent" => "#8b5cf6",
        "text" => "#312e81"
      },
      section_layouts: %{
        "intro" => "terminal_hero",
        "experience" => "commit_timeline",
        "skills" => "tech_stack",
        "projects" => "repo_showcase"
      }
    },

    "freelancer_hub" => %{
      name: "Freelancer Hub",
      description: "All-in-one layout with booking and payments",
      layout_config: %{
        "grid_type" => "business_focused",
        "card_style" => "action_oriented",
        "spacing" => "functional",
        "max_columns" => 3,
        "cta_prominent" => true
      },
      color_scheme: %{
        "primary" => "#7c2d12",
        "secondary" => "#fef7ff",
        "accent" => "#ea580c",
        "text" => "#9a3412"
      },
      section_layouts: %{
        "intro" => "availability_hero",
        "experience" => "client_testimonials",
        "skills" => "hourly_rates",
        "services" => "booking_packages"
      }
    }
  }

  @card_styles %{
    "elevated_minimal" => %{
      "shadow" => "lg",
      "border" => "none",
      "radius" => "xl",
      "padding" => "generous",
      "hover_effect" => "lift"
    },
    "borderless_hover" => %{
      "shadow" => "none",
      "border" => "subtle",
      "radius" => "lg",
      "padding" => "balanced",
      "hover_effect" => "scale"
    },
    "pricing_focused" => %{
      "shadow" => "md",
      "border" => "accent",
      "radius" => "lg",
      "padding" => "structured",
      "hover_effect" => "glow"
    },
    "terminal_inspired" => %{
      "shadow" => "inner",
      "border" => "mono",
      "radius" => "sm",
      "padding" => "compact",
      "hover_effect" => "highlight"
    },
    "action_oriented" => %{
      "shadow" => "md",
      "border" => "strong",
      "radius" => "lg",
      "padding" => "cta_focused",
      "hover_effect" => "bounce"
    }
  }

  @section_layout_types %{
    # Intro layouts
    "hero_banner" => %{
      "structure" => "full_width",
      "media_position" => "background",
      "text_alignment" => "center",
      "cta_style" => "prominent"
    },
    "split_media" => %{
      "structure" => "two_column",
      "media_position" => "left",
      "text_alignment" => "left",
      "cta_style" => "inline"
    },
    "value_proposition" => %{
      "structure" => "stacked",
      "media_position" => "top",
      "text_alignment" => "center",
      "cta_style" => "multiple"
    },

    # Experience layouts
    "timeline_cards" => %{
      "structure" => "vertical_timeline",
      "card_arrangement" => "alternating",
      "connection_style" => "line",
      "media_integration" => "card_header"
    },
    "story_cards" => %{
      "structure" => "narrative_flow",
      "card_arrangement" => "sequential",
      "connection_style" => "none",
      "media_integration" => "full_background"
    },
    "results_timeline" => %{
      "structure" => "metric_focused",
      "card_arrangement" => "achievement_based",
      "connection_style" => "progress_bar",
      "media_integration" => "result_showcase"
    },

    # Skills layouts
    "progress_grid" => %{
      "structure" => "grid_layout",
      "skill_display" => "progress_bars",
      "grouping" => "category",
      "interaction" => "hover_details"
    },
    "service_matrix" => %{
      "structure" => "table_layout",
      "skill_display" => "pricing_matrix",
      "grouping" => "service_type",
      "interaction" => "booking_modal"
    },
    "tech_stack" => %{
      "structure" => "logo_grid",
      "skill_display" => "technology_badges",
      "grouping" => "stack_layer",
      "interaction" => "project_filter"
    }
  }

  def get_template(template_key) do
    Map.get(@layout_templates, template_key)
  end

  def list_templates do
    @layout_templates
  end

  def get_card_style(style_key) do
    Map.get(@card_styles, style_key)
  end

  def get_section_layout(layout_key) do
    Map.get(@section_layout_types, layout_key)
  end

  def generate_template_config(template_key, customizations \\ %{}) do
    base_template = get_template(template_key)

    if base_template do
      Map.merge(base_template, customizations)
    else
      {:error, :template_not_found}
    end
  end

  def validate_template_compatibility(template_key, content_blocks) do
    template = get_template(template_key)

    if template do
      required_sections = Map.keys(template.section_layouts)
      available_sections = content_blocks |> Enum.map(& &1.block_type) |> Enum.uniq()

      missing_sections = required_sections -- available_sections

      if Enum.empty?(missing_sections) do
        {:ok, :compatible}
      else
        {:warning, {:missing_sections, missing_sections}}
      end
    else
      {:error, :template_not_found}
    end
  end
end
