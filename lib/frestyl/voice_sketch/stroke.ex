# lib/frestyl/voice_sketch/stroke.ex
defmodule Frestyl.VoiceSketch.Stroke do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "voice_sketch_strokes" do
    field :stroke_data, :map
    field :tool_type, :string
    field :color, :string
    field :stroke_width, :float
    field :layer_id, :string
    field :start_timestamp, :integer
    field :end_timestamp, :integer
    field :audio_timestamp, :integer
    field :stroke_order, :integer
    field :is_deleted, :boolean, default: false

    belongs_to :session, Frestyl.VoiceSketch.Session, foreign_key: :session_id
    belongs_to :user, Frestyl.Accounts.User, foreign_key: :user_id, type: :id

    timestamps()
  end

  def changeset(stroke, attrs) do
    stroke
    |> cast(attrs, [
      :stroke_data, :tool_type, :color, :stroke_width, :layer_id,
      :start_timestamp, :end_timestamp, :audio_timestamp, :stroke_order,
      :is_deleted, :session_id, :user_id
    ])
    |> validate_required([
      :stroke_data, :tool_type, :color, :stroke_width, :layer_id,
      :start_timestamp, :end_timestamp, :stroke_order, :session_id, :user_id
    ])
    |> validate_inclusion(:tool_type, ["pen", "brush", "eraser", "highlighter", "pencil"])
    |> validate_number(:stroke_width, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:start_timestamp, greater_than_or_equal_to: 0)
    |> validate_number(:end_timestamp, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:user_id)
  end
end
