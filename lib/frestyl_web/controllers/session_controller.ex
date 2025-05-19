# lib/frestyl_web/controllers/session_controller.ex
defmodule FrestylWeb.SessionController do
  use FrestylWeb, :controller

  alias Frestyl.Sessions
  alias Frestyl.Channels
  alias Frestyl.Accounts

  def index(conn, %{"channel_id" => channel_id}) do
    user_id = Plug.Conn.get_session(conn, :user_id)

    # Check if user has access to the channel
    with {:ok, channel} <- get_channel(channel_id),
         {:ok, _} <- check_channel_access(channel, user_id) do

      active_sessions = Sessions.list_active_sessions_for_channel(channel_id)
      upcoming_sessions = Sessions.list_upcoming_sessions_for_channel(channel_id)
      past_sessions = Sessions.list_past_sessions_for_channel(channel_id)

      render(conn, :index,
        channel: channel,
        active_sessions: active_sessions,
        upcoming_sessions: upcoming_sessions,
        past_sessions: past_sessions
      )
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Channel not found")
        |> redirect(to: ~p"/")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You don't have access to this channel")
        |> redirect(to: ~p"/")
    end
  end

  def show(conn, %{"id" => id}) do
    user_id = get_session(conn, :user_id)

    # Check if user has access to the session
    with {:ok, session} <- find_session(id),
         {:ok, _} <- check_session_access(session, user_id) do

      # For regular sessions, redirect to Studio LiveView
      if session.broadcast_type do
        # This is a broadcast, handle it differently
        if is_broadcast_live?(session) do
          # Redirect to LiveView for broadcast
          redirect(conn, to: ~p"/channels/#{session.channel_id}/broadcasts/#{session.id}/live")
        else
          # Show broadcast details page
          render(conn, :broadcast_details, session: session)
        end
      else
        # Regular session, redirect to studio
        redirect(conn, to: ~p"/channels/#{session.channel_id}/studio/#{session.id}")
      end
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You don't have access to this session")
        |> redirect(to: ~p"/")
    end
  end

  def create(conn, %{"session" => session_params}) do
    user_id = get_session(conn, :user_id)
    channel_id = session_params["channel_id"]

    # Check if user has permission to create sessions
    with {:ok, channel} <- get_channel(channel_id),
         {:ok, _} <- check_session_creation_permission(channel, user_id) do

      # Add creator_id to params
      session_params = Map.put(session_params, "creator_id", user_id)

      # Determine if this is a regular session or broadcast
      result = if is_nil(session_params["broadcast_type"]) do
        Sessions.create_session(session_params)
      else
        # This is a broadcast
        session_params = Map.put(session_params, "host_id", user_id)
        Sessions.create_broadcast(session_params)
      end

      case result do
        {:ok, session} ->
          conn
          |> put_flash(:info, "Session created successfully")
          |> redirect(to: ~p"/channels/#{channel_id}/sessions/#{session.id}")

        {:error, changeset} ->
          # Extract errors
          errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
          error_message = errors |> Enum.map(fn {k, v} -> "#{k}: #{v}" end) |> Enum.join(", ")

          conn
          |> put_flash(:error, "Failed to create session: #{error_message}")
          |> redirect(to: ~p"/channels/#{channel_id}")
      end
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Channel not found")
        |> redirect(to: ~p"/")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You don't have permission to create sessions in this channel")
        |> redirect(to: ~p"/channels/#{channel_id}")
    end
  end

  def join_form(conn, %{"id" => id}) do
    user_id = get_session(conn, :user_id)

    with {:ok, session} <- find_session(id),
         {:ok, _} <- check_join_permission(session, user_id) do
      render(conn, :join_form, session: session)
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You don't have permission to join this session")
        |> redirect(to: ~p"/")
    end
  end

  def join(conn, %{"id" => id}) do
    user_id = get_session(conn, :user_id)

    with {:ok, session} <- find_session(id),
         {:ok, _} <- check_join_permission(session, user_id) do

      case Sessions.join_session(session.id, user_id) do
        {:ok, _} ->
          if session.broadcast_type do
            # This is a broadcast - check if it's live
            if is_broadcast_live?(session) do
              redirect(conn, to: ~p"/channels/#{session.channel_id}/broadcasts/#{session.id}/live")
            else
              # Redirect to waiting room
              redirect(conn, to: ~p"/channels/#{session.channel_id}/broadcasts/#{session.id}/waiting")
            end
          else
            # Regular session
            redirect(conn, to: ~p"/channels/#{session.channel_id}/studio/#{session.id}")
          end

        {:error, reason} ->
          conn
          |> put_flash(:error, "Failed to join session: #{reason}")
          |> redirect(to: ~p"/channels/#{session.channel_id}")
      end
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You don't have permission to join this session")
        |> redirect(to: ~p"/")
    end
  end

  def leave(conn, %{"id" => id}) do
    user_id = get_session(conn, :user_id)

    with {:ok, session} <- find_session(id) do
      # Allow users to leave sessions they've joined
      Sessions.remove_participant(session.id, user_id)

      conn
      |> put_flash(:info, "You have left the session")
      |> redirect(to: ~p"/channels/#{session.channel_id}")
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/")
    end
  end

  def end_session(conn, %{"id" => id}) do
    user_id = Plug.Conn.get_session(conn, :user_id)

    with {:ok, session} <- find_session(id),
        {:ok, _} <- check_end_permission(session, user_id) do

      case Sessions.end_session(session) do
        {:ok, _} ->
          conn
          |> put_flash(:info, "Session ended successfully")
          |> redirect(to: ~p"/channels/#{session.channel_id}")

        {:error, _} ->
          conn
          |> put_flash(:error, "Failed to end session")
          |> redirect(to: ~p"/channels/#{session.channel_id}/sessions/#{id}")
      end
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/")

      {:error, :unauthorized} ->
        # Here we don't have access to `session`, so we need a different approach
        # Option 1: Try to find the session again
        session_info = case Sessions.get_session(id) do
          nil -> %{channel_id: ""}  # Default fallback
          s -> s
        end

        conn
        |> put_flash(:error, "You don't have permission to end this session")
        |> redirect(to: ~p"/channels/#{session_info.channel_id}/sessions/#{id}")
    end
  end

  def room(conn, %{"id" => id}) do
    user_id = get_session(conn, :user_id)

    with {:ok, session} <- find_session(id),
         {:ok, _} <- check_session_access(session, user_id) do

      # Check if user is a participant
      if Sessions.is_session_participant?(session.id, user_id) do
        # Render room template
        render(conn, :room, session: session)
      else
        # Redirect to join page
        redirect(conn, to: ~p"/sessions/#{id}/join")
      end
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You don't have access to this session")
        |> redirect(to: ~p"/")
    end
  end

  # Private helpers

  defp get_channel(channel_id) do
    case Channels.get_channel(channel_id) do
      nil -> {:error, :not_found}
      channel -> {:ok, channel}
    end
  end

  defp find_session(session_id) do
    case Sessions.get_session(session_id) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  defp check_channel_access(channel, user_id) do
    if Channels.user_has_access?(channel.id, user_id) do
      {:ok, :authorized}
    else
      {:error, :unauthorized}
    end
  end

  defp check_session_access(session, user_id) do
    # Public sessions are accessible to all channel members
    if session.is_public do
      # Check channel access
      check_channel_access(%{id: session.channel_id}, user_id)
    else
      # Private session - check if user is a participant
      if Sessions.is_session_participant?(session.id, user_id) do
        {:ok, :authorized}
      else
        {:error, :unauthorized}
      end
    end
  end

  defp check_session_creation_permission(channel, user_id) do
    # Check if user has permission to create sessions in this channel
    user_role = Channels.get_user_role_in_channel(channel.id, user_id)

    if user_role in ["owner", "moderator", "member"] do
      {:ok, :authorized}
    else
      {:error, :unauthorized}
    end
  end

  defp check_join_permission(session, user_id) do
    # Check if user can join this session
    cond do
      # Session creators/hosts can always join
      session.creator_id == user_id || session.host_id == user_id ->
        {:ok, :authorized}

      # Public sessions - check channel access
      session.is_public ->
        check_channel_access(%{id: session.channel_id}, user_id)

      # Private sessions - check if invited
      Sessions.is_user_invited?(session.id, user_id) ->
        {:ok, :authorized}

      true ->
        {:error, :unauthorized}
    end
  end

  defp check_end_permission(session, user_id) do
    # Check if user has permission to end this session
    cond do
      # Session creators/hosts can end
      session.creator_id == user_id || session.host_id == user_id ->
        {:ok, :authorized}

      # Channel owners/moderators can end
      Channels.is_channel_moderator?(session.channel_id, user_id) ->
        {:ok, :authorized}

      true ->
        {:error, :unauthorized}
    end
  end

  defp is_broadcast_live?(session) do
    # Check if a broadcast is currently live
    now = DateTime.utc_now()

    cond do
      session.status != "scheduled" ->
        false

      is_nil(session.scheduled_for) ->
        false

      true ->
        # Broadcast is live if current time is after scheduled time
        # but before end time (or if no end time, within 6 hours of scheduled time)
        is_after_start = DateTime.compare(now, session.scheduled_for) in [:eq, :gt]

        is_before_end = if session.ended_at do
          DateTime.compare(now, session.ended_at) == :lt
        else
          # Default broadcast length: 6 hours
          six_hours_later = DateTime.add(session.scheduled_for, 6 * 60 * 60, :second)
          DateTime.compare(now, six_hours_later) == :lt
        end

        is_after_start && is_before_end
    end
  end
end
