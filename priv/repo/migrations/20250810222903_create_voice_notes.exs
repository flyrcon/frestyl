# priv/repo/migrations/20250810000002_create_voice_notes.exs
defmodule Frestyl.Repo.Migrations.CreateVoiceNotes do
  use Ecto.Migration

  def change do
    create table(:voice_notes, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :story_id, references(:enhanced_story_structures, type: :uuid, on_delete: :delete_all), null: false
      add :section_id, :uuid  # References story sections (stored in JSON)
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :audio_file_path, :string, size: 500
      add :transcription, :text
      add :duration_seconds, :integer
      add :processing_status, :string, default: "pending"  # pending, processing, completed, error
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    # Indexes for efficient queries
    create index(:voice_notes, [:story_id])
    create index(:voice_notes, [:section_id])
    create index(:voice_notes, [:user_id])
    create index(:voice_notes, [:processing_status])
    create index(:voice_notes, [:inserted_at])

    # Composite index for story-section queries
    create index(:voice_notes, [:story_id, :section_id])
  end
end
