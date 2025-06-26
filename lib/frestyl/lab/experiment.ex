# lib/frestyl/lab/experiment.ex
defmodule Frestyl.Lab.Experiment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_experiments" do
    field :status, Ecto.Enum, values: [:active, :completed, :cancelled, :expired], default: :active
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :duration_minutes, :integer
    field :results, :map, default: %{} # Experiment results and data
    field :metadata, :map, default: %{} # Feature-specific experiment data
    field :feedback_rating, :integer # User satisfaction rating (1-5)
    field :feedback_comments, :string
    field :shared_publicly, :boolean, default: false # Whether user wants to share results
    field :success_metrics, :map, default: %{} # Success criteria and achievements

    belongs_to :user, Frestyl.Accounts.User
    belongs_to :feature, Frestyl.Lab.Feature
    belongs_to :portfolio, Frestyl.Portfolios.Portfolio, on_replace: :nilify
    belongs_to :channel, Frestyl.Channels.Channel, on_replace: :nilify # For collaborative experiments

    timestamps()
  end

  @doc false
  def changeset(experiment, attrs) do
    experiment
    |> cast(attrs, [
      :status, :started_at, :ended_at, :duration_minutes, :results, :metadata,
      :feedback_rating, :feedback_comments, :shared_publicly, :success_metrics,
      :user_id, :feature_id, :portfolio_id, :channel_id
    ])
    |> validate_required([:user_id, :feature_id, :started_at, :status])
    |> validate_inclusion(:feedback_rating, 1..5)
    |> validate_experiment_duration()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:feature_id)
    |> foreign_key_constraint(:portfolio_id)
    |> foreign_key_constraint(:channel_id)
  end

  @doc """
  Changeset for ending an experiment.
  """
  def end_changeset(experiment, attrs) do
    experiment
    |> cast(attrs, [:ended_at, :duration_minutes, :status, :results, :feedback_rating, :feedback_comments])
    |> validate_required([:ended_at, :status])
    |> validate_experiment_completion()
  end

  defp validate_experiment_duration(changeset) do
    started_at = get_field(changeset, :started_at)
    ended_at = get_field(changeset, :ended_at)

    if started_at && ended_at && DateTime.compare(ended_at, started_at) == :lt do
      add_error(changeset, :ended_at, "must be after start time")
    else
      changeset
    end
  end

  defp validate_experiment_completion(changeset) do
    status = get_field(changeset, :status)
    ended_at = get_field(changeset, :ended_at)

    if status in [:completed, :cancelled] && is_nil(ended_at) do
      add_error(changeset, :ended_at, "is required when experiment is completed or cancelled")
    else
      changeset
    end
  end
end
