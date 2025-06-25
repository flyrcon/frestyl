# lib/frestyl/streaming/engine.ex
defmodule Frestyl.Streaming.Engine do
  @moduledoc """
  Core streaming engine for live performance & streaming with tiered capabilities.

  Follows the proven RecordingEngine patterns but specialized for streaming:
  - Session-based streaming management
  - Subscription tier-aware quality and limits
  - Multi-platform distribution
  - Real-time audience management
  """

  use GenServer
  require Logger

  alias Frestyl.Streaming.{QualityManager, AudienceManager, RTMPHandler, DistributionManager}
  alias Frestyl.Accounts
  alias Phoenix.PubSub

  # Client API

  def start_link(stream_session_id) do
    GenServer.start_link(__MODULE__, stream_session_id, name: via_tuple(stream_session_id))
  end

  def start_stream(stream_session_id, user_id, stream_config) do
    GenServer.call(via_tuple(stream_session_id), {:start_stream, user_id, stream_config})
  end

  def stop_stream(stream_session_id, user_id) do
    GenServer.call(via_tuple(stream_session_id), {:stop_stream, user_id})
  end

  def join_audience(stream_session_id, viewer_id, viewer_metadata \\ %{}) do
    GenServer.call(via_tuple(stream_session_id), {:join_audience, viewer_id, viewer_metadata})
  end

  def leave_audience(stream_session_id, viewer_id) do
    GenServer.call(via_tuple(stream_session_id), {:leave_audience, viewer_id})
  end

  def send_video_chunk(stream_session_id, user_id, video_data, timestamp) do
    GenServer.cast(via_tuple(stream_session_id), {:video_chunk, user_id, video_data, timestamp})
  end

  def send_audio_chunk(stream_session_id, user_id, audio_data, timestamp) do
    GenServer.cast(via_tuple(stream_session_id), {:audio_chunk, user_id, audio_data, timestamp})
  end

  def update_stream_settings(stream_session_id, user_id, settings) do
    GenServer.call(via_tuple(stream_session_id), {:update_settings, user_id, settings})
  end

  def get_stream_stats(stream_session_id) do
    GenServer.call(via_tuple(stream_session_id), :get_stats)
  end

  # Server Implementation

  @impl true
  def init(stream_session_id) do
    Logger.info("Starting streaming engine for session #{stream_session_id}")

    initial_state = %{
      stream_session_id: stream_session_id,
      active_streams: %{},
      audience: %{},
      stream_stats: %{
        start_time: nil,
        total_viewers: 0,
        peak_viewers: 0,
        bytes_sent: 0,
        frames_sent: 0
      },
      subscription_limits: %{},
      platform_endpoints: %{}
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_call({:start_stream, user_id, stream_config}, _from, state) do
    user = Accounts.get_user!(user_id)
    limits = get_streaming_limits(user.subscription_tier)

    case validate_stream_start(state, user, limits, stream_config) do
      {:ok, validated_config} ->
        case start_streaming_session(state, user, validated_config, limits) do
          {:ok, new_state} ->
            broadcast_stream_started(state.stream_session_id, user_id, validated_config)
            {:reply, {:ok, validated_config}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:stop_stream, user_id}, _from, state) do
    case Map.get(state.active_streams, user_id) do
      nil ->
        {:reply, {:error, :stream_not_found}, state}

      stream_session ->
        case stop_streaming_session(state, user_id, stream_session) do
          {:ok, new_state} ->
            broadcast_stream_stopped(state.stream_session_id, user_id, stream_session)
            {:reply, {:ok, stream_session}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:join_audience, viewer_id, viewer_metadata}, _from, state) do
    user = Accounts.get_user!(viewer_id)
    stream_owner = get_stream_owner(state)

    case validate_audience_join(state, user, stream_owner) do
      {:ok, audience_config} ->
        new_audience = Map.put(state.audience, viewer_id, %{
          user_id: viewer_id,
          joined_at: DateTime.utc_now(),
          metadata: viewer_metadata,
          config: audience_config
        })

        new_stats = update_audience_stats(state.stream_stats, map_size(new_audience))
        new_state = %{state | audience: new_audience, stream_stats: new_stats}

        broadcast_audience_joined(state.stream_session_id, viewer_id, audience_config)
        {:reply, {:ok, audience_config}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:leave_audience, viewer_id}, _from, state) do
    case Map.get(state.audience, viewer_id) do
      nil ->
        {:reply, {:error, :not_in_audience}, state}

      _viewer ->
        new_audience = Map.delete(state.audience, viewer_id)
        new_stats = update_audience_stats(state.stream_stats, map_size(new_audience))
        new_state = %{state | audience: new_audience, stream_stats: new_stats}

        broadcast_audience_left(state.stream_session_id, viewer_id)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:update_settings, user_id, settings}, _from, state) do
    case Map.get(state.active_streams, user_id) do
      nil ->
        {:reply, {:error, :stream_not_found}, state}

      stream_session ->
        user = Accounts.get_user!(user_id)
        limits = get_streaming_limits(user.subscription_tier)

        case validate_settings_update(settings, limits) do
          {:ok, validated_settings} ->
            updated_session = Map.merge(stream_session, validated_settings)
            new_streams = Map.put(state.active_streams, user_id, updated_session)
            new_state = %{state | active_streams: new_streams}

            broadcast_settings_updated(state.stream_session_id, user_id, validated_settings)
            {:reply, {:ok, validated_settings}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    enhanced_stats = Map.merge(state.stream_stats, %{
      current_viewers: map_size(state.audience),
      active_streams: map_size(state.active_streams),
      uptime: calculate_uptime(state.stream_stats.start_time)
    })

    {:reply, enhanced_stats, state}
  end

  @impl true
  def handle_cast({:video_chunk, user_id, video_data, timestamp}, state) do
    case Map.get(state.active_streams, user_id) do
      nil ->
        {:noreply, state}

      stream_session ->
        # Process video chunk through quality manager and distribution
        processed_chunk = QualityManager.process_video_chunk(video_data, stream_session.quality_settings)

        # Send to RTMP endpoints
        RTMPHandler.send_video_chunk(stream_session.rtmp_endpoints, processed_chunk, timestamp)

        # Send to platform distributors
        DistributionManager.distribute_video_chunk(stream_session.platform_config, processed_chunk, timestamp)

        # Update stats
        new_stats = update_chunk_stats(state.stream_stats, :video, byte_size(video_data))
        new_state = %{state | stream_stats: new_stats}

        # Broadcast to audience
        broadcast_chunk_received(state.stream_session_id, user_id, :video, byte_size(video_data))

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast({:audio_chunk, user_id, audio_data, timestamp}, state) do
    case Map.get(state.active_streams, user_id) do
      nil ->
        {:noreply, state}

      stream_session ->
        # Process audio chunk
        processed_chunk = QualityManager.process_audio_chunk(audio_data, stream_session.quality_settings)

        # Send to RTMP endpoints
        RTMPHandler.send_audio_chunk(stream_session.rtmp_endpoints, processed_chunk, timestamp)

        # Send to platform distributors
        DistributionManager.distribute_audio_chunk(stream_session.platform_config, processed_chunk, timestamp)

        # Update stats
        new_stats = update_chunk_stats(state.stream_stats, :audio, byte_size(audio_data))
        new_state = %{state | stream_stats: new_stats}

        # Broadcast to audience
        broadcast_chunk_received(state.stream_session_id, user_id, :audio, byte_size(audio_data))

        {:noreply, new_state}
    end
  end

  # Helper Functions

  defp via_tuple(stream_session_id) do
    {:via, Registry, {Frestyl.Streaming.Registry, stream_session_id}}
  end

  defp get_streaming_limits(subscription_tier) do
    case subscription_tier do
      "personal" -> %{
        max_quality: "720p",
        max_duration_minutes: 30,
        max_viewers: 10,
        max_platforms: 1,
        interaction_features: [:basic_chat],
        analytics_retention_days: 7
      }

      "creator" -> %{
        max_quality: "1080p",
        max_duration_minutes: 120,
        max_viewers: 100,
        max_platforms: 3,
        interaction_features: [:chat, :polls, :quiz],
        analytics_retention_days: 30,
        social_clips: true
      }

      "professional" -> %{
        max_quality: "4K",
        max_duration_minutes: -1, # unlimited
        max_viewers: 1000,
        max_platforms: -1, # unlimited
        interaction_features: [:chat, :polls, :quiz, :q_and_a, :reactions],
        analytics_retention_days: 90,
        custom_rtmp: true,
        advanced_analytics: true
      }

      "enterprise" -> %{
        max_quality: "custom",
        max_duration_minutes: -1,
        max_viewers: -1,
        max_platforms: -1,
        interaction_features: [:all],
        analytics_retention_days: 365,
        api_access: true,
        white_label: true,
        custom_domains: true,
        priority_support: true
      }

      _ -> get_streaming_limits("personal") # Default to personal
    end
  end

  defp validate_stream_start(state, user, limits, stream_config) do
    with :ok <- check_active_stream_limit(state, user, limits),
         :ok <- check_quality_limit(stream_config.quality, limits),
         :ok <- check_platform_limit(stream_config.platforms, limits),
         :ok <- check_duration_limit(stream_config.max_duration, limits) do

      validated_config = %{
        quality: normalize_quality(stream_config.quality, limits),
        platforms: validate_platforms(stream_config.platforms, limits),
        interaction_features: validate_interactions(stream_config.interaction_features, limits),
        max_duration: normalize_duration(stream_config.max_duration, limits),
        rtmp_endpoints: setup_rtmp_endpoints(stream_config, limits),
        platform_config: setup_platform_config(stream_config.platforms, limits)
      }

      {:ok, validated_config}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_streaming_session(state, user, config, limits) do
    stream_session = %{
      user_id: user.id,
      started_at: DateTime.utc_now(),
      quality_settings: QualityManager.get_quality_settings(config.quality),
      rtmp_endpoints: config.rtmp_endpoints,
      platform_config: config.platform_config,
      interaction_features: config.interaction_features,
      limits: limits,
      status: :active
    }

    # Initialize RTMP handlers
    case RTMPHandler.start_stream(stream_session.rtmp_endpoints) do
      {:ok, rtmp_sessions} ->
        updated_session = Map.put(stream_session, :rtmp_sessions, rtmp_sessions)
        new_streams = Map.put(state.active_streams, user.id, updated_session)
        new_stats = Map.put(state.stream_stats, :start_time, DateTime.utc_now())

        {:ok, %{state | active_streams: new_streams, stream_stats: new_stats}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp stop_streaming_session(state, user_id, stream_session) do
    # Stop RTMP streams
    RTMPHandler.stop_stream(stream_session.rtmp_sessions)

    # Clean up platform connections
    DistributionManager.stop_distribution(stream_session.platform_config)

    # Remove from active streams
    new_streams = Map.delete(state.active_streams, user_id)

    {:ok, %{state | active_streams: new_streams}}
  end

  defp validate_audience_join(state, viewer, stream_owner) do
    stream_owner_limits = get_streaming_limits(stream_owner.subscription_tier)
    current_viewers = map_size(state.audience)

    cond do
      stream_owner_limits.max_viewers != -1 and current_viewers >= stream_owner_limits.max_viewers ->
        {:error, :viewer_limit_exceeded}

      viewer.subscription_tier in ["professional", "enterprise"] ->
        {:ok, %{priority_access: true, features: [:all]}}

      true ->
        {:ok, %{priority_access: false, features: stream_owner_limits.interaction_features}}
    end
  end

  # Broadcasting functions
  defp broadcast_stream_started(stream_session_id, user_id, config) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:stream_started, user_id, config})
  end

  defp broadcast_stream_stopped(stream_session_id, user_id, session) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:stream_stopped, user_id, session})
  end

  defp broadcast_audience_joined(stream_session_id, viewer_id, config) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:audience_joined, viewer_id, config})
  end

  defp broadcast_audience_left(stream_session_id, viewer_id) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:audience_left, viewer_id})
  end

  defp broadcast_settings_updated(stream_session_id, user_id, settings) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:settings_updated, user_id, settings})
  end

  defp broadcast_chunk_received(stream_session_id, user_id, type, size) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:chunk_received, user_id, type, size})
  end

  # Stats and utility functions
  defp update_audience_stats(stats, current_viewers) do
    stats
    |> Map.put(:total_viewers, max(stats.total_viewers, current_viewers))
    |> Map.put(:peak_viewers, max(stats.peak_viewers, current_viewers))
  end

  defp update_chunk_stats(stats, type, size) do
    stats
    |> Map.update(:bytes_sent, size, &(&1 + size))
    |> Map.update(:frames_sent, 1, &(&1 + 1))
  end

  defp calculate_uptime(nil), do: 0
  defp calculate_uptime(start_time) do
    DateTime.diff(DateTime.utc_now(), start_time, :second)
  end

  defp get_stream_owner(state) do
    case Enum.find(state.active_streams, fn {_user_id, _session} -> true end) do
      {user_id, _session} -> Accounts.get_user!(user_id)
      nil -> nil
    end
  end

  # Validation helpers (simplified - would need full implementation)
  defp check_active_stream_limit(_state, _user, _limits), do: :ok
  defp check_quality_limit(_quality, _limits), do: :ok
  defp check_platform_limit(_platforms, _limits), do: :ok
  defp check_duration_limit(_duration, _limits), do: :ok
  defp validate_settings_update(_settings, _limits), do: {:ok, %{}}

  defp normalize_quality(quality, limits), do: quality
  defp validate_platforms(platforms, limits), do: platforms
  defp validate_interactions(features, limits), do: features
  defp normalize_duration(duration, limits), do: duration
  defp setup_rtmp_endpoints(config, limits), do: []
  defp setup_platform_config(platforms, limits), do: %{}
end
