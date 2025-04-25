# lib/frestyl_web/controllers/message_controller.ex
defmodule FrestylWeb.MessageController do
  use FrestylWeb, :controller

  alias Frestyl.Channels

  def delete(conn, %{"id" => id, "channel_slug" => channel_slug, "room_slug" => room_slug}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user do
      room = Channels.get_room_by_slug(channel.id, room_slug)

      if room do
        message = Channels.get_message!(id)

        # User can delete their own messages or any message if they have delete_messages permission
        if message.user_id == user.id || Channels.has_permission?(user, channel, "delete_messages") do
          case Channels.delete_message(message) do
            {:ok, _} ->
              conn
              |> put_flash(:info, "Message deleted successfully.")
              |> redirect(to: ~p"/channels/#{channel_slug}/rooms/#{room_slug}")

            {:error, _} ->
              conn
              |> put_flash(:error, "Failed to delete message.")
              |> redirect(to: ~p"/channels/#{channel_slug}/rooms/#{room_slug}")
          end
        else
          conn
          |> put_flash(:error, "You don't have permission to delete this message.")
          |> redirect(to: ~p"/channels/#{channel_slug}/rooms/#{room_slug}")
        end
      else
        conn
        |> put_flash(:error, "Room not found")
        |> redirect(to: ~p"/channels/#{channel_slug}")
      end
    else
      conn
      |> put_flash(:error, "Channel not found or you don't have access")
      |> redirect(to: ~p"/channels")
    end
  end
end
