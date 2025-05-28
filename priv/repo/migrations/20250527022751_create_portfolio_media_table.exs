defmodule Frestyl.Repo.Migrations.CreatePortfolioMediaTable do
  use Ecto.Migration

  def change do
    alter table(:portfolio_media) do
      add_if_not_exists :title, :string
      add_if_not_exists :description, :text
      add_if_not_exists :media_type, :string, null: false
      add_if_not_exists :file_path, :string
      add_if_not_exists :file_size, :integer
      add_if_not_exists :mime_type, :string
      add_if_not_exists :visible, :boolean, default: true
      add_if_not_exists :position, :integer, default: 0

    end

    create_if_not_exists index(:portfolio_media, [:portfolio_id])
    create_if_not_exists index(:portfolio_media, [:section_id])
    create_if_not_exists index(:portfolio_media, [:position])
    create_if_not_exists index(:portfolio_media, [:media_file_id])
  end
end
