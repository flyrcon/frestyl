defmodule Frestyl.AIAssistant.Interaction do
  @moduledoc """
  Schema for AI assistant interactions with users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_interactions" do
    field :user_id, :id
    field :flow_type, :string  # onboarding, recommendation, assistance, etc.
    field :status, :string     # started, in_progress, completed, etc.
    field :responses, :map     # User responses during interaction
    field :metadata, :map      # Additional context for the interaction

    timestamps()
  end

  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:user_id, :flow_type, :status, :responses, :metadata])
    |> validate_required([:user_id, :flow_type, :status])
  end
end

defmodule Frestyl.AIAssistant.UserPreference do
  @moduledoc """
  Schema for storing user preferences identified by the AI assistant.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_preferences" do
    field :user_id, :id
    field :content_preferences, {:array, :string}  # Types of content user is interested in
    field :feature_preferences, {:array, :string}  # Features the user prioritizes
    field :experience_level, :string               # beginner, intermediate, advanced
    field :guidance_preference, :string            # guided, self_directed, balanced
    field :usage_frequency, :string                # daily, weekly, monthly, occasional
    field :last_updated, :utc_datetime

    timestamps()
  end

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [:user_id, :content_preferences, :feature_preferences, :experience_level, :guidance_preference, :usage_frequency])
    |> validate_required([:user_id])
    |> put_change(:last_updated, DateTime.utc_now())
  end
end

defmodule Frestyl.AIAssistant.Recommendation do
  @moduledoc """
  Schema for AI-generated recommendations for users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_recommendations" do
    field :user_id, :id
    field :category, :string        # channel_setup, content, feature, etc.
    field :title, :string           # Short title for the recommendation
    field :description, :string     # Detailed description
    field :relevance_score, :float  # How relevant this recommendation is (0.0-1.0)
    field :status, :string          # active, dismissed, completed
    field :dismissed_at, :utc_datetime
    field :completed_at, :utc_datetime

    timestamps()
  end

  def changeset(recommendation, attrs) do
    recommendation
    |> cast(attrs, [:user_id, :category, :title, :description, :relevance_score, :status, :dismissed_at, :completed_at])
    |> validate_required([:user_id, :category, :title, :description, :relevance_score, :status])
  end
end
