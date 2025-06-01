# priv/repo/migrations/<timestamp>_add_channel_customization_and_media_fields.exs
defmodule YourApp.Repo.Migrations.AddChannelCustomizationAndMediaFields do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add_if_not_exists :hero_image_url, :string
      add_if_not_exists :color_scheme, :map, default: %{"primary" => "#8B5CF6", "secondary" => "#00D4FF", "accent" => "#FF0080"}
      add_if_not_exists :tagline, :string
      add_if_not_exists :channel_type, :string, default: "general"
      add_if_not_exists :show_live_activity, :boolean, default: true
      add_if_not_exists :auto_detect_type, :boolean, default: false
      add_if_not_exists :social_links, :map, default: %{}
      add_if_not_exists :featured_content, {:array, :map}, default: [] # Or :jsonb if you prefer in postgres
      add_if_not_exists :active_branding_media_id, :integer
      add_if_not_exists :active_presentation_media_id, :integer
      add_if_not_exists :active_performance_media_id, :integer
      # You might also add foreign key constraints for active_media_ids if desired
      # foreign_key :active_branding_media_id, :media_items, on_delete: :nilify
      # foreign_key :active_presentation_media_id, :media_items, on_delete: :nilify
      # foreign_key :active_performance_media_id, :media_items, on_delete: :nilify
    end
  end
end
