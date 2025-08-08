# lib/frestyl/narrative_beats/ai_music_suggestion.ex
defmodule Frestyl.NarrativeBeats.AIMusicSuggestion do
  @moduledoc """
  AI-generated music suggestions for Narrative Beats sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ai_music_suggestions" do
    field :suggestion_type, :string
    field :context, :map, default: %{}
    field :suggestion_data, :map, default: %{}
    field :confidence_score, :float, default: 0.5
    field :status, :string, default: "pending"
    field :feedback, :string

    belongs_to :narrative_beats_session, Frestyl.NarrativeBeats.Session

    timestamps()
  end

  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [
      :suggestion_type, :context, :suggestion_data, :confidence_score,
      :status, :feedback, :narrative_beats_session_id
    ])
    |> validate_required([:suggestion_type, :narrative_beats_session_id])
    |> validate_inclusion(:suggestion_type, ["chord_progression", "melody", "rhythm", "arrangement", "instrumentation"])
    |> validate_inclusion(:status, ["pending", "accepted", "rejected", "modified"])
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> foreign_key_constraint(:narrative_beats_session_id)
  end
end
