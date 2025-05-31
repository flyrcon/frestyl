defmodule Frestyl.Media.ViewHistory do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Frestyl.Accounts.User
  alias Frestyl.Media.{MediaFile, MediaGroup}
  alias Frestyl.Channels.Channel

  @primary_key {:id, :id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  schema "view_history" do
    belongs_to :user, User
    belongs_to :media_file, MediaFile, foreign_key: :media_file_id
    belongs_to :media_group, MediaGroup, foreign_key: :media_group_id
    belongs_to :channel, Channel, foreign_key: :channel_id

    field :view_duration, :integer, default: 0
    field :interaction_count, :integer, default: 0
    field :device_type, :string
    field :view_context, :string
    field :completion_percentage, :float, default: 0.0
    field :metadata, :map, default: %{}

    timestamps()
  end

  @required_fields [:user_id]
  @optional_fields [:media_file_id, :media_group_id, :channel_id, :view_duration,
                   :interaction_count, :device_type, :view_context, :completion_percentage, :metadata]

  def changeset(view_history, attrs) do
    view_history
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:view_duration, greater_than_or_equal_to: 0)
    |> validate_number(:interaction_count, greater_than_or_equal_to: 0)
    |> validate_number(:completion_percentage, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_inclusion(:device_type, ["mobile", "tablet", "desktop", "unknown"])
    |> validate_inclusion(:view_context, ["discovery", "search", "recommendation", "direct", "playlist", "discussion"])
    |> validate_metadata()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:media_file_id)
    |> foreign_key_constraint(:media_group_id)
    |> foreign_key_constraint(:channel_id)
  end

  # Helper functions for analytics
  def for_user(query \\ __MODULE__, user_id) do
    from vh in query, where: vh.user_id == ^user_id
  end

  def for_media_file(query \\ __MODULE__, media_file_id) do
    from vh in query, where: vh.media_file_id == ^media_file_id
  end

  def for_channel(query \\ __MODULE__, channel_id) do
    from vh in query, where: vh.channel_id == ^channel_id
  end

  def recent(query \\ __MODULE__, days \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
    from vh in query, where: vh.inserted_at >= ^cutoff
  end

  def completed_views(query \\ __MODULE__, min_percentage \\ 80.0) do
    from vh in query, where: vh.completion_percentage >= ^min_percentage
  end

  def with_interactions(query \\ __MODULE__, min_interactions \\ 1) do
    from vh in query, where: vh.interaction_count >= ^min_interactions
  end

  # Aggregate functions
  def total_watch_time(query \\ __MODULE__) do
    from(vh in query, select: sum(vh.view_duration))
  end

  def avg_completion_rate(query \\ __MODULE__) do
    from(vh in query, select: avg(vh.completion_percentage))
  end

  def most_viewed_files(query \\ __MODULE__, limit \\ 10) do
    from(vh in query,
      group_by: vh.media_file_id,
      order_by: [desc: count(vh.id)],
      limit: ^limit,
      select: {vh.media_file_id, count(vh.id)}
    )
  end

  def device_breakdown(query \\ __MODULE__) do
    from(vh in query,
      group_by: vh.device_type,
      select: {vh.device_type, count(vh.id)}
    )
  end

  # Private helper functions
  defp validate_metadata(changeset) do
    case get_field(changeset, :metadata) do
      nil -> changeset
      metadata when is_map(metadata) -> changeset
      _ -> add_error(changeset, :metadata, "must be a valid map")
    end
  end
end
