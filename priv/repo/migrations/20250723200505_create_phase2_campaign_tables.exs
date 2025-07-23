defmodule Frestyl.Repo.Migrations.CreatePhase2CampaignTables do
  use Ecto.Migration

  def change do
    # Improvement Periods table
    create table(:improvement_periods, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id)
      add :user_id, references(:users, on_delete: :delete_all, type: :bigint)
      add :gate_name, :string, null: false
      add :current_score, :decimal, precision: 5, scale: 2
      add :target_score, :decimal, precision: 5, scale: 2
      add :reason, :text
      add :improvement_plan, :map
      add :status, :string, default: "active"
      add :started_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:improvement_periods, [:campaign_id])
    create index(:improvement_periods, [:user_id])
    create index(:improvement_periods, [:status])

    # Peer Review Requests table
    create table(:peer_review_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id)
      add :contributor_id, references(:users, on_delete: :delete_all, type: :bigint)
      add :submission_type, :string
      add :content_preview, :text
      add :review_criteria, :map
      add :reviewers_needed, :integer, default: 2
      add :status, :string, default: "pending"
      add :requested_at, :utc_datetime

      timestamps()
    end

    create index(:peer_review_requests, [:campaign_id])
    create index(:peer_review_requests, [:contributor_id])
    create index(:peer_review_requests, [:status])

    # Peer Reviews table
    create table(:peer_reviews, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :review_request_id, references(:peer_review_requests, on_delete: :delete_all, type: :binary_id)
      add :reviewer_id, references(:users, on_delete: :delete_all, type: :bigint)
      add :overall_score, :decimal, precision: 3, scale: 2
      add :criteria_scores, :map
      add :feedback, :text
      add :suggestions, :map
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:peer_reviews, [:review_request_id])
    create index(:peer_reviews, [:reviewer_id])

    # Quality Gates Status table
    create table(:quality_gates_status, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id)
      add :user_id, references(:users, on_delete: :delete_all, type: :bigint)
      add :gate_name, :string
      add :status, :string # passed, failed, pending, improvement
      add :current_value, :decimal, precision: 10, scale: 2
      add :threshold_value, :decimal, precision: 10, scale: 2
      add :last_checked_at, :utc_datetime

      timestamps()
    end

    create index(:quality_gates_status, [:campaign_id, :user_id])
    create index(:quality_gates_status, [:gate_name])
    create unique_index(:quality_gates_status, [:campaign_id, :user_id, :gate_name])

    # Campaign Sessions table (for audio integration)
    create table(:campaign_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id)
      add :session_id, :string, null: false
      add :session_type, :string # recording, collaboration, review
      add :metadata, :map
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime

      timestamps()
    end

    create index(:campaign_sessions, [:campaign_id])
    create index(:campaign_sessions, [:session_id])
    create_if_not_exists unique_index(:campaign_sessions, [:session_id])
  end
end
