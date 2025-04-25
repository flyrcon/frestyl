# lib/frestyl/streaming/room.ex

defmodule Frestyl.Streaming.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :name, :string
    field :description, :string
    field :status, :string, default: "active"
    field :max_participants, :integer, default: 50
    field :is_private, :boolean, default: false
    field :password_hash, :string

    belongs_to :creator, Frestyl.Accounts.User
    has_many :messages, Frestyl.Streaming.Message
    has_many :streams, Frestyl.Streaming.Stream

    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :description, :status, :max_participants, :is_private, :creator_id])
    |> validate_required([:name, :creator_id])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:status, ["active", "inactive", "archived"])
    |> validate_number(:max_participants, greater_than: 1, less_than_or_equal_to: 1000)
    |> maybe_put_password_hash(attrs)
  end

  defp maybe_put_password_hash(changeset, %{password: password}) when not is_nil(password) do
    changeset
    |> put_change(:is_private, true)
    |> put_change(:password_hash, Argon2.hash_pwd_salt(password))
  end

  defp maybe_put_password_hash(changeset, _), do: changeset
end
