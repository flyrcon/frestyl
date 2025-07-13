defmodule Frestyl.Repo.Migrations.AddFilenameToPortfolioMedia do
  use Ecto.Migration

  def change do
    alter table(:portfolio_media) do
      add :filename, :string
    end
  end
end
