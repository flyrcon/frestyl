# lib/frestyl_web/live/studio_live.ex
defmodule FrestylWeb.StudioLive do
  use FrestylWeb, :live_view
  require Logger

  use FrestylWeb.StudioLive.EventHandlerHelpers
  alias Frestyl.{Accounts, Channels, Sessions, Presence}
  alias FrestylWeb.StudioLive.{
    WorkspaceLayoutComponent,
    AudioEventHandler,
    MobileEventHandler,
    CollaborationEventHandler,
    ToolLayoutManager
  }
  alias Frestyl.Studio.{WorkspaceManager, CollaborationManager}
  alias Phoenix.PubSub

  @impl true
  def mount(%{"slug" => channel_slug, "session_id" => session_id} = params, session, socket) do
    current_user = session["user_token"] && Accounts.get_user_by_session_token(session["user_token"])

    if current_user do
      channel = Channels.get_channel_by_slug(channel_slug)

      if channel do
        session_data = Sessions.get_session(session_id)

        if session_data do
          socket = initialize_studio_session(socket, current_user, channel, session_data, params)
          {:ok, socket}
        else
          {:ok, redirect_with_error(socket, "Session not found", ~p"/channels/#{channel_slug}")}
        end
      else
        {:ok, redirect_with_error(socket, "Channel not found", ~p"/dashboard")}
      end
    else
      {:ok, redirect_with_error(socket, "You must be logged in", ~p"/users/log_in")}
    end
  end

  # Audio-text events
  @impl true
  def handle_event("audio_text_mode_change" = event, params, socket) do
    FrestylWeb.StudioLive.AudioTextEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event("create_text_block" = event, params, socket) do
    FrestylWeb.StudioLive.AudioTextEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event("update_text_block" = event, params, socket) do
    FrestylWeb.StudioLive.AudioTextEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event("select_text_block" = event, params, socket) do
    FrestylWeb.StudioLive.AudioTextEventHandler.handle_event(event, params, socket)
  end

  # Document events
  @impl true
  def handle_event("create_new_document" = event, params, socket) do
    FrestylWeb.StudioLive.DocumentEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event("load_existing_document" = event, params, socket) do
    FrestylWeb.StudioLive.DocumentEventHandler.handle_event(event, params, socket)
  end

  # Beat machine events
  @impl true
  def handle_event("beat_create_pattern" = event, params, socket) do
    FrestylWeb.StudioLive.BeatMachineEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event("beat_update_step" = event, params, socket) do
    FrestylWeb.StudioLive.BeatMachineEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event("beat_delete_pattern" = event, params, socket) do
    FrestylWeb.StudioLive.BeatMachineEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event("beat_duplicate_pattern" = event, params, socket) do
    FrestylWeb.StudioLive.BeatMachineEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event("beat_play_pattern" = event, params, socket) do
    FrestylWeb.StudioLive.BeatMachineEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event("beat_stop_pattern" = event, params, socket) do
    FrestylWeb.StudioLive.BeatMachineEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event("beat_clear_step" = event, params, socket) do
    FrestylWeb.StudioLive.BeatMachineEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event("beat_update_step_enhanced" = event, params, socket) do
    FrestylWeb.StudioLive.BeatMachineEventHandler.handle_event(event, params, socket)
  end

  @impl true
  def handle_event(event_name, params, socket) when event_name in [
    "change_collaboration_mode",
    "move_tool_to_dock",
    "toggle_tool_panel",
    "reset_tool_layout",
    "toggle_dock_visibility"
  ] do
    ToolLayoutManager.handle_event(event_name, params, socket)
  end

  def handle_event("toggle_dock_visibility", %{"dock" => dock}, socket) do
    ToolLayoutManager.handle_event("toggle_dock_visibility", %{"dock" => dock}, socket)
  end

  @impl true
  def handle_event(event_name, params, socket) do
    # Handle remaining general events
    case event_name do
      "send_session_message" -> CollaborationEventHandler.handle_event(event_name, params, socket)
      "typing_start" -> CollaborationEventHandler.handle_event(event_name, params, socket)
      "typing_stop" -> CollaborationEventHandler.handle_event(event_name, params, socket)
      "update_message_input" -> CollaborationEventHandler.handle_event(event_name, params, socket)
      "set_active_tool" -> handle_set_active_tool(params, socket)
      "toggle_invite_modal" -> {:noreply, assign(socket, show_invite_modal: !socket.assigns.show_invite_modal)}
      "toggle_settings_modal" -> {:noreply, assign(socket, show_settings_modal: !socket.assigns.show_settings_modal)}
      "end_session" -> {:noreply, assign(socket, show_end_session_modal: true)}
      "cancel_end_session" -> {:noreply, assign(socket, show_end_session_modal: false)}
      "end_session_confirmed" -> handle_end_session(socket)
      _ -> {:noreply, socket}
    end
  end

  def handle_event("set_active_dock_tool", %{"dock" => dock, "tool" => tool}, socket) do
    dock_atom = String.to_atom(dock)
    active_dock_tools = Map.put(socket.assigns.active_dock_tools, dock_atom, tool)
    {:noreply, assign(socket, active_dock_tools: active_dock_tools)}
  end

  @impl true
  def handle_info(message, socket) do
    cond do
      audio_engine_message?(message) -> AudioEventHandler.handle_info(message, socket)
      collaboration_message?(message) -> CollaborationEventHandler.handle_info(message, socket)
      presence_message?(message) -> handle_presence_update(message, socket)
      chat_message?(message) -> CollaborationEventHandler.handle_chat_info(message, socket)
      true -> {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gradient-to-br from-gray-900 to-indigo-900">
      <.live_component
        module={WorkspaceLayoutComponent}
        id="workspace-layout"
        {assigns}
      />
    </div>
    """
  end

  # Private Functions

  defp initialize_studio_session(socket, current_user, channel, session_data, _params) do
    # Initialize device and capabilities
    user_agent = if connected?(socket), do: get_connect_info(socket, :user_agent), else: nil
    device_info = get_device_info(user_agent)

    # Initialize workspace and collaboration
    {workspace_state, collaboration_mode} = WorkspaceManager.initialize_workspace(
      session_data,
      current_user,
      device_info
    )

    # Set up real-time subscriptions
    if connected?(socket) do
      CollaborationManager.setup_subscriptions(session_data.id, current_user.id)
      CollaborationManager.track_presence(session_data.id, current_user, device_info)
    end

    # Initialize audio engines
    WorkspaceManager.start_engines(session_data.id, device_info.is_mobile)

    socket
    |> assign_session_data(current_user, channel, session_data)
    |> assign_workspace_state(workspace_state, collaboration_mode)
    |> assign_device_capabilities(device_info)
    |> assign_ui_state()
  end

  defp assign_session_data(socket, current_user, channel, session_data) do
    role = determine_user_role(session_data, current_user)
    permissions = get_permissions_for_role(role, session_data.session_type)

    socket
    |> assign(:current_user, current_user)
    |> assign(:channel, channel)
    |> assign(:session, session_data)
    |> assign(:role, role)
    |> assign(:permissions, permissions)
    |> assign(:page_title, session_data.title || "Untitled Session")
  end

  defp assign_workspace_state(socket, workspace_state, collaboration_mode) do
    available_tools = ToolLayoutManager.get_available_tools_for_mode(collaboration_mode)
    tool_layout = ToolLayoutManager.get_user_tool_layout(socket.assigns.current_user.id, collaboration_mode)

    socket
    |> assign(:workspace_state, workspace_state)
    |> assign(:collaboration_mode, collaboration_mode)
    |> assign(:available_tools, available_tools)
    |> assign(:tool_layout, tool_layout)
    |> assign(:active_tool, WorkspaceManager.get_default_tool(workspace_state))
  end

  defp assign_device_capabilities(socket, device_info) do
    user_tier = get_user_audio_tier(socket.assigns.current_user)
    audio_config = get_audio_engine_config(user_tier, device_info.is_mobile)
    mobile_layout = ToolLayoutManager.get_mobile_layout_for_mode(socket.assigns.collaboration_mode)

    socket
    |> assign(:is_mobile, device_info.is_mobile)
    |> assign(:device_info, device_info)
    |> assign(:audio_config, audio_config)
    |> assign(:user_tier, user_tier)
    |> assign(:mobile_layout, mobile_layout)
  end

  defp assign_ui_state(socket) do
    socket
    |> assign(:active_tool, "audio")
    |> assign(:active_dock_tools, %{left: nil, right: "chat", bottom: nil})
    |> assign(:mobile_active_tool, "audio")
    |> assign(:mobile_tool_drawer_open, false)
    |> assign(:show_mobile_tool_modal, false)
    |> assign(:mobile_modal_tool, nil)
    |> assign(:mobile_layout, get_default_mobile_layout())
    |> assign(:show_invite_modal, false)
    |> assign(:show_settings_modal, false)
    |> assign(:show_end_session_modal, false)
    |> assign(:mobile_tool_drawer_open, false)
    |> assign(:show_mobile_tool_modal, false)
    |> assign(:mobile_modal_tool, nil)
    |> assign(:recording_track, nil)
    |> assign(:voice_commands_active, false)
    |> assign(:mobile_simplified_mode, false)
    |> assign(:mobile_text_size, "base")
    |> assign(:current_mobile_track, 0)
    |> assign(:dock_visibility, %{left: true, right: true, bottom: true})
    |> assign(:notifications, [])
    |> assign(:collaborators, CollaborationManager.list_collaborators(socket.assigns.session.id))
    |> assign(:chat_messages, Sessions.list_session_messages(socket.assigns.session.id) || [])
    |> assign(:message_input, "")
    |> assign(:connection_status, "connected")
    |> assign(:typing_users, MapSet.new())
    |> assign(:pending_operations, [])
    |> assign(:operation_conflicts, [])
  end

  defp get_default_mobile_layout do
    %{
      primary_tools: ["recorder", "mixer", "effects"],
      hidden_tools: [],
      quick_access: ["editor", "chat"]
    }
  end

  defp apply_action(socket, :show, _params) do
    assign(socket, :page_title, "#{socket.assigns.session.title} | Studio")
  end

  defp apply_action(socket, :edit_session, _params) do
    if can_edit_session?(socket.assigns.permissions) do
      assign(socket, :page_title, "Edit Session | #{socket.assigns.session.title}")
    else
      socket
      |> put_flash(:error, "You don't have permission to edit this session")
      |> push_redirect(to: ~p"/channels/#{socket.assigns.channel.slug}")
    end
  end

  defp handle_set_active_tool(%{"tool" => tool}, socket) do
    active_tool = case tool do
      "editor" -> "text"
      other -> other
    end

    CollaborationManager.update_presence(
      socket.assigns.session.id,
      socket.assigns.current_user.id,
      %{active_tool: active_tool}
    )

    {:noreply, assign(socket, active_tool: active_tool)}
  end

  defp handle_end_session(socket) do
    case Sessions.update_session(socket.assigns.session, %{status: "ended", ended_at: DateTime.utc_now()}) do
      {:ok, _updated_session} ->
        {:noreply, socket
          |> put_flash(:info, "Session ended successfully.")
          |> push_redirect(to: ~p"/channels/#{socket.assigns.channel.slug}")}

      {:error, reason} ->
        {:noreply, socket
          |> assign(show_end_session_modal: false)
          |> put_flash(:error, "Could not end session: #{reason}")}
    end
  end

  # Message type detection helpers
  defp audio_engine_message?({:track_added, _, _}), do: true
  defp audio_engine_message?({:track_volume_changed, _, _}), do: true
  defp audio_engine_message?({:beat_machine, _}), do: true
  defp audio_engine_message?({:playback_started, _}), do: true
  defp audio_engine_message?({:playback_stopped, _}), do: true
  defp audio_engine_message?(_), do: false

  defp collaboration_message?({:new_operation, _}), do: true
  defp collaboration_message?({:operation_acknowledged, _, _}), do: true
  defp collaboration_message?({:enhanced_audio_operation, _}), do: true
  defp collaboration_message?(_), do: false

  defp presence_message?(%Phoenix.Socket.Broadcast{event: "presence_diff"}), do: true
  defp presence_message?(_), do: false

  defp chat_message?({:new_message, _}), do: true
  defp chat_message?({:user_typing, _, _}), do: true
  defp chat_message?(_), do: false

  defp handle_presence_update(message, socket) do
    collaborators = CollaborationManager.list_collaborators(socket.assigns.session.id)
    notifications = CollaborationManager.process_presence_diff(message, socket.assigns.current_user.id)

    {:noreply, socket
      |> assign(collaborators: collaborators)
      |> update(:notifications, &(notifications ++ &1))}
  end

  defp redirect_with_error(socket, message, path) do
    socket
    |> put_flash(:error, message)
    |> push_redirect(to: path)
  end

  # Helper functions (simplified versions of originals)
  defp determine_user_role(session_data, current_user) do
    cond do
      session_data.creator_id == current_user.id -> :creator
      session_data.host_id == current_user.id -> :host
      true -> :participant
    end
  end

  defp get_permissions_for_role(role, session_type) do
    base = %{
      can_edit: role in [:creator, :host],
      can_record: true,
      can_chat: true,
      can_invite: role in [:creator, :host],
      can_end_session: role in [:creator, :host],
      can_use_audio_tools: true,
      can_edit_text: true,
      can_edit_audio: true,
      can_record_audio: true
    }

    case session_type do
      "audio" -> Map.put(base, :primary_workspace, :audio)
      "text" -> Map.put(base, :primary_workspace, :text)
      _ -> Map.put(base, :primary_workspace, :audio)
    end
  end

  defp can_edit_session?(permissions), do: Map.get(permissions, :can_edit, false)

  defp get_device_info(user_agent) do
    is_mobile = is_mobile_device?(user_agent)

    device_type = cond do
      is_nil(user_agent) -> "unknown"
      Regex.match?(~r/iPad/i, user_agent) -> "tablet"
      Regex.match?(~r/iPhone|iPod/i, user_agent) -> "phone"
      Regex.match?(~r/Android.*Mobile/i, user_agent) -> "phone"
      Regex.match?(~r/Android/i, user_agent) -> "tablet"
      is_mobile -> "mobile"
      true -> "desktop"
    end

    %{
      device_type: device_type,
      screen_size: if(device_type in ["phone"], do: "small", else: "large"),
      supports_audio: not Regex.match?(~r/Opera Mini|UC Browser/i, user_agent || ""),
      user_agent: user_agent,
      is_mobile: is_mobile
    }
  end

  defp is_mobile_device?(user_agent) when is_binary(user_agent) do
    mobile_patterns = [
      ~r/Android/i, ~r/webOS/i, ~r/iPhone/i, ~r/iPad/i, ~r/iPod/i,
      ~r/BlackBerry/i, ~r/IEMobile/i, ~r/Opera Mini/i, ~r/Mobile/i
    ]
    Enum.any?(mobile_patterns, &Regex.match?(&1, user_agent))
  end
  defp is_mobile_device?(_), do: false

  defp get_user_audio_tier(user) do
    case Map.get(user, :subscription_tier, "free") do
      "pro" -> :pro
      "premium" -> :premium
      _ -> :free
    end
  end

  defp get_audio_engine_config(user_tier, is_mobile) do
    base_config = case user_tier do
      :pro -> %{sample_rate: 48000, max_tracks: if(is_mobile, do: 4, else: 16)}
      :premium -> %{sample_rate: 44100, max_tracks: if(is_mobile, do: 4, else: 8)}
      :free -> %{sample_rate: 44100, max_tracks: if(is_mobile, do: 2, else: 4)}
    end

    if is_mobile do
      Map.merge(base_config, %{battery_optimized: true, simplified_effects: true})
    else
      base_config
    end
  end
end
