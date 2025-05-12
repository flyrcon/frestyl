# lib/frestyl/channels/blocked_user.ex
defmodule Frestyl.Channels.BlockedUser do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Channels.Channel
  alias Frestyl.Accounts.User

  schema "blocked_users" do
    field :reason, :string
    field :expires_at, :utc_datetime
    field :block_level, :string, default: "channel" # channel, organization, etc.
    field :restrictions, {:array, :string}, default: ["all"] # all, view, post, etc.
    field :email, :string # For proactive blocking by email
    field :blocked_by_user_id, :id
    field :notes, :string

    belongs_to :channel, Channel
    belongs_to :user, User, on_replace: :nilify

    timestamps()
  end

  @doc false
  def changeset(blocked_user, attrs) do
    blocked_user
    |> cast(attrs, [:channel_id, :user_id, :blocked_by_user_id, :reason, :expires_at,
                    :block_level, :restrictions, :email, :notes])
    |> validate_required([:channel_id, :blocked_by_user_id])
    |> validate_user_or_email()
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:blocked_by_user_id)
    |> unique_constraint([:user_id, :channel_id],
        message: "User is already blocked from this channel")
    |> unique_constraint([:email, :channel_id],
        message: "Email is already blocked from this channel")
  end

  # Custom validation to ensure either user_id or email is present
  defp validate_user_or_email(changeset) do
    user_id = get_field(changeset, :user_id)
    email = get_field(changeset, :email)

    if is_nil(user_id) && is_nil(email) do
      add_error(changeset, :user_id, "Either user_id or email must be provided")
    else
      changeset
    end
  end
end
