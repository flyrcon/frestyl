defmodule Frestyl.Repo.Migrations.AddVideoAspectRatioToPortfolios do
  use Ecto.Migration

  def up do
    # Add video aspect ratio fields to portfolio customizations
    # These will be stored as JSON fields in the existing customization column
    # No schema changes needed since customization is already a flexible JSON field

    # However, if you want dedicated columns for better indexing/querying:
    # alter table(:portfolios) do
    #   add :video_aspect_ratio, :string, default: "16:9"
    #   add :video_display_mode, :string, default: "original"
    # end

    # For now, we'll use the existing customization JSON field approach
    # This maintains backward compatibility and existing functionality

    # Optionally, add indexes if using dedicated columns:
    # create index(:portfolios, [:video_aspect_ratio])
    # create index(:portfolios, [:video_display_mode])

    # Update existing portfolios to have default values in customization
    execute """
    UPDATE portfolios
    SET customization = COALESCE(customization, '{}'::jsonb) ||
        '{"video_aspect_ratio": "16:9", "video_display_mode": "original"}'::jsonb
    WHERE customization IS NULL
       OR NOT (customization ? 'video_aspect_ratio')
    """
  end

  def down do
    # Remove the default aspect ratio fields from existing customizations
    execute """
    UPDATE portfolios
    SET customization = customization - 'video_aspect_ratio' - 'video_display_mode'
    WHERE customization IS NOT NULL
    """

    # If using dedicated columns, uncomment:
    # alter table(:portfolios) do
    #   remove :video_aspect_ratio
    #   remove :video_display_mode
    # end
  end
end
