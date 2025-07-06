# lib/frestyl/chat/context_manager.ex
# Extension to your existing Chat module for portfolio hub integration

defmodule Frestyl.Chat.ContextManager do
  @moduledoc """
  Manages contextual chat functionality for the portfolio hub integration.
  Extends the existing Frestyl.Chat module with context-aware features.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Chat
  alias Frestyl.Chat.{Message, Conversation, ConversationParticipant}
  alias Frestyl.{Portfolios, Services, Channels}

  @doc """
  Gets conversations for a user filtered by context (portfolio, service, etc.)
  """
  def get_contextual_conversations(user_id, context, opts \\ []) do
    base_conversations = Chat.list_user_conversations(user_id)

    case context do
      :portfolio ->
        portfolio_id = Keyword.get(opts, :portfolio_id)
        filter_portfolio_conversations(base_conversations, portfolio_id)

      :service ->
        filter_service_conversations(base_conversations, user_id)

      :channel ->
        channel_id = Keyword.get(opts, :channel_id)
        # For channels, we use the existing channel message system
        get_channel_context(user_id, channel_id)

      :collaboration ->
        session_id = Keyword.get(opts, :session_id)
        filter_collaboration_conversations(base_conversations, session_id)

      :general ->
        filter_general_conversations(base_conversations)

      _ ->
        base_conversations
    end
    |> Enum.take(Keyword.get(opts, :limit, 50))
    |> add_conversation_metadata(user_id)
  end

  @doc """
  Creates a portfolio feedback conversation using existing conversation system
  """
  def create_portfolio_feedback_conversation(portfolio_id, requester_id, expert_id) do
    requester = Frestyl.Accounts.get_user!(requester_id)
    expert = Frestyl.Accounts.get_user!(expert_id)

    case Chat.find_or_create_conversation(requester, expert) do
      {:ok, conversation} ->
        # Add portfolio context metadata
        updated_conversation = add_portfolio_context(conversation, portfolio_id, "feedback")
        {:ok, updated_conversation}

      error -> error
    end
  end

  @doc """
  Creates a service communication conversation
  """
  def create_service_conversation(service_id, client_id, provider_id) do
    client = Frestyl.Accounts.get_user!(client_id)
    provider = Frestyl.Accounts.get_user!(provider_id)

    case Chat.find_or_create_conversation(client, provider) do
      {:ok, conversation} ->
        updated_conversation = add_service_context(conversation, service_id)
        {:ok, updated_conversation}

      error -> error
    end
  end

  @doc """
  Sends a contextual message with metadata
  """
  def send_contextual_message(conversation_id, user_id, content, context_type, metadata \\ %{}) do
    user = Frestyl.Accounts.get_user!(user_id)
    conversation = Chat.get_conversation!(conversation_id)

    message_params = %{
      "content" => content,
      "message_type" => context_type,
      "metadata" => Map.merge(%{"context" => context_type}, metadata)
    }

    Chat.create_message(message_params, user, conversation)
  end

  @doc """
  Gets unread conversation count for a user in a specific context
  """
  def get_unread_count_by_context(user_id, context) do
    conversations = get_contextual_conversations(user_id, context)

    conversations
    |> Enum.map(&get_conversation_unread_count(&1.id, user_id))
    |> Enum.sum()
  end

  # Private helper functions

  defp filter_portfolio_conversations(conversations, nil) do
    # Return conversations with portfolio context
    Enum.filter(conversations, fn conv ->
      has_portfolio_context?(conv)
    end)
  end

  defp filter_portfolio_conversations(conversations, portfolio_id) do
    Enum.filter(conversations, fn conv ->
      get_portfolio_id_from_conversation(conv) == portfolio_id
    end)
  end

  defp filter_service_conversations(conversations, user_id) do
    # Get user's services (as provider or client)
    user_service_ids = get_user_service_ids(user_id)

    Enum.filter(conversations, fn conv ->
      has_service_context?(conv, user_service_ids)
    end)
  end

  defp filter_collaboration_conversations(conversations, session_id) do
    Enum.filter(conversations, fn conv ->
      has_collaboration_context?(conv, session_id)
    end)
  end

  defp filter_general_conversations(conversations) do
    Enum.filter(conversations, fn conv ->
      !has_specific_context?(conv)
    end)
  end

  defp get_channel_context(user_id, channel_id) do
    # For channels, return a special conversation-like structure
    # that represents the channel chat
    if channel_id do
      channel = Channels.get_channel!(channel_id)
      recent_messages = Chat.list_recent_channel_messages(channel_id, 50)

      [%{
        id: "channel_#{channel_id}",
        type: :channel,
        title: channel.name,
        participants: [],
        messages: recent_messages,
        last_message_at: case recent_messages do
          [first_message | _] -> first_message.inserted_at
          [] -> nil
        end,
        unread_count: 0, # Channel messages don't have traditional unread counts
        metadata: %{channel_id: channel_id, context: "channel"}
      }]
    else
      []
    end
  end

  defp add_conversation_metadata(conversations, user_id) do
    Enum.map(conversations, fn conversation ->
      conversation
      |> Map.put(:unread_count, get_conversation_unread_count(conversation.id, user_id))
      |> Map.put(:last_message, get_last_message(conversation.id))
      |> Map.put(:context_type, determine_conversation_context(conversation))
    end)
  end

  defp add_portfolio_context(conversation, portfolio_id, context_type) do
    metadata = %{
      portfolio_id: portfolio_id,
      context: "portfolio",
      context_type: context_type
    }

    # Update conversation title and metadata
    conversation
    |> Conversation.changeset(%{
      title: "Portfolio #{context_type}",
      metadata: metadata
    })
    |> Repo.update!()
  end

  defp add_service_context(conversation, service_id) do
    service = Services.get_service!(service_id)

    metadata = %{
      service_id: service_id,
      context: "service",
      service_name: service.name
    }

    conversation
    |> Conversation.changeset(%{
      title: "Service: #{service.name}",
      metadata: metadata
    })
    |> Repo.update!()
  end

  defp has_portfolio_context?(conversation) do
    get_in(conversation, [:metadata, "context"]) == "portfolio"
  end

  defp has_service_context?(conversation, user_service_ids) do
    context = get_in(conversation, [:metadata, "context"])
    service_id = get_in(conversation, [:metadata, "service_id"])

    context == "service" and service_id in user_service_ids
  end

  defp has_collaboration_context?(conversation, session_id) do
    context = get_in(conversation, [:metadata, "context"])
    conv_session_id = get_in(conversation, [:metadata, "session_id"])

    context == "collaboration" and (session_id == nil or conv_session_id == session_id)
  end

  defp has_specific_context?(conversation) do
    context = get_in(conversation, [:metadata, "context"])
    context in ["portfolio", "service", "collaboration", "channel", "lab"]
  end

  defp get_portfolio_id_from_conversation(conversation) do
    get_in(conversation, [:metadata, "portfolio_id"])
  end

  defp get_user_service_ids(user_id) do
    # Get services where user is provider or has bookings as client
    provider_services = from(s in Services.Service, where: s.provider_id == ^user_id, select: s.id)
    client_services = from(b in Services.Booking, where: b.client_id == ^user_id, select: b.service_id)

    (Repo.all(provider_services) ++ Repo.all(client_services))
    |> Enum.uniq()
  end

  defp get_conversation_unread_count(conversation_id, user_id) do
    # This would need to be implemented based on your existing message reading tracking
    # For now, return 0 as a placeholder
    0
  end

  defp get_last_message(conversation_id) do
    from(m in Message,
      where: m.conversation_id == ^conversation_id,
      order_by: [desc: m.inserted_at],
      limit: 1,
      preload: [:user]
    )
    |> Repo.one()
  end

  defp determine_conversation_context(conversation) do
    case get_in(conversation, [:metadata, "context"]) do
      "portfolio" -> :portfolio
      "service" -> :service
      "collaboration" -> :collaboration
      "lab" -> :lab
      _ -> :general
    end
  end
end
