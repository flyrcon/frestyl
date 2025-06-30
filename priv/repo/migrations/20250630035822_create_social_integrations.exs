# Migration 2: Create social_integrations table (FIXED)
# File: priv/repo/migrations/20241201000002_create_social_integrations.exs

defmodule Frestyl.Repo.Migrations.CreateSocialIntegrations do
  use Ecto.Migration

  def change do

    alter table(:social_integrations) do
      remove :portfolio_id
    end

    alter table(:social_integrations) do
      add_if_not_exists :platform, :string, null: false
      add :platform_user_id, :string
      add_if_not_exists :username, :string, null: false
      add_if_not_exists :display_name, :string
      add_if_not_exists :profile_url, :string, null: false
      add :avatar_url, :string
      add :follower_count, :integer, default: 0
      add :bio, :text
      add :verified, :boolean, default: false

      # OAuth tokens (will be encrypted in application)
      add :access_token, :text
      add :refresh_token, :text
      add :token_expires_at, :utc_datetime

      # Sync settings
      add :auto_sync_enabled, :boolean, default: true
      add_if_not_exists :last_sync_at, :utc_datetime
      add :sync_frequency, :string, default: "daily"
      add :sync_status, :string, default: "active"
      add :last_error, :text

      # Content settings
      add :show_recent_posts, :boolean, default: true
      add :max_posts, :integer, default: 3
      add :show_follower_count, :boolean, default: true
      add :show_bio, :boolean, default: true

      # Privacy settings
      add :public_visibility, :boolean, default: true

      # Foreign keys
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false


    end

    create index(:social_integrations, [:user_id])
    create index(:social_integrations, [:sync_status])
    create index(:social_integrations, [:last_sync_at])

    # Add check constraints for platform and sync values
    create constraint(:social_integrations, :valid_platform,
      check: "platform IN ('linkedin', 'twitter', 'instagram', 'github', 'tiktok')")
    create constraint(:social_integrations, :valid_sync_frequency,
      check: "sync_frequency IN ('hourly', 'daily', 'weekly', 'manual')")
    create constraint(:social_integrations, :valid_sync_status,
      check: "sync_status IN ('active', 'error', 'disabled')")
    create constraint(:social_integrations, :valid_max_posts,
      check: "max_posts > 0 AND max_posts <= 10")
  end
end
