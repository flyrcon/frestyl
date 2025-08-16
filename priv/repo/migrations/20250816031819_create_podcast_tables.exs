# priv/repo/migrations/20250815000001_create_podcast_tables.exs
defmodule Frestyl.Repo.Migrations.CreatePodcastTables do
  use Ecto.Migration

  def change do
    # Podcast Shows
    create table(:podcast_shows, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text, null: false
      add :slug, :string, null: false
      add :author_name, :string, null: false
      add :website_url, :string
      add :artwork_url, :string
      add :language, :string, default: "en"
      add :category, :string
      add :explicit, :boolean, default: false
      add :rss_feed_url, :string
      add :distribution_platforms, {:array, :string}, default: []
      add :status, :string, default: "draft"
      add :settings, :map, default: %{}

      add :creator_id, references(:users, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:podcast_shows, [:slug])
    create index(:podcast_shows, [:creator_id])
    create index(:podcast_shows, [:channel_id])
    create index(:podcast_shows, [:status])

    # Podcast Episodes
    create table(:podcast_episodes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text, null: false
      add :slug, :string, null: false
      add :episode_number, :integer, null: false
      add :season_number, :integer, default: 1
      add :duration, :integer # seconds
      add :file_size, :bigint
      add :audio_url, :string
      add :video_url, :string
      add :transcript, :text
      add :show_notes, :text
      add :chapters, :jsonb, default: "[]"
      add :tags, {:array, :string}, default: []
      add :explicit, :boolean, default: false
      add :status, :string, default: "draft"
      add :scheduled_for, :utc_datetime
      add :published_at, :utc_datetime
      add :recording_started_at, :utc_datetime
      add :recording_ended_at, :utc_datetime
      add :download_count, :integer, default: 0
      add :play_count, :integer, default: 0
      add :metadata, :map, default: %{}

      add :show_id, references(:podcast_shows, type: :binary_id, on_delete: :delete_all), null: false
      add :creator_id, references(:users, on_delete: :delete_all), null: false
      add :recording_session_id, references(:sessions, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:podcast_episodes, [:show_id, :episode_number])
    create unique_index(:podcast_episodes, [:slug])
    create index(:podcast_episodes, [:show_id])
    create index(:podcast_episodes, [:creator_id])
    create index(:podcast_episodes, [:status])
    create index(:podcast_episodes, [:published_at])

    # Podcast Guests
    create table(:podcast_guests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false
      add :bio, :text
      add :title, :string
      add :company, :string
      add :website_url, :string
      add :avatar_url, :string
      add :social_links, :map, default: %{}
      add :status, :string, default: "invited"
      add :role, :string, default: "guest"
      add :invitation_sent_at, :utc_datetime
      add :confirmed_at, :utc_datetime
      add :joined_at, :utc_datetime
      add :notes, :text
      add :technical_setup, :map, default: %{}

      add :episode_id, references(:podcast_episodes, type: :binary_id, on_delete: :delete_all), null: false
      add :invited_by, references(:users, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:podcast_guests, [:episode_id, :email])
    create index(:podcast_guests, [:episode_id])
    create index(:podcast_guests, [:user_id])
    create index(:podcast_guests, [:status])

    # Podcast Analytics
    create table(:podcast_analytics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :platform, :string
      add :country, :string
      add :device_type, :string
      add :user_agent, :text
      add :duration_listened, :integer
      add :completion_rate, :float
      add :timestamp, :utc_datetime, null: false
      add :metadata, :map, default: %{}

      add :show_id, references(:podcast_shows, type: :binary_id, on_delete: :delete_all)
      add :episode_id, references(:podcast_episodes, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:podcast_analytics, [:show_id])
    create index(:podcast_analytics, [:episode_id])
    create index(:podcast_analytics, [:event_type])
    create index(:podcast_analytics, [:timestamp])
    create index(:podcast_analytics, [:platform])
  end
end
