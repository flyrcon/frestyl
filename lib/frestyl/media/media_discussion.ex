# lib/frestyl/media/media_discussion.ex
defmodule Frestyl.Media.MediaDiscussion do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Frestyl.Accounts.User
  alias Frestyl.Media.{MediaFile, MediaGroup, DiscussionMessage}
  alias Frestyl.Channels.Channel

  schema "media_discussions" do
    field :title, :string
    field :description, :string
    field :discussion_type, :string, default: "general" # feedback, critique, collaboration, etc.
    field :status, :string, default: "active" # active, closed, archived
    field :is_pinned, :boolean, default: false
    field :metadata, :map, default: %{}

    belongs_to :media_file, MediaFile, foreign_key: :media_file_id
    belongs_to :media_group, MediaGroup, foreign_key: :media_group_id
    belongs_to :channel, Channel, foreign_key: :channel_id
    belongs_to :creator, User, foreign_key: :creator_id

    has_many :discussion_messages, DiscussionMessage, foreign_key: :media_discussion_id

    timestamps()
  end

  @required_fields [:title, :creator_id]
  @optional_fields [:description, :media_file_id, :media_group_id, :channel_id,
                   :discussion_type, :status, :is_pinned, :metadata]

  def changeset(media_discussion, attrs) do
    media_discussion
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:discussion_type, ["general", "feedback", "critique", "collaboration", "question", "announcement"])
    |> validate_inclusion(:status, ["active", "closed", "archived"])
    |> validate_metadata()
    |> validate_media_target()
    |> foreign_key_constraint(:creator_id)
    |> foreign_key_constraint(:media_file_id)
    |> foreign_key_constraint(:media_group_id)
    |> foreign_key_constraint(:channel_id)
  end

  # Query helpers
  def for_media_file(query \\ __MODULE__, media_file_id) do
    from(md in query, where: md.media_file_id == ^media_file_id)
  end

  def for_media_group(query \\ __MODULE__, media_group_id) do
    from(md in query, where: md.media_group_id == ^media_group_id)
  end

  def for_channel(query \\ __MODULE__, channel_id) do
    from(md in query, where: md.channel_id == ^channel_id)
  end

  def by_creator(query \\ __MODULE__, creator_id) do
    from(md in query, where: md.creator_id == ^creator_id)
  end

  def by_type(query \\ __MODULE__, discussion_type) do
    from(md in query, where: md.discussion_type == ^discussion_type)
  end

  def by_status(query \\ __MODULE__, status) do
    from(md in query, where: md.status == ^status)
  end

  def active(query \\ __MODULE__) do
    from(md in query, where: md.status == "active")
  end

  def pinned(query \\ __MODULE__) do
    from(md in query, where: md.is_pinned == true)
  end

  def recent(query \\ __MODULE__, days \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
    from(md in query, where: md.inserted_at >= ^cutoff)
  end

  def ordered(query \\ __MODULE__, direction \\ :desc) do
    from(md in query,
      order_by: [
        {^direction, md.is_pinned},
        {^direction, md.updated_at}
      ]
    )
  end

  def with_creator(query \\ __MODULE__) do
    from(md in query,
      join: c in assoc(md, :creator),
      preload: [creator: c]
    )
  end

  def with_messages(query \\ __MODULE__) do
    from(md in query,
      left_join: dm in assoc(md, :discussion_messages),
      left_join: u in assoc(dm, :user),
      preload: [discussion_messages: {dm, user: u}]
    )
  end

  def with_message_count(query \\ __MODULE__) do
    from(md in query,
      left_join: dm in assoc(md, :discussion_messages),
      group_by: md.id,
      select: {md, count(dm.id)}
    )
  end

  # Discovery interface specific
  def for_discovery(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    media_file_id = Keyword.get(opts, :media_file_id)
    media_group_id = Keyword.get(opts, :media_group_id)

    query =
      __MODULE__
      |> active()
      |> with_creator()
      |> with_message_count()
      |> ordered(:desc)
      |> limit(^limit)

    query = if media_file_id do
      from(md in query, where: md.media_file_id == ^media_file_id)
    else
      query
    end

    query = if media_group_id do
      from(md in query, where: md.media_group_id == ^media_group_id)
    else
      query
    end

    query
  end

  # Statistics helpers
  def count_for_media_file(media_file_id) do
    from(md in __MODULE__,
      where: md.media_file_id == ^media_file_id and md.status == "active",
      select: count(md.id)
    )
  end

  def count_for_media_group(media_group_id) do
    from(md in __MODULE__,
      where: md.media_group_id == ^media_group_id and md.status == "active",
      select: count(md.id)
    )
  end

  def latest_activity(query \\ __MODULE__) do
    from(md in query,
      left_join: dm in assoc(md, :discussion_messages),
      group_by: md.id,
      select: {md, max(dm.inserted_at)}
    )
  end

  # Helper functions
  def get_target_type(discussion) do
    cond do
      discussion.media_file_id -> :media_file
      discussion.media_group_id -> :media_group
      true -> :general
    end
  end

  def get_target_id(discussion) do
    case get_target_type(discussion) do
      :media_file -> discussion.media_file_id
      :media_group -> discussion.media_group_id
      :general -> nil
    end
  end

  # Private validation helpers
  defp validate_metadata(changeset) do
    case get_field(changeset, :metadata) do
      nil -> changeset
      metadata when is_map(metadata) -> changeset
      _ -> add_error(changeset, :metadata, "must be a valid map")
    end
  end

  defp validate_media_target(changeset) do
    media_file_id = get_field(changeset, :media_file_id)
    media_group_id = get_field(changeset, :media_group_id)

    case {media_file_id, media_group_id} do
      {nil, nil} -> changeset  # General discussion, no specific target
      {_, nil} -> changeset    # Discussion about a specific file
      {nil, _} -> changeset    # Discussion about a group
      {_, _} -> add_error(changeset, :base, "discussion cannot target both a file and a group")
    end
  end
end
