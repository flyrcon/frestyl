
# lib/frestyl_web/live/streaming_live/index.ex
defmodule FrestylWeb.StreamingLive.Index do
  @moduledoc """
  Main streaming interface LiveView with subscription tier-aware features.

  Provides:
  - Stream creation and management
  - Real-time audience monitoring
  - Subscription-based feature access
  - Multi-platform distribution
  - Analytics and performance tracking
  """

  use FrestylWeb, :live_view
  require Logger

  alias Frestyl.Streaming.{Engine, Supervisor}
  alias Frestyl.Streaming.AudienceManager
  alias Frestyl.Accounts
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      # Subscribe to user's streaming events
      PubSub.subscribe(Frestyl.PubSub, "user_streams:#{user.id}")
    end

    # Get user's streaming limits based on subscription
    streaming_limits = get_streaming_limits(user.subscription_tier)

    # Get user's active streams
    active_streams = get_user_active_streams(user.id)

    socket = socket
    |> assign(:page_title, "Live Streaming")
    |> assign(:streaming_limits, streaming_limits)
    |> assign(:active_streams, active_streams)
    |> assign(:stream_session_id, nil)
    |> assign(:streaming_state, :setup)
    |> assign(:audience_count, 0)
    |> assign(:show_create_modal, false)
    |> assign(:show_upgrade_modal, false)
    |> assign(:stream_stats, %{})
    |> assign(:platform_connections, %{})
    |> assign(:quality_settings, get_default_quality_settings(user.subscription_tier))
    |> assign(:interaction_features, streaming_limits.interaction_features)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # Stream Management Events

  @impl true
  def handle_event("show_create_stream_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  @impl true
  def handle_event("hide_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  @impl true
  def handle_event("create_stream", %{"stream_config" => stream_config}, socket) do
    user = socket.assigns.current_user

    # Validate stream creation against user's limits
    case validate_stream_creation(user, stream_config, socket.assigns.streaming_limits) do
      {:ok, validated_config} ->
        case start_new_stream(user, validated_config) do
          {:ok, stream_session_id} ->
            # Subscribe to this stream's events
            PubSub.subscribe(Frestyl.PubSub, "stream:#{stream_session_id}")

            socket = socket
            |> assign(:stream_session_id, stream_session_id)
            |> assign(:streaming_state, :ready)
            |> assign(:show_create_modal, false)
            |> put_flash(:info, "Stream created successfully! Ready to go live.")

            {:noreply, socket}

          {:error, reason} ->
            socket = socket
            |> put_flash(:error, "Failed to create stream: #{format_error(reason)}")

            {:noreply, socket}
        end

      {:error, :limit_exceeded} ->
        socket = socket
        |> assign(:show_upgrade_modal, true)
        |> assign(:show_create_modal, false)

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Invalid stream configuration: #{format_error(reason)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_streaming", _params, socket) do
    stream_session_id = socket.assigns.stream_session_id
    user_id = socket.assigns.current_user.id

    stream_config = %{
      quality: socket.assigns.quality_settings.selected_quality,
      platforms: get_enabled_platforms(socket.assigns.platform_connections),
      interaction_features: socket.assigns.interaction_features,
      max_duration: socket.assigns.streaming_limits.max_duration_minutes
    }

    case Engine.start_stream(stream_session_id, user_id, stream_config) do
      {:ok, validated_config} ->
        socket = socket
        |> assign(:streaming_state, :live)
        |> assign(:stream_config, validated_config)
        |> push_event("start_media_capture", %{
          quality_settings: validated_config.quality_settings,
          rtmp_endpoints: validated_config.rtmp_endpoints
        })

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Failed to start stream: #{format_error(reason)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stop_streaming", _params, socket) do
    stream_session_id = socket.assigns.stream_session_id
    user_id = socket.assigns.current_user.id

    case Engine.stop_stream(stream_session_id, user_id) do
      {:ok, _session} ->
        socket = socket
        |> assign(:streaming_state, :stopped)
        |> push_event("stop_media_capture", %{})
        |> put_flash(:info, "Stream ended successfully.")

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Failed to stop stream: #{format_error(reason)}")

        {:noreply, socket}
    end
  end

  # Media Events from JavaScript

  @impl true
  def handle_event("video_chunk", %{"data" => video_data, "timestamp" => timestamp}, socket) do
    if socket.assigns.streaming_state == :live do
      Engine.send_video_chunk(
        socket.assigns.stream_session_id,
        socket.assigns.current_user.id,
        video_data,
        timestamp
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_chunk", %{"data" => audio_data, "timestamp" => timestamp}, socket) do
    if socket.assigns.streaming_state == :live do
      Engine.send_audio_chunk(
        socket.assigns.stream_session_id,
        socket.assigns.current_user.id,
        audio_data,
        timestamp
      )
    end

    {:noreply, socket}
  end

  # Settings Events

  @impl true
  def handle_event("update_quality", %{"quality" => quality}, socket) do
    user = socket.assigns.current_user

    case validate_quality_for_tier(quality, user.subscription_tier) do
      {:ok, validated_quality} ->
        new_quality_settings = Map.put(socket.assigns.quality_settings, :selected_quality, validated_quality)

        socket = socket
        |> assign(:quality_settings, new_quality_settings)
        |> maybe_update_live_quality(validated_quality)

        {:noreply, socket}

      {:error, :not_allowed} ->
        socket = socket
        |> assign(:show_upgrade_modal, true)
        |> put_flash(:warning, "#{quality} quality requires a higher subscription tier")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_platform", %{"platform" => platform, "enabled" => enabled}, socket) do
    user = socket.assigns.current_user
    current_platforms = map_size(socket.assigns.platform_connections)

    cond do
      enabled and current_platforms >= socket.assigns.streaming_limits.max_platforms ->
        socket = socket
        |> assign(:show_upgrade_modal, true)
        |> put_flash(:warning, "Platform limit reached for your subscription tier")

        {:noreply, socket}

      true ->
        new_connections = if enabled do
          Map.put(socket.assigns.platform_connections, platform, %{
            enabled: true,
            connected: false,
            status: "configuring"
          })
        else
          Map.delete(socket.assigns.platform_connections, platform)
        end

        {:noreply, assign(socket, :platform_connections, new_connections)}
    end
  end

  # Audience Management Events

  @impl true
  def handle_event("moderate_viewer", %{"viewer_id" => viewer_id, "action" => action}, socket) do
    stream_session_id = socket.assigns.stream_session_id
    moderator_id = socket.assigns.current_user.id

    case AudienceManager.moderate_viewer(stream_session_id, moderator_id, viewer_id, action) do
      {:ok, _result} ->
        socket = socket
        |> put_flash(:info, "Moderation action applied successfully")

        {:noreply, socket}

      {:error, reason} ->
        socket = socket
        |> put_flash(:error, "Moderation failed: #{format_error(reason)}")

        {:noreply, socket}
    end
  end

  # Analytics Events

  @impl true
  def handle_event("refresh_stats", _params, socket) do
    if socket.assigns.stream_session_id do
      case Engine.get_stream_stats(socket.assigns.stream_session_id) do
        stats when is_map(stats) ->
          {:noreply, assign(socket, :stream_stats, stats)}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # PubSub Event Handlers

  @impl true
  def handle_info({:viewer_joined, viewer_id, metadata}, socket) do
    new_count = socket.assigns.audience_count + 1
    socket = socket
    |> assign(:audience_count, new_count)
    |> push_event("viewer_joined", %{viewer_id: viewer_id, metadata: metadata})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:viewer_left, viewer_id}, socket) do
    new_count = max(0, socket.assigns.audience_count - 1)
    socket = socket
    |> assign(:audience_count, new_count)
    |> push_event("viewer_left", %{viewer_id: viewer_id})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:interaction, viewer_id, type, data}, socket) do
    socket = socket
    |> push_event("new_interaction", %{
      viewer_id: viewer_id,
      type: type,
      data: data
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stream_started, user_id, config}, socket) do
    if user_id == socket.assigns.current_user.id do
      socket = socket
      |> assign(:streaming_state, :live)
      |> assign(:stream_config, config)
    else
      socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stream_stopped, user_id, session}, socket) do
    if user_id == socket.assigns.current_user.id do
      socket = socket
      |> assign(:streaming_state, :stopped)
      |> assign(:stream_stats, calculate_final_stats(session))
    else
      socket
    end

    {:noreply, socket}
  end

  # Helper Functions

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
        max_duration_minutes: -1,
        max_viewers: 1000,
        max_platforms: -1,
        interaction_features: [:chat, :polls, :quiz, :q_and_a, :reactions],
        analytics_retention_days: 90,
        custom_rtmp: true
      }

      "enterprise" -> %{
        max_quality: "custom",
        max_duration_minutes: -1,
        max_viewers: -1,
        max_platforms: -1,
        interaction_features: [:all],
        analytics_retention_days: 365,
        api_access: true,
        white_label: true
      }

      _ -> get_streaming_limits("personal")
    end
  end

  defp get_default_quality_settings(subscription_tier) do
    limits = get_streaming_limits(subscription_tier)

    %{
      available_qualities: get_available_qualities(subscription_tier),
      selected_quality: limits.max_quality,
      max_quality: limits.max_quality
    }
  end

  defp get_available_qualities(subscription_tier) do
    case subscription_tier do
      "personal" -> ["480p", "720p"]
      "creator" -> ["480p", "720p", "1080p"]
      "professional" -> ["480p", "720p", "1080p", "4K"]
      "enterprise" -> ["480p", "720p", "1080p", "4K", "custom"]
      _ -> ["480p", "720p"]
    end
  end

  defp validate_stream_creation(user, stream_config, limits) do
    with :ok <- check_concurrent_stream_limit(user, limits),
         :ok <- check_quality_limit(stream_config["quality"], limits),
         :ok <- check_platform_limit(stream_config["platforms"], limits) do
      {:ok, stream_config}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_new_stream(user, stream_config) do
    stream_session_id = generate_stream_session_id()

    case Supervisor.start_streaming_engine(stream_session_id) do
      {:ok, _pid} ->
        {:ok, stream_session_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_quality_for_tier(quality, subscription_tier) do
    available_qualities = get_available_qualities(subscription_tier)

    if quality in available_qualities do
      {:ok, quality}
    else
      {:error, :not_allowed}
    end
  end

  defp maybe_update_live_quality(socket, quality) do
    if socket.assigns.streaming_state == :live do
      stream_session_id = socket.assigns.stream_session_id
      user_id = socket.assigns.current_user.id

      settings = %{quality: quality}
      Engine.update_stream_settings(stream_session_id, user_id, settings)

      push_event(socket, "update_quality", %{quality: quality})
    else
      socket
    end
  end

  defp get_enabled_platforms(platform_connections) do
    platform_connections
    |> Enum.filter(fn {_platform, config} -> config.enabled end)
    |> Enum.map(fn {platform, _config} -> platform end)
  end

  defp get_user_active_streams(user_id) do
    # This would query the database for user's active streams
    []
  end

  defp generate_stream_session_id do
    "stream_" <> (:crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16))
  end

  defp format_error(error) when is_atom(error), do: error |> Atom.to_string() |> String.replace("_", " ")
  defp format_error(error) when is_binary(error), do: error
  defp format_error(_), do: "Unknown error"

  defp calculate_final_stats(session) do
    # Calculate final stream statistics
    %{
      duration: DateTime.diff(DateTime.utc_now(), session.started_at, :second),
      total_viewers: session.total_viewers || 0,
      peak_viewers: session.peak_viewers || 0
    }
  end

  # Validation helpers (simplified implementations)
  defp check_concurrent_stream_limit(_user, _limits), do: :ok
  defp check_quality_limit(_quality, _limits), do: :ok
  defp check_platform_limit(_platforms, _limits), do: :ok

  # Helper Functions for Templates

  def format_duration(seconds) when is_integer(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    cond do
      hours > 0 -> "#{hours}h #{minutes}m"
      minutes > 0 -> "#{minutes}m #{secs}s"
      true -> "#{secs}s"
    end
  end

  def format_duration(_), do: "0s"

  def format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  def format_bytes(_), do: "0 B"
end
