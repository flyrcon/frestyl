# lib/frestyl/lab/usage.ex
defmodule Frestyl.Lab.Usage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_usage" do
    field :action, :string # "start", "complete", "cancel", "pause", "resume"
    field :duration_minutes, :integer, default: 0
    field :timestamp, :utc_datetime
    field :session_data, :map, default: %{} # Additional session tracking data
    field :user_agent, :string # For tracking device/browser usage
    field :ip_address, :string # For geographic usage analytics
    field :success, :boolean, default: true # Whether the action was successful

    belongs_to :user, Frestyl.Accounts.User
    belongs_to :feature, Frestyl.Lab.Feature
    belongs_to :experiment, Frestyl.Lab.Experiment, on_replace: :nilify

    timestamps()
  end

  @doc false
  def changeset(usage, attrs) do
    usage
    |> cast(attrs, [
      :action, :duration_minutes, :timestamp, :session_data, :user_agent,
      :ip_address, :success, :user_id, :feature_id, :experiment_id
    ])
    |> validate_required([:action, :timestamp, :user_id, :feature_id])
    |> validate_inclusion(:action, ["start", "complete", "cancel", "pause", "resume", "error"])
    |> validate_number(:duration_minutes, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:feature_id)
    |> foreign_key_constraint(:experiment_id)
  end
end
