# lib/frestyl/features/session_integration.ex
defmodule Frestyl.Features.SessionIntegration do
  @moduledoc """
  Integration layer that connects all session-related systems:
  - Audio Engine with Recording Engine
  - WebRTC with Streaming Engine
  - Collaboration with Tokenization tracking
  - Feature gating with UI components
  """

  alias Frestyl.{Sessions, Collaboration}
  alias Frestyl.Features.{FeatureGate, TierManager}
  alias Frestyl.Studio.{AudioEngine, RecordingEngine}
  alias Frestyl.Streaming.Engine, as: StreamingEngine
  alias Frestyl.Streaming.WebRTCManager
  alias Phoenix.PubSub
  require Logger

  @doc """
  Initialize a complete session with all required engines based on session type and user tier.
  """
  def initialize_complete_session(session_id, session_type, host_user, options \\ []) do
    host_tier = TierManager.get_account_tier(host_user)

    # Start required engines based on session type and tier
    engines = determine_required_engines(session_type, host_tier, options)

    # Initialize engines in dependency order
    {:ok, engine_states} = start_engines_sequence(session_id, engines, host_tier)

    # Set up inter-engine communication
    setup_engine_communication(session_id, engine_states)

    # Initialize collaboration tracking
    setup_collaboration_tracking(session_id, host_user.id)

    # Return session state
    {:ok, %{
      session_id: session_id,
      session_type: session_type,
      engines: engine_states,
      host_tier: host_tier,
      collaboration_enabled: Map.has_key?(engine_states, :collaboration),
      recording_enabled: Map.has_key?(engine_states, :recording),
      streaming_enabled: Map.has_key?(engine_states, :streaming)
    }}
  end

  defp determine_required_engines(session_type, tier, options) do
    base_engines = [:audio, :webrtc]

    additional_engines = case session_type do
      :broadcast ->
        engines = [:streaming]
        if FeatureGate.feature_available?(tier, :session_recording), do: [:recording | engines], else: engines

      :consultation ->
        engines = []
        engines = if FeatureGate.feature_available?(tier, :session_recording), do: [:recording | engines], else: engines
        engines = if FeatureGate.feature_available?(tier, :file_sharing), do: [:collaboration | engines], else: engines
        engines

      :tutorial ->
        engines = [:collaboration]
        if FeatureGate.feature_available?(tier, :session_recording), do: [:recording | engines], else: engines

      :collaboration ->
        engines = [:collaboration]
        engines = if FeatureGate.feature_available?(tier, :multi_track_recording), do: [:recording | engines], else: engines
        engines = if FeatureGate.feature_available?(tier, :live_streaming), do: [:streaming | engines], else: engines
        engines
    end

    base_engines ++ additional_engines
  end

  defp start_engines_sequence(session_id, engines, tier) do
    engine_states = %{}

    # Start engines in dependency order
    Enum.reduce_while(engines, {:ok, engine_states}, fn engine, {:ok, acc} ->
      case start_engine(engine, session_id, tier) do
        {:ok, pid} ->
          {:cont, {:ok, Map.put(acc, engine, %{pid: pid, status: :running})}}
        {:error, {:already_started, pid}} ->
          {:cont, {:ok, Map.put(acc, engine, %{pid: pid, status: :running})}}
        {:error, reason} ->
          Logger.error("Failed to start #{engine} engine: #{inspect(reason)}")
          {:halt, {:error, {engine, reason}}}
      end
    end)
  end

  defp start_engine(:audio, session_id, _tier) do
    AudioEngine.start_link(session_id)
  end

  defp start_engine(:recording, session_id, _tier) do
    RecordingEngine.start_link(session_id)
  end

  defp start_engine(:streaming, session_id, _tier) do
    StreamingEngine.start_link(session_id)
  end

  defp start_engine(:webrtc, session_id, _tier) do
    WebRTCManager.start_link(session_id)
  end

  defp start_engine(:collaboration, session_id, _tier) do
    # Collaboration engine doesn't need a separate GenServer
    # It uses the existing Collaboration context
    {:ok, :context_based}
  end

  defp setup_engine_communication(session_id, engine_states) do
    # Set up communication channels between engines

    # Audio Engine -> Recording Engine
    if Map.has_key?(engine_states, :audio) and Map.has_key?(engine_states, :recording) do
      PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")
      setup_audio_recording_bridge(session_id)
    end

    # Audio Engine -> Streaming Engine
    if Map.has_key?(engine_states, :audio) and Map.has_key?(engine_states, :streaming) do
      setup_audio_streaming_bridge(session_id)
    end

    # WebRTC -> Audio Engine
    if Map.has_key?(engine_states, :webrtc) and Map.has_key?(engine_states, :audio) do
      setup_webrtc_audio_bridge(session_id)
    end

    # Collaboration -> All Engines
    if Map.has_key?(engine_states, :collaboration) do
      setup_collaboration_bridges(session_id, engine_states)
    end
  end

  defp setup_audio_recording_bridge(session_id) do
    # Forward audio events to recording engine
    Task.start(fn ->
      PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")

      receive do
        {:audio_chunk, track_id, user_id, audio_data, timestamp} ->
          RecordingEngine.add_audio_chunk(session_id, track_id, user_id, audio_data, timestamp)

        {:track_added, track_id, user_id, track_params} ->
          RecordingEngine.register_track(session_id, track_id, user_id, track_params)

        {:recording_started, track_id, user_id} ->
          RecordingEngine.start_recording(session_id, track_id, user_id)

        {:recording_stopped, track_id, user_id} ->
          RecordingEngine.stop_recording(session_id, track_id, user_id)
      after
        60_000 -> :timeout
      end
    end)
  end

  defp setup_audio_streaming_bridge(session_id) do
    # Connect audio engine output to streaming engine
    Task.start(fn ->
      PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")

      receive do
        {:audio_stream, audio_data} ->
          StreamingEngine.send_audio_chunk(session_id, audio_data)

        {:master_volume_changed, volume} ->
          StreamingEngine.update_audio_level(session_id, volume)
      after
        60_000 -> :timeout
      end
    end)
  end

  defp setup_webrtc_audio_bridge(session_id) do
    # Bridge WebRTC and Audio Engine for real-time audio
    Task.start(fn ->
      PubSub.subscribe(Frestyl.PubSub, "webrtc:#{session_id}")

      receive do
        {:webrtc_audio, user_id, audio_data} ->
          AudioEngine.receive_remote_audio(session_id, user_id, audio_data)

        {:participant_joined, user_id} ->
          AudioEngine.add_collaborator(session_id, user_id)

        {:participant_left, user_id} ->
          AudioEngine.remove_collaborator(session_id, user_id)
      after
        60_000 -> :timeout
      end
    end)
  end

  defp setup_collaboration_bridges(session_id, engine_states) do
    # Set up collaboration tracking for all engines

    # Track audio operations
    if Map.has_key?(engine_states, :audio) do
      setup_audio_collaboration_tracking(session_id)
    end

    # Track recording contributions
    if Map.has_key?(engine_states, :recording) do
      setup_recording_collaboration_tracking(session_id)
    end
  end

  defp setup_audio_collaboration_tracking(session_id) do
    Task.start(fn ->
      PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")

      receive do
        {:track_added, track_id, user_id, _track_params} ->
          track_collaboration_contribution(session_id, user_id, :track_creation, %{track_id: track_id})

        {:track_updated, track_id, user_id, updates} ->
          track_collaboration_contribution(session_id, user_id, :track_modification, %{track_id: track_id, updates: updates})

        {:effect_applied, track_id, user_id, effect_type, params} ->
          track_collaboration_contribution(session_id, user_id, :effect_application, %{track_id: track_id, effect: effect_type, params: params})

        {:recording_contribution, track_id, user_id, duration} ->
          track_collaboration_contribution(session_id, user_id, :recording_time, %{track_id: track_id, duration: duration})
      after
        60_000 -> :timeout
      end
    end)
  end

  defp setup_recording_collaboration_tracking(session_id) do
    Task.start(fn ->
      PubSub.subscribe(Frestyl.PubSub, "recording_engine:#{session_id}")

      receive do
        {:recording_completed, track_id, user_id, file_info} ->
          track_collaboration_contribution(session_id, user_id, :recording_completion, %{track_id: track_id, file_info: file_info})

        {:mix_created, user_id, mix_info} ->
          track_collaboration_contribution(session_id, user_id, :mix_creation, %{mix_info: mix_info})
      after
        60_000 -> :timeout
      end
    end)
  end

  defp setup_collaboration_tracking(session_id, host_user_id) do
    # Initialize collaboration session
    Collaboration.initialize_session(session_id, host_user_id)

    # Set up operation tracking
    PubSub.subscribe(Frestyl.PubSub, "collaboration:#{session_id}")
  end

  defp track_collaboration_contribution(session_id, user_id, contribution_type, metadata) do
    # Track contribution for tokenization system
    contribution = %{
      session_id: session_id,
      user_id: user_id,
      type: contribution_type,
      metadata: metadata,
      timestamp: DateTime.utc_now(),
      weight: calculate_contribution_weight(contribution_type, metadata)
    }

    # Store contribution (this would integrate with your tokenization system)
    Collaboration.record_contribution(contribution)

    # Broadcast contribution event
    PubSub.broadcast(
      Frestyl.PubSub,
      "collaboration:#{session_id}:contributions",
      {:contribution_recorded, contribution}
    )
  end

  defp calculate_contribution_weight(contribution_type, metadata) do
    # Calculate weight based on contribution type and complexity
    base_weights = %{
      track_creation: 10,
      track_modification: 5,
      effect_application: 3,
      recording_time: 1, # per minute
      recording_completion: 15,
      mix_creation: 20,
      visual_creation: 8,
      text_contribution: 2 # per 100 words
    }

    base_weight = Map.get(base_weights, contribution_type, 1)

    # Apply modifiers based on metadata
    case contribution_type do
      :recording_time ->
        # Weight by minutes recorded
        duration_minutes = div(metadata[:duration] || 0, 60)
        base_weight * max(1, duration_minutes)

      :text_contribution ->
        # Weight by word count
        word_count = div(metadata[:word_count] || 0, 100)
        base_weight * max(1, word_count)

      _ ->
        base_weight
    end
  end

  @doc """
  Get comprehensive session state including all engines and collaboration data.
  """
  def get_session_state(session_id) do
    base_state = %{
      session_id: session_id,
      timestamp: DateTime.utc_now()
    }

    # Collect state from all engines
    audio_state = get_audio_engine_state(session_id)
    recording_state = get_recording_engine_state(session_id)
    streaming_state = get_streaming_engine_state(session_id)
    webrtc_state = get_webrtc_state(session_id)
    collaboration_state = get_collaboration_state(session_id)

    Map.merge(base_state, %{
      audio: audio_state,
      recording: recording_state,
      streaming: streaming_state,
      webrtc: webrtc_state,
      collaboration: collaboration_state
    })
  end

  defp get_audio_engine_state(session_id) do
    case AudioEngine.get_engine_state(session_id) do
      {:ok, state} -> state
      {:error, _} -> %{status: :not_running}
    end
  end

  defp get_recording_engine_state(session_id) do
    case RecordingEngine.get_recording_state(session_id) do
      {:ok, state} -> state
      {:error, _} -> %{status: :not_running}
    end
  end

  defp get_streaming_engine_state(session_id) do
    case StreamingEngine.get_stream_stats(session_id) do
      {:ok, stats} -> stats
      {:error, _} -> %{status: :not_running}
    end
  end

  defp get_webrtc_state(session_id) do
    case WebRTCManager.get_broadcast_state(session_id) do
      {:ok, state} -> state
      {:error, _} -> %{status: :not_running}
    end
  end

  defp get_collaboration_state(session_id) do
    Collaboration.get_session_state(session_id)
  end

  @doc """
  Handle session events and coordinate between engines.
  """
  def handle_session_event(session_id, event, payload) do
    case event do
      :participant_joined ->
        handle_participant_joined(session_id, payload)

      :participant_left ->
        handle_participant_left(session_id, payload)

      :recording_started ->
        handle_recording_started(session_id, payload)

      :recording_stopped ->
        handle_recording_stopped(session_id, payload)

      :streaming_started ->
        handle_streaming_started(session_id, payload)

      :streaming_stopped ->
        handle_streaming_stopped(session_id, payload)

      :collaboration_operation ->
        handle_collaboration_operation(session_id, payload)

      _ ->
        Logger.warn("Unhandled session event: #{event}")
        :ok
    end
  end

  defp handle_participant_joined(session_id, %{user_id: user_id} = payload) do
    # Notify all engines
    PubSub.broadcast(Frestyl.PubSub, "audio_engine:#{session_id}", {:participant_joined, user_id})
    PubSub.broadcast(Frestyl.PubSub, "webrtc:#{session_id}", {:participant_joined, user_id})
    PubSub.broadcast(Frestyl.PubSub, "collaboration:#{session_id}", {:participant_joined, payload})

    # Track collaboration event
    track_collaboration_contribution(session_id, user_id, :session_participation, %{action: :joined})
  end

  defp handle_participant_left(session_id, %{user_id: user_id} = payload) do
    # Notify all engines
    PubSub.broadcast(Frestyl.PubSub, "audio_engine:#{session_id}", {:participant_left, user_id})
    PubSub.broadcast(Frestyl.PubSub, "webrtc:#{session_id}", {:participant_left, user_id})
    PubSub.broadcast(Frestyl.PubSub, "collaboration:#{session_id}", {:participant_left, payload})

    # Track collaboration event
    track_collaboration_contribution(session_id, user_id, :session_participation, %{action: :left})
  end

  defp handle_recording_started(session_id, payload) do
    # Coordinate recording start across engines
    PubSub.broadcast(Frestyl.PubSub, "audio_engine:#{session_id}", {:recording_started, payload})
    PubSub.broadcast(Frestyl.PubSub, "collaboration:#{session_id}", {:recording_started, payload})

    # Track significant session event
    if payload[:user_id] do
      track_collaboration_contribution(session_id, payload.user_id, :session_recording, %{action: :started})
    end
  end

  defp handle_recording_stopped(session_id, payload) do
    # Coordinate recording stop across engines
    PubSub.broadcast(Frestyl.PubSub, "audio_engine:#{session_id}", {:recording_stopped, payload})
    PubSub.broadcast(Frestyl.PubSub, "collaboration:#{session_id}", {:recording_stopped, payload})

    # Track session event
    if payload[:user_id] do
      track_collaboration_contribution(session_id, payload.user_id, :session_recording, %{action: :stopped})
    end
  end

  defp handle_streaming_started(session_id, payload) do
    # Coordinate streaming across engines
    PubSub.broadcast(Frestyl.PubSub, "audio_engine:#{session_id}", {:streaming_started, payload})
    PubSub.broadcast(Frestyl.PubSub, "webrtc:#{session_id}", {:streaming_started, payload})
  end

  defp handle_streaming_stopped(session_id, payload) do
    # Coordinate streaming stop
    PubSub.broadcast(Frestyl.PubSub, "audio_engine:#{session_id}", {:streaming_stopped, payload})
    PubSub.broadcast(Frestyl.PubSub, "webrtc:#{session_id}", {:streaming_stopped, payload})
  end

  defp handle_collaboration_operation(session_id, operation) do
    # Process collaboration operation and notify relevant engines
    case operation.type do
      :audio ->
        PubSub.broadcast(Frestyl.PubSub, "audio_engine:#{session_id}", {:collaboration_operation, operation})

      :visual ->
        PubSub.broadcast(Frestyl.PubSub, "collaboration:#{session_id}", {:visual_operation, operation})

      :text ->
        PubSub.broadcast(Frestyl.PubSub, "collaboration:#{session_id}", {:text_operation, operation})

      _ ->
        Logger.warn("Unknown collaboration operation type: #{operation.type}")
    end

    # Track the collaboration operation
    track_collaboration_contribution(
      session_id,
      operation.user_id,
      :collaboration_operation,
      %{operation_type: operation.type, action: operation.action}
    )
  end

  @doc """
  Gracefully shutdown all session engines.
  """
  def shutdown_session(session_id) do
    Logger.info("Shutting down session #{session_id}")

    # Shutdown in reverse dependency order
    engines = [:collaboration, :streaming, :recording, :webrtc, :audio]

    Enum.each(engines, fn engine ->
      case engine do
        :audio ->
          shutdown_engine(AudioEngine, session_id)
        :recording ->
          shutdown_engine(RecordingEngine, session_id)
        :streaming ->
          shutdown_engine(StreamingEngine, session_id)
        :webrtc ->
          shutdown_engine(WebRTCManager, session_id)
        :collaboration ->
          # Collaboration cleanup
          Collaboration.cleanup_session(session_id)
      end
    end)

    # Clean up PubSub subscriptions
    cleanup_session_subscriptions(session_id)

    Logger.info("Session #{session_id} shutdown complete")
  end

  defp shutdown_engine(module, session_id) do
    try do
      pid = GenServer.whereis(via_tuple(session_id, module))
      if pid && Process.alive?(pid) do
        GenServer.call(pid, :prepare_shutdown, 5000)
        GenServer.stop(pid, :normal, 5000)
      end
    catch
      :exit, _ -> :ok
    rescue
      _ -> :ok
    end
  end

  defp cleanup_session_subscriptions(session_id) do
    topics = [
      "audio_engine:#{session_id}",
      "recording_engine:#{session_id}",
      "streaming_engine:#{session_id}",
      "webrtc:#{session_id}",
      "collaboration:#{session_id}"
    ]

    Enum.each(topics, fn topic ->
      try do
        PubSub.unsubscribe(Frestyl.PubSub, topic)
      rescue
        _ -> :ok
      end
    end)
  end

  defp via_tuple(session_id, module) do
    {:via, Registry, {Frestyl.SessionRegistry, {module, session_id}}}
  end

  @doc """
  Get session analytics and collaboration metrics.
  """
  def get_session_analytics(session_id) do
    collaboration_stats = Collaboration.get_session_analytics(session_id)

    %{
      session_id: session_id,
      total_contributions: collaboration_stats.total_contributions,
      participants: collaboration_stats.participants,
      contribution_breakdown: collaboration_stats.contribution_breakdown,
      session_duration: collaboration_stats.session_duration,
      most_active_contributors: collaboration_stats.most_active_contributors,
      tokenization_weights: collaboration_stats.tokenization_weights
    }
  end

  @doc """
  Export session data for external analysis or backup.
  """
  def export_session_data(session_id, format \\ :json) do
    session_state = get_session_state(session_id)
    analytics = get_session_analytics(session_id)

    export_data = %{
      session_state: session_state,
      analytics: analytics,
      exported_at: DateTime.utc_now(),
      format_version: "1.0"
    }

    case format do
      :json ->
        Jason.encode(export_data)
      :erlang ->
        {:ok, export_data}
      _ ->
        {:error, :unsupported_format}
    end
  end
