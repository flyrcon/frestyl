defmodule Frestyl.Repo.Migrations.AddVideoBlockSupport do
  use Ecto.Migration

  def change do
    # Add video-specific fields to portfolio_media table
    alter table(:portfolio_media) do
      add :video_thumbnail_url, :string
      add :video_duration, :integer  # in seconds
      add :video_format, :string     # mp4, webm, etc.
      add :is_external_video, :boolean, default: false
      add :external_video_platform, :string  # youtube, vimeo
      add :external_video_id, :string
      add :video_metadata, :map, default: %{}
    end

    # Create index for video lookups
    create index(:portfolio_media, [:section_id, :is_external_video])
    create index(:portfolio_media, [:external_video_platform, :external_video_id])
  end

  def down do
    alter table(:portfolio_media) do
      remove :video_thumbnail_url
      remove :video_duration
      remove :video_format
      remove :is_external_video
      remove :external_video_platform
      remove :external_video_id
      remove :video_metadata
    end

    drop index(:portfolio_media, [:section_id, :is_external_video])
    drop index(:portfolio_media, [:external_video_platform, :external_video_id])
  end
end
