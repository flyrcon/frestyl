defmodule Frestyl.Channels do
  @moduledoc """
  The Channels context. Manages everything related to channels, rooms, and memberships.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Channels.{Channel, Membership, Room}
  alias Frestyl.Accounts.User
  alias Frestyl.Channels.Message
  alias Frestyl.Channels.{Role, Permission}
  alias Frestyl.Channels.FileAttachment
  alias Frestyl.FileStorage
  alias Frestyl.Channels.Invitation

  # Channel functions

  @doc """
  Returns the list of channels.
  Optional filters for public/private and by category.
  """
  def list_channels(filters \\ []) do
    query = Channel

    query = if Keyword.has_key?(filters, :public_only) && filters[:public_only] do
      from c in query, where: c.is_public == true
    else
      query
    end

    query = if Keyword.has_key?(filters, :category) do
      from c in query, where: c.category == ^filters[:category]
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  Gets a single channel by ID.
  """
  def get_channel!(id), do: Repo.get!(Channel, id)

  @doc """
  Gets a single channel by slug.
  """
  def get_channel_by_slug(slug) do
    Repo.get_by(Channel, slug: slug)
  end

  @doc """
  Creates a channel. Automatically adds the owner as a member with "owner" role.
  """
  def create_channel(%User{} = user, attrs \\ %{}) do
    attrs = Map.put(attrs, "owner_id", user.id)

    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, channel} ->
        # Add the creator as an owner
        %Membership{}
        |> Membership.changeset(%{
          user_id: user.id,
          channel_id: channel.id,
          role: "owner"
        })
        |> Repo.insert()

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
  end

  @doc """
  Deletes a channel.
  """
  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking channel changes.
  """
  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.changeset(channel, attrs)
  end

  # Room functions

  @doc """
  Returns the list of rooms for a specific channel.
  """
  def list_rooms(channel_id) do
    Room
    |> where([r], r.channel_id == ^channel_id)
    |> Repo.all()
  end

  @doc """
  Gets a single room by ID.
  """
  def get_room!(id), do: Repo.get!(Room, id)

  @doc """
  Gets a room by slug within a specific channel.
  """
  def get_room_by_slug(channel_id, slug) do
    Repo.get_by(Room, channel_id: channel_id, slug: slug)
  end

  @doc """
  Creates a room in a channel.
  """
  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a room.
  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a room.
  """
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.
  """
  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  # Invitation functions
def list_channel_invitations(channel_id) do
  Invitation
  |> where([i], i.channel_id == ^channel_id)
  |> order_by([i], desc: i.inserted_at)
  |> Repo.all()
end

def get_invitation_by_token(token) do
  Invitation
  |> where([i], i.token == ^token)
  |> Repo.one()
end

def create_invitation(%Channel{} = channel, email, role_name, expires_in_days \\ 7) do
  # Generate a secure random token
  token = Phoenix.Token.sign(FrestylWeb.Endpoint, "channel_invitation", %{
    channel_id: channel.id,
    email: email,
    timestamp: System.system_time(:second)
  })

  # Get the role
  role = get_role_by_name(role_name)

  # Calculate expiration time
  expires_at = DateTime.utc_now() |> DateTime.add(expires_in_days * 24 * 60 * 60, :second)

  # Create the invitation
  %Invitation{}
  |> Invitation.changeset(%{
    email: email,
    token: token,
    status: "pending",
    expires_at: expires_at,
    channel_id: channel.id,
    role_id: role.id
  })
  |> Repo.insert()
end

def accept_invitation(token) do
  case get_invitation_by_token(token) do
    nil ->
      {:error, :not_found}

    invitation ->
      # Check if invitation is still valid
      now = DateTime.utc_now()
      cond do
        DateTime.compare(now, invitation.expires_at) == :gt ->
          # Invitation expired
          invitation
          |> Invitation.changeset(%{status: "expired"})
          |> Repo.update()

          {:error, :expired}

        invitation.status != "pending" ->
          {:error, :already_processed}

        true ->
          # Valid invitation, update status
          {:ok, updated_invitation} = invitation
                                     |> Invitation.changeset(%{status: "accepted"})
                                     |> Repo.update()

          # Return the updated invitation
          {:ok, updated_invitation}
      end
  end
end

def get_invitation!(id), do: Repo.get!(Invitation, id)

def cancel_invitation(%Invitation{} = invitation) do
  invitation
  |> Invitation.changeset(%{status: "cancelled"})
  |> Repo.update()
end

def delete_invitation(%Invitation{} = invitation) do
  Repo.delete(invitation)
end

  # Membership functions

  @doc """
  Lists all members of a channel.
  """
  def list_channel_members(channel_id) do
    Membership
    |> where([m], m.channel_id == ^channel_id)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Removes a user from a channel.
  """
  def remove_channel_member(%Channel{} = channel, %User{} = user) do
    Membership
    |> Repo.get_by(channel_id: channel.id, user_id: user.id)
    |> case do
      nil -> {:error, :not_found}
      membership -> Repo.delete(membership)
    end
  end

  @doc """
  Checks if a user is a member of a channel.
  """
  def is_member?(%Channel{} = channel, %User{} = user) do
    Repo.exists?(from m in Membership,
      where: m.channel_id == ^channel.id and m.user_id == ^user.id)
  end

  @doc """
  Gets a user's role in a channel.
  """
  def get_member_role(%Channel{} = channel, %User{} = user) do
    Membership
    |> Repo.get_by(channel_id: channel.id, user_id: user.id)
    |> case do
      nil -> nil
      membership -> membership.role
    end
  end

  # Message functions
