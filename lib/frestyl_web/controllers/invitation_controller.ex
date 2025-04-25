# lib/frestyl_web/controllers/invitation_controller.ex
defmodule FrestylWeb.InvitationController do
  use FrestylWeb, :controller

  alias Frestyl.Events

  def accept(conn, %{"token" => token}) do
    case Events.get_invitation_by_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Invalid or expired invitation.")
        |> redirect(to: ~p"/events")

      invitation ->
        if invitation.status != :pending do
          conn
          |> put_flash(:error, "This invitation has already been #{invitation.status}.")
          |> redirect(to: ~p"/events")
        else
          current_user = conn.assigns.current_user

          case Events.accept_invitation(invitation, current_user.id) do
            {:ok, _} ->
              conn
              |> put_flash(:info, "Invitation accepted. You are now registered for the event.")
              |> redirect(to: ~p"/events/#{invitation.event_id}")

            {:error, _} ->
              conn
              |> put_flash(:error, "Error accepting invitation.")
              |> redirect(to: ~p"/events")
          end
        end
    end
  end

  def decline(conn, %{"token" => token}) do
    case Events.get_invitation_by_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Invalid or expired invitation.")
        |> redirect(to: ~p"/events")

      invitation ->
        if invitation.status != :pending do
          conn
          |> put_flash(:error, "This invitation has already been #{invitation.status}.")
          |> redirect(to: ~p"/events")
        else
          case Events.decline_invitation(invitation) do
            {:ok, _} ->
              conn
              |> put_flash(:info, "Invitation declined.")
              |> redirect(to: ~p"/events")

            {:error, _} ->
              conn
              |> put_flash(:error, "Error declining invitation.")
              |> redirect(to: ~p"/events")
          end
        end
    end
  end
end
