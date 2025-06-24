defmodule Frestyl.Stories.Story do
  use Ecto.Schema           # Provides schema/2 macro
  import Ecto.Changeset

  schema "stories" do
    # Account-based ownership (replaces direct user ownership)
    belongs_to :account, Frestyl.Accounts.Account
    belongs_to :created_by, Frestyl.Accounts.User

    # Story classification
    field :story_type, Ecto.Enum, values: [
      :personal_narrative,    # Life stories, personal journeys
      :professional_showcase, # Career portfolios, work highlights
      :brand_story,          # Company narratives, product stories
      :case_study,           # Problem-solution narratives
      :creative_portfolio,   # Art, design, creative work
      :educational_content   # Tutorials, lessons, guides
    ]

    # Ownership & sharing
    field :ownership_type, Ecto.Enum, values: [:personal, :work, :shared]
    field :sharing_model, Ecto.Enum, values: [:private, :team, :public, :link_only]

    # Story-specific metadata
    field :narrative_structure, :string  # "hero_journey", "case_study", "chronological"
    field :target_audience, :string
    field :story_tags, {:array, :string}
    field :estimated_read_time, :integer

    # Collaboration settings
    field :collaboration_settings, :map
    field :cross_account_permissions, :map

    has_many :story_chapters, Frestyl.Stories.Chapter
    has_many :story_collaborations, Frestyl.Stories.Collaboration
    has_many :story_analytics, Frestyl.Stories.Analytics

    timestamps()
  end
end
