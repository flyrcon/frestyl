defmodule Frestyl.Teams.RatingReminder do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "rating_reminders" do
    field :reminder_type, :string
    field :due_at, :utc_datetime
    field :escalation_level, :integer, default: 0
    field :last_reminded_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :status, :string, default: "pending"

    belongs_to :team, Frestyl.Teams.ChannelTeam
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [:reminder_type, :due_at, :escalation_level, :last_reminded_at,
                    :completed_at, :status])
    |> validate_required([:team_id, :user_id, :reminder_type, :due_at])
    |> validate_inclusion(:reminder_type, ["pulse_check", "milestone_rating"])
    |> validate_inclusion(:status, ["pending", "completed", "escalated"])
    |> validate_number(:escalation_level, greater_than_or_equal_to: 0, less_than_or_equal_to: 3)
    |> foreign_key_constraint(:team_id)
    |> foreign_key_constraint(:user_id)
  end
end
