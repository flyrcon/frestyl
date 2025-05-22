defmodule Frestyl.Repo.Migrations.CreatePortfolioSections do
  use Ecto.Migration

  def change do
    create table(:portfolio_sections) do
      add :title, :string, null: false
      add :position, :integer, default: 0
      add :section_type, :string, null: false
      add :content, :map, default: %{}
      add :visible, :boolean, default: true

      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:portfolio_sections, [:portfolio_id])
    create index(:portfolio_sections, [:portfolio_id, :position])
  end
end
