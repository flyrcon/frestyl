# Migration 2: Enhanced Media System for Template Types
# priv/repo/migrations/20250627_002_enhance_media_system.exs

defmodule Frestyl.Repo.Migrations.EnhanceMediaSystem do
  use Ecto.Migration

  def change do
    alter table(:portfolio_media) do
      # Media type categorization for template-specific handling
      add :media_category, :string, comment: "Category: audio, image, video, document, social_embed"

      # Audio-specific metadata
      add :audio_metadata, :map, default: %{}, comment: "Duration, waveform data, genre, collaborators"

      # Image-specific metadata for galleries
      add :image_metadata, :map, default: %{}, comment: "EXIF data, dimensions, camera settings"

      # Social media embed data
      add :social_embed_data, :map, default: %{}, comment: "Platform-specific embed configuration"

      # Template display settings
      add :display_settings, :map, default: %{}, comment: "How media appears in specific templates"

      # Media processing status
      add :processing_status, :string, default: "pending", comment: "pending, processing, completed, failed"

      # Accessibility and SEO
      add :alt_text, :text, comment: "Alt text for images and media accessibility"
      add :caption, :text, comment: "User-provided caption or description"

      # Template-specific positioning
      add :display_order, :integer, default: 0, comment: "Order within template sections"
      add :featured, :boolean, default: false, comment: "Featured media for template hero sections"
    end

    # Indexes for media queries
    create index(:portfolio_media, [:portfolio_id, :media_category])
    create index(:portfolio_media, [:portfolio_id, :display_order])
    create index(:portfolio_media, [:portfolio_id, :featured])
    create index(:portfolio_media, [:processing_status])
  end
end
