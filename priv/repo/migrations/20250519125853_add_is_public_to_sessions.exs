defmodule Frestyl.Repo.Migrations.AddIsPublicToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :is_public, :boolean, default: true
    end
  end
end
