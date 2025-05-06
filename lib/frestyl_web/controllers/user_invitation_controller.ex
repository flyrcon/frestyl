# File: lib/frestyl_web/controllers/user_invitation_controller.ex
defmodule FrestylWeb.UserInvitationController do
  use FrestylWeb, :controller

  alias Frestyl.Accounts
  alias Frestyl.Accounts.UserInvitation

  def show(conn, %{"token" => token}) do
    # Public view for invitation link - no auth required
    case Accounts.get_invitation_by_token(token) do
      %UserInvitation{status: "pending", expires_at: expires_at} = invitation ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          # Invitation is valid and not expired
          render(conn, :show, invitation: invitation)
        else
          # Invitation is expired
          conn
          |> put_flash(:error, "This invitation has expired")
          |> redirect(to: ~p"/login")
        end

      %UserInvitation{status: status} ->
        # Invitation exists but not pending
        conn
        |> put_flash(:error, "This invitation is #{status}")
        |> redirect(to: ~p"/login")

      nil ->
        # Invalid token
        conn
        |> put_flash(:error, "Invalid invitation")
        |> redirect(to: ~p"/login")
    end
  end

  def accept(conn, %{"token" => token}) do
    case Accounts.get_invitation_by_token(token) do
      %UserInvitation{status: "pending", expires_at: expires_at} = invitation ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          # Invitation is valid and not expired, redirect to registration
          conn
          |> assign(:invitation, invitation)
          |> redirect(to: ~p"/register?invite_token=#{token}")
        else
          # Invitation is expired
          conn
          |> put_flash(:error, "This invitation has expired")
          |> redirect(to: ~p"/login")
        end

      %UserInvitation{status: status} ->
        # Invitation exists but not pending
        conn
        |> put_flash(:error, "This invitation is #{status}")
        |> redirect(to: ~p"/login")

      nil ->
        # Invalid token
        conn
        |> put_flash(:error, "Invalid invitation")
        |> redirect(to: ~p"/login")
    end
  end

  def decline(conn, %{"token" => token}) do
    case Accounts.get_invitation_by_token(token) do
      %UserInvitation{} = invitation ->
        # Update invitation status to declined
        {:ok, _} = Accounts.update_invitation_status(invitation, "declined")

        conn
        |> put_flash(:info, "Invitation declined")
        |> redirect(to: ~p"/")

      nil ->
        conn
        |> put_flash(:error, "Invalid invitation")
        |> redirect(to: ~p"/")
    end
  end
end
