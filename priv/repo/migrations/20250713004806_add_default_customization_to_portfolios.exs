defmodule Frestyl.Repo.Migrations.AddDefaultCustomizationToPortfolios do
  use Ecto.Migration

  def up do
    execute """
    UPDATE portfolios
    SET customization = '{
      "color_scheme": "purple-pink",
      "layout_style": "single_page",
      "section_spacing": "normal",
      "font_style": "inter",
      "fixed_navigation": true,
      "dark_mode_support": false
    }'::jsonb
    WHERE customization IS NULL
    """
  end
end
