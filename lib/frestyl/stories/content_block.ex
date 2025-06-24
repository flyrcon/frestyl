# lib/frestyl/stories/content_block.ex
defmodule Frestyl.Stories.ContentBlock do
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_blocks" do
    field :block_uuid, :string
    field :block_type, Ecto.Enum, values: [
      :text, :image, :video, :gallery, :timeline, :card_grid,
      :bullet_list, :quote, :code_showcase, :media_showcase
    ]
    field :position, :integer
    field :content_data, :map, default: %{}
    field :layout_config, :map, default: %{}
    field :interaction_config, :map, default: %{}

    belongs_to :chapter, Frestyl.Stories.Chapter
    has_many :media_bindings, Frestyl.Stories.MediaBinding
    has_many :media_files, through: [:media_bindings, :media_file]

    timestamps()
  end

  def changeset(content_block, attrs) do
    content_block
    |> cast(attrs, [:block_uuid, :block_type, :position, :content_data, :layout_config, :interaction_config, :chapter_id])
    |> validate_required([:block_uuid, :block_type, :position, :chapter_id])
    |> unique_constraint([:block_uuid])
  end
end
