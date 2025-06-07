defmodule Frestyl.Content.MediaAttachment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "media_attachments" do
    field :attachment_type, :string
    field :position, :map
    field :relationship, :string
    field :metadata, :map, default: %{}

    belongs_to :block, Frestyl.Content.DocumentBlock, foreign_key: :block_id, type: :binary_id
    belongs_to :media_file, Frestyl.Media.MediaFile, foreign_key: :media_file_id, type: :integer

    timestamps()
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:attachment_type, :position, :relationship, :metadata, :block_id, :media_file_id])
    |> validate_required([:attachment_type, :position, :block_id, :media_file_id])
    |> validate_inclusion(:attachment_type, ["image", "audio", "video", "document", "code"])
    |> validate_inclusion(:relationship, ["illustrates", "narrates", "supports", "contrasts", "examples"])
  end
end
