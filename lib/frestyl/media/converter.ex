# lib/frestyl/media/converter.ex
defmodule Frestyl.Media.Converter do
  @moduledoc """
  Handles media format conversion using external tools like FFmpeg.
  """

  require Logger

  @doc """
  Converts a file from one format to another.
  Returns the path to the converted file.
  """
  def convert(source_path, source_format, target_format, options \\ []) do
    case {source_format, target_format} do
      {fmt, fmt} -> {:ok, source_path} # Same format, no conversion needed
      {source, target} when source in ["mp3", "wav", "ogg"] and target in ["mp3", "wav", "ogg"] ->
        convert_audio(source_path, target_format, options)
      {source, target} when source in ["mp4", "webm", "mov"] and target in ["mp4", "webm", "mov"] ->
        convert_video(source_path, target_format, options)
      {source, target} when source in ["docx", "txt", "pdf"] and target in ["docx", "txt", "pdf"] ->
        convert_document(source_path, target_format, options)
      _ ->
        {:error, "Unsupported conversion: #{source_format} to #{target_format}"}
    end
  end

  defp convert_audio(source_path, target_format, options) do
    target_path = String.replace(source_path, Path.extname(source_path), ".#{target_format}")

    args = [
      "-i", source_path,
      "-y" # Overwrite output file if it exists
    ] ++ format_specific_audio_options(target_format, options) ++ [target_path]

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_, 0} -> {:ok, target_path}
      {error, _} ->
        Logger.error("Failed to convert audio: #{error}")
        {:error, "Conversion failed"}
    end
  end

  defp format_specific_audio_options("mp3", options) do
    ["-codec:a", "libmp3lame", "-qscale:a", to_string(Keyword.get(options, :quality, 2))]
  end

  defp format_specific_audio_options("wav", _options) do
    ["-codec:a", "pcm_s16le"]
  end

  defp format_specific_audio_options("ogg", options) do
    ["-codec:a", "libvorbis", "-qscale:a", to_string(Keyword.get(options, :quality, 4))]
  end

  defp convert_video(source_path, target_format, options) do
    target_path = String.replace(source_path, Path.extname(source_path), ".#{target_format}")

    args = [
      "-i", source_path,
      "-y" # Overwrite output file if it exists
    ] ++ format_specific_video_options(target_format, options) ++ [target_path]

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_, 0} -> {:ok, target_path}
      {error, _} ->
        Logger.error("Failed to convert video: #{error}")
        {:error, "Conversion failed"}
    end
  end

  defp format_specific_video_options("mp4", options) do
    quality = Keyword.get(options, :quality, "medium")
    ["-codec:v", "libx264", "-preset", quality, "-codec:a", "aac", "-b:a", "128k"]
  end

  defp format_specific_video_options("webm", options) do
    quality = Keyword.get(options, :quality, "good")
    ["-codec:v", "libvpx", "-quality", quality, "-codec:a", "libvorbis"]
  end

  defp format_specific_video_options("mov", options) do
    ["-codec:v", "prores", "-codec:a", "pcm_s16le"]
  end

  defp convert_document(source_path, target_format, _options) do
    target_path = String.replace(source_path, Path.extname(source_path), ".#{target_format}")

    # This is a placeholder. In reality, you'd need tools like LibreOffice, Pandoc, etc.
    # Consider using external APIs like DocumentConverter.io
    {:error, "Document conversion not implemented yet"}
  end
end
