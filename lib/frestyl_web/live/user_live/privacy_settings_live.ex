# lib/frestyl_web/live/user_live/privacy_settings_live.ex
defmodule FrestylWeb.UserLive.PrivacySettingsLive do
  use FrestylWeb, :live_view
  alias Frestyl.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Default privacy settings if none exist
    privacy_settings = user.privacy_settings || %{
      "profile_visibility" => "public",
      "media_visibility" => "public",
      "metrics_visibility" => "private"
    }

    {:ok, assign(socket, privacy_settings: privacy_settings)}
  end

  def handle_event("update_privacy", %{"privacy" => params}, socket) do
    user = socket.assigns.current_user
    privacy_settings = socket.assigns.privacy_settings

    # Update privacy settings with new values
    updated_settings = %{
      "profile_visibility" => params["profile_visibility"] || privacy_settings["profile_visibility"],
      "media_visibility" => params["media_visibility"] || privacy_settings["media_visibility"],
      "metrics_visibility" => params["metrics_visibility"] || privacy_settings["metrics_visibility"]
    }

    case Accounts.update_privacy_settings(user, updated_settings) do
      {:ok, updated_user} ->
        socket =
          socket
          |> assign(:current_user, updated_user)
          |> assign(:privacy_settings, updated_user.privacy_settings)
          |> put_flash(:info, "Privacy settings updated successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to update privacy settings")

        {:noreply, socket}
    end
  end
end
