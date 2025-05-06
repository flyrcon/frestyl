defmodule Frestyl.Repo.Migrations.AddIsGroupToConversations do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :is_group, :boolean, default: false
    end
  end
end
