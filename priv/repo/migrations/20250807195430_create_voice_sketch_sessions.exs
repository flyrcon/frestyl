# priv/repo/migrations/20250108000003_create_voice_sketch_sessions.exs
defmodule Frestyl.Repo.Migrations.CreateVoiceSketchSessions do
  use Ecto.Migration

  def change do
    create table(:voice_sketch_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :story_id, references(:enhanced_story_structures, type: :binary_id)
      add :creator_id, references(:users, type: :id), null: false

      # Audio data
      add :voice_recording_url, :string
      add :voice_recording_duration, :integer  # milliseconds
      add :audio_segments, :map, default: %{}  # timestamped segments

      # Drawing data
      add :canvas_data, :map, default: %{}  # drawing strokes with timestamps
      add :canvas_dimensions, :map, default: %{width: 800, height: 600}
      add :drawing_layers, :map, default: %{}  # multiple drawing layers

      # Synchronization
      add :sync_markers, :map, default: %{}  # audio-visual sync points
      add :timeline_data, :map, default: %{}  # complete timeline

      # Export settings
      add :export_settings, :map, default: %{
        video_quality: "HD",
        frame_rate: 24,
        audio_quality: "high"
      }

      # Collaboration
      add :collaboration_enabled, :boolean, default: false
      add :collaborators, {:array, :id}, default: []
      add :real_time_enabled, :boolean, default: true

      # Status and processing
      add :status, :string, default: "draft"  # draft, recording, processing, complete
      add :processing_progress, :integer, default: 0
      add :export_url, :string
      add :thumbnail_url, :string

      timestamps()
    end

    create index(:voice_sketch_sessions, [:creator_id])
    create index(:voice_sketch_sessions, [:story_id])
    create index(:voice_sketch_sessions, [:status])
    create index(:voice_sketch_sessions, [:inserted_at])
  end
end
