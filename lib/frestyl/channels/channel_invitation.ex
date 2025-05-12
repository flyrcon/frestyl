# lib/frestyl/channels/channel_invitation.ex
defmodule Frestyl.Channels.ChannelInvitation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "channel_invitations" do
    field :email, :string
    field :token, :string
    field :status, Ecto.Enum, values: [:pending, :accepted, :declined], default: :pending
    field :expires_at, :utc_datetime

    belongs_to :channel, Frestyl.Channels.Channel
    belongs_to :inviter, Frestyl.Accounts.User
    belongs_to :user, Frestyl.Accounts.User  # Remove the optional: true option

    timestamps()
  end

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :token, :status, :expires_at, :channel_id, :inviter_id, :user_id])
    |> validate_required([:email, :token, :status, :expires_at, :channel_id, :inviter_id])
    # No validation required for user_id since it can be nil
    |> unique_constraint(:token)
  end
end
