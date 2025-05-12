# lib/frestyl/storage/storage.ex
defmodule Frestyl.Storage do
  alias Frestyl.Config
  alias Frestyl.Storage.{LocalStorage, S3Storage}

  @doc """
  Uploads a file using the configured storage method
  """
  def upload(source_path, key, opts \\ []) do
    case Config.storage_type() do
      "s3" ->
        S3Storage.upload(source_path, key, opts)
      _ ->
        destination_path = Path.join(Config.upload_path(), key)
        LocalStorage.upload(source_path, destination_path, opts)
    end
  end

  @doc """
  Deletes a file from storage
  """
  def delete(file_path) do
    case Config.storage_type() do
      "s3" ->
        # Extract key from S3 URL
        uri = URI.parse(file_path)
        key = String.replace_leading(uri.path, "/", "")
        S3Storage.delete(key)
      _ ->
        LocalStorage.delete(file_path)
    end
  end

  @doc """
  Generates a unique key for a file
  """
  def generate_key(filename, prefix \\ "uploads") do
    extension = Path.extname(filename)
    basename = Path.basename(filename, extension)
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random_suffix = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

    Path.join(prefix, "#{basename}_#{timestamp}_#{random_suffix}#{extension}")
  end
end
