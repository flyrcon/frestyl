# priv/repo/migrations/xxx_add_channel_customization_fields.exs
defmodule Frestyl.Repo.Migrations.AddChannelCustomizationFields do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      # Channel customization fields
      add :hero_image_url, :string
      add :color_scheme, :map, default: %{
        "primary" => "#8B5CF6",
        "secondary" => "#00D4FF",
        "accent" => "#FF0080"
      }
      add :tagline, :string
      add :featured_content, {:array, :map}, default: []
      add :channel_type, :string, default: "general"

      # Channel behavior settings
      add :auto_detect_type, :boolean, default: true
      add :show_live_activity, :boolean, default: true
      add :enable_transparency_mode, :boolean, default: false
      add :custom_css, :text  # Use :text in migrations for longer content

      # Social and engagement features
      add :social_links, :map, default: %{}
      add :fundraising_enabled, :boolean, default: false
      add :fundraising_goal, :decimal, precision: 12, scale: 2
      add :fundraising_description, :text  # Use :text in migrations
    end

    # Add indexes for performance
    create index(:channels, [:channel_type])
    create index(:channels, [:show_live_activity])
    create index(:channels, [:fundraising_enabled])
  end
end
