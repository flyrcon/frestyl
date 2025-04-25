# lib/frestyl/channels/file_attachment.ex
defmodule Frestyl.Channels.FileAttachment do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Channels.{Room, Channel}

  schema "file_attachments" do
    field :filename, :string
    field :file_url, :string
    field :file_size, :integer
    field :mime_type, :string
    field :description, :string

    belongs_to :user, User
    belongs_to :room, Room
    belongs_to :channel, Channel

    timestamps()
  end

  def changeset(file_attachment, attrs) do
    file_attachment
    |> cast(attrs, [:filename, :file_url, :file_size, :mime_type, :description, :user_id, :room_id, :channel_id])
    |> validate_required([:filename, :file_url, :user_id])
    |> validate_attachment_location()
  end

  # Either room_id or channel_id must be set, but not both
  defp validate_attachment_location(changeset) do
    room_id = get_field(changeset, :room_id)
    channel_id = get_field(changeset, :channel_id)

    cond do
      room_id != nil && channel_id != nil ->
        add_error(changeset, :location, "File must be attached to either a room or a channel, not both")

      room_id == nil && channel_id == nil ->
        add_error(changeset, :location, "File must be attached to either a room or a channel")

      true ->
        changeset
    end
  end
end
