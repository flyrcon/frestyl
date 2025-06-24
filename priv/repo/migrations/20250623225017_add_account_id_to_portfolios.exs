# priv/repo/migrations/003_add_account_id_to_portfolios.exs
defmodule Frestyl.Repo.Migrations.AddAccountIdToPortfolios do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add :account_id, references(:accounts, on_delete: :nilify_all)
    end

    create index(:portfolios, [:account_id])
  end
end
