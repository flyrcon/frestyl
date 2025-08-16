# priv/repo/migrations/20250815000006_create_session_operations.exs
defmodule Frestyl.Repo.Migrations.CreateSessionOperations do
  use Ecto.Migration

  def change do
    # Session operations for operational transform
    create table(:session_operations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :operation_type, :string, null: false # text, audio, visual, timeline, effect
      add :action, :string, null: false # insert, delete, update, move, apply, etc.
      add :data, :map, null: false
      add :version, :integer, null: false
      add :timestamp, :utc_datetime, null: false
      add :acknowledged_by, {:array, :binary_id}, default: []
      add :transformed, :boolean, default: false
      add :priority, :integer, default: 0

      timestamps()
    end

    create index(:session_operations, [:session_id])
    create index(:session_operations, [:user_id])
    create index(:session_operations, [:operation_type])
    create index(:session_operations, [:version])
    create index(:session_operations, [:timestamp])
    create unique_index(:session_operations, [:session_id, :version])
  end
end
