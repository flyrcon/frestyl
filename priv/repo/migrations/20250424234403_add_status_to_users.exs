# priv/repo/migrations/20250424000005_add_status_to_users.exs

defmodule Frestyl.Repo.Migrations.AddStatusToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :status, :string, default: "offline"
    end

    create index(:users, [:status])
  end
end
