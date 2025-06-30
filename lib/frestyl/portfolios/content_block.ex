# lib/frestyl/portfolios/content_block.ex
defmodule Frestyl.Portfolios.ContentBlock do
  @moduledoc """
  Unified content blocks for both portfolio sections and story chapters.
  Supports media attachments, monetization, streaming, and interactive bindings.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "portfolio_content_blocks" do
    field :block_uuid, :string
    field :block_type, Ecto.Enum, values: [
      # Portfolio content blocks
      :text, :responsibility, :achievement, :skill_item, :education_entry,
      :project_card, :service_offering, :testimonial_item, :experience_entry,

      # Story content blocks (merged from Stories.ContentBlock)
      :image, :video, :gallery, :timeline, :card_grid,
      :bullet_list, :quote, :code_showcase, :media_showcase,

      # Monetization blocks
      :pricing_tier, :booking_widget, :service_package, :hourly_rate,
      :consultation_offer, :payment_button,

      # Streaming blocks
      :live_session_embed, :scheduled_stream, :recording_showcase,
      :availability_calendar, :stream_archive,

      # Layout blocks
      :grid_container, :timeline_item, :card_stack, :feature_highlight,
      :stats_display
    ]

    field :position, :integer
    field :content_data, :map, default: %{}
    field :layout_config, :map, default: %{}

    # Portfolio-specific configs
    field :monetization_config, :map, default: %{}
    field :streaming_config, :map, default: %{}
    field :visibility_rules, :map, default: %{}

    # Story-specific configs (merged from Stories.ContentBlock)
    field :interaction_config, :map, default: %{}

    # Limits and permissions
    field :media_limit, :integer, default: 3
    field :requires_subscription_tier, :string
    field :is_premium_feature, :boolean, default: false

    # Dual relationships - can belong to either portfolio section OR story chapter
    belongs_to :portfolio_section, Frestyl.Portfolios.PortfolioSection, on_replace: :nilify
    belongs_to :chapter, Frestyl.Stories.Chapter, on_replace: :nilify

    # Portfolio media relationships
    has_many :block_media, Frestyl.Portfolios.BlockMedia, foreign_key: :content_block_id
    has_many :portfolio_media_files, through: [:block_media, :media_file]

    # Story media relationships (merged from Stories.MediaBinding)
    has_many :media_bindings, Frestyl.Stories.MediaBinding, foreign_key: :content_block_id
    has_many :story_media_files, through: [:media_bindings, :media_file]

    # Monetization and streaming
    has_many :monetization_settings, Frestyl.Portfolios.MonetizationSetting, foreign_key: :content_block_id
    has_many :streaming_integrations, Frestyl.Portfolios.StreamingIntegration, foreign_key: :content_block_id

    timestamps()
  end

  def changeset(content_block, attrs) do
    content_block
    |> cast(attrs, [
      :block_uuid, :block_type, :position, :content_data, :layout_config,
      :monetization_config, :streaming_config, :visibility_rules, :interaction_config,
      :media_limit, :requires_subscription_tier, :is_premium_feature,
      :portfolio_section_id, :chapter_id
    ])
    |> validate_required([:block_uuid, :block_type, :position])
    |> validate_parent_relationship()
    |> validate_media_limits()
    |> validate_subscription_requirements()
    |> unique_constraint([:block_uuid])
  end

  # Ensure block belongs to either portfolio section OR chapter, not both
  defp validate_parent_relationship(changeset) do
    portfolio_section_id = get_field(changeset, :portfolio_section_id)
    chapter_id = get_field(changeset, :chapter_id)

    cond do
      portfolio_section_id && chapter_id ->
        add_error(changeset, :base, "Block cannot belong to both portfolio section and story chapter")

      portfolio_section_id || chapter_id ->
        changeset

      true ->
        add_error(changeset, :base, "Block must belong to either a portfolio section or story chapter")
    end
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

  # ============================================================================
  # QUERY FUNCTIONS (merged from Stories.ContentBlock)
  # ============================================================================

  def for_portfolio_section(query \\ __MODULE__, section_id) do
    from c in query, where: c.portfolio_section_id == ^section_id
  end

  def for_chapter(query \\ __MODULE__, chapter_id) do
    from c in query, where: c.chapter_id == ^chapter_id
  end

  def by_type(query \\ __MODULE__, block_type) do
    from c in query, where: c.block_type == ^block_type
  end

  def ordered(query \\ __MODULE__) do
    from c in query, order_by: [asc: c.position]
  end

  def with_media(query \\ __MODULE__) do
    from c in query,
      left_join: bm in assoc(c, :block_media),
      left_join: mb in assoc(c, :media_bindings),
      preload: [block_media: bm, media_bindings: mb]
  end

  # ============================================================================
  # BUSINESS LOGIC FUNCTIONS
  # ============================================================================

  def create_for_portfolio_section(section_id, attrs) do
    %__MODULE__{portfolio_section_id: section_id}
    |> changeset(attrs)
    |> Frestyl.Repo.insert()
  end

  def create_for_chapter(chapter_id, attrs) do
    %__MODULE__{chapter_id: chapter_id}
    |> changeset(attrs)
    |> Frestyl.Repo.insert()
  end

  def list_for_section(section_id) do
    __MODULE__
    |> for_portfolio_section(section_id)
    |> ordered()
    |> with_media()
    |> Frestyl.Repo.all()
  end

  def list_for_chapter(chapter_id) do
    __MODULE__
    |> for_chapter(chapter_id)
    |> ordered()
    |> with_media()
    |> Frestyl.Repo.all()
  end

  def get_with_media!(id) do
    __MODULE__
    |> with_media()
    |> Frestyl.Repo.get!(id)
  end

  def update_position(content_block, new_position) do
    content_block
    |> changeset(%{position: new_position})
    |> Frestyl.Repo.update()
  end

  def duplicate(content_block, target_section_id \\ nil, target_chapter_id \\ nil) do
    new_attrs = %{
      block_uuid: Ecto.UUID.generate(),
      block_type: content_block.block_type,
      position: content_block.position + 1,
      content_data: content_block.content_data,
      layout_config: content_block.layout_config,
      interaction_config: content_block.interaction_config,
      media_limit: content_block.media_limit,
      portfolio_section_id: target_section_id || content_block.portfolio_section_id,
      chapter_id: target_chapter_id || content_block.chapter_id
    }

    %__MODULE__{}
    |> changeset(new_attrs)
    |> Frestyl.Repo.insert()
  end

  # ============================================================================
  # MEDIA MANAGEMENT
  # ============================================================================

  def add_media_binding(content_block, media_file, binding_config) do
    # For story-style media bindings with interaction configs
    Frestyl.Stories.MediaBinding.changeset(%Frestyl.Stories.MediaBinding{}, %{
      content_block_id: content_block.id,
      media_file_id: media_file.id,
      binding_type: binding_config.type,
      target_selector: binding_config.selector,
      sync_data: binding_config.sync_data || %{},
      trigger_config: binding_config.trigger_config || %{},
      display_config: binding_config.display_config || %{}
    })
    |> Frestyl.Repo.insert()
  end

  def add_portfolio_media(content_block, media_file) do
    # For simple portfolio media attachments
    Frestyl.Portfolios.BlockMedia.changeset(%Frestyl.Portfolios.BlockMedia{}, %{
      content_block_id: content_block.id,
      media_file_id: media_file.id
    })
    |> Frestyl.Repo.insert()
  end

  # ============================================================================
  # CONTENT TYPE HELPERS
  # ============================================================================

  def portfolio_block_types do
    [
      :text, :responsibility, :achievement, :skill_item, :education_entry,
      :project_card, :service_offering, :testimonial_item, :experience_entry,
      :pricing_tier, :booking_widget, :service_package, :hourly_rate,
      :consultation_offer, :payment_button, :live_session_embed,
      :scheduled_stream, :recording_showcase, :availability_calendar,
      :stream_archive
    ]
  end

  def story_block_types do
    [
      :text, :image, :video, :gallery, :timeline, :card_grid,
      :bullet_list, :quote, :code_showcase, :media_showcase,
      :grid_container, :timeline_item, :card_stack, :feature_highlight,
      :stats_display
    ]
  end

  def monetization_block_types do
    [
      :pricing_tier, :booking_widget, :service_package, :hourly_rate,
      :consultation_offer, :payment_button
    ]
  end

  def streaming_block_types do
    [
      :live_session_embed, :scheduled_stream, :recording_showcase,
      :availability_calendar, :stream_archive
    ]
  end

  def is_portfolio_block?(block_type) do
    block_type in portfolio_block_types()
  end

  def is_story_block?(block_type) do
    block_type in story_block_types()
  end

  def is_monetization_block?(block_type) do
    block_type in monetization_block_types()
  end

  def is_streaming_block?(block_type) do
    block_type in streaming_block_types()
  end
end
