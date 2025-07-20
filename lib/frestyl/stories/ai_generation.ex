# lib/frestyl/stories/ai_generation.ex (corrected)
defmodule Frestyl.Stories.AIGeneration do
  @moduledoc """
  Schema for tracking AI-generated content and suggestions
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "ai_generations" do
    field :generation_type, :string
    field :prompt, :string
    field :result, :map
    field :context, :map
    field :status, :string, default: "pending"
    field :feedback, :string
    field :usage_metadata, :map

    # Enhanced story structures use binary_id
    belongs_to :story, Frestyl.Stories.EnhancedStoryStructure, foreign_key: :story_id, type: :binary_id
    # Users use regular id
    belongs_to :user, Frestyl.Accounts.User, foreign_key: :user_id, type: :id

    timestamps()
  end

  def changeset(ai_generation, attrs) do
    ai_generation
    |> cast(attrs, [:generation_type, :prompt, :result, :context, :status, :feedback, :usage_metadata, :story_id, :user_id])
    |> validate_required([:generation_type, :prompt, :story_id, :user_id])
    |> validate_inclusion(:generation_type, ["text", "image", "suggestion", "analysis", "character", "world_building"])
    |> validate_inclusion(:status, ["pending", "completed", "failed", "accepted", "rejected"])
    |> foreign_key_constraint(:story_id)
    |> foreign_key_constraint(:user_id)
  end
end
