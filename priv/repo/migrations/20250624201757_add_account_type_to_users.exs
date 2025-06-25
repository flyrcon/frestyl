defmodule Frestyl.Repo.Migrations.AddAccountTypeToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :primary_account_type, :string, default: "personal", null: false
    end

    create index(:users, [:primary_account_type])
  end
end
