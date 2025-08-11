defmodule Frestyl.Channels do
  @moduledoc """
  The Channels context.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Accounts.User # Added for clarity in some functions
  alias Frestyl.Channels.{Channel, ChannelMembership, Message, BlockedUser, Room, ChannelInvitation}
  alias Frestyl.Notifications # Added for clarity in invite_to_channel
  alias Frestyl.Accounts # Added for clarity in invite_to_channel and block_user
  alias Frestyl.Sessions # Added for clarity in session/broadcast functions

  ## Channel functions

  @doc """
  Helper to dynamically apply archived filter.
  For queries starting with Channel as first binding.
  """
  defp exclude_archived(query, true), do: query
  defp exclude_archived(query, false), do: where(query, [c], c.archived == false)

  @doc """
  Helper to dynamically apply archived filter for user channel queries.
  For queries starting with ChannelMembership as first binding.
  """
  defp exclude_archived_user_channels(query, true), do: query
  defp exclude_archived_user_channels(query, false), do: where(query, [cm, c], c.archived == false)

  @doc """
  Base query for channels, including member count.
  """
  defp base_channel_query do
    from c in Channel,
      left_join: cm in assoc(c, :channel_memberships),
      group_by: c.id,
      # Always select the channel and its member count as a tuple
      select: {c, count(cm.id)}
  end

  @doc """
  Returns the list of all channels, including member count, excluding archived ones by default.
  """
  def list_channels(include_archived \\ false) do
    base_channel_query()
    |> exclude_archived(include_archived)
    |> Repo.all()
  end

  @doc """
  Returns the list of public channels, including member count, excluding archived ones by default.
  """
  def list_public_channels(include_archived \\ false) do
    base_channel_query()
    |> where([c, _member_count], c.visibility == "public") # Adjust where clause for tuple select
    |> exclude_archived(include_archived)
    |> Repo.all()
  end

  @doc """
  Searches public channels by name or description, including member count, excluding archived ones by default.
  """
  def search_public_channels(search_term, include_archived \\ false) do
    term = "%#{search_term}%"

    base_channel_query()
    |> where([c, _member_count], c.visibility == "public") # Adjust where clause for tuple select
    |> where([c, _member_count], ilike(c.name, ^term) or ilike(c.description, ^term))
    |> exclude_archived(include_archived)
    |> Repo.all()
  end

  @doc """
  Returns channels a user is a member of, including member count.
  """
  def list_user_channels(user, include_archived \\ false) do
    user_id = if is_map(user), do: user.id, else: user

    # Use left_join to get all channel memberships for the user,
    # and then count members for each channel.
    query = from cm in ChannelMembership,
      join: c in assoc(cm, :channel), # Join to Channel from ChannelMembership
      left_join: all_cm in assoc(c, :channel_memberships), # Left join again for overall channel member count
      where: cm.user_id == ^user_id,
      group_by: c.id,
      order_by: [desc: c.updated_at],
      select: {c, count(all_cm.id)} # Select channel and its total member count

    query = exclude_archived_user_channels(query, include_archived)
    Repo.all(query)
  end


  @doc """
  Archives a channel. Sets archived: true, archived_at: now.
  Only owner/admin can do this.
  """
  def archive_channel(%Channel{} = channel, %User{} = user) do
    if is_owner_or_admin?(channel, user) do
      channel
      |> Channel.archive_changeset(%{
        archived: true,
        archived_at: DateTime.utc_now(),
        archived_by_id: user.id # Ensure archived_by_id is set
      })
      |> Repo.update()
      |> case do
        {:ok, archived_channel} ->
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
  Unarchives a channel. Sets archived: false, clears archived_at and archived_by.
  Only owner/admin can do this.
  """
  def unarchive_channel(%Channel{} = channel, %User{} = user) do
    if is_owner_or_admin?(channel, user) do
      channel
      |> Channel.archive_changeset(%{
        archived: false,
        archived_at: nil,
        archived_by_id: nil
      })
      |> Repo.update()
      |> case do
        {:ok, unarchived_channel} ->
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
  Gets archived channels for a user, including member count.
  """
  def list_archived_channels(user) do
    list_user_channels(user, true)
    |> Enum.filter(fn {channel, _count} -> channel.archived end)
  end

  @doc """
  Gets active (non-archived) channels for a user, including member count.
  """
  def list_active_channels(user) do
    list_user_channels(user, false)
  end

  @doc """
  Checks if a channel is archived.
  """
  def archived?(channel) do
    channel.archived || false
  end

  @doc """
  Gets a channel with its archived_by user preloaded.
  """
  def get_channel_with_archive_info(id) do
    Repo.get(Channel, id)
    |> Repo.preload([:archived_by])
  end

  @doc """
  Gets a channel by ID.
  """
  def get_channel!(id), do: Repo.get!(Channel, id)

  @doc """
  Gets a channel by slug.
  """
    def get_channel_by_slug(slug) do
    Repo.get_by(Channel, slug: slug)
  end

  def get_channel_by_slug(nil), do: nil
  def get_channel_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Channel, slug: slug)
  end

  @doc """
  Gets a channel by ID or slug.
  """
  def get_channel_by_id_or_slug(id_or_slug) do
    case Integer.parse(id_or_slug) do
      {id, ""} -> get_channel!(id)  # It's an ID
      :error -> get_channel_by_slug(id_or_slug)  # It's a slug
    end
  end

  defp ensure_unique_slug_in_attrs(attrs) do
    case Map.get(attrs, :slug) do
      nil -> attrs  # Let the schema generate it
      slug -> Map.put(attrs, :slug, find_unique_slug(slug))
    end
  end

  # Helper to find a unique slug
  defp find_unique_slug(base_slug, counter \\ 0) do
    slug = if counter == 0, do: base_slug, else: "#{base_slug}-#{counter}"

    case Repo.get_by(Channel, slug: slug) do
      nil -> slug
      _ -> find_unique_slug(base_slug, counter + 1)
    end
  end

  # Retry channel creation with unique slug
  defp retry_with_unique_slug(changeset, attrs, user, max_retries \\ 5, attempt \\ 1) do
    if attempt > max_retries do
      {:error, changeset}
    else
      # Generate a new unique slug
      base_slug = slugify(attrs[:name] || "channel")
      unique_slug = find_unique_slug(base_slug)

      attrs_with_unique_slug = Map.put(attrs, :slug, unique_slug)

      %Channel{}
      |> Channel.changeset(attrs_with_unique_slug)
      |> Repo.insert()
      |> case do
        {:ok, channel} ->
          create_membership(%{
            channel_id: channel.id,
            user_id: user.id,
            role: "admin",
            last_activity_at: DateTime.utc_now()
          })
          Phoenix.PubSub.broadcast(Frestyl.PubSub, "channels", {:channel_created, channel})
          {:ok, channel}
        {:error, %Ecto.Changeset{errors: [slug: {"has already been taken", _}]} = new_changeset} ->
          retry_with_unique_slug(new_changeset, attrs, user, max_retries, attempt + 1)
        error -> error
      end
    end
  end

  def find_popular_channels_by_genre(genre, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    # Query channels tagged with specific genre, ordered by activity/member count
    Channel
    |> where([c], fragment("? @> ?", c.metadata, ^%{"genres" => [genre]}))
    |> where([c], c.visibility in ["public", "unlisted"])
    |> order_by([c], desc: c.member_count)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_popular_channels(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    Channel
    |> where([c], c.visibility == "public")
    |> where([c],
      is_nil(c.metadata) or
      not fragment("? @> ?", c.metadata, ^%{"is_official" => true})
    ) # Handle NULL metadata properly
    |> order_by([c], desc: c.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def ensure_user_in_frestyl_official(user_id) do
    case get_channel_by_slug("frestyl-official") do
      nil -> {:error, "Frestyl Official channel not found"}
      channel ->
        if user_member?(user_id, channel.id) do
          {:ok, :already_member}
        else
          join_channel(channel.id, user_id)
        end
    end
  end

  # Helper function for slug generation (same as in schema)
  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  @doc """
  Creates a channel with automatic slug generation and conflict resolution.
  """
  def create_channel(attrs \\ %{}, %User{} = user) do
    attrs_with_owner = Map.put(attrs, :owner_id, user.id)

    # Handle slug conflicts by trying different variations
    attrs_with_slug = ensure_unique_slug_in_attrs(attrs_with_owner)

    %Channel{}
    |> Channel.changeset(attrs_with_slug)
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
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "channels",
          {:channel_created, channel}
        )
        {:ok, channel}
      {:error, %Ecto.Changeset{errors: [slug: {"has already been taken", _}]} = changeset} ->
        # If slug conflict, try with a suffix
        retry_with_unique_slug(changeset, attrs_with_owner, user)
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
  Permanently deletes a channel.
  Only channel owners and admins can do this.
  """
  def permanently_delete_channel(%Channel{} = channel, %User{} = user) do
    if is_owner_or_admin?(channel, user) do
      Repo.delete(channel)
      |> case do
        {:ok, deleted_channel} ->
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
  Gets a channel with given ID and optional preloads.
  """
  def get_channel(id) do
    Repo.get(Channel, id)
  end

  def get_channel(id, preloads) when is_list(preloads) do
    Repo.get(Channel, id)
    |> Repo.preload(preloads)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking channel changes.
  """
  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.changeset(channel, attrs)
  end

  ## Message functions

  @doc """
  Creates a new message in a channel.
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> maybe_preload_message_associations()
    |> broadcast_message_change(:message_created)
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

  @doc """
  Lists messages for a channel with optional limit.
  """
  def list_messages(channel_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Message
    |> where([m], m.channel_id == ^channel_id) # Should be channel_id, not room_id for consistency
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  # Helper to preload associations for messages
  defp maybe_preload_message_associations({:ok, message}) do
    {:ok, Repo.preload(message, [:user, :channel])}
  end
  defp maybe_preload_message_associations(error), do: error

  # Helper function to broadcast message changes
  defp broadcast_message_change({:ok, message}, event) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{message.channel_id}",
      {event, message}
    )
    {:ok, message}
  end
  defp broadcast_message_change(error, _event), do: error

  ## Channel membership functions

  @doc """
  Checks if a user is an owner or admin of a channel.
  """
  def is_owner_or_admin?(%Channel{} = channel, %User{} = user) do
    Repo.exists?(
      from cm in ChannelMembership,
        where: cm.channel_id == ^channel.id and
               cm.user_id == ^user.id and
               cm.role in ["admin", "owner"] # Assuming 'owner' is a valid role
    ) || (channel.owner_id == user.id) # Also check if the user is the channel's owner (user_id field)
  end

  @doc """
  Checks if a user is a member of a channel.
  """
  def user_member?(%User{} = user, %Channel{} = channel) do
    Repo.exists?(
      from m in ChannelMembership,
      where: m.user_id == ^user.id and m.channel_id == ^channel.id
    )
  end

  # Overload for IDs
  def user_member?(user_id, channel_id) do
    Repo.exists?(
      from m in ChannelMembership,
      where: m.user_id == ^user_id and m.channel_id == ^channel_id
    )
  end

  @doc """
  Checks if a user can edit a channel.
  """
  def can_edit_channel?(%Channel{} = channel, %User{} = user) do
    Repo.exists?(
      from m in ChannelMembership,
      where: m.channel_id == ^channel.id and m.user_id == ^user.id and m.role in ["admin", "moderator", "owner"]
    )
  end

  @doc """
  Checks if user can send messages in a channel.
  """
  def can_send_messages?(%User{} = user, %Channel{} = channel) do
    # By default, all members can send messages
    user_member?(user, channel)
  end

  @doc """
  Invites a user to a channel by email.
  """
  def invite_to_channel(inviter_id, channel_id, email) do
    channel = get_channel(channel_id)
    if is_nil(channel), do: {:error, "Channel not found"}, else: :ok

    user = Accounts.get_user_by_email(email)

    if user && user_member?(user.id, channel_id) do # Use ID overloaded user_member?
      {:error, "User is already a member of this channel"}
    else
      token = generate_random_token()
      expires_at = DateTime.utc_now() |> DateTime.add(7, :day)

      %ChannelInvitation{}
      |> ChannelInvitation.changeset(%{
        channel_id: channel_id,
        inviter_id: inviter_id,
        email: email,
        user_id: user && user.id,
        token: token,
        status: :pending,
        expires_at: expires_at
      })
      |> Repo.insert()
      |> case do
        {:ok, invitation} ->
          if user do
            Notifications.send_channel_invitation_email(user, invitation)
          else
            Notifications.send_channel_invitation_email_to_new_user(email, invitation)
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

  @doc """
  Accepts a channel invitation by token.
  """
  def accept_invitation(token) do
    invitation = Repo.get_by(ChannelInvitation, token: token)

    cond do
      is_nil(invitation) ->
        {:error, "Invalid invitation"}
      DateTime.compare(invitation.expires_at, DateTime.utc_now()) == :lt ->
        {:error, "This invitation has expired"}
      invitation.status != :pending -> # Use atom :pending
        {:error, "This invitation has already been #{Atom.to_string(invitation.status)}"} # Convert atom to string for message
      true ->
        user = if invitation.user_id, do: Accounts.get_user(invitation.user_id), else: nil # Use Accounts.get_user

        case user do
          nil -> {:error, "User registration required or user not found."} # Handle user not found for existing user invitations
          _ ->
            channel = Repo.get(Channel, invitation.channel_id)

            case create_membership(%{
              channel_id: channel.id,
              user_id: user.id,
              role: "member",
              status: "active",
              last_activity_at: DateTime.utc_now()
            }) do
              {:ok, _} ->
                invitation
                |> ChannelInvitation.changeset(%{status: :accepted}) # Use atom :accepted
                |> Repo.update()
                {:ok, %{channel: channel, user: user}}
              error -> error
            end
        end
    end
  end

  @doc """
  Gets or creates a personal workspace for a user.
  Each user gets one personal workspace initially (tier-based limits apply later).
  """
  def get_or_create_personal_workspace(user) do
    case get_user_personal_workspace(user.id) do
      nil -> create_personal_workspace(user)
      workspace -> {:ok, workspace}
    end
  end

  @doc """
  Gets the user's existing personal workspace
  """
  defp get_user_personal_workspace(user_id) do
    from(c in Channel,
      where: c.owner_id == ^user_id and
            fragment("?->>'is_personal_workspace' = 'true'", c.metadata),
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Creates a new personal workspace for the user
  """
  defp create_personal_workspace(user) do
    user_tier = Frestyl.Features.TierManager.get_user_tier(user)

    workspace_params = %{
      name: "#{user.username}'s Personal Workspace",
      description: "Private creative workspace for personal projects and story development",
      slug: "#{user.username}-personal-#{System.unique_integer([:positive])}",
      channel_type: :general,  # Use valid enum value
      visibility: "private",
      metadata: %{
        is_personal_workspace: true,
        workspace_type: "personal_creative",
        tier: user_tier
      }
    }

    case create_channel(workspace_params, user) do
      {:ok, workspace} -> {:ok, workspace}
      error -> error
    end
  end

  @doc """
  Gets user's default channel (fallback for missing function)
  """
  def get_user_default_channel(user_id) do
    # Try to get personal workspace first
    case get_user_personal_workspace(user_id) do
      nil ->
        # Fall back to any channel owned by user
        from(c in Channel, where: c.owner_id == ^user_id, limit: 1)
        |> Repo.one()
      workspace -> workspace
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
  def get_channel_membership(%User{} = user, %Channel{} = channel) do
    Repo.one(
      from m in ChannelMembership,
      where: m.user_id == ^user.id and m.channel_id == ^channel.id
    )
  end

  # Overload for IDs
  def get_channel_membership(user_id, channel_id) do
    Repo.one(
      from m in ChannelMembership,
      where: m.user_id == ^user_id and m.channel_id == ^channel_id
    )
  end

  @doc """
  Lists members of a channel with their user info.
  """
  def list_channel_members(channel_id) do
    Repo.all(
      from m in ChannelMembership,
      where: m.channel_id == ^channel_id,
      preload: [:user], # Preload :user directly if m.user is defined
      order_by: [desc: m.inserted_at]
    )
  end

  @doc """
  Updates a user's last activity time in a channel.
  """
  def update_member_activity(user_id, channel_id) do
    membership = get_channel_membership(user_id, channel_id) # Use new helper

    if membership do
      membership
      |> ChannelMembership.changeset(%{last_activity_at: DateTime.utc_now()})
      |> Repo.update()
    else
      {:error, "Membership not found"}
    end
  end

  @doc """
  Checks if a user is blocked from a channel.
  """
  def user_blocked?(channel_id, user_id) do
    Repo.exists?(from b in BlockedUser,
      where: b.channel_id == ^channel_id and b.user_id == ^user_id and
            (is_nil(b.expires_at) or b.expires_at > ^DateTime.utc_now())
    )
  end

  @doc """
  Checks if a user is an admin of a channel (using direct query).
  """
  def is_admin?(channel_id, user_id) do
    Repo.exists?(
      from m in ChannelMembership,
      where: m.channel_id == ^channel_id and m.user_id == ^user_id and m.role in ["admin", "owner"]
    )
  end

  @doc """
  Gets a member's role in a channel.
  """
  def get_member_role(channel_id, user_id) do
    query = from m in ChannelMembership,
      where: m.channel_id == ^channel_id and m.user_id == ^user_id,
      select: m.role

    Repo.one(query) || "guest"
  end

  @doc """
  Joins a channel using IDs.
  """
  def join_channel(channel_id, user_id) do
    create_membership(%{
      channel_id: channel_id,
      user_id: user_id,
      role: "member",
      status: "active",
      last_activity_at: DateTime.utc_now()
    })
  end

  @doc """
  Leaves a channel using IDs.
  """
  def leave_channel(channel_id, user_id) do
    membership = get_channel_membership(user_id, channel_id) # Use new helper

    if membership do
      Repo.delete(membership)
    else
      {:error, "Membership not found"}
    end
  end

  @doc """
  Get channel member with preloaded user.
  """
  def get_channel_member(channel_id, user_id) do
    Repo.one(
      from m in ChannelMembership,
      where: m.channel_id == ^channel_id and m.user_id == ^user_id,
      preload: [:user]
    )
  end

  @doc """
  Updates a member's role directly using IDs.
  """
  def update_member_role(channel_id, user_id, role) when role in ["admin", "moderator", "member"] do
    membership = get_channel_member(channel_id, user_id)

    if membership do
      membership
      |> ChannelMembership.changeset(%{role: role})
      |> Repo.update()
    else
      {:error, "Membership not found"}
    end
  end

  @doc """
  Removes a member from a channel.
  """
  def remove_member(channel_id, user_id) do
    membership = get_channel_member(channel_id, user_id)

    if membership do
      Repo.delete(membership)
    else
      {:error, "Membership not found"}
    end
  end

  @doc """
  Blocks a user by ID or email with a reason and duration.
  """
  def block_user(channel_id, email_or_id, attrs \\ %{}) do
    channel = get_channel(channel_id)
    if is_nil(channel), do: {:error, "Channel not found"}, else: :ok

    user = case email_or_id do
      email when is_binary(email) -> Accounts.get_user_by_email(email)
      id when is_integer(id) -> Accounts.get_user(id)
    end

    # Determine blocked_by_user_id (Assuming current_user context is available or passed)
    # For now, using a placeholder, you'll need to pass the blocking user.
    blocked_by_user_id = if attrs[:blocked_by_user_id], do: attrs[:blocked_by_user_id], else: (Accounts.get_system_user() && Accounts.get_system_user().id) # Placeholder, fix this!

    attrs = Map.take(attrs, [:reason, :duration])

    # Convert duration string to actual expiration date
    attrs = case attrs[:duration] do
      "permanent" -> Map.delete(attrs, :duration) # No expires_at for permanent
      "1d" -> Map.put(attrs, :expires_at, DateTime.add(DateTime.utc_now(), 1, :day))
      "7d" -> Map.put(attrs, :expires_at, DateTime.add(DateTime.utc_now(), 7, :day))
      "30d" -> Map.put(attrs, :expires_at, DateTime.add(DateTime.utc_now(), 30, :day))
      "90d" -> Map.put(attrs, :expires_at, DateTime.add(DateTime.utc_now(), 90, :day))
      _ -> Map.delete(attrs, :duration) # Remove unknown duration, keep original expires_at if present
    end

    %BlockedUser{}
    |> BlockedUser.changeset(Map.merge(attrs, %{
      channel_id: channel.id,
      user_id: user && user.id, # Assign user_id if user found
      email: if(is_binary(email_or_id) && is_nil(user), do: email_or_id, else: nil), # Only assign email if user not found (blocking by email directly)
      blocked_by_user_id: blocked_by_user_id
    }))
    |> Repo.insert()
  end

  @doc """
  Unblocks a user or email.
  """
  def unblock_user(block_id) do
    block = Repo.get(BlockedUser, block_id)

    if block do
      Repo.delete(block)
    else
      {:error, "Block not found"}
    end
  end

  @doc """
  Subscribe to a channel's PubSub topic.
  """
  def subscribe(channel_id) do
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel_id}")
  end

  @doc """
  Blocks an email address from a channel.
  """
  def block_email(%Channel{} = channel, email, %User{} = blocked_by, attrs \\ %{}) do
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
  def unblock_email(%Channel{} = channel, email) do
    Repo.get_by(BlockedUser, channel_id: channel.id, email: email)
    |> case do
      nil -> {:error, "Email is not blocked"}
      blocked -> Repo.delete(blocked)
    end
  end

  @doc """
  Returns true if a user is blocked from a channel.
  """
  def is_blocked?(%Channel{} = channel, %User{} = user) do
    Repo.exists?(from b in BlockedUser,
      where: b.channel_id == ^channel.id and b.user_id == ^user.id and
            (is_nil(b.expires_at) or b.expires_at > ^DateTime.utc_now())
    )
  end

  @doc """
  Returns true if an email is blocked from a channel.
  """
  def is_email_blocked?(%Channel{} = channel, email) do
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

    field_name = String.to_atom("active_#{category}_media_id")
    attrs = %{field_name => media_item_id}

    channel
    |> Channel.media_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_channel} ->
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
  # Handle Channel struct
  def get_active_media(%Channel{} = channel) do
    # You might want to preload these in the initial channel fetch if performance is key
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
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "channels",
          {:channel_updated, updated_channel}
        )
        {:ok, updated_channel}
      error -> error
    end
  end

  ## Room functions (Moved and consolidated for clarity)

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
  Gets or creates a default room for a channel.
  """
  def get_or_create_default_room(channel_id) do
    case get_default_room(channel_id) do
      nil -> create_default_room_internal(channel_id) # Call internal helper
      room -> {:ok, room}
    end
  end

  # Internal helper for creating a default room to avoid duplication
  defp create_default_room_internal(channel_id) do
    channel = get_channel!(channel_id) # Ensure channel exists

    %Room{}
    |> Room.changeset(%{
      name: "General",
      channel_id: channel_id,
      is_default: true,
      description: "Default room for #{channel.name}"
    })
    |> Repo.insert()
  end

  # Removed duplicate `create_default_room` definitions

  ## Admin/Permissions Helpers (Consolidated)

  # Removed duplicate `is_last_admin?` as it was calling a non-existent `ChannelMember` schema

  @doc """
  Checks if a user is the last admin/owner of a channel.
  Assumes 'owner' role is managed via ChannelMembership.
  """
  def is_last_admin?(channel_id, user_id) do
    user_is_admin_or_owner = Repo.exists?(from m in ChannelMembership,
      where: m.channel_id == ^channel_id and m.user_id == ^user_id and m.role in ["admin", "owner"]
    )

    if user_is_admin_or_owner do
      admin_owner_count = Repo.one(from m in ChannelMembership,
        where: m.channel_id == ^channel_id and m.role in ["admin", "owner"],
        select: count(m.id)
      )
      admin_owner_count == 1
    else
      false
    end
  end

  ## Session and Broadcast functions (delegated to Frestyl.Sessions)

  @doc """
  Creates a new session.
  """
  def create_session(attrs), do: Sessions.create_session(attrs)

  @doc """
  Creates a new broadcast.
  """
  def create_broadcast(attrs), do: Sessions.create_broadcast(attrs)

  @doc """
  Gets a session by ID.
  """
  def get_session!(id), do: Sessions.get_session_with_details!(id)

  @doc """
  Gets a broadcast by ID.
  """
  def get_broadcast!(id), do: Sessions.get_session_with_details!(id) # Assuming broadcast is a type of session

  @doc """
  Starts a session.
  """
  def start_session(session), do: Sessions.update_session(session, %{status: "active", started_at: DateTime.utc_now()})

  @doc """
  Starts a broadcast.
  """
  def start_broadcast(broadcast), do: Sessions.start_broadcast(broadcast)

  @doc """
  Creates a changeset for session forms.
  """
  def change_session(session, attrs \\ %{})
  def change_session(nil, attrs) do
    Sessions.change_session(nil, attrs) # Delegate to Sessions context
  end
  def change_session(session, attrs) when is_map(session) do
    Sessions.change_session(session, attrs) # Delegate to Sessions context
  end

  @doc """
  Creates a changeset for broadcast forms.
  """
  def change_broadcast(broadcast, attrs \\ %{})
  def change_broadcast(nil, attrs) do
    Sessions.change_broadcast(nil, attrs) # Delegate to Sessions context
  end
  def change_broadcast(broadcast, attrs) when is_map(broadcast) do
    Sessions.change_broadcast(broadcast, attrs) # Delegate to Sessions context
  end

  ## Customization and Featured Content (retained as-is, assuming `Channel` schema supports these fields)

  @doc """
  Updates channel customization settings.
  """
  def update_channel_customization(%Channel{} = channel, attrs) do
    channel
    |> Channel.customization_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_channel} ->
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "channel:#{channel.id}",
          {:channel_customization_updated, updated_channel}
        )

        updated_channel = if updated_channel.auto_detect_type do
          detected_type = Channel.detect_channel_type(updated_channel.id) # Ensure this function exists in Channel schema
          if detected_type != updated_channel.channel_type do
            case update_channel(updated_channel, %{channel_type: detected_type}) do
              {:ok, channel_with_type} -> channel_with_type
              {:error, _} -> updated_channel
            end
          else
            updated_channel
          end
        else
          updated_channel
        end
        {:ok, updated_channel}
      error -> error
    end
  end

  @doc """
  Gets channel customization data for the frontend.
  """
  def get_channel_customization(%Channel{} = channel) do
    %{
      hero_image_url: channel.hero_image_url,
      color_scheme: channel.color_scheme || %{
        "primary" => "#8B5CF6",
        "secondary" => "#00D4FF",
        "accent" => "#FF0080"
      },
      tagline: channel.tagline,
      channel_type: channel.channel_type || "general",
      show_live_activity: channel.show_live_activity,
      enable_transparency_mode: channel.enable_transparency_mode,
      social_links: channel.social_links || %{},
      fundraising_enabled: channel.fundraising_enabled,
      fundraising_goal: channel.fundraising_goal,
      fundraising_description: channel.fundraising_description
    }
  end

  @doc """
  Updates featured content for a channel.
  """
  def update_featured_content(%Channel{} = channel, featured_items) when is_list(featured_items) do
    # Validate featured items structure - ensure `validate_featured_item/1` is defined elsewhere if needed
    # Or implement inline validation if simple. For now, assuming it exists.
    # validated_items = Enum.map(featured_items, &validate_featured_item/1)
    # if Enum.any?(validated_items, &is_nil/1) do
    #   {:error, "Invalid featured content format"}
    # else
    #   update_channel(channel, %{featured_content: validated_items})
    # end
    # For now, just update without explicit validation from `validate_featured_item/1`
    # You should implement `validate_featured_item/1` if this is crucial.
    update_channel(channel, %{featured_content: featured_items})
  end

  # Assuming `validate_featured_item/1` is defined in another module or needs to be added here.
  # defp validate_featured_item(item) do
  #   # Example: ensure item is a map with at least a :type and :id
  #   if is_map(item) and Map.has_key?(item, :type) and Map.has_key?(item, :id) do
  #     item
  #   else
  #     nil
  #   end
  # end

  # Removed the partial `Adds an item to featured content.` doc.
end
