# lib/frestyl/media/optimizer.ex
defmodule Frestyl.Media.Optimizer do
  @moduledoc """
  Handles media optimization for streaming and efficient storage.
  """

  require Logger
  alias Frestyl.Media.Converter

  @doc """
  Optimizes a media file for the given usage scenario.
  Returns the path to the optimized file.
  """
  def optimize(source_path, media_type, scenario) do
    case {media_type, scenario} do
      {"audio", :streaming} -> optimize_audio_for_streaming(source_path)
      {"audio", :download} -> optimize_audio_for_download(source_path)
      {"video", :streaming} -> optimize_video_for_streaming(source_path)
      {"video", :download} -> optimize_video_for_download(source_path)
      {"document", _} -> optimize_document(source_path, scenario)
      _ -> {:error, "Unsupported optimization scenario"}
    end
  end

  defp optimize_audio_for_streaming(source_path) do
    target_path = String.replace(source_path, Path.extname(source_path), "_stream.mp3")

    args = [
      "-i", source_path,
      "-codec:a", "libmp3lame",
      "-b:a", "128k",
      "-map_metadata", "0",
      "-id3v2_version", "3",
      "-y",
      target_path
    ]

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_, 0} -> {:ok, target_path}
      {error, _} ->
        Logger.error("Failed to optimize audio for streaming: #{error}")
        {:error, "Optimization failed"}
    end
  end

  defp optimize_audio_for_download(source_path) do
    target_path = String.replace(source_path, Path.extname(source_path), "_download.mp3")

    args = [
      "-i", source_path,
      "-codec:a", "libmp3lame",
      "-b:a", "320k",
      "-map_metadata", "0",
      "-id3v2_version", "3",
      "-y",
      target_path
    ]

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_, 0} -> {:ok, target_path}
      {error, _} ->
        Logger.error("Failed to optimize audio for download: #{error}")
        {:error, "Optimization failed"}
    end
  end

  defp optimize_video_for_streaming(source_path) do
    target_path = String.replace(source_path, Path.extname(source_path), "_stream.mp4")

    # Create HLS adaptive streaming segments
    segment_path = Path.join(Path.dirname(source_path), "stream")
    File.mkdir_p!(segment_path)
    playlist_path = Path.join(segment_path, "playlist.m3u8")

    args = [
      "-i", source_path,
      "-profile:v", "baseline",
      "-level", "3.0",
      "-start_number", "0",
      "-hls_time", "10",
      "-hls_list_size", "0",
      "-f", "hls",
      "-y",
      playlist_path
    ]

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_, 0} -> {:ok, playlist_path}
      {error, _} ->
        Logger.error("Failed to optimize video for streaming: #{error}")
        {:error, "Optimization failed"}
    end
  end

  defp optimize_video_for_download(source_path) do
    target_path = String.replace(source_path, Path.extname(source_path), "_download.mp4")

    args = [
      "-i", source_path,
      "-codec:v", "libx264",
      "-crf", "23",
      "-preset", "medium",
      "-codec:a", "aac",
      "-b:a", "128k",
      "-movflags", "+faststart",
      "-y",
      target_path
    ]

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_, 0} -> {:ok, target_path}
      {error, _} ->
        Logger.error("Failed to optimize video for download: #{error}")
        {:error, "Optimization failed"}
    end
  end

  defp optimize_document(source_path, _scenario) do
    # Document optimization would depend on the format
    # This could involve compressing PDFs, optimizing images in documents, etc.
    {:error, "Document optimization not implemented yet"}
  end
end
