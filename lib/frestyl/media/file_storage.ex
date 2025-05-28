# lib/frestyl/media/file_storage.ex
defmodule Frestyl.Media.FileStorage do
  @moduledoc """
  Handles file storage operations, including local and S3 storage.
  """

  require Logger

  @upload_path "priv/static/uploads"
  @public_path "/uploads"

  @doc """
  Stores a file locally.
  """
  def store_locally(file_data, attrs) do
    # Create a unique filename based on a timestamp and random string
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random_string = for _ <- 1..8, into: "", do: <<Enum.random('0123456789abcdef')>>

    # Clean up filename
    original_filename = attrs.original_filename || attrs.filename
    file_ext = Path.extname(original_filename)
    clean_name = original_filename
                 |> Path.basename(file_ext)
                 |> String.replace(~r/[^\w.-]/, "_")

    # Combine for unique filename
    unique_filename = "#{clean_name}_#{timestamp}_#{random_string}#{file_ext}"

    # Determine the directory based on media type
    media_type = determine_media_type(attrs.content_type || "application/octet-stream")
    dir_path = Path.join(@upload_path, media_type)

    # Create the directory if it doesn't exist
    File.mkdir_p!(dir_path)

    # Full path to the file
    file_path = Path.join(dir_path, unique_filename)

    # Write the file
    case write_file(file_data, file_path) do
      :ok ->
        {:ok, %{
          file_path: Path.join(media_type, unique_filename),
          storage_type: "local"
        }}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a locally stored file.
  """
  def delete_locally(file_path) do
    full_path = Path.join(@upload_path, file_path)

    case File.rm(full_path) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("Failed to delete file #{full_path}: #{reason}")
        {:error, "Failed to delete file: #{reason}"}
    end
  end

  @doc """
  Returns the URL for a locally stored file.
  """
  def local_url(file_path) do
    Path.join(@public_path, file_path)
  end

  @doc """
  Stores a file on S3.
  Requires that the application has the necessary AWS credentials configured.
  """
  def store_on_s3(file_data, attrs) do
    # Similar to local storage, but using S3 instead
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random_string = for _ <- 1..8, into: "", do: <<Enum.random('0123456789abcdef')>>

    original_filename = attrs.original_filename || attrs.filename
    file_ext = Path.extname(original_filename)
    clean_name = original_filename
                 |> Path.basename(file_ext)
                 |> String.replace(~r/[^\w.-]/, "_")

    unique_filename = "#{clean_name}_#{timestamp}_#{random_string}#{file_ext}"

    media_type = determine_media_type(attrs.content_type || "application/octet-stream")

    # Construct the S3 key (path in the bucket)
    channel_part = if attrs[:channel_id], do: "channels/#{attrs.channel_id}/", else: ""
    s3_key = "#{channel_part}#{media_type}/#{unique_filename}"

    # Upload to S3
    bucket = Application.get_env(:frestyl, :s3_bucket)

    case upload_to_s3(bucket, s3_key, file_data, attrs.content_type) do
      :ok ->
        {:ok, %{
          file_path: s3_key,
          storage_type: "s3"
        }}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a file from S3.
  """
  def delete_from_s3(file_path) do
    bucket = Application.get_env(:frestyl, :s3_bucket)

    ExAws.S3.delete_object(bucket, file_path)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, error} ->
        Logger.error("Failed to delete file from S3: #{inspect(error)}")
        {:error, "Failed to delete file from S3"}
    end
  end

  @doc """
  Returns the URL for an S3-stored file.
  """
  def s3_url(file_path) do
    bucket = Application.get_env(:frestyl, :s3_bucket)
    region = Application.get_env(:frestyl, :s3_region)

    "https://#{bucket}.s3.#{region}.amazonaws.com/#{file_path}"
  end

  def store_locally(file_data, attrs) when is_binary(file_data) do
    # Create a unique filename based on a timestamp and random string
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random_string = for _ <- 1..8, into: "", do: <<Enum.random('0123456789abcdef')>>

    # Clean up filename
    original_filename = attrs.original_filename || attrs.filename
    file_ext = Path.extname(original_filename)
    clean_name = original_filename
                |> Path.basename(file_ext)
                |> String.replace(~r/[^\w.-]/, "_")

    # Combine for unique filename
    unique_filename = "#{clean_name}_#{timestamp}_#{random_string}#{file_ext}"

    # Determine the directory based on media type
    media_type = determine_media_type(attrs.content_type || "application/octet-stream")
    dir_path = Path.join(@upload_path, media_type)

    # Create the directory if it doesn't exist
    File.mkdir_p!(dir_path)

    # Full path to the file
    file_path = Path.join(dir_path, unique_filename)

    # Write the binary data directly to file
    case File.write(file_path, file_data) do
      :ok ->
        {:ok, %{
          file_path: Path.join(media_type, unique_filename),
          storage_type: "local"
        }}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Keep the existing store_locally function for file uploads
  def store_locally(%{path: source_path}, attrs) do
    # Create a unique filename based on a timestamp and random string
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random_string = for _ <- 1..8, into: "", do: <<Enum.random('0123456789abcdef')>>

    # Clean up filename
    original_filename = attrs.original_filename || attrs.filename
    file_ext = Path.extname(original_filename)
    clean_name = original_filename
                |> Path.basename(file_ext)
                |> String.replace(~r/[^\w.-]/, "_")

    # Combine for unique filename
    unique_filename = "#{clean_name}_#{timestamp}_#{random_string}#{file_ext}"

    # Determine the directory based on media type
    media_type = determine_media_type(attrs.content_type || "application/octet-stream")
    dir_path = Path.join(@upload_path, media_type)

    # Create the directory if it doesn't exist
    File.mkdir_p!(dir_path)

    # Full path to the file
    file_path = Path.join(dir_path, unique_filename)

    # Copy the uploaded file
    case File.cp(source_path, file_path) do
      :ok ->
        {:ok, %{
          file_path: Path.join(media_type, unique_filename),
          storage_type: "local"
        }}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Update S3 storage to handle binary data
  def store_on_s3(file_data, attrs) when is_binary(file_data) do
    # Similar to local storage, but using S3 instead
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random_string = for _ <- 1..8, into: "", do: <<Enum.random('0123456789abcdef')>>

    original_filename = attrs.original_filename || attrs.filename
    file_ext = Path.extname(original_filename)
    clean_name = original_filename
                |> Path.basename(file_ext)
                |> String.replace(~r/[^\w.-]/, "_")

    unique_filename = "#{clean_name}_#{timestamp}_#{random_string}#{file_ext}"

    media_type = determine_media_type(attrs.content_type || "application/octet-stream")

    # Construct the S3 key (path in the bucket)
    s3_key = "#{media_type}/#{unique_filename}"

    # Upload binary data directly to S3
    bucket = Application.get_env(:frestyl, :s3_bucket)

    case upload_binary_to_s3(bucket, s3_key, file_data, attrs.content_type) do
      :ok ->
        {:ok, %{
          file_path: s3_key,
          storage_type: "s3"
        }}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Keep existing S3 function for file uploads
  def store_on_s3(%{path: source_path}, attrs) do
    # Read file and call binary version
    case File.read(source_path) do
      {:ok, file_data} ->
        store_on_s3(file_data, attrs)
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper for S3 binary uploads
  defp upload_binary_to_s3(bucket, key, binary_data, content_type) do
    ExAws.S3.put_object(bucket, key, binary_data, [
      {:content_type, content_type},
      {:acl, :public_read}
    ])
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, error} ->
        Logger.error("Failed to upload binary data to S3: #{inspect(error)}")
        {:error, "Failed to upload file to S3"}
    end
  end

  # Private helpers

  defp write_file(file_data, file_path) when is_binary(file_data) do
    File.write(file_path, file_data)
  end

  defp write_file(%{path: source_path}, file_path) do
    File.cp(source_path, file_path)
  end

  defp upload_to_s3(bucket, key, file_data, content_type) when is_binary(file_data) do
    ExAws.S3.put_object(bucket, key, file_data, [
      {:content_type, content_type},
      {:acl, :public_read}
    ])
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, error} ->
        Logger.error("Failed to upload file to S3: #{inspect(error)}")
        {:error, "Failed to upload file to S3"}
    end
  end

  defp upload_to_s3(bucket, key, %{path: source_path}, content_type) do
    source_path
    |> File.read!()
    |> upload_to_s3(bucket, key, content_type)
  end

  defp determine_media_type(content_type) do
    cond do
      String.starts_with?(content_type, "image/") -> "images"
      String.starts_with?(content_type, "video/") -> "videos"
      String.starts_with?(content_type, "audio/") -> "audio"
      true -> "documents"
    end
  end
end
