# test/frestyl_web/controllers/account_security_test.exs
defmodule FrestylWeb.AccountSecurityTest do
  # Instead of ConnCase, use your project's test case module
  # This could be something like:
  use FrestylWeb.ConnCase, async: true
  # OR:
  # use FrestylWeb.FeatureCase, async: true
  # OR:
  # import Frestyl.TestHelpers

  import Phoenix.ConnTest
  alias FrestylWeb.Router.Helpers, as: Routes
  import Frestyl.AccountsFixtures
  alias Frestyl.Accounts

  # You might need to add the following if your test setup requires it:
  @endpoint FrestylWeb.Endpoint

  # Setup function to create a user for testing
  setup %{conn: conn} do
    user = user_fixture()
    %{conn: conn, user: user}
  end

  describe "two factor authentication" do
    test "enables 2FA for a user", %{conn: conn, user: user} do
      # Log in as the user
      conn = log_in_user(conn, user)

      # Generate a TOTP secret
      secret = Accounts.generate_totp_secret()

      # Enable 2FA (simplified for test)
      {:ok, user_with_2fa, _backup_codes} = Accounts.enable_two_factor(
        user,
        NimbleTOTP.verification_code(secret),
        secret
      )

      assert user_with_2fa.totp_enabled
      assert user_with_2fa.totp_secret
      assert user_with_2fa.backup_codes
    end

    test "requires 2FA during login when enabled", %{conn: conn, user: user} do
      # Enable 2FA for the user
      secret = Accounts.generate_totp_secret()
      {:ok, user_with_2fa, _} = Accounts.enable_two_factor(
        user,
        NimbleTOTP.verification_code(secret),
        secret
      )

      # Attempt to log in
      conn = post(conn, Routes.user_session_path(conn, :create), %{
        "user" => %{"email" => user.email, "password" => valid_user_password()}
      })

      # Should redirect to 2FA verification
      assert redirected_to(conn) == Routes.user_live_two_factor_verify_path(conn, :index)
      assert get_session(conn, :pending_2fa)
    end
  end

  describe "session management" do
    test "lists active sessions", %{conn: conn, user: user} do
      # Log in as the user
      conn = log_in_user(conn, user)

      # Create additional session
      token = Accounts.generate_user_session_token(user)

      # Get sessions
      sessions = Accounts.list_user_sessions(user.id)

      # Should have at least one session
      assert length(sessions) >= 1
    end

    test "revokes a session", %{conn: conn, user: user} do
      # Log in as the user
      conn = log_in_user(conn, user)

      # Create additional session
      token = Accounts.generate_user_session_token(user)

      # Get sessions
      sessions = Accounts.list_user_sessions(user.id)
      session_to_revoke = List.first(sessions)

      # Revoke session
      assert {1, _} = Accounts.revoke_session(session_to_revoke.id, user.id)

      # Get sessions again
      new_sessions = Accounts.list_user_sessions(user.id)

      # Should have one less session
      assert length(new_sessions) == length(sessions) - 1
    end
  end

  # Helper function to log in a user for tests
  # This function should match your app's auth implementation
  defp log_in_user(conn, user) do
    token = Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  # Helper function to get a valid user password for tests
  # This should match how your fixtures are defined
  defp valid_user_password do
    "password123" # Or whatever password your fixtures use
  end
end
