defmodule Frestyl.Repo.Migrations.UpdateSectionTypesForStoryFeatures do
  use Ecto.Migration

  def up do
    # Drop the existing constraint if it exists
    execute """
    ALTER TABLE portfolio_sections
    DROP CONSTRAINT IF EXISTS portfolio_sections_section_type_check
    """

    # Add the new constraint with story section types
    execute """
    ALTER TABLE portfolio_sections
    ADD CONSTRAINT portfolio_sections_section_type_check
    CHECK (section_type IN (
      'intro', 'experience', 'education', 'skills', 'projects',
      'featured_project', 'case_study', 'achievements', 'testimonial',
      'media_showcase', 'code_showcase', 'contact', 'custom',
      'story', 'timeline', 'narrative', 'journey'
    ))
    """
  end

  def down do
    # Revert to the original constraint without story types
    execute """
    ALTER TABLE portfolio_sections
    DROP CONSTRAINT IF EXISTS portfolio_sections_section_type_check
    """

    execute """
    ALTER TABLE portfolio_sections
    ADD CONSTRAINT portfolio_sections_section_type_check
    CHECK (section_type IN (
      'intro', 'experience', 'education', 'skills', 'projects',
      'featured_project', 'case_study', 'achievements', 'testimonial',
      'media_showcase', 'code_showcase', 'contact', 'custom'
    ))
    """
  end
end
