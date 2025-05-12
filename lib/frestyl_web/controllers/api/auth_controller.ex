# lib/frestyl_web/controllers/api/auth_controller.ex
defmodule FrestylWeb.Api.AuthController do
  use FrestylWeb, :controller

  alias Frestyl.Accounts

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        token = Accounts.generate_user_session_token(user)

        # Check if 2FA is enabled
        if user.totp_enabled do
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            user_id: user.id,
            token: token,
            two_factor_required: true,
            message: "Two-factor authentication required"
          })
        else
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            user_id: user.id,
            token: token,
            two_factor_required: false,
            message: "Login successful"
          })
        end

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: "invalid_credentials",
          message: "Invalid email or password"
        })
    end
  end

  def register(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          user_id: user.id,
          message: "Registration successful"
        })

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "invalid_registration",
          errors: errors
        })
    end
  end

  def verify_2fa(conn, %{"totp_code" => totp_code}) do
    user = conn.assigns.current_user

    if user && user.totp_enabled do
      if Accounts.verify_totp(user.totp_secret, totp_code) do
        # Mark session as 2FA verified
        conn
        |> put_session(:totp_verified, true)
        |> json(%{success: true, message: "Two-factor authentication verified"})
      else
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_code", message: "Invalid verification code"})
      end
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "2fa_not_enabled", message: "Two-factor authentication not enabled for this user"})
    end
  end

  def verify_backup_code(conn, %{"backup_code" => backup_code}) do
    user = conn.assigns.current_user

    if user && user.totp_enabled do
      case Accounts.verify_backup_code(user, backup_code) do
        {:ok, _updated_user} ->
          # Mark session as 2FA verified
          conn
          |> put_session(:totp_verified, true)
          |> json(%{success: true, message: "Backup code accepted"})

        {:error, _reason} ->
          conn
          |> put_status(:unauthorized)
          |> json(%{error: "invalid_code", message: "Invalid backup code"})
      end
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "2fa_not_enabled", message: "Two-factor authentication not enabled for this user"})
    end
  end

  def status(conn, _params) do
    user = conn.assigns.current_user

    if user do
      totp_verified = get_session(conn, :totp_verified) || false

      conn
      |> json(%{
        authenticated: true,
        user_id: user.id,
        email: user.email,
        totp_enabled: user.totp_enabled || false,
        totp_verified: totp_verified
      })
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{authenticated: false})
    end
  end

  def logout(conn, _params) do
    if conn.assigns[:current_user] do
      token = get_session(conn, :user_token)

      if token do
        Accounts.delete_session_token(token)
      end

      conn
      |> clear_session()
      |> json(%{success: true, message: "Logged out successfully"})
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "not_authenticated", message: "Not authenticated"})
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
