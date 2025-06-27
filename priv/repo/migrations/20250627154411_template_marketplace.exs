# Migration 6: Template Customization Presets and Marketplace
# priv/repo/migrations/20250627_006_template_marketplace.exs

defmodule Frestyl.Repo.Migrations.TemplateMarketplace do
  use Ecto.Migration

  def change do
    # Template customization presets for quick setup
    create table(:template_presets) do
      add :template_theme, :string, null: false
      add :preset_name, :string, null: false
      add :preset_description, :text
      add :customization_config, :map, null: false, comment: "Complete customization settings"
      add :preview_image_url, :string
      add :created_by_user_id, references(:users, on_delete: :nilify_all)
      add :is_official, :boolean, default: false, comment: "Created by platform team"
      add :is_public, :boolean, default: false, comment: "Available to other users"
      add :usage_count, :integer, default: 0
      add :rating, :decimal, precision: 3, scale: 2, default: 0.0
      add :tags, {:array, :string}, default: []

      timestamps()
    end

    # Template showcase for inspiration (featured portfolios)
    create table(:template_showcase) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :template_theme, :string, null: false
      add :showcase_title, :string, null: false
      add :showcase_description, :text
      add :featured_by_admin, :boolean, default: false
      add :showcase_order, :integer, default: 0
      add :is_active, :boolean, default: true
      add :view_count, :integer, default: 0

      timestamps()
    end

    # Template feedback and feature requests
    create table(:template_feedback) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :template_theme, :string, null: false
      add :feedback_type, :string, null: false, comment: "bug_report, feature_request, improvement, praise"
      add :feedback_text, :text, null: false
      add :priority, :string, default: "medium", comment: "low, medium, high, critical"
      add :status, :string, default: "open", comment: "open, in_progress, resolved, closed"
      add :admin_response, :text
      add :resolved_at, :utc_datetime

      timestamps()
    end

    # Indexes
    create index(:template_presets, [:template_theme])
    create index(:template_presets, [:is_official, :is_public])
    create index(:template_presets, [:usage_count])
    create unique_index(:template_showcase, [:portfolio_id])
    create index(:template_showcase, [:template_theme, :is_active])
    create index(:template_feedback, [:template_theme, :status])
    create index(:template_feedback, [:user_id])
  end
end
