# lib/frestyl/channels/channel.ex
defmodule Frestyl.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Channels.ChannelMembership
  alias Frestyl.Chat.Message
  import Ecto.Query

  schema "channels" do
    field :name, :string
    field :description, :string
    field :visibility, :string, default: "public"
    field :icon_url, :string
    field :slug, :string
    field :category, :string
    field :owner_id, :id

    has_many :memberships, ChannelMembership
    has_many :messages, Message

    field :member_count, :integer, virtual: true

    field :branding_media_enabled, :boolean, default: true
    field :presentation_media_enabled, :boolean, default: true
    field :performance_media_enabled, :boolean, default: true
    field :archived, :boolean, default: false
    field :archived_at, :utc_datetime

    # Add WebRTC configuration
    field :webrtc_config, :map, default: %{
      "ice_servers" => [
        %{"urls" => "stun:stun.l.google.com:19302"}
      ],
      "max_quality" => "720p",
      "connection_limit" => 20
    }

    # Add storage configuration
    field :storage_bucket, :string
    field :storage_prefix, :string

    # Add active media references
    field :active_branding_media_id, :id
    field :active_presentation_media_id, :id
    field :active_performance_media_id, :id

    has_many :media_items, Frestyl.Media.MediaItem
    timestamps()
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :description, :visibility, :icon_url, :category, :owner_id]) # Add category
    |> validate_required([:name, :visibility, :owner_id])
    |> validate_length(:name, min: 2, max: 50)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:visibility, ["public", "private", "invite_only"])
    |> maybe_generate_slug()
  end

  @doc """
  Changeset for archiving/unarchiving channels
  """
  def archive_changeset(channel, attrs) do
    channel
    |> cast(attrs, [:archived, :archived_at])
    |> validate_required([:archived])
  end

  @doc """
  Changeset for media settings
  """
  def media_settings_changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :branding_media_enabled,
      :presentation_media_enabled,
      :performance_media_enabled,
      :webrtc_config,
      :storage_bucket,
      :storage_prefix
    ])
    |> validate_storage_config()
  end

  @doc """
  Changeset for updating active media
  """
  def media_changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :active_branding_media_id,
      :active_presentation_media_id,
      :active_performance_media_id
    ])
    |> validate_media_categories()
  end

  @doc """
  Validates that media categories are enabled when setting active media
  """
  defp validate_media_categories(changeset) do
    changeset
    |> validate_media_category(:active_branding_media_id, :branding_media_enabled)
    |> validate_media_category(:active_presentation_media_id, :presentation_media_enabled)
    |> validate_media_category(:active_performance_media_id, :performance_media_enabled)
  end

  defp validate_media_category(changeset, field, enabled_field) do
    if get_change(changeset, field) && get_field(changeset, enabled_field) == false do
      category = field
        |> Atom.to_string()
        |> String.replace("active_", "")
        |> String.replace("_media_id", "")

      add_error(changeset, field, "#{category} media is disabled")
    else
      changeset
    end
  end

  @doc """
  Determines if a user can view branding assets for a channel.
  Only admins, moderators, and the channel owner can view branding assets.
  """
  def can_view_branding_assets?(%__MODULE__{} = channel, user) do
    cond do
      user.role == "admin" -> true
      channel.owner_id == user.id -> true
      true ->
        # Check if user is a moderator for this channel
        case Frestyl.Repo.get_by(Frestyl.Channels.ChannelMembership,
                                user_id: user.id,
                                channel_id: channel.id,
                                role: "moderator") do
          nil -> false
          _ -> true
        end
    end
  end

  @doc """
  Validates S3 storage configuration
  """
  defp validate_storage_config(changeset) do
    s3_bucket = get_change(changeset, :storage_bucket)
    s3_prefix = get_change(changeset, :storage_prefix)

    cond do
      is_nil(s3_bucket) && is_nil(s3_prefix) ->
        # No changes to storage config
        changeset

      is_nil(s3_bucket) && !is_nil(s3_prefix) ->
        add_error(changeset, :storage_bucket, "must be provided if storage_prefix is set")

      !is_nil(s3_bucket) && is_nil(s3_prefix) ->
        # Generate a default prefix based on a timestamp and random string
        prefix = "channels/#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
        put_change(changeset, :storage_prefix, prefix)

      true ->
        changeset
    end
  end

  # In lib/frestyl/channels/channel.ex

  @doc """
  Determines if a user can view branding assets for a channel.
  Only admins, moderators, and the channel owner can view branding assets.
  """
  def can_view_branding_assets?(%__MODULE__{} = channel, user) do
    cond do
      # Channel owner can view
      channel.owner_id == user.id -> true

      # Admin users can view
      user.role == "admin" -> true

      # Moderators can view
      Frestyl.Repo.exists?(from m in Frestyl.Channels.ChannelMembership,
                            where: m.user_id == ^user.id and
                                  m.channel_id == ^channel.id and
                                  m.role == "moderator") -> true

      # Default: cannot view
      true -> false
    end
  end

  defp maybe_generate_slug(%Ecto.Changeset{valid?: true, changes: %{name: name}} = changeset) do
    if get_field(changeset, :slug) do
      changeset
    else
      slug = name
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9\s-]/, "")
        |> String.replace(~r/\s+/, "-")
        |> String.replace(~r/-+/, "-")
        |> String.trim_leading("-")
        |> String.trim_trailing("-")

      # Ensure uniqueness by adding a timestamp if needed
      slug = case Frestyl.Repo.get_by(__MODULE__, slug: slug) do
        nil -> slug
        _ -> "#{slug}-#{System.system_time(:second)}"
      end

      put_change(changeset, :slug, slug)
    end
  end

  defp maybe_generate_slug(changeset), do: changeset
end
