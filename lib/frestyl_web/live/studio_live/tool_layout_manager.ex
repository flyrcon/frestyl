# lib/frestyl_web/live/studio_live/tool_layout_manager.ex
defmodule FrestylWeb.StudioLive.ToolLayoutManager do
  @moduledoc """
  Manages tool panel layouts, docking positions, and user preferences.
  """

  import Phoenix.Component  # Add this import
  import Phoenix.LiveView
  alias Frestyl.UserPreferences
  alias Phoenix.LiveView

  @collaboration_modes %{
    "collaborative_writing" => %{
      description: "Real-time writing together",
      primary_tools: ["editor", "chat"],
      secondary_tools: ["recorder", "mixer", "effects"],
      default_layout: %{
        left_dock: ["editor"],
        right_dock: ["chat"],
        bottom_dock: [],
        floating: [],
        minimized: ["recorder", "mixer", "effects"]
      }
    },
    "audio_production" => %{
      description: "Creating/mixing audio together",
      primary_tools: ["recorder", "mixer", "effects"],
      secondary_tools: ["editor", "chat"],
      default_layout: %{
        left_dock: ["mixer"],
        right_dock: ["chat"],
        bottom_dock: ["recorder", "effects"],
        floating: [],
        minimized: ["editor"]
      }
    },
    "lyrics_creation" => %{
      description: "Create and sync lyrics with beats",
      primary_tools: ["editor", "timeline", "recorder"],
      secondary_tools: ["mixer", "effects", "chat"],
      default_layout: %{
        left_dock: ["editor"],
        right_dock: ["chat"],
        bottom_dock: ["timeline", "recorder"],
        floating: [],
        minimized: ["mixer", "effects"]
      }
    },
    "audiobook_production" => %{
      description: "Record audiobooks with script sync",
      primary_tools: ["script", "recorder", "timeline"],
      secondary_tools: ["mixer", "effects", "chat"],
      default_layout: %{
        left_dock: ["script"],
        right_dock: ["chat"],
        bottom_dock: ["recorder", "timeline"],
        floating: [],
        minimized: ["mixer", "effects"]
      }
    },
    "social_listening" => %{
      description: "Listen/watch together + discuss",
      primary_tools: ["chat"],
      secondary_tools: ["editor", "recorder"],
      default_layout: %{
        left_dock: [],
        right_dock: ["chat"],
        bottom_dock: [],
        floating: [],
        minimized: ["editor", "recorder"]
      }
    },
    "content_review" => %{
      description: "Review/critique existing content",
      primary_tools: ["chat", "editor"],
      secondary_tools: ["recorder", "mixer"],
      default_layout: %{
        left_dock: ["editor"],
        right_dock: ["chat"],
        bottom_dock: [],
        floating: [],
        minimized: ["recorder", "mixer"]
      }
    },
    "live_session" => %{
      description: "One presents, others participate",
      primary_tools: ["recorder", "chat"],
      secondary_tools: ["editor", "mixer", "effects"],
      default_layout: %{
        left_dock: ["recorder"],
        right_dock: ["chat"],
        bottom_dock: [],
        floating: [],
        minimized: ["editor", "mixer", "effects"]
      }
    },
    "multimedia_creation" => %{
      description: "Text + audio + media together",
      primary_tools: ["editor", "recorder", "mixer"],
      secondary_tools: ["effects", "chat"],
      default_layout: %{
        left_dock: ["editor"],
        right_dock: ["chat"],
        bottom_dock: ["recorder", "mixer"],
        floating: [],
        minimized: ["effects"]
      }
    }
  }

  @tool_definitions %{
    "chat" => %{
      name: "Chat",
      description: "Real-time messaging",
      icon: "chat-bubble-left-ellipsis",
      category: "communication"
    },
    "editor" => %{
      name: "Editor",
      description: "Collaborative text editing",
      icon: "document-text",
      category: "content"
    },
    "recorder" => %{
      name: "Recorder",
      description: "Audio recording",
      icon: "microphone",
      category: "audio"
    },
    "mixer" => %{
      name: "Audio Mixer",
      description: "Track mixing controls",
      icon: "adjustments-horizontal",
      category: "audio"
    },
    "effects" => %{
      name: "Effects",
      description: "Audio effects rack",
      icon: "sparkles",
      category: "audio"
    },
    "timeline" => %{
      name: "Timeline",
      description: "Audio-text synchronization",
      icon: "clock",
      category: "sync"
    },
    "script" => %{
      name: "Script",
      description: "Script/lyrics editor",
      icon: "document-text",
      category: "content"
    }
  }

  # Event Handlers

  def handle_event("change_collaboration_mode", %{"mode" => mode}, socket) do
    if Map.has_key?(@collaboration_modes, mode) do
      mode_config = @collaboration_modes[mode]

      # Apply default layout for the new mode
      new_layout = apply_user_layout_preferences(
        mode_config.default_layout,
        socket.assigns.current_user.id
      )

      workspace_state = socket.assigns.workspace_state
      new_workspace_state = %{workspace_state | tool_layout: new_layout}

      # Update active tool based on workspace type
      new_active_tool = case mode_config do
        %{primary_tools: [first_tool | _]} -> map_tool_to_workspace(first_tool)
        _ -> socket.assigns.active_tool
      end

      # Broadcast mode change to other users
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "studio:#{socket.assigns.session.id}",
        {:collaboration_mode_changed, mode, socket.assigns.current_user.id}
      )

      {:noreply, socket
        |> LiveView.assign(workspace_state: new_workspace_state)
        |> LiveView.assign(collaboration_mode: mode)
        |> LiveView.assign(active_tool: new_active_tool)
        |> add_notification("Switched to #{mode_config.description}", :info)}
    else
      {:noreply, socket |> LiveView.put_flash(:error, "Invalid collaboration mode")}
    end
  end

  def handle_event("move_tool_to_dock", %{"tool_id" => tool_id, "dock_area" => dock_area}, socket) do
    workspace_state = socket.assigns.workspace_state
    current_layout = Map.get(workspace_state, :tool_layout, %{})

    # Remove tool from all dock areas
    cleaned_layout = %{
      left_dock: List.delete(Map.get(current_layout, :left_dock, []), tool_id),
      right_dock: List.delete(Map.get(current_layout, :right_dock, []), tool_id),
      bottom_dock: List.delete(Map.get(current_layout, :bottom_dock, []), tool_id),
      floating: List.delete(Map.get(current_layout, :floating, []), tool_id),
      minimized: List.delete(Map.get(current_layout, :minimized, []), tool_id)
    }

    # Add tool to new dock area
    new_layout = case dock_area do
      "left_dock" -> Map.update(cleaned_layout, :left_dock, [tool_id], &[tool_id | &1])
      "right_dock" -> Map.update(cleaned_layout, :right_dock, [tool_id], &[tool_id | &1])
      "bottom_dock" -> Map.update(cleaned_layout, :bottom_dock, [tool_id], &[tool_id | &1])
      "floating" -> Map.update(cleaned_layout, :floating, [tool_id], &[tool_id | &1])
      "minimized" -> Map.update(cleaned_layout, :minimized, [tool_id], &[tool_id | &1])
      _ -> cleaned_layout
    end

    new_workspace_state = Map.put(workspace_state, :tool_layout, new_layout)

    # Save user preference
    save_user_tool_layout_preference(socket.assigns.current_user.id, new_layout)

    {:noreply, socket
      |> assign(workspace_state: new_workspace_state)
      |> push_event("tool_moved", %{tool_id: tool_id, dock_area: dock_area})}
  end

  def handle_event("toggle_tool_panel", %{"tool_id" => tool_id}, socket) do
    workspace_state = socket.assigns.workspace_state
    current_layout = Map.get(workspace_state, :tool_layout, %{})

    # If tool is minimized, restore to its preferred location
    new_layout = if tool_id in Map.get(current_layout, :minimized, []) do
      preferred_dock = get_tool_preferred_dock(tool_id, socket.assigns.collaboration_mode)

      current_layout
      |> Map.update(:minimized, [], &List.delete(&1, tool_id))
      |> Map.update(preferred_dock, [], &[tool_id | &1])
    else
      # Minimize the tool
      cleaned_layout = %{
        left_dock: List.delete(Map.get(current_layout, :left_dock, []), tool_id),
        right_dock: List.delete(Map.get(current_layout, :right_dock, []), tool_id),
        bottom_dock: List.delete(Map.get(current_layout, :bottom_dock, []), tool_id),
        floating: List.delete(Map.get(current_layout, :floating, []), tool_id),
        minimized: Map.get(current_layout, :minimized, [])
      }

      Map.update(cleaned_layout, :minimized, [tool_id], &[tool_id | &1])
    end

    new_workspace_state = Map.put(workspace_state, :tool_layout, new_layout)

    {:noreply, socket
      |> LiveView.assign(workspace_state: new_workspace_state)
      |> LiveView.push_event("tool_toggled", %{tool_id: tool_id, minimized: tool_id in Map.get(new_layout, :minimized, [])})}
  end

  def handle_event("reset_tool_layout", _params, socket) do
    mode = socket.assigns.collaboration_mode
    mode_config = @collaboration_modes[mode]

    new_workspace_state = Map.put(
      socket.assigns.workspace_state,
      :tool_layout,
      mode_config.default_layout
    )

    # Clear user preferences
    clear_user_tool_layout_preferences(socket.assigns.current_user.id)

    {:noreply, socket
      |> LiveView.assign(workspace_state: new_workspace_state)
      |> add_notification("Tool layout reset to default", :info)}
  end

  def handle_event("toggle_dock_visibility", %{"dock" => dock}, socket) do
    current_visibility = Map.get(socket.assigns, :dock_visibility, %{
      left: true,
      right: true,
      bottom: true
    })

    dock_atom = String.to_atom(dock)
    new_visibility = Map.put(current_visibility, dock_atom, !Map.get(current_visibility, dock_atom, true))

    {:noreply, socket
      |> assign(dock_visibility: new_visibility)
      |> push_event("dock_toggled", %{dock: dock, visible: Map.get(new_visibility, dock_atom)})}

  end

  # Public API Functions

  def get_available_tools_for_mode(collaboration_mode) do
    mode_config = Map.get(@collaboration_modes, collaboration_mode)

    if mode_config do
      all_tools = mode_config.primary_tools ++ mode_config.secondary_tools

      Enum.map(all_tools, fn tool_id ->
        tool_def = @tool_definitions[tool_id]

        Map.merge(tool_def, %{
          id: tool_id,
          is_primary: tool_id in mode_config.primary_tools,
          enabled: true
        })
      end)
    else
      # Fallback tools
      [
        %{id: "chat", name: "Chat", description: "Send messages", icon: "chat-bubble-left-ellipsis", is_primary: true, enabled: true},
        %{id: "mixer", name: "Audio Mixer", description: "Mix tracks", icon: "adjustments-horizontal", is_primary: true, enabled: true},
        %{id: "recorder", name: "Recorder", description: "Record audio", icon: "microphone", is_primary: true, enabled: true}
      ]
    end
  end

  def get_user_tool_layout(user_id, collaboration_mode) do
    mode_config = @collaboration_modes[collaboration_mode]
    apply_user_layout_preferences(mode_config.default_layout, user_id)
  end

  def get_mobile_layout_for_mode(collaboration_mode) do
    mode_config = @collaboration_modes[collaboration_mode]

    %{
      primary_tools: mode_config.primary_tools,
      quick_access: Enum.take(mode_config.secondary_tools, 2),
      hidden_tools: Enum.drop(mode_config.secondary_tools, 2)
    }
  end

  def get_tool_definition(tool_id) do
    Map.get(@tool_definitions, tool_id)
  end

  def get_collaboration_mode_config(mode) do
    Map.get(@collaboration_modes, mode)
  end

  def get_all_collaboration_modes do
    @collaboration_modes
  end

  # Private Helper Functions

  defp apply_user_layout_preferences(default_layout, user_id) do
    case get_user_tool_layout_preferences(user_id) do
      nil -> default_layout
      user_prefs -> Map.merge(default_layout, user_prefs)
    end
  end

  defp get_tool_preferred_dock(tool_id, collaboration_mode) do
    mode_config = @collaboration_modes[collaboration_mode]

    cond do
      tool_id in mode_config.primary_tools ->
        case tool_id do
          "chat" -> :right_dock
          "editor" -> :left_dock
          "recorder" -> :bottom_dock
          "mixer" -> :left_dock
          "effects" -> :bottom_dock
          "timeline" -> :bottom_dock
          "script" -> :left_dock
          _ -> :left_dock
        end
      true -> :minimized
    end
  end

  defp map_tool_to_workspace(tool_id) do
    case tool_id do
      "editor" -> "text"
      "script" -> "text"
      "timeline" -> "audio_text"
      tool_id when tool_id in ["recorder", "mixer", "effects"] -> "audio"
      _ -> "audio"
    end
  end

  defp save_user_tool_layout_preference(user_id, layout) do
    case UserPreferences.update_tool_layout(user_id, layout) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end

  defp get_user_tool_layout_preferences(user_id) do
    case UserPreferences.get_or_create_tool_preferences(user_id) do
      {:ok, preferences} -> Map.get(preferences, :tool_layout)
      {:error, _} -> nil
    end
  end

  defp clear_user_tool_layout_preferences(user_id) do
    save_user_tool_layout_preference(user_id, %{})
  end

  # Helper function for adding notifications (needs to be implemented in the calling module)
  defp add_notification(socket, message, type) do
    notification = %{
      id: System.unique_integer([:positive]),
      type: type,
      message: message,
      timestamp: DateTime.utc_now()
    }

    notifications = [notification | Map.get(socket.assigns, :notifications, [])] |> Enum.take(5)
    LiveView.assign(socket, notifications: notifications)
  end
end
