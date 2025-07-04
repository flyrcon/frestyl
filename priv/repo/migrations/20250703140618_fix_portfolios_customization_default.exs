# Generate this migration with:
# mix ecto.gen.migration fix_portfolios_customization_default

defmodule Frestyl.Repo.Migrations.FixPortfoliosCustomizationDefault do
  use Ecto.Migration

  def up do
    # Remove the complex default and set a simple empty map
    alter table(:portfolios) do
      modify :customization, :map, default: %{}
    end

    # Optional: Update existing records that have the old default
    # to prevent JSONB parsing issues
    execute """
    UPDATE portfolios
    SET customization = '{}'::jsonb
    WHERE customization = '{
      "color_scheme": "purple-pink",
      "layout_style": "single_page",
      "section_spacing": "normal",
      "font_style": "inter",
      "fixed_navigation": true,
      "dark_mode_support": false
    }'::jsonb
    """
  end

  def down do
    # Restore the original complex default if needed
    alter table(:portfolios) do
      modify :customization, :map, default: %{
        "color_scheme" => "purple-pink",
        "layout_style" => "single_page",
        "section_spacing" => "normal",
        "font_style" => "inter",
        "fixed_navigation" => true,
        "dark_mode_support" => false
      }
    end
  end
end
