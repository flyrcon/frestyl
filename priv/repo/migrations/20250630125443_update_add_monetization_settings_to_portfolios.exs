defmodule Frestyl.Repo.Migrations.UpdateAddMonetizationSettingsToPortfolios do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add :monetization_settings, :map, default: %{}
    end
  end
end
