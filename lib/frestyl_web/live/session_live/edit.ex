defmodule FrestylWeb.SessionLive.Edit do
  use FrestylWeb, :live_view

  alias Frestyl.Sessions
  alias Frestyl.Channels

  def mount(%{"channel_slug" => channel_slug, "id" => session_id}, _session, socket) do
    channel = Channels.get_channel_by_slug!(channel_slug)
    session = Sessions.get_session!(session_id)

    # Verify user can edit this session
    if session.creator_id != socket.assigns.current_user.id do
      {:ok, socket |> put_flash(:error, "Not authorized") |> redirect(to: ~p"/channels/#{channel.slug}")}
    else
      changeset = Sessions.change_session(session)

      {:ok, assign(socket,
        channel: channel,
        session: session,
        changeset: changeset,
        page_title: "Edit Session"
      )}
    end
  end

  def handle_event("save", %{"session" => session_params}, socket) do
    case Sessions.update_session(socket.assigns.session, session_params) do
      {:ok, session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Session updated successfully")
         |> redirect(to: ~p"/channels/#{socket.assigns.channel.slug}/sessions/#{session.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("delete", _params, socket) do
    {:ok, _} = Sessions.delete_session(socket.assigns.session)

    {:noreply,
     socket
     |> put_flash(:info, "Session deleted successfully")
     |> redirect(to: ~p"/channels/#{socket.assigns.channel.slug}")}
  end
end
