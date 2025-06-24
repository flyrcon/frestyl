# lib/frestyl/stories/media_binding.ex
defmodule Frestyl.Stories.MediaBinding do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_bindings" do
    field :binding_type, Ecto.Enum, values: [
      :background_audio, :narration_sync, :hover_audio, :click_video,
      :modal_image, :inline_video, :code_demo, :document_overlay, :hotspot_trigger
    ]
    field :target_selector, :string  # ".bullet-point-3", "#intro-text", etc.
    field :sync_data, :map, default: %{}
    field :trigger_config, :map, default: %{}
    field :display_config, :map, default: %{}

    belongs_to :content_block, Frestyl.Stories.ContentBlock
    belongs_to :media_file, Frestyl.Portfolios.PortfolioMedia

    timestamps()
  end

  def changeset(media_binding, attrs) do
    media_binding
    |> cast(attrs, [:binding_type, :target_selector, :sync_data, :trigger_config, :display_config, :content_block_id, :media_file_id])
    |> validate_required([:binding_type, :content_block_id, :media_file_id])
    |> unique_constraint([:content_block_id, :target_selector, :binding_type])
  end
end
