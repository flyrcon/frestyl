# lib/frestyl/media/media_reaction.ex
defmodule Frestyl.Media.MediaReaction do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :reaction_type, :intensity, :timestamp_reference,
                                :metadata, :media_file_id, :media_group_id, :discussion_message_id,
                                :user_id, :inserted_at, :updated_at]}

  alias Frestyl.Accounts.User
  alias Frestyl.Media.{MediaFile, MediaGroup, DiscussionMessage}

  schema "media_reactions" do
    field :reaction_type, :string # heart, fire, star, thumbsup, lightbulb, wave, lightning, rocket, leaf, gem, plane, etc.
    field :intensity, :float, default: 1.0 # For animated reactions (0.0 to 2.0)
    field :timestamp_reference, :float # Time-specific reactions for audio/video
    field :metadata, :map, default: %{}

    belongs_to :media_file, MediaFile, foreign_key: :media_file_id
    belongs_to :media_group, MediaGroup, foreign_key: :media_group_id
    belongs_to :discussion_message, DiscussionMessage, foreign_key: :discussion_message_id
    belongs_to :user, User, foreign_key: :user_id

    timestamps()
  end

  @required_fields [:reaction_type, :user_id]
  @optional_fields [:media_file_id, :media_group_id, :discussion_message_id,
                   :intensity, :timestamp_reference, :metadata]

  def changeset(media_reaction, attrs) do
    media_reaction
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:reaction_type, valid_reaction_types())
    |> validate_number(:intensity, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 2.0)
    |> validate_timestamp_reference()
    |> validate_target()
    |> validate_metadata()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:media_file_id)
    |> foreign_key_constraint(:media_group_id)
    |> foreign_key_constraint(:discussion_message_id)
  end

  # Valid reaction types for your discovery interface
  defp valid_reaction_types do
    [
      # Core emotions
      "heart", "fire", "star", "thumbsup", "thumbsdown",

      # Creative feedback
      "lightbulb", "rocket", "gem", "crown", "magic",

      # Theme-specific reactions
      "wave", "lightning", "leaf", "crystal", "paper", "cosmic",

      # Music-specific
      "headphones", "microphone", "guitar", "drums", "piano",

      # Collaboration
      "handshake", "team", "chat", "idea", "question",

      # Quality indicators
      "professional", "creative", "innovative", "polished", "raw"
    ]
  end

  # Query helpers
  def for_media_file(query \\ __MODULE__, media_file_id) do
    from(mr in query, where: mr.media_file_id == ^media_file_id)
  end

  def for_media_group(query \\ __MODULE__, media_group_id) do
    from(mr in query, where: mr.media_group_id == ^media_group_id)
  end

  def for_discussion_message(query \\ __MODULE__, message_id) do
    from(mr in query, where: mr.discussion_message_id == ^message_id)
  end

  def by_user(query \\ __MODULE__, user_id) do
    from(mr in query, where: mr.user_id == ^user_id)
  end

  def by_reaction_type(query \\ __MODULE__, reaction_type) do
    from(mr in query, where: mr.reaction_type == ^reaction_type)
  end

  def with_timestamp(query \\ __MODULE__) do
    from(mr in query, where: not is_nil(mr.timestamp_reference))
  end

  def recent(query \\ __MODULE__, days \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
    from(mr in query, where: mr.inserted_at >= ^cutoff)
  end

  def high_intensity(query \\ __MODULE__, min_intensity \\ 1.5) do
    from(mr in query, where: mr.intensity >= ^min_intensity)
  end

  def ordered(query \\ __MODULE__, direction \\ :desc) do
    from(mr in query, order_by: [{^direction, mr.inserted_at}])
  end

  def with_user(query \\ __MODULE__) do
    from(mr in query,
      join: u in assoc(mr, :user),
      preload: [user: u]
    )
  end

  # Discovery interface specific queries
  def reaction_summary_for_file(media_file_id) do
    from(mr in __MODULE__,
      where: mr.media_file_id == ^media_file_id,
      group_by: mr.reaction_type,
      select: {mr.reaction_type, count(mr.id), avg(mr.intensity)}
    )
  end

  def reaction_summary_for_group(media_group_id) do
    from(mr in __MODULE__,
      where: mr.media_group_id == ^media_group_id,
      group_by: mr.reaction_type,
      select: {mr.reaction_type, count(mr.id), avg(mr.intensity)}
    )
  end

  def trending_reactions(opts \\ []) do
    days = Keyword.get(opts, :days, 7)
    limit = Keyword.get(opts, :limit, 10)

    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(mr in __MODULE__,
      where: mr.inserted_at >= ^cutoff,
      group_by: mr.reaction_type,
      order_by: [desc: count(mr.id)],
      limit: ^limit,
      select: {mr.reaction_type, count(mr.id)}
    )
  end

  def user_reaction_patterns(user_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(mr in __MODULE__,
      where: mr.user_id == ^user_id and mr.inserted_at >= ^cutoff,
      group_by: mr.reaction_type,
      select: {mr.reaction_type, count(mr.id), avg(mr.intensity)}
    )
  end

  def reactions_timeline_for_media(media_file_id) do
    from(mr in __MODULE__,
      where: mr.media_file_id == ^media_file_id and not is_nil(mr.timestamp_reference),
      order_by: [asc: mr.timestamp_reference],
      preload: [:user]
    )
  end

  # Toggle reaction (add/remove)
  def toggle_reaction(attrs) do
    required_keys = [:user_id, :reaction_type]
    target_key = cond do
      attrs[:media_file_id] -> :media_file_id
      attrs[:media_group_id] -> :media_group_id
      attrs[:discussion_message_id] -> :discussion_message_id
      true -> nil
    end

    if target_key && attrs[target_key] do
      filter_attrs = Map.take(attrs, [:user_id, :reaction_type, target_key])

      case Frestyl.Repo.get_by(__MODULE__, filter_attrs) do
        nil ->
          # Create new reaction
          %__MODULE__{}
          |> changeset(attrs)
          |> Frestyl.Repo.insert()

        existing_reaction ->
          # Remove existing reaction
          Frestyl.Repo.delete(existing_reaction)
      end
    else
      {:error, :invalid_target}
    end
  end

  # Bulk operations for discovery interface
  def get_reactions_for_files(file_ids) when is_list(file_ids) do
    from(mr in __MODULE__,
      where: mr.media_file_id in ^file_ids,
      group_by: [mr.media_file_id, mr.reaction_type],
      select: {mr.media_file_id, mr.reaction_type, count(mr.id)}
    )
  end

  def get_reactions_for_groups(group_ids) when is_list(group_ids) do
    from(mr in __MODULE__,
      where: mr.media_group_id in ^group_ids,
      group_by: [mr.media_group_id, mr.reaction_type],
      select: {mr.media_group_id, mr.reaction_type, count(mr.id)}
    )
  end

  def user_reactions_for_content(user_id, file_ids, group_ids \\ []) do
    query = from(mr in __MODULE__, where: mr.user_id == ^user_id)

    query = if file_ids != [] do
      from(mr in query, or_where: mr.media_file_id in ^file_ids)
    else
      query
    end

    query = if group_ids != [] do
      from(mr in query, or_where: mr.media_group_id in ^group_ids)
    else
      query
    end

    from(mr in query, select: {mr.media_file_id, mr.media_group_id, mr.reaction_type})
  end

  # Analytics helpers
  def engagement_score_for_file(media_file_id) do
    # Calculate engagement based on reaction diversity and intensity
    reactions =
      from(mr in __MODULE__,
        where: mr.media_file_id == ^media_file_id,
        select: {mr.reaction_type, count(mr.id), avg(mr.intensity)}
      )
      |> Frestyl.Repo.all()

    calculate_engagement_score(reactions)
  end

  def engagement_score_for_group(media_group_id) do
    reactions =
      from(mr in __MODULE__,
        where: mr.media_group_id == ^media_group_id,
        select: {mr.reaction_type, count(mr.id), avg(mr.intensity)}
      )
      |> Frestyl.Repo.all()

    calculate_engagement_score(reactions)
  end

  defp calculate_engagement_score(reactions) do
    case reactions do
      [] -> 0.0
      _ ->
        # Base score from total reactions
        total_reactions = Enum.reduce(reactions, 0, fn {_, count, _}, acc -> acc + count end)
        base_score = :math.log(total_reactions + 1) * 10

        # Diversity bonus (more reaction types = higher engagement)
        diversity_bonus = length(reactions) * 2

        # Intensity bonus (average intensity across all reactions)
        intensity_bonus =
          reactions
          |> Enum.reduce(0, fn {_, count, avg_intensity}, acc ->
            acc + (count * (avg_intensity || 1.0))
          end)
          |> then(fn total -> total / total_reactions end)
          |> then(fn avg -> (avg - 1.0) * 5 end) # Scale intensity bonus

        # Quality reaction bonus (certain reactions indicate higher quality)
        quality_reactions = ["gem", "crown", "professional", "innovative", "polished"]
        quality_bonus =
          reactions
          |> Enum.filter(fn {type, _, _} -> type in quality_reactions end)
          |> Enum.reduce(0, fn {_, count, _}, acc -> acc + count end)
          |> then(fn count -> count * 3 end)

        base_score + diversity_bonus + intensity_bonus + quality_bonus
    end
  end

  # Real-time reaction helpers
  def subscribe_to_reactions(target_type, target_id) do
    topic = "reactions:#{target_type}:#{target_id}"
    Phoenix.PubSub.subscribe(Frestyl.PubSub, topic)
  end

  def broadcast_reaction_change(reaction, action) when action in [:added, :removed] do
    target_type = get_target_type(reaction)
    target_id = get_target_id(reaction)

    if target_type && target_id do
      topic = "reactions:#{target_type}:#{target_id}"
      Phoenix.PubSub.broadcast(Frestyl.PubSub, topic, {
        :reaction_update,
        %{
          action: action,
          reaction: reaction,
          target_type: target_type,
          target_id: target_id
        }
      })
    end
  end

  # Helper functions
  def get_target_type(reaction) do
    cond do
      reaction.media_file_id -> :media_file
      reaction.media_group_id -> :media_group
      reaction.discussion_message_id -> :discussion_message
      true -> nil
    end
  end

  def get_target_id(reaction) do
    case get_target_type(reaction) do
      :media_file -> reaction.media_file_id
      :media_group -> reaction.media_group_id
      :discussion_message -> reaction.discussion_message_id
      nil -> nil
    end
  end

  def get_reaction_emoji(reaction_type) do
    emoji_map = %{
      # Core emotions
      "heart" => "❤️", "fire" => "🔥", "star" => "⭐", "thumbsup" => "👍", "thumbsdown" => "👎",

      # Creative feedback
      "lightbulb" => "💡", "rocket" => "🚀", "gem" => "💎", "crown" => "👑", "magic" => "✨",

      # Theme-specific
      "wave" => "🌊", "lightning" => "⚡", "leaf" => "🍃", "crystal" => "🔮", "paper" => "📄", "cosmic" => "🌌",

      # Music-specific
      "headphones" => "🎧", "microphone" => "🎤", "guitar" => "🎸", "drums" => "🥁", "piano" => "🎹",

      # Collaboration
      "handshake" => "🤝", "team" => "👥", "chat" => "💬", "idea" => "🧠", "question" => "❓",

      # Quality indicators
      "professional" => "🏆", "creative" => "🎨", "innovative" => "🚀", "polished" => "✨", "raw" => "⚡"
    }

    emoji_map[reaction_type] || "👍"
  end

  def is_positive_reaction?(reaction_type) do
    positive_reactions = [
      "heart", "fire", "star", "thumbsup", "lightbulb", "rocket", "gem", "crown", "magic",
      "headphones", "microphone", "guitar", "drums", "piano", "handshake", "team",
      "professional", "creative", "innovative", "polished"
    ]

    reaction_type in positive_reactions
  end

  # Private validation helpers
  defp validate_timestamp_reference(changeset) do
    case get_field(changeset, :timestamp_reference) do
      nil -> changeset
      ref when is_float(ref) and ref >= 0.0 -> changeset
      _ -> add_error(changeset, :timestamp_reference, "must be a positive float representing seconds")
    end
  end

  defp validate_target(changeset) do
    media_file_id = get_field(changeset, :media_file_id)
    media_group_id = get_field(changeset, :media_group_id)
    discussion_message_id = get_field(changeset, :discussion_message_id)

    targets = [media_file_id, media_group_id, discussion_message_id]
    non_nil_targets = Enum.filter(targets, &(&1 != nil))

    case length(non_nil_targets) do
      1 -> changeset  # Exactly one target is set
      0 -> add_error(changeset, :base, "reaction must target a file, group, or message")
      _ -> add_error(changeset, :base, "reaction can only target one item")
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
