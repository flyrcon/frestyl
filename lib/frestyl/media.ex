# lib/frestyl/media.ex - Enhanced Media Context
defmodule Frestyl.Media do
  @moduledoc """
  Enhanced Media context with intelligent grouping, discussions, and revolutionary discovery features.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Accounts.User
  alias Frestyl.Channels.Channel

  alias Frestyl.Media.{
    MediaFile, MediaGroup, MediaGroupFile, MediaDiscussion, DiscussionMessage,
    MediaReaction, UserThemePreferences, MusicMetadata, ViewHistory, SavedFilter
  }

  # ==================
  # MEDIA GROUPS
  # ==================

  @doc """
  Gets intelligent media groups for a user with optional filtering.
  """
  def get_media_groups_for_user(user_id, opts \\ []) do
    channel_id = opts[:channel_id]
    group_type = opts[:group_type]
    auto_create = Keyword.get(opts, :auto_create, true)

    query = from g in MediaGroup,
      where: g.user_id == ^user_id,
      preload: [
        :primary_file,
        :channel,
        media_group_files: [:media_file],
        media_files: []
      ],
      order_by: [desc: g.updated_at]

    query = if channel_id, do: where(query, [g], g.channel_id == ^channel_id), else: query
    query = if group_type, do: where(query, [g], g.group_type == ^group_type), else: query

    groups = Repo.all(query)

    if auto_create and Enum.empty?(groups) do
      auto_create_groups_for_user(user_id, channel_id)
    else
      groups
    end
  end

  @doc """
  Auto-creates intelligent media groups based on user's files.
  """
  def auto_create_groups_for_user(user_id, channel_id \\ nil) do
    # Get all user's media files
    files = list_media_files_for_user(user_id, channel_id: channel_id)

    # Group by various strategies
    session_groups = group_by_sessions(files)
    album_groups = group_by_albums(files)
    time_groups = group_by_time_proximity(files)
    collaboration_groups = group_by_collaborations(files)  # Fixed: Added missing assignment

    # Create groups in database
    all_groups = session_groups ++ album_groups ++ time_groups ++ collaboration_groups

    Enum.map(all_groups, fn group_data ->
      create_media_group(%{
        name: group_data.name,
        description: group_data.description,
        group_type: group_data.type,
        user_id: user_id,
        channel_id: channel_id,
        primary_file_id: group_data.primary_file_id,
        metadata: group_data.metadata
      }, group_data.file_ids)
    end)
  end

  # Add this alias at the top of your media.ex file with your other aliases:
  alias Frestyl.Media.Comment

  @doc """
  Lists threaded comments for a media file with replies nested properly.
  """
  def list_threaded_comments_for_file(file_id) do
    # Get all comments for this asset (using your existing schema)
    all_comments = from(c in Comment,
      where: c.asset_id == ^file_id,
      preload: [:user],
      order_by: [asc: c.inserted_at]
    ) |> Repo.all()

    # Build comment tree with reactions
    comments_with_reactions = Enum.map(all_comments, fn comment ->
      reaction_summary = get_comment_reaction_summary(comment.id)
      user_reactions = get_comment_user_reactions(comment.id)

      comment
      |> Map.put(:reaction_summary, reaction_summary)
      |> Map.put(:user_reactions, user_reactions)
    end)

    # Build threaded structure
    build_comment_tree(comments_with_reactions)
  end

  @doc """
  Creates a threaded comment (can be a reply).
  """
  def create_threaded_comment(attrs, user) do
    # Map media_file_id to asset_id to match your schema
    attrs = attrs
    |> Map.put("user_id", user.id)
    |> Map.put("asset_id", attrs["media_file_id"])
    |> Map.delete("media_file_id")

    case create_comment(attrs, user) do
      {:ok, comment} ->
        # Broadcast real-time update
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "file_comments:#{comment.asset_id}",
          {:comment_created, comment}
        )
        {:ok, comment}
      error -> error
    end
  end

  @doc """
  Creates a comment using your existing system.
  """
  def create_comment(attrs, user) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a comment by ID.
  """
  def get_comment(id) do
    Repo.get(Comment, id)
  end

  @doc """
  Deletes a comment if user has permission.
  """
  def delete_comment(comment, user) do
    if comment.user_id == user.id do
      case Repo.delete(comment) do
        {:ok, deleted_comment} ->
          # Broadcast real-time update
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "file_comments:#{deleted_comment.asset_id}",
            {:comment_deleted, deleted_comment}
          )
          {:ok, deleted_comment}
        error -> error
      end
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Toggles a reaction on a comment.
  """
  def toggle_comment_reaction(attrs) do
    case get_existing_comment_reaction(attrs) do
      nil -> create_comment_reaction(attrs)
      reaction -> delete_comment_reaction(reaction)
    end
  end

  @doc """
  Subscribes to file comments for real-time updates.
  """
  def subscribe_to_file_comments(file_id) do
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "file_comments:#{file_id}")
  end

  defp build_comment_tree(comments) do
    # Separate root comments from replies
    {root_comments, replies} = Enum.split_with(comments, &is_nil(&1.parent_id))

    # Build tree recursively
    Enum.map(root_comments, fn root_comment ->
      attach_replies(root_comment, replies)
    end)
  end

  defp attach_replies(comment, all_replies) do
    # Find direct replies to this comment
    direct_replies = Enum.filter(all_replies, &(&1.parent_id == comment.id))

    # Recursively attach replies to each direct reply
    nested_replies = Enum.map(direct_replies, fn reply ->
      attach_replies(reply, all_replies)
    end)

    Map.put(comment, :replies, nested_replies)
  end

  defp get_comment_reaction_summary(comment_id) do

    from(r in "comment_reactions",
      where: r.comment_id == ^comment_id,
      group_by: r.reaction_type,
      select: {r.reaction_type, count(r.id)}
     )
     |> Repo.all()
     |> Enum.into(%{})

    %{} # Return empty for now
  end

  defp get_comment_user_reactions(comment_id) do

     from(r in "comment_reactions",
       where: r.comment_id == ^comment_id,
       group_by: r.user_id,
       select: {r.user_id, fragment("array_agg(?)", r.reaction_type)}
     )
     |> Repo.all()
     |> Enum.into(%{})

    %{} # Return empty for now
  end

  defp get_existing_comment_reaction(%{"comment_id" => comment_id, "user_id" => user_id, "reaction_type" => reaction_type}) do

     from(r in "comment_reactions",
       where: r.comment_id == ^comment_id and r.user_id == ^user_id and r.reaction_type == ^reaction_type
     )
     |> Repo.one()

    nil # Return nil for now
  end

  defp create_comment_reaction(attrs) do


    case Repo.insert_all("comment_reactions", [
       %{
         comment_id: attrs["comment_id"],
         user_id: attrs["user_id"],
         reaction_type: attrs["reaction_type"],
         inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
         updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
       }
     ]) do
       {1, _} ->
         Phoenix.PubSub.broadcast(
           Frestyl.PubSub,
           "file_comments:#{get_file_id_from_comment(attrs["comment_id"])}",
           {:comment_reaction_updated, attrs["comment_id"]}
         )
         {:ok, :reaction_added}
       _ -> {:error, :failed_to_create}
     end

    {:ok, :reaction_added} # Return success for now
  end

  defp delete_comment_reaction(reaction) do
    # For now, return success since we haven't created the reactions table yet
    {:ok, :reaction_removed}
  end

  defp get_file_id_from_comment(comment_id) do
    from(c in Comment, where: c.id == ^comment_id, select: c.asset_id)
    |> Repo.one()
  end

  defp group_by_sessions(files) do
    files
    |> Enum.group_by(fn file ->
      # Extract session info from metadata or filename patterns
      get_session_identifier(file)
    end)
    |> Enum.reject(fn {session_id, _files} -> is_nil(session_id) end)
    |> Enum.map(fn {session_id, session_files} ->
      primary_file = find_primary_file(session_files)
      %{
        name: "Session #{session_id}",
        description: "Created during session #{session_id}",
        type: "session",
        primary_file_id: primary_file.id,
        file_ids: Enum.map(session_files, & &1.id),
        metadata: %{session_id: session_id, auto_created: true}
      }
    end)
  end

  defp group_by_albums(files) do
    files
    |> Enum.filter(fn file -> file.file_type == "audio" end)
    |> Enum.group_by(fn file ->
      # Extract album info from metadata
      get_in(file.metadata, ["album"]) ||
      extract_album_from_filename(file.filename)
    end)
    |> Enum.reject(fn {album, _files} -> is_nil(album) end)
    |> Enum.filter(fn {_album, files} -> length(files) > 1 end)
    |> Enum.map(fn {album, album_files} ->
      primary_file = find_primary_file(album_files)
      %{
        name: album,
        description: "Album with #{length(album_files)} tracks",
        type: "album",
        primary_file_id: primary_file.id,
        file_ids: Enum.map(album_files, & &1.id),
        metadata: %{album: album, track_count: length(album_files), auto_created: true}
      }
    end)
  end

defp group_by_time_proximity(files) do
    # Group files uploaded within 1 hour of each other
    sorted_files = files |> Enum.sort_by(& &1.inserted_at, NaiveDateTime)

    # Use reduce instead of chunk_while for more control
    grouped_files = sorted_files
    |> Enum.reduce([], fn file, groups ->
      case groups do
        [] ->
          # First file starts the first group
          [[file]]

        [current_group | rest_groups] ->
          last_file = List.last(current_group)

          # Calculate time difference
          time_diff = case {file.inserted_at, last_file.inserted_at} do
            {%DateTime{} = file_time, %DateTime{} = last_time} ->
              DateTime.diff(file_time, last_time, :second)
            {%NaiveDateTime{} = file_time, %NaiveDateTime{} = last_time} ->
              NaiveDateTime.diff(file_time, last_time, :second)
            {%NaiveDateTime{} = file_time, %DateTime{} = last_time} ->
              file_datetime = DateTime.from_naive!(file_time, "Etc/UTC")
              DateTime.diff(file_datetime, last_time, :second)
            {%DateTime{} = file_time, %NaiveDateTime{} = last_time} ->
              last_datetime = DateTime.from_naive!(last_time, "Etc/UTC")
              DateTime.diff(file_time, last_datetime, :second)
          end

          if time_diff <= 3600 do
            # Add to current group
            [current_group ++ [file] | rest_groups]
          else
            # Start new group
            [[file], current_group | rest_groups]
          end
      end
    end)
    |> Enum.reverse()  # Reverse to maintain chronological order
    |> Enum.filter(fn group -> length(group) > 2 end)  # Only groups with 3+ files

    # Convert to group data format
    grouped_files
    |> Enum.map(fn time_group ->
      primary_file = find_primary_file(time_group)

      # Handle date extraction safely
      date = case primary_file.inserted_at do
        %DateTime{} = dt -> DateTime.to_date(dt)
        %NaiveDateTime{} = ndt -> NaiveDateTime.to_date(ndt)
        _ -> Date.utc_today()  # Fallback
      end

      %{
        name: "Upload Session - #{date}",
        description: "#{length(time_group)} files uploaded together",
        type: "auto",
        primary_file_id: primary_file.id,
        file_ids: Enum.map(time_group, & &1.id),
        metadata: %{upload_date: date, auto_created: true}
      }
    end)
  end

  defp group_by_collaborations(files) do
    # Group files that share collaboration patterns
    files
    |> Enum.filter(fn file ->
      music_meta = get_music_metadata(file.id)
      music_meta && length(music_meta.collaborators || []) > 0
    end)
    |> Enum.group_by(fn file ->
      music_meta = get_music_metadata(file.id)
      Enum.sort(music_meta.collaborators || [])
    end)
    |> Enum.filter(fn {_collaborators, files} -> length(files) > 1 end)
    |> Enum.map(fn {collaborators, collab_files} ->
      primary_file = find_primary_file(collab_files)
      %{
        name: "Collaboration #{length(collaborators)} artists",
        description: "#{length(collab_files)} collaborative works",
        type: "collaboration",
        primary_file_id: primary_file.id,
        file_ids: Enum.map(collab_files, & &1.id),
        metadata: %{collaborators: collaborators, auto_created: true}
      }
    end)
  end

  defp find_primary_file(files) do
    # Prioritize by: largest file, most recent, or first alphabetically
    files
    |> Enum.sort_by(fn file ->
      # Handle both DateTime and NaiveDateTime
      inserted_at_comparable = case file.inserted_at do
        %DateTime{} = dt -> dt
        %NaiveDateTime{} = ndt -> DateTime.from_naive!(ndt, "Etc/UTC")
        _ -> DateTime.utc_now()  # Fallback
      end

      {-(file.file_size || 0), inserted_at_comparable, file.filename}
    end)
    |> List.first()
  end

  defp get_session_identifier(file) do
    # Extract session ID from metadata or filename patterns
    get_in(file.metadata, ["session_id"]) ||
    extract_session_from_filename(file.filename)
  end

  defp extract_session_from_filename(filename) do
    # Look for patterns like "session_123_", "Session 456", etc.
    case Regex.run(~r/session[_\s]*(\d+)/i, filename) do
      [_, session_id] -> session_id
      _ -> nil
    end
  end

  defp extract_album_from_filename(filename) do
    # Extract album info from common patterns
    cond do
      String.contains?(filename, " - ") ->
        filename |> String.split(" - ") |> List.first()
      String.contains?(filename, "_") ->
        filename |> String.split("_") |> List.first()
      true -> nil
    end
  end

  @doc """
  Creates a new media group with associated files.
  """
  def create_media_group(attrs, file_ids \\ []) do
    Repo.transaction(fn ->
      with {:ok, group} <- %MediaGroup{} |> MediaGroup.changeset(attrs) |> Repo.insert(),
           :ok <- associate_files_to_group(group.id, file_ids) do
        group
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp associate_files_to_group(group_id, file_ids) do
    file_ids
    |> Enum.with_index()
    |> Enum.each(fn {file_id, index} ->
      %MediaGroupFile{}
      |> MediaGroupFile.changeset(%{
        media_group_id: group_id,
        media_file_id: file_id,
        position: index,
        role: if(index == 0, do: "primary", else: "component")
      })
      |> Repo.insert!()
    end)
    :ok
  end

  # ==================
  # DISCUSSIONS
  # ==================

  @doc """
  Creates a discussion around a media file or group.
  """
  def create_media_discussion(attrs) do
    %MediaDiscussion{}
    |> MediaDiscussion.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets discussions for a media file or group.
  """
  def get_discussions_for_media(media_file_id: file_id) do
    from(d in MediaDiscussion,
      where: d.media_file_id == ^file_id,
      where: d.status == "active",
      preload: [:creator, discussion_messages: [:user]],
      order_by: [desc: d.is_pinned, desc: d.updated_at]
    )
    |> Repo.all()
  end

  def get_discussions_for_media(media_group_id: group_id) do
    from(d in MediaDiscussion,
      where: d.media_group_id == ^group_id,
      where: d.status == "active",
      preload: [:creator, discussion_messages: [:user]],
      order_by: [desc: d.is_pinned, desc: d.updated_at]
    )
    |> Repo.all()
  end

  @doc """
  Adds a message to a discussion.
  """
  def add_discussion_message(attrs) do
    %DiscussionMessage{}
    |> DiscussionMessage.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        # Broadcast real-time update
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "discussion:#{message.media_discussion_id}",
          {:new_message, message}
        )
        {:ok, message}
      error -> error
    end
  end

  # ==================
  # REACTIONS
  # ==================

  @doc """
  Adds or toggles a reaction to media.
  """
  def toggle_reaction(attrs) do
    case get_existing_reaction(attrs) do
      nil -> create_reaction(attrs)
      reaction -> delete_reaction(reaction)
    end
  end

  defp get_existing_reaction(%{user_id: user_id, reaction_type: type} = attrs) do
    query = from r in MediaReaction,
      where: r.user_id == ^user_id and r.reaction_type == ^type

    query = cond do
      Map.has_key?(attrs, :media_file_id) ->
        where(query, [r], r.media_file_id == ^attrs.media_file_id)
      Map.has_key?(attrs, :media_group_id) ->
        where(query, [r], r.media_group_id == ^attrs.media_group_id)
      Map.has_key?(attrs, :discussion_message_id) ->
        where(query, [r], r.discussion_message_id == ^attrs.discussion_message_id)
      true -> query
    end

    Repo.one(query)
  end

  defp create_reaction(attrs) do
    %MediaReaction{}
    |> MediaReaction.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, reaction} ->
        broadcast_reaction_update(reaction, :added)
        {:ok, reaction}
      error -> error
    end
  end

  defp delete_reaction(reaction) do
    case Repo.delete(reaction) do
      {:ok, deleted_reaction} ->
        broadcast_reaction_update(deleted_reaction, :removed)
        {:ok, deleted_reaction}
      error -> error
    end
  end

  defp broadcast_reaction_update(reaction, action) do
    topic = cond do
      reaction.media_file_id -> "media_file:#{reaction.media_file_id}"
      reaction.media_group_id -> "media_group:#{reaction.media_group_id}"
      reaction.discussion_message_id -> "discussion_message:#{reaction.discussion_message_id}"
      true -> nil
    end

    if topic do
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        topic,
        {:reaction_update, %{action: action, reaction: reaction}}
      )
    end
  end

  @doc """
  Gets reaction summary for media.
  """
  def get_reaction_summary(media_file_id: file_id) do
    reactions = from(r in MediaReaction,
      where: r.media_file_id == ^file_id,
      select: {r.reaction_type, r.user_id}
    ) |> Repo.all()

    build_reaction_summary(reactions)
  end

  def get_reaction_summary(media_group_id: group_id) do
    reactions = from(r in MediaReaction,
      where: r.media_group_id == ^group_id,
      select: {r.reaction_type, r.user_id}
    ) |> Repo.all()

    build_reaction_summary(reactions)
  end

  defp build_reaction_summary(reactions) do
    grouped = Enum.group_by(reactions, fn {type, _user} -> type end)

    %{
      total_reactions: length(reactions),
      reactions: Enum.map(grouped, fn {type, list} -> {type, length(list)} end) |> Enum.into(%{}),
      user_reactions: Enum.group_by(reactions, fn {_type, user} -> user end) |> Enum.map(fn {user, list} ->
        {user, Enum.map(list, fn {type, _} -> type end)}
      end) |> Enum.into(%{}),
      top_reaction: grouped |> Enum.max_by(fn {_type, list} -> length(list) end, fn -> nil end) |> case do
        {type, _} -> type
        nil -> nil
      end
    }
  end

  # ==================
  # THEME PREFERENCES
  # ==================

  @doc """
  Gets or creates user theme preferences.
  """
  defp create_default_theme_preferences(user_id) do
    {:ok, preferences} = %UserThemePreferences{}  # Changed from UserThemePreference
    |> UserThemePreferences.changeset(%{user_id: user_id})  # Changed from UserThemePreference
    |> Repo.insert()

    preferences
  end

  def update_user_theme_preferences(user_id, attrs) do
    get_user_theme_preferences(user_id)
    |> UserThemePreferences.changeset(attrs)  # Changed from UserThemePreference
    |> Repo.update()
  end

  def get_user_theme_preferences(user_id) do
    case Repo.get_by(UserThemePreferences, user_id: user_id) do  # Changed from UserThemePreference
      nil -> create_default_theme_preferences(user_id)
      preferences -> preferences
    end
  end

  # ==================
  # MUSIC METADATA
  # ==================

  @doc """
  Gets or creates music metadata for an audio file.
  """
  def get_music_metadata(media_file_id) do
    Repo.get_by(MusicMetadata, media_file_id: media_file_id)
  end

  @doc """
  Creates or updates music metadata.
  """
  def upsert_music_metadata(media_file_id, attrs) do
    case get_music_metadata(media_file_id) do
      nil ->
        %MusicMetadata{}
        |> MusicMetadata.changeset(Map.put(attrs, :media_file_id, media_file_id))
        |> Repo.insert()
      existing ->
        existing
        |> MusicMetadata.changeset(attrs)
        |> Repo.update()
    end
  end

  # ==================
  # VIEW HISTORY & ANALYTICS
  # ==================

  @doc """
  Records a view event for analytics.
  """
  def record_view(attrs) do
    # Skip updating view_count since the field doesn't exist in MediaFile schema
    # Just record detailed view history
    %ViewHistory{}
    |> ViewHistory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets personalized recommendations based on view history.
  """
  def get_recommendations_for_user(user_id, limit \\ 10) do
    # Get user's view patterns
    viewed_files = from(vh in ViewHistory,
      where: vh.user_id == ^user_id,
      where: not is_nil(vh.media_file_id),
      select: vh.media_file_id,
      distinct: true
    ) |> Repo.all()

    # Get similar files based on tags, channels, and metadata
    from(mf in MediaFile,
      where: mf.id not in ^viewed_files,
      where: mf.status == "active",
      left_join: mft in "media_files_tags", on: mft.media_file_id == mf.id,
      left_join: t in "tags", on: t.id == mft.tag_id,
      group_by: mf.id,
      order_by: [desc: mf.engagement_score, desc: mf.view_count],
      limit: ^limit,
      preload: [:user, :channel]
    )
    |> Repo.all()
  end

  # ==================
  # ENHANCED MEDIA FILES
  # ==================

  @doc """
  Gets media files for discovery interface with intelligent grouping.
  """
  def get_discovery_data_for_user(user_id, opts \\ []) do
    # Get user's theme preferences
    theme_prefs = get_user_theme_preferences(user_id)

    # Get accessible files based on user permissions
    files = list_accessible_media_files(user_id, opts)

    # Get intelligent groups
    groups = get_media_groups_for_user(user_id, opts)

    # Build discovery cards (mix of individual files and groups)
    cards = build_discovery_cards(files, groups)

    %{
      cards: cards,
      theme_preferences: theme_prefs,
      total_files: length(files),
      total_groups: length(groups),
      recommendations: get_recommendations_for_user(user_id, 5)
    }
  end

defp list_accessible_media_files(user_id, opts) do
    channel_id = opts[:channel_id]
    file_type = opts[:file_type]
    search_query = opts[:search]

    # First get channels user has access to
    accessible_channel_ids = from(cm in "channel_memberships",
      where: cm.user_id == ^user_id and cm.status == "active",
      select: cm.channel_id
    ) |> Repo.all()

    # Build main query for accessible files
    query = from mf in MediaFile,
      where: mf.status == "active",
      where: mf.user_id == ^user_id or mf.channel_id in ^accessible_channel_ids,
      preload: [:user, :channel],
      order_by: [desc: mf.updated_at]

    query = if channel_id, do: where(query, [mf], mf.channel_id == ^channel_id), else: query
    query = if file_type, do: where(query, [mf], mf.file_type == ^file_type), else: query

    query = if search_query do
      search_term = "%#{search_query}%"
      where(query, [mf],
        ilike(mf.filename, ^search_term) or
        ilike(mf.title, ^search_term) or
        ilike(mf.description, ^search_term)
      )
    else
      query
    end

    Repo.all(query)
  end

  defp build_discovery_cards(files, groups) do
    # Create cards for grouped files
    group_cards = Enum.map(groups, fn group ->
      %{
        type: :group,
        id: "group_#{group.id}",
        data: group,
        primary_file: group.primary_file,
        file_count: length(group.media_files),
        expanded: group.auto_expand
      }
    end)

    # Create cards for ungrouped files
    grouped_file_ids = groups
    |> Enum.flat_map(& &1.media_files)
    |> Enum.map(& &1.id)
    |> MapSet.new()

    individual_cards = files
    |> Enum.reject(fn file -> MapSet.member?(grouped_file_ids, file.id) end)
    |> Enum.map(fn file ->
      %{
        type: :individual,
        id: "file_#{file.id}",
        data: file,
        primary_file: file
      }
    end)

    # Shuffle for discovery variety
    (group_cards ++ individual_cards) |> Enum.shuffle()
  end

  @doc """
  Lists media files for a user with enhanced metadata.
  """
  def list_media_files_for_user(user_id, opts \\ []) do
    from(mf in MediaFile,
      where: mf.user_id == ^user_id,
      where: mf.status == "active",
      preload: [:user, :channel],
      order_by: [desc: mf.updated_at]
    )
    |> apply_media_filters(opts)
    |> Repo.all()
  end

  defp apply_media_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:channel_id, nil}, q -> q
      {:channel_id, channel_id}, q -> where(q, [mf], mf.channel_id == ^channel_id)
      {:file_type, type}, q -> where(q, [mf], mf.file_type == ^type)
      {:limit, limit}, q -> limit(q, ^limit)
      {_key, _value}, q -> q
    end)
  end

  # ==================
  # PUBSUB SUBSCRIPTIONS
  # ==================

  @doc """
  Subscribes to real-time updates for media discussions.
  """
  def subscribe_to_discussion(discussion_id) do
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "discussion:#{discussion_id}")
  end

  @doc """
  Subscribes to real-time reaction updates.
  """
  def subscribe_to_media_reactions(media_file_id: file_id) do
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "media_file:#{file_id}")
  end

  def subscribe_to_media_reactions(media_group_id: group_id) do
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "media_group:#{group_id}")
  end

    @doc """
  Get media groups formatted for the discovery interface with planetary relationships
  """
  def list_media_groups_for_discovery(user_id, opts \\ %{}) do
    limit = Map.get(opts, :limit, 20)
    offset = Map.get(opts, :offset, 0)
    filter_type = Map.get(opts, :filter_type)
    sort_by = Map.get(opts, :sort_by, "recent")
    search = Map.get(opts, :search)

    base_query = from(mg in MediaGroup,
      join: pf in MediaFile, on: pf.id == mg.primary_file_id,
      join: u in User, on: u.id == mg.user_id,
      left_join: mgf in MediaGroupFile, on: mgf.media_group_id == mg.id,
      left_join: sf in MediaFile, on: sf.id == mgf.media_file_id,
      left_join: mm in MusicMetadata, on: mm.media_file_id == pf.id,
      left_join: mr in MediaReaction, on: mr.media_group_id == mg.id,
      left_join: md in MediaDiscussion, on: md.media_group_id == mg.id,
      left_join: vh in ViewHistory, on: vh.media_group_id == mg.id,
      where: mg.user_id == ^user_id or mg.visibility == "public",
      group_by: [mg.id, pf.id, u.id, mm.id],
      select: %{
        id: mg.id,
        title: mg.title,
        description: mg.description,
        visibility: mg.visibility,
        collaboration_enabled: mg.collaboration_enabled,
        tags: mg.tags,
        inserted_at: mg.inserted_at,
        updated_at: mg.updated_at,
        primary_file: %{
          id: pf.id,
          title: pf.title,
          original_filename: pf.original_filename,
          file_type: pf.file_type,
          file_path: pf.file_path,
          size: pf.size,
          thumbnail_path: pf.thumbnail_path,
          music_metadata: mm
        },
        creator: %{
          id: u.id,
          name: u.name,
          username: u.username,
          avatar_url: u.avatar_url
        },
        satellite_count: count(mgf.id),
        reaction_count: count(mr.id),
        discussion_count: count(md.id),
        view_count: count(vh.id)
      }
    )

    # Apply filters
    query = base_query
    |> apply_discovery_filters(filter_type, search)
    |> apply_discovery_sorting(sort_by)

    # Get total count for pagination
    total_count = query |> Repo.aggregate(:count, :id)

    # Get paginated results
    groups = query
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> load_discovery_associations()

    %{
      groups: groups,
      total_count: total_count,
      has_more: offset + limit < total_count
    }
  end

  @doc """
  Get a specific media group with all planetary data (primary file + satellites)
  """
  def get_media_group_with_planetary_data(group_id, user_id) do
    query = from(mg in MediaGroup,
      join: pf in MediaFile, on: pf.id == mg.primary_file_id,
      join: u in User, on: u.id == mg.user_id,
      left_join: mgf in MediaGroupFile, on: mgf.media_group_id == mg.id,
      left_join: sf in MediaFile, on: sf.id == mgf.media_file_id,
      left_join: mm in MusicMetadata, on: mm.media_file_id == pf.id,
      left_join: collab in Collaboration, on: collab.media_group_id == mg.id,
      left_join: collab_user in User, on: collab_user.id == collab.user_id,
      where: mg.id == ^group_id,
      where: mg.user_id == ^user_id or mg.visibility == "public"
    )

    case Repo.one(query) do
      nil -> nil
      group ->
        # Load associations separately to avoid preload issues
        media_group_files = from(mgf in MediaGroupFile,
          join: mf in MediaFile, on: mf.id == mgf.media_file_id,
          where: mgf.media_group_id == ^group_id,
          select: %{mgf | media_file: mf}
        ) |> Repo.all()

        collaborations = from(c in Collaboration,
          join: u in User, on: u.id == c.user_id,
          where: c.media_group_id == ^group_id,
          select: %{c | user: u}
        ) |> Repo.all()

        discussions = from(md in MediaDiscussion,
          left_join: dm in DiscussionMessage, on: dm.media_discussion_id == md.id,
          left_join: u in User, on: u.id == dm.user_id,
          where: md.media_group_id == ^group_id
        ) |> Repo.all()

        reactions = from(mr in MediaReaction,
          join: u in User, on: u.id == mr.user_id,
          where: mr.media_group_id == ^group_id
        ) |> Repo.all()

        # Get primary file with music metadata
        primary_file = from(mf in MediaFile,
          left_join: mm in MusicMetadata, on: mm.media_file_id == mf.id,
          where: mf.id == ^group.primary_file_id,
          select: %{mf | music_metadata: mm}
        ) |> Repo.one()

        %{
          id: group.id,
          title: group.title,
          description: group.description,
          visibility: group.visibility,
          collaboration_enabled: group.collaboration_enabled,
          tags: group.tags,
          inserted_at: group.inserted_at,
          updated_at: group.updated_at,
          primary_file: primary_file,
          satellites: media_group_files,
          creator: group.user,
          collaborators: Enum.map(collaborations, & &1.user),
          discussions: discussions,
          reactions: reactions,
          reaction_summary: calculate_reaction_summary(reactions),
          view_count: get_group_view_count(group.id)
        }
    end
  end

  @doc """
  Get suggested next planets based on user behavior and content similarity
  """
  def get_suggested_next_planets(current_planet_id, user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    # Get current planet info for similarity matching
    current_planet = get_media_group_with_planetary_data(current_planet_id, user_id)

    if current_planet do
      suggestions = []

      # 1. Same genre/style suggestions
      genre_suggestions = get_genre_based_suggestions(current_planet, user_id, 2)

      # 2. Same creator suggestions
      creator_suggestions = get_creator_based_suggestions(current_planet, user_id, 2)

      # 3. Collaborative filtering (users who liked this also liked...)
      collaborative_suggestions = get_collaborative_suggestions(current_planet_id, user_id, 2)

      # 4. Recent activity suggestions
      activity_suggestions = get_activity_based_suggestions(user_id, 1)

      (suggestions ++ genre_suggestions ++ creator_suggestions ++
       collaborative_suggestions ++ activity_suggestions)
      |> Enum.uniq_by(& &1.id)
      |> Enum.take(limit)
    else
      []
    end
  end

  @doc """
  Record a view for analytics and recommendation purposes
  """
  def record_view(media_group_id, user_id, metadata \\ %{}) do
    attrs = %{
      media_group_id: media_group_id,
      user_id: user_id,
      viewed_at: DateTime.utc_now(),
      session_id: metadata[:session_id],
      device_type: metadata[:device_type],
      source: metadata[:source] || "discovery",
      duration_seconds: metadata[:duration_seconds]
    }

    %ViewHistory{}
    |> ViewHistory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Get user's navigation history for back/forward functionality
  """
  def get_user_navigation_history(user_id, limit \\ 50) do
    from(vh in ViewHistory,
      join: mg in MediaGroup, on: mg.id == vh.media_group_id,
      join: pf in MediaFile, on: pf.id == mg.primary_file_id,
      where: vh.user_id == ^user_id,
      order_by: [desc: vh.viewed_at],
      limit: ^limit,
      select: %{
        id: mg.id,
        title: mg.title,
        primary_file_type: pf.file_type,
        viewed_at: vh.viewed_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Get recent media for theme suggestions
  """
  def get_recent_user_media(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    from(vh in ViewHistory,
      join: mg in MediaGroup, on: mg.id == vh.media_group_id,
      join: pf in MediaFile, on: pf.id == mg.primary_file_id,
      left_join: mm in MusicMetadata, on: mm.media_file_id == pf.id,
      where: vh.user_id == ^user_id,
      order_by: [desc: vh.viewed_at],
      limit: ^limit,
      select: %{
        id: mg.id,
        primary_file: pf,
        music_metadata: mm,
        viewed_at: vh.viewed_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Check if user is following a planet (for notifications)
  """
  def is_following_planet?(planet_id, user_id) do
    # Implement following logic based on your schema
    # This could be reactions, saved items, or dedicated follows
    from(mr in MediaReaction,
      where: mr.media_group_id == ^planet_id,
      where: mr.user_id == ^user_id,
      where: mr.reaction_type == "follow"
    )
    |> Repo.exists?()
  end

  @doc """
  Get collaboration status for a user on a planet
  """
  def get_collaboration_status(planet_id, user_id) do
    case Repo.get_by(Collaboration, media_group_id: planet_id, user_id: user_id) do
      nil -> %{status: "none", role: nil}
      collab -> %{status: "active", role: collab.role, permissions: collab.permissions}
    end
  end

  # Private helper functions

  defp apply_discovery_filters(query, filter_type, search) do
    query
    |> filter_by_type(filter_type)
    |> filter_by_search(search)
  end

  defp filter_by_type(query, nil), do: query
  defp filter_by_type(query, type) do
    from([mg, pf, ...] in query,
      where: pf.file_type == ^type
    )
  end

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, search) when is_binary(search) do
    search_term = "%#{search}%"
    from([mg, pf, ...] in query,
      where: ilike(mg.title, ^search_term) or
             ilike(pf.title, ^search_term) or
             ilike(pf.original_filename, ^search_term)
    )
  end

  defp apply_discovery_sorting(query, sort_by) do
    case sort_by do
      "recent" -> order_by(query, [mg, ...], desc: mg.updated_at)
      "popular" ->
        # For popular sorting, we need to count reactions in a subquery
        from([mg, pf, u, mgf, sf, mm, mr, md, vh] in query,
          group_by: [mg.id, pf.id, u.id, mm.id],
          order_by: [desc: count(mr.id)]
        )
      "title" -> order_by(query, [mg, ...], asc: mg.title)
      "oldest" -> order_by(query, [mg, ...], asc: mg.inserted_at)
      _ -> order_by(query, [mg, ...], desc: mg.updated_at)
    end
  end

  defp load_discovery_associations(groups) do
    Enum.map(groups, fn group ->
      # Load satellites for each group
      satellites = from(mgf in MediaGroupFile,
        join: sf in MediaFile, on: sf.id == mgf.media_file_id,
        where: mgf.media_group_id == ^group.id,
        order_by: [asc: mgf.position],
        select: %{
          id: sf.id,
          title: sf.title,
          file_type: sf.file_type,
          relationship_type: mgf.relationship_type,
          position: mgf.position,
          media_file: sf
        }
      ) |> Repo.all()

      # Load recent reactions
      recent_reactions = from(mr in MediaReaction,
        join: u in User, on: u.id == mr.user_id,
        where: mr.media_group_id == ^group.id,
        order_by: [desc: mr.inserted_at],
        limit: 5,
        select: %{
          reaction_type: mr.reaction_type,
          user: %{name: u.name, avatar_url: u.avatar_url},
          inserted_at: mr.inserted_at
        }
      ) |> Repo.all()

      Map.merge(group, %{
        media_group_files: satellites,
        reaction_summary: %{
          total_count: group.reaction_count,
          recent_reactions: recent_reactions
        }
      })
    end)
  end

  defp calculate_reaction_summary(reactions) do
    by_type = Enum.group_by(reactions, & &1.reaction_type)

    %{
      total_count: length(reactions),
      by_type: Map.new(by_type, fn {type, reactions} -> {type, length(reactions)} end),
      recent_reactions: Enum.take(reactions, 5)
    }
  end

  defp get_group_view_count(group_id) do
    from(vh in ViewHistory,
      where: vh.media_group_id == ^group_id,
      select: count(vh.id)
    )
    |> Repo.one() || 0
  end

  defp get_genre_based_suggestions(current_planet, user_id, limit) do
    genre = case current_planet.primary_file.music_metadata do
      %{genre: genre} when not is_nil(genre) -> genre
      _ -> nil
    end

    if genre do
      from(mg in MediaGroup,
        join: pf in MediaFile, on: pf.id == mg.primary_file_id,
        join: mm in MusicMetadata, on: mm.media_file_id == pf.id,
        where: mg.id != ^current_planet.id,
        where: mg.user_id == ^user_id or mg.visibility == "public",
        where: mm.genre == ^genre,
        order_by: [desc: mg.updated_at],
        limit: ^limit
      )
      |> Repo.all()
    else
      []
    end
  end

  defp get_creator_based_suggestions(current_planet, user_id, limit) do
    creator_id = current_planet.creator.id

    from(mg in MediaGroup,
      where: mg.user_id == ^creator_id,
      where: mg.id != ^current_planet.id,
      where: mg.user_id == ^user_id or mg.visibility == "public",
      order_by: [desc: mg.updated_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  defp get_collaborative_suggestions(planet_id, user_id, limit) do
    # Users who reacted to this planet
    similar_users = from(mr in MediaReaction,
      where: mr.media_group_id == ^planet_id,
      where: mr.user_id != ^user_id,
      select: mr.user_id,
      distinct: true
    ) |> Repo.all()

    # Get planets those users also liked
    from(mg in MediaGroup,
      join: mr in MediaReaction, on: mr.media_group_id == mg.id,
      where: mr.user_id in ^similar_users,
      where: mg.id != ^planet_id,
      where: mg.visibility == "public",
      group_by: mg.id,
      order_by: [desc: count(mr.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  defp get_activity_based_suggestions(user_id, limit) do
    # Get recently viewed planets by user
    from(mg in MediaGroup,
      join: vh in ViewHistory, on: vh.media_group_id == mg.id,
      where: vh.user_id == ^user_id,
      where: mg.visibility == "public",
      order_by: [desc: vh.viewed_at],
      limit: ^limit,
      distinct: true
    )
    |> Repo.all()
  end
end
