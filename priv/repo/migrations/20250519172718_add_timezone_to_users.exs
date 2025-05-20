# Create a migration for user timezone preferences
# priv/repo/migrations/[timestamp]_add_timezone_to_users.exs

defmodule Frestyl.Repo.Migrations.AddTimezoneToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :timezone, :string, default: "UTC"
    end
  end
end
