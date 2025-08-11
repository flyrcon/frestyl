# lib/frestyl/storage/cloud_uploader.ex
defmodule Frestyl.Storage.CloudUploader do
  @moduledoc """
  Handles cloud storage uploads for audio files with support for AWS S3,
  CloudFront CDN distribution, and file management.
  """

  require Logger
  alias ExAws.S3

  @bucket_name Application.compile_env(:frestyl, :s3_bucket, "frestyl-audio")
  @cloudfront_domain Application.compile_env(:frestyl, :cloudfront_domain, "audio.frestyl.com")
  @max_file_size 100 * 1024 * 1024  # 100MB
  @allowed_content_types ["audio/mpeg", "audio/wav", "audio/flac", "audio/ogg"]

  @doc """
  Upload an audio file to cloud storage.
  """
  def upload_audio_file(file_path, filename, metadata \\ %{}) do
    with :ok <- validate_file(file_path),
         {:ok, file_data} <- File.read(file_path),
         {:ok, content_type} <- determine_content_type(filename),
         :ok <- validate_content_type(content_type),
         {:ok, s3_key} <- generate_s3_key(filename, metadata),
         {:ok, upload_result} <- upload_to_s3(s3_key, file_data, content_type, metadata) do

      file_info = %{
        storage_type: :s3,
        bucket: @bucket_name,
        key: s3_key,
        filename: filename,
        content_type: content_type,
        size: byte_size(file_data),
        url: generate_public_url(s3_key),
        cdn_url: generate_cdn_url(s3_key),
        uploaded_at: DateTime.utc_now(),
        etag: upload_result.etag
      }

      {:ok, file_info}
    else
      error -> error
    end
  end

  @doc """
  Upload audio data directly from memory.
  """
  def upload_audio_data(audio_data, filename, metadata \\ %{}) do
    with :ok <- validate_audio_data(audio_data),
         {:ok, content_type} <- determine_content_type(filename),
         :ok <- validate_content_type(content_type),
         {:ok, s3_key} <- generate_s3_key(filename, metadata),
         {:ok, upload_result} <- upload_to_s3(s3_key, audio_data, content_type, metadata) do

      file_info = %{
        storage_type: :s3,
        bucket: @bucket_name,
        key: s3_key,
        filename: filename,
        content_type: content_type,
        size: byte_size(audio_data),
        url: generate_public_url(s3_key),
        cdn_url: generate_cdn_url(s3_key),
        uploaded_at: DateTime.utc_now(),
        etag: upload_result.etag
      }

      {:ok, file_info}
    else
      error -> error
    end
  end

  @doc """
  Delete an audio file from cloud storage.
  """
  def delete_audio_file(s3_key) do
    case S3.delete_object(@bucket_name, s3_key) |> ExAws.request() do
      {:ok, _result} ->
        Logger.info("Deleted audio file: #{s3_key}")
        :ok

      {:error, error} ->
        Logger.error("Failed to delete audio file #{s3_key}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Generate a presigned URL for direct uploads from the client.
  """
  def generate_presigned_upload_url(filename, metadata \\ %{}) do
    with {:ok, content_type} <- determine_content_type(filename),
         :ok <- validate_content_type(content_type),
         {:ok, s3_key} <- generate_s3_key(filename, metadata) do

      expires_in = 300  # 5 minutes

      presigned_url = S3.presigned_url(
        ExAws.Config.new(:s3),
        :put,
        @bucket_name,
        s3_key,
        expires_in: expires_in,
        query_params: [
          {"Content-Type", content_type}
        ]
      )

      {:ok, %{
        upload_url: presigned_url,
        s3_key: s3_key,
        content_type: content_type,
        expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
      }}
    else
      error -> error
    end
  end

  @doc """
  Get file information from S3.
  """
  def get_file_info(s3_key) do
    case S3.head_object(@bucket_name, s3_key) |> ExAws.request() do
      {:ok, response} ->
        {:ok, %{
          key: s3_key,
          size: String.to_integer(response.headers["content-length"]),
          content_type: response.headers["content-type"],
          last_modified: response.headers["last-modified"],
          etag: response.headers["etag"],
          url: generate_public_url(s3_key),
          cdn_url: generate_cdn_url(s3_key)
        }}

      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  List audio files for a session or user.
  """
  def list_audio_files(prefix) do
    case S3.list_objects_v2(@bucket_name, prefix: prefix) |> ExAws.request() do
      {:ok, %{body: %{contents: objects}}} ->
        files = Enum.map(objects, fn object ->
          %{
            key: object.key,
            size: object.size,
            last_modified: object.last_modified,
            etag: object.etag,
            url: generate_public_url(object.key),
            cdn_url: generate_cdn_url(object.key)
          }
        end)
        {:ok, files}

      {:ok, %{body: %{}}} ->
        {:ok, []}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Copy an audio file within S3 (useful for creating backups or versions).
  """
  def copy_audio_file(source_key, destination_key) do
    copy_source = "#{@bucket_name}/#{source_key}"

    case S3.put_object_copy(@bucket_name, destination_key, copy_source) |> ExAws.request() do
      {:ok, result} ->
        {:ok, %{
          source_key: source_key,
          destination_key: destination_key,
          etag: result.body.etag
        }}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Set file metadata or tags.
  """
  def update_file_metadata(s3_key, metadata) do
    tags = Enum.map(metadata, fn {key, value} ->
      "#{key}=#{value}"
    end) |> Enum.join("&")

    case S3.put_object_tagging(@bucket_name, s3_key, tags) |> ExAws.request() do
      {:ok, _result} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  # Private Functions

  defp validate_file(file_path) do
    cond do
      not File.exists?(file_path) ->
        {:error, :file_not_found}

      File.stat!(file_path).size > @max_file_size ->
        {:error, :file_too_large}

      true ->
        :ok
    end
  end

  defp validate_audio_data(audio_data) when is_binary(audio_data) do
    if byte_size(audio_data) > @max_file_size do
      {:error, :file_too_large}
    else
      :ok
    end
  end
  defp validate_audio_data(_), do: {:error, :invalid_audio_data}

  defp determine_content_type(filename) do
    case Path.extname(filename) |> String.downcase() do
      ".mp3" -> {:ok, "audio/mpeg"}
      ".wav" -> {:ok, "audio/wav"}
      ".flac" -> {:ok, "audio/flac"}
      ".ogg" -> {:ok, "audio/ogg"}
      ".m4a" -> {:ok, "audio/mp4"}
      ext -> {:error, "Unsupported file extension: #{ext}"}
    end
  end

  defp validate_content_type(content_type) do
    if content_type in @allowed_content_types do
      :ok
    else
      {:error, "Content type not allowed: #{content_type}"}
    end
  end

  defp generate_s3_key(filename, metadata) do
    # Create organized folder structure
    session_id = Map.get(metadata, :session_id, "unknown")
    user_id = Map.get(metadata, :user_id, "unknown")
    date = Date.utc_today() |> Date.to_string()

    # Generate unique filename to prevent collisions
    timestamp = System.system_time(:millisecond)
    uuid = UUID.uuid4()

    base_name = Path.basename(filename, Path.extname(filename))
    extension = Path.extname(filename)

    unique_filename = "#{base_name}_#{timestamp}_#{String.slice(uuid, 0, 8)}#{extension}"

    s3_key = Path.join([
      "audio",
      date,
      "users",
      to_string(user_id),
      "sessions",
      to_string(session_id),
      unique_filename
    ])

    {:ok, s3_key}
  end

  defp upload_to_s3(s3_key, data, content_type, metadata) do
    # Prepare S3 metadata
    s3_metadata = %{
      "Content-Type" => content_type,
      "Cache-Control" => "public, max-age=31536000",  # 1 year cache
      "x-amz-meta-uploaded-by" => "frestyl-app",
      "x-amz-meta-session-id" => to_string(Map.get(metadata, :session_id, "")),
      "x-amz-meta-user-id" => to_string(Map.get(metadata, :user_id, "")),
      "x-amz-meta-track-id" => to_string(Map.get(metadata, :track_id, "")),
      "x-amz-meta-uploaded-at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Add server-side encryption
    put_options = [
      content_type: content_type,
      meta: s3_metadata,
      server_side_encryption: "AES256"
    ]

    case S3.put_object(@bucket_name, s3_key, data, put_options) |> ExAws.request() do
      {:ok, result} ->
        Logger.info("Uploaded audio file to S3: #{s3_key}")
        {:ok, result}

      {:error, error} ->
        Logger.error("Failed to upload to S3: #{inspect(error)}")
        {:error, error}
    end
  end

  defp generate_public_url(s3_key) do
    "https://#{@bucket_name}.s3.amazonaws.com/#{s3_key}"
  end

  defp generate_cdn_url(s3_key) do
    if @cloudfront_domain do
      "https://#{@cloudfront_domain}/#{s3_key}"
    else
      generate_public_url(s3_key)
    end
  end
end

# UUID module for generating unique identifiers
defmodule UUID do
  def uuid4 do
    <<u0::32, u1::16, u2::16, u3::16, u4::48>> = :crypto.strong_rand_bytes(16)
    <<u2::16>> = <<4::4, u2::12>>
    <<u3::16>> = <<2::2, u3::14>>

    # Convert to hex string manually
    [
      Integer.to_string(u0, 16) |> String.pad_leading(8, "0"),
      "-",
      Integer.to_string(u1, 16) |> String.pad_leading(4, "0"),
      "-",
      Integer.to_string(u2, 16) |> String.pad_leading(4, "0"),
      "-",
      Integer.to_string(u3, 16) |> String.pad_leading(4, "0"),
      "-",
      Integer.to_string(u4, 16) |> String.pad_leading(12, "0")
    ]
    |> Enum.join()
    |> String.downcase()
  end
end
