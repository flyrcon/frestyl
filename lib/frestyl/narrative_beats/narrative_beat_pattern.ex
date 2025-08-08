# lib/frestyl/narrative_beats/narrative_beat_pattern.ex
defmodule Frestyl.NarrativeBeats.NarrativeBeatPattern do
  @moduledoc """
  Beat machine patterns specifically created for Narrative Beats sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "narrative_beat_patterns" do
    field :pattern_name, :string
    field :story_context, :string
    field :pattern_data, :map, default: %{}
    field :steps, :integer, default: 16
    field :tracks, :map, default: %{}
    field :is_active, :boolean, default: false

    belongs_to :narrative_beats_session, Frestyl.NarrativeBeats.Session

    timestamps()
  end

  def changeset(pattern, attrs) do
    pattern
    |> cast(attrs, [
      :pattern_name, :story_context, :pattern_data, :steps,
      :tracks, :is_active, :narrative_beats_session_id
    ])
    |> validate_required([:pattern_name, :narrative_beats_session_id])
    |> validate_length(:pattern_name, min: 1, max: 100)
    |> validate_number(:steps, greater_than: 0, less_than: 65) # Max 64 steps
    |> foreign_key_constraint(:narrative_beats_session_id)
  end
end
