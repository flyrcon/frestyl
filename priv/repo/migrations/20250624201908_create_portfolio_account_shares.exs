defmodule Frestyl.Repo.Migrations.CreatePortfolioAccountShares do
  use Ecto.Migration

  def change do
    create table(:portfolio_account_shares) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :account_id, references(:user_accounts, on_delete: :delete_all), null: false
      add :permission_level, :string, default: "view", null: false
      add :expires_at, :utc_datetime
      add :access_token, :string
      add :embed_settings, :map, default: %{}

      timestamps()
    end

    create index(:portfolio_account_shares, [:portfolio_id])
    create index(:portfolio_account_shares, [:account_id])
    create index(:portfolio_account_shares, [:permission_level])
    create index(:portfolio_account_shares, [:expires_at])
    create unique_index(:portfolio_account_shares, [:portfolio_id, :account_id])
    create unique_index(:portfolio_account_shares, [:access_token])
  end
end
