# lib/frestyl/media/media_group_file.ex
defmodule Frestyl.Media.MediaGroupFile do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Frestyl.Media.{MediaGroup, MediaFile}

  schema "media_group_files" do
    field :role, :string, default: "component" # primary, component, alternate, reference
    field :position, :integer, default: 0
    field :relationship_type, :string # cover_art, stem, lyrics, documentation, etc.
    field :metadata, :map, default: %{}

    belongs_to :media_group, MediaGroup, foreign_key: :media_group_id
    belongs_to :media_file, MediaFile, foreign_key: :media_file_id

    timestamps()
  end

  @required_fields [:media_group_id, :media_file_id]
  @optional_fields [:role, :position, :relationship_type, :metadata]

  def changeset(media_group_file, attrs) do
    media_group_file
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:role, ["primary", "component", "alternate", "reference"])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_relationship_type()
    |> validate_metadata()
    |> foreign_key_constraint(:media_group_id)
    |> foreign_key_constraint(:media_file_id)
    |> unique_constraint([:media_group_id, :media_file_id])
  end

  # Query helpers
  def for_group(query \\ __MODULE__, group_id) do
    from(mgf in query, where: mgf.media_group_id == ^group_id)
  end

  def for_file(query \\ __MODULE__, file_id) do
    from(mgf in query, where: mgf.media_file_id == ^file_id)
  end

  def by_role(query \\ __MODULE__, role) do
    from(mgf in query, where: mgf.role == ^role)
  end

  def by_relationship_type(query \\ __MODULE__, type) do
    from(mgf in query, where: mgf.relationship_type == ^type)
  end

  def ordered(query \\ __MODULE__, direction \\ :asc) do
    from(mgf in query, order_by: [{^direction, mgf.position}, {^direction, mgf.inserted_at}])
  end

  def with_media_file(query \\ __MODULE__) do
    from(mgf in query,
      join: mf in assoc(mgf, :media_file),
      preload: [media_file: mf]
    )
  end

  def with_media_group(query \\ __MODULE__) do
    from(mgf in query,
      join: mg in assoc(mgf, :media_group),
      preload: [media_group: mg]
    )
  end

  # Discovery interface helpers
  def primary_files_for_groups(group_ids) when is_list(group_ids) do
    from(mgf in __MODULE__,
      where: mgf.media_group_id in ^group_ids and mgf.role == "primary",
      preload: [:media_file, :media_group]
    )
  end

  def component_files_for_group(group_id) do
    from(mgf in __MODULE__,
      where: mgf.media_group_id == ^group_id and mgf.role in ["component", "alternate", "reference"],
      order_by: [asc: mgf.position, asc: mgf.inserted_at],
      preload: [:media_file]
    )
  end

  def files_by_relationship(group_id, relationship_type) do
    from(mgf in __MODULE__,
      where: mgf.media_group_id == ^group_id and mgf.relationship_type == ^relationship_type,
      order_by: [asc: mgf.position],
      preload: [:media_file]
    )
  end

  # Helper functions for music-specific relationships
  def get_stems_for_group(group_id) do
    files_by_relationship(group_id, "stem")
  end

  def get_cover_art_for_group(group_id) do
    files_by_relationship(group_id, "cover_art")
  end

  def get_documentation_for_group(group_id) do
    files_by_relationship(group_id, "documentation")
  end

  def get_lyrics_for_group(group_id) do
    files_by_relationship(group_id, "lyrics")
  end

  # Utility functions
  def reorder_files_in_group(group_id, file_positions) when is_map(file_positions) do
    # file_positions should be %{file_id => new_position, ...}
    # This would typically be called from a context function
    updates = Enum.map(file_positions, fn {file_id, position} ->
      %{media_file_id: file_id, media_group_id: group_id, position: position}
    end)

    # Return the updates for the context to handle
    updates
  end

  def get_next_position(group_id) do
    case from(mgf in __MODULE__,
           where: mgf.media_group_id == ^group_id,
           select: max(mgf.position)) |> Frestyl.Repo.one() do
      nil -> 0
      max_position -> max_position + 1
    end
  end

  # Private validation helpers
  defp validate_relationship_type(changeset) do
    case get_field(changeset, :relationship_type) do
      nil -> changeset
      type when type in [
        # Audio-specific
        "stem", "master", "demo", "remix", "cover",
        # Visual-specific
        "cover_art", "thumbnail", "poster", "still",
        # Documentation
        "lyrics", "chord_chart", "notes", "documentation", "readme",
        # Media-specific
        "subtitle", "caption", "transcript",
        # Generic
        "reference", "inspiration", "sample", "source"
      ] -> changeset
      _ -> add_error(changeset, :relationship_type, "must be a valid relationship type")
    end
  end

  defp validate_metadata(changeset) do
    case get_field(changeset, :metadata) do
      nil -> changeset
      metadata when is_map(metadata) -> changeset
      _ -> add_error(changeset, :metadata, "must be a valid map")
    end
  end
end