end

# lib/frestyl/features/session_manager.ex
defmodule Frestyl.Features.SessionManager do
  @moduledoc """
  High-level session management that orchestrates the unified session experience.
  Handles session lifecycle, feature gating, and user permissions.
  """

  use GenServer

  alias Frestyl.Features.SessionIntegration
  alias Frestyl.{Sessions, Accounts}
  alias Frestyl.Features.{FeatureGate, TierManager}
  alias Phoenix.PubSub
  require Logger

  defstruct [
    :session_id,
    :session_type,
    :host_user,
    :participants,
    :engines,
    :feature_gates,
    :started_at,
    :status
  ]

  # Client API

  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via_tuple(session_id))
  end

  def create_session(session_id, session_type, host_user, options \\ []) do
    case GenServer.start_link(__MODULE__, {session_id, session_type, host_user, options}) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
      error ->
        error
    end
  end

  def join_session(session_id, user, role \\ :participant) do
    GenServer.call(via_tuple(session_id), {:join_session, user, role})
  end

  def leave_session(session_id, user_id) do
    GenServer.call(via_tuple(session_id), {:leave_session, user_id})
  end

  def get_session_info(session_id) do
    GenServer.call(via_tuple(session_id), :get_session_info)
  end

  def update_session_settings(session_id, user_id, settings) do
    GenServer.call(via_tuple(session_id), {:update_settings, user_id, settings})
  end

  # GenServer Callbacks

  @impl true
  def init({session_id, session_type, host_user, options}) do
    Logger.info("Starting session manager for session #{session_id}")

    # Initialize complete session
    case SessionIntegration.initialize_complete_session(session_id, session_type, host_user, options) do
      {:ok, integration_state} ->
        state = %__MODULE__{
          session_id: session_id,
          session_type: session_type,
          host_user: host_user,
          participants: [%{user: host_user, role: :host, joined_at: DateTime.utc_now()}],
          engines: integration_state.engines,
          feature_gates: build_feature_gates(host_user),
          started_at: DateTime.utc_now(),
          status: :active
        }

        # Subscribe to session events
        PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}")

        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to initialize session #{session_id}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def init(session_id) when is_binary(session_id) or is_integer(session_id) do
    # Load existing session
    case Sessions.get_session(session_id) do
      nil ->
        {:stop, :session_not_found}
      session ->
        host_user = Accounts.get_user!(session.host_id)
        init({session_id, String.to_atom(session.session_type), host_user, []})
    end
  end

  @impl true
  def handle_call({:join_session, user, role}, _from, state) do
    user_tier = TierManager.get_account_tier(user)
    max_participants = get_max_participants(state.host_user, state.session_type)

    cond do
      length(state.participants) >= max_participants ->
        {:reply, {:error, :session_full}, state}

      participant_exists?(state.participants, user.id) ->
        {:reply, {:error, :already_joined}, state}

      not can_join_session?(state.session_type, user_tier) ->
        {:reply, {:error, :insufficient_tier}, state}

      true ->
        participant = %{
          user: user,
          role: role,
          joined_at: DateTime.utc_now(),
          permissions: get_participant_permissions(role, user_tier, state.feature_gates)
        }

        new_participants = [participant | state.participants]
        new_state = %{state | participants: new_participants}

        # Notify integration layer
        SessionIntegration.handle_session_event(state.session_id, :participant_joined, %{
          user_id: user.id,
          role: role,
          user_tier: user_tier
        })

        # Broadcast to LiveView
        PubSub.broadcast(
          Frestyl.PubSub,
          "session:#{state.session_id}",
          {:participant_joined, participant}
        )

        {:reply, {:ok, participant}, new_state}
    end
  end

  @impl true
  def handle_call({:leave_session, user_id}, _from, state) do
    case Enum.find(state.participants, &(&1.user.id == user_id)) do
      nil ->
        {:reply, {:error, :not_found}, state}

      participant ->
        new_participants = Enum.reject(state.participants, &(&1.user.id == user_id))
        new_state = %{state | participants: new_participants}

        # Notify integration layer
        SessionIntegration.handle_session_event(state.session_id, :participant_left, %{
          user_id: user_id,
          role: participant.role
        })

        # Broadcast to LiveView
        PubSub.broadcast(
          Frestyl.PubSub,
          "session:#{state.session_id}",
          {:participant_left, user_id}
        )

        # Check if session should be ended
        new_state = if length(new_participants) == 0 do
          schedule_session_cleanup()
          %{new_state | status: :ending}
        else
          new_state
        end

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:get_session_info, _from, state) do
    session_info = %{
      session_id: state.session_id,
      session_type: state.session_type,
      host: state.host_user,
      participants: state.participants,
      feature_gates: state.feature_gates,
      started_at: state.started_at,
      status: state.status,
      engines: Map.keys(state.engines),
      participant_count: length(state.participants)
    }

    {:reply, session_info, state}
  end

  @impl true
  def handle_call({:update_settings, user_id, settings}, _from, state) do
    participant = Enum.find(state.participants, &(&1.user.id == user_id))

    if participant && can_update_settings?(participant.role, participant.permissions) do
      # Apply settings updates
      apply_session_settings(state.session_id, settings, participant)
      {:reply, :ok, state}
    else
      {:reply, {:error, :insufficient_permissions}, state}
    end
  end

  @impl true
  def handle_info({:session_cleanup}, state) do
    Logger.info("Cleaning up session #{state.session_id}")
    SessionIntegration.shutdown_session(state.session_id)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Helper Functions

  defp build_feature_gates(user) do
    tier = TierManager.get_account_tier(user)

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

  defp get_max_participants(host_user, session_type) do
    tier = TierManager.get_account_tier(host_user)
    limits = TierManager.get_tier_limits(tier)

    base_limit = case session_type do
      :consultation -> 2
      :broadcast -> 1000  # viewers
      :tutorial -> 50
      :collaboration -> 8
    end

    Map.get(limits, :max_session_participants, base_limit)
  end

  defp participant_exists?(participants, user_id) do
    Enum.any?(participants, &(&1.user.id == user_id))
  end

  defp can_join_session?(session_type, user_tier) do
    case session_type do
      :consultation -> true  # All tiers can join consultations
      :broadcast -> true     # All tiers can view broadcasts
      :tutorial -> true      # All tiers can attend tutorials
      :collaboration -> FeatureGate.feature_available?(user_tier, :collaboration_sessions)
    end
  end

  defp get_participant_permissions(role, user_tier, feature_gates) do
    base_permissions = case role do
      :host ->
        %{
          can_record: feature_gates.recording,
          can_stream: feature_gates.streaming,
          can_share_screen: feature_gates.screen_sharing,
          can_manage_session: true,
          can_mute_others: true,
          can_kick_participants: true
        }

      :co_host ->
        %{
          can_record: feature_gates.recording,
          can_stream: false,
          can_share_screen: feature_gates.screen_sharing,
          can_manage_session: false,
          can_mute_others: true,
          can_kick_participants: false
        }

      :participant ->
        %{
          can_record: false,
          can_stream: false,
          can_share_screen: FeatureGate.feature_available?(user_tier, :screen_sharing),
          can_manage_session: false,
          can_mute_others: false,
          can_kick_participants: false
        }
    end

    # Apply tier-based restrictions
    Map.merge(base_permissions, %{
      can_use_effects: feature_gates.effects,
      can_multitrack: feature_gates.multitrack,
      can_share_files: feature_gates.file_sharing
    })
  end

  defp can_update_settings?(role, permissions) do
    role in [:host, :co_host] or permissions.can_manage_session
  end

  defp apply_session_settings(session_id, settings, participant) do
    # Apply various session settings
    Enum.each(settings, fn {key, value} ->
      case key do
        "quality" -> update_stream_quality(session_id, value)
        "recording" -> toggle_recording(session_id, value, participant)
        "layout" -> update_layout(session_id, value)
        _ -> :ok
      end
    end)
  end

  defp update_stream_quality(session_id, quality) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "session:#{session_id}",
      {:quality_updated, quality}
    )
  end

  defp toggle_recording(session_id, enabled, participant) do
    event = if enabled, do: :recording_started, else: :recording_stopped

    SessionIntegration.handle_session_event(session_id, event, %{
      user_id: participant.user.id,
      initiated_by: participant.role
    })
  end

  defp update_layout(session_id, layout) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "session:#{session_id}",
      {:layout_updated, layout}
    )
  end

  defp schedule_session_cleanup do
    Process.send_after(self(), {:session_cleanup}, 30_000) # 30 seconds grace period
  end

  defp via_tuple(session_id) do
    {:via, Registry, {Frestyl.SessionRegistry, {:session_manager, session_id}}}
  end
end
