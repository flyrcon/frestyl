# lib/frestyl_web/live/user_live/two_factor_verify_live.ex
defmodule FrestylWeb.UserLive.TwoFactorVerifyLive do
  use FrestylWeb, :live_view
  alias Frestyl.Accounts
  alias Frestyl.Accounts.User

  def mount(_params, session, socket) do
    email = session["email"] || ""
    user_id = session["user_id"]

    # Default changeset
    changeset = User.totp_verification_changeset(%User{}, %{})

    socket =
      socket
      |> assign(:email, email)
      |> assign(:user_id, user_id)
      |> assign(:changeset, changeset)
      |> assign(:show_backup_code_form, false)

    {:ok, socket}
  end

  def handle_event("verify", %{"totp_code" => code}, socket) do
    user_id = socket.assigns.user_id
    user = Accounts.get_user!(user_id)

    if Accounts.verify_totp(user.totp_secret, code) do
      # Create a session token for the user
      token = Accounts.generate_user_session_token(user)

      # In LiveView, we need to redirect to a controller action
      # that will set up the session properly
      socket =
        socket
        |> put_flash(:info, "Two-factor verification successful!")
        |> push_redirect(to: Routes.user_session_path(socket, :create_from_2fa, %{token: token}))

      {:noreply, socket}
    else
      changeset =
        %User{}
        |> User.totp_verification_changeset(%{totp_code: code})
        |> Map.put(:errors, [totp_code: {"Invalid verification code", []}])
        |> Map.put(:valid?, false)

      socket =
        socket
        |> put_flash(:error, "Invalid verification code")
        |> assign(:changeset, changeset)

      {:noreply, socket}
    end
  end

  def handle_event("use_backup_code", _params, socket) do
    {:noreply, assign(socket, :show_backup_code_form, true)}
  end

  def handle_event("cancel_backup", _params, socket) do
    {:noreply, assign(socket, :show_backup_code_form, false)}
  end

  def handle_event("verify_backup", %{"backup_code" => backup_code}, socket) do
    user_id = socket.assigns.user_id
    user = Accounts.get_user!(user_id)

    case Accounts.verify_backup_code(user, backup_code) do
      {:ok, updated_user} ->
        # Create a session token for the user
        token = Accounts.generate_user_session_token(updated_user)

        # In LiveView, we need to redirect to a controller action
        # that will set up the session properly
        socket =
          socket
          |> put_flash(:info, "Backup code accepted. Please set up 2FA again for additional security.")
          |> push_redirect(to: Routes.user_session_path(socket, :create_from_2fa, %{token: token}))

        {:noreply, socket}

      {:error, _} ->
        socket =
          socket
          |> put_flash(:error, "Invalid backup code")

        {:noreply, socket}
    end
  end
end
