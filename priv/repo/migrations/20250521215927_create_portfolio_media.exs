defmodule Frestyl.Repo.Migrations.CreatePortfolioMedia do
  use Ecto.Migration

  def change do
    create table(:portfolio_media) do
      add :title, :string
      add :media_type, :string, null: false
      add :file_path, :string, null: false
      add :position, :integer, default: 0
      add :metadata, :map, default: %{}
      add :thumbnail_path, :string
      add :visible, :boolean, default: true

      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :section_id, references(:portfolio_sections, on_delete: :nilify_all)

      timestamps()
    end

    create index(:portfolio_media, [:portfolio_id])
    create index(:portfolio_media, [:section_id])
  end
end
