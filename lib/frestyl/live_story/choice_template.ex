# lib/frestyl/live_story/choice_template.ex
defmodule Frestyl.LiveStory.ChoiceTemplate do
  @moduledoc """
  Pre-defined choice patterns for quick story branching.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "choice_templates" do
    field :template_name, :string
    field :description, :string
    field :choice_pattern, :map, default: %{}
    field :genre_tags, {:array, :string}, default: []
    field :difficulty_level, :string, default: "medium"
    field :usage_count, :integer, default: 0
    field :community_rating, :float, default: 0.0
    field :is_public, :boolean, default: true

    belongs_to :created_by, User, foreign_key: :created_by_id, type: :id

    timestamps()
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :template_name, :description, :choice_pattern, :genre_tags,
      :difficulty_level, :usage_count, :community_rating, :is_public,
      :created_by_id
    ])
    |> validate_required([:template_name, :created_by_id])
    |> validate_length(:template_name, min: 1, max: 100)
    |> validate_inclusion(:difficulty_level, ["easy", "medium", "hard"])
    |> validate_number(:usage_count, greater_than_or_equal_to: 0)
    |> validate_number(:community_rating, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 5.0)
    |> foreign_key_constraint(:created_by_id)
  end
end
