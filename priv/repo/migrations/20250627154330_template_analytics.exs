# Migration 3: Template Analytics and Engagement Tracking
# priv/repo/migrations/20250627_003_template_analytics.exs

defmodule Frestyl.Repo.Migrations.TemplateAnalytics do
  use Ecto.Migration

  def change do
    # Template-specific analytics table
    create table(:portfolio_template_analytics) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :template_theme, :string, null: false
      add :template_category, :string, null: false

      # Engagement metrics
      add :page_views, :integer, default: 0
      add :unique_visitors, :integer, default: 0
      add :avg_session_duration, :integer, default: 0, comment: "Average session duration in seconds"
      add :bounce_rate, :decimal, precision: 5, scale: 2, default: 0.0

      # Template-specific interactions
      add :audio_plays, :integer, default: 0, comment: "Audio template: track plays"
      add :gallery_views, :integer, default: 0, comment: "Gallery template: image views"
      add :booking_requests, :integer, default: 0, comment: "Service template: booking form submissions"
      add :social_clicks, :integer, default: 0, comment: "Social template: external link clicks"
      add :download_requests, :integer, default: 0, comment: "Document downloads"

      # Conversion tracking
      add :contact_form_submissions, :integer, default: 0
      add :newsletter_signups, :integer, default: 0
      add :service_inquiries, :integer, default: 0

      # Time-based tracking
      add :tracked_date, :date, null: false
      add :last_updated, :utc_datetime

      timestamps()
    end

    # Indexes for analytics queries
    create unique_index(:portfolio_template_analytics, [:portfolio_id, :tracked_date])
    create index(:portfolio_template_analytics, [:template_theme])
    create index(:portfolio_template_analytics, [:template_category])
    create index(:portfolio_template_analytics, [:tracked_date])
  end
end
