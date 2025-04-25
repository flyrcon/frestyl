# lib/frestyl/streaming/stream.ex

defmodule Frestyl.Streaming.Stream do
  use Ecto.Schema
  import Ecto.Changeset

  schema "streams" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "active"
    field :stream_key, :string
    field :ended_at, :utc_datetime

    belongs_to :room, Frestyl.Streaming.Room
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(stream, attrs) do
    stream
    |> cast(attrs, [:title, :description, :status, :room_id, :user_id, :ended_at])
    |> validate_required([:title, :room_id, :user_id])
    |> validate_length(:title, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:status, ["active", "ended", "paused"])
    |> maybe_generate_stream_key()
  end

  defp maybe_generate_stream_key(changeset) do
    if is_nil(get_field(changeset, :stream_key)) do
      put_change(changeset, :stream_key, generate_stream_key())
    else
      changeset
    end
  end

  defp generate_stream_key do
    :crypto.strong_rand_bytes(24)
    |> Base.url_encode64(padding: false)
  end
end
