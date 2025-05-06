defmodule FrestylWeb.UserSessionController do
  use FrestylWeb, :controller

  alias Frestyl.Accounts
  alias FrestylWeb.UserAuth
  alias Frestyl.Repo
  require Logger

  @session_key :user_token

  def register_success(conn, %{"user_id" => user_id}) do
    Logger.info("UserSessionController.register_success: User ID #{user_id}")
    user = Accounts.get_user!(user_id)
    # Call log_in_user to set session/cookie, then redirect explicitly
    conn
    |> FrestylWeb.UserAuth.log_in_user(user)
    |> put_flash(:info, "Account created successfully!") # Add flash message here
    |> redirect(to: "/dashboard")
  end

  # Handle login with user credentials
  def create(conn, %{"user" => user_params} = params) do
    %{"email" => email, "password" => password} = user_params
    Logger.info("UserSessionController.create (credentials): Attempting login for email: #{email}")

    action = Map.get(params, "_action")
    info = case action do
      "registered" -> "Account created successfully!" # This case might not be hit if register_success is used
      "password_updated" -> "Password updated successfully!"
      _ -> "Welcome back!"
    end
    Logger.info("UserSessionController.create (credentials): Determined flash info: #{info}")


    case Accounts.get_user_by_email_and_password(email, password) do
      {:ok, user} ->
        Logger.info("UserSessionController.create (credentials): Authentication successful for user #{user.email}")
        conn = conn
        |> UserAuth.log_in_user(user, user_params) # Set session/cookie
        Logger.info("UserSessionController.create (credentials): UserAuth.log_in_user called. Conn assigns: #{inspect conn.assigns[:current_user] && conn.assigns[:current_user].email}")
        Logger.info("UserSessionController.create (credentials): Conn session after log_in_user: #{inspect get_session(conn, @session_key)}")


        # Handle redirect based on action or default to dashboard
        if action == "password_updated" do
          Logger.info("UserSessionController.create (credentials): Redirecting to /users/settings (password_updated action)")
          conn
          |> put_flash(:info, info)
          |> redirect(to: "/users/settings")
        else
          Logger.info("UserSessionController.create (credentials): Redirecting to /dashboard")
          conn
          |> put_flash(:info, info)
          |> redirect(to: "/dashboard") # Explicitly redirect to dashboard
        end


      {:error, _} ->
        Logger.info("UserSessionController.create (credentials): Authentication failed for email: #{email}")
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: "/users/log_in")
    end
  end

  # Handle login with token
  def create(conn, %{"token" => token, "remember_me" => remember_me}) do
    Logger.info("UserSessionController.create (token): Attempting login with token")
    # Call log_in_user to set session/cookie, then redirect explicitly
    conn
    |> put_session(@session_key, token) # Set the token directly in session
    |> configure_session(renew: true) # Renew session
    # Note: log_in_user is not called here, handle cookie logic if needed
    # |> UserAuth.maybe_write_remember_me_cookie(token, %{"remember_me" => remember_me}) # If you want remember_me for token login
    Logger.info("UserSessionController.create (token): Session token set: #{inspect get_session(conn, @session_key)}")


    conn
    |> put_flash(:info, "Welcome back!")
    |> redirect(to: "/dashboard") # Explicitly redirect to dashboard
  end

  # Helper function for session renewal (no longer used directly for login redirect)
  defp renew_session(conn) do
    Logger.info("UserSessionController.renew_session: Renewing and clearing session")
    conn
    |> configure_session(renew: true)
    |> clear_session() # Clears all session data, including user_return_to
  end

  def delete(conn, _params) do
    Logger.info("UserSessionController.delete: Starting logout process")
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> FrestylWeb.UserAuth.log_out_user()
  end

  # Add the new action for the login form
  def new(conn, _params) do
    Logger.info("UserSessionController.new: Rendering login form")
    # Render the login form template
    render(conn, :new)
  end
end
