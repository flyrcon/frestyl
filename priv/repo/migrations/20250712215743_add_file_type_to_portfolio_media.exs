defmodule Frestyl.Repo.Migrations.AddFileTypeToPortfolioMedia do
  use Ecto.Migration

  def change do
    alter table(:portfolio_media) do
      add :file_type, :string
    end
  end
end
