defmodule Frestyl.Repo.Migrations.AddAccountSupportToPortfolios do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add :account_type, :string, default: "personal"
      add :sharing_permissions, :map, default: %{}
      add :cross_account_sharing, :boolean, default: false
    end

    create index(:portfolios, [:account_type])
    create index(:portfolios, [:cross_account_sharing])
  end
end
