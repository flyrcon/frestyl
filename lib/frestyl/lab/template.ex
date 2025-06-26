# lib/frestyl/lab/template.ex
defmodule Frestyl.Lab.Template do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_templates" do
    field :name, :string
    field :description, :string
    field :category, :string # "layout", "theme", "component", "full_portfolio"
    field :theme_name, :string # The actual theme identifier to use
    field :preview_url, :string
    field :min_tier, :string, default: "pro"
    field :is_active, :boolean, default: true
    field :is_experimental, :boolean, default: true
    field :stability_level, :string, default: "alpha" # "alpha", "beta", "stable"
    field :features, {:array, :string}, default: [] # List of experimental features included
    field :customization_options, :map, default: %{} # Available customization parameters
    field :compatibility, :map, default: %{} # Browser/device compatibility info
    field :performance_notes, :string # Notes about performance implications
    field :usage_count, :integer, default: 0 # Track how many times template is used
    field :success_rate, :float, default: 0.0 # Success rate based on user feedback
    field :tags, {:array, :string}, default: []

    timestamps()
  end

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :name, :description, :category, :theme_name, :preview_url, :min_tier,
      :is_active, :is_experimental, :stability_level, :features, :customization_options,
      :compatibility, :performance_notes, :usage_count, :success_rate, :tags
    ])
    |> validate_required([:name, :description, :category, :theme_name])
    |> validate_inclusion(:min_tier, ["free", "pro", "premium"])
    |> validate_inclusion(:stability_level, ["alpha", "beta", "stable"])
    |> validate_number(:usage_count, greater_than_or_equal_to: 0)
    |> validate_number(:success_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint(:name)
    |> unique_constraint(:theme_name)
  end
end
