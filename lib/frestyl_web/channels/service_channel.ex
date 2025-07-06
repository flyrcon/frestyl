# lib/frestyl_web/channels/service_channel.ex

defmodule FrestylWeb.ServiceChannel do
  @moduledoc """
  Service-specific chat channel for client-provider communication
  """

  use Phoenix.Channel
  alias Frestyl.{Chat, Services, Accounts}
  alias FrestylWeb.Presence

  def join("service:" <> service_id, _params, socket) do
    service_id = String.to_integer(service_id)
    user_id = socket.assigns.user_id

    case authorize_service_access(user_id, service_id) do
      {:ok, service, role} ->
        send(self(), :after_join)
        {:ok, %{service: service, role: role},
         socket |> assign(:service_id, service_id) |> assign(:service_role, role)}
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  def handle_info(:after_join, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)
    service_id = socket.assigns.service_id

    # Track presence for service participants
    {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
      online_at: inspect(System.system_time(:second)),
      user_id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      activity: "service_communication",
      service_id: service_id,
      role: socket.assigns.service_role
    })

    push(socket, "presence_state", Presence.list(socket))

    # Get service conversations for this user
    conversations = Chat.get_contextual_conversations(user.id, :service, service_id: service_id)
    push(socket, "service_conversations", %{conversations: conversations})

    {:noreply, socket}
  end

  def handle_in("service_message", %{"conversation_id" => conversation_id, "content" => content}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    case Chat.send_message(conversation_id, user.id, content, type: "service") do
      {:ok, message} ->
        broadcast!(socket, "new_service_message", format_service_message(message, user))
        {:reply, :ok, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "Failed to send message"}}, socket}
    end
  end

  def handle_in("booking_update", %{"booking_id" => booking_id, "status" => status, "message" => message}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)
    service_id = socket.assigns.service_id

    # Only service providers can update booking status
    if socket.assigns.service_role == :provider do
      case Services.update_booking_status(booking_id, status) do
        {:ok, booking} ->
          # Create system message about status change
          conversation_id = booking.conversation_id
          system_message = "Booking status updated to: #{status}"

          if message && String.trim(message) != "" do
            Chat.send_message(conversation_id, user.id, message, type: "service")
          end

          Chat.send_message(conversation_id, user.id, system_message, type: "system")

          broadcast!(socket, "booking_status_updated", %{
            booking_id: booking_id,
            status: status,
            message: message
          })

          {:reply, :ok, socket}

        {:error, _} ->
          {:reply, {:error, %{reason: "Failed to update booking"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "Unauthorized"}}, socket}
    end
  end

  def handle_in("request_meeting_link", %{"booking_id" => booking_id}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    case Services.generate_meeting_link(booking_id) do
      {:ok, meeting_link} ->
        broadcast!(socket, "meeting_link_generated", %{
          booking_id: booking_id,
          meeting_link: meeting_link
        })
        {:reply, {:ok, %{meeting_link: meeting_link}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  defp authorize_service_access(user_id, service_id) do
    case Services.get_service(service_id) do
      nil ->
        {:error, "Service not found"}
      service ->
        cond do
          service.provider_id == user_id -> {:ok, service, :provider}
          Services.user_has_booking?(user_id, service_id) -> {:ok, service, :client}
          true -> {:error, "Access denied"}
        end
    end
  end

  defp format_service_message(message, user) do
    %{
      id: message.id,
      content: message.content,
      message_type: message.message_type,
      user_id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      inserted_at: message.inserted_at,
      service_context: true
    }
  end
end
