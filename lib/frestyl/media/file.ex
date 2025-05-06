# lib/frestyl/media/file.ex
defmodule Frestyl.Media.File do
  use Ecto.Schema
  import Ecto.Changeset

  schema "files" do
    field :filename, :string
    field :content_type, :string
    field :file_size, :integer
    field :file_path, :string
    field :url, :string
    field :storage_type, :string, default: "local"
    field :status, :string, default: "active"

    belongs_to :user, Frestyl.Accounts.User
    belongs_to :channel, Frestyl.Channels.Channel

    timestamps()
  end

  @doc false
  def changeset(file, attrs) do
    file
    |> cast(attrs, [:filename, :content_type, :file_size, :file_path, :url,
                    :storage_type, :status, :user_id, :channel_id])
    |> validate_required([:filename, :content_type, :file_size, :file_path,
                          :url, :user_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:channel_id)
  end
end
