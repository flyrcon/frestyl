# priv/repo/migrations/20250815000010_update_media_files_for_editing.exs
defmodule Frestyl.Repo.Migrations.UpdateMediaFilesForEditing do
  use Ecto.Migration

  def change do
    # Enhance media files for content editing
    alter table(:media_files) do
      add :editing_metadata, :map, default: %{}
      add_if_not_exists :waveform_data, :text # JSON string of waveform points
      add :thumbnail_urls, {:array, :string}, default: [] # Multiple thumbnails for video
      add_if_not_exists :processing_status, :string, default: "pending" # pending, processing, complete, failed
      add :analysis_data, :map, default: %{} # AI analysis results
      add :duration_ms, :integer # Duration in milliseconds for precise editing
      add :frame_rate, :float # For video files
      add :sample_rate, :integer # For audio files
      add :bit_depth, :integer # For audio files
      add :resolution, :string # For video/image files
      add :codec, :string
      add :optimization_variants, :map, default: %{} # Different quality versions
    end

    create_if_not_exists index(:media_files, [:processing_status])
    create index(:media_files, [:duration_ms])
  end
end
