# lib/frestyl/media/thumbnail_processor.ex
defmodule Frestyl.Media.ThumbnailProcessor do
  alias Frestyl.Media.MediaFile
  alias Frestyl.Storage
  alias Frestyl.Config

  @doc """
  Generates thumbnails for a media file and updates the record
  """
  def process(%MediaFile{} = media_file) do
    # Generate thumbnails for each configured size
    thumbnail_sizes = Application.get_env(:frestyl, :thumbnail_sizes, [
      small: [width: 150, height: 150],
      medium: [width: 300, height: 300],
      large: [width: 600, height: 600]
    ])

    thumbnail_results = Enum.map(thumbnail_sizes, fn {size, dimensions} ->
      {size, generate_thumbnail(media_file, dimensions)}
    end)

    # Filter successful thumbnails
    successful_thumbnails = Enum.filter(thumbnail_results, fn {_, result} ->
      case result do
        {:ok, _} -> true
        _ -> false
      end
    end)
    |> Enum.map(fn {size, {:ok, url}} -> {size, url} end)
    |> Map.new()

    # Check if we have at least one successful thumbnail
    # Fixed: Properly define variables before using them
    {final_thumbnail_status, final_thumbnail_url} = if map_size(successful_thumbnails) > 0 do
      thumbnail_url = successful_thumbnails[:medium] ||
                     successful_thumbnails[:small] ||
                     Map.values(successful_thumbnails) |> List.first()
      {"generated", thumbnail_url}
    else
      {"failed", nil}
    end

    # Return the thumbnail data to update the media file
    %{
      thumbnail_url: final_thumbnail_url,
      thumbnail_status: final_thumbnail_status,
      thumbnails: successful_thumbnails
    }
  end

  defp generate_thumbnail(%MediaFile{} = media_file, dimensions) do
    width = dimensions[:width]
    height = dimensions[:height]

    case media_file.media_type do
      "image" -> generate_image_thumbnail(media_file, width, height)
      "video" -> generate_video_thumbnail(media_file, width, height)
      "document" -> generate_document_thumbnail(media_file, width, height)
      "audio" -> generate_audio_thumbnail(media_file, width, height)
      _ -> {:error, "Unsupported media type"}
    end
  end

  defp generate_image_thumbnail(media_file, width, height) do
    # Create a temporary file for the thumbnail
    tmp_dir = System.tmp_dir!()
    tmp_thumbnail = Path.join(tmp_dir, "thumb_#{:os.system_time(:millisecond)}.jpg")

    try do
      # Process with Mogrify
      Mogrify.open(media_file.file_path)
      |> Mogrify.resize_to_limit("#{width}x#{height}")
      |> Mogrify.save(path: tmp_thumbnail)

      # Upload the thumbnail to storage
      key = Storage.generate_key("thumb_#{width}x#{height}_#{Path.basename(media_file.filename)}", "thumbnails")
      Storage.upload(tmp_thumbnail, key, content_type: "image/jpeg")
    after
      # Clean up temp file
      File.rm(tmp_thumbnail)
    end
  end

  defp generate_image_thumbnail(media_file, width, height) do
    # Create a temporary file for the thumbnail
    tmp_dir = System.tmp_dir!()
    tmp_thumbnail = Path.join(tmp_dir, "thumb_#{:os.system_time(:millisecond)}.jpg")

    try do
      # Process with Mogrify
      Mogrify.open(media_file.file_path)
      |> Mogrify.resize_to_limit("#{width}x#{height}")
      |> Mogrify.save(path: tmp_thumbnail)

      # Upload the thumbnail to storage
      key = Storage.generate_key("thumb_#{width}x#{height}_#{Path.basename(media_file.filename)}", "thumbnails")
      Storage.upload(tmp_thumbnail, key, content_type: "image/jpeg")
    after
      # Clean up temp file
      File.rm(tmp_thumbnail)
    end
  end

  defp generate_video_thumbnail(media_file, width, height) do
    # Create a temporary file for the thumbnail
    tmp_dir = System.tmp_dir!()
    tmp_thumbnail = Path.join(tmp_dir, "thumb_#{:os.system_time(:millisecond)}.jpg")

    try do
      # Extract frame with FFmpeg
      args = [
        "-i", media_file.file_path,
        "-ss", "00:00:05", # 5 seconds in
        "-vframes", "1",
        "-vf", "scale=#{width}:#{height}:force_original_aspect_ratio=decrease",
        "-y", # Overwrite output files without asking
        tmp_thumbnail
      ]

      case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
        {_, 0} ->
          # Upload the thumbnail to storage
          key = Storage.generate_key("thumb_#{width}x#{height}_#{Path.basename(media_file.filename, Path.extname(media_file.filename))}.jpg", "thumbnails")
          Storage.upload(tmp_thumbnail, key, content_type: "image/jpeg")
        {error, _} ->
          {:error, "Failed to generate video thumbnail: #{error}"}
      end
    after
      # Clean up temp file
      File.rm(tmp_thumbnail)
    end
  end

  defp generate_document_thumbnail(media_file, width, height) do
    if String.ends_with?(String.downcase(media_file.file_path), ".pdf") do
      # Create temporary files
      tmp_dir = System.tmp_dir!()
      tmp_thumbnail = Path.join(tmp_dir, "thumb_#{:os.system_time(:millisecond)}")

      try do
        # Convert first page to image with pdftoppm
        args = [
          "-jpeg",
          "-singlefile",
          "-scale-to", "#{width}",
          media_file.file_path,
          tmp_thumbnail
        ]

        case System.cmd("pdftoppm", args, stderr_to_stdout: true) do
          {_, 0} ->
            # pdftoppm adds -1 suffix for single page output
            output_file = "#{tmp_thumbnail}-1.jpg"
            if File.exists?(output_file) do
              # Upload the thumbnail to storage
              key = Storage.generate_key("thumb_#{width}x#{height}_#{Path.basename(media_file.filename, Path.extname(media_file.filename))}.jpg", "thumbnails")
              Storage.upload(output_file, key, content_type: "image/jpeg")
            else
              generate_default_icon(media_file, width, height, "document")
            end
          _ ->
            generate_default_icon(media_file, width, height, "document")
        end
      after
        # Clean up temp files
        File.rm("#{tmp_thumbnail}-1.jpg")
      end
    else
      generate_default_icon(media_file, width, height, "document")
    end
  end

  defp generate_audio_thumbnail(media_file, width, height) do
    generate_default_icon(media_file, width, height, "audio")
  end

  defp generate_default_icon(media_file, width, height, type) do
    # Create a temporary file for the icon
    tmp_dir = System.tmp_dir!()
    tmp_icon = Path.join(tmp_dir, "#{type}_icon_#{:os.system_time(:millisecond)}.png")

    try do
      # Check if default icon exists
      icons_path = Application.app_dir(:frestyl, "priv/static/images/icons")
      icon_path = Path.join(icons_path, "#{type}.png")

      if File.exists?(icon_path) do
        # Resize existing icon
        Mogrify.open(icon_path)
        |> Mogrify.resize_to_limit("#{width}x#{height}")
        |> Mogrify.save(path: tmp_icon)
      else
        # Create a simple icon
        File.mkdir_p!(icons_path)

        Mogrify.open("wizard:") # Create blank canvas
        |> Mogrify.create(path: tmp_icon, size: "#{width}x#{height}", background: "transparent")
        |> Mogrify.custom("fill", "#333333")
        |> Mogrify.custom("gravity", "center")
        |> Mogrify.custom("pointsize", "#{div(width, 5)}")
        |> Mogrify.custom("draw", ~s{text 0,0 "#{String.upcase(type)}"})
        |> Mogrify.save(path: tmp_icon)
      end

      # Upload the icon to storage
      key = Storage.generate_key("thumb_#{width}x#{height}_#{Path.basename(media_file.filename, Path.extname(media_file.filename))}.png", "thumbnails")
      Storage.upload(tmp_icon, key, content_type: "image/png")
    after
      # Clean up temp file
      File.rm(tmp_icon)
    end
  end
end
