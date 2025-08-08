# lib/frestyl/story_engine/user_story_preferences.ex - Move schema to separate file FIRST
defmodule Frestyl.StoryEngine.UserStoryPreferences do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_story_preferences" do
    field :user_id, :id
    field :preferred_formats, {:array, :string}, default: []
    field :recent_intents, {:array, :string}, default: []
    field :quick_access_formats, {:array, :string}, default: []
    field :collaboration_preferences, :map, default: %{}
    field :ai_assistance_preferences, :map, default: %{}
    field :format_usage_stats, :map, default: %{}
    field :last_used_intent, :string
    field :story_completion_rate, :float, default: 0.0

    timestamps()
  end

  def changeset(preferences, attrs) do
    preferences
    |> cast(attrs, [
      :user_id, :preferred_formats, :recent_intents, :quick_access_formats,
      :collaboration_preferences, :ai_assistance_preferences, :format_usage_stats,
      :last_used_intent, :story_completion_rate
    ])
    |> validate_required([:user_id])
    |> validate_number(:story_completion_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint(:user_id)
  end
end
