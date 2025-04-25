# lib/frestyl_web/controllers/membership_controller.ex
defmodule FrestylWeb.MembershipController do
  use FrestylWeb, :controller

  alias Frestyl.Channels
  alias Frestyl.Accounts

  def index(conn, %{"channel_slug" => channel_slug}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "manage_members") do
      members = Channels.list_channel_members(channel.id)
      roles = Channels.list_roles()
      render(conn, :index, channel: channel, members: members, roles: roles)
    else
      conn
      |> put_flash(:error, "You don't have permission to manage channel members")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  def create(conn, %{"channel_slug" => channel_slug, "email" => email, "role_name" => role_name}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "manage_members") do
      # Check if trying to assign a role they don't have permission to assign
      if role_name == "owner" && !Channels.has_permission?(user, channel, "assign_roles") do
        conn
        |> put_flash(:error, "You don't have permission to assign the owner role")
        |> redirect(to: ~p"/channels/#{channel_slug}/members")
      else
        # Find the user by email
        case Accounts.get_user_by_email(email) do
          nil ->
            conn
            |> put_flash(:error, "User with email #{email} not found")
            |> redirect(to: ~p"/channels/#{channel_slug}/members")

          member_to_add ->
            # Check if already a member
            if Channels.is_member?(channel, member_to_add) do
              conn
              |> put_flash(:error, "User is already a member of this channel")
              |> redirect(to: ~p"/channels/#{channel_slug}/members")
            else
              case Channels.add_channel_member(channel, member_to_add, role_name) do
                {:ok, _membership} ->
                  conn
                  |> put_flash(:info, "User added to channel successfully")
                  |> redirect(to: ~p"/channels/#{channel_slug}/members")

                {:error, _changeset} ->
                  conn
                  |> put_flash(:error, "Failed to add user to channel")
                  |> redirect(to: ~p"/channels/#{channel_slug}/members")
              end
            end
        end
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to manage channel members")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  def update(conn, %{"channel_slug" => channel_slug, "id" => membership_id, "role_name" => role_name}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "manage_members") do
      # Check if they're trying to assign owner role without permission
      if role_name == "owner" && !Channels.has_permission?(user, channel, "assign_roles") do
        conn
        |> put_flash(:error, "You don't have permission to assign the owner role")
        |> redirect(to: ~p"/channels/#{channel_slug}/members")
      else
        membership = Channels.get_membership!(membership_id)

        # Don't allow changing the role of the last owner
        if Channels.get_role_by_name("owner").id == membership.role_id do
          # Count owners
          owner_count = channel.id
            |> Channels.list_channel_members()
            |> Enum.count(fn m -> m.role_id == Channels.get_role_by_name("owner").id end)

          if owner_count <= 1 && role_name != "owner" do
            conn
            |> put_flash(:error, "Cannot change the role of the last owner")
            |> redirect(to: ~p"/channels/#{channel_slug}/members")
          else
            handle_role_update(conn, membership, role_name, channel_slug)
          end
        else
          handle_role_update(conn, membership, role_name, channel_slug)
        end
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to manage channel members")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  def delete(conn, %{"channel_slug" => channel_slug, "id" => user_id}) do
    channel = Channels.get_channel_by_slug(channel_slug)
    current_user = conn.assigns[:current_user]

    if channel && current_user && Channels.has_permission?(current_user, channel, "manage_members") do
      user_to_remove = Accounts.get_user!(user_id)

      # Check if trying to remove an owner
      if Channels.get_role_name(channel, user_to_remove) == "owner" do
        # Only users with assign_roles permission can remove owners
        if !Channels.has_permission?(current_user, channel, "assign_roles") do
          conn
          |> put_flash(:error, "You don't have permission to remove channel owners")
          |> redirect(to: ~p"/channels/#{channel_slug}/members")
        else
          # Check if it's the last owner
          owner_count = channel.id
            |> Channels.list_channel_members()
            |> Enum.count(fn m -> m.role_id == Channels.get_role_by_name("owner").id end)

          if owner_count <= 1 do
            conn
            |> put_flash(:error, "Cannot remove the last owner of the channel")
            |> redirect(to: ~p"/channels/#{channel_slug}/members")
          else
            handle_member_removal(conn, channel, user_to_remove, channel_slug)
          end
        end
      else
        # Non-owner removal
        handle_member_removal(conn, channel, user_to_remove, channel_slug)
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to manage channel members")
      |> redirect(to: ~p"/channels/#{channel_slug}")
    end
  end

  defp handle_role_update(conn, membership, role_name, channel_slug) do
    case Channels.update_member_role(membership, role_name) do
      {:ok, _updated} ->
        conn
        |> put_flash(:info, "Member role updated successfully")
        |> redirect(to: ~p"/channels/#{channel_slug}/members")

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to update member role")
        |> redirect(to: ~p"/channels/#{channel_slug}/members")
    end
  end

  defp handle_member_removal(conn, channel, user, channel_slug) do
    case Channels.remove_channel_member(channel, user) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Member removed from channel successfully")
        |> redirect(to: ~p"/channels/#{channel_slug}/members")

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to remove member from channel")
        |> redirect(to: ~p"/channels/#{channel_slug}/members")
    end
  end
end
