defmodule Frestyl.Channels.ChannelMembership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "channel_memberships" do
    field :role, :string, default: "member"
    field :status, :string, default: "active"
    field :joined_at, :utc_datetime
    field :left_at, :utc_datetime

    belongs_to :user, Frestyl.Accounts.User
    belongs_to :channel, Frestyl.Channels.Channel

    timestamps()
  end

  @doc false
  def changeset(channel_membership, attrs) do
    channel_membership
    |> cast(attrs, [:role, :status, :joined_at, :left_at, :user_id, :channel_id])
    |> validate_required([:role, :status, :user_id, :channel_id])
    |> validate_inclusion(:role, ["member", "moderator", "admin"])
    |> validate_inclusion(:status, ["active", "inactive", "banned", "left"])
    |> validate_status_dates()
    |> unique_constraint([:user_id, :channel_id])
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

  # Custom validation for status and dates
  defp validate_status_dates(changeset) do
    status = get_change(changeset, :status) || get_field(changeset, :status)
    joined_at = get_change(changeset, :joined_at) || get_field(changeset, :joined_at)

    changeset = if is_nil(joined_at) and status == "active" do
      put_change(changeset, :joined_at, DateTime.utc_now() |> DateTime.truncate(:second))
    else
      changeset
    end

    # Set left_at when status changes to "left"
    if status == "left" and is_nil(get_field(changeset, :left_at)) do
      put_change(changeset, :left_at, DateTime.utc_now() |> DateTime.truncate(:second))
    else
      changeset
    end
  end
end
