# lib/frestyl_web/controllers/file_controller.ex
defmodule FrestylWeb.FileController do
  use FrestylWeb, :controller

  alias Frestyl.Channels
  alias Frestyl.FileStorage

  def index(conn, %{"channel_slug" => channel_slug}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel do
      # Check if channel is public or user has permission to view it
      cond do
        channel.is_public ->
          files = Channels.list_channel_files(channel.id)
          render(conn, :channel_index, channel: channel, files: files)

        user && Channels.has_permission?(user, channel, "view_channel") ->
          files = Channels.list_channel_files(channel.id)
          render(conn, :channel_index, channel: channel, files: files)

        true ->
          conn
          |> put_flash(:error, "This channel is private")
          |> redirect(to: ~p"/channels")
      end
    else
      conn
      |> put_flash(:error, "Channel not found")
      |> redirect(to: ~p"/channels")
    end
  end

  def index(conn, %{"channel_slug" => channel_slug, "room_slug" => room_slug}) do
    channel = Channels.get_channel_by_slug(channel_slug)

    if channel do
      room = Channels.get_room_by_slug(channel.id, room_slug)

      if room do
        # Check if room is public or user has permission to view it
        user = conn.assigns[:current_user]

        cond do
          room.is_public && channel.is_public ->
            files = Channels.list_room_files(room.id)
            render(conn, :room_index, channel: channel, room: room, files: files)

          user && Channels.has_permission?(user, channel, "view_channel") ->
            files = Channels.list_room_files(room.id)
            render(conn, :room_index, channel: channel, room: room, files: files)

          true ->
            conn
            |> put_flash(:error, "This room is private")
            |> redirect(to: ~p"/channels/#{channel_slug}")
        end
      else
        conn
        |> put_flash(:error, "Room not found")
        |> redirect(to: ~p"/channels/#{channel_slug}")
      end
    else
      conn
      |> put_flash(:error, "Channel not found")
      |> redirect(to: ~p"/channels")
    end
  end

  def new(conn, %{"channel_slug" => channel_slug}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "send_messages") do
      render(conn, :new_channel_file, channel: channel)
    else
      conn
      |> put_flash(:error, "You don't have permission to upload files to this channel")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  def new(conn, %{"channel_slug" => channel_slug, "room_slug" => room_slug}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "send_messages") do
      room = Channels.get_room_by_slug(channel.id, room_slug)

      if room do
        render(conn, :new_room_file, channel: channel, room: room)
      else
        conn
        |> put_flash(:error, "Room not found")
        |> redirect(to: ~p"/channels/#{channel_slug}")
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to upload files to this room")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  def create(conn, %{"channel_slug" => channel_slug, "file" => file_params}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "send_messages") do
      # Check if we have file data
      with %{"data" => data, "filename" => filename} <- file_params,
           true <- FileStorage.allowed_extension?(filename) do

        # Create file attachment with description (if provided)
        description = file_params["description"] || ""

        case Channels.create_file_attachment(%{
          "user_id" => user.id,
          "channel_id" => channel.id,
          "description" => description
        }, %{
          data: data,
          filename: filename
        }) do
          {:ok, _file} ->
            conn
            |> put_flash(:info, "File uploaded successfully.")
            |> redirect(to: ~p"/channels/#{channel_slug}/files")

          {:error, reason} when is_binary(reason) ->
            conn
            |> put_flash(:error, reason)
            |> render(:new_channel_file, channel: channel)

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_flash(:error, "Failed to create file record.")
            |> render(:new_channel_file, channel: channel, changeset: changeset)
        end
      else
        false ->
          conn
          |> put_flash(:error, "File type not allowed. Supported types: #{Enum.join(FileStorage.allowed_extensions(), ", ")}")
          |> render(:new_channel_file, channel: channel)

        _ ->
          conn
          |> put_flash(:error, "No file selected.")
          |> render(:new_channel_file, channel: channel)
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to upload files to this channel")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  def create(conn, %{"channel_slug" => channel_slug, "room_slug" => room_slug, "file" => file_params}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "send_messages") do
      room = Channels.get_room_by_slug(channel.id, room_slug)

      if room do
        # Check if we have file data
        with %{"data" => data, "filename" => filename} <- file_params,
             true <- FileStorage.allowed_extension?(filename) do

          # Create file attachment with description (if provided)
          description = file_params["description"] || ""

          case Channels.create_file_attachment(%{
            "user_id" => user.id,
            "room_id" => room.id,
            "description" => description
          }, %{
            data: data,
            filename: filename
          }) do
            {:ok, _file} ->
              conn
              |> put_flash(:info, "File uploaded successfully.")
              |> redirect(to: ~p"/channels/#{channel_slug}/rooms/#{room_slug}/files")

            {:error, reason} when is_binary(reason) ->
              conn
              |> put_flash(:error, reason)
              |> render(:new_room_file, channel: channel, room: room)

            {:error, %Ecto.Changeset{} = changeset} ->
              conn
              |> put_flash(:error, "Failed to create file record.")
              |> render(:new_room_file, channel: channel, room: room, changeset: changeset)
          end
        else
          false ->
            conn
            |> put_flash(:error, "File type not allowed. Supported types: #{Enum.join(FileStorage.allowed_extensions(), ", ")}")
            |> render(:new_room_file, channel: channel, room: room)

          _ ->
            conn
            |> put_flash(:error, "No file selected.")
            |> render(:new_room_file, channel: channel, room: room)
        end
      else
        conn
        |> put_flash(:error, "Room not found")
        |> redirect(to: ~p"/channels/#{channel_slug}")
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to upload files to this room")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  def delete(conn, %{"id" => id, "channel_slug" => channel_slug}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]
    file = Channels.get_file_attachment!(id)

    cond do
      !channel ->
        conn
        |> put_flash(:error, "Channel not found")
        |> redirect(to: ~p"/channels")

      !user ->
        conn
        |> put_flash(:error, "You must be logged in")
        |> redirect(to: ~p"/login")

      # File owners can delete their own files
      file.user_id == user.id || Channels.has_permission?(user, channel, "delete_messages") ->
        case Channels.delete_file_attachment(file) do
          {:ok, _} ->
            conn
            |> put_flash(:info, "File deleted successfully.")
            |> redirect_to_files_page(file)

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Failed to delete file.")
            |> redirect_to_files_page(file)
        end

      true ->
        conn
        |> put_flash(:error, "You don't have permission to delete this file")
        |> redirect_to_files_page(file)
    end
  end

  # Helper to redirect back to the appropriate files page
  defp redirect_to_files_page(conn, file) do
    if file.room_id do
      room = Channels.get_room!(file.room_id)
      channel = Channels.get_channel!(room.channel_id)
      redirect(conn, to: ~p"/channels/#{channel.slug}/rooms/#{room.slug}/files")
    else
      channel = Channels.get_channel!(file.channel_id)
      redirect(conn, to: ~p"/channels/#{channel.slug}/files")
    end
  end

  # In your MediaController or FileController
  def serve_file(conn, %{"path" => path}) do
    cache_key = "media_file:#{Enum.join(path, "/")}"

    case Frestyl.Cache.get(cache_key) do
      {:ok, {file_data, content_type, filename}} ->
        # Serve from cache
        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, file_data)

      :error ->
        # Find the file and cache it
        full_path = Path.join([Application.app_dir(:frestyl), "priv", "uploads"] ++ path)

        if File.exists?(full_path) do
          file_data = File.read!(full_path)
          content_type = MIME.from_path(full_path)
          filename = Path.basename(full_path)

          # Cache the file data
          Frestyl.Cache.put(cache_key, {file_data, content_type, filename})

          conn
          |> put_resp_content_type(content_type)
          |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
          |> send_resp(200, file_data)
        else
          conn
          |> put_status(:not_found)
          |> render(FrestylWeb.ErrorView, "404.html")
        end
    end
  end
end
