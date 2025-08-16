# lib/frestyl/content_editing/clip.ex
defmodule Frestyl.ContentEditing.Clip do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "editing_clips" do
    field :name, :string
    field :media_type, :string # video, audio, image, text
    field :duration, :integer # in milliseconds
    field :start_offset, :integer, default: 0 # trim start
    field :end_offset, :integer, default: 0 # trim end
    field :speed, :float, default: 1.0
    field :volume, :float, default: 1.0
    field :opacity, :float, default: 1.0
    field :position_x, :float, default: 0.0
    field :position_y, :float, default: 0.0
    field :scale_x, :float, default: 1.0
    field :scale_y, :float, default: 1.0
    field :rotation, :float, default: 0.0
    field :enabled, :boolean, default: true
    field :locked, :boolean, default: false
    field :metadata, :map, default: %{}
    field :thumbnail_url, :string

    belongs_to :project, Frestyl.ContentEditing.Project
    belongs_to :track, Frestyl.ContentEditing.Track
    belongs_to :media_file, Frestyl.Media.MediaFile
    belongs_to :creator, Frestyl.Accounts.User

    has_many :timeline_entries, Frestyl.ContentEditing.Timeline
    has_many :effects, Frestyl.ContentEditing.Effect, where: [target_type: "clip"]

    timestamps()
  end

  def changeset(clip, attrs) do
    clip
    |> cast(attrs, [:name, :media_type, :duration, :start_offset, :end_offset, :speed,
                    :volume, :opacity, :position_x, :position_y, :scale_x, :scale_y,
                    :rotation, :enabled, :locked, :metadata, :thumbnail_url,
                    :project_id, :track_id, :media_file_id, :creator_id])
    |> validate_required([:name, :media_type, :duration, :project_id, :creator_id])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:media_type, ~w(video audio image text))
    |> validate_number(:duration, greater_than: 0)
    |> validate_number(:start_offset, greater_than_or_equal_to: 0)
    |> validate_number(:end_offset, greater_than_or_equal_to: 0)
    |> validate_number(:speed, greater_than: 0.0, less_than_or_equal_to: 10.0)
    |> validate_number(:volume, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 2.0)
    |> validate_number(:opacity, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:scale_x, greater_than: 0.0)
    |> validate_number(:scale_y, greater_than: 0.0)
    |> validate_offsets()
  end

  defp validate_offsets(changeset) do
    duration = get_field(changeset, :duration) || 0
    start_offset = get_change(changeset, :start_offset) || 0
    end_offset = get_change(changeset, :end_offset) || 0

    if start_offset + end_offset >= duration do
      add_error(changeset, :end_offset, "start and end offsets cannot exceed clip duration")
    else
      changeset
    end
  end
end
