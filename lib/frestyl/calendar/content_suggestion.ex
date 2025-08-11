# lib/frestyl/calendar/content_suggestion.ex
defmodule Frestyl.Calendar.ContentSuggestion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @suggestion_types [
    "portfolio_update", "skill_addition", "project_showcase", "testimonial_request",
    "seo_optimization", "content_refresh", "service_launch", "rate_increase"
  ]

  @statuses ["pending", "accepted", "dismissed", "completed", "expired"]
  @impact_levels ["critical", "high", "medium", "low"]

  schema "calendar_content_suggestions" do
    field :user_id, :integer
    field :account_id, :integer
    field :portfolio_id, :integer

    field :suggestion_type, :string
    field :title, :string
    field :description, :string
    field :rationale, :string
    field :priority_score, :integer, default: 0

    field :estimated_impact, :string, default: "low"
    field :estimated_time_minutes, :integer
    field :suggested_due_date, :utc_datetime

    field :status, :string, default: "pending"
    field :dismissed_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :converted_to_event_id, :binary_id

    field :metadata, :map, default: %{}
    field :analytics_data, :map, default: %{}

    # Manual associations
    belongs_to :user, Frestyl.Accounts.User, foreign_key: :user_id, references: :id, define_field: false
    belongs_to :account, Frestyl.Accounts.Account, foreign_key: :account_id, references: :id, define_field: false
    belongs_to :converted_event, Frestyl.Calendar.Event, foreign_key: :converted_to_event_id, references: :id, define_field: false

    timestamps()
  end

  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [
      :user_id, :account_id, :portfolio_id, :suggestion_type, :title, :description,
      :rationale, :priority_score, :estimated_impact, :estimated_time_minutes,
      :suggested_due_date, :status, :dismissed_at, :completed_at,
      :converted_to_event_id, :metadata, :analytics_data
    ])
    |> validate_required([:user_id, :account_id, :suggestion_type, :title])
    |> validate_inclusion(:suggestion_type, @suggestion_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:estimated_impact, @impact_levels)
    |> validate_number(:priority_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:estimated_time_minutes, greater_than: 0)
    |> validate_length(:title, min: 5, max: 200)
    |> validate_length(:description, max: 1000)
  end

  def suggestion_types, do: @suggestion_types
  def statuses, do: @statuses
  def impact_levels, do: @impact_levels

  def is_pending?(%__MODULE__{status: "pending"}), do: true
  def is_pending?(_), do: false

  def is_high_priority?(%__MODULE__{priority_score: score}) when score >= 80, do: true
  def is_high_priority?(_), do: false

  def is_overdue?(%__MODULE__{suggested_due_date: nil}), do: false
  def is_overdue?(%__MODULE__{suggested_due_date: due_date}) do
    DateTime.compare(DateTime.utc_now(), due_date) == :gt
  end

  def format_suggestion_type("portfolio_update"), do: "Portfolio Update"
  def format_suggestion_type("skill_addition"), do: "Add New Skill"
  def format_suggestion_type("project_showcase"), do: "Showcase Project"
  def format_suggestion_type("testimonial_request"), do: "Request Testimonial"
  def format_suggestion_type("seo_optimization"), do: "SEO Optimization"
  def format_suggestion_type("content_refresh"), do: "Content Refresh"
  def format_suggestion_type("service_launch"), do: "Service Launch"
  def format_suggestion_type("rate_increase"), do: "Rate Increase"
  def format_suggestion_type(type), do: Phoenix.Naming.humanize(type)

  def get_icon("portfolio_update"), do: "📝"
  def get_icon("skill_addition"), do: "🎯"
  def get_icon("project_showcase"), do: "🚀"
  def get_icon("testimonial_request"), do: "💬"
  def get_icon("seo_optimization"), do: "🔍"
  def get_icon("content_refresh"), do: "🔄"
  def get_icon("service_launch"), do: "💼"
  def get_icon("rate_increase"), do: "💰"
  def get_icon(_), do: "💡"

  def get_color("critical"), do: "red"
  def get_color("high"), do: "orange"
  def get_color("medium"), do: "yellow"
  def get_color("low"), do: "green"
  def get_color(_), do: "gray"
end


# lib/frestyl/calendar/health_metric.ex
defmodule Frestyl.Calendar.HealthMetric do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "portfolio_health_metrics" do
    field :portfolio_id, :integer
    field :user_id, :integer

    field :last_content_update, :utc_datetime
    field :last_skill_update, :utc_datetime
    field :last_project_addition, :utc_datetime
    field :last_testimonial_update, :utc_datetime

    field :completeness_score, :decimal
    field :freshness_score, :decimal
    field :engagement_score, :decimal
    field :seo_score, :decimal

    field :stale_sections, {:array, :string}, default: []
    field :missing_elements, {:array, :string}, default: []
    field :optimization_opportunities, {:array, :map}, default: []

    field :last_analyzed_at, :utc_datetime
    field :analysis_version, :string

    # Manual associations
    belongs_to :user, Frestyl.Accounts.User, foreign_key: :user_id, references: :id, define_field: false

    timestamps()
  end

  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [
      :portfolio_id, :user_id, :last_content_update, :last_skill_update,
      :last_project_addition, :last_testimonial_update, :completeness_score,
      :freshness_score, :engagement_score, :seo_score, :stale_sections,
      :missing_elements, :optimization_opportunities, :last_analyzed_at,
      :analysis_version
    ])
    |> validate_required([:portfolio_id, :user_id])
    |> validate_number(:completeness_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:freshness_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:engagement_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:seo_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> unique_constraint([:portfolio_id])
  end

  def overall_health_score(metric) do
    scores = [
      metric.completeness_score || 0,
      metric.freshness_score || 0,
      metric.engagement_score || 0,
      metric.seo_score || 0
    ]

    weights = [0.4, 0.25, 0.20, 0.15]  # Completeness is most important

    weighted_sum = Enum.zip(scores, weights)
    |> Enum.reduce(0, fn {score, weight}, acc ->
      acc + (Decimal.to_float(score) * weight)
    end)

    Float.round(weighted_sum, 2)
  end

  def health_grade(metric) do
    score = overall_health_score(metric)

    cond do
      score >= 90 -> "A"
      score >= 80 -> "B"
      score >= 70 -> "C"
      score >= 60 -> "D"
      true -> "F"
    end
  end

  def needs_attention?(metric) do
    overall_health_score(metric) < 70 || length(metric.stale_sections) > 2
  end

  def is_stale?(metric) do
    case metric.last_analyzed_at do
      nil -> true
      last_analyzed -> DateTime.diff(DateTime.utc_now(), last_analyzed, :day) > 7
    end
  end

  def next_analysis_due(metric) do
    case metric.last_analyzed_at do
      nil -> DateTime.utc_now()
      last_analyzed ->
        score = overall_health_score(metric)
        days_to_add = cond do
          score >= 90 -> 30  # Monthly for excellent portfolios
          score >= 75 -> 21  # Every 3 weeks for good portfolios
          score >= 60 -> 14  # Bi-weekly for fair portfolios
          true -> 7          # Weekly for poor portfolios
        end
        DateTime.add(last_analyzed, days_to_add * 24 * 60 * 60, :second)
    end
  end
end
