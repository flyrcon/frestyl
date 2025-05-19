defmodule FrestylWeb.ChatLive.Index do
  use FrestylWeb, :authenticated_live_view
  require Logger
  import Ecto.Query

  alias Frestyl.Chat
  alias Frestyl.Chat.Message
  alias Frestyl.Chat.Conversation
  alias Frestyl.Chat.ConversationParticipant
  alias Frestyl.Repo

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("ChatLive.Index: Mounting...")

    current_user = socket.assigns[:current_user]

    if is_nil(current_user) do
      {:ok,
      socket
      |> put_flash(:error, "You must be logged in to use chat")
      |> push_redirect(to: ~p"/users/log_in")}
    else
      Logger.info("Current user ID: #{current_user.id}")

      # Setup ALL required assigns FIRST
      socket =
        socket
        |> assign(:conversations, [])
        |> assign(:selected_conversation, nil)
        |> assign(:conversation, nil)
        |> assign(:messages, [])
        |> assign(:loading_error, nil)
        |> assign(:users_map, %{})
        |> assign(:show_new_conversation_modal, false)
        |> assign(:available_users, [])
        |> assign(:selected_users, [])
        |> assign(:conversation_modal_tab, "users")
        |> assign(:user_channels, [])
        |> assign(:selected_channel, nil)
        |> assign(:conversation_title, "")
        |> assign(:typing_users, MapSet.new())

      # Configure upload
      socket =
        try do
          result_socket = socket
            |> allow_upload(:attachments,
              accept: ~w(.jpg .jpeg .png .gif .pdf .doc .docx .xls .xlsx .txt .zip .mp3 .mp4 .avi .mov .wav),
              max_entries: 5,
              max_file_size: 10_000_000
            )

          Logger.info("=== UPLOAD DEBUG ===")
          Logger.info("Upload configured successfully: #{inspect(result_socket.assigns.uploads)}")
          Logger.info("Upload attachments: #{inspect(result_socket.assigns.uploads.attachments)}")
          Logger.info("=== END UPLOAD DEBUG ===")

          result_socket
        rescue
          error ->
            Logger.error("Upload configuration failed: #{inspect(error)}")
            socket
        end

      # Load users map
      socket =
        try do
          users = Frestyl.Accounts.list_users()
          users_map =
            users
            |> Enum.reduce(%{}, fn user, acc -> Map.put(acc, user.id, user) end)
          assign(socket, :users_map, users_map)
        rescue
          error ->
            Logger.error("Error loading users: #{inspect(error)}")
            socket
        end

      # Load conversations
      try do
        conversations_query =
          from c in Conversation,
            join: cp in ConversationParticipant, on: cp.conversation_id == c.id,
            where: cp.user_id == ^current_user.id,
            order_by: [desc: c.last_message_at, desc: c.inserted_at],
            preload: [:participants]

        conversations = Repo.all(conversations_query)
        Logger.info("Found #{length(conversations)} conversations for user #{current_user.id}")

        socket =
          socket
          |> assign(:conversations, conversations)
          |> assign(:loading_error, nil)

        # Subscribe to real-time updates
        if socket.transport_pid do
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{current_user.id}:conversations")

          for conversation <- conversations do
            Phoenix.PubSub.subscribe(Frestyl.PubSub, "conversation:#{conversation.id}")
          end
        end

        {:ok, socket}
      rescue
        error ->
          Logger.error("Error loading conversations: #{inspect(error)}")
          {:ok, assign(socket, :loading_error, "Error loading conversations: #{inspect(error)}")}
      end
    end
  end

  @impl true
  def handle_params(%{"id" => conversation_id}, _uri, socket) do
    Logger.info("ChatLive.Index: Handling params with conversation ID: #{conversation_id}")

    try do
      conversation_id = String.to_integer(conversation_id)

      conversation =
        Conversation
        |> Repo.get(conversation_id)
        |> Repo.preload([:participants])

      if conversation do
        messages =
          from(m in Message,
            where: m.conversation_id == ^conversation_id,
            order_by: [asc: m.inserted_at],
            preload: [:user, :attachments]
          )
          |> Repo.all()

        Logger.info("Found #{length(messages)} messages in conversation #{conversation_id}")

        {:noreply,
         socket
         |> assign(:conversation, conversation)
         |> assign(:selected_conversation, conversation)
         |> assign(:messages, messages)}
      else
        Logger.error("Conversation not found: #{conversation_id}")
        {:noreply,
         socket
         |> put_flash(:error, "Conversation not found")
         |> push_navigate(to: ~p"/chat")}
      end
    rescue
      error ->
        Logger.error("Error processing conversation params: #{inspect(error)}")
        {:noreply,
         socket
         |> put_flash(:error, "Error loading conversation")
         |> push_navigate(to: ~p"/chat")}
    end
  end

  def handle_params(_params, _uri, socket) do
    Logger.info("ChatLive.Index: Handling default params")
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_test_conversation", _params, socket) do
    current_user = socket.assigns.current_user

    Logger.info("Creating test conversation for user #{current_user.id}")

    try do
      result = Repo.transaction(fn ->
        {:ok, conversation} =
          %Conversation{}
          |> Conversation.changeset(%{
            title: "Test Chat - #{DateTime.utc_now() |> Calendar.strftime("%H:%M")}",
            last_message_at: DateTime.utc_now(),
            is_group: false
          })
          |> Repo.insert()

        %ConversationParticipant{}
        |> ConversationParticipant.changeset(%{
          conversation_id: conversation.id,
          user_id: current_user.id
        })
        |> Repo.insert!()

        conversation = Repo.preload(conversation, [:participants])
        conversation
      end)

      case result do
        {:ok, conversation} ->
          conversations = [conversation | socket.assigns.conversations]

          {:noreply,
           socket
           |> assign(:conversations, conversations)
           |> assign(:conversation, conversation)
           |> assign(:selected_conversation, conversation)
           |> assign(:messages, [])
           |> put_flash(:info, "Test conversation created!")}

        {:error, reason} ->
          Logger.error("Failed to create conversation: #{inspect(reason)}")
          {:noreply, put_flash(socket, :error, "Failed to create conversation")}
      end
    rescue
      error ->
        Logger.error("Error creating conversation: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Error creating conversation")}
    end
  end

  @impl true
  def handle_event("show_new_conversation_modal", _params, socket) do
    current_user = socket.assigns.current_user

    try do
      user_channels = Frestyl.Channels.list_user_channels(current_user)

      common_channel_users =
        user_channels
        |> Enum.flat_map(fn channel ->
          case Frestyl.Channels.list_channel_members(channel.id) do
            members when is_list(members) ->
              members
              |> Enum.map(& &1.user)
              |> Enum.reject(&(&1.id == current_user.id))
            _ -> []
          end
        end)
        |> Enum.uniq_by(& &1.id)

      {:noreply,
       socket
       |> assign(:show_new_conversation_modal, true)
       |> assign(:conversation_modal_tab, "users")
       |> assign(:available_users, common_channel_users)
       |> assign(:user_channels, user_channels)
       |> assign(:selected_users, [])
       |> assign(:selected_channel, nil)
       |> assign(:conversation_title, "")}
    rescue
      error ->
        Logger.error("Error loading conversation data: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Error loading conversation options")}
    end
  end

  @impl true
  def handle_event("hide_new_conversation_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_new_conversation_modal, false)
     |> assign(:selected_users, [])
     |> assign(:selected_channel, nil)
     |> assign(:conversation_title, "")
     |> assign(:conversation_modal_tab, "users")}
  end

  @impl true
  def handle_event("toggle_user_selection", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    selected_users = socket.assigns.selected_users

    updated_selected =
      if user_id in selected_users do
        List.delete(selected_users, user_id)
      else
        [user_id | selected_users]
      end

    {:noreply, assign(socket, :selected_users, updated_selected)}
  end

  @impl true
  def handle_event("update_conversation_title", %{"value" => title}, socket) do
    {:noreply, assign(socket, :conversation_title, title)}
  end

  @impl true
  def handle_event("create_conversation", _params, socket) do
    current_user = socket.assigns.current_user
    selected_users = socket.assigns.selected_users
    title = socket.assigns.conversation_title

    if length(selected_users) == 0 do
      {:noreply, put_flash(socket, :error, "Please select at least one user")}
    else
      try do
        result = Repo.transaction(fn ->
          final_title = if String.trim(title) == "" do
            user_names =
              socket.assigns.available_users
              |> Enum.filter(&(&1.id in selected_users))
              |> Enum.map(&(&1.name || &1.email))
              |> Enum.take(2)

            case length(user_names) do
              1 -> "Chat with #{hd(user_names)}"
              2 -> "#{Enum.join(user_names, ", ")}"
              _ -> "Group Chat (#{length(selected_users)} people)"
            end
          else
            String.trim(title)
          end

          {:ok, conversation} =
            %Conversation{}
            |> Conversation.changeset(%{
              title: final_title,
              last_message_at: DateTime.utc_now(),
              is_group: length(selected_users) > 1
            })
            |> Repo.insert()

          %ConversationParticipant{}
          |> ConversationParticipant.changeset(%{
            conversation_id: conversation.id,
            user_id: current_user.id
          })
          |> Repo.insert!()

          for user_id <- selected_users do
            %ConversationParticipant{}
            |> ConversationParticipant.changeset(%{
              conversation_id: conversation.id,
              user_id: user_id
            })
            |> Repo.insert!()
          end

          conversation = Repo.preload(conversation, [:participants])
          conversation
        end)

        case result do
          {:ok, conversation} ->
            conversations = [conversation | socket.assigns.conversations]

            # FIXED: Use participant.user_id instead of participant.id
            for participant <- conversation.participants do
              Phoenix.PubSub.broadcast(
                Frestyl.PubSub,
                "user:#{participant.user_id}:conversations",  # FIXED: was participant.id
                {:conversation_created, conversation}
              )
            end

            {:noreply,
            socket
            |> assign(:conversations, conversations)
            |> assign(:conversation, conversation)
            |> assign(:selected_conversation, conversation)
            |> assign(:messages, [])
            |> assign(:show_new_conversation_modal, false)
            |> assign(:selected_users, [])
            |> assign(:conversation_title, "")
            |> put_flash(:info, "Conversation created successfully!")}

          {:error, reason} ->
            Logger.error("Failed to create conversation: #{inspect(reason)}")
            {:noreply, put_flash(socket, :error, "Failed to create conversation")}
        end
      rescue
        error ->
          Logger.error("Error creating conversation: #{inspect(error)}")
          {:noreply, put_flash(socket, :error, "Error creating conversation")}
      end
    end
  end

  @impl true
  def handle_event("select_conversation", %{"id" => id}, socket) do
    Logger.info("Selecting conversation with ID: #{id}")

    try do
      conversation_id = String.to_integer(id)
      conversation = Enum.find(socket.assigns.conversations, &(&1.id == conversation_id))

      if conversation do
        messages =
          from(m in Message,
            where: m.conversation_id == ^conversation_id,
            order_by: [asc: m.inserted_at],
            preload: [:user, :attachments]
          )
          |> Repo.all()

        Logger.info("Found #{length(messages)} messages in conversation #{conversation_id}")

        {:noreply,
         socket
         |> assign(:conversation, conversation)
         |> assign(:selected_conversation, conversation)
         |> assign(:messages, messages)}
      else
        Logger.error("Conversation not found in list: #{conversation_id}")
        {:noreply, put_flash(socket, :error, "Conversation not found")}
      end
    rescue
      error ->
        Logger.error("Error selecting conversation: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Error selecting conversation")}
    end
  end

  @impl true
  def handle_event("switch_conversation_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :conversation_modal_tab, tab)}
  end

  @impl true
  def handle_event("select_channel_for_conversation", %{"channel_id" => channel_id}, socket) do
    channel_id = String.to_integer(channel_id)
    selected_channel = Enum.find(socket.assigns.user_channels, &(&1.id == channel_id))

    {:noreply, assign(socket, :selected_channel, selected_channel)}
  end

  @impl true
  def handle_event("create_channel_conversation", _params, socket) do
    current_user = socket.assigns.current_user
    selected_channel = socket.assigns.selected_channel
    title = socket.assigns.conversation_title

    if is_nil(selected_channel) do
      {:noreply, put_flash(socket, :error, "Please select a channel")}
    else
      try do
        channel_members = Frestyl.Channels.list_channel_members(selected_channel.id)
        member_ids =
          channel_members
          |> Enum.map(& &1.user_id)
          |> Enum.reject(&(&1 == current_user.id))

        if length(member_ids) == 0 do
          {:noreply, put_flash(socket, :error, "No other members in this channel")}
        else
          result = Repo.transaction(fn ->
            final_title = if String.trim(title) == "" do
              "#{selected_channel.name} Chat"
            else
              String.trim(title)
            end

            {:ok, conversation} =
              %Conversation{}
              |> Conversation.changeset(%{
                title: final_title,
                last_message_at: DateTime.utc_now(),
                is_group: true
              })
              |> Repo.insert()

            %ConversationParticipant{}
            |> ConversationParticipant.changeset(%{
              conversation_id: conversation.id,
              user_id: current_user.id
            })
            |> Repo.insert!()

            for user_id <- member_ids do
              %ConversationParticipant{}
              |> ConversationParticipant.changeset(%{
                conversation_id: conversation.id,
                user_id: user_id
              })
              |> Repo.insert!()
            end

            conversation = Repo.preload(conversation, [:participants])
            conversation
          end)

          case result do
            {:ok, conversation} ->
              conversations = [conversation | socket.assigns.conversations]

              {:noreply,
               socket
               |> assign(:conversations, conversations)
               |> assign(:conversation, conversation)
               |> assign(:selected_conversation, conversation)
               |> assign(:messages, [])
               |> assign(:show_new_conversation_modal, false)
               |> assign(:selected_channel, nil)
               |> assign(:conversation_title, "")
               |> put_flash(:info, "Channel conversation created successfully!")}

            {:error, reason} ->
              Logger.error("Failed to create channel conversation: #{inspect(reason)}")
              {:noreply, put_flash(socket, :error, "Failed to create conversation")}
          end
        end
      rescue
        error ->
          Logger.error("Error creating channel conversation: #{inspect(error)}")
          {:noreply, put_flash(socket, :error, "Error creating conversation")}
      end
    end
  end

  @impl true
def handle_event("typing_start", _params, socket) do
  if socket.assigns.conversation do
    user_id = socket.assigns.current_user.id
    conversation_id = socket.assigns.conversation.id

    # Broadcast typing status
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "conversation:#{conversation_id}",
      {:user_typing, user_id, true}
    )
  end

  {:noreply, socket}
