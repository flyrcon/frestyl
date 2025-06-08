defmodule FrestylWeb.StudioLive.DocumentEventHandler do
  @moduledoc """
  Handles document-related events for the Studio LiveView.

  This module processes events for:
  - Document creation and loading
  - Branch creation and merging
  - Conflict resolution
  - Export and save operations
  - Document wizard interactions
  """

  import Phoenix.LiveView
  import Phoenix.Component
  require Logger

  alias Frestyl.Content
  alias Phoenix.PubSub

  # Permission helpers
  defp can_edit_text?(permissions), do: Map.get(permissions, :can_edit_text, false)
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

  # Content helpers
  defp extract_error_message(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  @doc """
  Handles document creation events
  """
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

          # Broadcast document creation
          PubSub.broadcast(
            Frestyl.PubSub,
            "studio:#{session_id}",
            {:document_created, document, user.id}
          )

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> assign(active_tool: "text")
            |> add_notification("Document created: #{document.title}", :success)}

        {:error, changeset} ->
          error_message = extract_error_message(changeset)
          {:noreply, socket |> put_flash(:error, "Failed to create document: #{error_message}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to create documents")}
    end
  end

  def handle_event("load_existing_document", %{"document_id" => document_id}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      user_id = socket.assigns.current_user.id

      case Content.get_document_for_user(document_id, user_id) do
        {:ok, document} ->
          new_workspace_state = socket.assigns.workspace_state
          |> put_in([:text, :document], document)
          |> put_in([:text, :active_document_id], document_id)

          # Subscribe to document updates
          PubSub.subscribe(Frestyl.PubSub, "document:#{document_id}")

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> assign(active_tool: "text")
            |> add_notification("Document loaded: #{document.title}", :info)}

        {:error, :not_found} ->
          {:noreply, socket |> put_flash(:error, "Document not found")}

        {:error, :access_denied} ->
          {:noreply, socket |> put_flash(:error, "You don't have access to this document")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to access documents")}
    end
  end

  @doc """
  Handles document wizard events
  """
  def handle_event("start_document_wizard", params, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      user_input = params["user_input"] || ""
      context = %{
        session_type: socket.assigns.session.session_type,
        user_history: get_user_writing_history(socket.assigns.current_user.id),
        collaborators: length(socket.assigns.collaborators)
      }

      suggestions = Content.suggest_document_type(user_input, context)

      {:noreply, socket
        |> assign(:document_wizard_open, true)
        |> assign(:document_suggestions, suggestions)
        |> push_event("show_document_wizard", %{suggestions: suggestions})}
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to create documents")}
    end
  end

  def handle_event("accept_document_suggestion", %{"document_type" => doc_type, "responses" => responses}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      user = socket.assigns.current_user
      session_id = socket.assigns.session.id

      workflow = Content.create_guided_workflow(doc_type, responses)

      document_attrs = %{
        "document_type" => doc_type,
        "title" => responses["title"] || "Untitled #{format_document_type(doc_type)}",
        "guided_setup" => true,
        "workflow_data" => workflow,
        "user_responses" => responses
      }

      case Content.create_document(document_attrs, user, session_id) do
        {:ok, document} ->
          new_workspace_state = socket.assigns.workspace_state
          |> put_in([:text, :document], document)
          |> put_in([:text, :active_document_id], document.id)
          |> put_in([:text, :editor_mode], "guided")
          |> put_in([:text, :workflow], workflow)

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> assign(active_tool: "text")
            |> assign(:document_wizard_open, false)
            |> add_notification("Let's start writing your #{format_document_type(doc_type)}!", :success)}

        {:error, changeset} ->
          error_message = extract_error_message(changeset)
          {:noreply, socket |> put_flash(:error, "Failed to create document: #{error_message}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to create documents")}
    end
  end

  def handle_event("close_document_wizard", _params, socket) do
    {:noreply, assign(socket, document_wizard_open: false)}
  end

  @doc """
  Handles branching and version control events
  """
  def handle_event("create_document_branch", %{"branch_name" => branch_name, "purpose" => purpose}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      document_id = socket.assigns.workspace_state.text.active_document_id
      user = socket.assigns.current_user

      if document_id do
        case Content.create_collaboration_branch(document_id, branch_name, user, purpose: purpose) do
          {:ok, branch} ->
            new_workspace_state = put_in(
              socket.assigns.workspace_state,
              [:text, :version_control, :current_branch],
              branch_name
            )

            PubSub.broadcast(
              Frestyl.PubSub,
              "studio:#{socket.assigns.session.id}",
              {:branch_created, branch, user.id}
            )

            {:noreply, socket
              |> assign(workspace_state: new_workspace_state)
              |> add_notification("Created branch: #{branch_name}", :success)}

          {:error, changeset} ->
            error_message = extract_error_message(changeset)
            {:noreply, socket |> put_flash(:error, "Failed to create branch: #{error_message}")}
        end
      else
        {:noreply, socket |> put_flash(:error, "No active document to branch from")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to create branches")}
    end
  end

  def handle_event("merge_document_branch", %{"branch_id" => branch_id, "merge_strategy" => strategy}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      user = socket.assigns.current_user

      case Content.merge_collaboration_branch(branch_id, user, strategy) do
        {:ok, merged_document} ->
          new_workspace_state = socket.assigns.workspace_state
          |> put_in([:text, :document], merged_document)
          |> put_in([:text, :version_control, :current_branch], "main")
          |> put_in([:text, :version_control, :merge_conflicts], [])

          PubSub.broadcast(
            Frestyl.PubSub,
            "studio:#{socket.assigns.session.id}",
            {:branch_merged, branch_id, user.id}
          )

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> add_notification("Branch merged successfully", :success)}

        {:error, {:conflicts, conflicts}} ->
          new_workspace_state = put_in(
            socket.assigns.workspace_state,
            [:text, :version_control, :merge_conflicts],
            conflicts
          )

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> add_notification("Merge conflicts detected. Please resolve manually.", :warning)}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to merge branch: #{inspect(reason)}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to merge branches")}
    end
  end

  @doc """
  Handles conflict resolution events
  """
  def handle_event("resolve_conflict", %{"conflict_id" => conflict_id, "resolution" => resolution}, socket) do
    conflicts = socket.assigns[:text_conflicts] || []

    case Enum.find(conflicts, &(&1.id == conflict_id)) do
      nil ->
        {:noreply, socket}

      conflict ->
        resolved_content = case resolution do
          "local" -> conflict.local_content
          "remote" -> conflict.remote_content
          "merge" -> merge_conflict_content(conflict.local_content, conflict.remote_content)
        end

        document_id = socket.assigns.workspace_state.text.active_document_id
        user = socket.assigns.current_user

        case Content.resolve_content_conflict(document_id, conflict.block_id, resolved_content, user) do
          {:ok, updated_document} ->
            new_workspace_state = put_in(
              socket.assigns.workspace_state,
              [:text, :document],
              updated_document
            )

            remaining_conflicts = Enum.reject(conflicts, &(&1.id == conflict_id))

            {:noreply, socket
              |> assign(workspace_state: new_workspace_state)
              |> assign(text_conflicts: remaining_conflicts)
              |> add_notification("Conflict resolved", :success)}

          {:error, reason} ->
            {:noreply, socket |> put_flash(:error, "Failed to resolve conflict")}
        end
    end
  end

  def handle_event("auto_resolve_conflicts", _params, socket) do
    conflicts = socket.assigns[:text_conflicts] || []
    document_id = socket.assigns.workspace_state.text.active_document_id
    user = socket.assigns.current_user

    case Content.auto_resolve_all_conflicts(document_id, conflicts, user) do
      {:ok, updated_document} ->
        new_workspace_state = put_in(
          socket.assigns.workspace_state,
          [:text, :document],
          updated_document
        )

        {:noreply, socket
          |> assign(workspace_state: new_workspace_state)
          |> assign(text_conflicts: [])
          |> add_notification("All conflicts auto-resolved", :success)}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to auto-resolve conflicts")}
    end
  end

  def handle_event("cancel_conflict_resolution", _params, socket) do
    {:noreply, assign(socket, text_conflicts: [])}
  end

  @doc """
  Handles document export and save events
  """
  def handle_event("text_export_document", %{"format" => format}, socket) do
    document = socket.assigns.workspace_state.text.document

    if document do
      case Content.export_document(document, format, socket.assigns.current_user) do
        {:ok, export_data} ->
          {:noreply, socket
            |> push_event("download_file", %{
              filename: "#{document.title}.#{format}",
              content: export_data.content,
              mime_type: export_data.mime_type
            })
            |> add_notification("Document exported as #{String.upcase(format)}", :success)}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Export failed: #{reason}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "No document to export")}
    end
  end

  def handle_event("text_save_document", _params, socket) do
    document = socket.assigns.workspace_state.text.document

    if document do
      case Content.save_document(document, socket.assigns.current_user) do
        {:ok, updated_document} ->
          new_workspace_state = put_in(
            socket.assigns.workspace_state,
            [:text, :document],
            updated_document
          )

          {:noreply, socket
            |> assign(workspace_state: new_workspace_state)
            |> add_notification("Document saved", :success)}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Save failed: #{reason}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "No document to save")}
    end
  end

  # Helper Functions
  defp extract_error_message(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  defp format_document_type(doc_type) do
    doc_type
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_user_writing_history(user_id) do
    try do
      Content.get_user_document_history(user_id, limit: 10)
    rescue
      _ -> []
    end
  end

  defp merge_conflict_content(local_content, remote_content) do
    "#{local_content}\n\n--- MERGED CONTENT ---\n\n#{remote_content}"
  end

end
