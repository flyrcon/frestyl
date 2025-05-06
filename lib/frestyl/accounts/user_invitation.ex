# File: lib/frestyl/accounts/user_invitation.ex
defmodule Frestyl.Accounts.UserInvitation do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User

  schema "user_invitations" do
    field :email, :string
    field :status, :string, default: "pending"
    field :token, :string
    field :expires_at, :utc_datetime

    belongs_to :invited_by, User

    timestamps()
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :invited_by_id, :status, :token, :expires_at])
    |> validate_required([:email, :invited_by_id, :token, :expires_at])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint(:token)
  end
end
