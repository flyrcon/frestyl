defmodule Frestyl.Repo.Migrations.AddIsGroupToConversations do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      modify :is_group, :boolean, default: false, null: false
    end
  end
end
