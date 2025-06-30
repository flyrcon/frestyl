# lib/frestyl/portfolios/content_blocks/dynamic_card_blocks.ex
defmodule Frestyl.Portfolios.ContentBlocks.DynamicCardBlocks do
  @moduledoc """
  Dynamic Card Layout Content Blocks for talent showcase with monetization opportunities.
  Works across all portfolio templates with brand-controllable design.
  """

  # ============================================================================
  # SERVICE PROVIDER CATEGORY BLOCKS
  # ============================================================================

  def service_showcase_block do
    %{
      type: :service_showcase,
      name: "Service Showcase",
      description: "Display your services with booking integration",
      category: :service_provider,
      monetization_tier: :creator, # Requires creator+ subscription
      brand_controllable: true,

      default_content: %{
        "service_title" => "",
        "service_description" => "",
        "starting_price" => nil,
        "currency" => "USD",
        "pricing_model" => "fixed", # fixed, hourly, project
        "duration_estimate" => "",
        "includes" => [],
        "booking_enabled" => false,
        "booking_type" => "inquiry", # inquiry, calendar, instant
        "testimonial_count" => 0,
        "completion_time" => "",
        "revision_count" => "",
        "portfolio_samples" => []
      },

      media_config: %{
        max_images: 6,
        max_videos: 2,
        featured_image_required: true,
        image_aspect_ratio: "16:9"
      },

      brand_tokens: %{
        primary_color: "service_card_background",
        accent_color: "pricing_highlight",
        typography: "service_title_font"
      }
    }
  end

  def testimonial_carousel_block do
    %{
      type: :testimonial_carousel,
      name: "Testimonial Carousel",
      description: "Client testimonials that build trust and drive bookings",
      category: :service_provider,
      monetization_tier: :personal, # Available to all tiers
      brand_controllable: true,

      default_content: %{
        "testimonials" => [],
        "display_style" => "carousel", # carousel, grid, list
        "show_client_photos" => true,
        "show_ratings" => true,
        "show_project_details" => false,
        "auto_rotate" => true,
        "rotation_interval" => 5000,
        "enable_filtering" => false,
        "filter_by_service" => false
      },

      testimonial_schema: %{
        "client_name" => "",
        "client_title" => "",
        "client_company" => "",
        "client_photo_url" => "",
        "testimonial_text" => "",
        "rating" => 5,
        "project_type" => "",
        "completion_date" => "",
        "project_value" => nil,
        "featured" => false
      },

      media_config: %{
        max_client_photos: 20,
        photo_size: "64x64",
        video_testimonials: 3
      }
    }
  end

  def pricing_display_block do
    %{
      type: :pricing_display,
      name: "Pricing Display",
      description: "Transparent pricing that converts visitors to clients",
      category: :service_provider,
      monetization_tier: :creator,
      brand_controllable: true,

      default_content: %{
        "pricing_tiers" => [],
        "display_format" => "cards", # cards, table, minimal
        "highlight_popular" => true,
        "show_comparison" => true,
        "enable_custom_quotes" => true,
        "currency" => "USD",
        "billing_cycles" => ["one-time", "monthly", "project"],
        "discount_display" => false,
        "add_ons_available" => false
      },

      pricing_tier_schema: %{
        "tier_name" => "",
        "base_price" => 0,
        "billing_cycle" => "one-time",
        "description" => "",
        "features_included" => [],
        "delivery_time" => "",
        "revision_count" => "",
        "is_popular" => false,
        "is_custom" => false,
        "booking_button_text" => "Get Started",
        "additional_notes" => ""
      },

      monetization_hooks: %{
        booking_integration: true,
        payment_processing: true,
        contract_templates: true,
        automated_invoicing: true
      }
    }
  end

  # ============================================================================
  # CREATIVE SHOWCASE CATEGORY BLOCKS
  # ============================================================================

  def portfolio_gallery_block do
    %{
      type: :portfolio_gallery,
      name: "Portfolio Gallery",
      description: "Visual work showcase with commission inquiry integration",
      category: :creative_showcase,
      monetization_tier: :personal,
      brand_controllable: true,

      default_content: %{
        "gallery_style" => "masonry", # masonry, grid, carousel, vertical
        "items_per_row" => 3,
        "show_project_details" => true,
        "enable_lightbox" => true,
        "enable_filtering" => true,
        "filter_categories" => [],
        "show_commission_status" => true,
        "enable_inquiries" => true,
        "watermark_images" => false
      },

      portfolio_item_schema: %{
        "title" => "",
        "description" => "",
        "category" => "",
        "creation_date" => "",
        "client_name" => "",
        "project_duration" => "",
        "tools_used" => [],
        "is_available_for_licensing" => false,
        "commission_status" => "available", # available, booked, unavailable
        "estimated_price_range" => "",
        "similar_work_available" => true
      },

      media_config: %{
        max_items: 50,
        image_formats: ["jpg", "png", "webp"],
        video_formats: ["mp4", "webm"],
        max_file_size_mb: 10,
        thumbnail_required: true
      },

      monetization_hooks: %{
        commission_inquiries: true,
        licensing_options: true,
        print_sales: true,
        digital_downloads: false
      }
    }
  end

  def process_showcase_block do
    %{
      type: :process_showcase,
      name: "Creative Process Showcase",
      description: "Behind-the-scenes that demonstrates expertise and builds trust",
      category: :creative_showcase,
      monetization_tier: :creator,
      brand_controllable: true,

      default_content: %{
        "process_steps" => [],
        "display_style" => "timeline", # timeline, steps, accordion
        "show_time_estimates" => true,
        "show_tools_used" => true,
        "include_client_collaboration" => true,
        "show_revision_process" => true,
        "enable_process_inquiry" => true
      },

      process_step_schema: %{
        "step_number" => 1,
        "step_title" => "",
        "step_description" => "",
        "estimated_duration" => "",
        "tools_required" => [],
        "client_involvement" => "", # none, review, collaboration, approval
        "deliverables" => [],
        "step_media" => []
      },

      media_config: %{
        max_images_per_step: 4,
        max_videos_per_step: 1,
        before_after_comparisons: true,
        time_lapse_videos: true
      },

      monetization_hooks: %{
        process_consultations: true,
        workshop_bookings: true,
        mentorship_sessions: true
      }
    }
  end

  def collaboration_display_block do
    %{
      type: :collaboration_display,
      name: "Past Collaborations",
      description: "Showcase partnerships and collaborations to attract new opportunities",
      category: :creative_showcase,
      monetization_tier: :creator,
      brand_controllable: true,

      default_content: %{
        "collaborations" => [],
        "display_format" => "featured_grid", # featured_grid, timeline, carousel
        "show_collaboration_type" => true,
        "show_results_metrics" => true,
        "enable_collaboration_inquiries" => true,
        "group_by_type" => false
      },

      collaboration_schema: %{
        "project_title" => "",
        "collaboration_type" => "", # brand_partnership, co_creation, client_work, pro_bono
        "partner_name" => "",
        "partner_logo_url" => "",
        "project_description" => "",
        "your_role" => "",
        "project_duration" => "",
        "completion_date" => "",
        "results_achieved" => [],
        "testimonial_quote" => "",
        "project_url" => "",
        "is_featured" => false,
        "available_for_similar" => true
      },

      monetization_hooks: %{
        partnership_inquiries: true,
        collaboration_booking: true,
        case_study_sales: false
      }
    }
  end

  # ============================================================================
  # TECHNICAL EXPERT CATEGORY BLOCKS
  # ============================================================================

  def skill_matrix_block do
    %{
      type: :skill_matrix,
      name: "Technical Skill Matrix",
      description: "Interactive skills display with project inquiry integration",
      category: :technical_expert,
      monetization_tier: :personal,
      brand_controllable: true,

      default_content: %{
        "skills" => [],
        "display_style" => "interactive_grid", # interactive_grid, category_tabs, skill_bars
        "show_experience_years" => true,
        "show_project_count" => true,
        "show_certification_badges" => true,
        "enable_skill_filtering" => true,
        "group_by_category" => true,
        "show_learning_progress" => false
      },

      skill_schema: %{
        "skill_name" => "",
        "category" => "", # programming, frameworks, tools, soft_skills, certifications
        "proficiency_level" => "", # beginner, intermediate, advanced, expert
        "years_experience" => 0,
        "projects_completed" => 0,
        "last_used" => "",
        "certification_url" => "",
        "learning_status" => "", # mastered, improving, learning
        "available_for_projects" => true,
        "hourly_rate" => nil
      },

      media_config: %{
        certification_badges: 20,
        project_screenshots: 3,
        badge_size: "48x48"
      },

      monetization_hooks: %{
        skill_based_inquiries: true,
        consultation_booking: true,
        training_sessions: true,
        project_estimates: true
      }
    }
  end

  def project_deep_dive_block do
    %{
      type: :project_deep_dive,
      name: "Project Deep Dive",
      description: "Detailed project breakdown that demonstrates technical expertise",
      category: :technical_expert,
      monetization_tier: :creator,
      brand_controllable: true,

      default_content: %{
        "project_title" => "",
        "project_overview" => "",
        "challenge_description" => "",
        "solution_approach" => "",
        "technologies_used" => [],
        "architecture_decisions" => [],
        "results_achieved" => [],
        "lessons_learned" => "",
        "project_duration" => "",
        "team_size" => "",
        "your_role" => "",
        "github_url" => "",
        "live_demo_url" => "",
        "case_study_pdf_url" => "",
        "available_for_similar_projects" => true
      },

      technical_details: %{
        "code_snippets" => [],
        "architecture_diagrams" => [],
        "performance_metrics" => {},
        "scalability_notes" => "",
        "security_considerations" => "",
        "testing_approach" => "",
        "deployment_strategy" => ""
      },

      media_config: %{
        max_screenshots: 10,
        max_diagrams: 5,
        max_videos: 2,
        code_highlighting: true
      },

      monetization_hooks: %{
        similar_project_inquiries: true,
        technical_consultation: true,
        code_review_services: true,
        architecture_consulting: true
      }
    }
  end

  def consultation_booking_block do
    %{
      type: :consultation_booking,
      name: "Technical Consultation Booking",
      description: "Direct booking for technical consultations and code reviews",
      category: :technical_expert,
      monetization_tier: :creator,
      brand_controllable: true,

      default_content: %{
        "consultation_types" => [],
        "default_duration" => 60,
        "hourly_rate" => nil,
        "available_time_slots" => [],
        "booking_lead_time" => 24, # hours
        "preparation_required" => true,
        "follow_up_included" => true,
        "recording_available" => false,
        "materials_provided" => true
      },

      consultation_type_schema: %{
        "type_name" => "",
        "description" => "",
        "duration_minutes" => 60,
        "price" => 0,
        "preparation_time" => 15,
        "includes" => [],
        "requirements" => [],
        "ideal_for" => ""
      },

      monetization_hooks: %{
        calendar_integration: true,
        payment_processing: true,
        automated_reminders: true,
        follow_up_scheduling: true,
        recording_delivery: true
      }
    }
  end

  # ============================================================================
  # CONTENT CREATOR CATEGORY BLOCKS
  # ============================================================================

  def content_metrics_block do
    %{
      type: :content_metrics,
      name: "Content Performance Metrics",
      description: "Showcase reach and engagement to attract brand partnerships",
      category: :content_creator,
      monetization_tier: :creator,
      brand_controllable: true,

      default_content: %{
        "platforms" => [],
        "total_followers" => 0,
        "average_engagement_rate" => 0,
        "content_categories" => [],
        "posting_frequency" => "",
        "audience_demographics" => {},
        "best_performing_content" => [],
        "collaboration_rate" => nil,
        "media_kit_available" => false
      },

      platform_schema: %{
        "platform_name" => "",
        "follower_count" => 0,
        "engagement_rate" => 0,
        "avg_views_per_post" => 0,
        "posting_frequency" => "",
        "audience_age_range" => "",
        "audience_gender_split" => {},
        "top_content_types" => []
      },

      monetization_hooks: %{
        brand_partnership_inquiries: true,
        sponsored_content_rates: true,
        collaboration_packages: true,
        media_kit_download: true
      }
    }
  end

  def brand_partnerships_block do
    %{
      type: :brand_partnerships,
      name: "Brand Partnerships",
      description: "Display past partnerships to attract new brand collaborations",
      category: :content_creator,
      monetization_tier: :creator,
      brand_controllable: true,

      default_content: %{
        "partnerships" => [],
        "partnership_types" => ["sponsored_posts", "long_term_ambassador", "product_review", "event_coverage"],
        "available_for_partnerships" => true,
        "partnership_guidelines" => "",
        "content_style_preferences" => [],
        "audience_alignment_notes" => ""
      },

      partnership_schema: %{
        "brand_name" => "",
        "brand_logo_url" => "",
        "partnership_type" => "",
        "campaign_duration" => "",
        "content_delivered" => [],
        "results_achieved" => {},
        "testimonial_quote" => "",
        "campaign_url" => "",
        "partnership_year" => "",
        "is_ongoing" => false,
        "featured_partnership" => false
      },

      monetization_hooks: %{
        partnership_inquiry_form: true,
        rate_card_access: true,
        portfolio_download: true,
        collaboration_calendar: true
      }
    }
  end

  def subscription_tiers_block do
    %{
      type: :subscription_tiers,
      name: "Creator Subscription Tiers",
      description: "Different ways audiences can support and access exclusive content",
      category: :content_creator,
      monetization_tier: :professional,
      brand_controllable: true,

      default_content: %{
        "tiers" => [],
        "platform_integration" => "", # patreon, kofi, gumroad, custom
        "free_content_preview" => true,
        "subscriber_benefits" => [],
        "content_calendar_visible" => false,
        "community_access" => false
      },

      tier_schema: %{
        "tier_name" => "",
        "monthly_price" => 0,
        "annual_discount" => 0,
        "tier_description" => "",
        "benefits_included" => [],
        "exclusive_content_types" => [],
        "interaction_level" => "", # view_only, comment, direct_message, video_calls
        "subscriber_count" => 0,
        "is_featured" => false
      },

      monetization_hooks: %{
        subscription_platform_integration: true,
        payment_processing: true,
        content_gating: true,
        subscriber_management: true,
        analytics_tracking: true
      }
    }
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  def get_all_dynamic_card_blocks do
    [
      # Service Provider Category
      service_showcase_block(),
      testimonial_carousel_block(),
      pricing_display_block(),

      # Creative Showcase Category
      portfolio_gallery_block(),
      process_showcase_block(),
      collaboration_display_block(),

      # Technical Expert Category
      skill_matrix_block(),
      project_deep_dive_block(),
      consultation_booking_block(),

      # Content Creator Category
      content_metrics_block(),
      brand_partnerships_block(),
      subscription_tiers_block()
    ]
  end

  def get_blocks_by_category(category) do
    get_all_dynamic_card_blocks()
    |> Enum.filter(&(&1.category == category))
  end

  def get_blocks_by_monetization_tier(tier) do
    tier_hierarchy = %{
      personal: 0,
      creator: 1,
      professional: 2,
      enterprise: 3
    }

    user_tier_level = Map.get(tier_hierarchy, tier, 0)

    get_all_dynamic_card_blocks()
    |> Enum.filter(fn block ->
      block_tier_level = Map.get(tier_hierarchy, block.monetization_tier, 0)
      user_tier_level >= block_tier_level
    end)
  end

  def get_available_layouts_for_category(category) do
    case category do
      :service_provider -> [
        %{
          layout_key: "professional_service_provider",
          name: "Professional Service Provider",
          description: "Emphasizes booking/pricing with trust-building elements",
          featured_blocks: [:service_showcase, :testimonial_carousel, :pricing_display],
          grid_style: "service_focused",
          monetization_emphasis: :high
        }
      ]

      :creative_showcase -> [
        %{
          layout_key: "creative_portfolio_showcase",
          name: "Creative Showcase",
          description: "Portfolio-focused with commission options and process display",
          featured_blocks: [:portfolio_gallery, :process_showcase, :collaboration_display],
          grid_style: "visual_masonry",
          monetization_emphasis: :medium
        }
      ]

      :technical_expert -> [
        %{
          layout_key: "technical_expert_dashboard",
          name: "Technical Expert",
          description: "Skill-based with project pricing and consultation booking",
          featured_blocks: [:skill_matrix, :project_deep_dive, :consultation_booking],
          grid_style: "structured_grid",
          monetization_emphasis: :high
        }
      ]

      :content_creator -> [
        %{
          layout_key: "content_creator_hub",
          name: "Content Creator/Performer",
          description: "Streaming-focused with subscription options and work showcase",
          featured_blocks: [:content_metrics, :brand_partnerships, :subscription_tiers],
          grid_style: "engagement_focused",
          monetization_emphasis: :very_high
        }
      ]

      :corporate_executive -> [
        %{
          layout_key: "corporate_executive_profile",
          name: "Corporate Executive",
          description: "Achievement-focused with consultation booking and thought leadership",
          featured_blocks: [:consultation_booking, :collaboration_display, :content_metrics],
          grid_style: "executive_dashboard",
          monetization_emphasis: :medium
        }
      ]
    end
  end

  def validate_block_content(block_type, content, brand_settings \\ nil) do
    block_config = get_block_config(block_type)
    errors = []

    # Validate required fields
    errors = validate_required_fields(content, block_config, errors)

    # Validate brand constraints if provided
    errors = if brand_settings do
      validate_brand_constraints(content, brand_settings, errors)
    else
      errors
    end

    # Validate monetization settings
    errors = validate_monetization_settings(content, block_config, errors)

    case errors do
      [] -> {:ok, content}
      errors -> {:error, errors}
    end
  end

  def apply_brand_tokens(block_content, brand_settings) do
    if brand_settings.enforce_brand_colors do
      apply_brand_colors(block_content, brand_settings)
    else
      block_content
    end
  end

  defp get_block_config(block_type) do
    get_all_dynamic_card_blocks()
    |> Enum.find(&(&1.type == block_type))
  end

  defp validate_required_fields(content, block_config, errors) do
    required_fields = get_required_fields_for_block(block_config.type)

    Enum.reduce(required_fields, errors, fn field, acc ->
      if Map.get(content, field) in [nil, ""] do
        ["#{field} is required" | acc]
      else
        acc
      end
    end)
  end

  defp validate_brand_constraints(content, brand_settings, errors) do
    # Example: Validate pricing display format matches brand guidelines
    if brand_settings.price_display_format && content["pricing_format"] do
      if content["pricing_format"] != brand_settings.price_display_format do
        ["Pricing format must match brand guidelines: #{brand_settings.price_display_format}" | errors]
      else
        errors
      end
    else
      errors
    end
  end

  defp validate_monetization_settings(content, block_config, errors) do
    # Validate monetization-specific requirements
    if block_config.monetization_tier != :personal && content["pricing_enabled"] == true do
      validate_pricing_content(content, errors)
    else
      errors
    end
  end

  defp validate_pricing_content(content, errors) do
    pricing_errors = []

    pricing_errors = if is_nil(content["currency"]) do
      ["Currency is required for pricing content" | pricing_errors]
    else
      pricing_errors
    end

    pricing_errors = if content["starting_price"] && content["starting_price"] <= 0 do
      ["Starting price must be greater than 0" | pricing_errors]
    else
      pricing_errors
    end

    errors ++ pricing_errors
  end

  defp apply_brand_colors(block_content, brand_settings) do
    color_mappings = %{
      "primary_color" => brand_settings.primary_color,
      "accent_color" => brand_settings.accent_color,
      "booking_button_color" => brand_settings.booking_brand_color || brand_settings.primary_color
    }

    Map.merge(block_content, color_mappings)
  end

  defp get_required_fields_for_block(:service_showcase), do: ["service_title", "service_description"]
  defp get_required_fields_for_block(:pricing_display), do: ["currency"]
  defp get_required_fields_for_block(:portfolio_gallery), do: ["gallery_style"]
  defp get_required_fields_for_block(:skill_matrix), do: ["display_style"]
  defp get_required_fields_for_block(:consultation_booking), do: ["hourly_rate", "default_duration"]
  defp get_required_fields_for_block(:content_metrics), do: ["platforms"]
  defp get_required_fields_for_block(_), do: []

  # ============================================================================
  # BRAND-AWARE RENDERING HELPERS
  # ============================================================================

  def generate_block_css(block_type, content, brand_settings) do
    base_styles = get_base_block_styles(block_type)
    brand_styles = generate_brand_styles(brand_settings)
    custom_styles = generate_content_specific_styles(block_type, content)

    """
    #{base_styles}
    #{brand_styles}
    #{custom_styles}
    """
  end

  defp get_base_block_styles(:service_showcase) do
    """
    .service-showcase-card {
      display: flex;
      flex-direction: column;
      border-radius: 0.75rem;
      padding: 1.5rem;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
      transition: all 0.3s ease;
      background: white;
      border: 1px solid #e5e7eb;
    }

    .service-showcase-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 10px 25px -3px rgba(0, 0, 0, 0.1);
    }

    .service-price {
      font-size: 1.5rem;
      font-weight: 700;
      color: var(--brand-primary-color, #1e40af);
    }

    .booking-button {
      background: var(--brand-accent-color, #f59e0b);
      color: white;
      border: none;
      padding: 0.75rem 1.5rem;
      border-radius: 0.5rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s ease;
    }

    .booking-button:hover {
      opacity: 0.9;
      transform: translateY(-1px);
    }
    """
  end

  defp get_base_block_styles(:portfolio_gallery) do
    """
    .portfolio-gallery {
      display: grid;
      gap: 1rem;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    }

    .portfolio-item {
      position: relative;
      border-radius: 0.5rem;
      overflow: hidden;
      background: white;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
      transition: all 0.3s ease;
    }

    .portfolio-item:hover {
      transform: scale(1.02);
      box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
    }

    .commission-badge {
      position: absolute;
      top: 0.5rem;
      right: 0.5rem;
      background: var(--brand-accent-color, #10b981);
      color: white;
      padding: 0.25rem 0.5rem;
      border-radius: 0.25rem;
      font-size: 0.75rem;
      font-weight: 600;
    }
    """
  end

  defp get_base_block_styles(:skill_matrix) do
    """
    .skill-matrix {
      display: grid;
      gap: 1rem;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    }

    .skill-item {
      background: white;
      border-radius: 0.5rem;
      padding: 1rem;
      border: 1px solid #e5e7eb;
      transition: all 0.2s ease;
    }

    .skill-item:hover {
      border-color: var(--brand-primary-color, #1e40af);
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    }

    .skill-proficiency {
      height: 0.5rem;
      background: #e5e7eb;
      border-radius: 0.25rem;
      overflow: hidden;
      margin-top: 0.5rem;
    }

    .skill-proficiency-fill {
      height: 100%;
      background: var(--brand-primary-color, #1e40af);
      transition: width 0.5s ease;
    }
    """
  end

  defp get_base_block_styles(_), do: ""

  defp generate_brand_styles(brand_settings) do
    """
    :root {
      --brand-primary-color: #{brand_settings.primary_color};
      --brand-secondary-color: #{brand_settings.secondary_color};
      --brand-accent-color: #{brand_settings.accent_color};
      --brand-primary-font: #{brand_settings.primary_font};
      --brand-heading-weight: #{brand_settings.heading_weight};
    }

    .brand-typography {
      font-family: var(--brand-primary-font), system-ui, sans-serif;
    }

    .brand-heading {
      font-weight: var(--brand-heading-weight);
      color: var(--brand-primary-color);
    }
    """
  end

  defp generate_content_specific_styles(block_type, content) do
    case block_type do
      :service_showcase ->
        pricing_color = if content["starting_price"] && content["starting_price"] > 1000 do
          "#dc2626" # Premium pricing in red
        else
          "var(--brand-primary-color)"
        end

        ".service-price { color: #{pricing_color}; }"

      :portfolio_gallery ->
        columns = content["items_per_row"] || 3
        ".portfolio-gallery { grid-template-columns: repeat(#{columns}, 1fr); }"

      _ -> ""
    end
  end
end
