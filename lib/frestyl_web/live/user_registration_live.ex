# lib/frestyl_web/live/user_registration_live.ex
defmodule FrestylWeb.UserRegistrationLive do
  use FrestylWeb, :live_view

  alias Frestyl.Accounts
  alias Frestyl.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="max-w-sm mx-auto py-12">
      <div class="bg-white shadow-sm rounded-lg p-6">
        <h2 class="text-2xl font-bold mb-6">Create an account</h2>

        <.simple_form
          for={@form}
          id="registration-form"
          phx-submit="submit"
          phx-change="validate"
        >
          <.input field={@form[:name]} type="text" label="Name" required />
          <.input field={@form[:username]} type="text" label="Username" required />
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Password" required />

          <:actions>
            <.button phx-disable-with="Creating account..." class="w-full">
              Create Account
            </.button>
          </:actions>
        </.simple_form>

        <p class="text-sm text-center mt-6">
          Already have an account? <.link navigate="/login" class="text-indigo-600 hover:text-indigo-500">Log in</.link>
        </p>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration()

    {:ok,
     socket
     |> assign(:page_title, "Create Account")
     |> assign(:changeset, changeset)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("submit", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Send confirmation email
        Accounts.send_confirmation_email(user)

        info = "Account created successfully! Please check your email to confirm your account."

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> push_navigate(to: "/login")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(user_params)
    changeset = Map.put(changeset, :action, :validate)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:form, to_form(changeset))}
  end
end
