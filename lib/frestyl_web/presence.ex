# lib/frestyl_web/presence.ex
defmodule FrestylWeb.Presence do
  use Phoenix.Presence,
    otp_app: :frestyl,
    pubsub_server: Frestyl.PubSub

  alias Frestyl.Accounts

  def track_user(pid, topic, user_id, meta \\ %{}) do
    user = Accounts.get_user!(user_id)
    # Update last_active timestamp
    Accounts.track_user_activity(user)

    # Add default user data to meta
    default_meta = %{
      name: user.full_name || user.email,
      role: user.role,
      tier: user.subscription_tier,
      online_at: System.system_time(:second)
    }

    # Track with combined metadata
    track(pid, topic, user_id, Map.merge(default_meta, meta))
  end

  def list_users_online(topic) do
    list(topic)
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      %{
        id: user_id,
        name: meta.name,
        role: meta.role,
        online_at: meta.online_at
      }
    end)
  end
end
