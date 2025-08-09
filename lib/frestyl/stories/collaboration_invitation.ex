# lib/frestyl/stories/collaboration_invitation.ex - Invitation Schema
defmodule Frestyl.Stories.CollaborationInvitation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Frestyl.Stories.EnhancedStoryStructure
  alias Frestyl.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "collaboration_invitations" do
    field :invitation_code, :string
    field :role, :string, default: "collaborator"
    field :expires_at, :utc_datetime
    field :max_uses, :integer, default: 1
    field :uses_count, :integer, default: 0
    field :is_active, :boolean, default: true

    belongs_to :story, EnhancedStoryStructure
    belongs_to :created_by, User

    timestamps()
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:invitation_code, :role, :expires_at, :max_uses, :story_id, :created_by_id])
    |> validate_required([:invitation_code, :role, :expires_at, :story_id, :created_by_id])
    |> validate_inclusion(:role, ["viewer", "collaborator", "editor", "co_author"])
    |> unique_constraint(:invitation_code)
  end
end
