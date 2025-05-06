defmodule Frestyl.Channels do
  @moduledoc """
  The Channels context.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo

  alias Frestyl.Channels.{Channel, ChannelMembership}
  alias Frestyl.Accounts.User

  ## Channel functions

  @doc """
  Returns the list of channels.
  """
  def list_channels do
    Channel
    |> Repo.all()
  end

  @doc """
  Returns the list of public channels.
  """
  def list_public_channels do
    Channel
    |> where([c], c.visibility == "public")
    |> Repo.all()
  end

  @doc """
  Searches public channels by name or description.
  """
  def search_public_channels(search_term) do
    term = "%#{search_term}%"

    Channel
    |> where([c], c.visibility == "public")
    |> where([c], ilike(c.name, ^term) or ilike(c.description, ^term))
    |> Repo.all()
  end

  @doc """
  Returns the list of channels for a user.
  """
  def list_user_channels(user) do
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
              member_count: fragment("(SELECT COUNT(*) FROM channel_memberships WHERE channel_id = ?)", c.id)
            }

    Repo.all(query)
  end

  @doc """
  Gets a single channel.
  """
  def get_channel!(id), do: Repo.get!(Channel, id)

  @doc """
  Creates a channel.
  """
  def create_channel(attrs \\ %{}, user) do
    %Channel{}
    |> Channel.changeset(attrs)
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

  @doc """
  Removes a user from a channel.
  """
  def leave_channel(user, channel) do
    membership = get_channel_membership(user, channel)

    if membership do
      Repo.delete(membership)
    else
      {:error, "User is not a member of this channel"}
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
  Returns the visibility options for channels.
  """
  def visibility_options do
    ~w(public private invite_only)
  end
end
