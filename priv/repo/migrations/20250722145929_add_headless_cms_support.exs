# lib/frestyl/repo/migrations/xxx_add_headless_cms_support.ex
defmodule Frestyl.Repo.Migrations.AddHeadlessCMSSupport do
  use Ecto.Migration

  def change do
    # Create collaboration campaigns table FIRST
    create table(:collaboration_campaigns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :account_id, references(:accounts, type: :id), null: false  # accounts uses bigint
      add :campaign_type, :string, default: "content_writing"
      add :status, :string, default: "open"
      add :max_contributors, :integer, default: 5
      add :contribution_rules, :map, default: %{}
      add :revenue_split_config, :map, default: %{}
      add :target_platforms, {:array, :string}, default: []
      add :deadline, :utc_datetime
      add :campaign_metadata, :map, default: %{}

      timestamps()
    end

    # Platform API configurations
    create table(:syndication_platforms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :id), null: false  # accounts uses bigint
      add :platform_name, :string, null: false
      add :api_credentials, :map, default: %{} # Encrypted
      add :platform_config, :map, default: %{}
      add :is_active, :boolean, default: true
      add :last_sync, :utc_datetime
      add :sync_status, :string, default: "ready"

      timestamps()
    end

    # Campaign contributors
    create table(:campaign_contributors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:collaboration_campaigns, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :id), null: false  # users likely uses bigint
      add :account_id, references(:accounts, type: :id), null: false  # accounts uses bigint
      add :role, :string, default: "contributor" # lead_writer, contributor, reviewer
      add :agreed_revenue_share, :decimal, precision: 5, scale: 2
      add :contribution_metrics, :map, default: %{}
      add :joined_at, :utc_datetime, default: fragment("NOW()")
      add :status, :string, default: "active"

      timestamps()
    end

    # Content syndication tracking
    create table(:content_syndications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :document_id, references(:documents, type: :binary_id, on_delete: :delete_all), null: false  # documents uses UUID
      add :account_id, references(:accounts, type: :id), null: false  # accounts uses bigint
      add :platform, :string, null: false
      add :external_url, :string
      add :external_id, :string # Platform-specific ID
      add :syndication_status, :string, default: "pending"
      add :platform_metrics, :map, default: %{}
      add :revenue_attribution, :decimal, precision: 10, scale: 2, default: 0
      add :collaboration_revenue_splits, :map, default: %{}
      add :syndicated_at, :utc_datetime
      add :last_metrics_update, :utc_datetime
      add :syndication_config, :map, default: %{} # Platform-specific config

      timestamps()
    end

    # Real-time contribution tracking
    create table(:contribution_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :document_id, references(:documents, type: :binary_id, on_delete: :delete_all), null: false  # documents uses UUID
      add :user_id, references(:users, type: :id), null: false  # users likely uses bigint
      add :session_start, :utc_datetime, default: fragment("NOW()")
      add :session_end, :utc_datetime
      add :words_contributed, :integer, default: 0
      add :edits_count, :integer, default: 0
      add :sections_edited, {:array, :string}, default: []
      add :contribution_metadata, :map, default: %{}

      timestamps()
    end

    # NOW extend existing documents table (after creating referenced tables)
    alter table(:documents) do
      add :collaboration_campaign_id, references(:collaboration_campaigns, type: :binary_id, on_delete: :nilify_all)
      add :syndication_targets, {:array, :string}, default: []
      add :contribution_tracking, :map, default: %{}
      add :revenue_sharing_config, :map, default: %{}
      add :publication_metadata, :map, default: %{}
      add :seo_config, :map, default: %{}
      add :external_id, :string # For platform-specific IDs
      add :publish_status, :string, default: "draft"
      add :scheduled_publish_at, :utc_datetime
      add :content_hash, :string # For change detection
    end

    # Create indexes for performance
    create index(:documents, [:collaboration_campaign_id])
    create index(:documents, [:publish_status])
    create index(:documents, [:scheduled_publish_at])
    create index(:collaboration_campaigns, [:account_id])
    create index(:collaboration_campaigns, [:status])
    create index(:campaign_contributors, [:campaign_id, :user_id])
    create_if_not_exists index(:campaign_contributors, [:account_id])
    create index(:content_syndications, [:document_id])
    create index(:content_syndications, [:account_id])
    create index(:content_syndications, [:platform])
    create index(:content_syndications, [:syndication_status])
    create index(:contribution_sessions, [:document_id, :user_id])
    create index(:syndication_platforms, [:account_id, :platform_name])

    # Unique constraints
    create_if_not_exists unique_index(:campaign_contributors, [:campaign_id, :user_id])
    create unique_index(:content_syndications, [:document_id, :platform])
    create_if_not_exists unique_index(:syndication_platforms, [:account_id, :platform_name])
  end
end
