# lib/frestyl/studio/workspace_manager.ex
defmodule Frestyl.Studio.WorkspaceManager do
  @moduledoc """
  Manages workspace state initialization, audio engines, and collaboration setup.
  """

  require Logger
  alias Frestyl.{Sessions, Presence}
  alias Frestyl.Studio.{AudioEngine, BeatMachine, MobileAudioEngine}
  alias Frestyl.Studio.CollaborationManager
  alias Phoenix.PubSub

  @default_workspace_state %{
    tracks: [],
    effects: [],
    master_settings: %{
      volume: 0.8,
      pan: 0.0
    },
    audio: %{
      tracks: [],
      selected_track: nil,
      recording: false,
      playing: false,
      current_time: 0,
      zoom_level: 1.0,
      track_counter: 0,
      version: 0
    },
    text: %{
      document: nil,
      active_document_id: nil,
      editor_mode: "guided",
      collaborative_editing: true,
      content: "",
      cursors: %{},
      selection: nil,
      version: 0,
      pending_operations: []
    },
    visual: %{
      elements: [],
      selected_element: nil,
      tool: "brush",
      brush_size: 5,
      color: "#4f46e5",
      version: 0
    },
    beat_machine: %{
      current_kit: "classic_808",
      patterns: %{},
      active_pattern: nil,
      playing: false,
      current_step: 0,
      bpm: 120,
      swing: 0,
      master_volume: 0.8,
      pattern_counter: 0,
      version: 0
    },
    audio_text: %{
      mode: "lyrics_with_audio",
      sync_enabled: true,
      current_text_block: nil,
      timeline: %{
        current_position: 0.0,
        duration: 0.0,
        markers: [],
        sync_points: []
      },
      text_sync: %{
        blocks: [],
        active_block_id: nil,
        scroll_position: 0,
        auto_scroll: true,
        highlight_current: true
      },
      beat_detection: %{
        enabled: false,
        bpm: 120,
        detected_beats: [],
        confidence: 0.0,
        auto_align: false
      },
      version: 0
    },
    tool_layout: %{
      left_dock: [],
      right_dock: ["chat"],
      bottom_dock: [],
      floating: [],
      minimized: []
    },
    collaboration_mode: "audio_production",
    user_tool_preferences: %{},
    ot_state: %{
      user_operations: %{},
      operation_queue: [],
      acknowledged_ops: MapSet.new(),
      local_version: 0,
      server_version: 0
    }
  }

  @doc """
  Initialize workspace state and collaboration mode for a new session.
  """
  def initialize_workspace(session_data, current_user, device_info) do
    # Determine collaboration mode based on session type
    collaboration_mode = get_session_collaboration_mode(session_data)

    # Get or create workspace state
    workspace_state = get_workspace_state(session_data.id) || @default_workspace_state
    workspace_state = ensure_workspace_state_structure(workspace_state)
    workspace_state = Map.put(workspace_state, :collaboration_mode, collaboration_mode)

    # Apply device-specific optimizations
    workspace_state = apply_device_optimizations(workspace_state, device_info)

    {workspace_state, collaboration_mode}
  end

  @doc """
  Start audio engines based on device capabilities.
  """
  def start_engines(session_id, is_mobile \\ false) do
    # Start appropriate audio engine
    audio_result = if is_mobile do
      start_mobile_audio_engine(session_id)
    else
      start_desktop_audio_engine(session_id)
    end

    # Start beat machine if not mobile or user has premium+
    beat_result = unless is_mobile do
      start_beat_machine(session_id)
    else
      :ok
    end

    case {audio_result, beat_result} do
      {:ok, :ok} -> :ok
      {:ok, _} -> :ok  # Beat machine is optional
      {error, _} -> error
    end
  end

  @doc """
  Get default tool for workspace type.
  """
  def get_default_tool(workspace_state) do
    case workspace_state.collaboration_mode do
      "collaborative_writing" -> "text"
      "content_review" -> "text"
      "lyrics_creation" -> "audio_text"
      "audiobook_production" -> "audio_text"
      _ -> "audio"
    end
  end

  @doc """
  Setup real-time subscriptions for collaboration.
  """
  def setup_subscriptions(session_id, user_id) do
    # Subscribe to various collaboration channels
    PubSub.subscribe(Frestyl.PubSub, "studio:#{session_id}")
    PubSub.subscribe(Frestyl.PubSub, "studio:#{session_id}:operations")
    PubSub.subscribe(Frestyl.PubSub, "user:#{user_id}")
    PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}:chat")
    PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")
    PubSub.subscribe(Frestyl.PubSub, "beat_machine:#{session_id}")
    PubSub.subscribe(Frestyl.PubSub, "mobile_audio:#{session_id}")
  end

  @doc """
  Track user presence with collaboration metadata.
  """
  def track_presence(session_id, current_user, device_info) do
    presence_data = %{
      user_id: current_user.id,
      username: current_user.username,
      avatar_url: current_user.avatar_url,
      joined_at: DateTime.utc_now(),
      active_tool: "audio",
      is_typing: false,
      last_activity: DateTime.utc_now(),
      ot_version: 0,
      is_recording: false,
      input_level: 0,
      active_audio_track: nil,
      audio_monitoring: false,
      is_mobile: device_info.is_mobile,
      device_type: device_info.device_type,
      screen_size: device_info.screen_size,
      supports_audio: device_info.supports_audio,
      battery_optimized: false,
      current_mobile_track: 0
    }

    Presence.track(self(), "studio:#{session_id}", current_user.id, presence_data)
  end

  # Private Functions

  defp get_session_collaboration_mode(session_data) do
    case session_data.session_type do
      "audio" -> "audio_production"
      "text" -> "collaborative_writing"
      "visual" -> "multimedia_creation"
      "lyrics" -> "lyrics_creation"
      "audiobook" -> "audiobook_production"
      "audio_text" -> "lyrics_creation"
      _ -> "audio_production"
    end
  end

  defp get_workspace_state(session_id) do
    case Sessions.get_workspace_state(session_id) do
      nil -> nil
      workspace_state -> normalize_workspace_state(workspace_state)
    end
  end

  defp ensure_workspace_state_structure(workspace_state) do
    # Ensure all required keys exist with defaults
    Map.merge(@default_workspace_state, workspace_state)
    |> ensure_ot_state()
  end

  defp ensure_ot_state(workspace_state) do
    # Ensure workspace state has operational transformation fields
    Map.merge(workspace_state, %{
      ot_version: Map.get(workspace_state, :ot_version, 0),
      pending_operations: Map.get(workspace_state, :pending_operations, [])
    })
  end

  defp apply_device_optimizations(workspace_state, device_info) do
    if device_info.is_mobile do
      # Apply mobile optimizations
      workspace_state
      |> put_in([:audio, :max_tracks], 4)
      |> put_in([:beat_machine, :simplified_ui], true)
      |> put_in([:text, :mobile_text_config, :voice_input_enabled], true)
      |> put_in([:audio_text, :mobile_config, :simplified_timeline], true)
    else
      workspace_state
    end
  end

  defp start_desktop_audio_engine(session_id) do
    case DynamicSupervisor.start_child(
      Frestyl.Studio.AudioEngineSupervisor,
      {AudioEngine, session_id}
    ) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} ->
        Logger.error("Failed to start audio engine: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp start_mobile_audio_engine(session_id) do
    case DynamicSupervisor.start_child(
      Frestyl.Studio.AudioEngineSupervisor,
      {MobileAudioEngine, session_id}
    ) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} ->
        Logger.error("Failed to start mobile audio engine: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp start_beat_machine(session_id) do
    case DynamicSupervisor.start_child(
      Frestyl.Studio.BeatMachineSupervisor,
      {BeatMachine, session_id}
    ) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} ->
        Logger.error("Failed to start beat machine: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp normalize_workspace_state(workspace_state) when is_map(workspace_state) do
    %{
      audio: normalize_audio_state(Map.get(workspace_state, "audio") || Map.get(workspace_state, :audio) || %{}),
      text: normalize_text_state(Map.get(workspace_state, "text") || Map.get(workspace_state, :text) || %{}),
      visual: normalize_visual_state(Map.get(workspace_state, "visual") || Map.get(workspace_state, :visual) || %{}),
      beat_machine: normalize_beat_machine_state(Map.get(workspace_state, "beat_machine") || Map.get(workspace_state, :beat_machine) || %{}),
      audio_text: normalize_audio_text_state(Map.get(workspace_state, "audio_text") || Map.get(workspace_state, :audio_text) || %{}),
      tool_layout: normalize_tool_layout(Map.get(workspace_state, "tool_layout") || Map.get(workspace_state, :tool_layout) || %{}),
      collaboration_mode: Map.get(workspace_state, "collaboration_mode") || Map.get(workspace_state, :collaboration_mode) || "audio_production",
      ot_state: Map.get(workspace_state, :ot_state) || @default_workspace_state.ot_state
    }
  end
  defp normalize_workspace_state(_), do: @default_workspace_state

  defp normalize_audio_state(audio_state) when is_map(audio_state) do
    %{
      tracks: normalize_tracks(Map.get(audio_state, "tracks") || Map.get(audio_state, :tracks) || []),
      selected_track: Map.get(audio_state, "selected_track") || Map.get(audio_state, :selected_track),
      recording: Map.get(audio_state, "recording") || Map.get(audio_state, :recording) || false,
      playing: Map.get(audio_state, "playing") || Map.get(audio_state, :playing) || false,
      current_time: Map.get(audio_state, "current_time") || Map.get(audio_state, :current_time) || 0,
      zoom_level: Map.get(audio_state, "zoom_level") || Map.get(audio_state, :zoom_level) || 1.0,
      track_counter: Map.get(audio_state, "track_counter") || Map.get(audio_state, :track_counter) || 0,
      version: Map.get(audio_state, "version") || Map.get(audio_state, :version) || 0
    }
  end
  defp normalize_audio_state(_), do: @default_workspace_state.audio

  defp normalize_tracks(tracks) when is_list(tracks) do
    Enum.map(tracks, fn track when is_map(track) ->
      %{
        id: Map.get(track, "id") || Map.get(track, :id) || "track-#{System.unique_integer([:positive])}",
        number: Map.get(track, "number") || Map.get(track, :number) || 1,
        name: Map.get(track, "name") || Map.get(track, :name) || "Untitled Track",
        clips: Map.get(track, "clips") || Map.get(track, :clips) || [],
        muted: Map.get(track, "muted") || Map.get(track, :muted) || false,
        solo: Map.get(track, "solo") || Map.get(track, :solo) || false,
        volume: Map.get(track, "volume") || Map.get(track, :volume) || 0.8,
        pan: Map.get(track, "pan") || Map.get(track, :pan) || 0.0,
        effects: Map.get(track, "effects") || Map.get(track, :effects) || [],
        created_by: Map.get(track, "created_by") || Map.get(track, :created_by),
        created_at: Map.get(track, "created_at") || Map.get(track, :created_at)
      }
    end)
  end
  defp normalize_tracks(_), do: []

  defp normalize_text_state(text_state) when is_map(text_state) do
    %{
      document: Map.get(text_state, "document") || Map.get(text_state, :document),
      active_document_id: Map.get(text_state, "active_document_id") || Map.get(text_state, :active_document_id),
      editor_mode: Map.get(text_state, "editor_mode") || Map.get(text_state, :editor_mode) || "guided",
      content: Map.get(text_state, "content") || Map.get(text_state, :content) || "",
      cursors: Map.get(text_state, "cursors") || Map.get(text_state, :cursors) || %{},
      selection: Map.get(text_state, "selection") || Map.get(text_state, :selection),
      version: Map.get(text_state, "version") || Map.get(text_state, :version) || 0,
      pending_operations: Map.get(text_state, "pending_operations") || Map.get(text_state, :pending_operations) || []
    }
  end
  defp normalize_text_state(_), do: @default_workspace_state.text

  defp normalize_visual_state(visual_state) when is_map(visual_state) do
    %{
      elements: Map.get(visual_state, "elements") || Map.get(visual_state, :elements) || [],
      selected_element: Map.get(visual_state, "selected_element") || Map.get(visual_state, :selected_element),
      tool: Map.get(visual_state, "tool") || Map.get(visual_state, :tool) || "brush",
      brush_size: Map.get(visual_state, "brush_size") || Map.get(visual_state, :brush_size) || 5,
      color: Map.get(visual_state, "color") || Map.get(visual_state, :color) || "#4f46e5",
      version: Map.get(visual_state, "version") || Map.get(visual_state, :version) || 0
    }
  end
  defp normalize_visual_state(_), do: @default_workspace_state.visual

  defp normalize_beat_machine_state(beat_state) when is_map(beat_state) do
    %{
      current_kit: Map.get(beat_state, "current_kit") || Map.get(beat_state, :current_kit) || "classic_808",
      patterns: Map.get(beat_state, "patterns") || Map.get(beat_state, :patterns) || %{},
      active_pattern: Map.get(beat_state, "active_pattern") || Map.get(beat_state, :active_pattern),
      playing: Map.get(beat_state, "playing") || Map.get(beat_state, :playing) || false,
      current_step: Map.get(beat_state, "current_step") || Map.get(beat_state, :current_step) || 0,
      bpm: Map.get(beat_state, "bpm") || Map.get(beat_state, :bpm) || 120,
      swing: Map.get(beat_state, "swing") || Map.get(beat_state, :swing) || 0,
      master_volume: Map.get(beat_state, "master_volume") || Map.get(beat_state, :master_volume) || 0.8,
      pattern_counter: Map.get(beat_state, "pattern_counter") || Map.get(beat_state, :pattern_counter) || 0,
      version: Map.get(beat_state, "version") || Map.get(beat_state, :version) || 0
    }
  end
  defp normalize_beat_machine_state(_), do: @default_workspace_state.beat_machine

  defp normalize_audio_text_state(audio_text_state) when is_map(audio_text_state) do
    %{
      mode: Map.get(audio_text_state, "mode") || Map.get(audio_text_state, :mode) || "lyrics_with_audio",
      sync_enabled: Map.get(audio_text_state, "sync_enabled") || Map.get(audio_text_state, :sync_enabled) || true,
      current_text_block: Map.get(audio_text_state, "current_text_block") || Map.get(audio_text_state, :current_text_block),
      timeline: normalize_timeline(Map.get(audio_text_state, "timeline") || Map.get(audio_text_state, :timeline) || %{}),
      text_sync: normalize_text_sync(Map.get(audio_text_state, "text_sync") || Map.get(audio_text_state, :text_sync) || %{}),
      beat_detection: normalize_beat_detection(Map.get(audio_text_state, "beat_detection") || Map.get(audio_text_state, :beat_detection) || %{}),
      version: Map.get(audio_text_state, "version") || Map.get(audio_text_state, :version) || 0
    }
  end
  defp normalize_audio_text_state(_), do: @default_workspace_state.audio_text

  defp normalize_timeline(timeline) when is_map(timeline) do
    %{
      current_position: Map.get(timeline, "current_position") || Map.get(timeline, :current_position) || 0.0,
      duration: Map.get(timeline, "duration") || Map.get(timeline, :duration) || 0.0,
      markers: Map.get(timeline, "markers") || Map.get(timeline, :markers) || [],
      sync_points: Map.get(timeline, "sync_points") || Map.get(timeline, :sync_points) || []
    }
  end
  defp normalize_timeline(_), do: @default_workspace_state.audio_text.timeline

  defp normalize_text_sync(text_sync) when is_map(text_sync) do
    %{
      blocks: Map.get(text_sync, "blocks") || Map.get(text_sync, :blocks) || [],
      active_block_id: Map.get(text_sync, "active_block_id") || Map.get(text_sync, :active_block_id),
      scroll_position: Map.get(text_sync, "scroll_position") || Map.get(text_sync, :scroll_position) || 0,
      auto_scroll: Map.get(text_sync, "auto_scroll") || Map.get(text_sync, :auto_scroll) || true,
      highlight_current: Map.get(text_sync, "highlight_current") || Map.get(text_sync, :highlight_current) || true
    }
  end
  defp normalize_text_sync(_), do: @default_workspace_state.audio_text.text_sync

  defp normalize_beat_detection(beat_detection) when is_map(beat_detection) do
    %{
      enabled: Map.get(beat_detection, "enabled") || Map.get(beat_detection, :enabled) || false,
      bpm: Map.get(beat_detection, "bpm") || Map.get(beat_detection, :bpm) || 120,
      detected_beats: Map.get(beat_detection, "detected_beats") || Map.get(beat_detection, :detected_beats) || [],
      confidence: Map.get(beat_detection, "confidence") || Map.get(beat_detection, :confidence) || 0.0,
      auto_align: Map.get(beat_detection, "auto_align") || Map.get(beat_detection, :auto_align) || false
    }
  end
  defp normalize_beat_detection(_), do: @default_workspace_state.audio_text.beat_detection

  defp normalize_tool_layout(tool_layout) when is_map(tool_layout) do
    %{
      left_dock: Map.get(tool_layout, "left_dock") || Map.get(tool_layout, :left_dock) || [],
      right_dock: Map.get(tool_layout, "right_dock") || Map.get(tool_layout, :right_dock) || ["chat"],
      bottom_dock: Map.get(tool_layout, "bottom_dock") || Map.get(tool_layout, :bottom_dock) || [],
      floating: Map.get(tool_layout, "floating") || Map.get(tool_layout, :floating) || [],
      minimized: Map.get(tool_layout, "minimized") || Map.get(tool_layout, :minimized) || []
    }
  end
  defp normalize_tool_layout(_), do: @default_workspace_state.tool_layout
end
