# Create migration: mix ecto.gen.migration consolidate_portfolio_section_types

defmodule Frestyl.Repo.Migrations.ConsolidatePortfolioSectionTypes do
  use Ecto.Migration

  def up do
    # Map old types to new types
    execute """
    UPDATE portfolio_sections
    SET section_type = CASE
      WHEN section_type = 'testimonial' THEN 'testimonials'
      WHEN section_type = 'awards' THEN 'achievements'
      WHEN section_type = 'story' THEN 'intro'
      WHEN section_type = 'narrative' THEN 'intro'
      WHEN section_type = 'journey' THEN 'timeline'
      WHEN section_type = 'video_hero' THEN 'hero'
      WHEN section_type = 'about' THEN 'intro'
      WHEN section_type = 'profile' THEN 'intro'
      WHEN section_type = 'summary' THEN 'intro'
      WHEN section_type = 'writing' THEN 'published_articles'
      WHEN section_type = 'portfolio' THEN 'projects'
      WHEN section_type = 'work' THEN 'projects'
      ELSE section_type
    END
    WHERE section_type IN (
      'testimonial', 'awards', 'story', 'narrative', 'journey',
      'video_hero', 'about', 'profile', 'summary', 'writing',
      'portfolio', 'work'
    )
    """
  end

  def down do
    # Optionally provide rollback logic if needed
    # This is more complex since multiple types map to single types
  end
end
