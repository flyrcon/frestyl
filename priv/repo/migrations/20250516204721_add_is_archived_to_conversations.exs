defmodule Frestyl.Repo.Migrations.AddIsArchivedToConversations do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :is_archived, :boolean, default: false
    end

    create index(:conversations, [:is_archived])
  end
end
