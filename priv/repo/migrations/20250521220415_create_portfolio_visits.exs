defmodule Frestyl.Repo.Migrations.CreatePortfolioVisits do
  use Ecto.Migration

  def change do
    create table(:portfolio_visits) do
      add :ip_address, :string
      add :user_agent, :string
      add :referrer, :string
      add :duration_seconds, :integer
      add :share_id, references(:portfolio_shares, on_delete: :nilify_all)
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:portfolio_visits, [:portfolio_id])
    create index(:portfolio_visits, [:share_id])
  end
end
