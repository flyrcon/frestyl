defmodule Frestyl.Channels.Membership do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Channels.{Channel, Role}

  schema "channel_memberships" do
    belongs_to :user, User
    belongs_to :channel, Channel
    belongs_to :role, Role

    # Additional permissions specific to this membership
    field :can_send_messages, :boolean, default: true
    field :can_manage_members, :boolean, default: false
    field :can_create_rooms, :boolean, default: false

    timestamps()
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :channel_id, :role_id, :can_send_messages,
                   :can_manage_members, :can_create_rooms])
    |> validate_required([:user_id, :channel_id, :role_id])
    |> unique_constraint([:user_id, :channel_id],
                       message: "User is already a member of this channel")
  end
end
