# Migration 4: Template-Specific Sections and Layouts
# priv/repo/migrations/20250627_004_template_sections.exs

defmodule Frestyl.Repo.Migrations.TemplateSections do
  use Ecto.Migration

  def change do
    alter table(:portfolio_sections) do
      # Template-specific section types
      add :section_template, :string, comment: "Template-specific section type"

      # Layout configuration for different templates
      add :layout_config, :map, default: %{}, comment: "Section layout configuration"

      # Template category this section belongs to
      add :template_category, :string, comment: "audio, gallery, dashboard, service, social"

      # Section-specific metadata
      add :section_metadata, :map, default: %{}, comment: "Template-specific section configuration"

      # Visibility rules for different templates
      add :visibility_rules, :map, default: %{}, comment: "When and how section appears"

      # Interactive elements configuration
      add :interactive_elements, :map, default: %{}, comment: "Buttons, forms, embeds configuration"
    end

    # Template section types lookup table
    create table(:template_section_types) do
      add :template_theme, :string, null: false
      add :section_type, :string, null: false
      add :display_name, :string, null: false
      add :description, :text
      add :default_config, :map, default: %{}
      add :required_subscription_tier, :string, default: "personal"
      add :is_premium_feature, :boolean, default: false

      timestamps()
    end

    # Indexes
    create index(:portfolio_sections, [:portfolio_id, :template_category])
    create index(:portfolio_sections, [:section_template])
    create unique_index(:template_section_types, [:template_theme, :section_type])
  end
end
