defmodule Frestyl.Migration.PortfolioToStory do
  @moduledoc "Migrate existing portfolios to story-based architecture"

  alias Frestyl.Portfolios
  alias Frestyl.Stories
  alias Frestyl.Accounts
  alias Frestyl.Repo
  import Ecto.Query
  require Logger

  def migrate_user_portfolios(user) do
    {:ok, personal_account} = create_default_personal_account(user)

    # Get all portfolios for the user
    portfolios = Portfolios.list_user_portfolios(user.id)

    # Migrate each portfolio
    migration_results = Enum.map(portfolios, fn portfolio ->
      migrate_single_portfolio(portfolio, personal_account)
    end)

    # Send completion notification
    send_migration_completion_email(user, migration_results)

    %{
      total_portfolios: length(portfolios),
      migrated_stories: filter_successful_migrations(migration_results),
      failed_migrations: filter_failed_migrations(migration_results),
      personal_account: personal_account
    }
  end

  def create_default_personal_account(user) do
    # Create a default personal account for the user
    account_params = %{
      name: "#{user.email}'s Personal Account",
      user_id: user.id,
      account_type: :personal,
      subscription_tier: user.subscription_tier || "free",
      created_at: DateTime.utc_now()
    }

    # Placeholder - in real implementation you'd use Accounts context
    {:ok, %{id: System.unique_integer([:positive]), name: account_params.name}}
  end

  def migrate_single_portfolio(portfolio, account) do
    try do
      # Create story from portfolio
      story_params = %{
        title: portfolio.title,
        description: portfolio.description,
        sharing_model: map_portfolio_visibility(portfolio.visibility),
        narrative_structure: infer_narrative_structure(portfolio),
        account_id: account.id,
        created_at: portfolio.inserted_at,
        updated_at: portfolio.updated_at
      }

      # Create the story (placeholder)
      story = %{id: System.unique_integer([:positive]), title: story_params.title}

      # Migrate portfolio sections to story chapters
      migrate_portfolio_sections(portfolio, story)

      # Migrate media files
      migrate_portfolio_media(portfolio, story)

      # Migrate analytics data
      migrate_portfolio_analytics(portfolio, story)

      # Create redirect from old portfolio URL to new story
      create_portfolio_redirect(portfolio, story)

      {:ok, story}
    rescue
      error ->
        Logger.error("Failed to migrate portfolio #{portfolio.id}: #{Exception.message(error)}")
        {:error, Exception.message(error)}
    end
  end

  def map_portfolio_visibility(visibility) do
    case visibility do
      :public -> :public
      :link_only -> :link_access
      :private -> :private
      _ -> :private
    end
  end

  def infer_narrative_structure(portfolio) do
    # Analyze portfolio structure and infer narrative approach
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    cond do
      has_timeline_structure?(sections) -> :chronological
      has_project_focus?(sections) -> :project_based
      has_skill_focus?(sections) -> :capability_based
      true -> :general
    end
  end

  def map_section_type_to_chapter_type(section_type) do
    case section_type do
      "about" -> "introduction"
      "experience" -> "timeline"
      "projects" -> "showcase"
      "skills" -> "capabilities"
      "education" -> "background"
      "contact" -> "connect"
      _ -> "content"
    end
  end

  def enhance_content_for_story_format(content) do
    # Enhance portfolio content for story format
    # Add narrative elements, improve structure
    case content do
      map when is_map(map) ->
        Map.put(map, :story_enhanced, true)
      _ ->
        %{original_content: content, story_enhanced: true}
    end
  end

  def migrate_portfolio_media(portfolio, story) do
    # Placeholder - migrate media files from portfolio to story
    Logger.info("Migrating media for portfolio #{portfolio.id} to story #{story.id}")
    :ok
  end

  def migrate_portfolio_analytics(portfolio, story) do
    # Placeholder - migrate analytics data
    Logger.info("Migrating analytics for portfolio #{portfolio.id} to story #{story.id}")
    :ok
  end

  def create_portfolio_redirect(portfolio, story) do
    # Create redirect from old portfolio URL to new story URL
    redirect_params = %{
      old_slug: portfolio.slug,
      new_story_id: story.id,
      redirect_type: :permanent,
      created_at: DateTime.utc_now()
    }

    Logger.info("Creating redirect from portfolio #{portfolio.slug} to story #{story.id}")
    :ok
  end

  def filter_successful_migrations(results) do
    Enum.filter(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {:ok, story} -> story end)
  end

  def filter_failed_migrations(results) do
    Enum.filter(results, fn
      {:error, _} -> true
      _ -> false
    end)
  end

  def send_migration_completion_email(user, results) do
    successful_count = length(filter_successful_migrations(results))
    failed_count = length(filter_failed_migrations(results))

    Logger.info("Sending migration completion email to #{user.email}: #{successful_count} successful, #{failed_count} failed")

    # Placeholder - send actual email notification
    :ok
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp has_timeline_structure?(sections) do
    timeline_types = ["experience", "education", "timeline"]
    Enum.any?(sections, fn section -> section.section_type in timeline_types end)
  end

  defp has_project_focus?(sections) do
    project_types = ["projects", "portfolio", "work"]
    project_sections = Enum.filter(sections, fn section -> section.section_type in project_types end)
    length(project_sections) >= 2
  end

  defp has_skill_focus?(sections) do
    skill_types = ["skills", "capabilities", "technologies"]
    Enum.any?(sections, fn section -> section.section_type in skill_types end)
  end

  defp infer_story_type_from_portfolio(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)
    section_types = Enum.map(sections, & &1.section_type)

    cond do
      "case_study" in section_types -> :case_study
      "projects" in section_types && "experience" in section_types -> :professional_showcase
      "creative_work" in section_types -> :creative_portfolio
      true -> :personal_narrative
    end
  end

  defp migrate_portfolio_sections(portfolio, story) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    Enum.each(sections, fn section ->
      chapter_attrs = %{
        story_id: story.id,
        title: section.title,
        chapter_type: map_section_type_to_chapter_type(section.section_type),
        content: enhance_content_for_story_format(section.content),
        position: section.position,
        visible: section.visible,

        # Migration tracking
        migrated_from_section_id: section.id
      }

      Stories.create_chapter(chapter_attrs)
    end)
  end
end
