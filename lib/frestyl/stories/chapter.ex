# lib/frestyl/stories/chapter.ex
defmodule Frestyl.Stories.Chapter do
  use Ecto.Schema
  import Ecto.Changeset

  schema "story_chapters" do
    field :title, :string
    field :chapter_type, Ecto.Enum, values: [
      :intro, :content, :media_showcase, :case_study_problem,
      :case_study_solution, :call_to_action, :conclusion
    ], default: :content
    field :content, :map, default: %{}
    field :position, :integer, default: 0
    field :visible, :boolean, default: true

    # Story-specific
    field :narrative_purpose, Ecto.Enum, values: [
      :hook, :context, :conflict, :journey, :resolution, :call_to_action
    ]
    field :emotional_tone, Ecto.Enum, values: [
      :inspiring, :analytical, :personal, :professional, :dramatic, :conversational
    ]

    field :interactive_elements, :map, default: %{}
    field :view_time_seconds, :integer, default: 0
    field :engagement_score, :decimal, default: Decimal.new("0.0")

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio

    timestamps()
  end

  def changeset(chapter, attrs) do
    chapter
    |> cast(attrs, [
      :title, :chapter_type, :content, :position, :visible,
      :narrative_purpose, :emotional_tone, :interactive_elements
    ])
    |> validate_required([:title, :portfolio_id])
    |> validate_length(:title, min: 1, max: 255)
  end
end
