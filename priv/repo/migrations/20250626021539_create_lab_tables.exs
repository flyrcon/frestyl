# Migration file example for reference
# priv/repo/migrations/20240101000000_create_lab_tables.exs
defmodule Frestyl.Repo.Migrations.CreateLabTables do
  use Ecto.Migration

  def change do
    # Lab Features table
    create table(:lab_features) do
      add :name, :string, null: false
      add :description, :text
      add :category, :string, null: false
      add :icon, :string
      add :min_tier, :string, default: "free"
      add :time_limit_minutes, :integer, default: 0
      add :is_active, :boolean, default: true
      add :display_order, :integer, default: 0
      add :estimated_duration, :string
      add :collaboration_type, :string
      add :complexity_level, :string, default: "beginner"
      add :tags, {:array, :string}, default: []
      add :requirements, :map, default: %{}
      add :metadata, :map, default: %{}

      timestamps()
    end

    # Lab Experiments table
    create table(:lab_experiments) do
      add :status, :string, default: "active"
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :duration_minutes, :integer
      add :results, :map, default: %{}
      add :metadata, :map, default: %{}
      add :feedback_rating, :integer
      add :feedback_comments, :text
      add :shared_publicly, :boolean, default: false
      add :success_metrics, :map, default: %{}

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :feature_id, references(:lab_features, on_delete: :delete_all), null: false
      add :portfolio_id, references(:portfolios, on_delete: :nilify_all)
      add :channel_id, references(:channels, on_delete: :nilify_all)

      timestamps()
    end

    # Lab Usage table
    create table(:lab_usage) do
      add :action, :string, null: false
      add :duration_minutes, :integer, default: 0
      add :timestamp, :utc_datetime, null: false
      add :session_data, :map, default: %{}
      add :user_agent, :string
      add :ip_address, :string
      add :success, :boolean, default: true

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :feature_id, references(:lab_features, on_delete: :delete_all), null: false
      add :experiment_id, references(:lab_experiments, on_delete: :nilify_all)

      timestamps()
    end

    # Lab Templates table
    create table(:lab_templates) do
      add :name, :string, null: false
      add :description, :text
      add :category, :string, null: false
      add :theme_name, :string, null: false
      add :preview_url, :string
      add :min_tier, :string, default: "pro"
      add :is_active, :boolean, default: true
      add :is_experimental, :boolean, default: true
      add :stability_level, :string, default: "alpha"
      add :features, {:array, :string}, default: []
      add :customization_options, :map, default: %{}
      add :compatibility, :map, default: %{}
      add :performance_notes, :text
      add :usage_count, :integer, default: 0
      add :success_rate, :float, default: 0.0
      add :tags, {:array, :string}, default: []

      timestamps()
    end

    # Lab Collaborations table
    create table(:lab_collaborations) do
      add :type, :string, null: false
      add :status, :string, default: "pending"
      add :anonymous_mode, :boolean, default: false
      add :skills_offered, {:array, :string}, default: []
      add :skills_needed, {:array, :string}, default: []
      add :project_description, :text
      add :estimated_duration, :string
      add :collaboration_rules, :map, default: %{}
      add :matching_criteria, :map, default: %{}
      add :success_metrics, :map, default: %{}
      add :feedback_data, :map, default: %{}
      add :public_showcase, :boolean, default: false

      add :initiator_id, references(:users, on_delete: :delete_all), null: false
      add :collaborator_id, references(:users, on_delete: :nilify_all)
      add :channel_id, references(:channels, on_delete: :nilify_all)
      add :experiment_id, references(:lab_experiments, on_delete: :nilify_all)

      timestamps()
    end

    # Indexes for performance
    create index(:lab_features, [:category])
    create index(:lab_features, [:min_tier])
    create index(:lab_features, [:is_active])

    create index(:lab_experiments, [:user_id])
    create index(:lab_experiments, [:feature_id])
    create index(:lab_experiments, [:status])
    create index(:lab_experiments, [:started_at])

    create index(:lab_usage, [:user_id])
    create index(:lab_usage, [:feature_id])
    create index(:lab_usage, [:timestamp])
    create index(:lab_usage, [:action])

    create index(:lab_templates, [:category])
    create index(:lab_templates, [:min_tier])
    create index(:lab_templates, [:is_active])
    create index(:lab_templates, [:stability_level])

    create index(:lab_collaborations, [:initiator_id])
    create index(:lab_collaborations, [:collaborator_id])
    create index(:lab_collaborations, [:type])
    create index(:lab_collaborations, [:status])

    # Unique constraints
    create unique_index(:lab_features, [:name])
    create unique_index(:lab_templates, [:name])
    create unique_index(:lab_templates, [:theme_name])

    # Composite indexes for common queries
    create index(:lab_experiments, [:user_id, :status])
    create index(:lab_experiments, [:feature_id, :status])
    create index(:lab_usage, [:user_id, :feature_id])
    create index(:lab_usage, [:user_id, :timestamp])
  end
end
