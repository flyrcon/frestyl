# lib/frestyl/admin/channel_management.ex
defmodule Frestyl.Admin.ChannelManagement do
  @moduledoc """
  Context for admin channel management, especially the Frestyl Official channel.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Channels.{Channel, ChannelMembership}
  alias Frestyl.Accounts.User
  alias Frestyl.Chat.Message

  @official_channel_slug "frestyl-official"
  @official_channel_name "Frestyl Official"

  # ============================================================================
  # FRESTYL OFFICIAL CHANNEL MANAGEMENT
  # ============================================================================

  def get_official_channel do
    Repo.get_by(Channel, slug: @official_channel_slug)
    |> case do
      nil -> nil
      channel ->
        channel
        |> Repo.preload([:creator, :members])
        |> add_channel_stats()
    end
  end

  def create_official_channel do
    # Get or create a system admin user for the official channel
    system_admin = get_or_create_system_admin()

    channel_attrs = %{
      name: @official_channel_name,
      slug: @official_channel_slug,
      description: "Official announcements, updates, and community highlights from the Frestyl team.",
      channel_type: "official",
      visibility: "public",
      is_official: true,
      is_featured: true,
      creator_id: system_admin.id,
      auto_join_all_users: true,  # Special flag for official channel
      settings: %{
        "allow_user_posts" => false,  # Only admins can post
        "allow_reactions" => true,
        "allow_file_uploads" => true,
        "moderation_level" => "strict"
      }
    }

    case Channel.changeset(%Channel{}, channel_attrs) |> Repo.insert() do
      {:ok, channel} ->
        # Add all existing users to the official channel
        add_all_users_to_official_channel(channel)

        # Set up initial welcome message
        create_welcome_message(channel, system_admin)

        {:ok, channel |> add_channel_stats()}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_official_channel(attrs) do
    case get_official_channel() do
      nil -> {:error, "Official channel not found"}
      channel ->
        channel
        |> Channel.admin_changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_channel} -> {:ok, updated_channel |> add_channel_stats()}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def broadcast_official_message(message_content, admin_user) do
    case get_official_channel() do
      nil -> {:error, "Official channel not found"}
      channel ->
        message_attrs = %{
          content: message_content,
          channel_id: channel.id,
          user_id: admin_user.id,
          message_type: "announcement",
          metadata: %{
            "is_official" => true,
            "admin_broadcast" => true,
            "timestamp" => DateTime.utc_now()
          }
        }

        case Message.changeset(%Message{}, message_attrs) |> Repo.insert() do
          {:ok, message} ->
            # Broadcast to all channel members via PubSub
            Phoenix.PubSub.broadcast(
              Frestyl.PubSub,
              "channel:#{channel.id}",
              {:new_message, message |> Repo.preload(:user)}
            )

            # Send push notifications to all users
            send_official_notification_to_all_users(message_content)

            {:ok, message}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def ensure_user_in_official_channel(user_id) do
    case get_official_channel() do
      nil -> {:error, "Official channel not found"}
      channel ->
        # Check if user is already a member
        existing_membership =
          from(cm in ChannelMembership,
            where: cm.channel_id == ^channel.id and cm.user_id == ^user_id
          )
          |> Repo.one()

        case existing_membership do
          nil ->
            # Add user to official channel
            membership_attrs = %{
              channel_id: channel.id,
              user_id: user_id,
              role: "member",
              status: "active",
              joined_at: DateTime.utc_now() |> DateTime.truncate(:second),
              auto_joined: true
            }

            %ChannelMembership{}
            |> ChannelMembership.changeset(membership_attrs)
            |> Repo.insert()

          membership ->
            {:ok, membership}
        end
    end
  end

  # ============================================================================
  # CHANNEL OVERSIGHT AND MODERATION
  # ============================================================================

  def list_public_channels(limit \\ 50) do
    from(c in Channel,
      where: c.visibility == "public",
      order_by: [desc: c.member_count, desc: c.inserted_at],
      limit: ^limit,
      preload: [:creator]
    )
    |> Repo.all()
    |> Enum.map(&add_channel_stats/1)
  end

  def get_trending_channels(limit \\ 10) do
    # Get channels with high activity in the last 24 hours
    yesterday = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)

    from(c in Channel,
      left_join: m in Message, on: c.id == m.channel_id and m.inserted_at >= ^yesterday,
      where: c.visibility == "public" and c.slug != ^@official_channel_slug,
      group_by: c.id,
      order_by: [desc: count(m.id), desc: c.member_count],
      limit: ^limit,
      preload: [:creator]
    )
    |> Repo.all()
    |> Enum.map(&add_channel_stats/1)
  end

  def get_reported_channels(limit \\ 20) do
    # This would integrate with a reporting system
    # For now, return channels that might need attention
    from(c in Channel,
      where: not is_nil(c.reported_at) or c.status == "under_review",
      order_by: [desc: c.reported_at],
      limit: ^limit,
      preload: [:creator]
    )
    |> Repo.all()
    |> Enum.map(&add_channel_stats/1)
  end

  def moderate_channel(channel_id, action, admin_user_id, reason \\ nil) do
    channel = Repo.get!(Channel, channel_id)

    case action do
      "feature" ->
        update_channel_status(channel, %{is_featured: true}, admin_user_id, reason)

      "unfeature" ->
        update_channel_status(channel, %{is_featured: false}, admin_user_id, reason)

      "suspend" ->
        update_channel_status(channel, %{status: "suspended", suspended_at: DateTime.utc_now()}, admin_user_id, reason)

      "restore" ->
        update_channel_status(channel, %{status: "active", suspended_at: nil}, admin_user_id, reason)

      "delete" ->
        soft_delete_channel(channel, admin_user_id, reason)

      _ ->
        {:error, "Invalid moderation action"}
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp get_or_create_system_admin do
    case Repo.get_by(User, email: "system@frestyl.com") do
      nil ->
        # Create system admin user
        user_attrs = %{
          email: "system@frestyl.com",
          name: "Frestyl System",
          is_system_user: true,
          password: :crypto.strong_rand_bytes(32) |> Base.encode64(),
          confirmed_at: DateTime.utc_now()
        }

        case User.registration_changeset(%User{}, user_attrs) |> Repo.insert() do
          {:ok, user} -> user
          {:error, _} ->
            # If creation fails, try to get existing user again
            Repo.get_by(User, email: "system@frestyl.com")
        end

      user -> user
    end
  end

  defp add_all_users_to_official_channel(channel) do
    # Get all active users
    user_ids =
      from(u in User,
        where: is_nil(u.status) or u.status == "active",
        select: u.id
      )
      |> Repo.all()

    # Batch insert memberships
    memberships =
      Enum.map(user_ids, fn user_id ->
        %{
          channel_id: channel.id,
          user_id: user_id,
          role: "member",
          status: "active",
          joined_at: DateTime.utc_now() |> DateTime.truncate(:second),
          auto_joined: true,
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
      end)

    Repo.insert_all(ChannelMembership, memberships)
  end

  defp create_welcome_message(channel, system_admin) do
    welcome_content = """
    🎉 Welcome to Frestyl Official!

    This is your central hub for:
    • Platform updates and new features
    • Community highlights and showcases
    • Tips and best practices
    • Important announcements

    We're excited to have you as part of the Frestyl community! 🚀
    """

    message_attrs = %{
      content: welcome_content,
      channel_id: channel.id,
      user_id: system_admin.id,
      message_type: "system",
      metadata: %{
        "is_welcome_message" => true,
        "is_official" => true
      }
    }

    Message.changeset(%Message{}, message_attrs) |> Repo.insert()
  end

  defp add_channel_stats(channel) do
    # Add real-time stats to channel
    stats = %{
      member_count: get_member_count(channel.id),
      messages_today: get_messages_today_count(channel.id),
      active_now: get_active_members_count(channel.id),
      last_activity: get_last_activity(channel.id)
    }

    Map.merge(channel, stats)
  end

  defp get_member_count(channel_id) do
    from(cm in ChannelMembership,
      where: cm.channel_id == ^channel_id and cm.status == "active"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_messages_today_count(channel_id) do
    today = DateTime.utc_now() |> DateTime.to_date()

    from(m in Message,
      where: m.channel_id == ^channel_id and fragment("date(?)", m.inserted_at) == ^today
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_active_members_count(channel_id) do
    # Members active in the last hour
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)

    from(cm in ChannelMembership,
      where: cm.channel_id == ^channel_id
      and cm.status == "active"
      and cm.last_activity_at >= ^one_hour_ago
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_last_activity(channel_id) do
    from(m in Message,
      where: m.channel_id == ^channel_id,
      order_by: [desc: m.inserted_at],
      limit: 1,
      select: m.inserted_at
    )
    |> Repo.one()
  end

  defp update_channel_status(channel, attrs, admin_user_id, reason) do
    admin_attrs = Map.merge(attrs, %{
      moderated_by_admin_id: admin_user_id,
      moderation_reason: reason,
      moderated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })

    channel
    |> Channel.admin_changeset(admin_attrs)
    |> Repo.update()
  end

  defp soft_delete_channel(channel, admin_user_id, reason) do
    attrs = %{
      status: "deleted",
      deleted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      deleted_by_admin_id: admin_user_id,
      deletion_reason: reason
    }

    update_channel_status(channel, attrs, admin_user_id, reason)
  end

  defp send_official_notification_to_all_users(message_content) do
    # This would integrate with your notification system
    # For now, just log it
    require Logger
    Logger.info("Official notification sent to all users: #{String.slice(message_content, 0, 100)}...")
  end
end
