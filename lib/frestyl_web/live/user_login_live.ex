defmodule FrestylWeb.UserLoginLive do
  use FrestylWeb, :live_view

  alias Frestyl.Accounts
  alias Frestyl.Accounts.User
  alias FrestylWeb.UserAuth
  alias Phoenix.LiveView

  def mount(_params, _session, socket) do
    email = live_flash(socket.assigns.flash, :email)
    changeset = change_user_login(%{"email" => email || "", "password" => ""})

    {:ok, assign(socket, form: to_form(changeset), trigger_submit: false)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      {:noreply,
       socket
       |> assign(trigger_submit: true)
      }
    else
      changeset = change_user_login(user_params) |> Map.put(:action, :validate)
      form = to_form(changeset)

      {:noreply,
       socket
       |> put_flash(:error, "Invalid email or password")
       |> assign(form: form)
      }
    end
  end

  # Add this private function to create a changeset
  defp change_user_login(params \\ %{}) do
    %User{}
    |> Ecto.Changeset.cast(params, [:email, :password])  # Removed :remember_me
    |> Ecto.Changeset.validate_required([:email, :password])
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-sm mx-auto">
      <.header>
        Log in to your account
      </.header>

      <.simple_form for={@form} id="login_form" action="/users/log_in" phx-submit="save" phx-trigger-action={@trigger_submit}>
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <.input name="user[remember_me]" type="checkbox" label="Keep me logged in" />
          <.link href="/users/reset_password" class="text-sm font-semibold">
            Forgot your password?
          </.link>
        </:actions>
        <:actions>
          <.button phx-disable-with="Logging in..." class="w-full">
            Log in <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def handle_event("login", %{"user" => params}, socket) do
    %{"email" => email, "password" => password} = params
    remember_me = Map.get(params, "remember_me", "false")

    Logger.debug("Login attempt for email: #{email}")

    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        Logger.debug("Authentication successful for user: #{user.id}")

        # We now have two options for handling login:

        # Option 1: Use the traditional form submission approach
        # Let the regular form submit to the controller
        updated_form = to_form(params, as: "user")
        socket =
          socket
          |> assign(form: updated_form)
          |> assign(trigger_submit: true)
        Logger.debug("Triggering form submission to controller")
        {:noreply, socket}

        # Option 2: Generate token in LiveView and redirect to a special endpoint
        # This is commented out but can be used if Option 1 doesn't work
        # {token, _} = Accounts.generate_user_session_token(user)
        # Logger.debug("Generated token for direct login")
        # socket =
        #   socket
        #   |> assign(token_param: token)
        # {:noreply, socket}

      {:error, :invalid_credentials} ->
        Logger.error("Authentication failed for email: #{email}")
        form = to_form(%{"email" => email}, as: "user")
        {:noreply,
         socket
         |> put_flash(:error, "Invalid email or password.")
         |> assign(:form, form)
         |> assign(:error, "Invalid email or password.")}
    end
  end

  # Fallback handler for other patterns
  def handle_event("login", _params, socket) do
    Logger.error("Login attempt with invalid params format")
    {:noreply,
     socket
     |> put_flash(:error, "Please fill out the login form.")
     |> assign(:error, "Please fill out the login form.")}
  end

  # Keep validation handler
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%{})
    changeset = Ecto.Changeset.cast(changeset, user_params, [:email, :password, :remember_me])

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  # Add fallback for validate too
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  # Helper function for form assignment
  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    error_message = if changeset.errors != [], do: "Please check the errors below.", else: nil
    assign(socket, form: form, error: error_message)
  end
end
