# File: lib/frestyl_web/live/invite_user_live.ex
defmodule FrestylWeb.InviteUserLive do
  use FrestylWeb, :live_view

  alias Frestyl.Accounts
  import FrestylWeb.Navigation, only: [nav: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Invite User")
     |> assign(:active_tab, :invite)
     |> assign(:form, to_form(%{"email" => ""}, as: :invite))}
  end

  @impl true
  def handle_event("validate", %{"invite" => invite_params}, socket) do
    {:noreply, assign(socket, :form, to_form(invite_params, as: :invite))}
  end

  @impl true
  def handle_event("submit", %{"invite" => %{"email" => email}}, socket) do
    current_user = socket.assigns.current_user

    case Accounts.invite_user(email, current_user) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}")
         |> push_navigate(to: ~p"/dashboard")}

      {:error, "User already exists"} ->
        {:noreply,
         socket
         |> put_flash(:error, "User with this email already exists")
         |> assign(:form, to_form(%{"email" => ""}, as: :invite))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to send invitation")
         |> assign(:form, to_form(changeset, as: :invite))}
    end
  end
end
