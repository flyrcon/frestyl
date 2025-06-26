# lib/frestyl/lab/collaboration.ex
defmodule Frestyl.Lab.Collaboration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_collaborations" do
    field :type, :string # "cipher", "stranger_match", "brainstorm", "skill_exchange"
    field :status, Ecto.Enum, values: [:pending, :active, :completed, :cancelled], default: :pending
    field :anonymous_mode, :boolean, default: false
    field :skills_offered, {:array, :string}, default: []
    field :skills_needed, {:array, :string}, default: []
    field :project_description, :string
    field :estimated_duration, :string
    field :collaboration_rules, :map, default: %{} # Custom rules for the collaboration
    field :matching_criteria, :map, default: %{} # Criteria used for matching
    field :success_metrics, :map, default: %{} # How to measure collaboration success
    field :feedback_data, :map, default: %{} # Post-collaboration feedback
    field :public_showcase, :boolean, default: false # Whether results can be showcased

    belongs_to :initiator, Frestyl.Accounts.User
    belongs_to :collaborator, Frestyl.Accounts.User, on_replace: :nilify
    belongs_to :channel, Frestyl.Channels.Channel, on_replace: :nilify
    belongs_to :experiment, Frestyl.Lab.Experiment, on_replace: :nilify

    timestamps()
  end

  @doc false
  def changeset(collaboration, attrs) do
    collaboration
    |> cast(attrs, [
      :type, :status, :anonymous_mode, :skills_offered, :skills_needed,
      :project_description, :estimated_duration, :collaboration_rules,
      :matching_criteria, :success_metrics, :feedback_data, :public_showcase,
      :initiator_id, :collaborator_id, :channel_id, :experiment_id
    ])
    |> validate_required([:type, :status, :initiator_id])
    |> validate_inclusion(:type, ["cipher", "stranger_match", "brainstorm", "skill_exchange"])
    |> foreign_key_constraint(:initiator_id)
    |> foreign_key_constraint(:collaborator_id)
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:experiment_id)
    |> validate_collaboration_participants()
  end

  defp validate_collaboration_participants(changeset) do
    initiator_id = get_field(changeset, :initiator_id)
    collaborator_id = get_field(changeset, :collaborator_id)

    if initiator_id && collaborator_id && initiator_id == collaborator_id do
      add_error(changeset, :collaborator_id, "cannot be the same as initiator")
    else
      changeset
    end
  end
end
