# lib/frestyl/portfolios/phase4_migration.ex
defmodule Frestyl.Portfolios.Phase4Migration do
  @moduledoc """
  Migration script to convert all portfolios to Dynamic Card Layout system.
  Run this once during Phase 4 deployment to ensure all portfolios work.
  """

  alias Frestyl.{Repo, Portfolios}
  alias Frestyl.Portfolios.Portfolio
  import Ecto.Query

  @doc """
  Migrate all portfolios to use Dynamic Card Layout.
  This ensures backward compatibility during Phase 4 rollout.
  """
  def migrate_all_portfolios do
    IO.puts("🚀 Starting Phase 4 Portfolio Migration...")

    portfolios =
      Portfolio
      |> preload([:sections, :user, :account])
      |> Repo.all()

    total_count = length(portfolios)
    IO.puts("Found #{total_count} portfolios to migrate")

    results =
      portfolios
      |> Enum.with_index(1)
      |> Enum.map(fn {portfolio, index} ->
        IO.puts("Migrating portfolio #{index}/#{total_count}: #{portfolio.title}")
        migrate_single_portfolio(portfolio)
      end)

    success_count = Enum.count(results, fn result -> result == :ok end)
    error_count = total_count - success_count

    IO.puts("✅ Migration complete!")
    IO.puts("   Successful: #{success_count}")
    IO.puts("   Errors: #{error_count}")

    if error_count > 0 do
      IO.puts("⚠️  Check logs for error details")
    end

    :ok
  end

  @doc """
  Migrate a single portfolio to Dynamic Card Layout.
  """
  def migrate_single_portfolio(portfolio) do
    try do
      # 1. Ensure portfolio has dynamic layout flag
      updated_customization = ensure_dynamic_layout_customization(portfolio.customization)

      # 2. Convert sections to dynamic blocks structure if needed
      sections = portfolio.sections || []

      if length(sections) > 0 do
        # Portfolio has traditional sections - convert them
        content_blocks = convert_sections_to_dynamic_blocks(sections)
        layout_zones = organize_blocks_into_zones(content_blocks, portfolio)

        # 3. Update portfolio with new structure
        portfolio_updates = %{
          customization: Map.merge(updated_customization, %{
            "dynamic_content_blocks" => content_blocks,
            "dynamic_layout_zones" => layout_zones,
            "migrated_to_dynamic" => true,
            "migration_date" => DateTime.utc_now() |> DateTime.to_iso8601()
          })
        }

        case Portfolios.update_portfolio(portfolio, portfolio_updates) do
          {:ok, _updated_portfolio} ->
            IO.puts("   ✅ Successfully migrated: #{portfolio.title}")
            :ok

          {:error, changeset} ->
            IO.puts("   ❌ Failed to migrate: #{portfolio.title}")
            IO.puts("      Errors: #{inspect(changeset.errors)}")
            :error
        end
      else
        # Portfolio has no sections - just update customization
        case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
          {:ok, _updated_portfolio} ->
            IO.puts("   ✅ Updated customization: #{portfolio.title}")
            :ok

          {:error, changeset} ->
            IO.puts("   ❌ Failed to update: #{portfolio.title}")
            IO.puts("      Errors: #{inspect(changeset.errors)}")
            :error
        end
      end

    rescue
      error ->
        IO.puts("   ❌ Exception migrating: #{portfolio.title}")
        IO.puts("      Error: #{Exception.message(error)}")
        :error
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp ensure_dynamic_layout_customization(nil) do
    get_default_dynamic_customization()
  end

  defp ensure_dynamic_layout_customization(customization) when is_map(customization) do
    default_customization = get_default_dynamic_customization()

    # Merge existing customization with dynamic layout defaults
    Map.merge(default_customization, customization)
    |> Map.put("use_dynamic_layout", true)
    |> Map.put("layout_system", "dynamic_cards")
  end

  defp get_default_dynamic_customization do
    %{
      "use_dynamic_layout" => true,
      "layout_system" => "dynamic_cards",
      "color_scheme" => "professional",
      "layout_style" => "dashboard",
      "section_spacing" => "normal",
      "font_style" => "inter",
      "fixed_navigation" => true,
      "dark_mode_support" => false,
      "design_system" => %{
        "theme_template" => "modern",
        "public_layout_type" => "dashboard",
        "primary_color" => "#1e40af",
        "secondary_color" => "#64748b",
        "accent_color" => "#3b82f6",
        "font_family" => "inter",
        "enable_animations" => true
      }
    }
  end

  defp convert_sections_to_dynamic_blocks(sections) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      %{
        "id" => "migrated_#{section.id}",
        "original_section_id" => section.id,
        "block_type" => map_section_type_to_block_type(section.section_type),
        "position" => index,
        "visible" => Map.get(section, :visible, true),
        "content_data" => extract_section_content(section),
        "migration_source" => "traditional_section",
        "migrated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    end)
  end

  defp map_section_type_to_block_type(section_type) do
    case to_string(section_type) do
      "intro" -> "about_card"
      "about" -> "about_card"
      "media_showcase" -> "hero_card"
      "hero" -> "hero_card"
      "experience" -> "experience_card"
      "work_experience" -> "experience_card"
      "achievements" -> "achievement_card"
      "skills" -> "skill_card"
      "portfolio" -> "project_card"
      "projects" -> "project_card"
      "services" -> "service_card"
      "testimonials" -> "testimonial_card"
      "contact" -> "contact_card"
      "education" -> "education_card"
      "certifications" -> "certification_card"
      _ -> "text_card" # Default fallback
    end
  end

  defp extract_section_content(section) do
    content = section.content || %{}

    %{
      "title" => section.title || Map.get(content, "title") || "Section Title",
      "description" => Map.get(content, "description"),
      "content" => Map.get(content, "main_content") || Map.get(content, "content"),
      "subtitle" => Map.get(content, "subtitle"),
      "summary" => Map.get(content, "summary"),
      # Preserve all original content for specific handling
      "original_content" => content,
      # Add metadata
      "section_type" => section.section_type,
      "position" => section.position
    }
  end

  defp organize_blocks_into_zones(content_blocks, portfolio) do
    # Determine portfolio category for zone organization
    category = determine_portfolio_category(portfolio)

    case category do
      :service_provider ->
        %{
          "hero" => filter_blocks_by_types(content_blocks, ["hero_card"]),
          "about" => filter_blocks_by_types(content_blocks, ["about_card"]),
          "services" => filter_blocks_by_types(content_blocks, ["service_card"]),
          "experience" => filter_blocks_by_types(content_blocks, ["experience_card"]),
          "testimonials" => filter_blocks_by_types(content_blocks, ["testimonial_card"]),
          "contact" => filter_blocks_by_types(content_blocks, ["contact_card"])
        }

      :creative_showcase ->
        %{
          "hero" => filter_blocks_by_types(content_blocks, ["hero_card"]),
          "about" => filter_blocks_by_types(content_blocks, ["about_card"]),
          "portfolio" => filter_blocks_by_types(content_blocks, ["project_card"]),
          "skills" => filter_blocks_by_types(content_blocks, ["skill_card"]),
          "experience" => filter_blocks_by_types(content_blocks, ["experience_card"]),
          "contact" => filter_blocks_by_types(content_blocks, ["contact_card"])
        }

      :technical_expert ->
        %{
          "hero" => filter_blocks_by_types(content_blocks, ["hero_card"]),
          "about" => filter_blocks_by_types(content_blocks, ["about_card"]),
          "skills" => filter_blocks_by_types(content_blocks, ["skill_card"]),
          "experience" => filter_blocks_by_types(content_blocks, ["experience_card"]),
          "projects" => filter_blocks_by_types(content_blocks, ["project_card"]),
          "achievements" => filter_blocks_by_types(content_blocks, ["achievement_card"]),
          "contact" => filter_blocks_by_types(content_blocks, ["contact_card"])
        }

      _ -> # Default/fallback organization
        %{
          "hero" => filter_blocks_by_types(content_blocks, ["hero_card"]),
          "main_content" => filter_blocks_by_types(content_blocks, ["about_card", "text_card"]),
          "experience" => filter_blocks_by_types(content_blocks, ["experience_card", "achievement_card"]),
          "portfolio" => filter_blocks_by_types(content_blocks, ["project_card", "service_card"]),
          "contact" => filter_blocks_by_types(content_blocks, ["contact_card"])
        }
    end
  end

  defp filter_blocks_by_types(blocks, types) do
    Enum.filter(blocks, fn block ->
      block["block_type"] in types
    end)
    |> Enum.sort_by(& &1["position"])
  end

  defp determine_portfolio_category(portfolio) do
    theme = portfolio.theme || "professional"
    customization = portfolio.customization || %{}
    layout = Map.get(customization, "layout", theme)

    case layout do
      theme when theme in ["professional_service", "consultant", "freelancer"] -> :service_provider
      theme when theme in ["creative", "designer", "artist", "photographer"] -> :creative_showcase
      theme when theme in ["developer", "engineer", "tech", "technical"] -> :technical_expert
      theme when theme in ["creator", "influencer", "content", "media"] -> :content_creator
      _ -> :service_provider # Default
    end
  end

  # ============================================================================
  # ROLLBACK FUNCTIONALITY (if needed)
  # ============================================================================

  @doc """
  Rollback migration for a portfolio (emergency use only).
  """
  def rollback_portfolio_migration(portfolio_id) do
    IO.puts("🔄 Rolling back migration for portfolio #{portfolio_id}")

    portfolio = Repo.get!(Portfolio, portfolio_id)
    customization = portfolio.customization || %{}

    # Remove dynamic layout flags
    updated_customization =
      customization
      |> Map.put("use_dynamic_layout", false)
      |> Map.put("layout_system", "traditional")
      |> Map.delete("dynamic_content_blocks")
      |> Map.delete("dynamic_layout_zones")
      |> Map.delete("migrated_to_dynamic")
      |> Map.delete("migration_date")

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, _updated_portfolio} ->
        IO.puts("✅ Rollback successful")
        :ok

      {:error, changeset} ->
        IO.puts("❌ Rollback failed: #{inspect(changeset.errors)}")
        :error
    end
  end

  # ============================================================================
  # VERIFICATION FUNCTIONS
  # ============================================================================

  @doc """
  Verify that all portfolios have been successfully migrated.
  """
  def verify_migration do
    IO.puts("🔍 Verifying Phase 4 migration...")

    portfolios = Repo.all(Portfolio)
    total_count = length(portfolios)

    migrated_count =
      Enum.count(portfolios, fn portfolio ->
        customization = portfolio.customization || %{}
        Map.get(customization, "use_dynamic_layout", false) == true
      end)

    pending_count = total_count - migrated_count

    IO.puts("📊 Migration Status:")
    IO.puts("   Total portfolios: #{total_count}")
    IO.puts("   Migrated: #{migrated_count}")
    IO.puts("   Pending: #{pending_count}")

    if pending_count > 0 do
      IO.puts("\n⚠️  Portfolios still needing migration:")

      portfolios
      |> Enum.filter(fn portfolio ->
        customization = portfolio.customization || %{}
        Map.get(customization, "use_dynamic_layout", false) != true
      end)
      |> Enum.each(fn portfolio ->
        IO.puts("   - #{portfolio.title} (ID: #{portfolio.id})")
      end)

      IO.puts("\nRun: Frestyl.Portfolios.Phase4Migration.migrate_all_portfolios()")
    else
      IO.puts("✅ All portfolios successfully migrated!")
    end

    %{
      total: total_count,
      migrated: migrated_count,
      pending: pending_count,
      success_rate: Float.round(migrated_count / total_count * 100, 2)
    }
  end

  @doc """
  Check if a specific portfolio is ready for Phase 4.
  """
  def check_portfolio_readiness(portfolio_id) do
    portfolio = Repo.get!(Portfolio, portfolio_id)
    customization = portfolio.customization || %{}

    checks = %{
      has_dynamic_flag: Map.get(customization, "use_dynamic_layout", false),
      has_layout_system: Map.get(customization, "layout_system") == "dynamic_cards",
      has_design_system: Map.has_key?(customization, "design_system"),
      is_migrated: Map.get(customization, "migrated_to_dynamic", false),
      sections_count: length(portfolio.sections || [])
    }

    is_ready = checks.has_dynamic_flag && checks.has_layout_system

    IO.puts("Portfolio: #{portfolio.title}")
    IO.puts("Ready for Phase 4: #{if is_ready, do: "✅ Yes", else: "❌ No"}")
    IO.puts("Checks:")
    Enum.each(checks, fn {key, value} ->
      status = if value, do: "✅", else: "❌"
      IO.puts("  #{status} #{key}: #{value}")
    end)

    {is_ready, checks}
  end

  # ============================================================================
  # BATCH OPERATIONS
  # ============================================================================

  @doc """
  Migrate portfolios in batches to avoid memory issues.
  """
  def migrate_portfolios_in_batches(batch_size \\ 50) do
    IO.puts("🚀 Starting batch migration (batch size: #{batch_size})")

    total_count = Repo.aggregate(Portfolio, :count, :id)
    batch_count = ceil(total_count / batch_size)

    IO.puts("Processing #{total_count} portfolios in #{batch_count} batches")

    results =
      0..(batch_count - 1)
      |> Enum.map(fn batch_index ->
        offset = batch_index * batch_size
        IO.puts("Processing batch #{batch_index + 1}/#{batch_count} (offset: #{offset})")

        portfolios =
          Portfolio
          |> preload([:sections, :user, :account])
          |> limit(^batch_size)
          |> offset(^offset)
          |> Repo.all()

        batch_results =
          portfolios
          |> Enum.map(&migrate_single_portfolio/1)

        success_count = Enum.count(batch_results, fn result -> result == :ok end)
        IO.puts("Batch #{batch_index + 1} complete: #{success_count}/#{length(portfolios)} successful")

        batch_results
      end)
      |> List.flatten()

    success_count = Enum.count(results, fn result -> result == :ok end)
    error_count = total_count - success_count

    IO.puts("🎉 Batch migration complete!")
    IO.puts("   Total: #{total_count}")
    IO.puts("   Successful: #{success_count}")
    IO.puts("   Errors: #{error_count}")

    :ok
  end

  # ============================================================================
  # DEVELOPMENT/TESTING HELPERS
  # ============================================================================

  @doc """
  Migrate a single portfolio by ID (for testing).
  """
  def migrate_portfolio_by_id(portfolio_id) do
    portfolio =
      Portfolio
      |> preload([:sections, :user, :account])
      |> Repo.get!(portfolio_id)

    migrate_single_portfolio(portfolio)
  end

  @doc """
  Reset a portfolio to traditional layout (for testing rollbacks).
  """
  def reset_portfolio_to_traditional(portfolio_id) do
    portfolio = Repo.get!(Portfolio, portfolio_id)

    traditional_customization = %{
      "use_dynamic_layout" => false,
      "layout_system" => "traditional",
      "color_scheme" => "professional",
      "layout_style" => "single_page",
      "section_spacing" => "normal",
      "font_style" => "inter"
    }

    case Portfolios.update_portfolio(portfolio, %{customization: traditional_customization}) do
      {:ok, _updated_portfolio} ->
        IO.puts("✅ Portfolio reset to traditional layout")
        :ok

      {:error, changeset} ->
        IO.puts("❌ Reset failed: #{inspect(changeset.errors)}")
        :error
    end
  end

  @doc """
  Get migration statistics.
  """
  def migration_stats do
    portfolios = Repo.all(Portfolio)
    total = length(portfolios)

    stats = %{
      total_portfolios: total,
      migrated: 0,
      traditional: 0,
      with_sections: 0,
      without_sections: 0,
      by_theme: %{}
    }

    portfolios
    |> Enum.reduce(stats, fn portfolio, acc ->
      customization = portfolio.customization || %{}
      is_migrated = Map.get(customization, "use_dynamic_layout", false)
      sections_count = length(portfolio.sections || [])
      theme = portfolio.theme || "unknown"

      acc
      |> Map.update!(:migrated, fn count -> if is_migrated, do: count + 1, else: count end)
      |> Map.update!(:traditional, fn count -> if is_migrated, do: count, else: count + 1 end)
      |> Map.update!(:with_sections, fn count -> if sections_count > 0, do: count + 1, else: count end)
      |> Map.update!(:without_sections, fn count -> if sections_count == 0, do: count + 1, else: count end)
      |> Map.update!(:by_theme, fn themes -> Map.update(themes, theme, 1, &(&1 + 1)) end)
    end)
    |> Map.put(:migration_percentage, Float.round(stats.migrated / total * 100, 2))
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp safe_string_to_atom(string) when is_binary(string) do
    try do
      String.to_existing_atom(string)
    rescue
      ArgumentError -> :unknown
    end
  end

  defp safe_string_to_atom(_), do: :unknown
