# lib/frestyl/media.ex
defmodule Frestyl.Media do
  @moduledoc """
  The Media context for handling file uploads and management.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Media.MediaFile
  alias Frestyl.Media.FileStorage

  @doc """
  Returns the list of media files for a specific channel.
  """
  def list_channel_files(channel_id) do
    MediaFile
    |> where(channel_id: ^channel_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single media file.
  """
  def get_media_file!(id), do: Repo.get!(MediaFile, id)

  @doc """
  Creates a media file.
  """
  def create_media_file(attrs \\ %{}, file_data \\ nil) do
    # Handle the file upload first if file_data is provided
    attrs = if file_data do
      # Determine media type from content type
      media_type = determine_media_type(attrs.content_type || "application/octet-stream")

      # Store the file using appropriate storage method
      case store_file(file_data, attrs) do
        {:ok, storage_info} ->
          Map.merge(attrs, %{
            media_type: media_type,
            file_path: storage_info.file_path,
            storage_type: storage_info.storage_type
          })
        {:error, reason} ->
          raise "File storage error: #{reason}"
      end
    else
      attrs
    end

    %MediaFile{}
    |> MediaFile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a media file.
  """
  def update_media_file(%MediaFile{} = media_file, attrs) do
    media_file
    |> MediaFile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a media file.
  """
  def delete_media_file(%MediaFile{} = media_file) do
    # First delete the physical file
    case delete_physical_file(media_file) do
      :ok ->
        # Then delete the database record
        Repo.delete(media_file)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns files of a specific type for a channel.
  """
  def list_files_by_type(channel_id, type) do
    MediaFile
    |> where(channel_id: ^channel_id)
    |> where(media_type: ^type)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media file changes.
  """
  def change_media_file(%MediaFile{} = media_file, attrs \\ %{}) do
    MediaFile.changeset(media_file, attrs)
  end

  # Private functions

  defp determine_media_type(content_type) do
    cond do
      String.starts_with?(content_type, "image/") -> "image"
      String.starts_with?(content_type, "video/") -> "video"
      String.starts_with?(content_type, "audio/") -> "audio"
      true -> "document"
    end
  end

  defp store_file(file_data, attrs) do
    # Check if S3 is configured and enabled
    use_s3 = Application.get_env(:frestyl, :use_s3)

    if use_s3 == true do
      # Make sure S3 bucket and region are configured
      s3_bucket = Application.get_env(:frestyl, :s3_bucket)
      s3_region = Application.get_env(:frestyl, :s3_region)

      if s3_bucket && s3_region do
        FileStorage.store_on_s3(file_data, attrs)
      else
        Logger.warning("S3 enabled but bucket or region not configured, falling back to local storage")
        FileStorage.store_locally(file_data, attrs)
      end
    else
      FileStorage.store_locally(file_data, attrs)
    end
  end

  defp delete_physical_file(media_file) do
    case media_file.storage_type do
      "s3" -> FileStorage.delete_from_s3(media_file.file_path)
      "local" -> FileStorage.delete_locally(media_file.file_path)
      _ -> {:error, "Unknown storage type: #{media_file.storage_type}"}
    end
  end

  # File URL generation
  def get_media_url(%MediaFile{} = media_file) do
    case media_file.storage_type do
      "s3" -> FileStorage.s3_url(media_file.file_path)
      "local" -> FileStorage.local_url(media_file.file_path)
      _ -> nil
    end
  end
end
