# File: priv/repo/migrations/YYYYMMDDHHMMSS_create_phase3_revenue_and_contracts.exs

defmodule Frestyl.Repo.Migrations.CreatePhase3RevenueAndContracts do
  use Ecto.Migration

  def up do
    # ========================================================================
    # CAMPAIGN CONTRACTS TABLE
    # ========================================================================
    create table(:campaign_contracts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id), null: false
      add :contributor_id, references(:users, on_delete: :delete_all, type: :bigint), null: false

      # Contract Details
      add :contract_type, :string, default: "revenue_sharing", null: false
      add :terms, :map, null: false
      add :revenue_split, :map, null: false
      add :quality_requirements, :map
      add :timeline, :map
      add :legal_terms, :text

      # Contract Status
      add :status, :string, default: "draft", null: false
      add :signed_at, :utc_datetime
      add :signature_hash, :string
      add :signature_metadata, :map

      # Financial Tracking
      add :total_payments_made, :decimal, precision: 10, scale: 2, default: 0.00
      add :last_payment_date, :utc_datetime
      add :payment_schedule, :map

      # Audit Fields
      add :created_by_ip, :string
      add :signed_by_ip, :string
      add :contract_version, :integer, default: 1

      timestamps()
    end

    create index(:campaign_contracts, [:campaign_id])
    create index(:campaign_contracts, [:contributor_id])
    create index(:campaign_contracts, [:status])
    create index(:campaign_contracts, [:contract_type])
    create unique_index(:campaign_contracts, [:campaign_id, :contributor_id],
      name: :unique_campaign_contributor_contract)

    # ========================================================================
    # REVENUE DISTRIBUTIONS TABLE
    # ========================================================================
    create table(:revenue_distributions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id), null: false

      # Revenue Amounts
      add :total_revenue, :decimal, precision: 12, scale: 2, null: false
      add :platform_fee, :decimal, precision: 12, scale: 2, null: false
      add :payment_processing_fee, :decimal, precision: 12, scale: 2, null: false
      add :net_revenue, :decimal, precision: 12, scale: 2, null: false

      # Distribution Data
      add :contributor_splits, :map, null: false
      add :payment_instructions, :map
      add :distribution_algorithm, :string, default: "dynamic_contribution"

      # Status & Tracking
      add :status, :string, default: "pending_payment", null: false
      add :calculated_at, :utc_datetime, null: false
      add :processed_at, :utc_datetime
      add :completion_rate, :decimal, precision: 5, scale: 2, default: 0.00

      # Payment Statistics
      add :successful_payments, :integer, default: 0
      add :failed_payments, :integer, default: 0
      add :total_payments_attempted, :integer, default: 0
      add :retry_count, :integer, default: 0

      # Audit & Compliance
      add :calculated_by_user_id, references(:users, type: :bigint)
      add :approved_by_user_id, references(:users, type: :bigint)
      add :approved_at, :utc_datetime

      timestamps()
    end

    create index(:revenue_distributions, [:campaign_id])
    create index(:revenue_distributions, [:status])
    create index(:revenue_distributions, [:calculated_at])
    create index(:revenue_distributions, [:processed_at])

    # ========================================================================
    # CAMPAIGN PAYMENTS TABLE
    # ========================================================================
    create table(:campaign_payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :distribution_id, references(:revenue_distributions, on_delete: :delete_all, type: :binary_id), null: false
      add :contract_id, references(:campaign_contracts, on_delete: :delete_all, type: :binary_id)
      add :recipient_id, references(:users, on_delete: :delete_all, type: :bigint), null: false

      # Payment Amounts
      add :gross_amount, :decimal, precision: 10, scale: 2, null: false
      add :platform_fee, :decimal, precision: 10, scale: 2, default: 0.00
      add :processing_fee, :decimal, precision: 10, scale: 2, default: 0.00
      add :net_amount, :decimal, precision: 10, scale: 2, null: false
      add :currency, :string, default: "USD", null: false

      # Payment Processing
      add :payment_processor, :string, null: false
      add :processor_payment_id, :string
      add :processor_transaction_id, :string
      add :payment_method_type, :string # card, ach, paypal, etc.

      # Status & Timing
      add :status, :string, default: "pending", null: false
      add :initiated_at, :utc_datetime
      add :processed_at, :utc_datetime
      add :failed_at, :utc_datetime
      add :completed_at, :utc_datetime

      # Error Handling
      add :failed_reason, :text
      add :error_code, :string
      add :retry_count, :integer, default: 0
      add :last_retry_at, :utc_datetime
      add :next_retry_at, :utc_datetime

      # Metadata & Audit
      add :payment_metadata, :map
      add :processor_metadata, :map
      add :initiated_by_user_id, references(:users, type: :bigint)

      timestamps()
    end

    create index(:campaign_payments, [:distribution_id])
    create index(:campaign_payments, [:contract_id])
    create index(:campaign_payments, [:recipient_id])
    create index(:campaign_payments, [:status])
    create index(:campaign_payments, [:payment_processor])
    create index(:campaign_payments, [:processor_payment_id])
    create index(:campaign_payments, [:processor_transaction_id])
    create index(:campaign_payments, [:processed_at])

    # ========================================================================
    # REVENUE MILESTONES TABLE
    # ========================================================================
    create table(:revenue_milestones, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id), null: false

      # Milestone Configuration
      add :milestone_type, :string, null: false # partial_payment, quality_bonus, completion_bonus, etc.
      add :milestone_name, :string
      add :milestone_description, :text

      # Trigger Conditions
      add :threshold_amount, :decimal, precision: 10, scale: 2
      add :threshold_percentage, :decimal, precision: 5, scale: 2
      add :trigger_condition, :string # revenue_reached, time_elapsed, quality_achieved, etc.
      add :criteria, :map

      # Status & Execution
      add :triggered, :boolean, default: false, null: false
      add :triggered_at, :utc_datetime
      add :triggered_amount, :decimal, precision: 10, scale: 2
      add :processed, :boolean, default: false, null: false
      add :processed_at, :utc_datetime
      add :processing_failed, :boolean, default: false
      add :failure_reason, :text

      # Milestone Results
      add :bonus_amount, :decimal, precision: 10, scale: 2
      add :affected_contributors, :map
      add :execution_results, :map

      timestamps()
    end

    create index(:revenue_milestones, [:campaign_id])
    create index(:revenue_milestones, [:milestone_type])
    create index(:revenue_milestones, [:triggered])
    create index(:revenue_milestones, [:processed])
    create index(:revenue_milestones, [:triggered_at])

    # ========================================================================
    # CAMPAIGN ANALYTICS TABLE
    # ========================================================================
    create table(:campaign_analytics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id), null: false

      # Revenue Analytics
      add :total_revenue_generated, :decimal, precision: 12, scale: 2, default: 0.00
      add :total_platform_fees, :decimal, precision: 12, scale: 2, default: 0.00
      add :total_contributor_payouts, :decimal, precision: 12, scale: 2, default: 0.00
      add :average_revenue_per_contributor, :decimal, precision: 10, scale: 2, default: 0.00

      # Contribution Analytics
      add :total_contributions, :integer, default: 0
      add :total_word_count, :integer, default: 0
      add :total_audio_minutes, :integer, default: 0
      add :total_media_items, :integer, default: 0
      add :average_quality_score, :decimal, precision: 3, scale: 2, default: 0.00

      # Collaboration Analytics
      add :total_collaborators, :integer, default: 0
      add :active_collaborators, :integer, default: 0
      add :peer_reviews_completed, :integer, default: 0
      add :quality_gates_passed, :integer, default: 0
      add :quality_gates_failed, :integer, default: 0
      add :improvement_periods_triggered, :integer, default: 0

      # Timeline Analytics
      add :campaign_duration_days, :integer
      add :average_daily_contributions, :decimal, precision: 5, scale: 2, default: 0.00
      add :time_to_first_contribution, :integer # minutes
      add :time_to_completion, :integer # days

      # Performance Metrics
      add :completion_rate, :decimal, precision: 5, scale: 2, default: 0.00
      add :contributor_retention_rate, :decimal, precision: 5, scale: 2, default: 0.00
      add :quality_improvement_rate, :decimal, precision: 5, scale: 2, default: 0.00

      # Calculated Fields
      add :analytics_generated_at, :utc_datetime, null: false
      add :analytics_version, :integer, default: 1

      timestamps()
    end

    create index(:campaign_analytics, [:campaign_id])
    create unique_index(:campaign_analytics, [:campaign_id], name: :unique_campaign_analytics)

    # ========================================================================
    # CONTENT TYPE TRACKING TABLE (Multi-format support)
    # ========================================================================
    create table(:content_type_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :bigint), null: false

      # Content Type Specific Metrics
      add :content_type, :string, null: false
      add :content_subtype, :string # blog_post, newsletter, podcast_episode, video_tutorial, etc.

      # Blog/Article Metrics
      add :word_count, :integer, default: 0
      add :readability_score, :decimal, precision: 3, scale: 2
      add :seo_score, :decimal, precision: 3, scale: 2
      add :publication_platforms, {:array, :string}, default: []
      add :total_views, :integer, default: 0
      add :engagement_rate, :decimal, precision: 5, scale: 4, default: 0.0000

      # Video Metrics
      add :video_duration_seconds, :integer, default: 0
      add :video_quality_score, :decimal, precision: 3, scale: 2
      add :production_role, :string
      add :editing_contributions, :map

      # Audio/Podcast Metrics
      add :audio_duration_seconds, :integer, default: 0
      add :audio_quality_score, :decimal, precision: 3, scale: 2
      add :speaking_time_seconds, :integer, default: 0
      add :audio_processing_score, :decimal, precision: 3, scale: 2

      # Data Story Metrics
      add :datasets_contributed, :integer, default: 0
      add :visualizations_created, :integer, default: 0
      add :research_insights, :integer, default: 0
      add :citations_added, :integer, default: 0
      add :data_accuracy_score, :decimal, precision: 3, scale: 2

      # Newsletter Metrics
      add :subscriber_growth, :integer, default: 0
      add :open_rate, :decimal, precision: 5, scale: 4, default: 0.0000
      add :click_rate, :decimal, precision: 5, scale: 4, default: 0.0000
      add :content_sections_contributed, :integer, default: 0

      # General Quality Metrics
      add :peer_review_score, :decimal, precision: 3, scale: 2
      add :unique_value_score, :decimal, precision: 3, scale: 2
      add :collaboration_score, :decimal, precision: 3, scale: 2

      # Timestamps for tracking
      add :last_contribution_at, :utc_datetime
      add :metrics_updated_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:content_type_metrics, [:campaign_id])
    create index(:content_type_metrics, [:user_id])
    create index(:content_type_metrics, [:content_type])
    create index(:content_type_metrics, [:content_subtype])
    create unique_index(:content_type_metrics, [:campaign_id, :user_id],
      name: :unique_campaign_user_content_metrics)

    # ========================================================================
    # EXTERNAL INTEGRATIONS TABLE
    # ========================================================================
    create table(:external_integrations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :bigint), null: false

      # Integration Details
      add :integration_type, :string, null: false # notion, google_docs, figma, discord, zapier, etc.
      add :integration_name, :string
      add :external_id, :string # Document ID, Figma file ID, etc.
      add :external_url, :string

      # Configuration
      add :configuration, :map, null: false
      add :webhook_url, :string
      add :api_credentials, :map # Encrypted
      add :sync_enabled, :boolean, default: true
      add :auto_sync_frequency, :string # hourly, daily, real_time

      # Status & Health
      add :status, :string, default: "active", null: false
      add :last_sync_at, :utc_datetime
      add :last_successful_sync_at, :utc_datetime
      add :sync_error_count, :integer, default: 0
      add :last_error_message, :text

      # Metrics
      add :total_contributions_synced, :integer, default: 0
      add :total_sync_attempts, :integer, default: 0
      add :successful_syncs, :integer, default: 0
      add :failed_syncs, :integer, default: 0

      timestamps()
    end

    create index(:external_integrations, [:campaign_id])
    create index(:external_integrations, [:user_id])
    create index(:external_integrations, [:integration_type])
    create index(:external_integrations, [:status])
    create index(:external_integrations, [:last_sync_at])
    create unique_index(:external_integrations, [:campaign_id, :integration_type, :external_id],
      name: :unique_campaign_integration)

    # ========================================================================
    # API ACCESS TOKENS TABLE
    # ========================================================================
    create table(:api_access_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :bigint), null: false

      # Token Details
      add :token_name, :string, null: false
      add :token_hash, :string, null: false # Hashed version of actual token
      add :token_prefix, :string, null: false # First few chars for identification
      add :scopes, {:array, :string}, null: false # campaigns:read, campaigns:write, etc.

      # Access Control
      add :allowed_ips, {:array, :string}
      add :rate_limit_per_hour, :integer, default: 1000
      add :campaign_access_type, :string, default: "owned_only" # owned_only, contributed_only, all
      add :specific_campaign_ids, {:array, :binary_id}

      # Usage Tracking
      add :last_used_at, :utc_datetime
      add :total_requests, :bigint, default: 0
      add :requests_this_hour, :integer, default: 0
      add :requests_hour_reset_at, :utc_datetime

      # Status & Security
      add :status, :string, default: "active", null: false
      add :expires_at, :utc_datetime
      add :created_by_ip, :string
      add :last_used_ip, :string
      add :revoked_at, :utc_datetime
      add :revoked_reason, :string

      timestamps()
    end

    create index(:api_access_tokens, [:user_id])
    create index(:api_access_tokens, [:token_hash])
    create index(:api_access_tokens, [:status])
    create index(:api_access_tokens, [:expires_at])
    create unique_index(:api_access_tokens, [:token_hash], name: :unique_api_token_hash)

    # ========================================================================
    # WEBHOOK LOGS TABLE
    # ========================================================================
    create table(:webhook_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :campaign_id, references(:content_campaigns, on_delete: :delete_all, type: :binary_id)
      add :integration_id, references(:external_integrations, on_delete: :delete_all, type: :binary_id)

      # Webhook Details
      add :webhook_type, :string, null: false # incoming, outgoing
      add :event_type, :string, null: false
      add :source, :string # zapier, notion, google_docs, etc.
      add :target_url, :string

      # Request/Response Data
      add :request_headers, :map
      add :request_body, :text
      add :response_status, :integer
      add :response_headers, :map
      add :response_body, :text

      # Processing Results
      add :processed_successfully, :boolean, default: false
      add :processing_error, :text
      add :retry_count, :integer, default: 0
      add :next_retry_at, :utc_datetime

      # Timing
      add :received_at, :utc_datetime, null: false
      add :processed_at, :utc_datetime
      add :processing_duration_ms, :integer

      timestamps()
    end

    create index(:webhook_logs, [:campaign_id])
    create index(:webhook_logs, [:integration_id])
    create index(:webhook_logs, [:webhook_type])
    create index(:webhook_logs, [:event_type])
    create index(:webhook_logs, [:source])
    create index(:webhook_logs, [:processed_successfully])
    create index(:webhook_logs, [:received_at])

    # ========================================================================
    # ADD INDEXES FOR PERFORMANCE
    # ========================================================================

    # Composite indexes for common queries
    create index(:campaign_payments, [:recipient_id, :status, :processed_at])
    create index(:revenue_distributions, [:campaign_id, :status, :calculated_at])
    create index(:campaign_contracts, [:contributor_id, :status, :signed_at])
    create index(:content_type_metrics, [:campaign_id, :content_type, :last_contribution_at])

    # Text search indexes (if using PostgreSQL)
    execute "CREATE INDEX IF NOT EXISTS campaign_contracts_legal_terms_search ON campaign_contracts USING gin(to_tsvector('english', legal_terms))"
    execute "CREATE INDEX IF NOT EXISTS webhook_logs_error_search ON webhook_logs USING gin(to_tsvector('english', processing_error))"
  end

  def down do
    # Drop indexes first
    drop_if_exists index(:webhook_logs, [:received_at])
    drop_if_exists index(:webhook_logs, [:processed_successfully])
    drop_if_exists index(:webhook_logs, [:source])
    drop_if_exists index(:webhook_logs, [:event_type])
    drop_if_exists index(:webhook_logs, [:webhook_type])
    drop_if_exists index(:webhook_logs, [:integration_id])
    drop_if_exists index(:webhook_logs, [:campaign_id])

    drop_if_exists index(:api_access_tokens, [:expires_at])
    drop_if_exists index(:api_access_tokens, [:status])
    drop_if_exists index(:api_access_tokens, [:token_hash])
    drop_if_exists index(:api_access_tokens, [:user_id])

    drop_if_exists index(:external_integrations, [:last_sync_at])
    drop_if_exists index(:external_integrations, [:status])
    drop_if_exists index(:external_integrations, [:integration_type])
    drop_if_exists index(:external_integrations, [:user_id])
    drop_if_exists index(:external_integrations, [:campaign_id])

    drop_if_exists index(:content_type_metrics, [:content_subtype])
    drop_if_exists index(:content_type_metrics, [:content_type])
    drop_if_exists index(:content_type_metrics, [:user_id])
    drop_if_exists index(:content_type_metrics, [:campaign_id])

    drop_if_exists index(:campaign_analytics, [:campaign_id])

    drop_if_exists index(:revenue_milestones, [:triggered_at])
    drop_if_exists index(:revenue_milestones, [:processed])
    drop_if_exists index(:revenue_milestones, [:triggered])
    drop_if_exists index(:revenue_milestones, [:milestone_type])
    drop_if_exists index(:revenue_milestones, [:campaign_id])

    drop_if_exists index(:campaign_payments, [:processed_at])
    drop_if_exists index(:campaign_payments, [:processor_transaction_id])
    drop_if_exists index(:campaign_payments, [:processor_payment_id])
    drop_if_exists index(:campaign_payments, [:payment_processor])
    drop_if_exists index(:campaign_payments, [:status])
    drop_if_exists index(:campaign_payments, [:recipient_id])
    drop_if_exists index(:campaign_payments, [:contract_id])
    drop_if_exists index(:campaign_payments, [:distribution_id])

    drop_if_exists index(:revenue_distributions, [:processed_at])
    drop_if_exists index(:revenue_distributions, [:calculated_at])
    drop_if_exists index(:revenue_distributions, [:status])
    drop_if_exists index(:revenue_distributions, [:campaign_id])

    drop_if_exists index(:campaign_contracts, [:contract_type])
    drop_if_exists index(:campaign_contracts, [:status])
    drop_if_exists index(:campaign_contracts, [:contributor_id])
    drop_if_exists index(:campaign_contracts, [:campaign_id])

    # Drop composite indexes
    drop_if_exists index(:content_type_metrics, [:campaign_id, :content_type, :last_contribution_at])
    drop_if_exists index(:campaign_contracts, [:contributor_id, :status, :signed_at])
    drop_if_exists index(:revenue_distributions, [:campaign_id, :status, :calculated_at])
    drop_if_exists index(:campaign_payments, [:recipient_id, :status, :processed_at])

    # Drop text search indexes
    execute "DROP INDEX IF EXISTS webhook_logs_error_search"
    execute "DROP INDEX IF EXISTS campaign_contracts_legal_terms_search"

    # Drop unique indexes
    drop_if_exists unique_index(:api_access_tokens, [:token_hash])
    drop_if_exists unique_index(:external_integrations, [:campaign_id, :integration_type, :external_id])
    drop_if_exists unique_index(:content_type_metrics, [:campaign_id, :user_id])
    drop_if_exists unique_index(:campaign_analytics, [:campaign_id])
    drop_if_exists unique_index(:campaign_contracts, [:campaign_id, :contributor_id])

    # Drop tables in reverse order
    drop table(:webhook_logs)
    drop table(:api_access_tokens)
    drop table(:external_integrations)
    drop table(:content_type_metrics)
    drop table(:campaign_analytics)
    drop table(:revenue_milestones)
    drop table(:campaign_payments)
    drop table(:revenue_distributions)
    drop table(:campaign_contracts)
  end
end
