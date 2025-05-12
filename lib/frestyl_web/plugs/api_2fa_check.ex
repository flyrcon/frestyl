# lib/frestyl_web/plugs/api_2fa_check.ex
defmodule FrestylWeb.Plugs.API2FACheck do
  @moduledoc """
  Plug to verify two-factor authentication for API endpoints.
  Ensures that users with 2FA enabled have completed verification.
  Returns 401 Unauthorized if verification is required but not completed.
  """

  import Plug.Conn
  import Phoenix.Controller
  alias Frestyl.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    # First check if user is authenticated at all
    with %{assigns: %{current_user: %Frestyl.Accounts.User{} = user}} <- conn,
         # Then check if user has 2FA enabled
         true <- user.totp_enabled do

      # Check if 2FA has been verified for this session
      case conn.private[:plug_session][:totp_verified] do
        true ->
          # 2FA is verified, proceed with request
          conn
        _ ->
          # 2FA verification required
          conn
          |> put_status(:unauthorized)
          |> json(%{
            error: "two_factor_auth_required",
            message: "Two-factor authentication required",
            verification_url: "/api/auth/verify_2fa"
          })
          |> halt()
      end
    else
      # User doesn't have 2FA enabled or isn't authenticated
      # Let other authentication plugs handle this case
      _ -> conn
    end
  end
end
