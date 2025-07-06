# lib/frestyl/chat/participant.ex
defmodule Frestyl.Chat.Participant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "participants" do
    field :role, :string, default: "member"  # "member", "admin", "moderator"
    field :joined_at, :utc_datetime
    field :last_read_at, :utc_datetime
    field :unread_count, :integer, default: 0
    field :notifications_enabled, :boolean, default: true

    belongs_to :conversation, Frestyl.Chat.Conversation
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:role, :joined_at, :last_read_at, :unread_count, :notifications_enabled, :conversation_id, :user_id])
    |> validate_required([:conversation_id, :user_id])
    |> validate_inclusion(:role, ["member", "admin", "moderator"])
    |> unique_constraint([:conversation_id, :user_id])
  end
end
