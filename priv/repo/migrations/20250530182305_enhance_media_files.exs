
# priv/repo/migrations/20250530000009_enhance_media_files.exs
defmodule Frestyl.Repo.Migrations.EnhanceMediaFiles do
  use Ecto.Migration

  def change do
    alter table(:media_files) do
      modify :thumbnail_status, :string, default: "pending" # pending, generating, generated, failed
      modify :thumbnails, :map, default: %{} # Multiple thumbnail sizes/types
      add :processing_status, :string, default: "completed" # uploaded, processing, completed, failed
      add :auto_generated_tags, {:array, :string}, default: []
      add :dominant_colors, {:array, :string}, default: [] # For images
      add :audio_peaks, {:array, :float}, default: [] # For audio waveforms
      add :video_keyframes, {:array, :string}, default: [] # Keyframe URLs for video
      add :ai_analysis, :map, default: %{} # AI-generated metadata
      add :accessibility_metadata, :map, default: %{} # Alt text, captions, etc.
      add :version_of, references(:media_files, on_delete: :nilify_all) # File versioning
      add :derived_from, references(:media_files, on_delete: :nilify_all) # Processed/edited versions
      add :quality_score, :float # 0.0 to 1.0, for sorting/filtering
      add :engagement_score, :float # Based on views, reactions, comments
      add :last_accessed_at, :utc_datetime
      add :view_count, :integer, default: 0
      add :download_count, :integer, default: 0
      add :share_count, :integer, default: 0
    end

    create index(:media_files, [:processing_status])
    create index(:media_files, [:version_of])
    create index(:media_files, [:derived_from])
    create index(:media_files, [:quality_score])
    create index(:media_files, [:engagement_score])
    create index(:media_files, [:last_accessed_at])
    create index(:media_files, [:view_count])
  end
end
