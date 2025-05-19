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
  alias Frestyl.Channels.Room
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
  # lib/frestyl/channels.ex (partial suggested changes)

  # The error happens because get_channel/1 is using Repo.get! which raises an error when id is nil
  # Here's a safer implementation:

  def get_channel(nil), do: nil  # Handle nil ID explicitly

  def get_channel(id) do
    try do
      Repo.get(Channel, id)
    rescue
      # Handle any errors (like invalid ID format)
      _e in Ecto.Query.CastError -> nil
      _e -> nil  # Catch all other errors and return nil
    end
  end

  # If your Channel module uses slugs, you might need this version instead:
  def get_channel_by_slug(nil), do: nil

  def get_channel_by_slug(slug) when is_binary(slug) do
    try do
      Repo.get_by(Channel, slug: slug)
    rescue
      _e -> nil  # Catch any errors and return nil
    end
  end

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

   @doc """
  Gets a channel with the given ID.
  """
  def get_channel!(id), do: Repo.get!(Channel, id)

  # In your Frestyl.Channels module (create it if it doesn't exist)
  def list_channels_for_user(_user_id) do
    # Return an empty list for now, implement proper channel fetching later
    []
  end

  @doc """
  Gets the default room for a channel.
  """
  def get_default_room(channel_id) do
    Room
    |> where([r], r.channel_id == ^channel_id and r.is_default == true)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Creates a default room for a channel if one doesn't exist.
  """
  def create_default_room(channel_id) do
    case get_default_room(channel_id) do
      nil ->
        %Room{}
        |> Room.changeset(%{
          name: "General",
          description: "General discussion",
          channel_id: channel_id,
          is_default: true
        })
        |> Repo.insert()

      room ->
        {:ok, room}
    end
  end

  @doc """
  Gets or creates a general room for a channel.
  """
  def get_or_create_general_room(channel_id) do
    case get_default_room(channel_id) do
      nil -> create_default_room(channel_id)
      room -> {:ok, room}
    end
  end

  @doc """
  Creates a default room for a channel if one doesn't exist.
  """
  def create_default_room(channel_id) do
    # First check if a default room already exists
    case get_default_room(channel_id) do
      nil ->
        # Get the channel to ensure it exists
        channel = get_channel!(channel_id)

        # Create a default room
        %Room{}
        |> Room.changeset(%{
          name: "General",
          channel_id: channel_id,
          is_default: true,
          description: "Default room for #{channel.name}"
        })
        |> Repo.insert()

      room ->
        {:ok, room}
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

  # lib/frestyl/channels.ex - Changes to add

  # These are the key functions needed by ChannelLive.Show that need to be adapted

  # Check if a user is blocked from a channel
  def user_blocked?(channel_id, user_id) do
    # Check directly in the database if this user is blocked for this channel
    Repo.exists?(from b in BlockedUser,
      where: b.channel_id == ^channel_id and b.user_id == ^user_id and
            (is_nil(b.expires_at) or b.expires_at > ^DateTime.utc_now())
    )
  end

  # Check if a user is a member of a channel
  def is_member?(channel_id, user_id) do
    Repo.exists?(
      from m in ChannelMembership,
      where: m.channel_id == ^channel_id and m.user_id == ^user_id
    )
  end

  # Check if a user is an admin of a channel (using direct query)
  def is_admin?(channel_id, user_id) do
    Repo.exists?(
      from m in ChannelMembership,
      where: m.channel_id == ^channel_id and m.user_id == ^user_id and m.role in ["admin", "owner"]
    )
  end

  # Get a member's role in a channel
  def get_member_role(channel_id, user_id) do
    query = from m in ChannelMembership,
      where: m.channel_id == ^channel_id and m.user_id == ^user_id,
      select: m.role

    Repo.one(query) || "guest"
  end

  # Join a channel using IDs
  def join_channel(channel_id, user_id) do
    # Create a new membership record directly
    create_membership(%{
      channel_id: channel_id,
      user_id: user_id,
      role: "member",
      status: "active",
      last_activity_at: DateTime.utc_now()
    })
  end

  # Leave a channel using IDs
  def leave_channel(channel_id, user_id) do
    # Find the membership
    membership = Repo.get_by(ChannelMembership, channel_id: channel_id, user_id: user_id)

    if membership do
      # Delete the membership
      Repo.delete(membership)
    else
      {:error, "Membership not found"}
    end
  end

  # Get channel member with preloaded user
  def get_channel_member(channel_id, user_id) do
    Repo.one(
      from m in ChannelMembership,
      where: m.channel_id == ^channel_id and m.user_id == ^user_id,
      preload: [:user]
    )
  end

  # Update a member's role directly using IDs
  def update_member_role(channel_id, user_id, role) when role in ["admin", "moderator", "member"] do
    membership = get_channel_member(channel_id, user_id)

    if membership do
      # Using the existing changeset directly since update_member_role/2 doesn't exist
      membership
      |> ChannelMembership.changeset(%{role: role})
      |> Repo.update()
    else
      {:error, "Membership not found"}
    end
  end

  # Remove a member from a channel
  def remove_member(channel_id, user_id) do
    membership = get_channel_member(channel_id, user_id)

    if membership do
      Repo.delete(membership)
    else
      {:error, "Membership not found"}
    end
  end

  # Block a user by ID or email with a reason and duration
  # For the block_user/3 function:

  # Block a user by ID or email with a reason and duration
  def block_user(channel_id, email_or_id, attrs \\ %{}) do
    channel = get_channel(channel_id)

    if !channel do
      {:error, "Channel not found"}
    else
      user = case email_or_id do
        email when is_binary(email) -> Frestyl.Accounts.get_user_by_email(email)
        id when is_integer(id) -> Frestyl.Accounts.get_user(id)
      end

      attrs = Map.take(attrs, [:reason, :duration])

      # Get admin user for blocking - you might want to use the current user here
      admin_user = Frestyl.Accounts.get_system_user()

      if user do
        # Convert duration string to actual expiration date
        attrs = case attrs[:duration] do
          "permanent" -> attrs
          "1d" -> Map.put(attrs, :expires_at, DateTime.add(DateTime.utc_now(), 1, :day))
          "7d" -> Map.put(attrs, :expires_at, DateTime.add(DateTime.utc_now(), 7, :day))
          "30d" -> Map.put(attrs, :expires_at, DateTime.add(DateTime.utc_now(), 30, :day))
          "90d" -> Map.put(attrs, :expires_at, DateTime.add(DateTime.utc_now(), 90, :day))
          _ -> attrs
        end

        # Using your existing block_user function with proper signature
        # Check the existing signature in the current file
        %BlockedUser{}
        |> BlockedUser.changeset(Map.merge(attrs, %{
          channel_id: channel.id,
          user_id: user.id,
          blocked_by_user_id: admin_user.id
        }))
        |> Repo.insert()
      else
        # Email blocking
        %BlockedUser{}
        |> BlockedUser.changeset(Map.merge(attrs, %{
          channel_id: channel.id,
          email: email_or_id,
          blocked_by_user_id: admin_user.id
        }))
        |> Repo.insert()
      end
    end
  end

  # Unblock a user or email
  def unblock_user(block_id) do
    block = Repo.get(BlockedUser, block_id)

    if block do
      Repo.delete(block)
    else
      {:error, "Block not found"}
    end
  end

  # List messages for a channel with optional limit
  def list_messages(channel_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Message
    |> where([m], m.room_id == ^channel_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  # Subscribe to a channel's PubSub topic
  def subscribe(channel_id) do
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel_id}")
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
  # Add this function to handle channel IDs
  @doc """
  Gets active media for a channel.
  """
  # Handle Channel struct
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

  # Handle integer or string IDs
  def get_active_media(channel_id) when is_integer(channel_id) or is_binary(channel_id) do
    channel_id = if is_binary(channel_id), do: String.to_integer(channel_id), else: channel_id

    # Try to fetch the channel
    case get_channel(channel_id) do
      nil -> %{} # Return an empty map if channel not found
      channel -> get_active_media(channel)
    end
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
end
