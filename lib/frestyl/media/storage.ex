# lib/frestyl/media/storage.ex
defmodule Frestyl.Media.Storage do
  @moduledoc """
  Handles file storage operations for media assets.
  Supports both local file system and cloud storage.
  """

  alias Frestyl.Media.Asset
  alias Frestyl.Media.AssetVersion

  @storage_type Application.get_env(:frestyl, :storage_type, :local)
  @local_storage_path Application.get_env(:frestyl, :local_storage_path, "uploads")

  @doc """
  Stores a file and returns the file path.
  """
  def store_file(upload, %Asset{} = asset) do
    ext = Path.extname(upload.filename)
    filename = "#{asset.id}_#{:os.system_time(:millisecond)}#{ext}"

    case @storage_type do
      :local -> store_local(upload, asset, filename)
      :s3 -> store_s3(upload, asset, filename)
      _ -> {:error, "Unsupported storage type"}
    end
  end

  defp store_local(upload, asset, filename) do
    directory = Path.join(@local_storage_path, "#{asset.type}/#{asset.id}")
    File.mkdir_p!(directory)

    path = Path.join(directory, filename)
    File.cp!(upload.path, path)

    {:ok, path}
  end

  defp store_s3(upload, asset, filename) do
    # Implementation for S3 storage
    # Here would be AWS S3 SDK calls
    {:error, "S3 storage not implemented yet"}
  end

  @doc """
  Retrieves a file by its path.
  """
  def get_file(path) do
    case @storage_type do
      :local -> get_local_file(path)
      :s3 -> get_s3_file(path)
      _ -> {:error, "Unsupported storage type"}
    end
  end

  defp get_local_file(path) do
    if File.exists?(path) do
      {:ok, path}
    else
      {:error, "File not found"}
    end
  end

  defp get_s3_file(path) do
    # Implementation for S3 retrieval
    {:error, "S3 retrieval not implemented yet"}
  end

  @doc """
  Deletes a file by its path.
  """
  def delete_file(path) do
    case @storage_type do
      :local -> File.rm(path)
      :s3 -> delete_s3_file(path)
      _ -> {:error, "Unsupported storage type"}
    end
  end

  defp delete_s3_file(path) do
    # Implementation for S3 deletion
    {:error, "S3 deletion not implemented yet"}
  end
end