end

# ============================================================================
# TASK FOR RUNNING MIGRATION VIA MIX
# ============================================================================

defmodule Mix.Tasks.Portfolios.MigrateToPhase4 do
  @moduledoc """
  Mix task to migrate all portfolios to Phase 4 Dynamic Card Layout.

  Usage:
    mix portfolios.migrate_to_phase4
    mix portfolios.migrate_to_phase4 --batch-size 25
    mix portfolios.migrate_to_phase4 --verify-only
  """

  use Mix.Task
  alias Frestyl.Portfolios.Phase4Migration

  @shortdoc "Migrate portfolios to Phase 4 Dynamic Card Layout"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _args, _invalid} = OptionParser.parse(args,
      switches: [
        batch_size: :integer,
        verify_only: :boolean,
        help: :boolean
      ],
      aliases: [
        b: :batch_size,
        v: :verify_only,
        h: :help
      ]
    )

    cond do
      opts[:help] ->
        show_help()

      opts[:verify_only] ->
        Phase4Migration.verify_migration()

      opts[:batch_size] ->
        Phase4Migration.migrate_portfolios_in_batches(opts[:batch_size])

      true ->
        Phase4Migration.migrate_all_portfolios()
    end
  end

  defp show_help do
    IO.puts("""

    Portfolio Phase 4 Migration Tool

    This tool migrates all portfolios from traditional sections to Dynamic Card Layout.

    Usage:
      mix portfolios.migrate_to_phase4                    # Migrate all portfolios
      mix portfolios.migrate_to_phase4 --batch-size 25    # Migrate in batches of 25
      mix portfolios.migrate_to_phase4 --verify-only      # Just check migration status
      mix portfolios.migrate_to_phase4 --help             # Show this help

    Options:
      --batch-size, -b    Process portfolios in batches (default: 50)
      --verify-only, -v   Only verify migration status, don't migrate
      --help, -h          Show this help message

    Examples:
      mix portfolios.migrate_to_phase4
      mix portfolios.migrate_to_phase4 -b 10
      mix portfolios.migrate_to_phase4 -v

    """)
  end
end
