defmodule Frestyl.Content.DocumentBlock do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "document_blocks" do
    field :block_type, :string
    field :content, :string
    field :position, :integer
    field :metadata, :map, default: %{}

    belongs_to :document, Frestyl.Content.Document, foreign_key: :document_id, type: :binary_id
    has_many :media_attachments, Frestyl.Content.MediaAttachment, foreign_key: :block_id

    timestamps()
  end

  def changeset(block, attrs) do
    block
    |> cast(attrs, [:block_type, :content, :position, :metadata, :document_id])
    |> validate_required([:block_type, :position, :document_id])
    |> validate_inclusion(:block_type, [
      "title", "subtitle", "paragraph", "heading", "list", "quote", "code",
      "image", "audio", "video", "media_gallery", "call_to_action",
      "scene_heading", "action", "character", "dialogue", "parenthetical",
      "stanza", "stanza_break", "chapter_number", "chapter_title"
    ])
  end
end
