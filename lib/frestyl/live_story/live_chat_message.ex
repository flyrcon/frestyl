# lib/frestyl/live_story/live_chat_message.ex
defmodule Frestyl.LiveStory.LiveChatMessage do
  @moduledoc """
  Live chat messages during story sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "live_chat_messages" do
    field :user_identifier, :string
    field :message_content, :string
    field :message_type, :string, default: "chat"
    field :timestamp, :utc_datetime
    field :is_highlighted, :boolean, default: false
    field :is_moderated, :boolean, default: false
    field :moderation_reason, :string

    belongs_to :live_story_session, Frestyl.LiveStory.Session
    belongs_to :user, User, foreign_key: :user_id, type: :id
    belongs_to :reply_to_message, __MODULE__, foreign_key: :reply_to_message_id

    has_many :replies, __MODULE__, foreign_key: :reply_to_message_id

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :user_identifier, :message_content, :message_type, :timestamp,
      :is_highlighted, :is_moderated, :moderation_reason,
      :live_story_session_id, :user_id, :reply_to_message_id
    ])
    |> validate_required([:message_content, :timestamp, :live_story_session_id])
    |> validate_length(:message_content, min: 1, max: 500)
    |> validate_inclusion(:message_type, [
      "chat", "system", "moderator", "narrator", "announcement"
    ])
    |> foreign_key_constraint(:live_story_session_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:reply_to_message_id)
  end
end