def list_room_messages(room_id, limit \\ 50) do
  Message
  |> where([m], m.room_id == ^room_id)
  |> order_by([m], desc: m.inserted_at)
  |> limit(^limit)
  |> Repo.all()
  |> Repo.preload(:user)
  |> Enum.reverse()  # Return in chronological order
end

def create_message(attrs) do
  %Message{}
  |> Message.changeset(attrs)
  |> Repo.insert()
end

def get_message!(id), do: Repo.get!(Message, id)

def delete_message(%Message{} = message) do
  Repo.delete(message)
end

def create_message_with_attachment(attrs, file_params) do
  # First, try to store the file if one is provided
  attachment_url = case file_params do
    %{data: data, filename: filename} when not is_nil(data) and not is_nil(filename) ->
      case Frestyl.FileStorage.store_file(data, filename) do
        {:ok, url} -> url
        {:error, _} -> nil
      end
    _ -> nil
  end

  # Then create the message with the attachment URL
  %Message{}
  |> Message.changeset(Map.put(attrs, "attachment_url", attachment_url))
  |> Repo.insert()
end

alias Frestyl.Channels.FileAttachment
alias Frestyl.FileStorage

# File attachment functions
def list_channel_files(channel_id) do
  FileAttachment
  |> where([f], f.channel_id == ^channel_id)
  |> order_by([f], desc: f.inserted_at)
  |> Repo.all()
  |> Repo.preload(:user)
end

def list_room_files(room_id) do
  FileAttachment
  |> where([f], f.room_id == ^room_id)
  |> order_by([f], desc: f.inserted_at)
  |> Repo.all()
  |> Repo.preload(:user)
end

def get_file_attachment!(id), do: Repo.get!(FileAttachment, id)

def create_file_attachment(attrs, %{data: file_data, filename: filename}) do
  with true <- FileStorage.allowed_extension?(filename),
       {:ok, binary_data} <- Base.decode64(file_data),
       :ok <- FileStorage.validate_file_size(binary_data),
       {:ok, file_url} <- FileStorage.store_file(file_data, filename) do

    file_size = byte_size(binary_data)
    mime_type = FileStorage.get_mime_type(filename)

    %FileAttachment{}
    |> FileAttachment.changeset(Map.merge(attrs, %{
      "filename" => filename,
      "file_url" => file_url,
      "file_size" => file_size,
      "mime_type" => mime_type
    }))
    |> Repo.insert()
  else
    false -> {:error, "File type not allowed"}
    {:error, reason} -> {:error, reason}
    _ -> {:error, "Failed to process file"}
  end
end

def delete_file_attachment(%FileAttachment{} = file) do
  # First delete the physical file
  case FileStorage.delete_file(file.file_url) do
    {:ok, _} ->
      # Then delete the record
      Repo.delete(file)

    {:error, reason} ->
      {:error, reason}
  end
end

def human_readable_file_size(bytes) when is_integer(bytes) do
  cond do
    bytes >= 1_000_000 ->
      mb = bytes / 1_000_000
      "#{Float.round(mb, 2)} MB"

    bytes >= 1_000 ->
      kb = bytes / 1_000
      "#{Float.round(kb, 2)} KB"

    true ->
      "#{bytes} bytes"
  end
end

# Role and Permission functions
def list_roles do
  Repo.all(Role)
end

def get_role!(id), do: Repo.get!(Role, id)

def get_role_by_name(name) do
  Repo.get_by(Role, name: name)
end

def list_permissions do
  Repo.all(Permission)
end

def get_role_permissions(role_id) do
  Role
  |> Repo.get!(role_id)
  |> Repo.preload(:permissions)
  |> Map.get(:permissions)
end

def has_permission?(user, channel, permission_name) do
  membership = Repo.get_by(Membership, user_id: user.id, channel_id: channel.id)

  if membership do
    # Check specific permission overrides
    case permission_name do
      "send_messages" -> membership.can_send_messages
      "manage_members" -> membership.can_manage_members
      "create_room" -> membership.can_create_rooms
      _ -> false
    end
    ||
    # Check role-based permissions
    role_has_permission?(membership.role_id, permission_name)
  else
    false
  end
end

defp role_has_permission?(role_id, permission_name) do
  query = from p in Permission,
    join: rp in "role_permissions", on: rp.permission_id == p.id,
    where: rp.role_id == ^role_id and p.name == ^permission_name

  Repo.exists?(query)
end

# Modified function to add a member with a role
def add_channel_member(%Channel{} = channel, %User{} = user, role_name \\ "member") do
  role = get_role_by_name(role_name)

  %Membership{}
  |> Membership.changeset(%{
    user_id: user.id,
    channel_id: channel.id,
    role_id: role.id
  })
  |> Repo.insert()
end

# Update a member's role
def update_member_role(%Membership{} = membership, role_name) do
  role = get_role_by_name(role_name)

  membership
  |> Membership.changeset(%{role_id: role.id})
  |> Repo.update()
end

  # Channel categorization with AI

  @doc """
  Suggests categories for a channel based on its name and description.
  This would integrate with an AI service.
  """
  def suggest_categories(name, description) do
    Frestyl.Channels.AIClient.suggest_categories(name, description)
  end
end
