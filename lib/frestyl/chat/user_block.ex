# lib/frestyl/chat/user_block.ex
defmodule Frestyl.Chat.UserBlock do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_blocks" do
    field :reason, :string
    field :blocked_until, :utc_datetime
    field :is_permanent, :boolean, default: false

    belongs_to :blocker, Frestyl.Accounts.User
    belongs_to :blocked, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(user_block, attrs) do
    user_block
    |> cast(attrs, [:reason, :blocked_until, :is_permanent, :blocker_id, :blocked_id])
    |> validate_required([:blocker_id, :blocked_id])
    |> validate_length(:reason, max: 500)
    |> unique_constraint([:blocker_id, :blocked_id])
  end
end
