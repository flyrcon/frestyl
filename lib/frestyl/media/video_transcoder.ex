# lib/frestyl/media/video_transcoder.ex
defmodule Frestyl.Media.VideoTranscoder do
  alias Frestyl.Media.MediaFile
  alias Frestyl.Storage
  alias Frestyl.Repo

  @output_formats [
    %{
      name: "web_hd",
      extension: "mp4",
      resolution: "1280x720",
      codec: "libx264",
      preset: "medium",
      crf: "23",
      audio_codec: "aac",
      audio_bitrate: "128k"
    },
    %{
      name: "web_sd",
      extension: "mp4",
      resolution: "640x360",
      codec: "libx264",
      preset: "medium",
      crf: "23",
      audio_codec: "aac",
      audio_bitrate: "96k"
    }
  ]

  @doc """
  Transcodes a video file to web-friendly formats
  """
  def transcode(%MediaFile{} = media_file) do
    if media_file.media_type != "video" do
      {:error, "Not a video file"}
    else
      # Update status to transcoding
      media_file
      |> Ecto.Changeset.change(%{status: "processing"})
      |> Repo.update()

      # Start transcoding process
      transcoded_versions = Enum.map(@output_formats, fn format ->
        case transcode_to_format(media_file, format) do
          {:ok, result} -> {format.name, result}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()

      # Update media file metadata with transcoded versions
      metadata = media_file.metadata || %{}
      updated_metadata = Map.put(metadata, "transcoded_versions", transcoded_versions)

      media_file
      |> Ecto.Changeset.change(%{
        status: "active",
        metadata: updated_metadata
      })
      |> Repo.update()
    end
  end

  defp transcode_to_format(%MediaFile{} = media_file, format) do
    # Create temporary directory for output
    tmp_dir = System.tmp_dir!()
    output_filename = "#{Path.basename(media_file.filename, Path.extname(media_file.filename))}_#{format.name}.#{format.extension}"
    output_path = Path.join(tmp_dir, output_filename)

    try do
      # Execute FFmpeg command
      args = [
        "-i", media_file.file_path,
        "-vf", "scale=#{format.resolution}",
        "-c:v", format.codec,
        "-preset", format.preset,
        "-crf", format.crf,
        "-c:a", format.audio_codec,
        "-b:a", format.audio_bitrate,
        "-movflags", "+faststart",
        "-y", # Overwrite without asking
        output_path
      ]

      case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
        {_, 0} ->
          # Upload transcoded file to storage
          key = Storage.generate_key(output_filename, "transcoded")
          Storage.upload(output_path, key, content_type: "video/#{format.extension}")
        {error, _} ->
          {:error, "Transcoding error: #{error}"}
      end
    after
      # Clean up temporary file
      File.rm(output_path)
    end
  end
end
