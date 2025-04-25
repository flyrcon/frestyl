defmodule FrestylWeb.SessionChannel do
  use Phoenix.Channel
  alias Frestyl.Sessions
  alias Frestyl.Accounts
  alias FrestylWeb.Presence

  @doc """
  Joins a session channel. Requires authorization to the session.
  """
  def join("session:" <> session_id, _params, socket) do
    user_id = socket.assigns.user_id

    case authorize_session(user_id, String.to_integer(session_id)) do
      {:ok, session} ->
        send(self(), :after_join)
        {:ok, %{session: session}, assign(socket, :session_id, session_id)}
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  @doc """
  After joining, track presence for the user
  """
  def handle_info(:after_join, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
      online_at: inspect(System.system_time(:second)),
      user_id: user.id,
      username: user.username
    })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @doc """
  Handles chat messages in the session
  """
  def handle_in("new_message", %{"content" => content}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    message = %{
      user_id: user.id,
      username: user.username,
      content: content,
      timestamp: :os.system_time(:millisecond)
    }

    broadcast!(socket, "new_message", message)
    {:reply, :ok, socket}
  end

  @doc """
  Handles WebRTC signaling for media streaming
  """
  def handle_in("signal", %{"to" => to_user_id, "signal_data" => signal_data}, socket) do
    user_id = socket.assigns.user_id

    # Forward the signal to the intended recipient
    push(socket, "signal", %{
      from: user_id,
      signal_data: signal_data
    })

    {:noreply, socket}
  end

  @doc """
  Handles media item sharing in the session
  """
  def handle_in("share_media", media_data, socket) do
    # Handle media sharing logic here
    broadcast!(socket, "media_shared", Map.put(media_data, "shared_by", socket.assigns.user_id))
    {:reply, :ok, socket}
  end

  # Private functions

  defp authorize_session(user_id, session_id) do
    session = Sessions.get_session_with_details!(session_id)

    cond do
      session.creator_id == user_id ->
        {:ok, sanitize_session(session)}
      Enum.any?(session.participants, fn p -> p.id == user_id end) ->
        {:ok, sanitize_session(session)}
      true ->
        {:error, "unauthorized"}
    end
  rescue
    Ecto.NoResultsError -> {:error, "session not found"}
  end

  defp sanitize_session(session) do
    # Return relevant session data that should be sent to clients
    %{
      id: session.id,
      title: session.title,
      description: session.description,
      start_time: session.start_time,
      end_time: session.end_time,
      session_type: session.session_type,
      status: session.status,
      creator_id: session.creator_id
    }
  end
end
