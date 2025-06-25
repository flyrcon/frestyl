# lib/frestyl/streaming/quality_manager.ex - PART 1
defmodule Frestyl.Streaming.QualityManager do
  @moduledoc """
  Manages streaming quality based on subscription tiers and system capabilities.

  Handles:
  - Tier-based quality settings (Personal: 720p, Creator: 1080p, Professional: 4K, Enterprise: Custom)
  - Video/audio processing and encoding
  - Adaptive bitrate for different platforms
  - Quality fallback and optimization
  """

  use GenServer
  require Logger

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_quality_settings(quality_tier) do
    GenServer.call(__MODULE__, {:get_quality_settings, quality_tier})
  end

  def process_video_chunk(video_data, quality_settings) do
    GenServer.call(__MODULE__, {:process_video_chunk, video_data, quality_settings})
  end

  def process_audio_chunk(audio_data, quality_settings) do
    GenServer.call(__MODULE__, {:process_audio_chunk, audio_data, quality_settings})
  end

  def validate_quality_tier(tier, subscription_tier) do
    GenServer.call(__MODULE__, {:validate_quality_tier, tier, subscription_tier})
  end

  def get_adaptive_settings(base_quality, platform_requirements) do
    GenServer.call(__MODULE__, {:get_adaptive_settings, base_quality, platform_requirements})
  end

  # Server Implementation

  @impl true
  def init(_) do
    Logger.info("Starting Quality Manager")

    state = %{
      quality_presets: build_quality_presets(),
      encoding_cache: %{},
      performance_metrics: %{
        processing_times: [],
        error_rates: %{}
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get_quality_settings, quality_tier}, _from, state) do
    settings = Map.get(state.quality_presets, quality_tier, state.quality_presets["720p"])
    {:reply, settings, state}
  end

  @impl true
  def handle_call({:process_video_chunk, video_data, quality_settings}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    result = case process_video_internal(video_data, quality_settings) do
      {:ok, processed_data} ->
        # Log processing time for monitoring
        processing_time = System.monotonic_time(:millisecond) - start_time
        new_state = update_performance_metrics(state, :video, processing_time, :success)

        {{:ok, processed_data}, new_state}

      {:error, reason} ->
        processing_time = System.monotonic_time(:millisecond) - start_time
        new_state = update_performance_metrics(state, :video, processing_time, :error)

        Logger.error("Video processing failed: #{inspect(reason)}")
        {{:error, reason}, new_state}
    end

    case result do
      {{:ok, processed_data}, new_state} ->
        {:reply, {:ok, processed_data}, new_state}

      {{:error, reason}, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:process_audio_chunk, audio_data, quality_settings}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    result = case process_audio_internal(audio_data, quality_settings) do
      {:ok, processed_data} ->
        processing_time = System.monotonic_time(:millisecond) - start_time
        new_state = update_performance_metrics(state, :audio, processing_time, :success)

        {{:ok, processed_data}, new_state}

      {:error, reason} ->
        processing_time = System.monotonic_time(:millisecond) - start_time
        new_state = update_performance_metrics(state, :audio, processing_time, :error)

        Logger.error("Audio processing failed: #{inspect(reason)}")
        {{:error, reason}, new_state}
    end

    case result do
      {{:ok, processed_data}, new_state} ->
        {:reply, {:ok, processed_data}, new_state}

      {{:error, reason}, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:validate_quality_tier, tier, subscription_tier}, _from, state) do
    allowed_tiers = get_allowed_quality_tiers(subscription_tier)
    is_valid = tier in allowed_tiers

    result = if is_valid do
      {:ok, tier}
    else
      highest_allowed = List.last(allowed_tiers)
      Logger.warning("Quality tier #{tier} not allowed for #{subscription_tier}, falling back to #{highest_allowed}")
      {:fallback, highest_allowed}
    end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_adaptive_settings, base_quality, platform_requirements}, _from, state) do
    adaptive_settings = calculate_adaptive_settings(base_quality, platform_requirements, state.quality_presets)
    {:reply, adaptive_settings, state}
  end

  # Internal Processing Functions

  defp build_quality_presets do
    %{
      # Personal Tier - 720p max
      "720p" => %{
        video: %{
          resolution: {1280, 720},
          bitrate: 2500,
          framerate: 30,
          codec: "h264",
          profile: "main",
          keyframe_interval: 2
        },
        audio: %{
          bitrate: 128,
          sample_rate: 44100,
          channels: 2,
          codec: "aac"
        },
        tier_limits: %{
          max_duration_minutes: 30,
          max_concurrent_streams: 1
        }
      },

      # Creator Tier - 1080p max
      "1080p" => %{
        video: %{
          resolution: {1920, 1080},
          bitrate: 5000,
          framerate: 30,
          codec: "h264",
          profile: "high",
          keyframe_interval: 2
        },
        audio: %{
          bitrate: 160,
          sample_rate: 48000,
          channels: 2,
          codec: "aac"
        },
        tier_limits: %{
          max_duration_minutes: 120,
          max_concurrent_streams: 3,
          social_clips: true
        }
      },

      # Professional Tier - 4K max
      "4K" => %{
        video: %{
          resolution: {3840, 2160},
          bitrate: 15000,
          framerate: 60,
          codec: "h264",
          profile: "high",
          keyframe_interval: 2,
          advanced_encoding: true
        },
        audio: %{
          bitrate: 320,
          sample_rate: 48000,
          channels: 2,
          codec: "aac",
          advanced_processing: true
        },
        tier_limits: %{
          max_duration_minutes: -1, # unlimited
          max_concurrent_streams: -1, # unlimited
          custom_rtmp: true,
          advanced_analytics: true
        }
      },

      # Enterprise Tier - Custom quality
      "custom" => %{
        video: %{
          resolution: :custom, # Can be set per stream
          bitrate: :custom,
          framerate: :custom,
          codec: :custom,
          profile: :custom,
          keyframe_interval: :custom,
          hardware_acceleration: true
        },
        audio: %{
          bitrate: :custom,
          sample_rate: :custom,
          channels: :custom,
          codec: :custom,
          professional_processing: true
        },
        tier_limits: %{
          max_duration_minutes: -1,
          max_concurrent_streams: -1,
          api_access: true,
          white_label: true,
          priority_processing: true
        }
      }
    }
  end

  defp process_video_internal(video_data, quality_settings) do
    try do
      # Simulate video processing - in production this would use FFmpeg or similar
      processed_data = %{
        original_size: byte_size(video_data),
        processed_data: video_data, # Would be actual processed video
        encoding_settings: quality_settings.video,
        processing_metadata: %{
          timestamp: DateTime.utc_now(),
          processing_time_ms: :rand.uniform(50), # Simulated
          quality_applied: quality_settings.video.resolution
        }
      }

      {:ok, processed_data}
    rescue
      error ->
        {:error, {:processing_failed, error}}
    end
  end

  defp process_audio_internal(audio_data, quality_settings) do
    try do
      # Simulate audio processing
      processed_data = %{
        original_size: byte_size(audio_data),
        processed_data: audio_data, # Would be actual processed audio
        encoding_settings: quality_settings.audio,
        processing_metadata: %{
          timestamp: DateTime.utc_now(),
          processing_time_ms: :rand.uniform(20), # Simulated
          quality_applied: quality_settings.audio.bitrate
        }
      }

      {:ok, processed_data}
    rescue
      error ->
        {:error, {:processing_failed, error}}
    end
  end

  defp get_allowed_quality_tiers(subscription_tier) do
    case subscription_tier do
      "personal" -> ["720p"]
      "creator" -> ["720p", "1080p"]
      "professional" -> ["720p", "1080p", "4K"]
      "enterprise" -> ["720p", "1080p", "4K", "custom"]
      _ -> ["720p"] # Default fallback
    end
  end

  defp calculate_adaptive_settings(base_quality, platform_requirements, quality_presets) do
    base_settings = Map.get(quality_presets, base_quality, quality_presets["720p"])

    # Adapt settings based on platform requirements
    Enum.map(platform_requirements, fn {platform, requirements} ->
      adapted_settings = case platform do
        "twitch" ->
          adapt_for_twitch(base_settings, requirements)

        "youtube" ->
          adapt_for_youtube(base_settings, requirements)

        "facebook" ->
          adapt_for_facebook(base_settings, requirements)

        "custom_rtmp" ->
          adapt_for_custom_rtmp(base_settings, requirements)

        _ ->
          base_settings
      end

      {platform, adapted_settings}
    end)
    |> Enum.into(%{})
  end

  defp adapt_for_twitch(base_settings, _requirements) do
    # Twitch-specific optimizations
    %{base_settings |
      video: Map.merge(base_settings.video, %{
        keyframe_interval: 2, # Twitch prefers 2s keyframes
        bitrate: min(base_settings.video.bitrate, 8000) # Twitch max bitrate
      })
    }
  end

  defp adapt_for_youtube(base_settings, _requirements) do
    # YouTube-specific optimizations
    %{base_settings |
      video: Map.merge(base_settings.video, %{
        keyframe_interval: 4, # YouTube can handle longer keyframe intervals
        profile: "high" # YouTube prefers high profile
      })
    }
  end

  defp adapt_for_facebook(base_settings, _requirements) do
    # Facebook-specific optimizations
    %{base_settings |
      video: Map.merge(base_settings.video, %{
        bitrate: min(base_settings.video.bitrate, 4000), # Facebook bitrate limits
        framerate: min(base_settings.video.framerate, 30) # Facebook framerate limits
      })
    }
  end

  defp adapt_for_custom_rtmp(base_settings, requirements) do
    # Use custom requirements if provided
    video_overrides = Map.get(requirements, :video, %{})
    audio_overrides = Map.get(requirements, :audio, %{})

    %{base_settings |
      video: Map.merge(base_settings.video, video_overrides),
      audio: Map.merge(base_settings.audio, audio_overrides)
    }
  end

  defp update_performance_metrics(state, type, processing_time, result) do
    # Update processing time metrics
    new_times = [processing_time | state.performance_metrics.processing_times]
    |> Enum.take(100) # Keep last 100 measurements

    # Update error rates
    new_error_rates = case result do
      :success ->
        current_errors = Map.get(state.performance_metrics.error_rates, type, 0)
        Map.put(state.performance_metrics.error_rates, type, max(0, current_errors - 1))

      :error ->
        current_errors = Map.get(state.performance_metrics.error_rates, type, 0)
        Map.put(state.performance_metrics.error_rates, type, current_errors + 1)
    end

    new_metrics = %{
      processing_times: new_times,
      error_rates: new_error_rates
    }

    %{state | performance_metrics: new_metrics}
  end

  # Public helper functions for other modules

  def get_bitrate_for_resolution({1280, 720}), do: 2500
  def get_bitrate_for_resolution({1920, 1080}), do: 5000
  def get_bitrate_for_resolution({3840, 2160}), do: 15000
  def get_bitrate_for_resolution(_), do: 2500 # Default

  def estimate_bandwidth_usage(quality_settings) do
    video_bitrate = quality_settings.video.bitrate
    audio_bitrate = quality_settings.audio.bitrate

    # Add 20% overhead for protocol and network overhead
    total_bitrate = (video_bitrate + audio_bitrate) * 1.2

    %{
      video_kbps: video_bitrate,
      audio_kbps: audio_bitrate,
      total_kbps: round(total_bitrate),
      estimated_mb_per_minute: round(total_bitrate * 60 / 8 / 1024)
    }
  end

  def recommend_quality_for_bandwidth(available_bandwidth_kbps) do
    cond do
      available_bandwidth_kbps >= 20000 -> "4K"
      available_bandwidth_kbps >= 6000 -> "1080p"
      available_bandwidth_kbps >= 3000 -> "720p"
      true -> "480p" # Fallback quality
    end
  end
end
