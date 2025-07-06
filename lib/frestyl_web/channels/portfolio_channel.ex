# lib/frestyl_web/channels/portfolio_channel.ex

defmodule FrestylWeb.PortfolioChannel do
  @moduledoc """
  Portfolio-specific chat channel for feedback, collaboration, and portfolio discussions
  """

  use Phoenix.Channel
  alias Frestyl.{Chat, Portfolios, Accounts}
  alias FrestylWeb.Presence

  def join("portfolio:" <> portfolio_id, _params, socket) do
    portfolio_id = String.to_integer(portfolio_id)
    user_id = socket.assigns.user_id

    case authorize_portfolio_access(user_id, portfolio_id) do
      {:ok, portfolio} ->
        send(self(), :after_join)
        {:ok, %{portfolio: portfolio}, assign(socket, :portfolio_id, portfolio_id)}
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  def handle_info(:after_join, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)
    portfolio_id = socket.assigns.portfolio_id

    # Track presence for portfolio visitors/collaborators
    {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
      online_at: inspect(System.system_time(:second)),
      user_id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      activity: "viewing_portfolio",
      portfolio_id: portfolio_id
    })

    # Push current presence state
    push(socket, "presence_state", Presence.list(socket))

    # Get recent portfolio conversations
    conversations = Chat.get_contextual_conversations(user.id, :portfolio, portfolio_id: portfolio_id)
    push(socket, "recent_conversations", %{conversations: conversations})

    {:noreply, socket}
  end

  def handle_in("portfolio_feedback", %{"section_id" => section_id, "content" => content}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)
    portfolio_id = socket.assigns.portfolio_id

    # Create or find feedback conversation for this section
    case Chat.find_or_create_conversation(
      [user.id], # Can add portfolio owner later
      :portfolio,
      portfolio_id,
      %{title: "Section Feedback", metadata: %{section_id: section_id}}
    ) do
      {:ok, conversation} ->
        case Chat.send_message(conversation.id, user.id, content, type: "feedback") do
          {:ok, message} ->
            broadcast!(socket, "new_feedback", %{
              section_id: section_id,
              message: format_message(message, user),
              conversation_id: conversation.id
            })
            {:reply, :ok, socket}

          {:error, _} ->
            {:reply, {:error, %{reason: "Failed to save feedback"}}, socket}
        end

      {:error, _} ->
        {:reply, {:error, %{reason: "Failed to create conversation"}}, socket}
    end
  end

  def handle_in("portfolio_collaboration_request", %{"message" => message}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)
    portfolio_id = socket.assigns.portfolio_id

    # Get portfolio owner
    portfolio = Portfolios.get_portfolio!(portfolio_id)

    if portfolio.user_id != user.id do
      # Create collaboration request conversation
      case Chat.find_or_create_conversation(
        [user.id, portfolio.user_id],
        :portfolio,
        portfolio_id,
        %{title: "Collaboration Request", metadata: %{type: "collaboration_request"}}
      ) do
        {:ok, conversation} ->
          case Chat.send_message(conversation.id, user.id, message, type: "collaboration_request") do
            {:ok, message} ->
              # Notify portfolio owner
              broadcast!(socket, "collaboration_request", %{
                from_user: user,
                message: message.content,
                conversation_id: conversation.id
              })
              {:reply, :ok, socket}

            {:error, _} ->
              {:reply, {:error, %{reason: "Failed to send request"}}, socket}
          end

        {:error, _} ->
          {:reply, {:error, %{reason: "Failed to create conversation"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "Cannot collaborate with yourself"}}, socket}
    end
  end

  def handle_in("chat_message", %{"conversation_id" => conversation_id, "content" => content}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    case Chat.send_message(conversation_id, user.id, content) do
      {:ok, message} ->
        broadcast!(socket, "new_message", format_message(message, user))
        {:reply, :ok, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "Failed to send message"}}, socket}
    end
  end

  defp authorize_portfolio_access(user_id, portfolio_id) do
    case Portfolios.get_portfolio(portfolio_id) do
      nil -> {:error, "Portfolio not found"}
      portfolio ->
        if portfolio.visibility in ["public", "unlisted"] or portfolio.user_id == user_id do
          {:ok, portfolio}
        else
          {:error, "Access denied"}
        end
    end
  end

  defp format_message(message, user) do
    %{
      id: message.id,
      content: message.content,
      message_type: message.message_type,
      user_id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      inserted_at: message.inserted_at
    }
  end
end
