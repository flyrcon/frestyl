# lib/frestyl_web/channels/session_channel.ex
defmodule FrestylWeb.SessionChannel do
  use Phoenix.Channel
  alias Frestyl.Sessions
  alias Frestyl.Accounts
  alias Frestyl.Media
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

    # Track user presence
    {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
      online_at: inspect(System.system_time(:second)),
      user_id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      active_tool: "audio",
      is_typing: false,
      last_activity: DateTime.utc_now()
    })

    # Push current presence state to the newly joined user
    push(socket, "presence_state", Presence.list(socket))

    # Fetch session workspace state and push to client
    session_id = socket.assigns.session_id
    case Sessions.get_workspace_state(session_id) do
      nil -> :ok
      workspace_state -> push(socket, "workspace_state", workspace_state)
    end

    # Fetch recent messages and push to client
    messages = Sessions.list_recent_messages(session_id, 50)
    push(socket, "recent_messages", %{messages: messages})

    {:noreply, socket}
  end

  @doc """
  Handles chat messages in the session
  """
  def handle_in("new_message", %{"content" => content}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)
    session_id = socket.assigns.session_id

    message_params = %{
      content: content,
      user_id: user.id,
      session_id: session_id
    }

    case Sessions.create_message(message_params) do
      {:ok, message} ->
        # Format the message for broadcast
        message_data = %{
          id: message.id,
          content: message.content,
          user_id: message.user_id,
          username: user.username,
          avatar_url: user.avatar_url,
          inserted_at: message.inserted_at
        }

        broadcast!(socket, "new_message", message_data)
        {:reply, :ok, socket}

      {:error, _changeset} ->
        {:reply, {:error, %{reason: "Failed to save message"}}, socket}
    end
  end

  @doc """
  Handles workspace state updates
  """
  def handle_in("workspace_update", update_data, socket) do
    # Broadcast the update to all users in the session
    broadcast!(socket, "workspace_updated", update_data)

    # Persist workspace state if this is a state-changing update
    if update_data["persist"] do
      session_id = socket.assigns.session_id

      # Get the current workspace state or initialize if not present
      current_state = Sessions.get_workspace_state(session_id) || %{}

      # Update the state based on the type of update
      new_state = case update_data["type"] do
        "audio" ->
          audio_state = Map.get(current_state, "audio", %{})
          Map.put(current_state, "audio", Map.merge(audio_state, update_data["state"]))

        "midi" ->
          midi_state = Map.get(current_state, "midi", %{})
          Map.put(current_state, "midi", Map.merge(midi_state, update_data["state"]))

        "text" ->
          text_state = Map.get(current_state, "text", %{})
          Map.put(current_state, "text", Map.merge(text_state, update_data["state"]))

        "visual" ->
          visual_state = Map.get(current_state, "visual", %{})
          Map.put(current_state, "visual", Map.merge(visual_state, update_data["state"]))

        _ -> current_state
      end

      # Save the updated state
      Sessions.save_workspace_state(session_id, new_state)
    end

    {:reply, :ok, socket}
  end

  @doc """
  Handles WebRTC signaling for media streaming
  """
  def handle_in("signal", %{"to" => to_user_id, "signal_data" => signal_data}, socket) do
    # Forward the signal to the intended recipient
    broadcast!(socket, "signal", %{
      from: socket.assigns.user_id,
      to: to_user_id,
      signal_data: signal_data
    })

    {:noreply, socket}
  end

  @doc """
  Handles media item sharing in the session
  """
  def handle_in("share_media", media_data, socket) do
    user_id = socket.assigns.user_id
    session_id = socket.assigns.session_id

    # Store the media item
    case Media.create_media_item(%{
      session_id: session_id,
      user_id: user_id,
      data: media_data["data"],
      name: media_data["name"],
      content_type: media_data["content_type"],
      size: media_data["size"]
    }) do
      {:ok, media_item} ->
        # Broadcast the shared media to all participants
        broadcast_data = %{
          id: media_item.id,
          name: media_item.name,
          content_type: media_item.content_type,
          size: media_item.size,
          url: media_item.url,
          shared_by: user_id,
          timestamp: media_item.inserted_at
        }

        broadcast!(socket, "media_shared", broadcast_data)
        {:reply, :ok, socket}

      {:error, _changeset} ->
        {:reply, {:error, %{reason: "Failed to save media item"}}, socket}
    end
  end

  @doc """
  Handles user activity updates (e.g., typing status, active tool)
  """
  def handle_in("update_presence", presence_data, socket) do
    user_id = socket.assigns.user_id

    # Get current presence data
    current_data = Presence.get_by_key(socket, user_id)
      |> case do
        nil -> %{}
        %{metas: [data | _]} -> data
      end

    # Update with new data
    new_data = Map.merge(current_data, presence_data)

    # Track updated presence
    {:ok, _} = Presence.update(socket, user_id, new_data)

    {:reply, :ok, socket}
  end

  # Private functions

  defp authorize_session(user_id, session_id) do
    session = Sessions.get_session(session_id)

    cond do
      is_nil(session) ->
        {:error, "session not found"}

      # Session creators/hosts can always join
      session.creator_id == user_id || session.host_id == user_id ->
        {:ok, sanitize_session(session)}

      # Public sessions - check channel access
      session.is_public && Frestyl.Channels.user_has_access?(session.channel_id, user_id) ->
        {:ok, sanitize_session(session)}

      # Private sessions - check if user is a participant
      Sessions.is_session_participant?(session_id, user_id) ->
        {:ok, sanitize_session(session)}

      # Otherwise not authorized
      true ->
        {:error, "unauthorized"}
    end
  end

  defp sanitize_session(session) do
    # Return relevant session data that should be sent to clients
    %{
      id: session.id,
      title: session.title,
      description: session.description,
      session_type: session.session_type,
      status: session.status,
      channel_id: session.channel_id,
      creator_id: session.creator_id,
      host_id: session.host_id,
      is_public: session.is_public,
      scheduled_for: session.scheduled_for,
      broadcast_type: session.broadcast_type
    }
  end
end
