# lib/frestyl/content_editing/timeline.ex
defmodule Frestyl.ContentEditing.Timeline do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "editing_timeline" do
    field :start_position, :integer # milliseconds from timeline start
    field :end_position, :integer # milliseconds from timeline start
    field :layer, :integer, default: 0 # for overlapping clips
    field :transition_in, :map # transition at start
    field :transition_out, :map # transition at end
    field :metadata, :map, default: %{}

    belongs_to :project, Frestyl.ContentEditing.Project
    belongs_to :track, Frestyl.ContentEditing.Track
    belongs_to :clip, Frestyl.ContentEditing.Clip
    belongs_to :user, Frestyl.Accounts.User # who placed it

    timestamps()
  end

  def changeset(timeline, attrs) do
    timeline
    |> cast(attrs, [:start_position, :end_position, :layer, :transition_in, :transition_out,
                    :metadata, :project_id, :track_id, :clip_id, :user_id])
    |> validate_required([:start_position, :end_position, :project_id, :track_id, :clip_id, :user_id])
    |> validate_number(:start_position, greater_than_or_equal_to: 0)
    |> validate_number(:end_position, greater_than: 0)
    |> validate_number(:layer, greater_than_or_equal_to: 0)
    |> validate_position_order()
    |> validate_timeline_conflicts()
  end

  defp validate_position_order(changeset) do
    start_pos = get_field(changeset, :start_position) || 0
    end_pos = get_field(changeset, :end_position) || 0

    if end_pos <= start_pos do
      add_error(changeset, :end_position, "must be greater than start position")
    else
      changeset
    end
  end

  defp validate_timeline_conflicts(changeset) do
    # This would check for overlapping clips on the same track/layer
    # Implementation would query existing timeline entries
    changeset
  end
end
