defmodule Frestyl.Chat do
  @moduledoc """
  The Chat context for managing messages in channels and direct conversations.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo

  alias Frestyl.Chat.{Message, Conversation}
  alias Frestyl.Accounts.User
  alias Frestyl.Channels
  alias Frestyl.Channels.Channel

  @doc """
  Creates a message in a channel.
  """
  def create_channel_message(params, user, channel) do
    message_params = Map.merge(params, %{
      "user_id" => user.id,
      "channel_id" => channel.id,
      "message_type" => Map.get(params, "message_type", "text")
    })

    message = %Message{}
    |> Message.changeset(message_params)
    |> Repo.insert()

    case message do
      {:ok, msg} ->
        msg = Repo.preload(msg, :user)
        broadcast_channel_message(channel.id, msg)
        update_user_activity(user.id, channel.id)
        {:ok, msg}
      error -> error
    end
  end

  @doc """
  Returns a list of recent messages for a channel.
  """
  def list_recent_channel_messages(channel_id, limit \\ 50) do
    Message
    |> where([m], m.channel_id == ^channel_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload([:user])
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Returns a list of channel messages with pagination.
  """
  def list_channel_messages(channel_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 50)

    Message
    |> where([m], m.channel_id == ^channel_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^per_page)
    |> offset((^page - 1) * ^per_page)
    |> preload([:user])
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Returns messages before a specific message ID
  """
  def list_channel_messages_before(channel_id, message_id, limit \\ 50) do
    Message
    |> where([m], m.channel_id == ^channel_id and m.id < ^message_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload([:user])
    |> Repo.all()
    |> Enum.reverse()
  end

  defp broadcast_channel_message(channel_id, message) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{channel_id}",
      {:new_message, message}
    )
  end

  @doc """
  Updates user's last activity in channel.
  """
  def update_user_activity(user_id, channel_id) do
    Channels.update_member_activity(user_id, channel_id)
  end

  @doc """
  Broadcasts a typing status for a user in a channel.
  """
  def broadcast_typing_status(channel_id, user_id, typing) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{channel_id}:typing",
      {:typing_status, user_id, typing}
    )
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.
  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Deletes a message.
  """
  def delete_message(message_id, user) do
    message = Repo.get(Message, message_id)

    cond do
      is_nil(message) ->
        {:error, "Message not found"}

      message.user_id == user.id or user.role in ["admin", "moderator"] ->
        # Hard delete for now, could be changed to soft delete
        result = Repo.delete(message)

        # If delete was successful, broadcast the deletion
        case result do
          {:ok, deleted_message} ->
            Phoenix.PubSub.broadcast(
              Frestyl.PubSub,
              "channel:#{deleted_message.channel_id}",
              {:message_deleted, deleted_message.id}
            )
            {:ok, deleted_message}
          error -> error
        end

      true ->
        {:error, "Unauthorized"}
    end
  end

  # Conversation functions

  @doc """
  Creates a direct message conversation between two users.
  """
  def create_conversation(user_a_id, user_b_id) do
    # Check if conversation already exists
    case get_conversation_between_users(user_a_id, user_b_id) do
      nil ->
        # Create new conversation
        with {:ok, conversation} <- %Conversation{}
                                    |> Conversation.changeset(%{
                                      title: "Direct Message",
                                      last_message_at: DateTime.utc_now()
                                    })
                                    |> Repo.insert(),
             # Add participants
             {:ok, _} <- add_participant_to_conversation(conversation.id, user_a_id),
             {:ok, _} <- add_participant_to_conversation(conversation.id, user_b_id) do
          {:ok, conversation}
        else
          {:error, changeset} -> {:error, changeset}
        end
      conversation ->
        {:ok, conversation}
    end
  end

  @doc """
  Gets a conversation between two users.
  """
  def get_conversation_between_users(user_a_id, user_b_id) do
    # Find conversation where both users are participants
    query = from c in Conversation,
            join: p1 in "conversation_participants", on: p1.conversation_id == c.id,
            join: p2 in "conversation_participants", on: p2.conversation_id == c.id,
            where: p1.user_id == ^user_a_id and p2.user_id == ^user_b_id,
            limit: 1

    Repo.one(query)
  end

  @doc """
  Gets a single conversation.
  """
  def get_conversation!(id) do
    Repo.get!(Conversation, id)
    |> Repo.preload([:participants, messages: [user: []]])
  end

  @doc """
  Lists messages for a conversation.
  """
  def list_messages(conversation_id) do
    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> order_by([m], asc: m.inserted_at)
    |> preload([:user])
    |> Repo.all()
  end

  @doc """
  Creates a message in a conversation.
  """
  def create_message(params, user, conversation) do
    %Message{}
    |> Message.changeset(%{
      content: params["content"],
      user_id: user.id,
      conversation_id: conversation.id,
      message_type: "text"
    })
    |> Repo.insert()
  end

  @doc """
  Finds an existing conversation between users or creates a new one.
  """
  def find_or_create_conversation(user_a, user_b) do
    # Check if conversation already exists
    case get_conversation_between_users(user_a.id, user_b.id) do
      nil ->
        # Create new conversation
        {:ok, conversation} = %Conversation{}
          |> Conversation.changeset(%{
            title: "Chat with #{user_b.name || user_b.email}",
            last_message_at: DateTime.utc_now()
          })
          |> Repo.insert()

        # Add participants
        add_participant_to_conversation(conversation.id, user_a.id)
        add_participant_to_conversation(conversation.id, user_b.id)

        {:ok, conversation}

      conversation ->
        {:ok, conversation}
    end
  end

  @doc """
  Adds a user as a participant to a conversation.
  """
  defp add_participant_to_conversation(conversation_id, user_id) do
    %{
      conversation_id: conversation_id,
      user_id: user_id
    }
    |> insert_participant()
  end

  defp insert_participant(attrs) do
    Repo.insert(
      Ecto.Query.from(p in "conversation_participants")
      |> Ecto.Query.insert_all([attrs])
      |> Repo.transaction()
    )
  end

  @doc """
  Creates a direct message in a conversation.
  """
  def create_direct_message(params, user_id, conversation_id) do
    message_params = Map.merge(params, %{
      user_id: user_id,
      conversation_id: conversation_id,
      message_type: Map.get(params, :message_type, "text")
    })

    message = %Message{}
    |> Message.changeset(message_params)
    |> Repo.insert()

    case message do
      {:ok, msg} ->
        msg = Repo.preload(msg, :user)
        broadcast_direct_message(conversation_id, msg)
        update_conversation_last_message(conversation_id)
        {:ok, msg}
      error -> error
    end
  end

  defp broadcast_direct_message(conversation_id, message) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "conversation:#{conversation_id}",
      {:new_message, message}
    )
  end

  defp update_conversation_last_message(conversation_id) do
    Repo.get(Conversation, conversation_id)
    |> Conversation.changeset(%{last_message_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Returns messages for a conversation.
  """
  def list_conversation_messages(conversation_id, limit \\ 50) do
    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload([:user])
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Gets all conversations for a user.
  """
  def list_user_conversations(user_id) do
    query = from c in Conversation,
            join: p in "conversation_participants", on: p.conversation_id == c.id,
            where: p.user_id == ^user_id,
            order_by: [desc: c.last_message_at],
            preload: [:participants]

    Repo.all(query)
  end
end
