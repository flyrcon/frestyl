# lib/frestyl/content_editing/collaborator.ex
defmodule Frestyl.ContentEditing.Collaborator do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "editing_collaborators" do
    field :role, :string, default: "editor" # editor, viewer, reviewer, admin
    field :permissions, {:array, :string}, default: []
    field :invited_at, :utc_datetime
    field :joined_at, :utc_datetime
    field :last_active_at, :utc_datetime
    field :status, :string, default: "invited" # invited, active, inactive, removed
    field :contribution_score, :integer, default: 0
    field :metadata, :map, default: %{}

    belongs_to :project, Frestyl.ContentEditing.Project
    belongs_to :user, Frestyl.Accounts.User
    belongs_to :invited_by, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(collaborator, attrs) do
    collaborator
    |> cast(attrs, [:role, :permissions, :invited_at, :joined_at, :last_active_at, :status,
                    :contribution_score, :metadata, :project_id, :user_id, :invited_by])
    |> validate_required([:role, :project_id, :user_id])
    |> validate_inclusion(:role, ~w(editor viewer reviewer admin))
    |> validate_inclusion(:status, ~w(invited active inactive removed))
    |> validate_permissions()
    |> validate_number(:contribution_score, greater_than_or_equal_to: 0)
    |> unique_constraint([:project_id, :user_id])
  end

  defp validate_permissions(changeset) do
    valid_permissions = ~w(
      edit_timeline add_clips delete_clips move_clips
      apply_effects edit_effects delete_effects
      edit_tracks create_tracks delete_tracks
      render_project export_project
      invite_collaborators manage_collaborators
      edit_project_settings
    )

    permissions = get_change(changeset, :permissions) || []
    invalid_permissions = permissions -- valid_permissions

    if Enum.empty?(invalid_permissions) do
      changeset
    else
      add_error(changeset, :permissions, "contains invalid permissions: #{Enum.join(invalid_permissions, ", ")}")
    end
  end
end
