# lib/frestyl/chat/conversation_mute.ex
defmodule Frestyl.Chat.ConversationMute do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversation_mutes" do
    field :muted_until, :utc_datetime
    field :reason, :string

    belongs_to :conversation, Frestyl.Chat.Conversation
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(conversation_mute, attrs) do
    conversation_mute
    |> cast(attrs, [:muted_until, :reason, :conversation_id, :user_id])
    |> validate_required([:muted_until, :conversation_id, :user_id])
    |> unique_constraint([:conversation_id, :user_id])
  end
end
