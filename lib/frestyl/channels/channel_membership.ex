defmodule Frestyl.Channels.ChannelMembership do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Channels.Channel
  alias Frestyl.Accounts.User

  schema "channel_memberships" do
    field :role, :string, default: "member" # member, moderator, admin
    field :last_activity_at, :utc_datetime
    field :can_send_messages, :boolean, default: true
    field :can_upload_files, :boolean, default: true
    field :can_invite_users, :boolean, default: false

    belongs_to :channel, Channel
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :last_activity_at, :channel_id, :user_id, :can_send_messages, :can_upload_files, :can_invite_users])
    |> validate_required([:role, :channel_id, :user_id])
    |> validate_inclusion(:role, ["member", "moderator", "admin"])
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :channel_id], name: :channel_memberships_user_id_channel_id_index)
  end

  @doc """
  Creates a changeset for updating a membership's role.
  """
  def role_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, ["member", "moderator", "admin"])
  end

  @doc """
  Creates a changeset for updating a membership's permissions.
  """
  def permissions_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:can_send_messages, :can_upload_files, :can_invite_users])
  end

  @doc """
  Creates a changeset for tracking user activity.
  """
  def activity_changeset(membership, attrs \\ %{}) do
    membership
    |> cast(attrs, [:last_activity_at])
    |> validate_required([:last_activity_at])
  end
end
