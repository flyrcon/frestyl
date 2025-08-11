# priv/repo/migrations/20250812000001_enhance_calendar_for_content.exs
defmodule Frestyl.Repo.Migrations.EnhanceCalendarForContent do
  use Ecto.Migration

  def up do
    # Add content calendar specific fields to calendar_events
    alter table(:calendar_events) do
      # Content calendar classification
      add :content_type, :string, default: "general"
      add :priority_level, :string, default: "medium"
      add :ownership_type, :string, default: "mine"
      add :completion_status, :string, default: "pending"

      # Smart features
      add :auto_generated, :boolean, default: false
      add :estimated_time_minutes, :integer
      add :revenue_impact, :string, default: "none"
      add :portfolio_section_affected, :string

      # Workflow state
      add :workflow_template, :string
      add :next_action_required, :string
      add :dependency_events, {:array, :binary_id}, default: []

      # Intelligence features
      add :success_metrics, :map, default: %{}
      add :auto_reminder_schedule, {:array, :string}, default: []
      add :suggested_followup_actions, {:array, :map}, default: []

      # External source tracking
      add :external_source, :string
      add :industry_relevance_score, :decimal, precision: 3, scale: 2
    end

    # Create content suggestions table
    create table(:calendar_content_suggestions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :integer, null: false
      add :account_id, :integer, null: false
      add :portfolio_id, :integer

      add :suggestion_type, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :rationale, :text
      add :priority_score, :integer, default: 0

      add :estimated_impact, :string, default: "low"
      add :estimated_time_minutes, :integer
      add :suggested_due_date, :utc_datetime

      add :status, :string, default: "pending"
      add :dismissed_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :converted_to_event_id, :binary_id

      add :metadata, :map, default: %{}
      add :analytics_data, :map, default: %{}

      timestamps()
    end

    # Create portfolio health tracking table
    create table(:portfolio_health_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :portfolio_id, :integer, null: false
      add :user_id, :integer, null: false

      add :last_content_update, :utc_datetime
      add :last_skill_update, :utc_datetime
      add :last_project_addition, :utc_datetime
      add :last_testimonial_update, :utc_datetime

      add :completeness_score, :decimal, precision: 5, scale: 2
      add :freshness_score, :decimal, precision: 5, scale: 2
      add :engagement_score, :decimal, precision: 5, scale: 2
      add :seo_score, :decimal, precision: 5, scale: 2

      add :stale_sections, {:array, :string}, default: []
      add :missing_elements, {:array, :string}, default: []
      add :optimization_opportunities, {:array, :map}, default: []

      add :last_analyzed_at, :utc_datetime
      add :analysis_version, :string

      timestamps()
    end

    # Create calendar workflow templates table
    create table(:calendar_workflow_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :category, :string, null: false

      add :estimated_duration_minutes, :integer
      add :required_tier, :string, default: "personal"

      add :steps, {:array, :map}, default: []
      add :completion_criteria, :map, default: %{}
      add :success_metrics, {:array, :string}, default: []

      add :is_system_template, :boolean, default: false
      add :is_active, :boolean, default: true

      timestamps()
    end

    # Create workflow executions table
    create table(:calendar_workflow_executions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, :binary_id, null: false
      add :template_id, :binary_id, null: false
      add :user_id, :integer, null: false

      add :status, :string, default: "started"
      add :current_step, :integer, default: 0
      add :total_steps, :integer, null: false

      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :paused_at, :utc_datetime

      add :steps_completed, {:array, :map}, default: []
      add :time_spent_minutes, :integer, default: 0
      add :completion_notes, :text

      timestamps()
    end

    # Add indexes for performance
    create index(:calendar_events, [:content_type])
    create index(:calendar_events, [:ownership_type])
    create index(:calendar_events, [:priority_level])
    create index(:calendar_events, [:completion_status])
    create index(:calendar_events, [:auto_generated])
    create index(:calendar_events, [:workflow_template])
    create index(:calendar_events, [:portfolio_id, :content_type])

    create index(:calendar_content_suggestions, [:user_id, :status])
    create index(:calendar_content_suggestions, [:suggestion_type])
    create index(:calendar_content_suggestions, [:priority_score])
    create index(:calendar_content_suggestions, [:suggested_due_date])

    create index(:portfolio_health_metrics, [:portfolio_id])
    create index(:portfolio_health_metrics, [:user_id])
    create index(:portfolio_health_metrics, [:last_analyzed_at])
    create index(:portfolio_health_metrics, [:completeness_score])
    create index(:portfolio_health_metrics, [:freshness_score])

    create index(:calendar_workflow_templates, [:category])
    create index(:calendar_workflow_templates, [:required_tier])
    create index(:calendar_workflow_templates, [:is_system_template])
    create index(:calendar_workflow_templates, [:is_active])

    create index(:calendar_workflow_executions, [:event_id])
    create index(:calendar_workflow_executions, [:template_id])
    create index(:calendar_workflow_executions, [:user_id, :status])
    create index(:calendar_workflow_executions, [:status])

    # Add foreign key constraints
    create constraint(:calendar_content_suggestions, :valid_suggestion_type,
      check: "suggestion_type IN ('portfolio_update', 'skill_addition', 'project_showcase', 'testimonial_request', 'seo_optimization', 'content_refresh', 'service_launch', 'rate_increase')")

    create constraint(:calendar_content_suggestions, :valid_status,
      check: "status IN ('pending', 'accepted', 'dismissed', 'completed', 'expired')")

    create constraint(:calendar_events, :valid_content_type,
      check: "content_type IN ('general', 'portfolio_update', 'skill_showcase', 'project_addition', 'content_review', 'client_work', 'service_booking', 'channel_broadcast', 'collaboration', 'learning', 'industry_event', 'revenue_review')")

    create constraint(:calendar_events, :valid_priority_level,
      check: "priority_level IN ('critical', 'high', 'medium', 'low')")

    create constraint(:calendar_events, :valid_ownership_type,
      check: "ownership_type IN ('mine', 'participating', 'fyi', 'suggested', 'imported')")

    create constraint(:calendar_events, :valid_completion_status,
      check: "completion_status IN ('pending', 'in_progress', 'completed', 'deferred', 'cancelled')")

    create constraint(:calendar_events, :valid_revenue_impact,
      check: "revenue_impact IN ('critical', 'high', 'medium', 'low', 'none')")

    # Update existing events with default values
    execute """
    UPDATE calendar_events
    SET
      content_type = CASE
        WHEN event_type = 'service_booking' THEN 'service_booking'
        WHEN event_type = 'broadcast' THEN 'channel_broadcast'
        WHEN event_type = 'portfolio_studio' THEN 'portfolio_update'
        ELSE 'general'
      END,
      ownership_type = 'mine',
      priority_level = CASE
        WHEN event_type = 'service_booking' THEN 'high'
        WHEN event_type = 'broadcast' THEN 'medium'
        ELSE 'low'
      END,
      revenue_impact = CASE
        WHEN event_type = 'service_booking' THEN 'high'
        WHEN is_paid = true THEN 'medium'
        ELSE 'none'
      END
    WHERE content_type IS NULL
    """
  end

  def down do
    drop constraint(:calendar_events, :valid_revenue_impact)
    drop constraint(:calendar_events, :valid_completion_status)
    drop constraint(:calendar_events, :valid_ownership_type)
    drop constraint(:calendar_events, :valid_priority_level)
    drop constraint(:calendar_events, :valid_content_type)
    drop constraint(:calendar_content_suggestions, :valid_status)
    drop constraint(:calendar_content_suggestions, :valid_suggestion_type)

    drop index(:calendar_workflow_executions, [:status])
    drop index(:calendar_workflow_executions, [:user_id, :status])
    drop index(:calendar_workflow_executions, [:template_id])
    drop index(:calendar_workflow_executions, [:event_id])

    drop index(:calendar_workflow_templates, [:is_active])
    drop index(:calendar_workflow_templates, [:is_system_template])
    drop index(:calendar_workflow_templates, [:required_tier])
    drop index(:calendar_workflow_templates, [:category])

    drop index(:portfolio_health_metrics, [:freshness_score])
    drop index(:portfolio_health_metrics, [:completeness_score])
    drop index(:portfolio_health_metrics, [:last_analyzed_at])
    drop index(:portfolio_health_metrics, [:user_id])
    drop index(:portfolio_health_metrics, [:portfolio_id])

    drop index(:calendar_content_suggestions, [:suggested_due_date])
    drop index(:calendar_content_suggestions, [:priority_score])
    drop index(:calendar_content_suggestions, [:suggestion_type])
    drop index(:calendar_content_suggestions, [:user_id, :status])

    drop index(:calendar_events, [:portfolio_id, :content_type])
    drop index(:calendar_events, [:workflow_template])
    drop index(:calendar_events, [:auto_generated])
    drop index(:calendar_events, [:completion_status])
    drop index(:calendar_events, [:priority_level])
    drop index(:calendar_events, [:ownership_type])
    drop index(:calendar_events, [:content_type])

    drop table(:calendar_workflow_executions)
    drop table(:calendar_workflow_templates)
    drop table(:portfolio_health_metrics)
    drop table(:calendar_content_suggestions)

    alter table(:calendar_events) do
      remove :industry_relevance_score
      remove :external_source
      remove :suggested_followup_actions
      remove :auto_reminder_schedule
      remove :success_metrics
      remove :dependency_events
      remove :next_action_required
      remove :workflow_template
      remove :portfolio_section_affected
      remove :revenue_impact
      remove :estimated_time_minutes
      remove :auto_generated
      remove :completion_status
      remove :ownership_type
      remove :priority_level
      remove :content_type
    end
  end
end
