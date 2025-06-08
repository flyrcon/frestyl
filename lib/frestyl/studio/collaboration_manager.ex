# lib/frestyl/studio/collaboration_manager.ex
defmodule Frestyl.Studio.CollaborationManager do
  @moduledoc """
  Manages real-time collaboration features including presence, subscriptions, and notifications.
  """

  require Logger
  alias Frestyl.{Presence, Sessions}
  alias Phoenix.PubSub

  @doc """
  Setup real-time subscriptions for a user session.
  """
  def setup_subscriptions(session_id, user_id) do
    # Subscribe to various collaboration channels
    PubSub.subscribe(Frestyl.PubSub, "studio:#{session_id}")
    PubSub.subscribe(Frestyl.PubSub, "studio:#{session_id}:operations")
    PubSub.subscribe(Frestyl.PubSub, "user:#{user_id}")
    PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}:chat")
    PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")
    PubSub.subscribe(Frestyl.PubSub, "beat_machine:#{session_id}")
    PubSub.subscribe(Frestyl.PubSub, "mobile_audio:#{session_id}")
    PubSub.subscribe(Frestyl.PubSub, "audio_text_sync:#{session_id}")
  end

  @doc """
  Track user presence with collaboration metadata.
  """
  def track_presence(session_id, current_user, device_info) do
    presence_data = %{
      user_id: current_user.id,
      username: current_user.username,
      avatar_url: current_user.avatar_url,
      joined_at: DateTime.utc_now(),
      active_tool: "audio",
      is_typing: false,
      last_activity: DateTime.utc_now(),
      ot_version: 0,
      is_recording: false,
      input_level: 0,
      active_audio_track: nil,
      audio_monitoring: false,
      is_mobile: device_info.is_mobile,
      device_type: device_info.device_type,
      screen_size: device_info.screen_size,
      supports_audio: device_info.supports_audio,
      battery_optimized: false,
      current_mobile_track: 0
    }

    {:ok, _} = Presence.track(self(), "studio:#{session_id}", current_user.id, presence_data)
  end

  @doc """
  Update user presence with new metadata.
  """
  def update_presence(session_id, user_id, updates) do
    case Presence.get_by_key("studio:#{session_id}", to_string(user_id)) do
      %{metas: [meta | _]} ->
        new_meta = Map.merge(meta, updates)
        Presence.update(self(), "studio:#{session_id}", to_string(user_id), new_meta)
      _ ->
        Logger.warn("Could not update presence for user #{user_id} in session #{session_id}")
        nil
    end
  end

  @doc """
  Update typing status for a user.
  """
  def update_typing_status(session_id, user_id, is_typing) do
    update_presence(session_id, user_id, %{
      is_typing: is_typing,
      last_activity: DateTime.utc_now()
    })

    # Also broadcast typing status
    PubSub.broadcast(
      Frestyl.PubSub,
      "session:#{session_id}:chat",
      {:user_typing, user_id, is_typing}
    )
  end

  @doc """
  List all collaborators in a session.
  """
  def list_collaborators(session_id) do
    presence_list = Presence.list("studio:#{session_id}")

    Enum.flat_map(presence_list, fn {user_id, %{metas: metas}} ->
      meta = List.first(metas)
      if meta do
        [Map.put_new(meta, :user_id, user_id)]
      else
        []
      end
    end)
  end

  @doc """
  Process presence diff and generate notifications.
  """
  def process_presence_diff(diff_message, current_user_id) do
    %Phoenix.Socket.Broadcast{payload: diff} = diff_message

    join_notifications = Enum.reduce(Map.get(diff, :joins, %{}), [], fn {user_id, user_data}, acc ->
      if user_id != to_string(current_user_id) do
        meta_data = List.first(user_data.metas)
        notification = %{
          id: System.unique_integer([:positive]),
          type: :user_joined,
          message: "#{meta_data.username} joined the session",
          timestamp: DateTime.utc_now()
        }
        [notification | acc]
      else
        acc
      end
    end)

    leave_notifications = Enum.reduce(Map.get(diff, :leaves, %{}), [], fn {user_id, user_data}, acc ->
      if user_id != to_string(current_user_id) do
        meta_data = List.first(user_data.metas)
        notification = %{
          id: System.unique_integer([:positive]),
          type: :user_left,
          message: "#{meta_data.username} left the session",
          timestamp: DateTime.utc_now()
        }
        [notification | acc]
      else
        acc
      end
    end)

    join_notifications ++ leave_notifications
  end

  @doc """
  Broadcast a collaboration event to all session participants.
  """
  def broadcast_collaboration_event(session_id, event_type, data, sender_id \\ nil) do
    event_data = %{
      type: event_type,
      data: data,
      sender_id: sender_id,
      timestamp: DateTime.utc_now()
    }

    PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{session_id}",
      {:collaboration_event, event_data}
    )
  end

  @doc """
  Send a notification to a specific user.
  """
  def send_user_notification(user_id, notification) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "user:#{user_id}",
      {:notification, notification}
    )
  end

  @doc """
  Get collaboration statistics for a session.
  """
  def get_collaboration_stats(session_id) do
    collaborators = list_collaborators(session_id)

    %{
      total_collaborators: length(collaborators),
      active_collaborators: Enum.count(collaborators, &is_recently_active?/1),
      recording_users: Enum.count(collaborators, & &1.is_recording),
      mobile_users: Enum.count(collaborators, & &1.is_mobile),
      typing_users: Enum.count(collaborators, & &1.is_typing)
    }
  end

  @doc """
  Check if a user has necessary permissions for an operation.
  """
  def check_permission(session_id, user_id, operation) do
    session = Sessions.get_session(session_id)

    cond do
      session.creator_id == user_id -> true
      session.host_id == user_id -> true
      operation in [:view, :chat, :record] -> true
      operation in [:edit_audio, :edit_text] -> true  # Allow for collaborative sessions
      true -> false
    end
  end

  @doc """
  Initialize operational transform state for a session.
  """
  def initialize_ot_state(session_id) do
    # Initialize OT tracking for the session
    PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{session_id}:operations",
      {:ot_initialized, session_id}
    )
  end

  @doc """
  Broadcast an operation to all collaborators.
  """
  def broadcast_operation(session_id, operation) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{session_id}:operations",
      {:new_operation, operation}
    )
  end

  @doc """
  Acknowledge an operation completion.
  """
  def acknowledge_operation(session_id, operation_timestamp, user_id) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{session_id}:operations",
      {:operation_acknowledged, operation_timestamp, user_id}
    )
  end

  @doc """
  Handle session cleanup when a user disconnects.
  """
  def handle_user_disconnect(session_id, user_id) do
    # Clean up any ongoing operations by this user
    broadcast_collaboration_event(session_id, :user_disconnected, %{user_id: user_id})

    # Stop any recordings by this user
    case Frestyl.Studio.AudioEngine.stop_user_recordings(session_id, user_id) do
      :ok -> :ok
      {:error, reason} -> Logger.warn("Failed to stop recordings for user #{user_id}: #{reason}")
    end
  end

  @doc """
  Handle session cleanup when session ends.
  """
  def cleanup_session(session_id) do
    # Stop all engines
    try do
      Frestyl.Studio.AudioEngine.stop_engine(session_id)
      Frestyl.Studio.BeatMachine.stop_engine(session_id)
    rescue
      error -> Logger.warn("Error cleaning up session engines: #{inspect(error)}")
    end

    # Clear presence
    presence_list = Presence.list("studio:#{session_id}")
    Enum.each(presence_list, fn {user_id, _} ->
      Presence.untrack(self(), "studio:#{session_id}", user_id)
    end)

    # Broadcast session cleanup
    PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{session_id}",
      {:session_cleanup, session_id}
    )
  end

  # Private Functions

  defp is_recently_active?(collaborator) do
    case collaborator.last_activity do
      nil -> false
      last_activity ->
        DateTime.diff(DateTime.utc_now(), last_activity, :second) < 300  # 5 minutes
    end
  end
end
