# Database Migration to Fix Section Type Constraint
# Create this file: priv/repo/migrations/[timestamp]_update_portfolio_section_types.exs

defmodule Frestyl.Repo.Migrations.UpdatePortfolioSectionTypes do
  use Ecto.Migration

  def up do
    # First, check what constraint exists and drop it
    execute("ALTER TABLE portfolio_sections DROP CONSTRAINT IF EXISTS portfolio_sections_section_type_check")

    # Since the enum doesn't exist, we're likely dealing with a string column with check constraint
    # Let's add a new check constraint that includes all the section types
    execute("""
      ALTER TABLE portfolio_sections
      ADD CONSTRAINT portfolio_sections_section_type_check
      CHECK (section_type IN (
        'hero',
        'intro',
        'contact',
        'experience',
        'education',
        'skills',
        'projects',
        'certifications',
        'services',
        'achievements',
        'testimonials',
        'published_articles',
        'collaborations',
        'timeline',
        'gallery',
        'blog',
        'pricing',
        'code_showcase',
        'custom'
      ))
    """)
  end

  def down do
    # Remove the constraint
    execute("ALTER TABLE portfolio_sections DROP CONSTRAINT IF EXISTS portfolio_sections_section_type_check")

    # You might want to add back the original constraint here
    # Check what the original constraint was and add it back if needed
  end
end
