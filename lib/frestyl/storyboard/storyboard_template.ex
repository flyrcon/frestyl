# lib/frestyl/storyboard/storyboard_template.ex
defmodule Frestyl.Storyboard.StoryboardTemplate do
  @moduledoc """
  Ecto schema for storyboard templates.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "storyboard_templates" do
    field :name, :string
    field :description, :string
    field :category, :string
    field :default_width, :integer, default: 800
    field :default_height, :integer, default: 600
    field :canvas_data, :map
    field :thumbnail_url, :string
    field :is_public, :boolean, default: false

    # Associations
    belongs_to :created_by_user, Frestyl.Accounts.User, foreign_key: :created_by, type: :integer

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating and updating templates.
  """
  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :name, :description, :category, :default_width, :default_height,
      :canvas_data, :thumbnail_url, :is_public, :created_by
    ])
    |> validate_required([:name, :category, :canvas_data])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:category, valid_categories())
    |> validate_number(:default_width, greater_than: 100, less_than: 5000)
    |> validate_number(:default_height, greater_than: 100, less_than: 5000)
    |> validate_canvas_data()
  end

  defp valid_categories do
    ["basic", "comic", "film", "character", "mobile", "custom", "experimental"]
  end

  defp validate_canvas_data(changeset) do
    case get_field(changeset, :canvas_data) do
      nil ->
        add_error(changeset, :canvas_data, "cannot be empty")

      canvas_data when is_map(canvas_data) ->
        required_fields = ["width", "height", "objects"]
        missing_fields = Enum.reject(required_fields, &Map.has_key?(canvas_data, &1))

        case missing_fields do
          [] ->
            changeset
            |> validate_canvas_dimensions()
            |> validate_canvas_objects()

          fields ->
            add_error(changeset, :canvas_data,
              "missing required fields: #{Enum.join(fields, ", ")}")
        end

      _ ->
        add_error(changeset, :canvas_data, "must be a valid canvas object")
    end
  end

  defp validate_canvas_dimensions(changeset) do
    canvas_data = get_field(changeset, :canvas_data)

    cond do
      canvas_data["width"] <= 0 or canvas_data["width"] > 5000 ->
        add_error(changeset, :canvas_data, "width must be between 1 and 5000")

      canvas_data["height"] <= 0 or canvas_data["height"] > 5000 ->
        add_error(changeset, :canvas_data, "height must be between 1 and 5000")

      true ->
        changeset
    end
  end

  defp validate_canvas_objects(changeset) do
    canvas_data = get_field(changeset, :canvas_data)

    case canvas_data["objects"] do
      objects when is_list(objects) ->
        if length(objects) > 100 do
          add_error(changeset, :canvas_data, "too many objects (max 100)")
        else
          changeset
        end

      _ ->
        add_error(changeset, :canvas_data, "objects must be a list")
    end
  end
end
