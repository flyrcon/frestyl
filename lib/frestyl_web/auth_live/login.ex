# In lib/frestyl_web/auth_live/login.ex

defmodule FrestylWeb.AuthLive.Login do
  use FrestylWeb, :live_view

  alias Frestyl.Accounts
  require Logger # Ensure Logger is required if you have debug statements

  def mount(_params, _session, socket) do
    # Use Accounts.change_user_registration if this is a registration-style login form
    # that doesn't require name validation on initial load.
    # If it's a standard login, Accounts.change_user is fine here for form building.
    changeset = Accounts.change_user(%Frestyl.Accounts.User{})
    {:ok, assign(socket, changeset: changeset, error: nil)}
  end

  def render(assigns) do
    ~H"""
    <%# START: Styled Login Form Template - Copied from auth_live_login_template_styled immersive %>
    <div class="mx-auto max-w-md px-4 py-8 bg-white shadow-lg rounded-xl">
      <h2 class="text-2xl font-bold text-center text-gray-800 mb-6">Login</h2>

      <%= if @error do %>
        <div class="text-red-600 text-sm mb-4 text-center"><%= @error %></div>
      <% end %>

      <.simple_form :let={f} for={@changeset} phx-submit="login" class="space-y-6">
        <div class="flex flex-col">
          <.input field={f[:email]} type="email" label="Email" required class="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500" />
            <%# <.input> component usually handles displaying field-specific errors automatically %>
        </div>

        <div class="flex flex-col">
          <.input field={f[:password]} type="password" label="Password" required class="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500" />
          <%# <.input> component usually handles displaying field-specific errors automatically %>
        </div>

        <:actions>
          <.button type="submit" class="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition duration-150 ease-in-out">
            Login
          </.button>
        </:actions>
      </.simple_form>
    </div>
    <%# END: Styled Login Form Template %>
    """
  end

  # Correct the pattern match to expect parameters nested under "user"
  def handle_event("login", %{"user" => %{"email" => email, "password" => password}}, socket) do
    Logger.debug("Login handle_event received email: #{email}, password: #{password}")

    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        Logger.info("User authenticated successfully: #{user.email}")
        # Success branch: redirect, set session, etc.
        {:noreply,
          socket
          |> put_flash(:info, "Welcome back!")
          |> Phoenix.LiveView.push_redirect(to: ~p"/dashboard", replace: true) # Redirect to dashboard or signed_in_path
          |> assign(:current_user, user)
          |> maybe_put_user_session(user)} # Ensure maybe_put_user_session is correct

      {:error, _} ->
        Logger.warn("Authentication failed for email: #{email}")
        # Failure branch: assign error message and update changeset for form errors
        changeset = Accounts.change_user(%Frestyl.Accounts.User{}, %{email: email})
        {:noreply, assign(socket, changeset: changeset, error: "Invalid credentials")}
    end
  end

  # Keep your other handle_event clauses below this one if they exist
  # def handle_event("open_profile", ...)...

  # The handle_event("open_profile", ...) functions seem unrelated to login,
  # ensure they are handled correctly or remove if not needed here.
  # def handle_event("open_profile", %{"value" => ""}, socket) do
  #   Logger.debug("--- handle_event('open_profile', ...) triggered with empty value ---")
  #   {:noreply, socket}
  # end

  # def handle_event("open_profile", %{"value" => value}, socket) do
  #   Logger.debug("--- handle_event('open_profile', ...) triggered with value: #{value} ---")
  #   {:noreply, socket}
  # end


  # Ensure maybe_put_user_session is correctly defined and imported or aliased
  # If it's in FrestylWeb.UserAuth, you might need to call FrestylWeb.UserAuth.maybe_put_user_session
  # or move it into this module. Assuming it's a helper in UserAuth and UserAuth is imported.
  # If maybe_put_user_session is not defined in UserAuth or this module, you'll get an error.

  # Placeholder/Example maybe_put_user_session if not in UserAuth:
  defp maybe_put_user_session(socket, user) do
      # This is a simplified example. Your actual implementation might be different.
      # It should put the user's ID or token into the session.
      Phoenix.LiveView.put_session(socket, :user_id, user.id)
  end

end
