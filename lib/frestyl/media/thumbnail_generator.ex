# lib/frestyl/media/thumbnail_generator.ex
defmodule Frestyl.Media.ThumbnailGenerator do
  alias Frestyl.Media.MediaFile

  @thumbnail_width 300
  @thumbnail_height 300
  @thumbnail_dir "thumbnails"

  def generate_thumbnail(%MediaFile{} = media_file) do
    # Create thumbnails directory if it doesn't exist
    thumbnails_path = thumbnails_path()
    File.mkdir_p!(thumbnails_path)

    thumbnail_filename = "thumb_#{Path.basename(media_file.filename)}"
    thumbnail_path = Path.join(thumbnails_path, thumbnail_filename)

    result = case media_file.media_type do
      "image" -> generate_image_thumbnail(media_file.file_path, thumbnail_path)
      "video" -> generate_video_thumbnail(media_file.file_path, thumbnail_path)
      "document" -> generate_document_thumbnail(media_file.file_path, thumbnail_path)
      "audio" -> generate_audio_thumbnail(thumbnail_path)
      _ -> {:error, "Unsupported media type for thumbnail generation"}
    end

    case result do
      {:ok, thumb_path} ->
        # Update media file with thumbnail path
        {:ok, thumbnail_url(thumb_path)}
      error -> error
    end
  end

  defp generate_image_thumbnail(source_path, thumbnail_path) do
    try do
      # Make sure the thumbnail path has the proper extension
      thumbnail_path = ensure_extension(thumbnail_path, Path.extname(source_path))

      # Using Mogrify for image processing
      Mogrify.open(source_path)
      |> Mogrify.resize_to_limit("#{@thumbnail_width}x#{@thumbnail_height}")
      |> Mogrify.save(path: thumbnail_path)

      {:ok, thumbnail_path}
    rescue
      e -> {:error, "Failed to generate image thumbnail: #{inspect(e)}"}
    end
  end

  defp generate_video_thumbnail(source_path, thumbnail_path) do
    # Using FFmpeg to extract a frame from the video
    thumbnail_jpg = ensure_extension(thumbnail_path, ".jpg")

    args = [
      "-i", source_path,
      "-ss", "00:00:05", # 5 seconds in
      "-vframes", "1",
      "-vf", "scale=#{@thumbnail_width}:#{@thumbnail_height}:force_original_aspect_ratio=decrease",
      "-y", # Overwrite output files without asking
      thumbnail_jpg
    ]

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_, 0} -> {:ok, thumbnail_jpg}
      {error, _} -> {:error, "Failed to generate video thumbnail: #{error}"}
    end
  end

  defp generate_document_thumbnail(source_path, thumbnail_path) do
    # For PDFs
    if String.ends_with?(String.downcase(source_path), ".pdf") do
      thumbnail_jpg = ensure_extension(thumbnail_path, ".jpg")
      output_prefix = Path.rootname(thumbnail_jpg)

      args = [
        "-jpeg",
        "-singlefile",
        "-scale-to", "#{@thumbnail_width}",
        source_path,
        output_prefix
      ]

      case System.cmd("pdftoppm", args, stderr_to_stdout: true) do
        {_, 0} ->
          # pdftoppm adds -1 suffix for single page output
          {:ok, "#{output_prefix}-1.jpg"}
        {error, _} ->
          # Fall back to generic document icon
          copy_default_icon("document", thumbnail_jpg)
      end
    else
      # For other document types, use a generic icon
      copy_default_icon("document", ensure_extension(thumbnail_path, ".png"))
    end
  end

  defp generate_audio_thumbnail(thumbnail_path) do
    # For audio files, use a default audio icon
    copy_default_icon("audio", ensure_extension(thumbnail_path, ".png"))
  end

  defp copy_default_icon(type, destination_path) do
    # Path to default icons
    icons_path = Application.app_dir(:frestyl, "priv/static/images/icons")
    source_path = Path.join(icons_path, "#{type}.png")

    if File.exists?(source_path) do
      File.cp!(source_path, destination_path)
      {:ok, destination_path}
    else
      # Create default icon directory if it doesn't exist
      File.mkdir_p!(icons_path)

      # If icon doesn't exist, create a simple one with Mogrify
      Mogrify.open("wizard:") # Create blank canvas
      |> Mogrify.create(path: source_path, size: "200x200", background: "transparent")
      |> Mogrify.custom("fill", "#333333")
      |> Mogrify.custom("gravity", "center")
      |> Mogrify.custom("pointsize", "40")
      |> Mogrify.custom("draw", ~s{text 0,0 "#{String.upcase(type)}"})
      |> Mogrify.save(path: source_path)

      File.cp!(source_path, destination_path)
      {:ok, destination_path}
    end
  end

  defp ensure_extension(path, ext) do
    if Path.extname(path) == ext do
      path
    else
      "#{Path.rootname(path)}#{ext}"
    end
  end

  defp thumbnails_path do
    upload_path = Application.get_env(:frestyl, :upload_path, "priv/static/uploads")
    Path.join(upload_path, @thumbnail_dir)
  end

  defp thumbnail_url(thumbnail_path) do
    # Convert filesystem path to URL
    "/uploads/#{@thumbnail_dir}/#{Path.basename(thumbnail_path)}"
  end
end
