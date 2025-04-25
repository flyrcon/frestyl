# lib/frestyl_web/controllers/room_controller.ex
defmodule FrestylWeb.RoomController do
  use FrestylWeb, :controller

  alias Frestyl.Channels
  alias Frestyl.Channels.Room

  def new(conn, %{"channel_slug" => channel_slug}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "create_room") do
      changeset = Channels.change_room(%Room{channel_id: channel.id})
      render(conn, :new, changeset: changeset, channel: channel, button_label: "Create Room")
    else
      conn
      |> put_flash(:error, "You don't have permission to create rooms in this channel")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  def create(conn, %{"channel_slug" => channel_slug, "room" => room_params}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "create_room") do
      room_params = Map.put(room_params, "channel_id", channel.id)

      case Channels.create_room(room_params) do
        {:ok, room} ->
          conn
          |> put_flash(:info, "Room created successfully.")
          |> redirect(to: ~p"/channels/#{channel_slug}/rooms/#{room.slug}")

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, :new, changeset: changeset, channel: channel, button_label: "Create Room")
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to create rooms in this channel")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  def show(conn, %{"channel_slug" => channel_slug, "slug" => slug}) do
    channel = Channels.get_channel_by_slug(channel_slug)

    if channel do
      room = Channels.get_room_by_slug(channel.id, slug)

      if room do
        # Check if room is public or user has permission to view it
        user = conn.assigns[:current_user]

        cond do
          room.is_public && channel.is_public ->
            render(conn, :show, channel: channel, room: room)

          user && Channels.has_permission?(user, channel, "view_channel") ->
            render(conn, :show, channel: channel, room: room)

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

  def edit(conn, %{"channel_slug" => channel_slug, "slug" => slug}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "manage_room") do
      room = Channels.get_room_by_slug(channel.id, slug)

      if room do
        changeset = Channels.change_room(room)
        render(conn, :edit, channel: channel, room: room, changeset: changeset, button_label: "Save Changes")
      else
        conn
        |> put_flash(:error, "Room not found")
        |> redirect(to: ~p"/channels/#{channel_slug}")
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to edit rooms in this channel")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  def update(conn, %{"channel_slug" => channel_slug, "slug" => slug, "room" => room_params}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "manage_room") do
      room = Channels.get_room_by_slug(channel.id, slug)

      if room do
        case Channels.update_room(room, room_params) do
          {:ok, updated_room} ->
            conn
            |> put_flash(:info, "Room updated successfully.")
            |> redirect(to: ~p"/channels/#{channel_slug}/rooms/#{updated_room.slug}")

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, :edit, channel: channel, room: room, changeset: changeset, button_label: "Save Changes")
        end
      else
        conn
        |> put_flash(:error, "Room not found")
        |> redirect(to: ~p"/channels/#{channel_slug}")
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to edit rooms in this channel")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  def delete(conn, %{"channel_slug" => channel_slug, "slug" => slug}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "delete_room") do
      room = Channels.get_room_by_slug(channel.id, slug)

      if room do
        {:ok, _} = Channels.delete_room(room)

        conn
        |> put_flash(:info, "Room deleted successfully.")
        |> redirect(to: ~p"/channels/#{channel_slug}")
      else
        conn
        |> put_flash(:error, "Room not found")
        |> redirect(to: ~p"/channels/#{channel_slug}")
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to delete rooms in this channel")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end
end
