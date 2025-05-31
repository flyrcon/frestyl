# lib/frestyl/media/discussion_message.ex
defmodule Frestyl.Media.DiscussionMessage do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Frestyl.Accounts.User
  alias Frestyl.Media.MediaDiscussion

  schema "discussion_messages" do
    field :content, :string
    field :message_type, :string, default: "text" # text, media, timestamp_note, etc.
    field :timestamp_reference, :float # For time-based comments on audio/video
    field :attachments, {:array, :map}, default: []
    field :mentions, {:array, :integer}, default: [] # User IDs mentioned
    field :edited_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :media_discussion, MediaDiscussion, foreign_key: :media_discussion_id
    belongs_to :user, User, foreign_key: :user_id
    belongs_to :parent, __MODULE__, foreign_key: :parent_id # For threading

    has_many :replies, __MODULE__, foreign_key: :parent_id

    timestamps()
  end

  @required_fields [:content, :media_discussion_id, :user_id]
  @optional_fields [:message_type, :timestamp_reference, :attachments, :mentions,
                   :edited_at, :metadata, :parent_id]

  def changeset(discussion_message, attrs) do
    discussion_message
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:content, min: 1, max: 2000)
    |> validate_inclusion(:message_type, ["text", "media", "timestamp_note", "system", "reaction"])
    |> validate_timestamp_reference()
    |> validate_attachments()
    |> validate_mentions()
    |> validate_metadata()
    |> foreign_key_constraint(:media_discussion_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:parent_id)
  end

  # Query helpers
  def for_discussion(query \\ __MODULE__, discussion_id) do
    from(dm in query, where: dm.media_discussion_id == ^discussion_id)
  end

  def by_user(query \\ __MODULE__, user_id) do
    from(dm in query, where: dm.user_id == ^user_id)
  end

  def by_type(query \\ __MODULE__, message_type) do
    from(dm in query, where: dm.message_type == ^message_type)
  end

  def top_level(query \\ __MODULE__) do
    from(dm in query, where: is_nil(dm.parent_id))
  end

  def replies_to(query \\ __MODULE__, parent_id) do
    from(dm in query, where: dm.parent_id == ^parent_id)
  end

  def with_timestamp(query \\ __MODULE__) do
    from(dm in query, where: not is_nil(dm.timestamp_reference))
  end

  def recent(query \\ __MODULE__, days \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
    from(dm in query, where: dm.inserted_at >= ^cutoff)
  end

  def edited(query \\ __MODULE__) do
    from(dm in query, where: not is_nil(dm.edited_at))
  end

  def ordered(query \\ __MODULE__, direction \\ :asc) do
    from(dm in query, order_by: [{^direction, dm.inserted_at}])
  end

  def with_user(query \\ __MODULE__) do
    from(dm in query,
      join: u in assoc(dm, :user),
      preload: [user: u]
    )
  end

  def with_replies(query \\ __MODULE__) do
    from(dm in query,
      left_join: r in assoc(dm, :replies),
      left_join: u in assoc(r, :user),
      preload: [replies: {r, user: u}]
    )
  end

  def threaded_for_discussion(discussion_id) do
    from(dm in __MODULE__,
      where: dm.media_discussion_id == ^discussion_id,
      left_join: u in assoc(dm, :user),
      left_join: r in assoc(dm, :replies),
      left_join: ru in assoc(r, :user),
      order_by: [asc: dm.inserted_at, asc: r.inserted_at],
      preload: [
        user: u,
        replies: {r, user: ru}
      ]
    )
  end

  # Discovery interface specific
  def recent_for_user_content(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    days = Keyword.get(opts, :days, 7)

    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(dm in __MODULE__,
      join: md in assoc(dm, :media_discussion),
      left_join: mf in assoc(md, :media_file),
      left_join: mg in assoc(md, :media_group),
      where: dm.inserted_at >= ^cutoff and (
        (not is_nil(mf.id) and mf.user_id == ^user_id) or
        (not is_nil(mg.id) and mg.user_id == ^user_id)
      ),
      order_by: [desc: dm.inserted_at],
      limit: ^limit,
      preload: [
        user: [:user],
        media_discussion: [
          media_file: [:media_file],
          media_group: [:media_group]
        ]
      ]
    )
  end

  def mentions_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    days = Keyword.get(opts, :days, 30)

    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(dm in __MODULE__,
      where: ^user_id in dm.mentions and dm.inserted_at >= ^cutoff,
      order_by: [desc: dm.inserted_at],
      limit: ^limit,
      preload: [:user, :media_discussion]
    )
  end

  # Statistics
  def count_for_discussion(discussion_id) do
    from(dm in __MODULE__,
      where: dm.media_discussion_id == ^discussion_id,
      select: count(dm.id)
    )
  end

  def count_replies(message_id) do
    from(dm in __MODULE__,
      where: dm.parent_id == ^message_id,
      select: count(dm.id)
    )
  end

  # Helper functions
  def extract_mentions(content) when is_binary(content) do
    # Extract @username mentions from content
    # This is a simple regex - you might want more sophisticated parsing
    mentions = Regex.scan(~r/@(\w+)/, content, capture: :all_but_first)
    mentions |> List.flatten() |> Enum.uniq()
  end

  def extract_mentions(_), do: []

  def format_timestamp_reference(nil), do: nil
  def format_timestamp_reference(seconds) when is_float(seconds) do
    minutes = trunc(seconds / 60)
    remaining_seconds = trunc(rem(seconds, 60))
    "#{minutes}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end

  def is_threaded_reply?(message) do
    not is_nil(message.parent_id)
  end

  def thread_depth(message, depth \\ 0) do
    if message.parent_id do
      # In a real implementation, you'd recursively check the parent
      # For now, we'll assume max depth of 1 (simple reply structure)
      depth + 1
    else
      depth
    end
  end

  # Private validation helpers
  defp validate_timestamp_reference(changeset) do
    case get_field(changeset, :timestamp_reference) do
      nil -> changeset
      ref when is_float(ref) and ref >= 0.0 -> changeset
      _ -> add_error(changeset, :timestamp_reference, "must be a positive float representing seconds")
    end
  end

  defp validate_attachments(changeset) do
    case get_field(changeset, :attachments) do
      nil -> changeset
      [] -> changeset
      attachments when is_list(attachments) ->
        if Enum.all?(attachments, &is_map/1) do
          changeset
        else
          add_error(changeset, :attachments, "must be a list of maps")
        end
      _ -> add_error(changeset, :attachments, "must be a list")
    end
  end

  defp validate_mentions(changeset) do
    case get_field(changeset, :mentions) do
      nil -> changeset
      [] -> changeset
      mentions when is_list(mentions) ->
        if Enum.all?(mentions, &is_integer/1) do
          changeset
        else
          add_error(changeset, :mentions, "must be a list of user IDs (integers)")
        end
      _ -> add_error(changeset, :mentions, "must be a list")
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
