# Create with: mix ecto.gen.migration add_media_fields_to_channels
defmodule Frestyl.Repo.Migrations.AddMediaFieldsToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      # Media category fields
      add :branding_media_enabled, :boolean, default: true
      add :presentation_media_enabled, :boolean, default: true
      add :performance_media_enabled, :boolean, default: true

      # WebRTC configuration
      add :webrtc_config, :map

      # Storage configuration
      add :storage_bucket, :string
      add :storage_prefix, :string

      # Active media references
      add :active_branding_media_id, :id
      add :active_presentation_media_id, :id
      add :active_performance_media_id, :id
    end

    # Create indexes for active media references
    create index(:channels, [:active_branding_media_id])
    create index(:channels, [:active_presentation_media_id])
    create index(:channels, [:active_performance_media_id])
  end
end
