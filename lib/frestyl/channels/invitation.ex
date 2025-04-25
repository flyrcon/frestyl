# lib/frestyl/channels/invitation.ex
defmodule Frestyl.Channels.Invitation do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Channels.{Channel, Role}

  schema "channel_invitations" do
    field :email, :string
    field :token, :string
    field :status, :string, default: "pending" # pending, accepted, declined, expired
    field :expires_at, :utc_datetime

    belongs_to :channel, Channel
    belongs_to :role, Role

    timestamps()
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :token, :status, :expires_at, :channel_id, :role_id])
    |> validate_required([:email, :token, :status, :expires_at, :channel_id, :role_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unique_constraint([:email, :channel_id],
                      message: "has already been invited to this channel")
  end
end
