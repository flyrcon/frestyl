# lib/frestyl/notifications.ex

defmodule Frestyl.Notifications do
  @moduledoc """
  Context module for managing notifications with chat integration
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Notifications.Notification
  alias Phoenix.PubSub

  @doc """
  Creates a new notification
  """
  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, notification} ->
        # Broadcast to user
        PubSub.broadcast(Frestyl.PubSub, "user:#{notification.user_id}:notifications",
          {:new_notification, notification})
        {:ok, notification}

      error -> error
    end
  end

  @doc """
  Creates a chat-related notification
  """
  def create_chat_notification(user_id, type, attrs) do
    notification_attrs = Map.merge(attrs, %{
      user_id: user_id,
      type: to_string(type),
      category: "chat"
    })

    create_notification(notification_attrs)
  end

  @doc """
  Creates notifications for new messages
  """
  def notify_new_message(conversation, message, sender) do
    # Get all participants except the sender
    participants = conversation.participants
    |> Enum.reject(& &1.user_id == sender.id)

    # Create notifications for each participant
    Enum.each(participants, fn participant ->
      if participant.notifications_enabled do
        title = case conversation.type do
          "direct" -> "New message from #{sender.username}"
          "group" -> "New message in #{conversation.title || "group chat"}"
          _ -> "New message"
        end

        create_chat_notification(participant.user_id, :chat, %{
          title: title,
          message: truncate_message(message.content),
          metadata: %{
            conversation_id: conversation.id,
            message_id: message.id,
            sender_id: sender.id,
            context: conversation.context
          }
        })
      end
    end)
  end

  @doc """
  Creates notifications for collaboration requests
  """
  def notify_collaboration_request(portfolio_owner_id, requester, portfolio) do
    create_chat_notification(portfolio_owner_id, :collaboration, %{
      title: "Collaboration request",
      message: "#{requester.username} wants to collaborate on #{portfolio.title}",
      metadata: %{
        requester_id: requester.id,
        portfolio_id: portfolio.id,
        type: "collaboration_request"
      }
    })
  end

  @doc """
  Creates notifications for service communications
  """
  def notify_service_message(service, client, provider, message_type \\ :general) do
    case message_type do
      :booking_confirmation ->
        create_chat_notification(client.id, :service, %{
          title: "Booking confirmed",
          message: "Your #{service.name} booking has been confirmed",
          metadata: %{service_id: service.id, provider_id: provider.id}
        })

      :status_update ->
        create_chat_notification(client.id, :service, %{
          title: "Service update",
          message: "Update on your #{service.name} service",
          metadata: %{service_id: service.id, provider_id: provider.id}
        })

      _ ->
        create_chat_notification(client.id, :service, %{
          title: "Service message",
          message: "New message from #{provider.username}",
          metadata: %{service_id: service.id, provider_id: provider.id}
        })
    end
  end

  @doc """
  Creates notifications for lab activities
  """
  def notify_lab_activity(user_id, activity_type, metadata \\ %{}) do
    {title, message} = case activity_type do
      :experiment_ready ->
        {"Experiment ready", "Your A/B test results are available"}
      :feature_request_update ->
        {"Feature request update", "There's an update on your feature request"}
      :beta_invitation ->
        {"Beta program invitation", "You've been invited to test a new feature"}
      :ai_insight ->
        {"AI insight available", "New optimization suggestions for your portfolio"}
      _ ->
        {"Lab notification", "New activity in Creator Lab"}
    end

    create_chat_notification(user_id, :lab, %{
      title: title,
      message: message,
      metadata: metadata
    })
  end

  @doc """
  Gets notifications for a user
  """
  def get_user_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(n in Notification,
      where: n.user_id == ^user_id,
      order_by: [desc: n.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Marks a notification as read
  """
  def mark_notification_read(notification_id, user_id) do
    from(n in Notification,
      where: n.id == ^notification_id and n.user_id == ^user_id
    )
    |> Repo.update_all(set: [read_at: DateTime.utc_now()])
  end

  @doc """
  Marks all notifications as read for a user
  """
  def mark_user_notifications_read(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at)
    )
    |> Repo.update_all(set: [read_at: DateTime.utc_now()])
  end

  @doc """
  Gets unread notification count for a user
  """
  def get_unread_count(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at)
    )
    |> Repo.aggregate(:count)
  end

  defp truncate_message(content, length \\ 50) do
    if String.length(content) > length do
      String.slice(content, 0, length) <> "..."
    else
      content
    end
  end
end
