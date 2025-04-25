# lib/frestyl/media/file_helpers.ex
defmodule Frestyl.Media.FileHelpers do
  @moduledoc """
  Helper functions for working with media files.
  """

  @doc """
  Validates a file upload based on type and size constraints.
  """
  def validate_file(upload, type) do
    max_sizes = Application.get_env(:frestyl, :max_file_sizes)
    allowed_exts = Application.get_env(:frestyl, :allowed_extensions)

    ext = Path.extname(upload.filename) |> String.downcase()

    cond do
      !Map.has_key?(max_sizes, type) ->
        {:error, "Invalid media type: #{type}"}

      !Enum.member?(allowed_exts[type], ext) ->
        {:error, "File extension #{ext} is not allowed for #{type}. Allowed: #{Enum.join(allowed_exts[type], ", ")}"}

      upload.size > max_sizes[type] ->
        max_mb = max_sizes[type] / 1_048_576
        {:error, "File size exceeds the maximum allowed size of #{max_mb} MB for #{type}"}

      true ->
        {:ok, upload}
    end
  end

  @doc """
  Generates a unique filename for an upload.
  """
  def generate_filename(upload, prefix \\ "") do
    ext = Path.extname(upload.filename)
    base = Path.basename(upload.filename, ext)
              |> String.replace(~r/[^a-zA-Z0-9_-]/, "-")

    timestamp = DateTime.utc_now()
                |> DateTime.to_unix()

    random = :crypto.strong_rand_bytes(4)
              |> Base.encode16(case: :lower)

    "#{prefix}#{base}-#{timestamp}-#{random}#{ext}"
  end

  @doc """
  Returns the MIME type for a given file extension.
  """
  def mime_type_from_extension(ext) do
    ext = String.downcase(ext)

    case ext do
      ".pdf" -> "application/pdf"
      ".docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      ".txt" -> "text/plain"
      ".md" -> "text/markdown"
      ".rtf" -> "application/rtf"
      ".odt" -> "application/vnd.oasis.opendocument.text"
      ".mp3" -> "audio/mpeg"
      ".wav" -> "audio/wav"
      ".ogg" -> "audio/ogg"
      ".flac" -> "audio/flac"
      ".m4a" -> "audio/mp4"
      ".mp4" -> "video/mp4"
      ".webm" -> "video/webm"
      ".mov" -> "video/quicktime"
      ".avi" -> "video/x-msvideo"
      ".mkv" -> "video/x-matroska"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".svg" -> "image/svg+xml"
      ".webp" -> "image/webp"
      _ -> "application/octet-stream"
    end
  end

  @doc """
  Formats file size in bytes to a human-readable format.
  """
  def format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes < 1_024 ->
        "#{bytes} B"
      bytes < 1_048_576 ->
        kb = bytes / 1_024
        "#{Float.round(kb, 1)} KB"
      bytes < 1_073_741_824 ->
        mb = bytes / 1_048_576
        "#{Float.round(mb, 1)} MB"
      true ->
        gb = bytes / 1_073_741_824
        "#{Float.round(gb, 1)} GB"
    end
  end

  def format_bytes(_), do: "N/A"
end
