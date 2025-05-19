defmodule Frestyl.Channels.Message do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Channels.Room

  schema "messages" do
    field :content, :string
    # Remove the attachment_url field since it doesn't exist in the database
    field :message_type, :string, default: "text" # Options: "text", "file", "system"

    belongs_to :user, User
    belongs_to :room, Room

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :message_type, :user_id, :room_id]) # Remove attachment_url from here too
    |> validate_required([:content, :user_id, :room_id])
    |> validate_length(:content, min: 1, max: 5000)
  end
end
