defmodule Frestyl.Repo.Migrations.AddIntroVideoToPortfolios do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add :intro_video_id, references(:media_files, on_delete: :nilify_all), null: true
    end

    create index(:portfolios, [:intro_video_id])
  end
end
