# lib/frestyl_web/live/user_live/profile.ex
defmodule FrestylWeb.UserLive.Profile do
  use FrestylWeb, :live_view

  alias Frestyl.Accounts

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = Accounts.get_user_by_session_token(user_token)

    # Track user presence
    if connected?(socket) do
      FrestylWeb.Presence.track_user(
        self(),
        "users:presence",
        user.id
      )

      Phoenix.PubSub.subscribe(Frestyl.PubSub, "users:presence")
    end

    socket =
      socket
      |> assign(:page_title, "My Profile")
      |> assign(:user, user)
      |> assign(:online_users, FrestylWeb.Presence.list_users_online("users:presence"))
      |> assign(:changeset, Accounts.change_user_profile(user))

    {:ok, socket}
  end

  @impl true
  def handle_event("save_profile", %{"user" => user_params}, socket) do
    case Accounts.update_profile(socket.assigns.user, user_params) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:user, user)
          |> assign(:changeset, Accounts.change_user_profile(user))
          |> put_flash(:info, "Profile updated successfully")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # Update list of online users when presence changes
    online_users = FrestylWeb.Presence.list_users_online("users:presence")
    {:noreply, assign(socket, :online_users, online_users)}
  end
end
