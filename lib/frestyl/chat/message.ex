defmodule Frestyl.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Channels.Channel

  schema "messages" do
    field :content, :string
    field :message_type, :string, default: "text" # text, image, file, system
    field :metadata, :map, default: %{}
    field :is_edited, :boolean, default: false
    field :is_deleted, :boolean, default: false

    belongs_to :user, User
    belongs_to :channel, Channel
    belongs_to :conversation, Frestyl.Chat.Conversation, on_replace: :nilify

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :message_type, :metadata, :user_id, :channel_id, :conversation_id])
    |> validate_required([:content, :user_id])
    |> validate_at_least_one_destination()
    |> validate_inclusion(:message_type, ["text", "image", "file", "system"])
    |> validate_length(:content, max: 10000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:conversation_id)
  end

  @doc """
  Changeset for editing a message.
  """
  def edit_changeset(message, attrs) do
    message
    |> cast(attrs, [:content])
    |> validate_required([:content])
    |> validate_length(:content, max: 10000)
    |> put_change(:is_edited, true)
  end

  @doc """
  Marks a message as deleted.
  """
  def delete_changeset(message) do
    change(message, is_deleted: true, content: "[This message was deleted]")
  end

  # Either channel_id or conversation_id must be set
  defp validate_at_least_one_destination(changeset) do
    channel_id = get_field(changeset, :channel_id)
    conversation_id = get_field(changeset, :conversation_id)

    if is_nil(channel_id) && is_nil(conversation_id) do
      add_error(changeset, :base, "Message must be sent to either a channel or a conversation")
    else
      changeset
    end
  end
end
