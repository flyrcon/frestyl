# lib/frestyl/sessions/invitation.ex
defmodule Frestyl.Sessions.Invitation do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Sessions.Session
  alias Frestyl.Accounts.User

  schema "session_invitations" do
    field :email, :string
    field :token, :string
    field :role, :string, default: "participant"
    field :status, Ecto.Enum, values: [:pending, :accepted, :declined], default: :pending
    field :accepted, :boolean, default: false
    field :accepted_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :session, Session
    belongs_to :user, User
    belongs_to :inviter, User, foreign_key: :inviter_id

    timestamps()
  end

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :token, :role, :status, :session_id, :user_id, :inviter_id])
    |> validate_required([:email, :token, :role, :session_id, :inviter_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_inclusion(:role, ["participant", "moderator", "viewer"])
    |> put_expires_at()
    |> unique_constraint([:session_id, :email])
  end

  @doc """
  Changeset for accepting an invitation
  """
  def accept_changeset(invitation) do
    invitation
    |> change(%{
      status: :accepted,
      accepted: true,
      accepted_at: DateTime.utc_now()
    })
  end

  @doc """
  Changeset for declining an invitation
  """
  def decline_changeset(invitation) do
    invitation
    |> change(%{
      status: :declined,
      accepted: false
    })
  end

  defp put_expires_at(changeset) do
    if changeset.valid? && !get_field(changeset, :expires_at) do
      expires_at = DateTime.utc_now() |> DateTime.add(7 * 24 * 60 * 60, :second)
      put_change(changeset, :expires_at, expires_at)
    else
      changeset
    end
  end
end
