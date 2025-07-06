# lib/frestyl/chat/conversation.ex
defmodule Frestyl.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Chat.Message

  schema "conversations" do
    field :title, :string
    field :type, :string  # "direct", "group", "channel"
    field :context, :string  # "portfolio", "session", "service", "channel", "lab", "general"
    field :context_id, :integer  # ID of the context object (portfolio_id, session_id, etc.)
    field :metadata, :map, default: %{}
    field :last_message_at, :utc_datetime
    field :is_group, :boolean, default: false
    field :is_archived, :boolean, default: false

    # Use belongs_to association (this creates last_message_id automatically)
    belongs_to :last_message, Frestyl.Chat.Message

    # Use a different name for the virtual field to avoid conflict
    field :last_message_data, :any, virtual: true

    has_many :messages, Message

    # Choose ONE of these participant associations (not both):
    # Option 1: Use the join table approach (recommended for your existing Chat module)
    has_many :participants, Frestyl.Chat.ConversationParticipant
    has_many :users, through: [:participants, :user]

    # Option 2: Direct many_to_many (remove the lines above if using this)
    # many_to_many :participants, User, join_through: "conversation_participants"

    timestamps()
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :type, :context, :context_id, :metadata, :last_message_at, :last_message_id, :is_group, :is_archived])
    |> validate_required([:last_message_at])
    |> validate_required([:type])
    |> validate_inclusion(:type, ["direct", "group", "channel"])
    |> validate_inclusion(:context, ["portfolio", "session", "service", "channel", "lab", "general"])
  end
end
