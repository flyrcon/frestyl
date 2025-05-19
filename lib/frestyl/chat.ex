defmodule Frestyl.Chat do
  @moduledoc """
  The Chat context for managing messages in channels and direct conversations.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo

  alias Frestyl.Chat.Attachment
  alias Frestyl.Chat.Message
  alias Frestyl.Chat.Conversation
  alias Frestyl.Chat.ConversationParticipant
  alias Frestyl.Chat.Reaction

  alias Frestyl.Accounts.User
  alias Frestyl.Channels
  alias Frestyl.Channels.Channel

  # ===============================
  # CHANNEL MESSAGE FUNCTIONS
  # ===============================

  @doc """
  Creates a message in a channel.
  """
  def create_channel_message(params, user, channel) do
    message_params = params
      |> Map.put("user_id", user.id)
      |> Map.put("channel_id", channel.id)
      |> Map.put("message_type", Map.get(params, "message_type", "text"))

    # Get default room if needed
    message_params = if Map.has_key?(message_params, "room_id") do
      message_params
    else
      default_room = Frestyl.Channels.get_default_room(channel.id)
      Map.put(message_params, "room_id", default_room && default_room.id)
    end

    %Message{}
    |> Message.changeset(message_params)
    |> Repo.insert()
    |> case do
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

  # ===============================
  # CONVERSATION FUNCTIONS
  # ===============================

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

  @doc """
  Gets a single conversation with preloaded data.
  """
  def get_conversation!(id) do
    Conversation
    |> Repo.get!(id)
    |> Repo.preload([:participants, messages: [user: []]])
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
    |> case do
      {:ok, message} ->
        message = Repo.preload(message, :user)
        # Broadcast just the message ID to avoid serialization issues
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "conversation:#{conversation.id}",
          {:new_message, message.id}  # Send ID instead of full message
        )
        # Update conversation's last_message_at
        update_conversation_last_message(conversation.id)
        {:ok, message}
      error -> error
    end
  end

  @doc """
  Lists messages for a conversation with options.
  """
  def list_messages_for_conversation(conversation_id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])
    before = Keyword.get(opts, :before)
    limit = Keyword.get(opts, :limit)

    query = from m in Message,
            where: m.conversation_id == ^conversation_id,
            order_by: [asc: m.inserted_at]

    query = if before do
      from m in query, where: m.id < ^before
    else
      query
    end

    query = if limit do
      from m in query, limit: ^limit
    else
      query
    end

    query = if preloads != [] do
      from m in query, preload: ^preloads
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  Deletes a message and its attachments.
  """
  def delete_message(message_id) do
    case Repo.get(Message, message_id) |> Repo.preload(:attachments) do
      nil ->
        {:error, :not_found}

      message ->
        # Soft delete - just mark as deleted instead of removing completely
        result =
          message
          |> Ecto.Changeset.change(%{
            content: "[Message deleted]",
            metadata: Map.put(message.metadata || %{}, "deleted", true)
          })
          |> Repo.update()

        case result do
          {:ok, updated_message} ->
            # Optionally: Remove file attachments from filesystem
            # (but keep the records for audit trail)
            for attachment <- message.attachments || [] do
              # Build the full file path
              full_path = Path.join([Application.app_dir(:frestyl), "priv", "static"]) <> attachment.path
              if File.exists?(full_path) do
                File.rm(full_path)
              end
            end

            {:ok, updated_message}

          error ->
            error
        end
    end
  end

  @doc """
  Updates a conversation's last_message_at timestamp.
  """
  defp update_conversation_last_message(conversation_id) do
    Repo.get(Conversation, conversation_id)
    |> Conversation.changeset(%{last_message_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Creates a conversation between users.
  """
  def find_or_create_conversation(user_a, user_b) do
    case get_conversation_between_users(user_a.id, user_b.id) do
      nil ->
        case Repo.transaction(fn ->
          {:ok, conversation} = %Conversation{}
            |> Conversation.changeset(%{
              title: "Chat with #{user_b.name || user_b.email}",
              last_message_at: DateTime.utc_now()
            })
            |> Repo.insert()

          # Add participants
          Repo.insert_all("conversation_participants", [
            %{
              conversation_id: conversation.id,
              user_id: user_a.id,
              inserted_at: DateTime.utc_now(),
              updated_at: DateTime.utc_now()
            },
            %{
              conversation_id: conversation.id,
              user_id: user_b.id,
              inserted_at: DateTime.utc_now(),
              updated_at: DateTime.utc_now()
            }
          ])

          conversation
        end) do
          {:ok, conversation} -> {:ok, conversation}
          {:error, reason} -> {:error, reason}
        end

      conversation ->
        {:ok, conversation}
    end
  end

  @doc """
  Gets a conversation between two users.
  """
  def get_conversation_between_users(user_a_id, user_b_id) do
    query = from c in Conversation,
            join: p1 in "conversation_participants", on: p1.conversation_id == c.id,
            join: p2 in "conversation_participants", on: p2.conversation_id == c.id,
            where: p1.user_id == ^user_a_id and p2.user_id == ^user_b_id,
            limit: 1

    Repo.one(query)
  end

  # ===============================
  # REACTION FUNCTIONS (NEW)
  # ===============================

  @doc """
  Adds an emoji reaction to a message.
  """
  def add_reaction(message_id, user_id, emoji) do
    case get_existing_emoji_reaction(message_id, user_id, emoji) do
      nil ->
        %Reaction{}
        |> Reaction.changeset(%{
          message_id: message_id,
          user_id: user_id,
          emoji: emoji,
          reaction_type: "emoji"
        })
        |> Repo.insert()
        |> broadcast_reaction_update(message_id)

      existing ->
        {:ok, existing}
    end
  end

  @doc """
  Adds a custom reaction to a message.
  """
  def add_custom_reaction(message_id, user_id, text) do
    case get_existing_custom_reaction(message_id, user_id, text) do
      nil ->
        %Reaction{}
        |> Reaction.changeset(%{
          message_id: message_id,
          user_id: user_id,
          custom_text: text,
          reaction_type: "custom"
        })
        |> Repo.insert()
        |> broadcast_reaction_update(message_id)

      existing ->
        {:ok, existing}
    end
  end

  @doc """
  Removes an emoji reaction from a message.
  """
  def remove_reaction(message_id, user_id, emoji) do
    from(r in Reaction,
      where: r.message_id == ^message_id and
             r.user_id == ^user_id and
             r.emoji == ^emoji and
             r.reaction_type == "emoji"
    )
    |> Repo.delete_all()
    |> case do
      {count, _} when count > 0 ->
        broadcast_reaction_update({:ok, nil}, message_id)
        {:ok, count}
      {0, _} ->
        {:error, :not_found}
    end
  end

  @doc """
  Removes a custom reaction from a message.
  """
  def remove_custom_reaction(message_id, user_id, text) do
    from(r in Reaction,
      where: r.message_id == ^message_id and
             r.user_id == ^user_id and
             r.custom_text == ^text and
             r.reaction_type == "custom"
    )
    |> Repo.delete_all()
    |> case do
      {count, _} when count > 0 ->
        broadcast_reaction_update({:ok, nil}, message_id)
        {:ok, count}
      {0, _} ->
        {:error, :not_found}
    end
  end

  defp load_emoji_reactions(user_id) do
    try do
      # Check if ConversationParticipant schema exists
      unless Code.ensure_loaded?(Frestyl.Chat.ConversationParticipant) do
        Logger.warning("ConversationParticipant schema not found, skipping emoji reactions")
        %{}
      else
        query = from r in Reaction,
                join: m in Message, on: r.message_id == m.id,
                join: c in Conversation, on: m.conversation_id == c.id,
                join: cp in ConversationParticipant, on: c.id == cp.conversation_id,
                where: cp.user_id == ^user_id and r.reaction_type == "emoji",
                select: {r.message_id, r.emoji, r.user_id}

        query
        |> Repo.all()
        |> Enum.reduce(%{}, fn {message_id, emoji, reactor_id}, acc ->
          message_reactions = Map.get(acc, message_id, %{})
          emoji_users = Map.get(message_reactions, emoji, [])
          updated_users = if reactor_id in emoji_users, do: emoji_users, else: [reactor_id | emoji_users]
          updated_message_reactions = Map.put(message_reactions, emoji, updated_users)
          Map.put(acc, message_id, updated_message_reactions)
        end)
      end
    rescue
      error ->
        Logger.error("Error loading emoji reactions: #{inspect(error)}")
        %{}
    end
  end

  # Helper function to load custom text reactions for a user's conversations
  defp load_custom_reactions(user_id) do
    try do
      # Check if ConversationParticipant schema exists
      unless Code.ensure_loaded?(Frestyl.Chat.ConversationParticipant) do
        Logger.warning("ConversationParticipant schema not found, skipping custom reactions")
        %{}
      else
        query = from r in Reaction,
                join: m in Message, on: r.message_id == m.id,
                join: c in Conversation, on: m.conversation_id == c.id,
                join: cp in ConversationParticipant, on: c.id == cp.conversation_id,
                where: cp.user_id == ^user_id and r.reaction_type == "custom",
                select: {r.message_id, r.custom_text, r.user_id}

        query
        |> Repo.all()
        |> Enum.reduce(%{}, fn {message_id, text, reactor_id}, acc ->
          message_reactions = Map.get(acc, message_id, %{})
          text_users = Map.get(message_reactions, text, [])
          updated_users = if reactor_id in text_users, do: text_users, else: [reactor_id | text_users]
          updated_message_reactions = Map.put(message_reactions, text, updated_users)
          Map.put(acc, message_id, updated_message_reactions)
        end)
      end
    rescue
      error ->
        Logger.error("Error loading custom reactions: #{inspect(error)}")
        %{}
    end
  end

  # Updated public functions for loading reactions
  def list_emoji_reactions_for_user_conversations(user_id) do
    try do
      unless Code.ensure_loaded?(Frestyl.Chat.ConversationParticipant) do
        Logger.warning("ConversationParticipant schema not found, returning empty reactions")
        %{}
      else
        query = from r in Reaction,
                join: m in Message, on: r.message_id == m.id,
                join: c in Conversation, on: m.conversation_id == c.id,
                join: cp in ConversationParticipant, on: c.id == cp.conversation_id,
                where: cp.user_id == ^user_id and r.reaction_type == "emoji",
                select: {r.message_id, r.emoji, r.user_id}

        query
        |> Repo.all()
        |> Enum.reduce(%{}, fn {message_id, emoji, reactor_id}, acc ->
          message_reactions = Map.get(acc, message_id, %{})
          emoji_users = Map.get(message_reactions, emoji, [])
          updated_users = if reactor_id in emoji_users, do: emoji_users, else: [reactor_id | emoji_users]
          updated_message_reactions = Map.put(message_reactions, emoji, updated_users)
          Map.put(acc, message_id, updated_message_reactions)
        end)
      end
    rescue
      error ->
        Logger.error("Error loading emoji reactions: #{inspect(error)}")
        %{}
    end
  end

  def list_custom_reactions_for_user_conversations(user_id) do
    try do
      unless Code.ensure_loaded?(Frestyl.Chat.ConversationParticipant) do
        Logger.warning("ConversationParticipant schema not found, returning empty reactions")
        %{}
      else
        query = from r in Reaction,
                join: m in Message, on: r.message_id == m.id,
                join: c in Conversation, on: m.conversation_id == c.id,
                join: cp in ConversationParticipant, on: c.id == cp.conversation_id,
                where: cp.user_id == ^user_id and r.reaction_type == "custom",
                select: {r.message_id, r.custom_text, r.user_id}

        query
        |> Repo.all()
        |> Enum.reduce(%{}, fn {message_id, text, reactor_id}, acc ->
          message_reactions = Map.get(acc, message_id, %{})
          text_users = Map.get(message_reactions, text, [])
          updated_users = if reactor_id in text_users, do: text_users, else: [reactor_id | text_users]
          updated_message_reactions = Map.put(message_reactions, text, updated_users)
          Map.put(acc, message_id, updated_message_reactions)
        end)
      end
    rescue
      error ->
        Logger.error("Error loading custom reactions: #{inspect(error)}")
        %{}
    end
  end

  # ===============================
  # ATTACHMENT FUNCTIONS
  # ===============================

  @doc """
  Creates an attachment.
  """
  def create_attachment(attrs \\ %{}) do
    %Attachment{}
    |> Attachment.changeset(attrs)
    |> Repo.insert()
  end

  # ===============================
  # MESSAGE UTILITIES
  # ===============================

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.
  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  # ===============================
  # PRIVATE HELPER FUNCTIONS
  # ===============================

  defp get_existing_emoji_reaction(message_id, user_id, emoji) do
    Repo.get_by(Reaction,
      message_id: message_id,
      user_id: user_id,
      emoji: emoji,
      reaction_type: "emoji"
    )
  end

  defp get_existing_custom_reaction(message_id, user_id, text) do
    Repo.get_by(Reaction,
      message_id: message_id,
      user_id: user_id,
      custom_text: text,
      reaction_type: "custom"
    )
  end

  defp broadcast_reaction_update({:ok, _reaction}, message_id) do
    # Get the message to determine broadcast target
    case Repo.get(Message, message_id) do
      %{channel_id: channel_id} when not is_nil(channel_id) ->
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "channel:#{channel_id}",
          {:reactions_updated, message_id}
        )
      %{conversation_id: conversation_id} when not is_nil(conversation_id) ->
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "conversation:#{conversation_id}",
          {:reactions_updated, message_id}
        )
      _ -> :ok
    end
    {:ok, _reaction}
  end

  defp broadcast_reaction_update(error, _message_id), do: error



end
