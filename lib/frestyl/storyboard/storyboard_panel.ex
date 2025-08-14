# lib/frestyl/storyboard/storyboard_panel.ex
defmodule Frestyl.Storyboard.StoryboardPanel do
  @moduledoc """
  Ecto schema for storyboard panels.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "storyboard_panels" do
    field :panel_order, :integer
    field :canvas_data, :map
    field :thumbnail_url, :string
    field :voice_note_id, :binary_id
    field :created_by, :integer  # Changed from :binary_id to :integer for bigint compatibility

    # Associations
    belongs_to :story, Frestyl.Stories.EnhancedStoryStructure, foreign_key: :story_id
    field :section_id, :binary_id # Links to story section

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating and updating panels.
  """
  def changeset(panel, attrs) do
    panel
    |> cast(attrs, [
      :story_id, :section_id, :panel_order, :canvas_data,
      :thumbnail_url, :voice_note_id, :created_by
    ])
    |> validate_required([:story_id, :panel_order, :canvas_data, :created_by])
    |> validate_number(:panel_order, greater_than: 0)
    |> validate_canvas_data()
    |> unique_constraint([:story_id, :panel_order])
  end

  defp validate_canvas_data(changeset) do
    case get_field(changeset, :canvas_data) do
      nil -> add_error(changeset, :canvas_data, "cannot be empty")
      canvas_data when is_map(canvas_data) ->
        # Validate required canvas fields
        required_fields = ["width", "height", "objects"]
        missing_fields = Enum.reject(required_fields, &Map.has_key?(canvas_data, &1))

        case missing_fields do
          [] -> changeset
          fields -> add_error(changeset, :canvas_data, "missing required fields: #{Enum.join(fields, ", ")}")
        end

      _ -> add_error(changeset, :canvas_data, "must be a valid canvas object")
    end
  end
end
