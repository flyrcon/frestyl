# priv/repo/migrations/004_add_story_fields_to_portfolios.exs
defmodule Frestyl.Repo.Migrations.AddStoryFieldsToPortfolios do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add :story_type, :string
      add :narrative_structure, :string, default: "chronological"
      add :target_audience, :string
      add :story_tags, {:array, :string}, default: []
      add :estimated_read_time, :integer, default: 0
      add :collaboration_settings, :map, default: %{}
    end

    # Add constraints
    create constraint(:portfolios, :valid_story_type,
      check: "story_type IN ('personal_narrative', 'professional_showcase', 'brand_story', 'case_study', 'creative_portfolio', 'educational_content')")

    create constraint(:portfolios, :valid_narrative_structure,
      check: "narrative_structure IN ('chronological', 'hero_journey', 'case_study', 'before_after', 'problem_solution')")
  end
end
