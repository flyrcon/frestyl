# lib/frestyl/media/media_group.ex
defmodule Frestyl.Media.MediaGroup do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :name, :description, :group_type, :metadata, :color_theme,
                                :position, :is_public, :auto_expand, :primary_file_id, :channel_id,
                                :user_id, :inserted_at, :updated_at]}

  alias Frestyl.Accounts.User
  alias Frestyl.Media.{MediaFile, MediaGroupFile}
  alias Frestyl.Channels.Channel

  schema "media_groups" do
    field :name, :string
    field :description, :string
    field :group_type, :string, default: "auto" # auto, manual, session, album, project
    field :metadata, :map, default: %{}
    field :color_theme, :string, default: "#8B5CF6"
    field :position, :float, default: 0.0
    field :is_public, :boolean, default: true
    field :auto_expand, :boolean, default: false

    belongs_to :primary_file, MediaFile, foreign_key: :primary_file_id
    belongs_to :channel, Channel, foreign_key: :channel_id
    belongs_to :user, User, foreign_key: :user_id

    has_many :media_group_files, MediaGroupFile, foreign_key: :media_group_id
    has_many :media_files, through: [:media_group_files, :media_file]

    timestamps()
  end

  @required_fields [:name, :user_id]
  @optional_fields [:description, :group_type, :primary_file_id, :channel_id,
                   :metadata, :color_theme, :position, :is_public, :auto_expand]

  def changeset(media_group, attrs) do
    media_group
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:group_type, ["auto", "manual", "session", "album", "project", "collaboration"])
    |> validate_number(:position, greater_than_or_equal_to: 0.0)
    |> validate_color_theme()
    |> validate_metadata()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:primary_file_id)
  end

  # Query helpers for discovery interface
  def for_user(query \\ __MODULE__, user_id) do
    from(mg in query, where: mg.user_id == ^user_id)
  end

  def for_channel(query \\ __MODULE__, channel_id) do
    from(mg in query, where: mg.channel_id == ^channel_id)
  end

  def by_type(query \\ __MODULE__, group_type) do
    from(mg in query, where: mg.group_type == ^group_type)
  end

  def public_groups(query \\ __MODULE__) do
    from(mg in query, where: mg.is_public == true)
  end

  def auto_expand(query \\ __MODULE__) do
    from(mg in query, where: mg.auto_expand == true)
  end

  def ordered(query \\ __MODULE__, direction \\ :asc) do
    from(mg in query, order_by: [{^direction, mg.position}, {^direction, mg.inserted_at}])
  end

  def recent(query \\ __MODULE__, days \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
    from(mg in query, where: mg.inserted_at >= ^cutoff)
  end

  def with_files(query \\ __MODULE__) do
    from(mg in query,
      left_join: mgf in assoc(mg, :media_group_files),
      left_join: mf in assoc(mgf, :media_file),
      preload: [media_group_files: {mgf, media_file: mf}]
    )
  end

  def with_primary_file(query \\ __MODULE__) do
    from(mg in query,
      left_join: pf in assoc(mg, :primary_file),
      preload: [primary_file: pf]
    )
  end

  def with_channel(query \\ __MODULE__) do
    from(mg in query,
      left_join: c in assoc(mg, :channel),
      preload: [channel: c]
    )
  end

  def with_user(query \\ __MODULE__) do
    from(mg in query,
      left_join: u in assoc(mg, :user),
      preload: [user: u]
    )
  end

  # Discovery interface specific queries
  def discovery_cards_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    search = Keyword.get(opts, :search)
    media_type = Keyword.get(opts, :media_type)
    channel_id = Keyword.get(opts, :channel_id)

    query =
      __MODULE__
      |> for_user(user_id)
      |> with_files()
      |> with_primary_file()
      |> with_channel()
      |> ordered(:desc)
      |> limit(^limit)

    query = if search do
      search_term = "%#{search}%"
      from(mg in query,
        where: ilike(mg.name, ^search_term) or ilike(mg.description, ^search_term)
      )
    else
      query
    end

    query = if channel_id do
      from(mg in query, where: mg.channel_id == ^channel_id)
    else
      query
    end

    # Filter by media type if specified
    query = if media_type do
      from(mg in query,
        join: mgf in assoc(mg, :media_group_files),
        join: mf in assoc(mgf, :media_file),
        where: mf.media_type == ^media_type
      )
    else
      query
    end

    query
  end

  def count_for_user(user_id) do
    from(mg in __MODULE__, where: mg.user_id == ^user_id, select: count(mg.id))
  end

  def total_files_in_groups(user_id) do
    from(mg in __MODULE__,
      join: mgf in assoc(mg, :media_group_files),
      where: mg.user_id == ^user_id,
      select: count(mgf.id)
    )
  end

  # Helper functions
  def get_component_files(media_group) do
    media_group.media_group_files
    |> Enum.reject(&(&1.role == "primary"))
    |> Enum.map(&(&1.media_file))
  end

  def get_primary_file(media_group) do
    case media_group.primary_file do
      nil ->
        # Fallback to first file marked as primary in group_files
        primary_group_file = Enum.find(media_group.media_group_files, &(&1.role == "primary"))
        primary_group_file && primary_group_file.media_file
      primary_file ->
        primary_file
    end
  end

  def calculate_engagement_score(media_group) do
    # Calculate based on views, reactions, discussions, etc.
    # This is a placeholder - implement based on your analytics needs
    base_score = case media_group.group_type do
      "album" -> 1.0
      "project" -> 0.9
      "session" -> 0.8
      "collaboration" -> 1.1
      _ -> 0.7
    end

    # Factor in file count
    file_count = length(media_group.media_group_files || [])
    file_bonus = min(file_count * 0.1, 0.5)

    # Factor in recency (groups created in last 7 days get bonus)
    recency_bonus = if DateTime.diff(DateTime.utc_now(), media_group.inserted_at, :day) <= 7 do
      0.2
    else
      0.0
    end

    base_score + file_bonus + recency_bonus
  end

  # Private helper functions
  defp validate_color_theme(changeset) do
    case get_field(changeset, :color_theme) do
      nil -> changeset
      color when is_binary(color) ->
        if String.match?(color, ~r/^#[0-9A-Fa-f]{6}$/) do
          changeset
        else
          add_error(changeset, :color_theme, "must be a valid hex color (e.g., #8B5CF6)")
        end
      _ -> add_error(changeset, :color_theme, "must be a string")
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
