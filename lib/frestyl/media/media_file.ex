# lib/frestyl/media/media_file.ex
defmodule Frestyl.Media.MediaFile do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Channels.Channel

  schema "media_files" do
    field :filename, :string
    field :original_filename, :string
    field :content_type, :string
    field :file_size, :integer
    field :media_type, :string # "image", "video", "audio", "document"
    field :file_path, :string
    field :storage_type, :string, default: "local"
    field :status, :string, default: "active"
    field :title, :string
    field :description, :string
    field :metadata, :map, default: %{}
    field :duration, :integer
    field :width, :integer
    field :height, :integer
    field :thumbnail_url, :string

    belongs_to :user, User
    belongs_to :channel, Channel

    timestamps()
  end

  @required_fields [:filename, :original_filename, :content_type, :file_size,
                    :media_type, :file_path, :user_id]
  @optional_fields [:channel_id, :storage_type, :status, :title, :description,
                   :metadata, :duration, :width, :height, :thumbnail_url]

  def changeset(media_file, attrs) do
    media_file
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:channel_id)
    |> validate_inclusion(:media_type, ["image", "video", "audio", "document"])
    |> validate_inclusion(:storage_type, ["local", "s3"])
    |> validate_inclusion(:status, ["active", "processing", "error", "archived"])
  end
end
