
# priv/repo/migrations/20250530000007_create_music_metadata.exs
defmodule Frestyl.Repo.Migrations.CreateMusicMetadata do
  use Ecto.Migration

  def change do
    create table(:music_metadata) do
      add :media_file_id, references(:media_files, on_delete: :delete_all), null: false
      add :bpm, :float
      add :key_signature, :string # C, Dm, F#, etc.
      add :time_signature, :string # 4/4, 3/4, 7/8, etc.
      add :genre, :string
      add :mood, :string
      add :energy_level, :float # 0.0 to 1.0
      add :instrument_tags, {:array, :string}, default: []
      add :stems, {:array, :map}, default: [] # Array of stem file references
      add :collaborators, {:array, :integer}, default: [] # User IDs
      add :creation_session_id, references(:sessions, on_delete: :nilify_all)
      add :lyrics, :text
      add :chord_progression, :text
      add :production_notes, :text
      add :version_number, :string
      add :parent_track_id, references(:media_files, on_delete: :nilify_all) # For remixes/versions
      add :is_loop, :boolean, default: false
      add :loop_bars, :integer
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:music_metadata, [:media_file_id])
    create index(:music_metadata, [:creation_session_id])
    create index(:music_metadata, [:parent_track_id])
    create index(:music_metadata, [:bpm])
    create index(:music_metadata, [:key_signature])
    create index(:music_metadata, [:genre])
  end
end
