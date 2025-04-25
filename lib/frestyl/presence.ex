# lib/frestyl/presence.ex

defmodule Frestyl.Presence do
  @moduledoc """
  Provides presence tracking for channels and processes.

  Optimized for real-time user status tracking with automatic
  conflict resolution and distributed state recovery.
  """

  use Phoenix.Presence,
    otp_app: :frestyl,
    pubsub_server: Frestyl.PubSub

  alias Frestyl.Accounts.User
  alias Frestyl.Repo
  import Ecto.Query, only: [from: 2]

  def fetch(_topic, presences) do
    users = presences
    |> Map.keys()
    |> get_users_map()

    for {key, %{metas: metas}} <- presences, into: %{} do
      {key, %{metas: metas, user: users[key]}}
    end
  end

  defp get_users_map(ids) do
    query = from u in User, where: u.id in ^ids

    Repo.all(query)
    |> Enum.reduce(%{}, fn user, acc ->
      Map.put(acc, to_string(user.id), %{
        id: user.id,
        username: user.username,
        profile_image: user.profile_image
      })
    end)
  end

  @doc """
  Returns a list of online users in a given topic.
  """
  def list_users(topic) do
    list(topic)
    |> Enum.map(fn {_user_id, %{user: user}} -> user end)
  end

  @doc """
  Returns a map of user_id => presence information.
  """
  def user_count(topic) do
    list(topic)
    |> map_size()
  end
end
