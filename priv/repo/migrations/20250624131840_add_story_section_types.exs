defmodule Frestyl.Repo.Migrations.AddStorySectionTypes do
   use Ecto.Migration

   def change do
     alter table(:portfolio_sections) do
       modify :section_type, :string, null: false
     end

     # Add check constraint to include new types
     execute """
     ALTER TABLE portfolio_sections
     DROP CONSTRAINT IF EXISTS portfolio_sections_section_type_check;
     """, ""

     execute """
     ALTER TABLE portfolio_sections
     ADD CONSTRAINT portfolio_sections_section_type_check
     CHECK (section_type IN (
       'intro', 'experience', 'education', 'skills', 'projects',
       'featured_project', 'case_study', 'achievements', 'testimonial',
       'media_showcase', 'code_showcase', 'contact', 'custom',
       'story', 'timeline', 'narrative', 'journey'
     ));
     """, ""
   end
 end
