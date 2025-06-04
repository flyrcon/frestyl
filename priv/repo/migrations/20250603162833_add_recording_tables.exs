# priv/repo/migrations/001_add_recording_tables.exs
defmodule Frestyl.Repo.Migrations.AddRecordingTables do
  use Ecto.Migration

  def change do
    # Recording sessions table
    create table(:recording_sessions) do
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :track_id, :string, null: false
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :duration_seconds, :integer
      add :audio_path, :string
      add :quality_settings, :map
      add :analysis_data, :map
      add :status, :string, default: "active"

      timestamps()
    end

    create index(:recording_sessions, [:session_id])
    create index(:recording_sessions, [:user_id])
    create index(:recording_sessions, [:track_id])
    create index(:recording_sessions, [:started_at])

    # Recording drafts table
    create table(:recording_drafts) do
      add :draft_id, :string, null: false
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text
      add :collaborators, {:array, :integer}, default: []
      add :tracks_data, :map
      add :mix_settings, :map
      add :protection_level, :string, default: "draft"
      add :creation_proof, :map
      add :expires_at, :utc_datetime, null: false
      add :status, :string, default: "active"

      timestamps()
    end

    create unique_index(:recording_drafts, [:draft_id])
    create index(:recording_drafts, [:session_id])
    create index(:recording_drafts, [:expires_at])

    # Export credits tracking table
    create table(:export_credits) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :month_year, :string, null: false # Format: "2024-01"
      add :credits_used, :integer, default: 0
      add :credits_limit, :integer, null: false
      add :tier, :string, null: false

      timestamps()
    end

    create unique_index(:export_credits, [:user_id, :month_year])
    create index(:export_credits, [:month_year])

    # Media export logs table
    create table(:media_export_logs) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :draft_id, :string
      add :media_file_id, references(:media_files, on_delete: :delete_all)
      add :export_settings, :map
      add :quality, :string
      add :file_size_bytes, :bigint
      add :processing_time_ms, :integer
      add :credits_cost, :integer, default: 1
      add :status, :string, default: "completed"

      timestamps()
    end

    create index(:media_export_logs, [:user_id])
    create index(:media_export_logs, [:draft_id])
    create index(:media_export_logs, [:inserted_at])

    # Creation proofs table (for copyright protection)
    create table(:creation_proofs) do
      add :proof_id, :string, null: false
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :proof_data, :map, null: false
      add :proof_hash, :string, null: false
      add :blockchain_anchor, :map
      add :collaborators, {:array, :integer}, default: []
      add :track_fingerprints, :map

      timestamps()
    end

    create unique_index(:creation_proofs, [:proof_id])
    create index(:creation_proofs, [:session_id])
    create index(:creation_proofs, [:proof_hash])

    # Add recording-related fields to existing sessions table
    alter table(:sessions) do
      add :recording_enabled, :boolean, default: false
      add :max_recording_duration, :integer # in minutes
      add :recording_settings, :map
    end

    # Add workspace state field if it doesn't exist
    # (This might already exist in your sessions table)
    alter table(:sessions) do
      add_if_not_exists :workspace_state, :map
    end
  end

  def down do
    alter table(:sessions) do
      remove :recording_enabled
      remove :max_recording_duration
      remove :recording_settings
    end

    drop table(:creation_proofs)
    drop table(:media_export_logs)
    drop table(:export_credits)
    drop table(:recording_drafts)
    drop table(:recording_sessions)
  end
end
