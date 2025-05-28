defmodule Frestyl.Repo.Migrations.AddCustomizationToPortfolios do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add :customization, :map, default: %{
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
