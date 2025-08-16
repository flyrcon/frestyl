# priv/repo/migrations/20250815000004_create_session_registry_table.exs
defmodule Frestyl.Repo.Migrations.CreateSessionRegistryTable do
  use Ecto.Migration

  def change do
    # Session Registry for managing active sessions
    create table(:session_registry, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :engine_type, :string, null: false # audio, recording, streaming, webrtc, collaboration
      add :engine_pid, :string
      add :status, :string, default: "starting" # starting, running, stopping, stopped, error
      add :started_at, :utc_datetime, null: false
      add :stopped_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:session_registry, [:session_id])
    create index(:session_registry, [:engine_type])
    create index(:session_registry, [:status])
    create unique_index(:session_registry, [:session_id, :engine_type])
  end
end
