# lib/frestyl/content_editing/track.ex
defmodule Frestyl.ContentEditing.Track do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "editing_tracks" do
    field :name, :string
    field :track_type, :string # video, audio, text, graphics, subtitles
    field :order, :integer
    field :enabled, :boolean, default: true
    field :muted, :boolean, default: false
    field :solo, :boolean, default: false
    field :locked, :boolean, default: false
    field :volume, :float, default: 1.0
    field :pan, :float, default: 0.0
    field :color, :string
    field :settings, :map, default: %{}
    field :effects_chain, {:array, :map}, default: []

    belongs_to :project, Frestyl.ContentEditing.Project

    has_many :clips, Frestyl.ContentEditing.Clip
    has_many :timeline_entries, Frestyl.ContentEditing.Timeline
    has_many :effects, Frestyl.ContentEditing.Effect, where: [target_type: "track"]

    timestamps()
  end

  def changeset(track, attrs) do
    track
    |> cast(attrs, [:name, :track_type, :order, :enabled, :muted, :solo, :locked,
                    :volume, :pan, :color, :settings, :effects_chain, :project_id])
    |> validate_required([:name, :track_type, :order, :project_id])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:track_type, ~w(video audio text graphics subtitles))
    |> validate_number(:order, greater_than: 0)
    |> validate_number(:volume, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 2.0)
    |> validate_number(:pan, greater_than_or_equal_to: -1.0, less_than_or_equal_to: 1.0)
    |> unique_constraint([:project_id, :order])
  end
end
