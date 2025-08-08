# lib/frestyl/voice_sketch/session.ex
defmodule Frestyl.VoiceSketch.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "voice_sketch_sessions" do
    field :title, :string
    field :description, :string
    field :voice_recording_url, :string
    field :voice_recording_duration, :integer
    field :audio_segments, :map, default: %{}
    field :canvas_data, :map, default: %{}
    field :canvas_dimensions, :map, default: %{width: 800, height: 600}
    field :drawing_layers, :map, default: %{}
    field :sync_markers, :map, default: %{}
    field :timeline_data, :map, default: %{}
    field :export_settings, :map, default: %{
      video_quality: "HD",
      frame_rate: 24,
      audio_quality: "high"
    }
    field :collaboration_enabled, :boolean, default: false
    field :collaborators, {:array, :id}, default: []
    field :real_time_enabled, :boolean, default: true
    field :status, :string, default: "draft"
    field :processing_progress, :integer, default: 0
    field :export_url, :string
    field :thumbnail_url, :string

    belongs_to :story, Frestyl.Stories.EnhancedStoryStructure, foreign_key: :story_id
    belongs_to :creator, Frestyl.Accounts.User, foreign_key: :creator_id, type: :id
    has_many :strokes, Frestyl.VoiceSketch.Stroke, foreign_key: :session_id

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :title, :description, :voice_recording_url, :voice_recording_duration,
      :audio_segments, :canvas_data, :canvas_dimensions, :drawing_layers,
      :sync_markers, :timeline_data, :export_settings, :collaboration_enabled,
      :collaborators, :real_time_enabled, :status, :processing_progress,
      :export_url, :thumbnail_url, :story_id, :creator_id
    ])
    |> validate_required([:title, :creator_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_inclusion(:status, ["draft", "recording", "processing", "complete", "error"])
    |> validate_number(:processing_progress, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:story_id)
    |> foreign_key_constraint(:creator_id)
  end

  def recording_changeset(session, attrs) do
    session
    |> changeset(attrs)
    |> put_change(:status, "recording")
  end

  def complete_changeset(session, attrs) do
    session
    |> changeset(attrs)
    |> put_change(:status, "complete")
    |> put_change(:processing_progress, 100)
  end
end
