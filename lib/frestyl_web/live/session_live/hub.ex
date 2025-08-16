# lib/frestyl_web/live/session_live/hub.ex
defmodule FrestylWeb.SessionLive.Hub do
  @moduledoc """
  Unified session hub that handles all types of live sessions:
  - Broadcasts (1-to-many streaming)
  - Consultations (1-on-1 calls)
  - Tutorials (interactive teaching)
  - Collaborations (multi-user creative sessions)

  Features tier-aware UI and real-time collaboration tracking.
  """

  use FrestylWeb, :live_view
  require Logger

  alias Frestyl.{Sessions, Channels, Accounts, Collaboration}
  alias Frestyl.Features.{FeatureGate, TierManager}
  alias Frestyl.Studio.{AudioEngine, RecordingEngine}
  alias Frestyl.Streaming.Engine, as: StreamingEngine
  alias Frestyl.Streaming.WebRTCManager
  alias Phoenix.PubSub

  @impl true
  def mount(%{"slug" => channel_slug, "id" => session_id} = params, session, socket) do
    current_user = session["user_token"] && Accounts.get_user_by_session_token(session["user_token"])

    if is_nil(current_user) do
      {:ok, redirect(socket, to: ~p"/login")}
    else
      session_id_int = String.to_integer(session_id)
      session_record = Sessions.get_session(session_id_int)
      channel = Channels.get_channel_by_slug(channel_slug)

      case validate_session_access(session_record, channel, current_user) do
        {:ok, session_data} ->
          socket = initialize_session_hub(socket, session_data, current_user, params)
          {:ok, socket}

        {:error, reason} ->
          {:ok, redirect_with_error(socket, reason, channel_slug)}
      end
    end
  end

  defp validate_session_access(session_record, channel, user) do
    cond do
      is_nil(session_record) -> {:error, :session_not_found}
      is_nil(channel) -> {:error, :channel_not_found}
      session_record.channel_id != channel.id -> {:error, :session_channel_mismatch}
      not Sessions.user_can_access_session?(session_record, user) -> {:error, :access_denied}
      true -> {:ok, %{session: session_record, channel: channel}}
    end
  end

  defp initialize_session_hub(socket, %{session: session, channel: channel}, user, params) do
    # Determine session mode
    session_mode = determine_session_mode(session, params)

    # Get user tier and permissions
    user_tier = TierManager.get_account_tier(user)
    permissions = get_session_permissions(session, user, user_tier)

    # Initialize engines based on session type
    initialize_session_engines(session.id, session_mode, user_tier)

    if connected?(socket) do
      # Subscribe to real-time updates
      subscribe_to_session_events(session.id, channel.id, user.id)
    end

    # Load initial session state
    session_state = load_session_state(session, user, session_mode)

    socket
    |> assign(:page_title, build_page_title(session, session_mode))
    |> assign(:session, session)
    |> assign(:channel, channel)
    |> assign(:current_user, user)
    |> assign(:user_tier, user_tier)
    |> assign(:session_mode, session_mode)
    |> assign(:permissions, permissions)
    |> assign(:session_state, session_state)
    |> assign(:ui_state, initialize_ui_state(session_mode, user_tier))
    |> assign(:feature_gates, build_feature_gates(user_tier))
  end

  defp determine_session_mode(session, params) do
    case {session.session_type, Map.get(params, "mode")} do
      {"broadcast", _} -> :broadcast
      {"consultation", _} -> :consultation
      {"tutorial", _} -> :tutorial
      {"collaboration", _} -> :collaboration
      {_, "consultation"} -> :consultation
      {_, "tutorial"} -> :tutorial
      {_, mode} when mode in ["broadcast", "stream"] -> :broadcast
      _ -> :collaboration
    end
  end

  defp get_session_permissions(session, user, tier) do
    %{
      can_host: Sessions.user_can_host?(session, user),
      can_record: FeatureGate.feature_available?(tier, :session_recording),
      can_stream: FeatureGate.feature_available?(tier, :live_streaming),
      can_share_screen: FeatureGate.feature_available?(tier, :screen_sharing),
      can_share_files: FeatureGate.feature_available?(tier, :file_sharing),
      can_use_effects: FeatureGate.feature_available?(tier, :audio_effects),
      can_multitrack: FeatureGate.feature_available?(tier, :multi_track_recording),
      max_participants: TierManager.get_tier_limits(tier)[:max_session_participants] || 4
    }
  end

  defp initialize_session_engines(session_id, session_mode, tier) do
    # Always start audio engine for any live session
    case AudioEngine.start_link(session_id) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> Logger.warn("Failed to start AudioEngine: #{inspect(error)}")
    end

    # Start recording engine if user has recording permissions
    if FeatureGate.feature_available?(tier, :session_recording) do
      case RecordingEngine.start_link(session_id) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        error -> Logger.warn("Failed to start RecordingEngine: #{inspect(error)}")
      end
    end

    # Start streaming engine for broadcast mode
    if session_mode == :broadcast and FeatureGate.feature_available?(tier, :live_streaming) do
      case StreamingEngine.start_link(session_id) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        error -> Logger.warn("Failed to start StreamingEngine: #{inspect(error)}")
      end
    end

    # Start WebRTC manager for video sessions
    if session_mode in [:consultation, :tutorial, :collaboration] do
      case WebRTCManager.start_link(session_id) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        error -> Logger.warn("Failed to start WebRTCManager: #{inspect(error)}")
      end
    end
  end

  defp subscribe_to_session_events(session_id, channel_id, user_id) do
    PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}")
    PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}:audio")
    PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}:webrtc")
    PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}:collaboration")
    PubSub.subscribe(Frestyl.PubSub, "channel:#{channel_id}")
  end

  defp load_session_state(session, user, mode) do
    base_state = %{
      participants: Sessions.list_session_participants(session.id),
      status: session.status,
      started_at: session.started_at,
      recording: false,
      streaming: false
    }

    case mode do
      :broadcast ->
        Map.merge(base_state, %{
          viewer_count: Sessions.get_viewer_count(session.id),
          stream_quality: "720p",
          chat_enabled: true
        })

      :consultation ->
        Map.merge(base_state, %{
          call_duration: calculate_call_duration(session),
          screen_sharing: false,
          notes_shared: false
        })

      :tutorial ->
        Map.merge(base_state, %{
          lesson_progress: 0,
          interactive_elements: [],
          qa_enabled: true
        })

      :collaboration ->
        collaboration_state = Collaboration.get_session_state(session.id)
        Map.merge(base_state, %{
          workspace: collaboration_state.workspace || %{},
          active_operations: collaboration_state.pending_operations || [],
          cursors: collaboration_state.cursors || %{}
        })
    end
  end

  defp initialize_ui_state(mode, tier) do
    %{
      layout: get_default_layout(mode),
      panels: %{
        sidebar: :open,
        chat: if(mode == :broadcast, do: :open, else: :closed),
        participants: :open,
        controls: :open
      },
      feature_hints: get_feature_hints(tier),
      modal_state: %{
        settings: false,
        upgrade: false,
        recording: false
      }
    }
  end

  defp get_default_layout(:broadcast), do: :presenter
  defp get_default_layout(:consultation), do: :split
  defp get_default_layout(:tutorial), do: :focus
  defp get_default_layout(:collaboration), do: :grid

  defp build_feature_gates(tier) do
    %{
      recording: FeatureGate.feature_available?(tier, :session_recording),
      streaming: FeatureGate.feature_available?(tier, :live_streaming),
      screen_sharing: FeatureGate.feature_available?(tier, :screen_sharing),
      file_sharing: FeatureGate.feature_available?(tier, :file_sharing),
      effects: FeatureGate.feature_available?(tier, :audio_effects),
      multitrack: FeatureGate.feature_available?(tier, :multi_track_recording),
      analytics: FeatureGate.feature_available?(tier, :session_analytics),
      custom_branding: FeatureGate.feature_available?(tier, :custom_branding)
    }
  end

  # Event Handlers

  @impl true
  def handle_event("toggle_recording", _params, socket) do
    if socket.assigns.permissions.can_record do
      handle_recording_toggle(socket)
    else
      {:noreply, show_upgrade_modal(socket, :session_recording)}
    end
  end

  @impl true
  def handle_event("start_streaming", _params, socket) do
    if socket.assigns.permissions.can_stream do
      handle_streaming_start(socket)
    else
      {:noreply, show_upgrade_modal(socket, :live_streaming)}
    end
  end

  @impl true
  def handle_event("toggle_screen_share", _params, socket) do
    if socket.assigns.permissions.can_share_screen do
      handle_screen_share_toggle(socket)
    else
      {:noreply, show_upgrade_modal(socket, :screen_sharing)}
    end
  end

  defp handle_screen_share_toggle(socket) do
    session_id = socket.assigns.session.id
    user_id = socket.assigns.current_user.id

    # Toggle screen sharing state
    current_sharing = socket.assigns.session_state[:screen_sharing] || false

    # Broadcast screen share toggle event
    PubSub.broadcast(
      Frestyl.PubSub,
      "session:#{session_id}:webrtc",
      {:screen_share_toggle, user_id, !current_sharing}
    )

    # Update session state
    session_state = Map.put(socket.assigns.session_state, :screen_sharing, !current_sharing)

    {:noreply, assign(socket, :session_state, session_state)}
  end

  @impl true
  def handle_event("change_layout", %{"layout" => layout}, socket) do
    new_ui_state = put_in(socket.assigns.ui_state, [:layout], String.to_atom(layout))
    {:noreply, assign(socket, :ui_state, new_ui_state)}
  end

  @impl true
  def handle_event("toggle_panel", %{"panel" => panel}, socket) do
    current_state = get_in(socket.assigns.ui_state, [:panels, String.to_atom(panel)])
    new_state = if current_state == :open, do: :closed, else: :open

    new_ui_state = put_in(socket.assigns.ui_state, [:panels, String.to_atom(panel)], new_state)
    {:noreply, assign(socket, :ui_state, new_ui_state)}
  end

  @impl true
  def handle_event("collaboration_operation", %{"operation" => op_data}, socket) do
    if socket.assigns.session_mode == :collaboration do
      handle_collaboration_operation(socket, op_data)
    else
      {:noreply, socket}
    end
  end

  # Real-time Message Handlers

  @impl true
  def handle_info({:participant_joined, participant}, socket) do
    new_participants = [participant | socket.assigns.session_state.participants]
    session_state = Map.put(socket.assigns.session_state, :participants, new_participants)

    # Track collaboration activity
    if socket.assigns.session_mode == :collaboration do
      track_collaboration_event(socket.assigns.session.id, participant.user_id, :joined)
    end

    {:noreply, assign(socket, :session_state, session_state)}
  end

  @impl true
  def handle_info({:participant_left, participant_id}, socket) do
    new_participants = Enum.reject(socket.assigns.session_state.participants, &(&1.id == participant_id))
    session_state = Map.put(socket.assigns.session_state, :participants, new_participants)

    {:noreply, assign(socket, :session_state, session_state)}
  end

  @impl true
  def handle_info({:recording_started}, socket) do
    session_state = Map.put(socket.assigns.session_state, :recording, true)
    {:noreply,
     socket
     |> assign(:session_state, session_state)
     |> put_flash(:info, "Recording started")}
  end

  @impl true
  def handle_info({:recording_stopped}, socket) do
    session_state = Map.put(socket.assigns.session_state, :recording, false)
    {:noreply,
     socket
     |> assign(:session_state, session_state)
     |> put_flash(:info, "Recording stopped")}
  end

  @impl true
  def handle_info({:collaboration_operation, operation}, socket) do
    if socket.assigns.session_mode == :collaboration do
      handle_incoming_collaboration_op(socket, operation)
    else
      {:noreply, socket}
    end
  end

  # Helper Functions

  defp handle_recording_toggle(socket) do
    case socket.assigns.session_state.recording do
      false ->
        RecordingEngine.start_recording(socket.assigns.session.id, socket.assigns.current_user.id)
        {:noreply, socket}
      true ->
        RecordingEngine.stop_recording(socket.assigns.session.id, socket.assigns.current_user.id)
        {:noreply, socket}
    end
  end

  defp handle_streaming_start(socket) do
    session_id = socket.assigns.session.id
    user_id = socket.assigns.current_user.id

    case StreamingEngine.start_stream(session_id, user_id, %{quality: "720p"}) do
      {:ok, _stream} ->
        session_state = Map.put(socket.assigns.session_state, :streaming, true)
        {:noreply,
         socket
         |> assign(:session_state, session_state)
         |> put_flash(:info, "Live stream started")}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start stream: #{reason}")}
    end
  end

  defp handle_collaboration_operation(socket, op_data) do
    session_id = socket.assigns.session.id
    user_id = socket.assigns.current_user.id

    case Collaboration.create_and_broadcast_operation(
      session_id,
      user_id,
      op_data["type"],
      op_data["action"],
      op_data["data"]
    ) do
      {:ok, operation} ->
        # Track for tokenization
        track_collaboration_event(session_id, user_id, {:operation, operation})
        {:noreply, socket}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Collaboration error: #{reason}")}
    end
  end

  defp handle_incoming_collaboration_op(socket, operation) do
    # Apply operation to local state
    current_workspace = socket.assigns.session_state.workspace

    case Collaboration.OperationalTransform.apply_operation(current_workspace, operation) do
      {:ok, new_workspace} ->
        session_state = Map.put(socket.assigns.session_state, :workspace, new_workspace)
        {:noreply, assign(socket, :session_state, session_state)}
      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  defp track_collaboration_event(session_id, user_id, event) do
    # Integration point for tokenization system
    # This would track collaboration contributions for reward distribution
    Task.start(fn ->
      Collaboration.track_contribution(session_id, user_id, event)
    end)
  end

  defp show_upgrade_modal(socket, feature) do
    ui_state = put_in(socket.assigns.ui_state, [:modal_state, :upgrade], true)
    socket
    |> assign(:ui_state, ui_state)
    |> assign(:upgrade_feature, feature)
    |> put_flash(:info, "Upgrade your plan to access #{feature}")
  end

  defp build_page_title(session, mode) do
    mode_text = case mode do
      :broadcast -> "🔴 Live"
      :consultation -> "📞 Call"
      :tutorial -> "🎓 Tutorial"
      :collaboration -> "🤝 Collaborate"
    end

    "#{mode_text} #{session.title}"
  end

  defp get_feature_hints(tier) do
    case tier do
      :free -> ["Upgrade to record sessions", "Unlock screen sharing with Pro"]
      :creator -> ["Try multi-track recording", "Stream to multiple platforms"]
      :pro -> ["Access advanced analytics"]
      _ -> []
    end
  end

  defp calculate_call_duration(session) do
    if session.started_at do
      DateTime.diff(DateTime.utc_now(), session.started_at, :second)
    else
      0
    end
  end

  defp redirect_with_error(socket, reason, channel_slug) do
    error_message = case reason do
      :session_not_found -> "Session not found"
      :channel_not_found -> "Channel not found"
      :access_denied -> "You don't have permission to access this session"
      _ -> "Unable to access session"
    end

    socket
    |> put_flash(:error, error_message)
    |> redirect(to: ~p"/channels/#{channel_slug}")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="session-hub min-h-screen bg-gray-900 text-white overflow-hidden">
      <!-- Session Control Bar -->
      <.session_control_bar
        session={@session}
        session_state={@session_state}
        permissions={@permissions}
        feature_gates={@feature_gates}
        ui_state={@ui_state}
      />

      <!-- Main Session Interface -->
      <div class="session-main flex-1 flex overflow-hidden">
        <.session_layout
          mode={@session_mode}
          layout={@ui_state.layout}
          session={@session}
          session_state={@session_state}
          current_user={@current_user}
          permissions={@permissions}
          feature_gates={@feature_gates}
          ui_state={@ui_state}
        />
      </div>

      <!-- Modals -->
      <.upgrade_modal :if={@ui_state.modal_state.upgrade}
        feature={assigns[:upgrade_feature]}
        current_tier={@user_tier} />
    </div>
    """
  end

  # Import the UI components from SessionComponents
  defdelegate session_control_bar(assigns), to: FrestylWeb.SessionComponents
  defdelegate session_layout(assigns), to: FrestylWeb.SessionComponents
  defdelegate upgrade_modal(assigns), to: FrestylWeb.SessionComponents
end
