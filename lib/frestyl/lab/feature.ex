# lib/frestyl/lab/feature.ex
defmodule Frestyl.Lab.Feature do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_features" do
    field :name, :string
    field :description, :string
    field :category, :string
    field :icon, :string
    field :min_tier, :string, default: "free"
    field :time_limit_minutes, :integer, default: 0
    field :is_active, :boolean, default: true
    field :display_order, :integer, default: 0
    field :estimated_duration, :string
    field :collaboration_type, :string # "solo", "collaborative", "async"
    field :complexity_level, :string, default: "beginner" # "beginner", "intermediate", "advanced"
    field :tags, {:array, :string}, default: []
    field :requirements, :map, default: %{} # Technical or skill requirements
    field :metadata, :map, default: %{} # Additional feature-specific data

    has_many :experiments, Frestyl.Lab.Experiment
    has_many :usage_records, Frestyl.Lab.Usage

    timestamps()
  end

  @doc false
  def changeset(feature, attrs) do
    feature
    |> cast(attrs, [
      :name, :description, :category, :icon, :min_tier, :time_limit_minutes,
      :is_active, :display_order, :estimated_duration, :collaboration_type,
      :complexity_level, :tags, :requirements, :metadata
    ])
    |> validate_required([:name, :description, :category])
    |> validate_inclusion(:min_tier, ["free", "pro", "premium"])
    |> validate_inclusion(:collaboration_type, ["solo", "collaborative", "async"])
    |> validate_inclusion(:complexity_level, ["beginner", "intermediate", "advanced"])
    |> validate_number(:time_limit_minutes, greater_than_or_equal_to: 0)
    |> validate_number(:display_order, greater_than_or_equal_to: 0)
  end
end
