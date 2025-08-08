# priv/repo/migrations/20250108000004_create_voice_sketch_strokes.exs
defmodule Frestyl.Repo.Migrations.CreateVoiceSketchStrokes do
  use Ecto.Migration

  def change do
    create table(:voice_sketch_strokes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:voice_sketch_sessions, type: :binary_id), null: false
      add :user_id, references(:users, type: :id), null: false

      # Stroke data
      add :stroke_data, :map, null: false  # points, pressure, etc.
      add :tool_type, :string, null: false  # pen, brush, eraser, etc.
      add :color, :string, null: false
      add :stroke_width, :float, null: false
      add :layer_id, :string, null: false

      # Timing
      add :start_timestamp, :integer, null: false  # ms from session start
      add :end_timestamp, :integer, null: false
      add :audio_timestamp, :integer  # corresponding audio position

      # Metadata
      add :stroke_order, :integer, null: false
      add :is_deleted, :boolean, default: false

      timestamps()
    end

    create index(:voice_sketch_strokes, [:session_id, :stroke_order])
    create index(:voice_sketch_strokes, [:session_id, :start_timestamp])
    create index(:voice_sketch_strokes, [:user_id])
  end
end
