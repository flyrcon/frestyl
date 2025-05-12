# lib/frestyl/media.ex
defmodule Frestyl.Media do
  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Media.{MediaFile, ThumbnailProcessor, VideoTranscoder}
  alias Frestyl.Storage
  alias Frestyl.Media.MediaItem

  @doc """
  Creates a new media file from an uploaded file.
  """
  def create_file(attrs, uploaded_file_path) do
    # Determine media type from content type
    media_type = determine_media_type(attrs[:content_type] || attrs["content_type"])

    # Generate a unique filename for storage
    original_filename = attrs[:original_filename] || attrs["original_filename"] || attrs[:filename] || attrs["filename"]
    filename = generate_unique_filename(original_filename)

    # Set up storage path - maintaining compatibility with your current approach
    # and providing upgrade path to Storage module
    destination_path = if function_exported?(Storage, :generate_key, 2) do
      # Use new Storage module if available
      key = Storage.generate_key(original_filename)

      case Storage.upload(uploaded_file_path, key, content_type: attrs[:content_type] || attrs["content_type"]) do
        {:ok, file_url} ->
          # File uploaded to storage, return the URL
          {:ok, file_url}
        _ ->
          # Fall back to your existing method
          upload_path = Application.get_env(:frestyl, :upload_path, "priv/static/uploads")
          dest_path = Path.join(upload_path, filename)
          File.cp!(uploaded_file_path, dest_path)
          {:ok, dest_path}
      end
    else
      # Use your existing method
      upload_path = Application.get_env(:frestyl, :upload_path, "priv/static/uploads")
      File.mkdir_p!(upload_path)
      dest_path = Path.join(upload_path, filename)
      File.cp!(uploaded_file_path, dest_path)
      {:ok, dest_path}
    end

    case destination_path do
      {:ok, file_path} ->
        # Create media file record
        %MediaFile{}
        |> MediaFile.changeset(Map.merge(attrs, %{
          filename: filename,
          original_filename: original_filename,
          media_type: media_type,
          file_path: file_path,
          storage_type: determine_storage_type(),
          status: "processing"
        }))
        |> Repo.insert()
        |> broadcast_created() # Add this line
        |> case do
          {:ok, media_file} ->
            # Process the file asynchronously
            Task.start(fn ->
              processed_media_file = process_media_file(media_file)
              # Broadcast update when processing is done - fixed this line
              # Instead of using broadcast_updated/2, we'll use broadcast/2 directly
              # since we have the processed file
              case processed_media_file do
                {:ok, updated_file} ->
                  broadcast({:ok, updated_file}, :media_file_processed)
                _ ->
                  nil
              end
            end)
            {:ok, media_file}
          error -> error
        end

      error -> error
    end
  end

  @doc """
  Lists media items for a channel, filtered by category.
  """
  def list_channel_media_by_category(channel_id, category \\ nil, opts \\ []) do
    limit = Keyword.get(opts, :limit)

    query = from m in MediaItem,
            where: m.channel_id == ^channel_id,
            order_by: [desc: m.inserted_at]

    query = if category do
      where(query, [m], m.category == ^category)
    else
      query
    end

    query = if limit do
      limit(query, ^limit)
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  List files for a channel (backward compatibility function)
  """
  def list_channel_files(channel_id) do
    list_channel_media_by_category(channel_id)
  end

  @doc """
  Changes a media item's category.
  """
  def update_media_category(%MediaItem{} = media_item, category)
      when category in [:branding, :presentation, :performance, :general] do

    media_item
    |> MediaItem.changeset(%{category: category})
    |> Repo.update()
    |> broadcast_updated()
  end

  @doc """
  Subscribe to channel-specific media events.
  """
  def subscribe_to_channel(channel_id) do
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel_id}:media")
  end

  @doc """
  Check if a user can manage media in a channel.
  """
  def can_manage_media?(user_id, channel_id) do
    # Check if the user is an admin or moderator in the channel
    Repo.exists?(
      from m in Frestyl.Channels.ChannelMembership,
      where: m.user_id == ^user_id and m.channel_id == ^channel_id and
            (m.role in ["admin", "moderator"] or m.can_upload_files == true)
    )
  end

  # Update media item
  def update_media_file(%MediaItem{} = media_item, attrs) do
    result = media_item
    |> MediaItem.changeset(attrs)
    |> Repo.update()

    case result do
      {:ok, updated_item} ->
        # Invalidate the cache for this media item
        Frestyl.Cache.invalidate("media_file:#{updated_item.id}")
        Frestyl.Cache.invalidate_by_prefix("media_url:#{updated_item.id}")
        {:ok, updated_item}

      error ->
        error
    end
  end

  def delete_media_file(%MediaItem{} = media_item) do
    result = Repo.delete(media_item)

    case result do
      {:ok, deleted_item} ->
        # Invalidate cache for this media item
        Frestyl.Cache.invalidate("media_file:#{deleted_item.id}")
        Frestyl.Cache.invalidate_by_prefix("media_url:#{deleted_item.id}")
        {:ok, deleted_item}

      error ->
        error
    end
  end

  @doc """
  Process an uploaded file. This maintains compatibility with your existing code
  while providing a path to use the new processing functionality.
  """
  def process_upload(entry, user) do
    # This function can be expanded to use the new thumbnail and processing logic
    # while maintaining backward compatibility with your existing LiveView code

    # In the original implementation this would likely do something
    # This is a placeholder that will be replaced with your actual implementation
    {:ok, %{id: 1, filename: entry.client_name}}
  end

  @doc """
  Process a media file, extracting metadata and generating thumbnails.
  """
  def process_media_file(%MediaFile{} = media_file) do
    # Extract metadata
    metadata = extract_metadata(media_file)

    # Generate thumbnails
    thumbnail_data = if function_exported?(ThumbnailProcessor, :process, 1) do
      ThumbnailProcessor.process(media_file)
    else
      # Fallback if the new ThumbnailProcessor isn't available yet
      %{}
    end

    # Update the media file with metadata and thumbnail data
    result = media_file
    |> MediaFile.changeset(Map.merge(metadata, thumbnail_data))
    |> MediaFile.changeset(%{status: "active"})
    |> Repo.update()

    # If it's a video and we have the transcoder available, start transcoding
    if media_file.media_type == "video" && function_exported?(VideoTranscoder, :transcode, 1) do
      Task.start(fn -> VideoTranscoder.transcode(media_file) end)
    end

    # Return the update result
    result
  end

  @doc """
  Extract metadata from a media file based on its type.
  """
  def extract_metadata(%MediaFile{} = media_file) do
    case media_file.media_type do
      "image" -> extract_image_metadata(media_file)
      "video" -> extract_video_metadata(media_file)
      "audio" -> extract_audio_metadata(media_file)
      _ -> %{}
    end
  end

  defp extract_image_metadata(%MediaFile{} = media_file) do
    case System.cmd("identify", ["-format", "%w %h", media_file.file_path], stderr_to_stdout: true) do
      {output, 0} ->
        [width_str, height_str] = String.split(String.trim(output))
        {width, _} = Integer.parse(width_str)
        {height, _} = Integer.parse(height_str)

        %{
          width: width,
          height: height,
          metadata: %{
            format: Path.extname(media_file.filename)
          }
        }
      _ -> %{}
    end
  end

  defp extract_video_metadata(%MediaFile{} = media_file) do
    case System.cmd("ffprobe", [
      "-v", "quiet",
      "-print_format", "json",
      "-show_format",
      "-show_streams",
      media_file.file_path
    ], stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, json} ->
            format = json["format"]
            video_stream = Enum.find(json["streams"] || [], fn stream ->
              Map.get(stream, "codec_type") == "video"
            end)

            if video_stream do
              %{
                width: video_stream["width"],
                height: video_stream["height"],
                duration: format["duration"] && (String.to_float(format["duration"]) * 1000) |> round(),
                metadata: %{
                  format: format["format_name"],
                  bitrate: format["bit_rate"],
                  codec: video_stream["codec_name"],
                  framerate: video_stream["r_frame_rate"]
                }
              }
            else
              %{}
            end
          _ -> %{}
        end
      _ -> %{}
    end
  end

  defp extract_audio_metadata(%MediaFile{} = media_file) do
    case System.cmd("ffprobe", [
      "-v", "quiet",
      "-print_format", "json",
      "-show_format",
      media_file.file_path
    ], stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, json} ->
            format = json["format"]

            %{
              duration: format["duration"] && (String.to_float(format["duration"]) * 1000) |> round(),
              metadata: %{
                format: format["format_name"],
                bitrate: format["bit_rate"]
              }
            }
          _ -> %{}
        end
      _ -> %{}
    end
  end

  @doc """
  Determine the media type from the content type.
  """
  def determine_media_type(content_type) when is_binary(content_type) do
    cond do
      String.starts_with?(content_type, "image/") -> "image"
      String.starts_with?(content_type, "video/") -> "video"
      String.starts_with?(content_type, "audio/") -> "audio"
      String.match?(content_type, ~r/application\/(pdf|msword|vnd\.openxmlformats|vnd\.ms)/) -> "document"
      true -> "other"
    end
  end
  def determine_media_type(_), do: "other"

  @doc """
  Determine the storage type based on configuration.
  """
  defp determine_storage_type do
    case Application.get_env(:frestyl, :storage_type, "local") do
      "s3" -> "s3"
      :s3 -> "s3"
      _ -> "local"
    end
  end

  @doc """
  Generate a unique filename for a file.
  """
  defp generate_unique_filename(original_filename) do
    extension = Path.extname(original_filename)
    basename = Path.basename(original_filename, extension)
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random_suffix = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

    "#{basename}_#{timestamp}_#{random_suffix}#{extension}"
  end

  # CRUD operations for MediaFile


  @doc """
  Gets the URL for a media file, with caching.
  """
  def get_media_url(%MediaItem{} = media_item) do
    cache_key = "media_url:#{media_item.id}"

    case Frestyl.Cache.get(cache_key) do
      {:ok, url} ->
        url

      :error ->
        url = generate_media_url(media_item)
        Frestyl.Cache.put(cache_key, url)
        url
    end
  end

  # Private function to generate the actual URL
  defp generate_media_url(%MediaItem{} = media_item) do
    cond do
      media_item.storage_type == "s3" ->
        # Generate S3 presigned URL with short expiration
        config = Application.get_env(:frestyl, :s3)
        bucket = config[:bucket]

        {:ok, url} = ExAws.S3.presigned_url(
          ExAws.Config.new(:s3),
          :get,
          bucket,
          media_item.file_path,
          expires_in: 3600 # 1 hour
        )
        url

      media_item.storage_type == "local" ->
        # Generate local URL
        "/uploads/#{media_item.file_path}"

      true ->
        media_item.file_url
    end
  end

  @doc """
  Lists media files with optional filters.
  """
  def list_media_files(filters \\ []) do
    MediaFile
    |> filter_by_user(filters[:user_id])
    |> filter_by_channel(filters[:channel_id])
    |> filter_by_folder(filters[:folder_id])
    |> filter_by_media_type(filters[:media_type])
    |> filter_by_status(filters[:status])
    |> filter_by_search(filters[:search])
    |> order_by_field(filters[:order_by] || [desc: :inserted_at])
    |> Repo.all()
  end

  defp filter_by_user(query, nil), do: query
  defp filter_by_user(query, user_id), do: where(query, [m], m.user_id == ^user_id)

  defp filter_by_channel(query, nil), do: query
  defp filter_by_channel(query, channel_id), do: where(query, [m], m.channel_id == ^channel_id)

  defp filter_by_folder(query, nil), do: query
  defp filter_by_folder(query, folder_id), do: where(query, [m], m.folder_id == ^folder_id)

  defp filter_by_media_type(query, nil), do: query
  defp filter_by_media_type(query, media_type), do: where(query, [m], m.media_type == ^media_type)

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status), do: where(query, [m], m.status == ^status)

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, search) do
    search_term = "%#{search}%"
    where(query, [m], ilike(m.original_filename, ^search_term) or
                      ilike(m.title, ^search_term) or
                      ilike(m.description, ^search_term))
  end

  defp order_by_field(query, order), do: order_by(query, ^order)

  @doc """
  Updates a media file.
  """
  def update_media_file(%MediaFile{} = media_file, attrs) do
    media_file
    |> MediaFile.changeset(attrs)
    |> Repo.update()
    |> broadcast_updated() # Add this line
  end

  @doc """
  Deletes a media file.
  """
  def delete_media_file(%MediaFile{} = media_file) do
    # Delete the file from storage
    if function_exported?(Storage, :delete, 1) do
      Storage.delete(media_file.file_path)
    else
      # Fallback to direct file deletion
      if media_file.storage_type == "local" do
        File.rm(media_file.file_path)

    # Delete from database
    Repo.delete(media_file)
    |> broadcast_deleted() # Add this line
    end
  end

    # Delete thumbnails if they exist
    if media_file.thumbnails && map_size(media_file.thumbnails) > 0 do
      if function_exported?(Storage, :delete, 1) do
        Enum.each(media_file.thumbnails, fn {_size, url} ->
          Storage.delete(url)
        end)
      else
        # Fallback for local storage
        if media_file.storage_type == "local" do
          Enum.each(media_file.thumbnails, fn {_size, path} ->
            File.rm(path)
          end)
        end
      end
    end

    # Delete from database
    Repo.delete(media_file)
  end

  # Tag related functions

  @doc """
  Adds tags to a media file.
  """
  def add_tags_to_media_file(%MediaFile{} = media_file, tag_ids) when is_list(tag_ids) do
    alias Frestyl.Media.Tag
    tags = Repo.all(from t in Tag, where: t.id in ^tag_ids)

    # Get existing tags
    existing_tags = Repo.preload(media_file, :tags).tags

    # Merge tags
    all_tags = existing_tags ++ tags |> Enum.uniq_by(& &1.id)

    # Update associations
    media_file
    |> MediaFile.tag_changeset(all_tags)
    |> Repo.update()
  end

  @doc """
  Removes tags from a media file.
  """
  def remove_tags_from_media_file(%MediaFile{} = media_file, tag_ids) when is_list(tag_ids) do
    # Get existing tags
    existing_tags = Repo.preload(media_file, :tags).tags

    # Filter out tags to remove
    remaining_tags = Enum.filter(existing_tags, fn tag -> tag.id not in tag_ids end)

    # Update associations
    media_file
    |> MediaFile.tag_changeset(remaining_tags)
    |> Repo.update()
  end

  @doc """
  Moves a media file to a folder.
  """
  def move_to_folder(%MediaFile{} = media_file, folder_id) do
    media_file
    |> MediaFile.changeset(%{folder_id: folder_id})
    |> Repo.update()
  end

  # lib/frestyl/media.ex - add these functions at the bottom
  @doc """
  Subscribes the current process to media file updates.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "media")
  end

  @doc """
  Broadcasts a media file update to all subscribers.
  """
  def broadcast({:ok, media_file} = result, event) do
    Phoenix.PubSub.broadcast(Frestyl.PubSub, "media", {event, media_file})
    result
  end
  def broadcast({:error, _} = result, _event), do: result

  @doc """
  Broadcasts when a media file is created.
  """
  def broadcast_created(result), do: broadcast(result, :media_file_created)

  @doc """
  Broadcasts when a media file is updated.
  """
  def broadcast_updated(result), do: broadcast(result, :media_file_updated)

  @doc """
  Broadcasts when a media file is deleted.
  """
  def broadcast_deleted(result), do: broadcast(result, :media_file_deleted)

  # lib/frestyl/media.ex - add these functions at the bottom
  @doc """
  Subscribes the current process to media file updates.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "media")
  end

  @doc """
  Broadcasts a media file update to all subscribers.
  """
  def broadcast({:ok, media_file} = result, event) do
    Phoenix.PubSub.broadcast(Frestyl.PubSub, "media", {event, media_file})
    result
  end
  def broadcast({:error, _} = result, _event), do: result

  @doc """
  Broadcasts when a media file is created.
  """
  def broadcast_created(result), do: broadcast(result, :media_file_created)

  @doc """
  Broadcasts when a media file is updated.
  """
  def broadcast_updated(result), do: broadcast(result, :media_file_updated)

  @doc """
  Broadcasts when a media file is deleted.
  """
  def broadcast_deleted(result), do: broadcast(result, :media_file_deleted)
end
