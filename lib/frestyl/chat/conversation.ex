# In lib/frestyl/chat/conversation.ex
defmodule Frestyl.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Chat.Message

  schema "conversations" do
    field :title, :string
    field :last_message_at, :utc_datetime
    field :is_group, :boolean, default: false

    # Add a virtual field for last message display
    field :last_message, :any, virtual: true

    has_many :messages, Message
    many_to_many :participants, User, join_through: "conversation_participants"

    timestamps()
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :last_message_at, :is_group])
    |> validate_required([:last_message_at])
  end
end
