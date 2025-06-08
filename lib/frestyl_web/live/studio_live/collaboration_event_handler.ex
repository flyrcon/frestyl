defmodule FrestylWeb.StudioLive.CollaborationEventHandler do
  @moduledoc """
  Handles collaboration-related events for the Studio LiveView.
  """

  import Phoenix.LiveView
  import Phoenix.Component
  require Logger

  alias Phoenix.PubSub

  # Permission helpers
  defp can_edit_text?(permissions), do: Map.get(permissions, :can_edit_text, false)
  defp can_edit_audio?(permissions), do: Map.get(permissions, :can_edit_audio, false)
  defp can_edit_session?(permissions), do: Map.get(permissions, :can_edit_session, false)

  # Notification helper
  defp add_notification(socket, message, type \\ :info) do
    notification = %{
      id: System.unique_integer([:positive]),
      type: type,
      message: message,
      timestamp: DateTime.utc_now()
    }
    notifications = [notification | (socket.assigns[:notifications] || [])] |> Enum.take(5)
    assign(socket, notifications: notifications)
  end

  # Text Editing Events
  def handle_text_event("text_update", %{"content" => new_content, "selection" => selection}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.session.id
      workspace_state = socket.assigns.workspace_state

      current_content = workspace_state.text.content

      # Generate text operations (diff between old and new content)
      text_ops = generate_text_operations(current_content, new_content)

      if length(text_ops) > 0 do
        # Create OT operation
        current_version = workspace_state.text.version
        operation = TextOp.new(text_ops, user_id, current_version)

        # Apply operation locally
        new_workspace_state = OT.apply_operation(workspace_state, operation)

        # Update cursors
        text_state = new_workspace_state.text
        new_cursors = Map.put(text_state.cursors, user_id, selection)
        new_text_state = %{text_state | cursors: new_cursors}
        new_workspace_state = Map.put(new_workspace_state, :text, new_text_state)

        # Broadcast operation
        PubSub.broadcast(
          Frestyl.PubSub,
          "studio:#{session_id}:operations",
          {:new_operation, operation}
        )

        # Save state
        save_workspace_state_async(session_id, new_workspace_state)

        {:noreply, LiveView.assign(socket, workspace_state: new_workspace_state)}
      else
        # No text changes, just update cursor
        text_state = workspace_state.text
        new_cursors = Map.put(text_state.cursors, user_id, selection)
        new_text_state = %{text_state | cursors: new_cursors}
        new_workspace_state = Map.put(workspace_state, :text, new_text_state)

        {:noreply, LiveView.assign(socket, workspace_state: new_workspace_state)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_text_event("text_cursor_update", %{"cursor" => cursor, "selection" => selection}, socket) do
    user_id = socket.assigns.current_user.id
    workspace_state = socket.assigns.workspace_state

    # Update just cursor position without creating operations
    text_state = workspace_state.text
    new_cursors = Map.put(text_state.cursors, user_id, %{cursor: cursor, selection: selection})
    new_text_state = %{text_state | cursors: new_cursors}
    new_workspace_state = Map.put(workspace_state, :text, new_text_state)

    # Broadcast cursor update
    PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{socket.assigns.session.id}",
      {:cursor_update, user_id, cursor, selection}
    )

    {:noreply, LiveView.assign(socket, workspace_state: new_workspace_state)}
  end

  # Chat Events
  def handle_chat_message(message, socket) when is_binary(message) and message != "" do
    user = socket.assigns.current_user
    session_id = socket.assigns.session.id

    # Create message using existing Sessions context
    message_params = %{
      content: message,
      user_id: user.id,
      session_id: session_id,
      message_type: "text"
    }

    case Sessions.create_message(message_params) do
      {:ok, new_message} ->
        # Broadcast using existing chat pattern
        message_data = %{
          id: new_message.id,
          content: new_message.content,
          user_id: new_message.user_id,
          username: user.username,
          avatar_url: user.avatar_url,
          inserted_at: new_message.inserted_at
        }

        PubSub.broadcast(Frestyl.PubSub, "session:#{session_id}:chat", {:new_message, message_data})

        # Update typing status
        update_presence(session_id, user.id, %{is_typing: false})

        {:noreply, LiveView.assign(socket, message_input: "")}

      {:error, _changeset} ->
        {:noreply, socket |> LiveView.put_flash(:error, "Could not send message")}
    end
  end

  def handle_chat_message(_message, socket), do: {:noreply, socket}

  # Document Management Events
  def handle_event("create_new_document", %{"document_type" => doc_type} = params, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      user = socket.assigns.current_user
      session_id = socket.assigns.session.id

      document_attrs = %{
        "document_type" => doc_type,
        "title" => params["title"] || "Untitled Document",
        "guided_setup" => params["guided_setup"] || true,
        "collaboration_mode" => params["collaboration_mode"] || "open"
      }

      case Content.create_document(document_attrs, user, session_id) do
        {:ok, document} ->
          # Update workspace state
          new_workspace_state = socket.assigns.workspace_state
          |> put_in([:text, :document], document)
          |> put_in([:text, :active_document_id], document.id)

          # Broadcast document creation to collaborators
          PubSub.broadcast(
            Frestyl.PubSub,
            "studio:#{session_id}",
            {:document_created, document, user.id}
          )

          {:noreply, socket
            |> LiveView.assign(workspace_state: new_workspace_state)
            |> LiveView.assign(active_tool: "text")
            |> add_notification("Document created: #{document.title}", :success)}

        {:error, changeset} ->
          error_message = extract_error_message(changeset)
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to create document: #{error_message}")}
      end
    else
      {:noreply, socket |> LiveView.put_flash(:error, "You don't have permission to create documents")}
    end
  end

  def handle_event("load_existing_document", %{"document_id" => document_id}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id

      case Content.get_document_for_user(document_id, user_id) do
        {:ok, document_data} ->
          # Update workspace state with loaded document
          new_workspace_state = socket.assigns.workspace_state
          |> put_in([:text, :document], document_data.document)
          |> put_in([:text, :active_document_id], document_id)

          # Subscribe to document updates
          PubSub.subscribe(Frestyl.PubSub, "document:#{document_id}")

          {:noreply, socket
            |> LiveView.assign(workspace_state: new_workspace_state)
            |> LiveView.assign(active_tool: "text")
            |> add_notification("Document loaded: #{document_data.document.title}", :info)}

        {:error, :not_found} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Document not found")}

        {:error, :access_denied} ->
          {:noreply, socket |> LiveView.put_flash(:error, "You don't have access to this document")}
      end
    else
      {:noreply, socket |> LiveView.put_flash(:error, "You don't have permission to access documents")}
    end
  end

  # Audio-Text Sync Events
  def handle_event("create_text_block", %{"content" => content, "type" => type}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id

      block = %{
        content: content,
        type: type,
        created_by: socket.assigns.current_user.id,
        created_at: DateTime.utc_now()
      }

      case Frestyl.Studio.AudioTextSync.add_text_block(session_id, block) do
        {:ok, new_block} ->
          {:noreply, socket |> add_notification("Added #{type}", :success)}

        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Failed to add block: #{reason}")}
      end
    else
      {:noreply, socket |> LiveView.put_flash(:error, "You don't have permission to edit text")}
    end
  end

  def handle_event("sync_text_to_audio", %{"block_id" => block_id, "position" => position}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      session_id = socket.assigns.session.id
      position_float = String.to_float(position)

      case Frestyl.Studio.AudioTextSync.sync_text_block(session_id, block_id, position_float) do
        {:ok, sync_point} ->
          {:noreply, socket
            |> add_notification("Text synced to #{format_time(position_float)}", :success)
            |> LiveView.push_event("text_synced", %{block_id: block_id, position: position_float})}

        {:error, reason} ->
          {:noreply, socket |> LiveView.put_flash(:error, "Sync failed: #{reason}")}
      end
    else
      {:noreply, socket |> LiveView.put_flash(:error, "You don't have permission to sync audio")}
    end
  end

  # Handle incoming collaboration messages
  def handle_info({:new_operation, remote_operation}, socket) do
    # Don't process our own operations
    if remote_operation.user_id != socket.assigns.current_user.id do
      current_workspace = socket.assigns.workspace_state

      # Apply remote operation
      new_workspace_state = OT.apply_operation(current_workspace, remote_operation)

      # Notify about the update
      username = get_username_from_collaborators(remote_operation.user_id, socket.assigns.collaborators)
      message = format_operation_message(remote_operation, username)

      socket = if message do
        add_notification(socket, message, :info)
      else
        socket
      end

      {:noreply, LiveView.assign(socket, workspace_state: new_workspace_state)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:operation_acknowledged, timestamp, user_id}, socket) do
    if user_id == socket.assigns.current_user.id do
      # Remove acknowledged operation from pending list if we're tracking them
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:cursor_update, user_id, cursor, selection}, socket) do
    if user_id != socket.assigns.current_user.id do
      # Update remote cursor position
      workspace_state = socket.assigns.workspace_state
      text_state = workspace_state.text
      new_cursors = Map.put(text_state.cursors, user_id, %{cursor: cursor, selection: selection})
      new_text_state = %{text_state | cursors: new_cursors}
      new_workspace_state = Map.put(workspace_state, :text, new_text_state)

      {:noreply, LiveView.assign(socket, workspace_state: new_workspace_state)}
    else
      {:noreply, socket}
    end
  end

  # Chat message handlers
  def handle_chat_info({:new_message, message}, socket) do
    updated_messages = socket.assigns.chat_messages ++ [message]

    notifications = if message.user_id != socket.assigns.current_user.id do
      [%{
        id: System.unique_integer([:positive]),
        type: :new_message,
        message: "New message from #{message.username}",
        timestamp: DateTime.utc_now()
      } | socket.assigns.notifications]
    else
      socket.assigns.notifications
    end

    {:noreply, socket
      |> LiveView.assign(chat_messages: updated_messages)
      |> LiveView.assign(notifications: notifications)}
  end

  def handle_chat_info({:user_typing, user_id, typing}, socket) do
    current_user_id = socket.assigns.current_user.id

    if user_id != current_user_id do
      updated_typing_users = if typing do
        MapSet.put(socket.assigns.typing_users || MapSet.new(), user_id)
      else
        MapSet.delete(socket.assigns.typing_users || MapSet.new(), user_id)
      end

      {:noreply, LiveView.assign(socket, typing_users: updated_typing_users)}
    else
      {:noreply, socket}
    end
  end

  # Document update handlers
  def handle_info({:document_updated, %{blocks: updated_blocks, user_id: user_id}}, socket) do
    if user_id != socket.assigns.current_user.id do
      # Update local document state with remote changes
      new_workspace_state = put_in(
        socket.assigns.workspace_state,
        [:text, :document, :blocks],
        updated_blocks
      )

      username = get_username_from_collaborators(user_id, socket.assigns.collaborators)

      {:noreply, socket
        |> LiveView.assign(workspace_state: new_workspace_state)
        |> add_notification("#{username} updated the document", :info)
        |> LiveView.push_event("document_updated_remotely", %{blocks: updated_blocks})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:document_created, document, user_id}, socket) do
    if user_id != socket.assigns.current_user.id do
      username = get_username_from_collaborators(user_id, socket.assigns.collaborators)

      {:noreply, socket
        |> add_notification("#{username} created a new document: #{document.title}", :info)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(message, socket) do
    Logger.debug("Unhandled collaboration message: #{inspect(message)}")
    {:noreply, socket}
  end

  # Private Helper Functions

  defp generate_text_operations(old_content, new_content) do
    # Simple diff algorithm - in production you'd use a more sophisticated one
    cond do
      old_content == new_content ->
        []

      String.length(new_content) > String.length(old_content) ->
        # Content was inserted
        insertion_point = find_insertion_point(old_content, new_content)
        inserted_text = String.slice(new_content, insertion_point, String.length(new_content) - String.length(old_content))

        ops = []
        ops = if insertion_point > 0, do: [{:retain, insertion_point} | ops], else: ops
        ops = [{:insert, inserted_text} | ops]
        remaining = String.length(old_content) - insertion_point
        ops = if remaining > 0, do: [{:retain, remaining} | ops], else: ops

        Enum.reverse(ops)

      String.length(new_content) < String.length(old_content) ->
        # Content was deleted
        deletion_point = find_deletion_point(old_content, new_content)
        deleted_length = String.length(old_content) - String.length(new_content)

        ops = []
        ops = if deletion_point > 0, do: [{:retain, deletion_point} | ops], else: ops
        ops = [{:delete, deleted_length} | ops]
        remaining = String.length(new_content) - deletion_point
        ops = if remaining > 0, do: [{:retain, remaining} | ops], else: ops

        Enum.reverse(ops)

      true ->
        # Content was replaced - for simplicity, delete all and insert new
        [
          {:delete, String.length(old_content)},
          {:insert, new_content}
        ]
    end
  end

  defp find_insertion_point(old_content, new_content) do
    # Find the first position where they differ
    old_chars = String.graphemes(old_content)
    new_chars = String.graphemes(new_content)
    find_diff_position(old_chars, new_chars, 0)
  end

  defp find_deletion_point(old_content, new_content) do
    # Similar to insertion point but for deletion
    old_chars = String.graphemes(old_content)
    new_chars = String.graphemes(new_content)
    find_diff_position(new_chars, old_chars, 0)
  end

  defp find_diff_position([], _, pos), do: pos
  defp find_diff_position(_, [], pos), do: pos
  defp find_diff_position([h | t1], [h | t2], pos) do
    find_diff_position(t1, t2, pos + 1)
  end
  defp find_diff_position(_, _, pos), do: pos

  defp save_workspace_state_async(session_id, workspace_state) do
    Task.start(fn ->
      Sessions.save_workspace_state(session_id, workspace_state)
    end)
  end

  defp update_presence(session_id, user_id, updates) do
    Frestyl.Presence.update(self(), "studio:#{session_id}", to_string(user_id), updates)
  end

  defp get_username_from_collaborators(user_id, collaborators) do
    case Enum.find(collaborators, fn c -> c.user_id == user_id end) do
      %{username: username} -> username
      _ -> "Someone"
    end
  end

  defp format_operation_message(operation, username) do
    case {operation.type, operation.action} do
      {:audio, :add_track} ->
        track_name = operation.data.name || "new track"
        "#{username} added #{track_name}"

      {:audio, :delete_track} ->
        "#{username} deleted a track"

      {:text, _} ->
        "#{username} edited the text"

      _ ->
        nil
    end
  end

  defp format_time(milliseconds) when is_number(milliseconds) do
    seconds = div(trunc(milliseconds), 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end
  defp format_time(_), do: "00:00"

  defp extract_error_message(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

end
