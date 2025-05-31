defmodule Frestyl.Repo.Migrations.AddUserIdToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add :user_id, references(:users, on_delete: :delete_all)
    end

    create index(:channels, [:user_id])
  end
end
