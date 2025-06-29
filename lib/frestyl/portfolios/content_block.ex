# lib/frestyl/portfolios/content_block.ex
defmodule Frestyl.Portfolios.ContentBlock do
  @moduledoc """
  Granular content blocks for portfolio sections with media and monetization support.
  Each block can have its own media attachments, pricing, and streaming integration.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "portfolio_content_blocks" do
    field :block_uuid, :string
    field :block_type, Ecto.Enum, values: [
      # Content blocks
      :text, :responsibility, :achievement, :skill_item, :education_entry,
      :project_card, :service_offering, :testimonial_item, :experience_entry,

      # Monetization blocks
      :pricing_tier, :booking_widget, :service_package, :hourly_rate,
      :consultation_offer, :payment_button,

      # Streaming blocks
      :live_session_embed, :scheduled_stream, :recording_showcase,
      :availability_calendar, :stream_archive,

      # Layout blocks
      :grid_container, :timeline_item, :card_stack, :feature_highlight,
      :stats_display, :media_gallery
    ]

    field :position, :integer
    field :content_data, :map, default: %{}
    field :layout_config, :map, default: %{}
    field :monetization_config, :map, default: %{}
    field :streaming_config, :map, default: %{}
    field :visibility_rules, :map, default: %{}
    field :interaction_config, :map, default: %{}

    # Limits and permissions
    field :media_limit, :integer, default: 3
    field :requires_subscription_tier, :string
    field :is_premium_feature, :boolean, default: false

    belongs_to :portfolio_section, Frestyl.Portfolios.PortfolioSection
    has_many :block_media, Frestyl.Portfolios.BlockMedia, foreign_key: :content_block_id
    has_many :media_files, through: [:block_media, :media_file]
    has_many :monetization_settings, Frestyl.Portfolios.MonetizationSetting, foreign_key: :content_block_id
    has_many :streaming_integrations, Frestyl.Portfolios.StreamingIntegration, foreign_key: :content_block_id

    timestamps()
  end

  def changeset(content_block, attrs) do
    content_block
    |> cast(attrs, [
      :block_uuid, :block_type, :position, :content_data, :layout_config,
      :monetization_config, :streaming_config, :visibility_rules, :interaction_config,
      :media_limit, :requires_subscription_tier, :is_premium_feature, :portfolio_section_id
    ])
    |> validate_required([:block_uuid, :block_type, :position, :portfolio_section_id])
    |> validate_media_limits()
    |> validate_subscription_requirements()
    |> unique_constraint([:block_uuid, :portfolio_section_id])
  end

  defp validate_media_limits(changeset) do
    media_limit = get_change(changeset, :media_limit) || get_field(changeset, :media_limit)

    if media_limit && media_limit > 10 do
      add_error(changeset, :media_limit, "cannot exceed 10 media attachments per block")
    else
      changeset
    end
  end

  defp validate_subscription_requirements(changeset) do
    is_premium = get_change(changeset, :is_premium_feature) || get_field(changeset, :is_premium_feature)
    required_tier = get_change(changeset, :requires_subscription_tier) || get_field(changeset, :requires_subscription_tier)

    if is_premium && is_nil(required_tier) do
      add_error(changeset, :requires_subscription_tier, "must be specified for premium features")
    else
      changeset
    end
  end
end
