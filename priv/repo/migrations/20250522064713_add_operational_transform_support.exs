# priv/repo/migrations/20240101000000_add_operational_transform_support.exs
defmodule Frestyl.Repo.Migrations.AddOperationalTransformSupport do
  use Ecto.Migration

  def change do
    # Add version tracking to sessions for OT
    alter table(:sessions) do
      add :workspace_version, :integer, default: 0
      add :last_operation_id, :uuid
      add :operation_log, :map, default: %{}
    end

    # Create operations table for OT history and debugging
    create table(:session_operations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :operation_type, :string, null: false  # "text", "audio", "visual", "midi"
      add :action, :string, null: false  # "insert", "delete", "add_track", etc.
      add :data, :map, null: false  # Operation-specific data
      add :version, :integer, null: false  # Version when operation was created
      add :transformed_by, {:array, :uuid}, default: []  # Operations this was transformed by
      add :acknowledged, :boolean, default: false
      add :conflict_resolution, :map  # How conflicts were resolved

      timestamps()
    end

    create index(:session_operations, [:session_id])
    create index(:session_operations, [:user_id])
    create index(:session_operations, [:session_id, :version])
    create index(:session_operations, [:acknowledged])

    # Add OT-specific fields to session_participants
    alter table(:session_participants) do
      add :last_operation_version, :integer, default: 0
      add :pending_operations_count, :integer, default: 0
      add :ot_client_id, :string  # For tracking client state
    end

    # Create table for tracking operation acknowledgments
    create table(:operation_acknowledgments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :operation_id, references(:session_operations, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :acknowledged_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:operation_acknowledgments, [:operation_id, :user_id])

    # Add indexes for performance
    create index(:sessions, [:workspace_version])
    create index(:session_participants, [:last_operation_version])
  end

  def down do
    drop table(:operation_acknowledgments)
    drop table(:session_operations)

    alter table(:session_participants) do
      remove :last_operation_version
      remove :pending_operations_count
      remove :ot_client_id
    end

    alter table(:sessions) do
      remove :workspace_version
      remove :last_operation_id
      remove :operation_log
    end
  end
end
