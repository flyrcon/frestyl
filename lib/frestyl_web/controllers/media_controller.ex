# lib/frestyl_web/controllers/media_controller.ex
defmodule FrestylWeb.MediaController do
  use FrestylWeb, :controller

  alias Frestyl.Media
  alias Frestyl.Media.{Asset, AssetVersion, Streamer}

  plug :add_cache_headers when action in [:serve_file, :download, :thumbnail, :stream]


  def index(conn, _params) do
    assets = Media.list_assets()
    render(conn, :index, assets: assets)
  end

  def show(conn, %{"id" => id}) do
    asset = Media.get_asset!(id)
    versions = Media.list_asset_versions(asset)
    render(conn, :show, asset: asset, versions: versions)
  end

  def new(conn, _params) do
    changeset = Media.change_asset(%Asset{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"asset" => asset_params}) do
    # Add the current user as the owner
    asset_params = Map.put(asset_params, "owner_id", conn.assigns.current_user.id)

    case Media.create_asset(asset_params) do
      {:ok, asset} ->
        conn
        |> put_flash(:info, "Asset created successfully.")
        |> redirect(to: ~p"/media/#{asset}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    asset = Media.get_asset!(id)

    # Check if user has permission to edit
    if Media.user_can_access?(asset, conn.assigns.current_user.id, :edit) do
      changeset = Media.change_asset(asset)
      render(conn, :edit, asset: asset, changeset: changeset)
    else
      conn
      |> put_flash(:error, "You don't have permission to edit this asset.")
      |> redirect(to: ~p"/media/#{asset}")
    end
  end

  def serve_file(conn, %{"path" => path}) do
    file_path = Path.join([Application.get_env(:frestyl, :upload_dir) | path])

    case File.read(file_path) do
      {:ok, content} ->
        content_type = MIME.from_path(file_path)

        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("content-disposition", "inline; filename=\"#{Path.basename(file_path)}\"")
        |> send_resp(200, content)

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> text("File not found")
    end
  end

  def update(conn, %{"id" => id, "asset" => asset_params}) do
    asset = Media.get_asset!(id)

    # Check if user has permission to edit
    if Media.user_can_access?(asset, conn.assigns.current_user.id, :edit) do
      case Media.update_asset(asset, asset_params) do
        {:ok, asset} ->
          conn
          |> put_flash(:info, "Asset updated successfully.")
          |> redirect(to: ~p"/media/#{asset}")

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, :edit, asset: asset, changeset: changeset)
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to edit this asset.")
      |> redirect(to: ~p"/media/#{asset}")
    end
  end

  def delete(conn, %{"id" => id}) do
    asset = Media.get_asset!(id)

    # Check if user has permission to delete
    if Media.user_can_access?(asset, conn.assigns.current_user.id, :owner) do
      {:ok, _} = Media.delete_asset(asset)

      conn
      |> put_flash(:info, "Asset deleted successfully.")
      |> redirect(to: ~p"/media")
    else
      conn
      |> put_flash(:error, "You don't have permission to delete this asset.")
      |> redirect(to: ~p"/media/#{asset}")
    end
  end

  def upload_version(conn, %{"asset_id" => asset_id, "version" => version_params}) do
    asset = Media.get_asset!(asset_id)

    # Check if user has permission to upload
    if Media.user_can_access?(asset, conn.assigns.current_user.id, :edit) do
      upload = version_params["file"]

      # Store the uploaded file
      case Frestyl.Media.Storage.store_file(upload, asset) do
        {:ok, file_path} ->
          # Create a new version record
          version_attrs = %{
            "file_path" => file_path,
            "file_size" => upload.size,
            "created_by_id" => conn.assigns.current_user.id,
            "metadata" => %{
              "original_filename" => upload.filename,
              "content_type" => upload.content_type
            }
          }

          case Media.create_asset_version(asset, version_attrs) do
            {:ok, _version} ->
              conn
              |> put_flash(:info, "New version uploaded successfully.")
              |> redirect(to: ~p"/media/#{asset}")

            {:error, _changeset} ->
              conn
              |> put_flash(:error, "Error creating version record.")
              |> redirect(to: ~p"/media/#{asset}")
          end

        {:error, reason} ->
          conn
          |> put_flash(:error, "Error uploading file: #{reason}")
          |> redirect(to: ~p"/media/#{asset}")
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to add versions to this asset.")
      |> redirect(to: ~p"/media/#{asset}")
    end
  end

  def serve_file(conn, %{"path" => path}) do
    path_parts = path
    file_path = Path.join([Application.app_dir(:frestyl), "priv", "uploads"] ++ path_parts)

    if File.exists?(file_path) do
      # Try to get the media item from the database to check permissions
      media_file = Media.get_media_file_by_path(path_parts)

      if is_nil(media_file) || can_access_media?(conn.assigns.current_user, media_file) do
        # Either it's a public file or the user has access
        content_type = MIME.from_path(file_path)

        conn
        |> put_resp_content_type(content_type)
        |> send_file(200, file_path)
      else
        conn
        |> put_status(:forbidden)
        |> put_flash(:error, "You don't have permission to access this file.")
        |> redirect(to: Routes.page_path(conn, :index))
      end
    else
      conn
      |> put_status(:not_found)
      |> put_view(FrestylWeb.ErrorView)
      |> render("404.html")
    end
  end

  # In your MediaController
  def download(conn, %{"id" => id}) do
    media_item = Media.get_media_file!(id)

    # Check if user has access to this file
    if has_access_to_file?(conn.assigns.current_user, media_item) do
      # For branding media, apply longer cache times
      cache_control = if media_item.category == "branding" do
        # Cache for 1 day, public resources (CDNs can cache)
        "public, max-age=86400"
      else
        # Cache for 1 hour, private (only browser can cache)
        "private, max-age=3600"
      end

      conn
      |> put_resp_header("cache-control", cache_control)
      |> put_resp_content_type(media_item.mime_type)
      |> put_resp_header("content-disposition", content_disposition_header(media_item))
      |> send_file(200, media_item.file_path)
    else
      conn
      |> put_status(:forbidden)
      |> render(FrestylWeb.ErrorView, "403.html")
    end
  end

  # Helper to determine content disposition
  defp content_disposition_header(media_item) do
    if media_item.category == "branding" and media_item.media_type in ["image", "video"] do
      # For branding images/videos, inline display
      ~s(inline; filename="#{media_item.filename}")
    else
      # For other files, download
      ~s(attachment; filename="#{media_item.filename}")
    end
  end

  # Helper to check if user has access to the file
  defp has_access_to_file?(user, media_item) do
    cond do
      # Public media files accessible to everyone
      media_item.visibility == "public" ->
        true

      # Branding media files only accessible to admins and channel owners
      media_item.category == "branding" ->
        user.role == "admin" or media_item.channel.owner_id == user.id

      # Check if user is a member of the channel
      true ->
        Frestyl.Channels.user_member?(user, media_item.channel_id)
    end
  end


  def public_branding(conn, %{"id" => id}) do
    case Media.get_public_branding_file(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(FrestylWeb.ErrorView)
        |> render("404.html")

      media_file ->
        # Check if CDN is enabled for this file
        if Application.get_env(:frestyl, :cdn)[:enabled] &&
          media_file.category == "branding" &&
          media_file.visibility == "public" do
          # Redirect to CDN URL
          cdn_url = Frestyl.CDN.url(media_file.file_path)
          redirect(conn, external: cdn_url)
        else
          # Public branding assets can be cached aggressively
          conn = conn
          |> put_resp_header("cache-control", "public, max-age=2592000") # 30 days

          conn
          |> put_resp_content_type(media_file.mime_type)
          |> send_file(200, Media.get_file_path(media_file))
        end
    end
  end

  def stream(conn, %{"asset_id" => asset_id, "version_id" => version_id}) do
    asset = Media.get_asset!(asset_id)
    version = Media.get_asset_version!(version_id)

    # Check if user has permission to view
    if Media.user_can_access?(asset, conn.assigns.current_user.id, :view) do
      Streamer.stream_media(conn, version)
    else
      conn
      |> put_status(403)
      |> put_view(json: FrestylWeb.ErrorJSON)
      |> put_flash(:error, "You don't have permission to view this media.")
      |> render(:"403")
    end
  end

  defp add_cache_headers(conn, _opts) do
    path = conn.request_path
    etag = generate_etag(path)
    last_modified = get_last_modified(path)

    conn = conn
    |> put_resp_header("vary", "accept-encoding")

    # Add ETag if available
    conn = if etag, do: put_resp_header(conn, "etag", etag), else: conn

    # Add Last-Modified if available
    conn = if last_modified, do: put_resp_header(conn, "last-modified", format_http_date(last_modified)), else: conn

    # Check for conditional request headers
    cond do
      # If-None-Match
      has_matching_etag?(conn, etag) ->
        conn
        |> send_resp(304, "")
        |> halt()

      # If-Modified-Since
      has_not_been_modified_since?(conn, last_modified) ->
        conn
        |> send_resp(304, "")
        |> halt()

      true ->
        # Default cache-control header
        # For media files, use a default cache time
        put_resp_header(conn, "cache-control", "private, max-age=3600")
    end
  end

  # Helper functions for caching

  defp has_matching_etag?(conn, nil), do: false
  defp has_matching_etag?(conn, etag) do
    case get_req_header(conn, "if-none-match") do
      [req_etag] -> req_etag == etag
      _ -> false
    end
  end

  defp has_not_been_modified_since?(conn, nil), do: false
  defp has_not_been_modified_since?(conn, last_modified) do
    case get_req_header(conn, "if-modified-since") do
      [if_modified_since] ->
        case parse_http_date(if_modified_since) do
          nil -> false  # Invalid date format, don't consider it modified
          if_modified_since_date ->
            try do
              DateTime.compare(last_modified, if_modified_since_date) != :gt
            rescue
              # Handle any errors in DateTime.compare
              _ -> false
            end
        end
      _ ->
        false
    end
  end

  # Generate an ETag for a file
  defp generate_etag(path) do
    if String.starts_with?(path, "/uploads/") do
      file_path = Path.join([Application.app_dir(:frestyl), "priv", path])

      if File.exists?(file_path) do
        %{size: size, mtime: mtime} = File.stat!(file_path, time: :posix)
        hash = :crypto.hash(:md5, "#{path}:#{size}:#{mtime}") |> Base.encode16(case: :lower)
        ~s("#{hash}")
      else
        nil
      end
    else
      nil
    end
  end

  # Get the last modified time for a file
  defp get_last_modified(path) do
    if String.starts_with?(path, "/uploads/") do
      file_path = Path.join([Application.app_dir(:frestyl), "priv", path])

      if File.exists?(file_path) do
        case File.stat(file_path, time: :posix) do
          {:ok, %{mtime: mtime}} ->
            DateTime.from_unix!(mtime)
          _ ->
            nil
        end
      else
        nil
      end
    else
      nil
    end
  end

  # Parse an HTTP date
  defp parse_http_date(date_string) do
    try do
      # Example: "Wed, 21 Oct 2015 07:28:00 GMT"
      [_, day, month, year, hour, minute, second] =
        Regex.run(~r/\w+, (\d+) (\w+) (\d+) (\d+):(\d+):(\d+) GMT/, date_string)

      month_number = month_to_number(month)

      {:ok, datetime} = NaiveDateTime.new(
        String.to_integer(year),
        month_number,
        String.to_integer(day),
        String.to_integer(hour),
        String.to_integer(minute),
        String.to_integer(second)
      )

      DateTime.from_naive!(datetime, "Etc/UTC")
    rescue
      _ -> nil
    end
  end

  # Format a datetime as an HTTP date
  defp format_http_date(datetime) do
    # Use built-in Calendar functionality
    Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S GMT")
  end

  defp can_access_media?(user, nil), do: true  # Public files with no DB entry are accessible
  defp can_access_media?(user, media_file) do
    cond do
      # Admin users can access all files
      user.role == "admin" ->
        true

      # Public files are accessible to all authenticated users
      media_file.visibility == "public" ->
        true

      # Branding assets are only accessible to channel owners and admins
      media_file.category == "branding" ->
        channel = Frestyl.Channels.get_channel!(media_file.channel_id)
        channel.owner_id == user.id ||
        Frestyl.Channels.is_channel_admin?(user.id, channel.id)

      # Channel members can access channel files
      media_file.channel_id ->
        Frestyl.Channels.user_member?(user, %{id: media_file.channel_id})

      # File owner can access their own files
      media_file.user_id == user.id ->
        true

      # Default deny
      true ->
        false
    end
  end

  # Convert month name to number
  defp month_to_number("Jan"), do: 1
  defp month_to_number("Feb"), do: 2
  defp month_to_number("Mar"), do: 3
  defp month_to_number("Apr"), do: 4
  defp month_to_number("May"), do: 5
  defp month_to_number("Jun"), do: 6
  defp month_to_number("Jul"), do: 7
  defp month_to_number("Aug"), do: 8
  defp month_to_number("Sep"), do: 9
  defp month_to_number("Oct"), do: 10
  defp month_to_number("Nov"), do: 11
  defp month_to_number("Dec"), do: 12

end
