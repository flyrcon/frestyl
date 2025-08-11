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
