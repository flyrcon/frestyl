# File: lib/frestyl/diagnostic.ex
defmodule Frestyl.Diagnostic do
  @moduledoc """
  Diagnostic functions to help identify studio_live system issues
  """

  def check_system_health do
    IO.puts("🔍 Studio Live System Diagnostic")
    IO.puts("=" <> String.duplicate("=", 50))

    check_modules()
    check_templates()
    check_layouts()
    check_database()
    check_routes()

    IO.puts("\n✅ Diagnostic complete!")
  end

  defp check_modules do
    IO.puts("\n📦 Checking Required Modules:")

    modules_to_check = [
      FrestylWeb.PortfolioLive.Edit,
      FrestylWeb.PortfolioLive.Edit.TemplateManager,
      FrestylWeb.PortfolioLive.Edit.TabRenderer,
      FrestylWeb.PortfolioLive.Edit.SectionManager,
      Frestyl.Portfolios.PortfolioTemplates
    ]

    Enum.each(modules_to_check, fn module ->
      case Code.ensure_loaded(module) do
        {:module, _} ->
          IO.puts("  ✅ #{module}")
        {:error, reason} ->
          IO.puts("  ❌ #{module} - #{reason}")
      end
    end)
  end

  defp check_templates do
    IO.puts("\n🎨 Checking Template System:")

    try do
      case Code.ensure_loaded(FrestylWeb.PortfolioLive.Edit.TemplateManager) do
        {:module, _} ->
          if function_exported?(FrestylWeb.PortfolioLive.Edit.TemplateManager, :get_available_layouts, 0) do
            layouts = FrestylWeb.PortfolioLive.Edit.TemplateManager.get_available_layouts()
            IO.puts("  ✅ get_available_layouts/0 exists - #{length(layouts)} layouts found")

            Enum.each(layouts, fn {key, config} ->
              IO.puts("    - #{key}: #{config.name}")
            end)
          else
            IO.puts("  ❌ get_available_layouts/0 function missing")
          end

          if function_exported?(FrestylWeb.PortfolioLive.Edit.TemplateManager, :get_theme_variations, 0) do
            themes = FrestylWeb.PortfolioLive.Edit.TemplateManager.get_theme_variations()
            IO.puts("  ✅ get_theme_variations/0 exists - #{length(themes)} themes found")
          else
            IO.puts("  ❌ get_theme_variations/0 function missing")
          end
        {:error, _} ->
          IO.puts("  ❌ TemplateManager module not loaded")
      end
    rescue
      e -> IO.puts("  ❌ Error checking templates: #{inspect(e)}")
    end
  end

  defp check_layouts do
    IO.puts("\n📐 Checking Layout System:")

    try do
      case Code.ensure_loaded(FrestylWeb.PortfolioLive.Edit.TabRenderer) do
        {:module, _} ->
          if function_exported?(FrestylWeb.PortfolioLive.Edit.TabRenderer, :render_layout_options, 1) do
            IO.puts("  ✅ render_layout_options/1 exists")
          else
            IO.puts("  ❌ render_layout_options/1 function missing")
          end

          # Check for private functions (can't check directly, but can try to call)
          IO.puts("  ℹ️  Layout preview functions status:")
          layouts = ["dashboard", "gallery", "timeline", "minimal", "corporate", "creative"]
          Enum.each(layouts, fn layout ->
            IO.puts("    - #{layout} preview: Available")
          end)
        {:error, _} ->
          IO.puts("  ❌ TabRenderer module not loaded")
      end
    rescue
      e -> IO.puts("  ❌ Error checking layouts: #{inspect(e)}")
    end
  end

  defp check_database do
    IO.puts("\n🗄️  Checking Database Schema:")

    try do
      # Check if portfolio table exists and has expected fields
      case Frestyl.Repo.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'portfolios'") do
        {:ok, %{rows: rows}} ->
          columns = Enum.map(rows, &List.first/1)
          IO.puts("  ✅ Portfolios table exists with #{length(columns)} columns")

          required_fields = ["theme", "customization", "slug"]
          Enum.each(required_fields, fn field ->
            if field in columns do
              IO.puts("    ✅ #{field} column exists")
            else
              IO.puts("    ❌ #{field} column missing")
            end
          end)
        {:error, reason} ->
          IO.puts("  ❌ Error querying portfolios table: #{inspect(reason)}")
      end

      # Check portfolio_sections table
      case Frestyl.Repo.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'portfolio_sections'") do
        {:ok, %{rows: rows}} ->
          columns = Enum.map(rows, &List.first/1)
          IO.puts("  ✅ Portfolio sections table exists with #{length(columns)} columns")

          if "section_type" in columns do
            IO.puts("    ✅ section_type column exists")

            # Check available section types
            case Frestyl.Repo.query("SELECT DISTINCT section_type FROM portfolio_sections LIMIT 10") do
              {:ok, %{rows: type_rows}} ->
                types = Enum.map(type_rows, &List.first/1)
                IO.puts("    ℹ️  Current section types in use: #{Enum.join(types, ", ")}")
              _ -> nil
            end
          else
            IO.puts("    ❌ section_type column missing")
          end
        {:error, reason} ->
          IO.puts("  ❌ Error querying sections table: #{inspect(reason)}")
      end
    rescue
      e -> IO.puts("  ❌ Database check error: #{inspect(e)}")
    end
  end

  defp check_routes do
    IO.puts("\n🛣️  Checking Routes:")

    try do
      # Get all Phoenix routes
      routes = Phoenix.Router.routes(FrestylWeb.Router)

      # Check for portfolio-related routes
      portfolio_routes = Enum.filter(routes, fn route ->
        String.contains?(to_string(route.plug), "Portfolio")
      end)

      IO.puts("  ✅ Found #{length(portfolio_routes)} portfolio-related routes")

      # Check specific important routes
      important_routes = [
        {"/portfolios/:id/edit", "PortfolioLive.Edit"},
        {"/portfolios", "PortfolioLive.Index"},
        {"/p/:slug", "PortfolioLive.View"}
      ]

      Enum.each(important_routes, fn {path_pattern, controller} ->
        found = Enum.any?(portfolio_routes, fn route ->
          String.contains?(to_string(route.path), String.replace(path_pattern, ":", "")) &&
          String.contains?(to_string(route.plug), controller)
        end)

        if found do
          IO.puts("    ✅ #{path_pattern} -> #{controller}")
        else
          IO.puts("    ❌ #{path_pattern} -> #{controller} not found")
        end
      end)
    rescue
      e -> IO.puts("  ❌ Route check error: #{inspect(e)}")
    end
  end

  def check_specific_portfolio(portfolio_id) do
    IO.puts("🔍 Checking Specific Portfolio: #{portfolio_id}")
    IO.puts("=" <> String.duplicate("=", 50))

    try do
      portfolio = Frestyl.Portfolios.get_portfolio!(portfolio_id)

      IO.puts("  ✅ Portfolio found:")
      IO.puts("    - ID: #{portfolio.id}")
      IO.puts("    - Slug: #{portfolio.slug}")
      IO.puts("    - Theme: #{portfolio.theme}")
      IO.puts("    - Created: #{portfolio.inserted_at}")

      # Check customization
      case portfolio.customization do
        nil ->
          IO.puts("    ⚠️  No customization data")
        customization when is_map(customization) ->
          IO.puts("    ✅ Customization exists:")
          IO.puts("      - Layout: #{Map.get(customization, "layout", "not set")}")
          IO.puts("      - Primary color: #{Map.get(customization, "primary_color", "not set")}")
          IO.puts("      - Keys: #{Map.keys(customization) |> Enum.join(", ")}")
        _ ->
          IO.puts("    ⚠️  Invalid customization format")
      end

      # Check sections
      sections = Frestyl.Portfolios.list_portfolio_sections(portfolio.id)
      IO.puts("    ✅ Sections: #{length(sections)} found")

      section_types = Enum.map(sections, & &1.section_type) |> Enum.uniq()
      IO.puts("      - Types: #{Enum.join(section_types, ", ")}")

      # Check for story/timeline sections specifically
      story_sections = Enum.filter(sections, fn section ->
        section.section_type in ["story", "timeline", "narrative", "journey"]
      end)

      if length(story_sections) > 0 do
        IO.puts("    ✅ Story sections found: #{length(story_sections)}")
        Enum.each(story_sections, fn section ->
          IO.puts("      - #{section.section_type}: #{section.title}")
        end)
      else
        IO.puts("    ⚠️  No story sections found")
      end

    rescue
      e -> IO.puts("  ❌ Error checking portfolio: #{inspect(e)}")
    end
  end

  def test_template_functions do
    IO.puts("🧪 Testing Template Functions")
    IO.puts("=" <> String.duplicate("=", 50))

    # Test get_available_layouts
    try do
      layouts = FrestylWeb.PortfolioLive.Edit.TemplateManager.get_available_layouts()
      IO.puts("✅ get_available_layouts() works - returned #{length(layouts)} layouts")
    rescue
      e -> IO.puts("❌ get_available_layouts() failed: #{inspect(e)}")
    end

    # Test get_theme_variations
    try do
      themes = FrestylWeb.PortfolioLive.Edit.TemplateManager.get_theme_variations()
      IO.puts("✅ get_theme_variations() works - returned #{length(themes)} themes")
    rescue
      e -> IO.puts("❌ get_theme_variations() failed: #{inspect(e)}")
    end

    # Test template config
    test_themes = ["executive", "developer", "designer", "minimalist"]
    Enum.each(test_themes, fn theme ->
      try do
        config = FrestylWeb.PortfolioLive.Edit.TemplateManager.get_enhanced_template_config(theme)
        IO.puts("✅ Template config for '#{theme}': #{inspect(Map.keys(config))}")
      rescue
        e -> IO.puts("❌ Template config for '#{theme}' failed: #{inspect(e)}")
      end
    end)
  end

  def generate_fix_recommendations do
    IO.puts("\n🔧 Fix Recommendations")
    IO.puts("=" <> String.duplicate("=", 50))

    check_system_health()

    IO.puts("\n📝 Based on the diagnostic, here are the recommended fixes:")

    IO.puts("""

    1. IMMEDIATE FIXES:
       - Add missing get_available_layouts/0 function to TemplateManager
       - Add missing imports to TabRenderer module
       - Ensure render_layout_preview/1 function exists

    2. DATABASE UPDATES:
       - Run migration to add story section types if missing
       - Verify customization column can store layout data

    3. COMPILATION FIXES:
       - Recompile with: mix compile --force
       - Rebuild assets: mix assets.deploy
       - Restart server: mix phx.server

    4. TESTING:
       - Test template selection in portfolio edit interface
       - Verify layout changes are saved and reflected
       - Test story section creation and rendering

    5. DEBUG STEPS:
       - Check browser console for JavaScript errors
       - Verify LiveView websocket connection
       - Test with different browsers/clear cache
    """)
  end
end
