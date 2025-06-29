# ==============================================================================
# ENHANCED PORTFOLIO MIGRATION - Merged with Existing System
# ==============================================================================

# lib/frestyl/portfolio_migration.ex - Enhanced with Content Blocks
defmodule Frestyl.PortfolioMigration do
  @moduledoc """
  Migration utilities for transitioning from fragmented portfolio system
  to unified account-aware system with monetization support and content blocks.
  """

  alias Frestyl.{Portfolios, Accounts, Repo}
  alias Frestyl.Portfolios.{ContentBlock, ContentBlockBuilder, TemplateSystem}
  import Ecto.Query

  # ============================================================================
  # MAIN MIGRATION FUNCTIONS - Enhanced
  # ============================================================================

  @doc """
  Migrate all portfolios to account-based system with content blocks
  """
  def migrate_portfolios_to_accounts(options \\ %{}) do
    portfolios_without_accounts = from(p in Portfolios.Portfolio,
      where: is_nil(p.account_id),
      preload: [:user]
    ) |> Repo.all()

    migration_strategy = Map.get(options, :strategy, "selective")
    enable_content_blocks = Map.get(options, :enable_content_blocks, true)

    results = Enum.map(portfolios_without_accounts, fn portfolio ->
      migrate_single_portfolio(portfolio, %{
        strategy: migration_strategy,
        enable_content_blocks: enable_content_blocks,
        enable_monetization: options[:enable_monetization] || false,
        enable_streaming: options[:enable_streaming] || false
      })
    end)

    {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

    %{
      migrated: length(successes),
      failed: length(failures),
      failures: Enum.map(failures, fn {:error, {portfolio_id, reason}} ->
        %{portfolio_id: portfolio_id, reason: reason}
      end),
      content_blocks_created: calculate_total_blocks_created(successes)
    }
  end

  defp migrate_single_portfolio(portfolio, options) do
    # Find or create account for the portfolio's user
    case get_or_create_user_account(portfolio.user) do
      {:ok, account} ->
        case update_portfolio_with_account(portfolio, account, options) do
          {:ok, updated_portfolio} ->
            if options[:enable_content_blocks] do
              case migrate_portfolio_to_content_blocks(updated_portfolio, options) do
                {:ok, block_count} ->
                  {:ok, %{portfolio: updated_portfolio, blocks_created: block_count}}
                {:error, reason} ->
                  {:error, {portfolio.id, "Content block migration failed: #{reason}"}}
              end
            else
              # Legacy content migration
              migrate_portfolio_content(updated_portfolio)
              {:ok, %{portfolio: updated_portfolio, blocks_created: 0}}
            end

          {:error, changeset} ->
            {:error, {portfolio.id, format_changeset_errors(changeset)}}
        end

      {:error, reason} ->
        {:error, {portfolio.id, "Failed to create account: #{reason}"}}
    end
  end

  defp get_or_create_user_account(user) do
    case Accounts.get_user_primary_account(user.id) do
      nil ->
        # Create new personal account for user
        Accounts.create_account(user.id, %{
          name: "#{user.first_name}'s Portfolio Account",
          subscription_tier: determine_user_tier(user),
          account_type: "personal"
        })

      account ->
        {:ok, account}
    end
  end

  defp determine_user_tier(user) do
    # Migrate user's existing subscription to account tier
    case user.subscription_tier do
      nil -> "personal"
      "free" -> "personal"
      tier when tier in ["basic", "creator"] -> "creator"
      tier when tier in ["premium", "professional"] -> "professional"
      "enterprise" -> "enterprise"
      _ -> "personal"
    end
  end

  defp update_portfolio_with_account(portfolio, account, options) do
    # Determine new template based on content
    new_template = determine_portfolio_template(portfolio, options)

    Portfolios.update_portfolio(portfolio, %{
      account_id: account.id,
      layout: determine_portfolio_layout(portfolio),
      theme: new_template,
      template_version: "2.0",
      monetization_enabled: options[:enable_monetization] && account.subscription_tier in ["creator", "professional", "enterprise"],
      streaming_enabled: options[:enable_streaming] && account.subscription_tier in ["creator", "professional", "enterprise"],
      booking_enabled: account.subscription_tier in ["creator", "professional", "enterprise"],
      customization: enhance_customization_config(portfolio.customization, new_template)
    })
  end

  defp determine_portfolio_template(portfolio, options) do
    theme = portfolio.theme || "professional"
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    # Analyze content to recommend best template
    has_projects = Enum.any?(sections, &(&1.section_type in [:projects, "projects"]))
    has_services = options[:enable_monetization]
    has_extensive_experience = Enum.any?(sections, fn section ->
      section.section_type in [:experience, "experience"] &&
      length(get_in(section.content, ["jobs"]) || []) > 3
    end)

    cond do
      has_services && has_projects -> "freelancer_hub"
      has_projects && has_extensive_experience -> "developer_portfolio"
      has_services -> "consultant_showcase"
      has_projects -> "creative_portfolio"
      theme in ["executive", "corporate", "professional"] -> "executive_grid"
      true -> "executive_grid"
    end
  end

  defp enhance_customization_config(existing_customization, template_key) do
    template_config = TemplateSystem.get_template(template_key)

    Map.merge(existing_customization || %{}, %{
      "template_key" => template_key,
      "layout_config" => template_config.layout_config,
      "color_scheme" => template_config.color_scheme,
      "section_layouts" => template_config.section_layouts,
      "template_version" => "2.0",
      "migration_date" => DateTime.utc_now()
    })
  end

  # ============================================================================
  # CONTENT BLOCKS MIGRATION - New Enhanced System
  # ============================================================================

  defp migrate_portfolio_to_content_blocks(portfolio, options) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    Repo.transaction(fn ->
      total_blocks_created = Enum.reduce(sections, 0, fn section, acc ->
        case migrate_section_to_enhanced_blocks(section, options) do
          {:ok, block_count} -> acc + block_count
          {:error, _reason} -> acc
        end
      end)

      total_blocks_created
    end)
  end

  defp migrate_section_to_enhanced_blocks(section, options) do
    case section.section_type do
      type when type in [:experience, "experience"] ->
        migrate_experience_to_content_blocks(section, options)

      type when type in [:skills, "skills"] ->
        migrate_skills_to_content_blocks(section, options)

      type when type in [:projects, "projects"] ->
        migrate_projects_to_content_blocks(section, options)

      type when type in [:intro, "intro"] ->
        migrate_intro_to_content_blocks(section, options)

      type when type in [:education, "education"] ->
        migrate_education_to_content_blocks(section, options)

      _ ->
        migrate_generic_to_content_blocks(section, options)
    end
  end

  defp migrate_experience_to_content_blocks(section, options) do
    jobs = get_in(section.content, ["jobs"]) || []

    total_blocks = Enum.with_index(jobs) |> Enum.reduce(0, fn {job, index}, acc ->
      # Create main experience block
      case ContentBlockBuilder.create_experience_block(
        section.id,
        job,
        %{
          position: index * 10, # Leave space for responsibility blocks
          enable_consulting: options[:enable_monetization],
          hourly_rate: job["hourly_rate"],
          enable_demos: options[:enable_streaming],
          media_limit: 5
        }
      ) do
        {:ok, exp_block} ->
          # Create responsibility blocks
          responsibilities = job["responsibilities"] || []
          resp_count = Enum.with_index(responsibilities) |> Enum.reduce(0, fn {resp, resp_index}, resp_acc ->
            case ContentBlockBuilder.create_responsibility_block(
              exp_block.id,
              resp,
              %{position: (index * 10) + resp_index + 1, media_limit: 2}
            ) do
              {:ok, _resp_block} -> resp_acc + 1
              {:error, _} -> resp_acc
            end
          end)

          acc + 1 + resp_count

        {:error, _} ->
          acc
      end
    end)

    # Update section with migration metadata
    update_section_migration_metadata(section, %{
      "content_blocks_created" => total_blocks,
      "migration_strategy" => "enhanced_blocks",
      "migrated_at" => DateTime.utc_now()
    })

    {:ok, total_blocks}
  end

  defp migrate_skills_to_content_blocks(section, options) do
    skills = get_in(section.content, ["skills"]) || []
    skill_categories = get_in(section.content, ["skill_categories"]) || %{}

    # Handle flat skills
    flat_skill_blocks = Enum.with_index(skills) |> Enum.reduce(0, fn {skill, index}, acc ->
      skill_data = normalize_skill_data(skill)

      case ContentBlockBuilder.create_skill_block(
        section.id,
        skill_data,
        %{
          position: index,
          enable_services: options[:enable_monetization],
          hourly_rate: skill_data["hourly_rate"],
          media_limit: 3
        }
      ) do
        {:ok, _skill_block} -> acc + 1
        {:error, _} -> acc
      end
    end)

    # Handle categorized skills
    category_blocks = Enum.with_index(skill_categories) |> Enum.reduce(0, fn {{category, category_skills}, cat_index}, acc ->
      base_position = length(skills) + cat_index * 100

      Enum.with_index(category_skills) |> Enum.reduce(acc, fn {skill, skill_index}, cat_acc ->
        skill_data = normalize_skill_data(skill) |> Map.put("category", category)

        case ContentBlockBuilder.create_skill_block(
          section.id,
          skill_data,
          %{
            position: base_position + skill_index,
            enable_services: options[:enable_monetization],
            media_limit: 2
          }
        ) do
          {:ok, _skill_block} -> cat_acc + 1
          {:error, _} -> cat_acc
        end
      end)
    end)

    total_blocks = flat_skill_blocks + category_blocks

    update_section_migration_metadata(section, %{
      "content_blocks_created" => total_blocks,
      "migration_strategy" => "enhanced_blocks"
    })

    {:ok, total_blocks}
  end

  defp migrate_projects_to_content_blocks(section, options) do
    projects = get_in(section.content, ["projects"]) || []

    total_blocks = Enum.with_index(projects) |> Enum.reduce(0, fn {project, index}, acc ->
      # Create project showcase block
      content_data = %{
        "title" => project["title"],
        "description" => project["description"],
        "technologies" => project["technologies"] || [],
        "demo_url" => project["demo_url"],
        "github_url" => project["github_url"],
        "client" => project["client"],
        "duration" => project["duration"],
        "results" => project["results"] || []
      }

      monetization_config = if options[:enable_monetization] && project["available_for_hire"] do
        %{
          "similar_project_rate" => project["project_rate"],
          "consultation_available" => true,
          "case_study_available" => true
        }
      else
        %{}
      end

      streaming_config = if options[:enable_streaming] do
        %{
          "demo_sessions_available" => true,
          "walkthrough_available" => true,
          "tech_talk_available" => project["complex"] || false
        }
      else
        %{}
      end

      case %ContentBlock{}
      |> ContentBlock.changeset(%{
        block_uuid: Ecto.UUID.generate(),
        block_type: :project_card,
        position: index,
        portfolio_section_id: section.id,
        content_data: content_data,
        monetization_config: monetization_config,
        streaming_config: streaming_config,
        media_limit: 8
      })
      |> Repo.insert() do
        {:ok, _project_block} -> acc + 1
        {:error, _} -> acc
      end
    end)

    update_section_migration_metadata(section, %{
      "content_blocks_created" => total_blocks,
      "migration_strategy" => "enhanced_blocks"
    })

    {:ok, total_blocks}
  end

  defp migrate_intro_to_content_blocks(section, options) do
    content = section.content || %{}

    # Create main intro block
    content_data = %{
      "headline" => content["headline"] || "",
      "summary" => content["summary"] || "",
      "location" => content["location"] || "",
      "availability" => content["availability"] || "",
      "value_proposition" => content["value_proposition"] || "",
      "years_experience" => content["years_experience"],
      "specializations" => content["specializations"] || []
    }

    streaming_config = if options[:enable_streaming] do
      %{
        "intro_video_available" => true,
        "portfolio_tour_available" => true,
        "meet_and_greet_sessions" => true
      }
    else
      %{}
    end

    monetization_config = if options[:enable_monetization] do
      %{
        "consultation_cta" => true,
        "availability_display" => true,
        "starting_rate_display" => content["starting_rate"]
      }
    else
      %{}
    end

    blocks_created = 0

    # Create intro block
    case %ContentBlock{}
    |> ContentBlock.changeset(%{
      block_uuid: Ecto.UUID.generate(),
      block_type: :text,
      position: 0,
      portfolio_section_id: section.id,
      content_data: content_data,
      streaming_config: streaming_config,
      monetization_config: monetization_config,
      media_limit: 5
    })
    |> Repo.insert() do
      {:ok, _intro_block} ->
        blocks_created = blocks_created + 1
      {:error, _} ->
        :ok
    end

    # Add booking widget if monetization enabled
    if options[:enable_monetization] && content["booking_enabled"] do
      case ContentBlockBuilder.create_booking_widget_block(
        section.id,
        %{
          "title" => "Schedule a Consultation",
          "description" => "Let's discuss your project needs",
          "booking_url" => content["booking_url"] || "",
          "calendar_provider" => "calendly"
        },
        %{position: 1}
      ) do
        {:ok, _booking_block} ->
          blocks_created = blocks_created + 1
        {:error, _} ->
          :ok
      end
    end

    update_section_migration_metadata(section, %{
      "content_blocks_created" => blocks_created,
      "migration_strategy" => "enhanced_blocks"
    })

    {:ok, blocks_created}
  end

  defp migrate_education_to_content_blocks(section, _options) do
    education_entries = get_in(section.content, ["education"]) || []

    total_blocks = Enum.with_index(education_entries) |> Enum.reduce(0, fn {edu, index}, acc ->
      content_data = %{
        "degree" => edu["degree"],
        "field" => edu["field"],
        "institution" => edu["institution"],
        "location" => edu["location"],
        "start_date" => edu["start_date"],
        "end_date" => edu["end_date"],
        "gpa" => edu["gpa"],
        "honors" => edu["honors"] || [],
        "relevant_coursework" => edu["coursework"] || [],
        "thesis_title" => edu["thesis"]
      }

      case %ContentBlock{}
      |> ContentBlock.changeset(%{
        block_uuid: Ecto.UUID.generate(),
        block_type: :education_entry,
        position: index,
        portfolio_section_id: section.id,
        content_data: content_data,
        media_limit: 3
      })
      |> Repo.insert() do
        {:ok, _edu_block} -> acc + 1
        {:error, _} -> acc
      end
    end)

    update_section_migration_metadata(section, %{
      "content_blocks_created" => total_blocks,
      "migration_strategy" => "enhanced_blocks"
    })

    {:ok, total_blocks}
  end

  defp migrate_generic_to_content_blocks(section, _options) do
    content = section.content || %{}

    case %ContentBlock{}
    |> ContentBlock.changeset(%{
      block_uuid: Ecto.UUID.generate(),
      block_type: :text,
      position: 0,
      portfolio_section_id: section.id,
      content_data: content,
      monetization_config: %{},
      streaming_config: %{},
      media_limit: 5
    })
    |> Repo.insert() do
      {:ok, _generic_block} ->
        update_section_migration_metadata(section, %{
          "content_blocks_created" => 1,
          "migration_strategy" => "enhanced_blocks"
        })
        {:ok, 1}
      {:error, _} ->
        {:ok, 0}
    end
  end

  # Helper functions for content blocks migration
  defp normalize_skill_data(skill) when is_binary(skill) do
    %{"name" => skill, "proficiency" => "intermediate"}
  end

  defp normalize_skill_data(skill) when is_map(skill) do
    skill
  end

  defp update_section_migration_metadata(section, metadata) do
    updated_meta = Map.merge(section.meta || %{}, %{
      "migration_metadata" => metadata,
      "template_version" => 2
    })

    section
    |> Portfolios.PortfolioSection.changeset(%{meta: updated_meta})
    |> Repo.update()
  end

  defp calculate_total_blocks_created(successes) do
    Enum.reduce(successes, 0, fn {:ok, result}, acc ->
      acc + Map.get(result, :blocks_created, 0)
    end)
  end

  # ============================================================================
  # LEGACY CONTENT MIGRATION - Preserved from Original
  # ============================================================================

  defp determine_portfolio_layout(portfolio) do
    theme = portfolio.theme || "professional"

    case theme do
      theme when theme in ["executive", "corporate", "professional"] -> "professional_service"
      theme when theme in ["creative", "designer", "artistic"] -> "creative_showcase"
      theme when theme in ["developer", "technical"] -> "technical_expert"
      theme when theme in ["minimalist", "clean"] -> "minimal_professional"
      _ -> "professional_service"
    end
  end

  defp migrate_portfolio_content(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    Enum.each(sections, fn section ->
      migrate_section_to_content_blocks(section)
    end)
  end

  defp migrate_section_to_content_blocks(section) do
    content_blocks = case section.section_type do
      type when type in [:experience, "experience"] ->
        migrate_experience_content(section.content)

      type when type in [:skills, "skills"] ->
        migrate_skills_content(section.content)

      type when type in [:education, "education"] ->
        migrate_education_content(section.content)

      type when type in [:projects, "projects"] ->
        migrate_projects_content(section.content)

      type when type in [:intro, "intro"] ->
        migrate_intro_content(section.content)

      _ ->
        migrate_generic_content(section.content)
    end

    # Update section with new content blocks structure
    Portfolios.update_section(section, %{
      content_blocks: content_blocks,
      template_version: 2 # Mark as migrated to new template system
    })
  end

  # [Keep all the existing legacy migration functions unchanged]
  defp migrate_experience_content(content) when is_map(content) do
    jobs = Map.get(content, "jobs", [])

    %{
      "header" => %{
        "type" => "header",
        "content" => %{
          "title" => "Professional Experience",
          "subtitle" => "My career journey and achievements"
        }
      },
      "jobs" => Enum.with_index(jobs, fn job, index ->
        {
          "job_#{index}",
          %{
            "type" => "experience_entry",
            "content" => %{
              "title" => Map.get(job, "title", ""),
              "company" => Map.get(job, "company", ""),
              "location" => Map.get(job, "location", ""),
              "start_date" => Map.get(job, "start_date", ""),
              "end_date" => Map.get(job, "end_date", ""),
              "current" => Map.get(job, "current", false),
              "employment_type" => Map.get(job, "employment_type", "Full-time")
            },
            "content_blocks" => %{
              "description" => %{
                "type" => "rich_text",
                "content" => Map.get(job, "description", ""),
                "media_attachments" => []
              },
              "responsibilities" => %{
                "type" => "bullet_list",
                "content" => Map.get(job, "responsibilities", []),
                "media_attachments" => []
              },
              "achievements" => %{
                "type" => "bullet_list",
                "content" => Map.get(job, "achievements", []),
                "media_attachments" => []
              }
            }
          }
        }
      end) |> Enum.into(%{})
    }
  end
  defp migrate_experience_content(_), do: %{}

  defp migrate_skills_content(content) when is_map(content) do
    skills = Map.get(content, "skills", [])
    skill_categories = Map.get(content, "skill_categories", %{})

    %{
      "header" => %{
        "type" => "header",
        "content" => %{
          "title" => "Skills & Expertise",
          "subtitle" => "My technical and professional capabilities"
        }
      },
      "skills_display" => %{
        "type" => "skills_visualization",
        "content" => %{
          "display_type" => "categories", # categories, cloud, bars, circles
          "skills" => transform_skills_for_visualization(skills, skill_categories)
        },
        "media_attachments" => []
      }
    }
  end
  defp migrate_skills_content(_), do: %{}

  defp transform_skills_for_visualization(skills, skill_categories) do
    if map_size(skill_categories) > 0 do
      # Use categorized skills
      Enum.map(skill_categories, fn {category, category_skills} ->
        %{
          "category" => category,
          "skills" => Enum.map(category_skills, fn skill ->
            case skill do
              %{"name" => name} = skill_data ->
                %{
                  "name" => name,
                  "proficiency" => Map.get(skill_data, "proficiency", "intermediate"),
                  "years" => Map.get(skill_data, "years"),
                  "level" => proficiency_to_level(Map.get(skill_data, "proficiency", "intermediate"))
                }
              skill_string when is_binary(skill_string) ->
                %{
                  "name" => skill_string,
                  "proficiency" => "intermediate",
                  "level" => 3
                }
            end
          end)
        }
      end)
    else
      # Convert simple skills list
      [%{
        "category" => "Skills",
        "skills" => Enum.map(skills, fn skill ->
          %{
            "name" => skill,
            "proficiency" => "intermediate",
            "level" => 3
          }
        end)
      }]
    end
  end

  defp proficiency_to_level(proficiency) do
    case proficiency do
      "beginner" -> 1
      "intermediate" -> 3
      "advanced" -> 4
      "expert" -> 5
      _ -> 3
    end
  end

  defp migrate_education_content(content) when is_map(content) do
    education = Map.get(content, "education", [])

    %{
      "header" => %{
        "type" => "header",
        "content" => %{
          "title" => "Education",
          "subtitle" => "My academic background and learning journey"
        }
      },
      "education_entries" => Enum.with_index(education, fn edu, index ->
        {
          "education_#{index}",
          %{
            "type" => "education_entry",
            "content" => %{
              "degree" => Map.get(edu, "degree", ""),
              "field" => Map.get(edu, "field", ""),
              "institution" => Map.get(edu, "institution", ""),
              "location" => Map.get(edu, "location", ""),
              "start_date" => Map.get(edu, "start_date", ""),
              "end_date" => Map.get(edu, "end_date", ""),
              "gpa" => Map.get(edu, "gpa", ""),
              "status" => Map.get(edu, "status", "Completed")
            },
            "content_blocks" => %{
              "description" => %{
                "type" => "rich_text",
                "content" => Map.get(edu, "description", ""),
                "media_attachments" => []
              },
              "coursework" => %{
                "type" => "bullet_list",
                "content" => Map.get(edu, "relevant_coursework", []),
                "media_attachments" => []
              },
              "activities" => %{
                "type" => "bullet_list",
                "content" => Map.get(edu, "activities", []),
                "media_attachments" => []
              }
            }
          }
        }
      end) |> Enum.into(%{})
    }
  end
  defp migrate_education_content(_), do: %{}

  defp migrate_projects_content(content) when is_map(content) do
    projects = Map.get(content, "projects", [])

    %{
      "header" => %{
        "type" => "header",
        "content" => %{
          "title" => "Projects",
          "subtitle" => "Showcasing my work and achievements"
        }
      },
      "projects" => Enum.with_index(projects, fn project, index ->
        {
          "project_#{index}",
          %{
            "type" => "project_entry",
            "content" => %{
              "title" => Map.get(project, "title", ""),
              "description" => Map.get(project, "description", ""),
              "technologies" => Map.get(project, "technologies", []),
              "url" => Map.get(project, "url", ""),
              "github_url" => Map.get(project, "github_url", ""),
              "start_date" => Map.get(project, "start_date", ""),
              "end_date" => Map.get(project, "end_date", ""),
              "status" => Map.get(project, "status", "completed")
            },
            "media_attachments" => []
          }
        }
      end) |> Enum.into(%{})
    }
  end
  defp migrate_projects_content(_), do: %{}

  defp migrate_intro_content(content) when is_map(content) do
    %{
      "hero" => %{
        "type" => "hero_section",
        "content" => %{
          "headline" => Map.get(content, "headline", ""),
          "tagline" => Map.get(content, "tagline", ""),
          "location" => Map.get(content, "location", "")
        },
        "media_attachments" => [] # For intro video
      },
      "summary" => %{
        "type" => "rich_text",
        "content" => Map.get(content, "summary", ""),
        "media_attachments" => []
      },
      "contact_info" => %{
        "type" => "contact_block",
        "content" => %{
          "email" => Map.get(content, "email", ""),
          "phone" => Map.get(content, "phone", ""),
          "website" => Map.get(content, "website", ""),
          "social_links" => Map.get(content, "social_links", %{})
        }
      }
    }
  end
  defp migrate_intro_content(_), do: %{}

  defp migrate_generic_content(content) when is_map(content) do
    %{
      "main_content" => %{
        "type" => "rich_text",
        "content" => extract_text_content(content),
        "media_attachments" => []
      }
    }
  end
  defp migrate_generic_content(_), do: %{}

  defp extract_text_content(content) when is_map(content) do
    content
    |> Map.values()
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
    |> String.trim()
  end

  # ============================================================================
  # ENHANCED VALIDATION & CLEANUP
  # ============================================================================

  @doc """
  Validate migrated portfolios with content blocks support
  """
  def validate_migration(options \\ %{}) do
    portfolios_without_accounts = from(p in Portfolios.Portfolio,
      where: is_nil(p.account_id)
    ) |> Repo.aggregate(:count, :id)

    sections_without_content_blocks = if options[:check_content_blocks] do
      from(s in Portfolios.PortfolioSection,
        left_join: cb in ContentBlock, on: cb.portfolio_section_id == s.id,
        where: is_nil(cb.id),
        select: count(s.id)
      ) |> Repo.one()
    else
      from(s in Portfolios.PortfolioSection,
        where: is_nil(s.content_blocks) or s.content_blocks == ^%{}
      ) |> Repo.aggregate(:count, :id)
    end

    content_blocks_stats = if options[:check_content_blocks] do
      %{
        total_blocks: Repo.aggregate(ContentBlock, :count, :id),
        monetization_blocks: from(cb in ContentBlock,
          where: fragment("?->>'enabled' = 'true'", cb.monetization_config)
        ) |> Repo.aggregate(:count, :id),
        streaming_blocks: from(cb in ContentBlock,
          where: fragment("?->>'enabled' = 'true'", cb.streaming_config)
        ) |> Repo.aggregate(:count, :id)
      }
    else
      %{}
    end

    %{
      portfolios_without_accounts: portfolios_without_accounts,
      sections_without_content_blocks: sections_without_content_blocks,
      content_blocks_stats: content_blocks_stats,
      migration_complete: portfolios_without_accounts == 0,
      enhanced_migration: options[:check_content_blocks] || false
    }
  end

  @doc """
  Enhanced cleanup with content blocks support
  """
  def cleanup_old_system_files do
    files_to_remove = [
      "lib/frestyl_web/live/portfolio_live/edit/tab_renderer.ex",
      "lib/frestyl_web/live/portfolio_live/edit/section_manager.ex",
      "lib/frestyl_web/live/portfolio_live/edit/media_manager.ex",
      "lib/frestyl_web/live/portfolio_live/edit/template_manager.ex"
    ]

    results = Enum.map(files_to_remove, fn file_path ->
      if File.exists?(file_path) do
        case File.rm(file_path) do
          :ok -> {:ok, file_path}
          {:error, reason} -> {:error, {file_path, reason}}
        end
      else
        {:ok, "#{file_path} (already removed)"}
      end
    end)

    {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

    %{
      removed_files: Enum.map(successes, fn {:ok, path} -> path end),
      failed_removals: Enum.map(failures, fn {:error, {path, reason}} ->
        %{path: path, reason: reason}
      end)
    }
  end

  @doc """
  Enhanced router configuration with content blocks routes
  """
  def update_router_configuration do
    """
    # Replace in router.ex:

    # OLD:
    # live "/portfolios/:id/edit", PortfolioLive.Edit, :edit

    # NEW:
    live "/portfolios/:id/edit", PortfolioLive.PortfolioEditor, :edit

    # Enhanced routes for content blocks system:
    live "/portfolios/:id/edit/content", PortfolioLive.PortfolioEditor, :content
    live "/portfolios/:id/edit/design", PortfolioLive.PortfolioEditor, :design
    live "/portfolios/:id/edit/monetization", PortfolioLive.PortfolioEditor, :monetization
    live "/portfolios/:id/edit/streaming", PortfolioLive.PortfolioEditor, :streaming
    live "/portfolios/:id/edit/analytics", PortfolioLive.PortfolioEditor, :analytics

    # Content block management routes:
    live "/portfolios/:id/blocks/:block_id/edit", PortfolioLive.BlockEditor, :edit
    live "/portfolios/:id/sections/:section_id/blocks/new", PortfolioLive.BlockBuilder, :new
    """
  end

  # ============================================================================
  # ENHANCED MIGRATION RUNNER
  # ============================================================================

  @doc """
  Run complete enhanced migration process
  """
  def run_complete_migration(options \\ %{}) do
    IO.puts("🚀 Starting enhanced portfolio system migration...")

    migration_options = Map.merge(%{
      strategy: "selective",
      enable_content_blocks: true,
      enable_monetization: false,
      enable_streaming: false
    }, options)

    # Step 1: Migrate portfolios to accounts with content blocks
    IO.puts("📂 Migrating portfolios to account system with content blocks...")
    portfolio_results = migrate_portfolios_to_accounts(migration_options)
    IO.puts("✅ Migrated #{portfolio_results.migrated} portfolios")
    IO.puts("🧱 Created #{portfolio_results.content_blocks_created} content blocks")

    if portfolio_results.failed > 0 do
      IO.puts("⚠️  Failed to migrate #{portfolio_results.failed} portfolios:")
      Enum.each(portfolio_results.failures, fn failure ->
        IO.puts("   - Portfolio #{failure.portfolio_id}: #{failure.reason}")
      end)
    end

    # Step 2: Validate enhanced migration
    IO.puts("🔍 Validating enhanced migration...")
    validation = validate_migration(%{check_content_blocks: migration_options.enable_content_blocks})

    if validation.migration_complete do
      IO.puts("✅ Migration validation passed!")

      if validation.enhanced_migration do
        IO.puts("📊 Content blocks statistics:")
        IO.puts("   - Total blocks: #{validation.content_blocks_stats.total_blocks}")
        IO.puts("   - Monetization blocks: #{validation.content_blocks_stats.monetization_blocks}")
        IO.puts("   - Streaming blocks: #{validation.content_blocks_stats.streaming_blocks}")
      end

      # Step 3: Cleanup old files
      IO.puts("🧹 Cleaning up old system files...")
      cleanup_results = cleanup_old_system_files()
      IO.puts("✅ Removed #{length(cleanup_results.removed_files)} old files")

      if length(cleanup_results.failed_removals) > 0 do
        IO.puts("⚠️  Failed to remove some files:")
        Enum.each(cleanup_results.failed_removals, fn failure ->
          IO.puts("   - #{failure.path}: #{failure.reason}")
        end)
      end

      IO.puts("🎉 Enhanced migration completed successfully!")
      IO.puts("📋 Next steps:")
      IO.puts("   1. Update your router configuration")
      IO.puts("   2. Run database migrations for content blocks")
      IO.puts("   3. Test the enhanced portfolio editor")
      IO.puts("   4. Configure monetization and streaming features")

    else
      IO.puts("❌ Migration validation failed:")
      IO.puts("   - Portfolios without accounts: #{validation.portfolios_without_accounts}")
      IO.puts("   - Sections without content blocks: #{validation.sections_without_content_blocks}")
    end

    validation
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
