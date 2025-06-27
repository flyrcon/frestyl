defmodule Frestyl.Repo.Migrations.AddTemplateFeatures do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      # Template-specific feature configurations
      add :template_features, :map, default: %{}, comment: "Template-specific feature toggles and settings"

      # Social media integration settings
      add :social_integrations, :map, default: %{}, comment: "Social media platform connections and settings"

      # Booking and scheduling settings for service providers
      add :booking_settings, :map, default: %{}, comment: "Service booking configuration and calendar integration"

      # Audio-specific settings
      add :audio_settings, :map, default: %{}, comment: "Audio player configuration and track metadata"

      # Gallery-specific settings
      add :gallery_settings, :map, default: %{}, comment: "Gallery layout, lightbox, and image display settings"

      # Dashboard and metrics settings
      add :dashboard_settings, :map, default: %{}, comment: "Dashboard layout and metrics display configuration"

      # Template category for easier querying
      add :template_category, :string, comment: "Primary template category: audio, gallery, dashboard, service, social"

      # SEO and metadata enhancements for templates
      add :seo_settings, :map, default: %{}, comment: "Template-specific SEO configuration"
    end

    # Add indexes for better query performance
    create index(:portfolios, [:template_category])
    create index(:portfolios, [:theme, :template_category])
  end
end
