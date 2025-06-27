# Migration 7: Template Performance and SEO Optimization
# priv/repo/migrations/20250627_007_template_optimization.exs

defmodule Frestyl.Repo.Migrations.TemplateOptimization do
  use Ecto.Migration

  def change do
    # Template performance metrics
    create table(:template_performance_metrics) do
      add :template_theme, :string, null: false
      add :metric_type, :string, null: false, comment: "page_load_time, lighthouse_score, mobile_score"
      add :metric_value, :decimal, precision: 10, scale: 3, null: false
      add :measurement_date, :date, null: false
      add :sample_portfolio_id, references(:portfolios, on_delete: :delete_all)
      add :test_environment, :string, default: "production"

      timestamps()
    end

    # SEO optimization tracking per template
    create table(:template_seo_metrics) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :template_theme, :string, null: false
      add :search_engine_ranking, :map, default: %{}, comment: "Rankings for different keywords"
      add :meta_title, :string
      add :meta_description, :text
      add :structured_data, :map, default: %{}, comment: "JSON-LD structured data"
      add :social_meta_tags, :map, default: %{}, comment: "Open Graph, Twitter Card data"
      add :last_seo_audit, :utc_datetime
      add :seo_score, :integer, comment: "Overall SEO score 0-100"

      timestamps()
    end

    # Template A/B testing for optimization
    create table(:template_ab_tests) do
      add :test_name, :string, null: false
      add :template_theme, :string, null: false
      add :variant_a_config, :map, null: false
      add :variant_b_config, :map, null: false
      add :success_metric, :string, null: false, comment: "conversion_rate, bounce_rate, engagement_time"
      add :test_start_date, :utc_datetime, null: false
      add :test_end_date, :utc_datetime
      add :variant_a_performance, :decimal, precision: 10, scale: 4
      add :variant_b_performance, :decimal, precision: 10, scale: 4
      add :winner_variant, :string, comment: "a, b, inconclusive"
      add :statistical_significance, :decimal, precision: 5, scale: 2
      add :is_active, :boolean, default: true

      timestamps()
    end

    # Indexes for performance queries
    create index(:template_performance_metrics, [:template_theme, :metric_type])
    create index(:template_performance_metrics, [:measurement_date])
    create unique_index(:template_seo_metrics, [:portfolio_id])
    create index(:template_seo_metrics, [:template_theme])
    create index(:template_ab_tests, [:template_theme, :is_active])
  end
end
