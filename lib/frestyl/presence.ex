# lib/frestyl/presence.ex
defmodule Frestyl.Presence do
  use Phoenix.Presence,
    otp_app: :frestyl,
    pubsub_server: Frestyl.PubSub

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
      Enum.any?(metas, fn meta -> meta[:typing] end)
    end)
    |> Enum.map(fn {user_id, _presence} -> String.to_integer(user_id) end)
  end
end
