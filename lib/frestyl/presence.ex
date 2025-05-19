defmodule Frestyl.Presence do
  use Phoenix.Presence,
    otp_app: :frestyl,
    pubsub_server: Frestyl.PubSub

  alias Frestyl.Accounts

  @doc """
  Tracks a user joining a topic with custom metadata.
  """
  def track_user(pid, topic, user_id, meta \\ %{}) do
    user = Accounts.get_user!(user_id)
    # Update last_active timestamp if the function exists
    if function_exported?(Accounts, :track_user_activity, 1) do
      Accounts.track_user_activity(user)
    end

    # Add default user data to meta
    default_meta = %{
      name: user.name || user.email,
      online_at: System.system_time(:second)
    }

    # Track with combined metadata
    track(pid, topic, to_string(user_id), Map.merge(default_meta, meta))
  end

  @doc """
  Lists all online users in a topic.
  """
  def list_users(topic) do
    list(topic)
    |> Enum.map(fn {user_id, %{metas: _}} -> user_id end)
  end

  @doc """
  Lists all users who are currently typing in a topic.
  """
  def list_typing_users(topic) do
    list(topic)
    |> Enum.filter(fn {_user_id, %{metas: metas}} ->
      Enum.any?(metas, fn meta -> Map.get(meta, :typing) == true end)
    end)
    |> Enum.map(fn {user_id, _presence} ->
      case Integer.parse(user_id) do
        {id, _} -> id
        :error -> user_id
      end
    end)
  end
end
