# lib/frestyl/sessions/message.ex
defmodule Frestyl.Sessions.Message do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Sessions.Session
  alias Frestyl.Accounts.User

  schema "session_messages" do
    field :content, :string
    field :message_type, :string, default: "text"
    field :parent_id, :id

    belongs_to :session, Session
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :message_type, :session_id, :user_id, :parent_id])
    |> validate_required([:content, :session_id, :user_id])
    |> validate_length(:content, min: 1, max: 4000)
    |> validate_inclusion(:message_type, ["text", "system", "media"])
  end
end
