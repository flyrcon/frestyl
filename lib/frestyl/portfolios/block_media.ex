# lib/frestyl/portfolios/block_media.ex
defmodule Frestyl.Portfolios.BlockMedia do
  @moduledoc """
  Join table for content blocks and media with granular attachment context.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "portfolio_block_media" do
    field :attachment_type, Ecto.Enum, values: [
      :primary_image, :gallery_item, :background_video, :demo_recording,
      :process_diagram, :result_screenshot, :testimonial_photo, :skill_certificate,
      :hover_preview, :click_demo, :streaming_thumbnail, :service_preview
    ]

    field :display_config, :map, default: %{}
    field :interaction_triggers, {:array, :string}, default: []
    field :position_in_block, :integer, default: 0
    field :alt_text, :string
    field :caption, :string

    belongs_to :content_block, Frestyl.Portfolios.ContentBlock
    belongs_to :media_file, Frestyl.Portfolios.PortfolioMedia

    timestamps()
  end

  def changeset(block_media, attrs) do
    block_media
    |> cast(attrs, [
      :attachment_type, :display_config, :interaction_triggers, :position_in_block,
      :alt_text, :caption, :content_block_id, :media_file_id
    ])
    |> validate_required([:attachment_type, :content_block_id, :media_file_id])
    |> validate_inclusion(:attachment_type, [
      :primary_image, :gallery_item, :background_video, :demo_recording,
      :process_diagram, :result_screenshot, :testimonial_photo, :skill_certificate,
      :hover_preview, :click_demo, :streaming_thumbnail, :service_preview
    ])
  end
end
