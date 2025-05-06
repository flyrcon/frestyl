# lib/frestyl_web/controllers/media_controller.ex
defmodule FrestylWeb.MediaController do
  use FrestylWeb, :controller

  alias Frestyl.Media
  alias Frestyl.Media.{Asset, AssetVersion, Streamer}

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
end
