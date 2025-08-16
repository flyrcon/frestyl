# priv/repo/migrations/20250815000002_create_content_editing_tables.exs
defmodule Frestyl.Repo.Migrations.CreateContentEditingTables do
  use Ecto.Migration

  def change do
    # Editing Projects (must be created first)
    create table(:editing_projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :project_type, :string, null: false
      add :status, :string, default: "draft"
      add :settings, :map, default: %{}
      add :metadata, :map, default: %{}
      add :duration, :integer, default: 0
      add :render_settings, :map, default: %{}
      add :collaboration_enabled, :boolean, default: true
      add :auto_save_enabled, :boolean, default: true
      add :version, :integer, default: 1

      add :creator_id, references(:users, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, on_delete: :delete_all)
      add :session_id, references(:sessions, on_delete: :nilify_all)

      timestamps()
    end

    create index(:editing_projects, [:creator_id])
    create index(:editing_projects, [:channel_id])
    create index(:editing_projects, [:project_type])
    create index(:editing_projects, [:status])

    # Editing Tracks
    create table(:editing_tracks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :track_type, :string, null: false
      add :order, :integer, null: false
      add :enabled, :boolean, default: true
      add :muted, :boolean, default: false
      add :solo, :boolean, default: false
      add :locked, :boolean, default: false
      add :volume, :float, default: 1.0
      add :pan, :float, default: 0.0
      add :color, :string
      add :settings, :map, default: %{}
      add :effects_chain, :jsonb, default: "[]"

      add :project_id, references(:editing_projects, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:editing_tracks, [:project_id, :order])
    create index(:editing_tracks, [:project_id])
    create index(:editing_tracks, [:track_type])

    # Editing Clips
    create table(:editing_clips, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :media_type, :string, null: false
      add :duration, :integer, null: false
      add :start_offset, :integer, default: 0
      add :end_offset, :integer, default: 0
      add :speed, :float, default: 1.0
      add :volume, :float, default: 1.0
      add :opacity, :float, default: 1.0
      add :position_x, :float, default: 0.0
      add :position_y, :float, default: 0.0
      add :scale_x, :float, default: 1.0
      add :scale_y, :float, default: 1.0
      add :rotation, :float, default: 0.0
      add :enabled, :boolean, default: true
      add :locked, :boolean, default: false
      add :metadata, :map, default: %{}
      add :thumbnail_url, :string

      add :project_id, references(:editing_projects, type: :binary_id, on_delete: :delete_all), null: false
      add :track_id, references(:editing_tracks, type: :binary_id, on_delete: :delete_all)
      add :media_file_id, references(:media_files, on_delete: :delete_all)
      add :creator_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:editing_clips, [:project_id])
    create index(:editing_clips, [:track_id])
    create index(:editing_clips, [:media_file_id])
    create index(:editing_clips, [:creator_id])

    # Timeline Entries
    create table(:editing_timeline, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :start_position, :integer, null: false
      add :end_position, :integer, null: false
      add :layer, :integer, default: 0
      add :transition_in, :map
      add :transition_out, :map
      add :metadata, :map, default: %{}

      add :project_id, references(:editing_projects, type: :binary_id, on_delete: :delete_all), null: false
      add :track_id, references(:editing_tracks, type: :binary_id, on_delete: :delete_all), null: false
      add :clip_id, references(:editing_clips, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:editing_timeline, [:project_id])
    create index(:editing_timeline, [:track_id])
    create index(:editing_timeline, [:clip_id])
    create index(:editing_timeline, [:start_position])

    # Effects
    create table(:editing_effects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :effect_type, :string, null: false
      add :target_type, :string, null: false
      add :target_id, :binary_id, null: false
      add :enabled, :boolean, default: true
      add :order, :integer, default: 0
      add :parameters, :map, default: %{}
      add :preset_name, :string
      add :processing_status, :string, default: "pending"
      add :processing_progress, :float, default: 0.0
      add :result_url, :string
      add :metadata, :map, default: %{}

      add :project_id, references(:editing_projects, type: :binary_id, on_delete: :delete_all), null: false
      add :creator_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:editing_effects, [:project_id])
    create index(:editing_effects, [:target_type, :target_id])
    create index(:editing_effects, [:effect_type])
    create index(:editing_effects, [:processing_status])

    # Render Jobs (references editing_projects, so must come after)
    create table(:editing_render_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, default: "queued"
      add :progress, :float, default: 0.0
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :failed_at, :utc_datetime
      add :error_message, :text
      add :render_settings, :map, default: %{}
      add :output_file_url, :string
      add :output_file_size, :bigint
      add :processing_time, :integer
      add :estimated_completion, :utc_datetime
      add :priority, :integer, default: 0
      add :metadata, :map, default: %{}

      add :project_id, references(:editing_projects, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:editing_render_jobs, [:project_id])
    create index(:editing_render_jobs, [:user_id])
    create index(:editing_render_jobs, [:status])
    create index(:editing_render_jobs, [:priority])

    # Collaborators (references editing_projects, so must come after)
    create table(:editing_collaborators, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, default: "editor"
      add :permissions, {:array, :string}, default: []
      add :invited_at, :utc_datetime
      add :joined_at, :utc_datetime
      add :last_active_at, :utc_datetime
      add :status, :string, default: "invited"
      add :contribution_score, :integer, default: 0
      add :metadata, :map, default: %{}

      add :project_id, references(:editing_projects, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :invited_by, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:editing_collaborators, [:project_id, :user_id])
    create index(:editing_collaborators, [:project_id])
    create index(:editing_collaborators, [:user_id])
    create index(:editing_collaborators, [:status])
  end
end
