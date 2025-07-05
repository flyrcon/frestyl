defmodule Frestyl.Repo.Migrations.AddCustomFieldsSupport do
  use Ecto.Migration

  def up do
    # Add custom field definitions table
    create table(:custom_field_definitions) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :field_name, :string, null: false
      add :field_type, :string, null: false # text, rich_text, number, date, url, list, object
      add :field_label, :string, null: false
      add :field_description, :text
      add :validation_rules, :map # JSON with validation criteria
      add :display_options, :map # JSON with display preferences
      add :position, :integer, default: 0
      add :is_required, :boolean, default: false
      add :is_public, :boolean, default: true

      timestamps()
    end

    create index(:custom_field_definitions, [:portfolio_id])
    create unique_index(:custom_field_definitions, [:portfolio_id, :field_name])

    # Add custom field values table
    create table(:custom_field_values) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :section_id, references(:portfolio_sections, on_delete: :delete_all), null: true
      add :field_definition_id, references(:custom_field_definitions, on_delete: :delete_all), null: false
      add :field_name, :string, null: false # Denormalized for performance
      add :value, :map # JSON storage for any value type
      add :value_text, :text # Searchable text representation

      timestamps()
    end

    create index(:custom_field_values, [:portfolio_id])
    create index(:custom_field_values, [:section_id])
    create index(:custom_field_values, [:field_definition_id])
    create index(:custom_field_values, [:field_name])

    # Enhance portfolio_sections to support custom field metadata
    alter table(:portfolio_sections) do
      add :custom_fields_enabled, :boolean, default: false
      add :custom_field_template, :string # Template name for common field sets
    end
  end

  def down do
    alter table(:portfolio_sections) do
      remove :custom_fields_enabled
      remove :custom_field_template
    end

    drop table(:custom_field_values)
    drop table(:custom_field_definitions)
  end
end
