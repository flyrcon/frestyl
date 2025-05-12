defmodule Frestyl.Channels do
  @moduledoc """
  The Channels context.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Channels.{Channel, ChannelMembership, BlockedUser}
  alias Frestyl.Channels.Message
  alias Frestyl.Channels.{Channel, ChannelMembership}
  alias Frestyl.Accounts.User
  alias Frestyl.Channels.ChannelInvitation

  ## Channel functions

  @doc """
  Returns the list of channels, excluding archived ones by default.
  """
  def list_channels(include_archived \\ false) do
    Channel
    |> exclude_archived(include_archived)
    |> Repo.all()
  end

  @doc """
  Returns the list of public channels, excluding archived ones by default.
  """
  def list_public_channels(include_archived \\ false) do
    Channel
    |> where([c], c.visibility == "public")
    |> exclude_archived(include_archived)
    |> Repo.all()
  end

  @doc """
  Searches public channels by name or description, excluding archived ones by default.
  """
  def search_public_channels(search_term, include_archived \\ false) do
    term = "%#{search_term}%"

    Channel
    |> where([c], c.visibility == "public")
    |> where([c], ilike(c.name, ^term) or ilike(c.description, ^term))
    |> exclude_archived(include_archived)
    |> Repo.all()
  end

  @doc """
  Returns the list of channels for a user, excluding archived ones by default.
  """
  def list_user_channels(user, include_archived \\ false) do
    user_id = if is_map(user), do: user.id, else: user

    query = from c in Channel,
            join: cm in ChannelMembership, on: c.id == cm.channel_id,
            where: cm.user_id == ^user_id, # Now using just the ID
            order_by: [desc: c.updated_at],
            select: %{
              id: c.id,
              name: c.name,
              description: c.description,
              visibility: c.visibility,
              category: c.category,
              icon_url: c.icon_url,
              archived: c.archived,
              member_count: fragment("(SELECT COUNT(*) FROM channel_memberships WHERE channel_id = ?)", c.id)
            }

    query = exclude_archived(query, include_archived)
    Repo.all(query)
  end

  # Helper to exclude archived channels
  defp exclude_archived(query, true), do: query
  defp exclude_archived(query, false), do: where(query, [c], c.archived == false or is_nil(c.archived))

  @doc """
  Gets a single channel.
  """
  def get_channel!(id), do: Repo.get!(Channel, id)

  @doc """
  Creates a channel.
  """
  def create_channel(attrs \\ %{}, user) do
    attrs_with_owner = Map.put(attrs, "owner_id", user.id)

    %Channel{}
    |> Channel.changeset(attrs_with_owner) # Use the new attrs map with owner_id
    |> Repo.insert()
    |> case do
      {:ok, channel} ->
        # Make the creator an admin member
        create_membership(%{
          channel_id: channel.id,
          user_id: user.id,
          role: "admin",
          last_activity_at: DateTime.utc_now()
        })

        # Broadcast channel creation
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "channels",
          {:channel_created, channel}
        )

        {:ok, channel}
      error -> error
    end
  end

  @doc """
  Updates a channel.
  """
  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_channel} ->
        # Broadcast channel update
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "channels",
          {:channel_updated, updated_channel}
        )

        {:ok, updated_channel}
      error -> error
    end
  end

  @doc """
  Deletes a channel.
  """
  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
    |> case do
      {:ok, deleted_channel} ->
        # Broadcast channel deletion
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "channels",
          {:channel_deleted, deleted_channel}
        )

        {:ok, deleted_channel}
      error -> error
    end
  end

  def is_last_admin?(channel_id, user_id) do
    # First, check if the user is an admin or owner
    user_is_admin = from(m in ChannelMember,
      where: m.channel_id == ^channel_id and m.user_id == ^user_id and m.role in ["admin", "owner"],
      select: count(m.id)
    ) |> Repo.one() > 0

    # If they're not an admin/owner, they're not the last admin
    if !user_is_admin do
      false
    else
      # Count how many admins/owners exist in the channel
      admin_count = from(m in ChannelMember,
        where: m.channel_id == ^channel_id and m.role in ["admin", "owner"],
        select: count(m.id)
      ) |> Repo.one()

      # If there's only one admin and this user is an admin, they must be the last admin
      admin_count == 1
    end
  end

  @doc """
  Archives a channel instead of deleting it.
  """
  def archive_channel(%Channel{} = channel, user) do
    if can_edit_channel?(channel, user) do
      channel
      |> Channel.archive_changeset(%{
        archived: true,
        archived_at: DateTime.utc_now()
      })
      |> Repo.update()
      |> case do
        {:ok, archived_channel} ->
          # Broadcast channel update
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "channels",
            {:channel_archived, archived_channel}
          )

          {:ok, archived_channel}
        error -> error
      end
    else
      {:error, "You don't have permission to archive this channel"}
    end
  end

  @doc """
  Restores an archived channel.
  """
  def unarchive_channel(%Channel{} = channel, user) do
    if can_edit_channel?(channel, user) do
      channel
      |> Channel.archive_changeset(%{
        archived: false,
        archived_at: nil
      })
      |> Repo.update()
      |> case do
        {:ok, unarchived_channel} ->
          # Broadcast channel update
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "channels",
            {:channel_unarchived, unarchived_channel}
          )

          {:ok, unarchived_channel}
        error -> error
      end
    else
      {:error, "You don't have permission to unarchive this channel"}
    end
  end

  @doc """
  Permanently deletes a channel.
  Only channel owners and admins can do this.
  """
  def permanently_delete_channel(%Channel{} = channel, user) do
    if is_owner_or_admin?(channel, user) do
      Repo.delete(channel)
      |> case do
        {:ok, deleted_channel} ->
          # Broadcast channel deletion
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "channels",
            {:channel_deleted, deleted_channel}
          )

          {:ok, deleted_channel}
        error -> error
      end
    else
      {:error, "Only channel owners and admins can permanently delete channels"}
    end
  end

  @doc """
  Creates a new message in a channel.

  ## Examples

      iex> create_message(%{content: "Hello", user_id: 1, channel_id: 1})
      {:ok, %Message{}}

      iex> create_message(%{content: "", user_id: nil, channel_id: nil})
      {:error, %Ecto.Changeset{}}
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> maybe_preload_message_associations()
  end

  @doc """
  Gets a message by ID.
  """
  def get_message!(id), do: Repo.get!(Message, id) |> Repo.preload([:user, :channel])

  @doc """
  Lists all messages for a channel.
  """
  def list_channel_messages(channel_id) do
    Message
    |> where([m], m.channel_id == ^channel_id)
    |> order_by([m], asc: m.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  # Helper to preload associations
  defp maybe_preload_message_associations({:ok, message}) do
    {:ok, Repo.preload(message, [:user, :channel])}
  end
  defp maybe_preload_message_associations(error), do: error

  # Helper function to broadcast changes
  defp broadcast_message_change({:ok, message}, event) do
    # Broadcast the change so subscribers can update their LiveViews
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{message.channel_id}",
      {event, message}
    )

    {:ok, message}
  end
  defp broadcast_message_change(error, _event), do: error

  # Helper to preload associations if needed
  defp maybe_preload_associations({:ok, message}) do
    {:ok, Repo.preload(message, [:user, :channel])}
  end
  defp maybe_preload_associations(error), do: error

  # Add this helper function
  defp is_owner_or_admin?(%Channel{} = channel, user) do
    cond do
      user.role == "admin" -> true
      channel.owner_id == user.id -> true
      true -> false
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking channel changes.
  """
  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.changeset(channel, attrs)
  end

  ## Channel membership functions

  @doc """
  Checks if a user is a member of a channel.
  """
  def user_member?(user, channel) do
    Repo.exists?(
      from m in ChannelMembership,
      where: m.user_id == ^user.id and m.channel_id == ^channel.id
    )
  end

  @doc """
  Checks if a user can edit a channel.
  """
  def can_edit_channel?(channel, user) do
    Repo.exists?(
      from m in ChannelMembership,
      where: m.channel_id == ^channel.id and m.user_id == ^user.id and m.role in ["admin", "moderator"]
    )
  end

  @doc """
  Checks if user can send messages in a channel.
  """
  def can_send_messages?(user, channel) do
    # By default, all members can send messages
    user_member?(user, channel)
  end

  @doc """
  Adds a user to a channel.
  """
  def join_channel(user, channel) do
    case channel.visibility do
      "public" ->
        create_membership(%{
          channel_id: channel.id,
          user_id: user.id,
          role: "member",
          status: "active",
          last_activity_at: DateTime.utc_now()
        })
      "private" ->
        {:error, "This channel requires approval to join"}
      "invite_only" ->
        {:error, "This channel is invite-only"}
    end
  end

  def invite_to_channel(inviter_id, channel_id, email) do
    # Use the existing aliases to get the user
    user = Accounts.get_user_by_email(email)

    # Add a check to see if user is already a member
    if user && user_member?(user, %{id: channel_id}) do
      {:error, "User is already a member of this channel"}
    else
      # Generate token (keep your existing function)
      token = generate_random_token()

      # Set expiration (7 days)
      expires_at = DateTime.utc_now() |> DateTime.add(7, :day)

      # Create invitation - using changeset instead of direct struct creation for validation
      %ChannelInvitation{}
      |> ChannelInvitation.changeset(%{
        channel_id: channel_id,
        inviter_id: inviter_id,
        email: email,
        user_id: user && user.id,
        token: token,
        status: :pending,  # Use atom instead of string for Ecto.Enum
        expires_at: expires_at
      })
      |> Repo.insert()
      |> case do
        {:ok, invitation} ->
          # Keep your existing email notification logic
          if user do
            Frestyl.Notifications.send_channel_invitation_email(user, invitation)
          else
            Frestyl.Notifications.send_channel_invitation_email_to_new_user(email, invitation)
          end
          {:ok, invitation}

        error -> error
      end
    end
  end

  # Helper function to generate a random token
  defp generate_random_token do
    :crypto.strong_rand_bytes(20) |> Base.url_encode64() |> binary_part(0, 20)
  end

  def accept_invitation(token) do
    # Find the invitation
    invitation = Repo.get_by(ChannelInvitation, token: token)

    cond do
      # If invitation doesn't exist
      is_nil(invitation) ->
        {:error, "Invalid invitation"}

      # If invitation has expired
      DateTime.compare(invitation.expires_at, DateTime.utc_now()) == :lt ->
        {:error, "This invitation has expired"}

      # If invitation has already been used
      invitation.status != "pending" ->
        {:error, "This invitation has already been #{invitation.status}"}

      # Valid invitation
      true ->
        # Get or create the user
        user =
          if invitation.user_id do
            Repo.get(User, invitation.user_id)
          else
            # Create a new user if they don't exist yet
            # This should be handled by your user registration flow
            {:error, "User registration required"}
          end

        case user do
          {:error, message} ->
            {:error, message}

          user ->
            # Add the user to the channel
            channel = Repo.get(Channel, invitation.channel_id)

            # Use create_membership instead of add_channel_member
            case create_membership(%{
              channel_id: channel.id,
              user_id: user.id,
              role: "member",
              status: "active",
              last_activity_at: DateTime.utc_now()
            }) do
              {:ok, _} ->
                # Update invitation status
                invitation
                |> Ecto.Changeset.change(%{status: "accepted"})
                |> Repo.update()

                {:ok, %{channel: channel, user: user}}

              error -> error
            end
        end
    end
  end

  @doc """
  Removes a user from a channel.
  Returns error if trying to remove the last admin when other members remain.
  """
  def leave_channel(user, channel) do
    # Check if this is the last admin
    if is_last_admin?(channel.id, user.id) do
      {:error, "You cannot leave the channel as you are the only admin. Please promote another member to admin first."}
    else
      # Find the membership
      channel_member = Repo.get_by(ChannelMember, user_id: user.id, channel_id: channel.id)

      if channel_member do
        # Delete the membership
        Repo.delete(channel_member)
      else
        {:error, "You are not a member of this channel"}
      end
    end
  end

  @doc """
  Creates a channel membership.
  """
  def create_membership(attrs) do
    %ChannelMembership{}
    |> ChannelMembership.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a channel membership for a user.
  """
  def get_channel_membership(user, channel) do
    Repo.one(
      from m in ChannelMembership,
      where: m.user_id == ^user.id and m.channel_id == ^channel.id
    )
  end

  @doc """
  Lists members of a channel with their user info.
  """
  def list_channel_members(channel_id) do
    Repo.all(
      from m in ChannelMembership,
      where: m.channel_id == ^channel_id,
      join: u in User, on: m.user_id == u.id,
      preload: [user: u],
      order_by: [desc: m.inserted_at]
    )
  end

  @doc """
  Updates a user's role in a channel.
  """
  def update_member_role(membership, role) when role in ["admin", "moderator", "member"] do
    membership
    |> ChannelMembership.changeset(%{role: role})
    |> Repo.update()
  end

  @doc """
  Updates a user's last activity time in a channel.
  """
  def update_member_activity(user_id, channel_id) do
    membership = Repo.one(
      from m in ChannelMembership,
      where: m.user_id == ^user_id and m.channel_id == ^channel_id
    )

    if membership do
      membership
      |> ChannelMembership.changeset(%{last_activity_at: DateTime.utc_now()})
      |> Repo.update()
    else
      {:error, "Membership not found"}
    end
  end

  @doc """
  Blocks a user from a channel.
  """
  def block_user(channel, %User{} = user, %User{} = blocked_by, attrs \\ %{}) do
    # Remove any existing memberships
    case get_channel_membership(user, channel) do
      nil -> :ok  # No membership to remove
      membership -> Repo.delete(membership)
    end

    # Create the block
    %BlockedUser{}
    |> BlockedUser.changeset(Map.merge(attrs, %{
      channel_id: channel.id,
      user_id: user.id,
      blocked_by_user_id: blocked_by.id
    }))
    |> Repo.insert()
  end

  @doc """
  Blocks an email address from a channel.
  """
  def block_email(channel, email, %User{} = blocked_by, attrs \\ %{}) do
    %BlockedUser{}
    |> BlockedUser.changeset(Map.merge(attrs, %{
      channel_id: channel.id,
      email: email,
      blocked_by_user_id: blocked_by.id
    }))
    |> Repo.insert()
  end

  @doc """
  Unblocks a user from a channel.
  """
  def unblock_user(channel, %User{} = user) do
    Repo.get_by(BlockedUser, channel_id: channel.id, user_id: user.id)
    |> case do
      nil -> {:error, "User is not blocked"}
      blocked -> Repo.delete(blocked)
    end
  end

  @doc """
  Unblocks an email from a channel.
  """
  def unblock_email(channel, email) do
    Repo.get_by(BlockedUser, channel_id: channel.id, email: email)
    |> case do
      nil -> {:error, "Email is not blocked"}
      blocked -> Repo.delete(blocked)
    end
  end

  @doc """
  Returns true if a user is blocked from a channel.
  """
  def is_blocked?(channel, %User{} = user) do
    Repo.exists?(from b in BlockedUser,
      where: b.channel_id == ^channel.id and b.user_id == ^user.id and
            (is_nil(b.expires_at) or b.expires_at > ^DateTime.utc_now())
    )
  end

  @doc """
  Returns true if an email is blocked from a channel.
  """
  def is_email_blocked?(channel, email) do
    Repo.exists?(from b in BlockedUser,
      where: b.channel_id == ^channel.id and b.email == ^email and
            (is_nil(b.expires_at) or b.expires_at > ^DateTime.utc_now())
    )
  end

  @doc """
  Lists all blocked users for a channel.
  """
  def list_blocked_users(channel_id) do
    Repo.all(from b in BlockedUser,
      where: b.channel_id == ^channel_id and not is_nil(b.user_id),
      preload: [:user]
    )
  end

  @doc """
  Lists all blocked emails for a channel.
  """
  def list_blocked_emails(channel_id) do
    Repo.all(from b in BlockedUser,
      where: b.channel_id == ^channel_id and not is_nil(b.email),
      select: b
    )
  end

  @doc """
  Returns the visibility options for channels.
  """
  def visibility_options do
    ~w(public private invite_only)
  end

  @doc """
  Sets active media for a channel category.
  """
  def set_active_media(%Channel{} = channel, category, media_item_id)
  when category in [:branding, :presentation, :performance] do

  # Build attribute map based on category
  field_name = String.to_atom("active_#{category}_media_id")
  attrs = %{field_name => media_item_id}

  # Update the channel
  channel
  |> Channel.media_changeset(attrs)
  |> Repo.update()
  |> case do
  {:ok, updated_channel} ->
    # Broadcast active media change
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{channel.id}",
      {:media_changed, %{category: category, media_id: media_item_id}}
    )
    {:ok, updated_channel}
  error -> error
  end
  end

  @doc """
  Clears active media for a channel category.
  """
  def clear_active_media(%Channel{} = channel, category)
  when category in [:branding, :presentation, :performance] do
  set_active_media(channel, category, nil)
  end

  @doc """
  Gets active media for a channel.
  """
  def get_active_media(%Channel{} = channel) do
  # Load active media items
  branding_media = if channel.active_branding_media_id,
                  do: Repo.get(Frestyl.Media.MediaItem, channel.active_branding_media_id),
                  else: nil

  presentation_media = if channel.active_presentation_media_id,
                      do: Repo.get(Frestyl.Media.MediaItem, channel.active_presentation_media_id),
                      else: nil

  performance_media = if channel.active_performance_media_id,
                    do: Repo.get(Frestyl.Media.MediaItem, channel.active_performance_media_id),
                    else: nil

  %{
  branding: branding_media,
  presentation: presentation_media,
  performance: performance_media
  }
  end

  @doc """
  Updates channel media settings.
  """
  def update_media_settings(%Channel{} = channel, attrs) do
  channel
  |> Channel.media_settings_changeset(attrs)
  |> Repo.update()
  |> case do
  {:ok, updated_channel} ->
    # Broadcast channel update
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channels",
      {:channel_updated, updated_channel}
    )

    {:ok, updated_channel}
  error -> error
  end
  end

  @doc """
  Gets a channel by slug.
  """
  def get_channel_by_slug!(slug) do
  Repo.get_by!(Channel, slug: slug)
  end
end
