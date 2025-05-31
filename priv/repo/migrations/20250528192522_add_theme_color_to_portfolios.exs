defmodule Frestyl.Repo.Migrations.AddThemeColorToPortfolios do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add :theme_color, :string, default: "#8b5cf6"
    end
  end
end
