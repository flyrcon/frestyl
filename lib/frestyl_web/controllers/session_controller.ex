defmodule FrestylWeb.SessionController do
  use FrestylWeb, :controller

  alias Frestyl.Sessions
  alias Frestyl.Sessions.Session
  alias Frestyl.Media

  def index(conn, _params) do
    user_id = conn.assigns.current_user.id
    upcoming_sessions = Sessions.list_upcoming_sessions_for_user(user_id)
    active_sessions = Sessions.list_active_sessions_for_user(user_id)

    render(conn, :index, upcoming_sessions: upcoming_sessions, active_sessions: active_sessions)
  end

  def new(conn, _params) do
    changeset = Sessions.change_session(%Session{})
    render(conn, :new, changeset: changeset)
  end

def create(conn, %{"session" => session_params}) do
  case Sessions.create_session(session_params) do
    {:ok, session} ->
      # If this is one of the user's first few sessions, offer setup assistance
      current_user = conn.assigns.current_user
      session_count = Sessions.count_user_sessions(current_user.id)

      if session_count <= 3 do
        Task.start(fn ->
          AIAssistant.assist_with_setup(current_user.id, "session", %{
            session_id: session.id,
            name: session.name,
            type: session.type
          })
        end)
      end

      conn
      |> put_flash(:info, "Session created successfully.")
      |> redirect(to: ~p"/sessions/#{session}")

    {:error, %Ecto.Changeset{} = changeset} ->
      render(conn, :new, changeset: changeset)
  end
end

  def show(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user.id
    session = Sessions.get_session_with_details!(id)

    if user_authorized?(user_id, session) do
      media_items = Media.list_session_media(id)
      render(conn, :show, session: session, media_items: media_items)
    else
      unauthorized_access(conn, "You don't have permission to view this session.", ~p"/sessions")
    end
  end

  def edit(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user.id
    session = Sessions.get_session!(id)

    if session.creator_id == user_id do
      changeset = Sessions.change_session(session)
      render(conn, :edit, session: session, changeset: changeset)
    else
      unauthorized_access(conn, "Only the session creator can edit session details.", ~p"/sessions/#{session}")
    end
  end

  def update(conn, %{"id" => id, "session" => session_params}) do
    user_id = conn.assigns.current_user.id
    session = Sessions.get_session!(id)

    if session.creator_id == user_id do
      case Sessions.update_session(session, session_params) do
        {:ok, session} ->
          conn
          |> put_flash(:info, "Session updated successfully.")
          |> redirect(to: ~p"/sessions/#{session}")

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, :edit, session: session, changeset: changeset)
      end
    else
      unauthorized_access(conn, "Only the session creator can update session details.", ~p"/sessions/#{session}")
    end
  end

  def delete(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user.id
    session = Sessions.get_session!(id)

    if session.creator_id == user_id do
      {:ok, _session} = Sessions.delete_session(session)

      conn
      |> put_flash(:info, "Session deleted successfully.")
      |> redirect(to: ~p"/sessions")
    else
      unauthorized_access(conn, "Only the session creator can delete the session.", ~p"/sessions/#{session}")
    end
  end

  def join(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user.id

    case Sessions.add_participant(id, user_id) do
      {:ok, _session} ->
        conn
        |> put_flash(:info, "Joined session successfully.")
        |> redirect(to: ~p"/sessions/#{id}")

      {:error, :already_added} ->
        conn
        |> put_flash(:info, "You are already a participant in this session.")
        |> redirect(to: ~p"/sessions/#{id}")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error joining session.")
        |> redirect(to: ~p"/sessions")
    end
  end

  def leave(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user.id
    session = Sessions.get_session!(id)

    if session.creator_id == user_id do
      conn
      |> put_flash(:error, "Session creators cannot leave their own sessions.")
      |> redirect(to: ~p"/sessions/#{id}")
    else
      {:ok, _session} = Sessions.remove_participant(id, user_id)

      conn
      |> put_flash(:info, "Left session successfully.")
      |> redirect(to: ~p"/sessions")
    end
  end

  def start(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user.id
    session = Sessions.get_session!(id)

    if creator?(session, user_id) do
      case Sessions.start_session(session) do
        {:ok, _session} ->
          conn
          |> put_flash(:info, "Session started successfully.")
          |> redirect(to: ~p"/sessions/#{id}/room")

        {:error, _changeset} ->
          conn
          |> put_flash(:error, "Error starting session.")
          |> redirect(to: ~p"/sessions/#{id}")
      end
    else
      unauthorized_access(conn, "Only the session creator can start the session.", ~p"/sessions/#{id}")
    end
  end

  def end_session(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user.id
    session = Sessions.get_session!(id)

    if creator?(session, user_id) do
      case Sessions.end_session(session) do
        {:ok, _session} ->
          conn
          |> put_flash(:info, "Session ended successfully.")
          |> redirect(to: ~p"/sessions/#{id}")

        {:error, _changeset} ->
          conn
          |> put_flash(:error, "Error ending session.")
          |> redirect(to: ~p"/sessions/#{id}")
      end
    else
      unauthorized_access(conn, "Only the session creator can end the session.", ~p"/sessions/#{id}")
    end
  end

  def room(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user.id
    session = Sessions.get_session_with_details!(id)

    if user_authorized?(user_id, session) do
      if session.status == :in_progress do
        render(conn, :room, session: session)
      else
        conn
        |> put_flash(:error, "This session is not currently active.")
        |> redirect(to: ~p"/sessions/#{id}")
      end
    else
      unauthorized_access(conn, "You don't have permission to join this session.", ~p"/sessions")
    end
  end

  # Helper functions

  defp creator?(session, user_id) do
    session.creator_id == user_id
  end

  defp user_authorized?(user_id, session) do
    creator?(session, user_id) ||
    Enum.any?(session.participants, fn p -> p.id == user_id end)
  end

  defp unauthorized_access(conn, message, redirect_path) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: redirect_path)
  end
end
