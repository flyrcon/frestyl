# priv/repo/migrations/20250815000008_create_workspace_states.exs
defmodule Frestyl.Repo.Migrations.CreateWorkspaceStates do
  use Ecto.Migration

  def change do
    # Workspace states for collaboration
    create table(:workspace_states, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :workspace_type, :string, null: false # content_editing, podcast_show, session_collaboration
      add :state_data, :map, default: %{}
      add :version, :integer, default: 1
      add :last_modified_by, references(:users, on_delete: :nilify_all)
      add :last_modified_at, :utc_datetime
      add :cursors, :map, default: %{} # real-time cursor positions
      add :selections, :map, default: %{} # real-time selections
      add :locks, :map, default: %{} # element locks for editing

      timestamps()
    end

    create index(:workspace_states, [:session_id])
    create index(:workspace_states, [:workspace_type])
    create index(:workspace_states, [:last_modified_at])
    create unique_index(:workspace_states, [:session_id, :workspace_type])
  end
end
