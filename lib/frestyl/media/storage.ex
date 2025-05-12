# lib/frestyl/media/storage.ex
defmodule Frestyl.Media.Storage do
  @moduledoc """
  Handles file storage and retrieval for media files.
  """

  alias Frestyl.Media.FileStorage
  alias Frestyl.Media.MediaFile
  alias Frestyl.Media

  @doc """
  Store a file and create a media file record.
  """
  def store_file(upload_params, user_id, channel_id \\ nil) do
    # Determine media type from content type
    media_type = determine_media_type(upload_params.content_type)

    # Prepare attrs for storage
    storage_attrs = %{
      filename: upload_params.filename,
      original_filename: upload_params.filename,
      content_type: upload_params.content_type,
      channel_id: channel_id
    }

    # Store the file using the appropriate storage method
    storage_result =
      if Application.get_env(:frestyl, :use_s3, false) do
        FileStorage.store_on_s3(upload_params, storage_attrs)
      else
        FileStorage.store_locally(upload_params, storage_attrs)
      end

    case storage_result do
      {:ok, storage_data} ->
        # Create a new media file record
        media_file_attrs = %{
          filename: Path.basename(storage_data.file_path),
          original_filename: upload_params.filename,
          content_type: upload_params.content_type,
          file_size: upload_params.size,
          media_type: media_type,
          file_path: storage_data.file_path,
          storage_type: storage_data.storage_type,
          user_id: user_id,
          channel_id: channel_id,
          status: "active",
          title: Path.rootname(upload_params.filename)
        }

        Media.create_media_file(media_file_attrs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Delete a media file and its storage.
  """
  def delete_file(%MediaFile{} = media_file) do
    # Delete the file from storage
    storage_result =
      case media_file.storage_type do
        "local" -> FileStorage.delete_locally(media_file.file_path)
        "s3" -> FileStorage.delete_from_s3(media_file.file_path)
        _ -> {:error, "Unknown storage type"}
      end

    case storage_result do
      :ok ->
        # Delete the media file record
        Media.delete_media_file(media_file)
      error ->
        error
    end
  end

  @doc """
  Generate a URL for a media file.
  """
  def media_url(%MediaFile{} = media_file) do
    case media_file.storage_type do
      "local" -> FileStorage.local_url(media_file.file_path)
      "s3" -> FileStorage.s3_url(media_file.file_path)
      _ -> nil
    end
  end

  # Private helpers

  defp determine_media_type(content_type) do
    cond do
      String.starts_with?(content_type, "image/") -> "image"
      String.starts_with?(content_type, "video/") -> "video"
      String.starts_with?(content_type, "audio/") -> "audio"
      true -> "document"
    end
  end

  # Helper to format file size for display
  def format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 1)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end
end
