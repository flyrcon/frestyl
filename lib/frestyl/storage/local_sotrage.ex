# lib/frestyl/storage/local_storage.ex
defmodule Frestyl.Storage.LocalStorage do
  alias Frestyl.Config

  @doc """
  Stores a file locally
  """
  def upload(source_path, destination_path, _opts \\ []) do
    # Ensure directory exists
    destination_path
    |> Path.dirname()
    |> File.mkdir_p!()

    # Copy file to destination
    File.cp!(source_path, destination_path)

    # Convert to URL path
    url_path = to_url_path(destination_path)
    {:ok, url_path}
  end

  @doc """
  Converts a local file path to a URL path
  """
  def to_url_path(file_path) do
    upload_path = Config.upload_path()

    case String.starts_with?(file_path, upload_path) do
      true ->
        # Convert the file path to a URL path
        "/uploads/" <> String.replace_leading(file_path, upload_path <> "/", "")
      false ->
        # Already a URL or not in upload path
        file_path
    end
  end

  @doc """
  Deletes a file
  """
  def delete(file_path) do
    path = if String.starts_with?(file_path, "/uploads") do
      Path.join(Config.upload_path(), String.replace_leading(file_path, "/uploads/", ""))
    else
      file_path
    end

    File.rm(path)
  end
end
