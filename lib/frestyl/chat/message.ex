defmodule Frestyl.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    field :message_type, :string, default: "text"
    field :metadata, :map, default: %{}

    has_many :attachments, Frestyl.Chat.Attachment
    has_many :reactions, Frestyl.Chat.Reaction

    belongs_to :user, Frestyl.Accounts.User
    belongs_to :conversation, Frestyl.Chat.Conversation
    belongs_to :channel, Frestyl.Channels.Channel
    belongs_to :room, Frestyl.Channels.Room

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :user_id, :conversation_id, :channel_id, :room_id, :message_type, :metadata])
    |> validate_required([:content, :user_id])
    |> validate_length(:content, min: 1, max: 5000)
    |> validate_inclusion(:message_type, ["text", "file", "system", "media"])
    |> validate_at_least_one_recipient()
  end

  defp validate_at_least_one_recipient(changeset) do
    conversation_id = get_field(changeset, :conversation_id)
    channel_id = get_field(changeset, :channel_id)

    if is_nil(conversation_id) && is_nil(channel_id) do
      add_error(changeset, :base, "Message must have at least one recipient (conversation or channel)")
    else
      changeset
    end
  end
end
