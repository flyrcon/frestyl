# lib/frestyl/portfolios/streaming_integration.ex
defmodule Frestyl.Portfolios.StreamingIntegration do
  @moduledoc """
  Streaming and live session integration for content blocks.
  Connects portfolio content to the streaming system.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "portfolio_streaming_integrations" do
    field :integration_type, Ecto.Enum, values: [
      :live_session_embed, :scheduled_consultation, :recorded_demo,
      :interactive_walkthrough, :skill_demonstration, :portfolio_tour,
      :client_meeting, :workshop_session, :archive_showcase
    ]

    field :streaming_config, :map, default: %{}
    field :scheduling_config, :map, default: %{}
    field :access_rules, :map, default: %{}
    field :session_duration_minutes, :integer, default: 30
    field :requires_payment, :boolean, default: false
    field :is_public_stream, :boolean, default: true
    field :max_participants, :integer
    field :booking_buffer_minutes, :integer, default: 15

    # Integration with existing streaming system
    field :stream_session_id, :string
    field :calendar_integration_id, :string
    field :zoom_meeting_id, :string

    belongs_to :content_block, Frestyl.Portfolios.ContentBlock
    belongs_to :portfolio, Frestyl.Portfolios.Portfolio

    timestamps()
  end

  def changeset(streaming_integration, attrs) do
    streaming_integration
    |> cast(attrs, [
      :integration_type, :streaming_config, :scheduling_config, :access_rules,
      :session_duration_minutes, :requires_payment, :is_public_stream, :max_participants,
      :booking_buffer_minutes, :stream_session_id, :calendar_integration_id,
      :zoom_meeting_id, :content_block_id, :portfolio_id
    ])
    |> validate_required([:integration_type, :content_block_id, :portfolio_id])
    |> validate_number(:session_duration_minutes, greater_than: 0, less_than: 480)
    |> validate_number(:max_participants, greater_than: 0, less_than: 1000)
  end
end
