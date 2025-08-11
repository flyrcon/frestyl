# lib/frestyl/calendar/event.ex
defmodule Frestyl.Calendar.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  # Content calendar event types
  @content_types [
    "general", "portfolio_update", "skill_showcase", "project_addition",
    "content_review", "client_work", "service_booking", "channel_broadcast",
    "collaboration", "learning", "industry_event", "revenue_review"
  ]

  @priority_levels ["critical", "high", "medium", "low"]
  @ownership_types ["mine", "participating", "fyi", "suggested", "imported"]
  @completion_statuses ["pending", "in_progress", "completed", "deferred", "cancelled"]
  @revenue_impacts ["critical", "high", "medium", "low", "none"]

  schema "calendar_events" do
    # Original fields
    field :title, :string
    field :description, :string
    field :event_type, :string
    field :status, :string, default: "scheduled"

    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :timezone, :string, default: "UTC"
    field :all_day, :boolean, default: false

    field :visibility, :string, default: "private"
    field :booking_enabled, :boolean, default: false
    field :max_attendees, :integer
    field :requires_approval, :boolean, default: false
    field :meeting_url, :string
    field :location, :string

    field :is_paid, :boolean, default: false
    field :price_cents, :integer, default: 0
    field :currency, :string, default: "USD"

    field :external_calendar_id, :string
    field :external_event_id, :string
    field :external_provider, :string
    field :sync_status, :string, default: "pending"

    field :metadata, :map, default: %{}
    field :reminders, {:array, :map}, default: []
    field :recurrence_rule, :string

    # Enhanced content calendar fields
    field :content_type, :string, default: "general"
    field :priority_level, :string, default: "medium"
    field :ownership_type, :string, default: "mine"
    field :completion_status, :string, default: "pending"

    # Smart features
    field :auto_generated, :boolean, default: false
    field :estimated_time_minutes, :integer
    field :revenue_impact, :string, default: "none"
    field :portfolio_section_affected, :string

    # Workflow state
    field :workflow_template, :string
    field :next_action_required, :string
    field :dependency_events, {:array, :binary_id}, default: []

    # Intelligence features
    field :success_metrics, :map, default: %{}
    field :auto_reminder_schedule, {:array, :string}, default: []
    field :suggested_followup_actions, {:array, :map}, default: []

    # External source tracking
    field :external_source, :string
    field :industry_relevance_score, :decimal

    # Foreign keys - all bigint to match existing schema
    field :creator_id, :integer
    field :account_id, :integer
    field :portfolio_id, :integer
    field :channel_id, :integer
    field :service_booking_id, :integer
    field :broadcast_id, :integer
    field :parent_event_id, :binary_id

    # Associations (using manual belongs_to since we have mixed foreign key types)
    belongs_to :creator, Frestyl.Accounts.User, foreign_key: :creator_id, references: :id, define_field: false
    belongs_to :account, Frestyl.Accounts.Account, foreign_key: :account_id, references: :id, define_field: false
    belongs_to :parent_event, __MODULE__, foreign_key: :parent_event_id, references: :id, define_field: false

    has_many :attendees, Frestyl.Calendar.EventAttendee, foreign_key: :event_id
    has_many :child_events, __MODULE__, foreign_key: :parent_event_id

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :title, :description, :event_type, :status, :starts_at, :ends_at,
      :timezone, :all_day, :visibility, :booking_enabled, :max_attendees,
      :requires_approval, :meeting_url, :location, :is_paid, :price_cents,
      :currency, :metadata, :reminders, :recurrence_rule, :creator_id,
      :account_id, :portfolio_id, :channel_id, :service_booking_id,
      :broadcast_id, :parent_event_id, :external_calendar_id,
      :external_event_id, :external_provider, :sync_status,
      # Enhanced content calendar fields
      :content_type, :priority_level, :ownership_type, :completion_status,
      :auto_generated, :estimated_time_minutes, :revenue_impact,
      :portfolio_section_affected, :workflow_template, :next_action_required,
      :dependency_events, :success_metrics, :auto_reminder_schedule,
      :suggested_followup_actions, :external_source, :industry_relevance_score
    ])
    |> validate_required([:title, :starts_at])
    |> validate_inclusion(:content_type, @content_types)
    |> validate_inclusion(:priority_level, @priority_levels)
    |> validate_inclusion(:ownership_type, @ownership_types)
    |> validate_inclusion(:completion_status, @completion_statuses)
    |> validate_inclusion(:revenue_impact, @revenue_impacts)
    |> validate_datetime_order()
    |> validate_attendee_limit()
    |> validate_estimated_time()
    |> validate_workflow_dependencies()
    |> maybe_set_auto_generated_fields()
  end

  # Content calendar specific functions
  def content_types, do: @content_types
  def priority_levels, do: @priority_levels
  def ownership_types, do: @ownership_types
  def completion_statuses, do: @completion_statuses
  def revenue_impacts, do: @revenue_impacts

  def is_content_event?(%__MODULE__{content_type: type}) when type in [
    "portfolio_update", "skill_showcase", "project_addition", "content_review"
  ], do: true
  def is_content_event?(_), do: false

  def is_revenue_event?(%__MODULE__{revenue_impact: impact}) when impact in [
    "critical", "high", "medium"
  ], do: true
  def is_revenue_event?(_), do: false

  def is_auto_generated?(%__MODULE__{auto_generated: true}), do: true
  def is_auto_generated?(_), do: false

  def requires_action?(%__MODULE__{completion_status: status}) when status in [
    "pending", "in_progress"
  ], do: true
  def requires_action?(_), do: false

  def get_priority_weight("critical"), do: 4
  def get_priority_weight("high"), do: 3
  def get_priority_weight("medium"), do: 2
  def get_priority_weight("low"), do: 1
  def get_priority_weight(_), do: 0

  def get_ownership_color("mine"), do: "blue"
  def get_ownership_color("participating"), do: "purple"
  def get_ownership_color("fyi"), do: "gray"
  def get_ownership_color("suggested"), do: "green"
  def get_ownership_color("imported"), do: "yellow"
  def get_ownership_color(_), do: "gray"

  def get_priority_color("critical"), do: "red"
  def get_priority_color("high"), do: "orange"
  def get_priority_color("medium"), do: "yellow"
  def get_priority_color("low"), do: "green"
  def get_priority_color(_), do: "gray"

  # Validation helpers
  defp validate_datetime_order(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && DateTime.compare(starts_at, ends_at) != :lt do
      add_error(changeset, :ends_at, "must be after start time")
    else
      changeset
    end
  end

  defp validate_attendee_limit(changeset) do
    max_attendees = get_field(changeset, :max_attendees)

    if max_attendees && max_attendees < 1 do
      add_error(changeset, :max_attendees, "must be at least 1")
    else
      changeset
    end
  end

  defp validate_estimated_time(changeset) do
    estimated_time = get_field(changeset, :estimated_time_minutes)

    if estimated_time && estimated_time < 1 do
      add_error(changeset, :estimated_time_minutes, "must be at least 1 minute")
    else
      changeset
    end
  end

  defp validate_workflow_dependencies(changeset) do
    dependencies = get_field(changeset, :dependency_events) || []
    event_id = get_field(changeset, :id)

    # Ensure event doesn't depend on itself
    if event_id && Enum.member?(dependencies, event_id) do
      add_error(changeset, :dependency_events, "event cannot depend on itself")
    else
      changeset
    end
  end

  defp maybe_set_auto_generated_fields(changeset) do
    auto_generated = get_field(changeset, :auto_generated)

    if auto_generated do
      changeset
      |> put_change(:ownership_type, "suggested")
      |> maybe_set_default_reminders()
    else
      changeset
    end
  end

  defp maybe_set_default_reminders(changeset) do
    content_type = get_field(changeset, :content_type)
    current_reminders = get_field(changeset, :auto_reminder_schedule) || []

    default_reminders = case content_type do
      "portfolio_update" -> ["7d", "1d", "2h"]
      "skill_showcase" -> ["3d", "1d"]
      "project_addition" -> ["1d", "4h"]
      "revenue_review" -> ["7d", "1d"]
      _ -> ["1d"]
    end

    if Enum.empty?(current_reminders) do
      put_change(changeset, :auto_reminder_schedule, default_reminders)
    else
      changeset
    end
  end

  # Helper functions for UI display
  def format_content_type("portfolio_update"), do: "Portfolio Update"
  def format_content_type("skill_showcase"), do: "Skill Showcase"
  def format_content_type("project_addition"), do: "Project Addition"
  def format_content_type("content_review"), do: "Content Review"
  def format_content_type("client_work"), do: "Client Work"
  def format_content_type("service_booking"), do: "Service Booking"
  def format_content_type("channel_broadcast"), do: "Channel Broadcast"
  def format_content_type("collaboration"), do: "Collaboration"
  def format_content_type("learning"), do: "Learning"
  def format_content_type("industry_event"), do: "Industry Event"
  def format_content_type("revenue_review"), do: "Revenue Review"
  def format_content_type(type), do: Phoenix.Naming.humanize(type)

  def format_priority_level("critical"), do: "🔴 Critical"
  def format_priority_level("high"), do: "🟠 High"
  def format_priority_level("medium"), do: "🟡 Medium"
  def format_priority_level("low"), do: "🟢 Low"
  def format_priority_level(level), do: Phoenix.Naming.humanize(level)

  def format_ownership_type("mine"), do: "📋 My Content"
  def format_ownership_type("participating"), do: "🤝 Participating"
  def format_ownership_type("fyi"), do: "📚 FYI"
  def format_ownership_type("suggested"), do: "💡 Suggested"
  def format_ownership_type("imported"), do: "📥 Imported"
  def format_ownership_type(type), do: Phoenix.Naming.humanize(type)

  def format_revenue_impact("critical"), do: "💰 Critical Revenue Impact"
  def format_revenue_impact("high"), do: "💰 High Revenue Impact"
  def format_revenue_impact("medium"), do: "💸 Medium Revenue Impact"
  def format_revenue_impact("low"), do: "💸 Low Revenue Impact"
  def format_revenue_impact("none"), do: "No Revenue Impact"
  def format_revenue_impact(impact), do: Phoenix.Naming.humanize(impact)
end
