defmodule Frestyl.Repo.Migrations.AddWorkspaceStateToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add_if_not_exists :workspace_state, :map, default: %{}
    end
  end
end
