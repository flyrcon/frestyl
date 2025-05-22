defmodule Frestyl.Repo.Migrations.CreatePortfolios do
  use Ecto.Migration

  def change do
    create table(:portfolios) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :visibility, :string, default: "link_only"
      add :expires_at, :utc_datetime
      add :approval_required, :boolean, default: false
      add :theme, :string, default: "default"
      add :custom_css, :text

      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:portfolios, [:user_id])
    create unique_index(:portfolios, [:slug, :user_id])
  end
end