end

@impl true
def handle_event("typing_stop", _params, socket) do
  if socket.assigns.conversation do
    user_id = socket.assigns.current_user.id
    conversation_id = socket.assigns.conversation.id

    # Broadcast stop typing status
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "conversation:#{conversation_id}",
      {:user_typing, user_id, false}
    )
  end

  {:noreply, socket}
end

  # Add handler for typing status updates from other users
  @impl true
  def handle_info({:user_typing, user_id, typing}, socket) do
    current_user_id = socket.assigns.current_user.id

    # Don't show typing indicator for current user
    if user_id != current_user_id do
      updated_typing_users =
        if typing do
          MapSet.put(socket.assigns.typing_users, user_id)
        else
          MapSet.delete(socket.assigns.typing_users, user_id)
        end

      {:noreply, assign(socket, :typing_users, updated_typing_users)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_user

    content = String.trim(content)

    # Check for uploaded files
    uploaded_files = socket.assigns.uploads.attachments.entries
    Logger.info("Content: '#{content}', Files: #{length(uploaded_files)}")

    if content == "" && Enum.empty?(uploaded_files) do
      {:noreply, put_flash(socket, :error, "Please enter a message or attach a file")}
    else
      if conversation do
        try do
          result = Repo.transaction(fn ->
            # Fix: For file-only messages, use a default content or make content optional
            message_attrs = %{
              "content" => if(content == "", do: "[File attachment]", else: content)
            }

            case Chat.create_message(message_attrs, current_user, conversation) do
              {:ok, message} ->
                Logger.info("Successfully created message with ID: #{message.id}")

                # Handle file uploads if any
                if not Enum.empty?(uploaded_files) do
                  Logger.info("Processing #{length(uploaded_files)} file uploads")

                  # Process each uploaded file
                  consume_uploaded_entries(socket, :attachments, fn %{path: path}, entry ->
                    Logger.info("Processing file: #{entry.client_name}")

                    # Generate unique filename
                    date_path = Date.utc_today() |> to_string()
                    filename = "#{Ecto.UUID.generate()}-#{entry.client_name}"
                    dest_dir = Path.join(["priv", "static", "uploads", "chat_attachments", date_path])
                    dest = Path.join(dest_dir, filename)

                    # Ensure directory exists
                    File.mkdir_p!(dest_dir)

                    # Copy the file
                    case File.cp(path, dest) do
                      :ok ->
                        attachment_attrs = %{
                          file_name: entry.client_name,
                          content_type: entry.client_type,
                          size: entry.client_size,
                          path: "/uploads/chat_attachments/#{date_path}/#{filename}",
                          message_id: message.id
                        }

                        case Chat.create_attachment(attachment_attrs) do
                          {:ok, attachment} ->
                            Logger.info("Created attachment: #{attachment.id}")
                            {:ok, attachment}
                          {:error, reason} ->
                            Logger.error("Failed to create attachment: #{inspect(reason)}")
                            raise "Failed to create attachment"
                        end
                      {:error, reason} ->
                        Logger.error("Failed to copy file: #{inspect(reason)}")
                        raise "Failed to copy file"
                    end
                  end)

                  Logger.info("Successfully processed files")
                end

                message
              {:error, changeset} ->
                Logger.error("Failed to create message: #{inspect(changeset)}")
                raise "Failed to create message"
            end
          end)

          case result do
            {:ok, _message} ->
              # Clear the form and reset uploads AFTER successful transaction
              socket = socket
                |> push_event("reset-form", %{})
                |> allow_upload(:attachments,
                  accept: ~w(.jpg .jpeg .png .gif .pdf .doc .docx .xls .xlsx .txt .zip .mp3 .mp4 .avi .mov .wav),
                  max_entries: 5,
                  max_file_size: 10_000_000
                )

              {:noreply, socket}

            {:error, reason} ->
              Logger.error("Transaction failed: #{inspect(reason)}")
              {:noreply, put_flash(socket, :error, "Failed to send message")}
          end
        rescue
          error ->
            Logger.error("Error creating message: #{inspect(error)}")
            {:noreply, put_flash(socket, :error, "Error sending message")}
        end
      else
        {:noreply, put_flash(socket, :error, "Please select a conversation")}
      end
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

  @impl true
  def handle_event("archive_conversation", %{"id" => conversation_id}, socket) do
    conversation_id = String.to_integer(conversation_id)

    try do
      case Repo.get(Conversation, conversation_id) |> Repo.preload([:participants]) do
        nil ->
          {:noreply, put_flash(socket, :error, "Conversation not found")}

        conversation ->
          case Conversation.changeset(conversation, %{is_archived: true})
               |> Repo.update() do
            {:ok, _updated_conversation} ->
              for participant <- conversation.participants do
                Phoenix.PubSub.broadcast(
                  Frestyl.PubSub,
                  "user:#{participant.user_id}:conversations",
                  {:conversation_archived, conversation_id}
                )
              end

              conversations = Enum.reject(socket.assigns.conversations, &(&1.id == conversation_id))

              {conversation, selected_conversation} =
                if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
                  {nil, nil}
                else
                  {socket.assigns.conversation, socket.assigns.selected_conversation}
                end

              {:noreply,
               socket
               |> assign(:conversations, conversations)
               |> assign(:conversation, conversation)
               |> assign(:selected_conversation, selected_conversation)
               |> assign(:messages, [])
               |> put_flash(:info, "Conversation archived")}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to archive conversation")}
          end
      end
    rescue
      error ->
        Logger.error("Error archiving conversation: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Error archiving conversation")}
    end
  end

  @impl true
  def handle_event("delete_conversation", %{"id" => conversation_id}, socket) do
    conversation_id = String.to_integer(conversation_id)
    current_user_id = socket.assigns.current_user.id

    try do
      {removed_count, _} =
        from(cp in ConversationParticipant,
          where: cp.conversation_id == ^conversation_id and cp.user_id == ^current_user_id
        )
        |> Repo.delete_all()

      if removed_count > 0 do
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "user:#{current_user_id}:conversations",
          {:conversation_deleted, conversation_id}
        )

        conversations = Enum.reject(socket.assigns.conversations, &(&1.id == conversation_id))

        {conversation, selected_conversation} =
          if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
            {nil, nil}
          else
            {socket.assigns.conversation, socket.assigns.selected_conversation}
          end

        {:noreply,
         socket
         |> assign(:conversations, conversations)
         |> assign(:conversation, conversation)
         |> assign(:selected_conversation, selected_conversation)
         |> assign(:messages, [])
         |> put_flash(:info, "Conversation removed")}
      else
        {:noreply, put_flash(socket, :error, "Failed to remove conversation")}
      end
    rescue
      error ->
        Logger.error("Error deleting conversation: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Error deleting conversation")}
    end
  end

  @impl true
  def handle_event("delete_message", %{"id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    current_user = socket.assigns.current_user

    # Find the message in the current conversation
    message = Enum.find(socket.assigns.messages, fn m -> m.id == message_id end)

    if message && message.user_id == current_user.id do
      # Simplified: just check if it's not already deleted, remove time limit for now
      if !message.metadata || !message.metadata["deleted"] do
        case Chat.delete_message(message_id) do
          {:ok, _deleted_message} ->
            # Update the local messages list to show as deleted
            updated_messages =
              Enum.map(socket.assigns.messages, fn m ->
                if m.id == message_id do
                  %{m | content: "[Message deleted]", metadata: Map.put(m.metadata || %{}, "deleted", true)}
                else
                  m
                end
              end)

            # Broadcast the deletion to other participants
            Phoenix.PubSub.broadcast(
              Frestyl.PubSub,
              "conversation:#{socket.assigns.conversation.id}",
              {:message_deleted, message_id}
            )

            {:noreply,
            socket
            |> assign(:messages, updated_messages)
            |> put_flash(:info, "Message deleted")}

          {:error, reason} ->
            Logger.error("Failed to delete message: #{inspect(reason)}")
            {:noreply, put_flash(socket, :error, "Failed to delete message")}
        end
      else
        {:noreply, put_flash(socket, :error, "Message is already deleted")}
      end
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own messages")}
    end
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    # Update the messages list when someone else deletes a message
    updated_messages =
      Enum.map(socket.assigns.messages, fn m ->
        if m.id == message_id do
          %{m | content: "[Message deleted]", metadata: Map.put(m.metadata || %{}, "deleted", true)}
        else
          m
        end
      end)

    {:noreply, assign(socket, :messages, updated_messages)}
  end

  @impl true
  def handle_info(:submit_message_form, socket) do
    # This will trigger the form submission
    # We'll handle this by pushing an event to the client
    {:noreply, push_event(socket, "submit-form", %{id: "message-form"})}
  end

  @impl true
  def handle_event("clear_all_uploads", _params, socket) do
    socket = allow_upload(socket, :attachments,
      accept: ~w(.jpg .jpeg .png .gif .pdf .doc .docx .xls .xlsx .txt .zip .mp3 .mp4 .avi .mov .wav),
      max_entries: 5,
      max_file_size: 10_000_000
    )
    {:noreply, socket}
  end

  # PubSub Handlers
  @impl true
  def handle_info({:new_message, message_id}, socket) when is_integer(message_id) do
    # Fetch the full message with preloads
    case Message
        |> Repo.get(message_id)
        |> Repo.preload([:user, :attachments]) do
      nil ->
        Logger.warn("Received PubSub for non-existent message ID: #{message_id}")
        {:noreply, socket}

      message ->
        # Update the conversation's last message time in the sidebar list
        updated_conversations =
          Enum.map(socket.assigns.conversations, fn conv ->
            if conv.id == message.conversation_id do
              %{conv | last_message_at: message.inserted_at}
            else
              conv
            end
          end)
          |> Enum.sort_by(& &1.last_message_at, {:desc, NaiveDateTime})

        socket = assign(socket, :conversations, updated_conversations)

        # If the new message belongs to the currently selected conversation, add it to the list
        if socket.assigns.conversation && message.conversation_id == socket.assigns.conversation.id do
          updated_messages = socket.assigns.messages ++ [message]
          {:noreply, assign(socket, :messages, updated_messages)}
        else
          {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_info({:new_message, %{id: message_id}}, socket) do
    handle_info({:new_message, message_id}, socket)
  end


  @impl true
  def handle_info({:conversation_created, conversation}, socket) do
    updated_conversations = [conversation | socket.assigns.conversations]
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "conversation:#{conversation.id}")
    {:noreply, assign(socket, :conversations, updated_conversations)}
  end

  @impl true
  def handle_info({:conversation_archived, conversation_id}, socket) do
    updated_conversations = Enum.reject(socket.assigns.conversations, &(&1.id == conversation_id))

    {conversation, selected_conversation, messages} =
      if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
        {nil, nil, []}
      else
        {socket.assigns.conversation, socket.assigns.selected_conversation, socket.assigns.messages}
      end

    {:noreply,
     socket
     |> assign(:conversations, updated_conversations)
     |> assign(:conversation, conversation)
     |> assign(:selected_conversation, selected_conversation)
     |> assign(:messages, messages)}
  end

  @impl true
  def handle_info({:conversation_deleted, conversation_id}, socket) do
    updated_conversations = Enum.reject(socket.assigns.conversations, &(&1.id == conversation_id))

    {conversation, selected_conversation, messages} =
      if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
        {nil, nil, []}
      else
        {socket.assigns.conversation, socket.assigns.selected_conversation, socket.assigns.messages}
      end

    {:noreply,
     socket
     |> assign(:conversations, updated_conversations)
     |> assign(:conversation, conversation)
     |> assign(:selected_conversation, selected_conversation)
     |> assign(:messages, messages)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # Helper functions
  defp format_file_size(size) when is_nil(size), do: "Unknown size"
  defp format_file_size(size) when size < 1024, do: "#{size} B"
  defp format_file_size(size) when size < 1024 * 1024, do: "#{Float.round(size / 1024, 1)} KB"
  defp format_file_size(size), do: "#{Float.round(size / 1024 / 1024, 1)} MB"

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:too_many_files), do: "Too many files (max 5)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"

@impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      <!-- Conversations Sidebar -->
      <div class="w-80 bg-white shadow-lg border-r border-gray-200">
        <div class="p-4 bg-gradient-to-r from-indigo-600 to-purple-600">
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-lg font-semibold text-white">Chats</h2>
            <button
              phx-click="show_new_conversation_modal"
              class="p-2 bg-white/20 text-white rounded-xl hover:bg-white/30 transition-all duration-200 backdrop-blur-sm"
              title="New Chat"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
              </svg>
            </button>
          </div>

          <!-- Navigation Links -->
          <div class="flex space-x-2">
            <a
              href="/dashboard"
              class="flex items-center px-3 py-2 text-sm text-white/80 hover:text-white hover:bg-white/10 rounded-lg transition-all duration-200"
              title="Go to Dashboard"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"></path>
              </svg>
              Dashboard
            </a>

            <a
              href="/channels"
              class="flex items-center px-3 py-2 text-sm text-white/80 hover:text-white hover:bg-white/10 rounded-lg transition-all duration-200"
              title="Go to Channels"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
              </svg>
              Channels
            </a>
          </div>
        </div>

        <div class="overflow-y-auto h-full pb-4">
          <%= if @conversations && length(@conversations) > 0 do %>
            <%= for conversation <- @conversations do %>
              <div class="relative group mx-2 my-1">
                <button
                  phx-click="select_conversation"
                  phx-value-id={conversation.id}
                  class={[
                    "w-full text-left p-4 rounded-xl transition-all duration-200 border-2",
                    (@selected_conversation && @selected_conversation.id == conversation.id) &&
                    "bg-gradient-to-r from-indigo-50 to-purple-50 border-indigo-200 shadow-md" ||
                    "hover:bg-gradient-to-r hover:from-gray-50 hover:to-blue-50 border-transparent hover:border-blue-100 hover:shadow-sm"
                  ]}
                >
                  <div class="flex items-center">
                    <div class={[
                      "h-12 w-12 rounded-full flex items-center justify-center text-white font-bold text-lg shadow-lg",
                      "bg-gradient-to-br from-indigo-500 to-purple-600"
                    ]}>
                      <%= String.first(conversation.title || "C") %>
                    </div>
                    <div class="ml-3 flex-1 min-w-0">
                      <p class="text-sm font-semibold text-gray-900 truncate">
                        <%= conversation.title || "Conversation ##{conversation.id}" %>
                      </p>
                      <p class="text-xs text-gray-500 truncate">
                        <%= if conversation.last_message_at do %>
                          <%= Calendar.strftime(conversation.last_message_at, "%b %d at %H:%M") %>
                        <% else %>
                          Just created
                        <% end %>
                      </p>
                    </div>
                  </div>
                </button>

                <!-- Action Buttons -->
                <div class="absolute right-3 top-1/2 transform -translate-y-1/2 opacity-0 group-hover:opacity-100 transition-all duration-200 flex space-x-1">
                  <button
                    phx-click="archive_conversation"
                    phx-value-id={conversation.id}
                    class="p-2 rounded-full bg-white shadow-md hover:bg-yellow-50 text-yellow-600 hover:text-yellow-700 transition-all duration-200"
                    title="Archive conversation"
                    data-confirm="Are you sure you want to archive this conversation?"
                  >
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 8l4 4 4-4"></path>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 1h16l-1 20L12 16 5 21z"></path>
                    </svg>
                  </button>

                  <button
                    phx-click="delete_conversation"
                    phx-value-id={conversation.id}
                    class="p-2 rounded-full bg-white shadow-md hover:bg-red-50 text-red-600 hover:text-red-700 transition-all duration-200"
                    title="Leave conversation"
                    data-confirm="Are you sure you want to leave this conversation?"
                  >
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path>
                    </svg>
                  </button>
                </div>
              </div>
            <% end %>
          <% else %>
            <div class="p-6 text-center">
              <div class="bg-gradient-to-br from-indigo-100 to-purple-100 rounded-2xl p-8">
                <div class="bg-gradient-to-br from-indigo-500 to-purple-600 w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4">
                  <svg class="h-8 w-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
                  </svg>
                </div>
                <h3 class="text-lg font-bold text-gray-900 mb-2">No chats yet</h3>
                <p class="text-sm text-gray-600 mb-4">Start a conversation to get chatting</p>
                <button
                  phx-click="show_new_conversation_modal"
                  class="px-6 py-3 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 transition-all duration-200 font-medium shadow-lg"
                >
                  Start Chatting
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Chat Area -->
      <div class="flex-1 flex flex-col bg-gradient-to-br from-white to-gray-50">
        <%= if @conversation do %>
          <!-- Chat Header -->
          <div class="p-6 bg-white shadow-sm border-b border-gray-100">
            <div class="flex items-center">
              <div class="h-10 w-10 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-bold mr-4">
                <%= String.first(@conversation.title || "C") %>
              </div>
              <div>
                <h3 class="text-xl font-bold text-gray-900"><%= @conversation.title %></h3>
                <p class="text-sm text-gray-500">
                  <%= length(@conversation.participants) %> participant(s) | <%= length(@messages || []) %> message(s)
                </p>
              </div>
            </div>
          </div>

          <!-- Messages Display -->
          <div class="flex-1 overflow-y-auto p-6 space-y-4 bg-gradient-to-b from-gray-50/50 to-blue-50/30">
            <%= if @messages && length(@messages) > 0 do %>
              <%= for {message, index} <- Enum.with_index(@messages) do %>
                <% is_own_message = message.user_id == @current_user.id %>
                <% is_same_user_as_previous = index > 0 && Enum.at(@messages, index - 1).user_id == message.user_id %>

                <div class={[
                  "flex",
                  is_own_message && "justify-end" || "justify-start"
                ]}>
                  <div class={[
                    "group max-w-xs lg:max-w-md xl:max-w-lg",
                    is_own_message && "order-2" || "order-1"
                  ]}>
                    <!-- User info (only show if different from previous message) -->
                    <%= if not is_same_user_as_previous do %>
                      <div class={[
                        "flex items-center mb-1",
                        is_own_message && "justify-end" || "justify-start"
                      ]}>
                        <%= unless is_own_message do %>
                          <div class="w-6 h-6 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white text-xs font-bold mr-2">
                            <%= String.first(if message.user, do: message.user.name || message.user.email, else: "U") %>
                          </div>
                        <% end %>
                        <span class={[
                          "text-xs font-medium",
                          is_own_message && "text-indigo-600" || "text-gray-600"
                        ]}>
                          <%= if message.user, do: message.user.name || message.user.email, else: "User #{message.user_id}" %>
                        </span>
                        <span class="text-xs text-gray-400 ml-2">
                          <%= Calendar.strftime(message.inserted_at, "%H:%M") %>
                        </span>

                        <!-- Delete button (only for own messages and if not already deleted) -->
                        <%= if message.user_id == @current_user.id && (!message.metadata || !message.metadata["deleted"]) do %>
                          <button
                            phx-click="delete_message"
                            phx-value-id={message.id}
                            class="opacity-0 group-hover:opacity-100 ml-2 p-1 text-gray-400 hover:text-red-500 transition-all duration-200"
                            title="Delete message"
                            data-confirm="Are you sure you want to delete this message? This action cannot be undone."
                          >
                            <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                            </svg>
                          </button>
                        <% end %>
                      </div>
                    <% end %>

                    <!-- Message bubble -->
                    <%= if message.metadata && message.metadata["deleted"] do %>
                      <div class={[
                        "p-3 rounded-2xl text-sm italic flex items-center",
                        "bg-gray-100 text-gray-500 border border-gray-200"
                      ]}>
                        <svg class="inline h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"></path>
                        </svg>
                        This message was deleted
                      </div>
                    <% else %>
                      <div class={[
                        "p-4 rounded-2xl shadow-sm relative",
                        if is_own_message do
                          "bg-gradient-to-br from-indigo-600 to-purple-600 text-white rounded-br-md"
                        else
                          "bg-white border border-gray-200 text-gray-900 rounded-bl-md"
                        end
                      ]}>
                        <!-- Message tail/pointer -->
                        <div class={[
                          "absolute w-0 h-0 top-0",
                          if is_own_message do
                            "right-0 border-l-8 border-l-indigo-600 border-t-8 border-t-transparent"
                          else
                            "left-0 border-r-8 border-r-white border-t-8 border-t-transparent"
                          end
                        ]}></div>

                        <!-- Regular message content -->
                        <%= if message.content && String.trim(message.content) != "" && message.content != "[File attachment]" do %>
                          <div class="text-sm leading-relaxed break-words">
                            <%= message.content %>
                          </div>
                        <% end %>

                        <!-- Message Attachments -->
                        <%= if message.attachments && length(message.attachments) > 0 do %>
                          <div class={[
                            "space-y-3",
                            message.content && String.trim(message.content) != "" && message.content != "[File attachment]" && "mt-3"
                          ]}>
                            <%= for attachment <- message.attachments do %>
                              <div class="bg-white/10 rounded-xl overflow-hidden backdrop-blur-sm">
                                <%= cond do %>
                                  <% String.starts_with?(attachment.content_type, "image/") -> %>
                                    <!-- Image Display -->
                                    <div class="relative">
                                      <img
                                        src={attachment.path}
                                        alt={attachment.file_name}
                                        class="max-w-full rounded-xl cursor-pointer hover:opacity-90 transition-opacity"
                                        onclick="window.open(this.src, '_blank')"
                                      />
                                      <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/60 to-transparent p-3">
                                        <p class="text-xs text-white font-medium"><%= attachment.file_name %></p>
                                      </div>
                                    </div>

                                  <% String.starts_with?(attachment.content_type, "video/") -> %>
                                    <!-- Video Display -->
                                    <div class="space-y-2">
                                      <video controls class="max-w-full rounded-lg">
                                        <source src={attachment.path} type={attachment.content_type} />
                                        Your browser does not support video playback.
                                      </video>
                                      <div class="px-3 pb-2">
                                        <p class="text-xs font-medium opacity-80"><%= attachment.file_name %></p>
                                      </div>
                                    </div>

                                  <% String.starts_with?(attachment.content_type, "audio/") -> %>
                                    <!-- Audio Display -->
                                    <div class="p-3">
                                      <div class="flex items-center space-x-3 mb-3">
                                        <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
                                          <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
                                          </svg>
                                        </div>
                                        <div class="flex-1 min-w-0">
                                          <p class="text-sm font-medium opacity-90 truncate"><%= attachment.file_name %></p>
                                          <p class="text-xs opacity-70"><%= format_file_size(attachment.size) %></p>
                                        </div>
                                      </div>
                                      <audio controls class="w-full">
                                        <source src={attachment.path} type={attachment.content_type} />
                                        Your browser does not support audio playback.
                                      </audio>
                                    </div>

                                  <% true -> %>
                                    <!-- File Download Link -->
                                    <div class="p-3">
                                      <a
                                        href={attachment.path}
                                        target="_blank"
                                        class="flex items-center space-x-3 group"
                                      >
                                        <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center">
                                          <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                                          </svg>
                                        </div>
                                        <div class="flex-1 min-w-0">
                                          <p class="text-sm font-medium opacity-90 group-hover:opacity-100 transition-opacity truncate">
                                            <%= attachment.file_name %>
                                          </p>
                                          <p class="text-xs opacity-70">
                                            <%= format_file_size(attachment.size) %> • Click to download
                                          </p>
                                        </div>
                                        <svg class="h-4 w-4 opacity-70 group-hover:opacity-100 transition-opacity" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path>
                                        </svg>
                                      </a>
                                    </div>
                                <% end %>
                              </div>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% else %>
              <div class="flex-1 flex items-center justify-center">
                <div class="text-center">
                  <div class="bg-gradient-to-br from-indigo-100 to-purple-100 w-24 h-24 rounded-full flex items-center justify-center mx-auto mb-4">
                    <svg class="h-12 w-12 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
                    </svg>
                  </div>
                  <h3 class="text-lg font-semibold text-gray-900 mb-2">No messages yet</h3>
                  <p class="text-sm text-gray-500">This conversation is empty. Send the first message!</p>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Typing Indicator -->
          <%= if MapSet.size(@typing_users) > 0 do %>
            <div class="px-6 py-3 border-t border-gray-100 bg-white/50 backdrop-blur-sm">
              <div class="flex items-center space-x-2 text-sm text-gray-600">
                <div class="flex space-x-1">
                  <%= case MapSet.size(@typing_users) do %>
                    <% 1 -> %>
                      <% user_id = @typing_users |> MapSet.to_list() |> hd() %>
                      <% user = Map.get(@users_map, user_id, %{name: "Someone"}) %>
                      <div class="w-6 h-6 rounded-full bg-gradient-to-br from-green-500 to-emerald-600 flex items-center justify-center text-white text-xs font-bold">
                        <%= String.first(user.name || user.email || "S") %>
                      </div>
                      <span class="font-medium"><%= user.name || user.email || "Someone" %></span>
                      <span>is typing</span>
                    <% 2 -> %>
                      <% [user1_id, user2_id] = @typing_users |> MapSet.to_list() %>
                      <% user1 = Map.get(@users_map, user1_id, %{name: "Someone"}) %>
                      <% user2 = Map.get(@users_map, user2_id, %{name: "Someone"}) %>
                      <div class="flex -space-x-1">
                        <div class="w-6 h-6 rounded-full bg-gradient-to-br from-green-500 to-emerald-600 flex items-center justify-center text-white text-xs font-bold ring-2 ring-white">
                          <%= String.first(user1.name || user1.email || "S") %>
                        </div>
                        <div class="w-6 h-6 rounded-full bg-gradient-to-br from-blue-500 to-cyan-600 flex items-center justify-center text-white text-xs font-bold ring-2 ring-white">
                          <%= String.first(user2.name || user2.email || "S") %>
                        </div>
                      </div>
                      <span class="font-medium"><%= user1.name || user1.email || "Someone" %></span>
                      <span>and</span>
                      <span class="font-medium"><%= user2.name || user2.email || "Someone" %></span>
                      <span>are typing</span>
                    <% count when count > 2 -> %>
                      <div class="w-6 h-6 rounded-full bg-gradient-to-br from-purple-500 to-pink-600 flex items-center justify-center text-white text-xs font-bold">
                        <%= count %>
                      </div>
                      <span>Several people are typing</span>
                  <% end %>
                </div>
                <div class="typing-dots flex space-x-1">
                  <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
                  <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.1s;"></div>
                  <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s;"></div>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Message Form with File Uploads -->
          <div class="p-4 bg-white border-t border-gray-100">
            <!-- Drag and drop overlay -->
            <div
              id="drag-overlay"
              phx-hook="DragAndDrop"
              class="hidden fixed inset-0 bg-black bg-opacity-50 z-40 flex items-center justify-center"
            >
              <div class="bg-white rounded-2xl p-8 text-center border-2 border-dashed border-indigo-300 mx-4">
                <div class="bg-gradient-to-br from-indigo-500 to-purple-600 w-20 h-20 rounded-2xl flex items-center justify-center mx-auto mb-4">
                  <svg class="h-10 w-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
                  </svg>
                </div>
                <p class="text-xl font-bold text-gray-900 mb-2">Drop files here to attach</p>
                <p class="text-gray-600">or click the paperclip to browse</p>
              </div>
            </div>

            <!-- Uploaded files preview -->
            <%= if not Enum.empty?(@uploads.attachments.entries) do %>
              <div class="mb-4 p-4 bg-gradient-to-r from-indigo-50 to-purple-50 rounded-xl border border-indigo-100">
                <div class="flex items-center justify-between mb-3">
                  <h4 class="text-sm font-semibold text-gray-900 flex items-center">
                    <svg class="h-4 w-4 mr-2 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"></path>
                    </svg>
                    Files to send:
                  </h4>
                  <button
                    type="button"
                    phx-click="clear_all_uploads"
                    class="text-sm text-gray-500 hover:text-red-600 transition-colors font-medium"
                  >
                    Clear all
                  </button>
                </div>
                <div class="space-y-3">
                  <%= for entry <- @uploads.attachments.entries do %>
                    <div class="flex items-center justify-between p-3 bg-white rounded-lg border border-gray-200 shadow-sm">
                      <div class="flex items-center space-x-3">
                        <!-- File type icon with gradient -->
                        <%= cond do %>
                          <% String.starts_with?(entry.client_type, "image/") -> %>
                            <div class="w-10 h-10 rounded-lg bg-gradient-to-br from-pink-500 to-red-500 flex items-center justify-center">
                              <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                              </svg>
                            </div>
                          <% String.starts_with?(entry.client_type, "video/") -> %>
                            <div class="w-10 h-10 rounded-lg bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
                              <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path>
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                              </svg>
                            </div>
                          <% String.starts_with?(entry.client_type, "audio/") -> %>
                            <div class="w-10 h-10 rounded-lg bg-gradient-to-br from-red-500 to-yellow-500 flex items-center justify-center">
                              <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
                              </svg>
                            </div>
                          <% true -> %>
                            <div class="w-10 h-10 rounded-lg bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center">
                              <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                              </svg>
                            </div>
                        <% end %>

                        <div class="flex-1 min-w-0">
                          <p class="text-sm font-medium text-gray-900 truncate"><%= entry.client_name %></p>
                          <p class="text-xs text-gray-500"><%= format_file_size(entry.client_size) %></p>
                        </div>
                      </div>

                      <div class="flex items-center space-x-3">
                        <!-- Progress bar (if needed) -->
                        <%= if entry.progress > 0 and entry.progress < 100 do %>
                          <div class="w-20 bg-gray-200 rounded-full h-2">
                            <div class="bg-gradient-to-r from-indigo-600 to-purple-600 h-2 rounded-full transition-all duration-300" style={"width: #{entry.progress}%"}></div>
                          </div>
                        <% end %>

                        <!-- Remove button -->
                        <button
                          type="button"
                          phx-click="cancel_upload"
                          phx-value-ref={entry.ref}
                          class="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-all duration-200"
                          title="Remove file"
                        >
                          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                          </svg>
                        </button>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Upload errors -->
            <%= if not Enum.empty?(@uploads.attachments.errors) do %>
              <div class="mb-4 p-4 bg-gradient-to-r from-red-50 to-pink-50 border border-red-200 rounded-xl">
                <div class="flex items-center mb-2">
                  <svg class="h-5 w-5 text-red-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                  </svg>
                  <h4 class="text-sm font-semibold text-red-800">Upload Errors:</h4>
                </div>
                <%= for err <- @uploads.attachments.errors do %>
                  <p class="text-sm text-red-600 ml-7">• <%= error_to_string(err) %></p>
                <% end %>
              </div>
            <% end %>

            <!-- Message form -->
            <form
              id="message-form"
              phx-hook="MessageForm"
              phx-submit="send_message"
              phx-change="validate"
              phx-drop-target={@uploads.attachments.ref}
              class="relative"
            >
              <div class="relative flex items-end space-x-3 p-4 bg-white rounded-2xl border-2 border-gray-200 focus-within:border-indigo-500 focus-within:ring-4 focus-within:ring-indigo-100 transition-all duration-200 shadow-sm">
                <!-- Hidden file input -->
                <.live_file_input upload={@uploads.attachments} class="hidden" />

                <!-- Message textarea with paperclip -->
                <div class="flex-1 relative">
                  <textarea
                    id="message-textarea"
                    name="content"
                    phx-hook="AutoResize"
                    rows="1"
                    class="block w-full pr-12 border-0 resize-none focus:ring-0 focus:outline-none placeholder-gray-400 text-gray-900"
                    placeholder="Type your message..."
                  ></textarea>

                  <!-- Paperclip button -->
                  <button
                    type="button"
                    onclick="document.querySelector('[data-phx-upload-ref]').click()"
                    class="absolute right-2 top-1/2 transform -translate-y-1/2 p-2 text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-all duration-200"
                    title="Attach files"
                  >
                    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"></path>
                    </svg>
                  </button>
                </div>

                <!-- Send button -->
                <button
                  type="submit"
                  class="flex-shrink-0 inline-flex items-center justify-center w-12 h-12 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 focus:outline-none focus:ring-4 focus:ring-indigo-100 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 shadow-lg"
                  title="Send message"
                >
                  <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path>
                  </svg>
                </button>
              </div>
            </form>
          </div>

        <% else %>
          <div class="flex-1 flex items-center justify-center p-8">
            <div class="text-center max-w-md mx-auto">
              <div class="bg-gradient-to-br from-indigo-100 to-purple-100 w-32 h-32 rounded-3xl flex items-center justify-center mx-auto mb-6">
                <div class="bg-gradient-to-br from-indigo-600 to-purple-600 w-20 h-20 rounded-2xl flex items-center justify-center">
                  <svg class="h-10 w-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
                  </svg>
                </div>
              </div>
              <h3 class="text-2xl font-bold text-gray-900 mb-3">No conversation selected</h3>
              <p class="text-gray-600 mb-6">Choose a conversation to start messaging or create a new one</p>
              <button
                phx-click="show_new_conversation_modal"
                class="px-6 py-3 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 transition-all duration-200 font-semibold shadow-lg"
              >
                New Conversation
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- New Conversation Modal -->
      <%= if @show_new_conversation_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full max-h-[90vh] overflow-hidden">
            <div class="bg-gradient-to-r from-indigo-600 to-purple-600 p-6">
              <div class="flex justify-between items-center">
                <h3 class="text-xl font-bold text-white">New Chat</h3>
                <button
                  phx-click="hide_new_conversation_modal"
                  class="p-2 text-white/80 hover:text-white hover:bg-white/10 rounded-lg transition-all duration-200"
                >
                  <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                  </svg>
                </button>
              </div>
            </div>

            <!-- Tab Navigation -->
            <div class="flex bg-gray-50">
              <button
                phx-click="switch_conversation_tab"
                phx-value-tab="users"
                class={[
                  "flex-1 px-6 py-4 text-sm font-semibold border-b-2 transition-all duration-200 flex items-center justify-center",
                  (@conversation_modal_tab == "users" &&
                    "border-indigo-500 text-indigo-600 bg-white" ||
                    "border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-100")
                ]}
              >
                <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
                </svg>
                Direct Chat
              </button>
              <button
                phx-click="switch_conversation_tab"
                phx-value-tab="channels"
                class={[
                  "flex-1 px-6 py-4 text-sm font-semibold border-b-2 transition-all duration-200 flex items-center justify-center",
                  (@conversation_modal_tab == "channels" &&
                    "border-indigo-500 text-indigo-600 bg-white" ||
                    "border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-100")
                ]}
              >
                <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                </svg>
                Channel Chat
              </button>
            </div>

            <div class="p-6 overflow-y-auto max-h-96">
              <!-- Chat Title Input -->
              <div class="mb-6">
                <label class="block text-sm font-semibold text-gray-700 mb-3">
                  Chat Name (optional)
                </label>
                <input
                  type="text"
                  value={@conversation_title}
                  phx-keyup="update_conversation_title"
                  name="title"
                  class="w-full border-2 border-gray-200 rounded-xl px-4 py-3 focus:outline-none focus:ring-4 focus:ring-indigo-100 focus:border-indigo-500 transition-all duration-200"
                  placeholder="Enter a name or leave blank for auto-generated"
                />
              </div>

              <!-- Tab Content -->
              <%= if @conversation_modal_tab == "users" do %>
                <!-- Direct Chat Tab -->
                <div class="mb-6">
                  <label class="block text-sm font-semibold text-gray-700 mb-3">
                    Select People to Chat With
                  </label>
                  <div class="max-h-64 overflow-y-auto border-2 border-gray-200 rounded-xl">
                    <%= if length(@available_users) > 0 do %>
                      <%= for user <- @available_users do %>
                        <div
                          class="flex items-center p-4 hover:bg-gradient-to-r hover:from-indigo-50 hover:to-purple-50 cursor-pointer transition-all duration-200 border-b border-gray-100 last:border-b-0"
                          phx-click="toggle_user_selection"
                          phx-value-user_id={user.id}
                        >
                          <div class="flex items-center flex-1">
                            <div class="h-10 w-10 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white text-sm font-bold mr-3 shadow-md">
                              <%= String.first(user.name || user.email || "U") %>
                            </div>
                            <div>
                              <p class="text-sm font-semibold text-gray-900">
                                <%= user.name || user.email %>
                              </p>
                              <%= if user.name && user.email do %>
                                <p class="text-xs text-gray-500"><%= user.email %></p>
                              <% end %>
                            </div>
                          </div>

                          <!-- Checkbox -->
                          <div class="ml-auto">
                            <%= if user.id in @selected_users do %>
                              <div class="w-6 h-6 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-full flex items-center justify-center shadow-sm">
                                <svg class="h-4 w-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                                  <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
                                </svg>
                              </div>
                            <% else %>
                              <div class="w-6 h-6 border-2 border-gray-300 rounded-full"></div>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    <% else %>
                      <div class="p-8 text-center">
                        <div class="bg-gradient-to-br from-gray-100 to-gray-200 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-3">
                          <svg class="h-8 w-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>
                          </svg>
                        </div>
                        <p class="text-sm font-medium text-gray-900 mb-1">No users from your channels available</p>
                        <p class="text-xs text-gray-500">Users you can chat with appear here</p>
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Selected Users Summary -->
                <%= if length(@selected_users) > 0 do %>
                  <div class="mb-6 p-4 bg-gradient-to-r from-indigo-50 to-purple-50 rounded-xl border border-indigo-200">
                    <p class="text-sm font-semibold text-indigo-900 mb-3">
                      <%= length(@selected_users) %>
                      <%= if length(@selected_users) == 1, do: "person", else: "people" %> selected
                    </p>
                    <div class="flex flex-wrap gap-2">
                      <%= for user_id <- @selected_users do %>
                        <% user = Enum.find(@available_users, &(&1.id == user_id)) %>
                        <%= if user do %>
                          <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-indigo-600 to-purple-600 text-white shadow-sm">
                            <%= user.name || String.slice(user.email, 0, 10) %>
                          </span>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <!-- Action Buttons for Direct Chat -->
                <div class="flex space-x-3">
                  <button
                    phx-click="hide_new_conversation_modal"
                    class="flex-1 px-4 py-3 border-2 border-gray-200 rounded-xl text-gray-700 hover:bg-gray-50 transition-all duration-200 font-medium"
                  >
                    Cancel
                  </button>
                  <button
                    phx-click="create_conversation"
                    class={[
                      "flex-1 px-4 py-3 rounded-xl text-white font-semibold transition-all duration-200 shadow-lg",
                      (length(@selected_users) > 0 && "bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700") || "bg-gray-300 cursor-not-allowed"
                    ]}
                    disabled={length(@selected_users) == 0}
                  >
                    Start Chat
                  </button>
                </div>
              <% else %>
                <!-- Channel Chat Tab -->
                <div class="mb-6">
                  <label class="block text-sm font-semibold text-gray-700 mb-3">
                    Select a Channel
                  </label>
                  <div class="max-h-64 overflow-y-auto border-2 border-gray-200 rounded-xl">
                    <%= if length(@user_channels || []) > 0 do %>
                      <%= for channel <- @user_channels do %>
                        <div
                          class="flex items-center p-4 hover:bg-gradient-to-r hover:from-blue-50 hover:to-indigo-50 cursor-pointer transition-all duration-200 border-b border-gray-100 last:border-b-0"
                          phx-click="select_channel_for_conversation"
                          phx-value-channel_id={channel.id}
                        >
                          <div class="flex items-center flex-1">
                            <div class="h-10 w-10 rounded-lg bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white text-sm font-bold mr-3 shadow-md">
                              <%= String.first(channel.name || "C") %>
                            </div>
                            <div>
                              <p class="text-sm font-semibold text-gray-900">
                                <%= channel.name %>
                              </p>
                              <p class="text-xs text-gray-500">
                                <%= channel.member_count || 0 %> members
                              </p>
                            </div>
                          </div>

                          <!-- Radio button -->
                          <div class="ml-auto">
                            <%= if @selected_channel && @selected_channel.id == channel.id do %>
                              <div class="w-6 h-6 bg-gradient-to-br from-blue-600 to-indigo-600 rounded-full flex items-center justify-center shadow-sm">
                                <svg class="h-4 w-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                                  <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
                                </svg>
                              </div>
                            <% else %>
                              <div class="w-6 h-6 border-2 border-gray-300 rounded-full"></div>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    <% else %>
                      <div class="p-8 text-center">
                        <div class="bg-gradient-to-br from-gray-100 to-gray-200 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-3">
                          <svg class="h-8 w-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
                          </svg>
                        </div>
                        <p class="text-sm font-medium text-gray-900 mb-1">No channels available</p>
                        <p class="text-xs text-gray-500">Join a channel to start group chats</p>
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Selected Channel Summary -->
                <%= if @selected_channel do %>
                  <div class="mb-6 p-4 bg-gradient-to-r from-blue-50 to-indigo-50 rounded-xl border border-blue-200">
                    <p class="text-sm font-semibold text-blue-900 mb-2">
                      Creating chat for <span class="font-bold"><%= @selected_channel.name %></span>
                    </p>
                    <p class="text-xs text-blue-700">
                      All channel members will be added to this chat
                    </p>
                  </div>
                <% end %>

                <!-- Action Buttons for Channel Chat -->
                <div class="flex space-x-3">
                  <button
                    phx-click="hide_new_conversation_modal"
                    class="flex-1 px-4 py-3 border-2 border-gray-200 rounded-xl text-gray-700 hover:bg-gray-50 transition-all duration-200 font-medium"
                  >
                    Cancel
                  </button>
                  <button
                    phx-click="create_channel_conversation"
                    class={[
                      "flex-1 px-4 py-3 rounded-xl text-white font-semibold transition-all duration-200 shadow-lg",
                      (@selected_channel && "bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700") || "bg-gray-300 cursor-not-allowed"
                    ]}
                    disabled={is_nil(@selected_channel)}
                  >
                    Start Channel Chat
                  </button>
                </div>
              <% end %>

              <!-- Development option -->
              <div class="mt-6 pt-6 border-t border-gray-200">
                <button
                  phx-click="create_test_conversation"
                  class="w-full px-4 py-3 text-sm text-gray-600 hover:text-gray-800 hover:bg-gray-50 rounded-xl transition-all duration-200 font-medium"
                >
                  Create empty test chat
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    # This handler is required for uploads to work properly
    {:noreply, socket}
  end

  @impl true
  def handle_event("debug_uploads", _params, socket) do
    Logger.info("=== MANUAL DEBUG ===")
    Logger.info("Full socket.assigns: #{inspect(Map.keys(socket.assigns))}")
    Logger.info("Uploads assign: #{inspect(socket.assigns[:uploads])}")
    if socket.assigns[:uploads] do
      Logger.info("Uploads.attachments: #{inspect(socket.assigns.uploads[:attachments])}")
      if socket.assigns.uploads[:attachments] do
        Logger.info("Entries: #{inspect(socket.assigns.uploads.attachments.entries)}")
      end
    end
    Logger.info("=== END MANUAL DEBUG ===")
    {:noreply, put_flash(socket, :info, "Check logs for upload debug info")}
  end

  @impl true
  def handle_event("debug_uploads", _params, socket) do
    Logger.info("=== DEBUG UPLOADS HANDLER ===")
    Logger.info("Full uploads assign: #{inspect(socket.assigns.uploads, pretty: true)}")
    Logger.info("Attachments entries: #{inspect(socket.assigns.uploads.attachments.entries, pretty: true)}")
    Logger.info("Attachments errors: #{inspect(socket.assigns.uploads.attachments.errors, pretty: true)}")

    # Try to get more info about the upload configuration
    Logger.info("Upload config: #{inspect(socket.assigns.uploads.attachments, pretty: true)}")

    {:noreply, put_flash(socket, :info, "Check server logs for upload debug info")}
  end
end
