defmodule Frestyl.Repo.Migrations.CreatePortfolioShares do
  use Ecto.Migration

  def change do
    create table(:portfolio_shares) do
      add :token, :string, null: false
      add :name, :string
      add :email, :string
      add :message, :text
      add :expires_at, :utc_datetime
      add :access_count, :integer, default: 0
      add :last_accessed_at, :utc_datetime
      add :approval_status, :string, default: "pending"

      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:portfolio_shares, [:portfolio_id])
    create unique_index(:portfolio_shares, [:token])
  end
end
