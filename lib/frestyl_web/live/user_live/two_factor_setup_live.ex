# lib/frestyl_web/live/user_live/two_factor_setup_live.ex
defmodule FrestylWeb.UserLive.TwoFactorSetupLive do
  use FrestylWeb, :live_view
  alias Frestyl.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user.totp_enabled do
      # User already has 2FA enabled
      {:ok, redirect(socket, to: Routes.user_live_profile_path(socket, :show))}
    else
      # Generate a new secret for user
      secret = Accounts.generate_totp_secret()
      uri = Accounts.generate_totp_uri(user, secret)
      qr_code = Accounts.generate_totp_qr_code(uri)

      socket =
        socket
        |> assign(:secret, secret)
        |> assign(:uri, uri)
        |> assign(:qr_code, qr_code)
        |> assign(:verify_changeset, %{})
        |> assign(:secret_base32, Base.encode32(secret))

      {:ok, socket}
    end
  end

  def handle_event("verify", %{"totp_code" => code}, socket) do
    user = socket.assigns.current_user
    secret = socket.assigns.secret

    case Accounts.enable_two_factor(user, code, secret) do
      {:ok, updated_user, backup_codes} ->
        socket =
          socket
          |> assign(:current_user, updated_user)
          |> assign(:backup_codes, backup_codes)
          |> assign(:step, :backup_codes)

        {:noreply, socket}

      {:error, :invalid_code} ->
        socket =
          socket
          |> put_flash(:error, "Invalid verification code. Please try again.")
          |> assign(:verify_changeset, %{errors: [totp_code: {"Invalid verification code", []}]})

        {:noreply, socket}
    end
  end

  def handle_event("complete_setup", _params, socket) do
    {:noreply, redirect(socket, to: Routes.user_live_profile_path(socket, :show))}
  end
end
