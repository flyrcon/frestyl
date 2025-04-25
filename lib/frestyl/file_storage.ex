# lib/frestyl/file_storage.ex
defmodule Frestyl.FileStorage do
  @moduledoc """
  Handles file storage for the application.
  """

  # Change these settings according to your needs
  @upload_directory "priv/static/uploads"
  @max_file_size 10_485_760  # 10 MB

  @doc """
  Stores a file from a base64 encoded string.
  Returns {:ok, url} or {:error, reason}.
  """
  def store_file(base64_data, file_name) do
    with {:ok, binary_data} <- Base.decode64(base64_data),
         :ok <- validate_file_size(binary_data),
         {:ok, sanitized_name} <- sanitize_filename(file_name),
         unique_name = generate_unique_filename(sanitized_name),
         path = Path.join(@upload_directory, unique_name),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, binary_data)
    do
      # Return the URL that can be used to access the file
      {:ok, "/uploads/#{unique_name}"}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes a file given its URL.
  """
  def delete_file(url) do
    # Extract the filename from the URL
    filename = String.replace_prefix(url, "/uploads/", "")
    path = Path.join(@upload_directory, filename)

    case File.rm(path) do
      :ok -> {:ok, :deleted}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helpers

  defp validate_file_size(data) when byte_size(data) > @max_file_size do
    {:error, "File exceeds maximum size of #{@max_file_size} bytes"}
  end

  defp validate_file_size(_data), do: :ok

  defp sanitize_filename(name) do
    # Remove any path components and get just the filename
    name = Path.basename(name)

    # Replace any potentially problematic characters
    sanitized = String.replace(name, ~r/[^\w\.\-]/, "_")

    if sanitized == "" do
      {:error, "Invalid filename"}
    else
      {:ok, sanitized}
    end
  end

  defp generate_unique_filename(name) do
    # Generate a random string to ensure uniqueness
    random_string = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)

    # Get file extension
    ext = Path.extname(name)
    base_name = Path.basename(name, ext)

    # Format: original_name-random_string.extension
    "#{base_name}-#{random_string}#{ext}"
  end

  @doc """
  Returns a list of allowed file extensions.
  """
  def allowed_extensions do
    ~w(.jpg .jpeg .png .gif .pdf .doc .docx .xls .xlsx .txt .md .csv .zip .mp3 .mp4)
  end

  @doc """
  Checks if a file has an allowed extension.
  """
  def allowed_extension?(filename) do
    ext = String.downcase(Path.extname(filename))
    ext in allowed_extensions()
  end

  @doc """
  Gets the mime type for a file based on its extension.
  """
  def get_mime_type(filename) do
    ext = String.downcase(Path.extname(filename))

    case ext do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".pdf" -> "application/pdf"
      ".doc" -> "application/msword"
      ".docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      ".xls" -> "application/vnd.ms-excel"
      ".xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      ".txt" -> "text/plain"
      ".md" -> "text/markdown"
      ".csv" -> "text/csv"
      ".zip" -> "application/zip"
      ".mp3" -> "audio/mpeg"
      ".mp4" -> "video/mp4"
      _ -> "application/octet-stream"
    end
  end

  @doc """
  Determines if a file is an image based on its extension.
  """
  def is_image?(filename) do
    ext = String.downcase(Path.extname(filename))
    ext in ~w(.jpg .jpeg .png .gif)
  end
end
