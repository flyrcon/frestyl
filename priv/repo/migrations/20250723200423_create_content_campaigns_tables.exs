defmodule Frestyl.Repo.Migrations.CreateContentCampaignsTables do
  use Ecto.Migration

  def change do
    create table(:content_campaigns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :content_type, :string, null: false
      add :status, :string, default: "draft"
      add :max_contributors, :integer, default: 5
      add :deadline, :utc_datetime
      add :revenue_target, :decimal, precision: 10, scale: 2
      add :minimum_contribution_threshold, :map
      add :contract_terms, :map
      add :platform_integrations, :map
      add :current_metrics, :map
      add :revenue_splits, :map
      # FIX: Use :bigint to match the users table primary key type
      add :creator_id, references(:users, on_delete: :delete_all, type: :bigint)

      timestamps()
    end

    create index(:content_campaigns, [:creator_id])
    create index(:content_campaigns, [:status])
    create index(:content_campaigns, [:content_type])

    create_if_not_exists table(:campaign_contributors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id)
      # FIX: Use :bigint to match the users table primary key type
      add :user_id, references(:users, on_delete: :delete_all, type: :bigint)
      add :role, :string, default: "contributor"
      add :revenue_percentage, :decimal, precision: 5, scale: 2, default: 0.0
      add :contribution_data, :map
      add :joined_at, :utc_datetime
      add :last_active_at, :utc_datetime

      timestamps()
    end

    create index(:campaign_contributors, [:campaign_id])
    create index(:campaign_contributors, [:user_id])
    create_if_not_exists unique_index(:campaign_contributors, [:campaign_id, :user_id])

    create table(:campaign_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :bigint)
      # FIX: Use :bigint to match the users table primary key type
      add :user_id, references(:users, on_delete: :delete_all, type: :bigint)
      add :metric_type, :string  # word_count, media_upload, peer_review, etc.
      add :metric_value, :decimal, precision: 10, scale: 2
      add :metadata, :map
      add :recorded_at, :utc_datetime

      timestamps()
    end

    create index(:campaign_metrics, [:campaign_id])
    create index(:campaign_metrics, [:user_id])
    create index(:campaign_metrics, [:metric_type])
  end
end
