# lib/frestyl/portfolios/video_thumbnails.ex
# Video Thumbnail Generation and Management System

defmodule Frestyl.Portfolios.VideoThumbnails do
  @moduledoc """
  Handles video thumbnail generation, caching, and management for portfolio videos.
  Supports both server-side and client-side thumbnail generation.
  """

  alias Frestyl.{Portfolios, Storage}
  require Logger

  # ============================================================================
  # THUMBNAIL GENERATION
  # ============================================================================

  @doc """
  Generates a thumbnail for a video file and saves it to storage.
  """
  def generate_video_thumbnail(video_path, options \\ %{}) do
    default_options = %{
      width: 320,
      height: 180,
      time_offset: 1.0,  # seconds into video
      format: "jpg",
      quality: 85
    }

    opts = Map.merge(default_options, options)

    case detect_thumbnail_method() do
      :ffmpeg -> generate_thumbnail_with_ffmpeg(video_path, opts)
      :client_side -> generate_client_side_placeholder(video_path, opts)
      :placeholder -> generate_static_placeholder(opts)
    end
  end

  @doc """
  Processes a base64 thumbnail data from the client and saves it.
  """
  def save_client_thumbnail(video_filename, thumbnail_data, portfolio_id) do
    try do
      # Decode base64 thumbnail
      case Base.decode64(thumbnail_data) do
        {:ok, image_data} ->
          # Generate thumbnail filename
          base_name = Path.rootname(video_filename)
          timestamp = System.system_time(:second)
          thumbnail_filename = "#{base_name}_thumb_#{timestamp}.jpg"

          # Save to thumbnails directory
          thumbnail_dir = Path.join(["priv", "static", "uploads", "thumbnails"])
          File.mkdir_p!(thumbnail_dir)

          thumbnail_path = Path.join(thumbnail_dir, thumbnail_filename)

          case File.write(thumbnail_path, image_data) do
            :ok ->
              web_path = convert_to_web_path(thumbnail_path)

              {:ok, %{
                filename: thumbnail_filename,
                file_path: thumbnail_path,
                web_url: web_path,
                file_size: byte_size(image_data),
                generated_at: DateTime.utc_now(),
                method: "client_generated"
              }}

            {:error, reason} ->
              {:error, "Failed to save thumbnail: #{reason}"}
          end

        :error ->
          {:error, "Invalid thumbnail data"}
      end
    rescue
      error ->
        Logger.error("Thumbnail save error: #{Exception.message(error)}")
        {:error, "Thumbnail processing failed"}
    end
  end

  @doc """
  Gets or generates a thumbnail for a video section.
  """
  def get_section_thumbnail(section) do
    case section.section_type do
      :media_showcase ->
        content = section.content || %{}

        case Map.get(content, "video_type") do
          "introduction" ->
            get_video_intro_thumbnail(content)
          _ ->
            get_default_media_thumbnail()
        end

      _ ->
        get_section_type_thumbnail(section.section_type)
    end
  end

  # ============================================================================
  # THUMBNAIL CACHING AND OPTIMIZATION
  # ============================================================================

  @doc """
  Caches thumbnail metadata in the section content for quick access.
  """
  def cache_thumbnail_in_section(section, thumbnail_info) do
    updated_content = Map.merge(section.content || %{}, %{
      "thumbnail" => %{
        "url" => thumbnail_info.web_url,
        "filename" => thumbnail_info.filename,
        "generated_at" => DateTime.to_iso8601(thumbnail_info.generated_at),
        "method" => thumbnail_info.method,
        "file_size" => thumbnail_info.file_size
      }
    })

    Portfolios.update_section(section, %{content: updated_content})
  end

  @doc """
  Regenerates thumbnails for all videos in a portfolio (maintenance function).
  """
  def regenerate_portfolio_thumbnails(portfolio_id) do
    portfolio_id
    |> Portfolios.list_portfolio_sections()
    |> Enum.filter(&is_video_section?/1)
    |> Enum.map(&regenerate_section_thumbnail/1)
    |> Enum.reduce({0, 0}, fn result, {success, failed} ->
      case result do
        {:ok, _} -> {success + 1, failed}
        {:error, _} -> {success, failed + 1}
      end
    end)
    |> case do
      {success, 0} -> {:ok, "Regenerated #{success} thumbnails"}
      {success, failed} -> {:partial, "Regenerated #{success} thumbnails, #{failed} failed"}
    end
  end

  # ============================================================================
  # RESPONSIVE THUMBNAIL SIZES
  # ============================================================================

  @doc """
  Generates multiple thumbnail sizes for responsive display.
  """
  def generate_responsive_thumbnails(video_path, base_filename) do
    sizes = [
      %{name: "small", width: 160, height: 90},    # 16:9 small
      %{name: "medium", width: 320, height: 180},  # 16:9 medium
      %{name: "large", width: 640, height: 360}    # 16:9 large
    ]

    Enum.map(sizes, fn size ->
      options = %{
        width: size.width,
        height: size.height,
        time_offset: 1.0,
        format: "jpg",
        quality: 85
      }

      size_filename = "#{Path.rootname(base_filename)}_#{size.name}.jpg"

      case generate_video_thumbnail(video_path, options) do
        {:ok, thumbnail_info} ->
          {:ok, Map.put(thumbnail_info, :size_name, size.name)}
        error ->
          error
      end
    end)
  end

  # ============================================================================
  # THUMBNAIL METHODS
  # ============================================================================

  defp detect_thumbnail_method do
    cond do
      System.find_executable("ffmpeg") -> :ffmpeg
      Application.get_env(:frestyl, :enable_client_thumbnails, true) -> :client_side
      true -> :placeholder
    end
  end

  defp generate_thumbnail_with_ffmpeg(video_path, opts) do
    try do
      thumbnail_dir = Path.join(["priv", "static", "uploads", "thumbnails"])
      File.mkdir_p!(thumbnail_dir)

      base_name = Path.basename(video_path, Path.extname(video_path))
      timestamp = System.system_time(:second)
      thumbnail_filename = "#{base_name}_thumb_#{timestamp}.#{opts.format}"
      thumbnail_path = Path.join(thumbnail_dir, thumbnail_filename)

      # Build ffmpeg command
      cmd_args = [
        "-i", video_path,
        "-ss", to_string(opts.time_offset),
        "-vframes", "1",
        "-vf", "scale=#{opts.width}:#{opts.height}",
        "-q:v", to_string(opts.quality),
        "-y",  # Overwrite output file
        thumbnail_path
      ]

      case System.cmd("ffmpeg", cmd_args, stderr_to_stdout: true) do
        {_output, 0} ->
          web_path = convert_to_web_path(thumbnail_path)
          file_size = File.stat!(thumbnail_path).size

          {:ok, %{
            filename: thumbnail_filename,
            file_path: thumbnail_path,
            web_url: web_path,
            file_size: file_size,
            generated_at: DateTime.utc_now(),
            method: "ffmpeg",
            dimensions: "#{opts.width}x#{opts.height}"
          }}

        {error_output, exit_code} ->
          Logger.error("FFmpeg thumbnail generation failed: #{error_output}")
          {:error, "FFmpeg failed with exit code #{exit_code}"}
      end
    rescue
      error ->
        Logger.error("FFmpeg thumbnail error: #{Exception.message(error)}")
        generate_static_placeholder(opts)
    end
  end

  defp generate_client_side_placeholder(video_path, opts) do
    # Return info for client-side generation
    base_name = Path.basename(video_path, Path.extname(video_path))

    {:ok, %{
      method: "client_pending",
      video_path: video_path,
      base_filename: base_name,
      options: opts,
      placeholder_url: "/images/video-generating-thumbnail.png"
    }}
  end

  defp generate_static_placeholder(opts) do
    # Use a static placeholder image
    {:ok, %{
      filename: "video_placeholder.jpg",
      web_url: "/images/video-placeholder.jpg",
      file_size: 0,
      generated_at: DateTime.utc_now(),
      method: "static_placeholder",
      dimensions: "#{opts.width}x#{opts.height}"
    }}
  end

  # ============================================================================
  # THUMBNAIL RETRIEVAL HELPERS
  # ============================================================================

  defp get_video_intro_thumbnail(content) do
    case Map.get(content, "thumbnail") do
      nil ->
        # Try to generate from video URL
        video_url = Map.get(content, "video_url")
        if video_url do
          generate_thumbnail_for_url(video_url)
        else
          get_default_video_thumbnail()
        end

      thumbnail_info ->
        %{
          type: "video_thumbnail",
          url: thumbnail_info["url"],
          generated_at: thumbnail_info["generated_at"],
          method: thumbnail_info["method"]
        }
    end
  end

  defp generate_thumbnail_for_url(video_url) do
    # Convert web URL back to file path if possible
    if String.starts_with?(video_url, "/uploads/videos/") do
      filename = Path.basename(video_url)
      file_path = Path.join(["priv", "static", "uploads", "videos", filename])

      if File.exists?(file_path) do
        case generate_video_thumbnail(file_path) do
          {:ok, thumbnail_info} ->
            %{
              type: "video_thumbnail",
              url: thumbnail_info.web_url,
              generated_at: DateTime.to_iso8601(thumbnail_info.generated_at),
              method: thumbnail_info.method
            }

          {:error, _} ->
            get_default_video_thumbnail()
        end
      else
        get_default_video_thumbnail()
      end
    else
      get_default_video_thumbnail()
    end
  end

  defp get_default_video_thumbnail do
    %{
      type: "placeholder",
      url: "/images/video-placeholder.jpg",
      icon: "🎥"
    }
  end

  defp get_default_media_thumbnail do
    %{
      type: "placeholder",
      url: "/images/media-placeholder.jpg",
      icon: "📱"
    }
  end

  defp get_section_type_thumbnail(:intro), do: %{type: "icon", icon: "👋", color: "blue"}
  defp get_section_type_thumbnail(:experience), do: %{type: "icon", icon: "💼", color: "green"}
  defp get_section_type_thumbnail(:education), do: %{type: "icon", icon: "🎓", color: "purple"}
  defp get_section_type_thumbnail(:skills), do: %{type: "icon", icon: "⚡", color: "yellow"}
  defp get_section_type_thumbnail(:projects), do: %{type: "icon", icon: "🚀", color: "red"}
  defp get_section_type_thumbnail(:contact), do: %{type: "icon", icon: "📧", color: "gray"}
  defp get_section_type_thumbnail(_), do: %{type: "icon", icon: "📄", color: "gray"}

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp is_video_section?(section) do
    section.section_type == :media_showcase and
    Map.get(section.content || %{}, "video_type") == "introduction"
  end

  defp regenerate_section_thumbnail(section) do
    content = section.content || %{}
    video_url = Map.get(content, "video_url")

    if video_url do
      case generate_thumbnail_for_url(video_url) do
        %{type: "video_thumbnail"} = thumbnail_info ->
          cache_thumbnail_in_section(section, %{
            web_url: thumbnail_info.url,
            filename: "regenerated_#{System.system_time(:second)}.jpg",
            generated_at: DateTime.utc_now(),
            method: thumbnail_info.method,
            file_size: 0
          })

        _ ->
          {:error, "Failed to regenerate thumbnail"}
      end
    else
      {:error, "No video URL found"}
    end
  end

  defp convert_to_web_path(file_path) do
    try do
      if String.contains?(file_path, "priv/static") do
        file_path
        |> String.replace("priv/static", "")
        |> String.trim_leading("/")
        |> then(&("/#{&1}"))
      else
        "/uploads/thumbnails/#{Path.basename(file_path)}"
      end
    rescue
      _ -> "/uploads/thumbnails/#{Path.basename(file_path)}"
    end
  end

  # ============================================================================
  # PUBLIC API FOR THUMBNAIL MANAGEMENT
  # ============================================================================

  @doc """
  Updates the video capture hook to send thumbnail data along with video.
  """
  def extract_thumbnail_from_video_blob(video_blob_data, video_filename) do
    # This would typically be called from the enhanced video component
    # when processing video uploads

    # For now, we return a placeholder that indicates client-side generation is needed
    base_name = Path.rootname(video_filename)

    %{
      status: "pending_client_generation",
      base_filename: base_name,
      instructions: %{
        capture_time: 1.0,
        width: 320,
        height: 180,
        format: "jpeg",
        quality: 0.8
      }
    }
  end

  @doc """
  Cleanup old thumbnails to prevent storage bloat.
  """
  def cleanup_old_thumbnails(days_old \\ 30) do
    thumbnail_dir = Path.join(["priv", "static", "uploads", "thumbnails"])

    if File.exists?(thumbnail_dir) do
      cutoff_time = DateTime.utc_now() |> DateTime.add(-days_old * 24 * 3600, :second)

      thumbnail_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, [".jpg", ".jpeg", ".png"]))
      |> Enum.reduce({0, 0}, fn filename, {deleted, kept} ->
        file_path = Path.join(thumbnail_dir, filename)

        case File.stat(file_path) do
          {:ok, %{mtime: mtime}} ->
            file_datetime = DateTime.from_unix!(mtime)

            if DateTime.compare(file_datetime, cutoff_time) == :lt do
              case File.rm(file_path) do
                :ok -> {deleted + 1, kept}
                {:error, _} -> {deleted, kept + 1}
              end
            else
              {deleted, kept + 1}
            end

          {:error, _} ->
            {deleted, kept + 1}
        end
      end)
      |> case do
        {deleted, kept} ->
          {:ok, "Cleaned up #{deleted} old thumbnails, kept #{kept}"}
      end
    else
      {:ok, "No thumbnail directory found"}
    end
  end

  # ============================================================================
  # INTEGRATION WITH ENHANCED VIDEO COMPONENT
  # ============================================================================

  @doc """
  Called by the enhanced video component after successful video save.
  """
  def process_video_thumbnail(video_info, section, thumbnail_data \\ nil) do
    cond do
      # Client provided thumbnail data
      thumbnail_data ->
        case save_client_thumbnail(video_info.filename, thumbnail_data, section.portfolio_id) do
          {:ok, thumbnail_info} ->
            cache_thumbnail_in_section(section, thumbnail_info)

          {:error, reason} ->
            Logger.warning("Failed to save client thumbnail: #{reason}")
            generate_fallback_thumbnail(video_info, section)
        end

      # Try server-side generation
      File.exists?(video_info.file_path) ->
        case generate_video_thumbnail(video_info.file_path) do
          {:ok, thumbnail_info} ->
            cache_thumbnail_in_section(section, thumbnail_info)

          {:error, reason} ->
            Logger.warning("Failed to generate server thumbnail: #{reason}")
            generate_fallback_thumbnail(video_info, section)
        end

      # Use placeholder
      true ->
        generate_fallback_thumbnail(video_info, section)
    end
  end

  defp generate_fallback_thumbnail(video_info, section) do
    placeholder_info = %{
      web_url: "/images/video-placeholder.jpg",
      filename: "placeholder.jpg",
      generated_at: DateTime.utc_now(),
      method: "fallback_placeholder",
      file_size: 0
    }

    cache_thumbnail_in_section(section, placeholder_info)
  end
end
