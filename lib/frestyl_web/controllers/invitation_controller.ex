# lib/frestyl_web/controllers/invitation_controller.ex
defmodule FrestylWeb.InvitationController do
  use FrestylWeb, :controller

  alias Frestyl.Events
  alias Frestyl.Channels

  # Event invitation acceptance
  def accept(conn, %{"token" => token, "type" => "event"}) do
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

  # Event invitation decline
  def decline(conn, %{"token" => token, "type" => "event"}) do
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

  # Channel invitation acceptance
  def accept(conn, %{"token" => token, "type" => "channel"}) do
    case Channels.get_invitation_by_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Invalid or expired channel invitation.")
        |> redirect(to: ~p"/channels")

      invitation ->
        if invitation.status != :pending do
          conn
          |> put_flash(:error, "This channel invitation has already been #{invitation.status}.")
          |> redirect(to: ~p"/channels")
        else
          current_user = conn.assigns.current_user

          case Channels.accept_invitation(invitation, current_user.id) do
            {:ok, channel} ->
              conn
              |> put_flash(:info, "Invitation accepted. You are now a member of the channel.")
              |> redirect(to: ~p"/channels/#{channel.slug}")

            {:error, _} ->
              conn
              |> put_flash(:error, "Error accepting channel invitation.")
              |> redirect(to: ~p"/channels")
          end
        end
    end
  end

  # Channel invitation decline
  def decline(conn, %{"token" => token, "type" => "channel"}) do
    case Channels.get_invitation_by_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Invalid or expired channel invitation.")
        |> redirect(to: ~p"/channels")

      invitation ->
        if invitation.status != :pending do
          conn
          |> put_flash(:error, "This channel invitation has already been #{invitation.status}.")
          |> redirect(to: ~p"/channels")
        else
          case Channels.decline_invitation(invitation) do
            {:ok, _} ->
              conn
              |> put_flash(:info, "Channel invitation declined.")
              |> redirect(to: ~p"/channels")

            {:error, _} ->
              conn
              |> put_flash(:error, "Error declining channel invitation.")
              |> redirect(to: ~p"/channels")
          end
        end
    end
  end

  # For backward compatibility - detect type from token format or structure
  def accept(conn, %{"token" => token}) do
    cond do
      Events.invitation_token_valid?(token) ->
        accept(conn, %{"token" => token, "type" => "event"})

      Channels.invitation_token_valid?(token) ->
        accept(conn, %{"token" => token, "type" => "channel"})

      true ->
        conn
        |> put_flash(:error, "Invalid invitation token.")
        |> redirect(to: ~p"/dashboard")
    end
  end

  def decline(conn, %{"token" => token}) do
    cond do
      Events.invitation_token_valid?(token) ->
        decline(conn, %{"token" => token, "type" => "event"})

      Channels.invitation_token_valid?(token) ->
        decline(conn, %{"token" => token, "type" => "channel"})

      true ->
        conn
        |> put_flash(:error, "Invalid invitation token.")
        |> redirect(to: ~p"/dashboard")
    end
  end
end
