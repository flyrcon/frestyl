# lib/frestyl/streaming/message.ex

defmodule Frestyl.Streaming.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    field :type, :string, default: "text"

    belongs_to :room, Frestyl.Streaming.Room
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :type, :room_id, :user_id])
    |> validate_required([:content, :room_id, :user_id])
    |> validate_length(:content, min: 1, max: 2000)
    |> validate_inclusion(:type, ["text", "media", "system"])
  end
end
