# STEP 1: Create the EventHandlerHelpers module
# File: lib/frestyl_web/live/studio_live/event_handler_helpers.ex

defmodule FrestylWeb.StudioLive.EventHandlerHelpers do
  @moduledoc """
  Common helpers and imports for Studio LiveView event handlers.
  """

  defmacro __using__(_opts) do
    quote do
      import Phoenix.LiveView
      import Phoenix.Component
      require Logger

      # Permission helper functions
      defp can_edit_audio?(permissions), do: Map.get(permissions, :can_edit_audio, false)
      defp can_record_audio?(permissions), do: Map.get(permissions, :can_record_audio, false)
      defp can_edit_text?(permissions), do: Map.get(permissions, :can_edit_text, false)
      defp can_edit_session?(permissions), do: Map.get(permissions, :can_edit_session, false)
      defp can_invite_users?(permissions), do: Map.get(permissions, :can_invite_users, false)
      defp can_edit_midi?(permissions), do: Map.get(permissions, :can_edit_midi, false)
      defp can_edit_visual?(permissions), do: Map.get(permissions, :can_edit_visual, false)

      # Helper function for notifications
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

      # Content helper functions
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

      # Workspace state helpers
      defp update_workspace_text_state(workspace_state, updates) do
        text_state = Map.get(workspace_state, :text, %{})
        new_text_state = Map.merge(text_state, updates)
        Map.put(workspace_state, :text, new_text_state)
      end

      defp update_workspace_audio_text_state(workspace_state, updates) do
        audio_text_state = Map.get(workspace_state, :audio_text, %{})
        new_audio_text_state = Map.merge(audio_text_state, updates)
        Map.put(workspace_state, :audio_text, new_audio_text_state)
      end

      # Format time helper
      defp format_time(milliseconds) when is_number(milliseconds) do
        seconds = div(trunc(milliseconds), 1000)
        minutes = div(seconds, 60)
        remaining_seconds = rem(seconds, 60)
        "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
      end
      defp format_time(_), do: "00:00"

      # Get username helper
      defp get_username_from_collaborators(user_id, collaborators) do
        case Enum.find(collaborators, fn c ->
          (is_map(c) and Map.get(c, :user_id) == user_id) or
          (is_map(c) and Map.get(c, :id) == user_id)
        end) do
          %{username: username} -> username
          %{name: name} -> name
          _ -> "Someone"
        end
      end
    end
  end
end
