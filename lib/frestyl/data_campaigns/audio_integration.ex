# File: lib/frestyl/data_campaigns/audio_integration.ex

defmodule Frestyl.DataCampaigns.AudioIntegration do
  @moduledoc """
  Integrates recording engine with content campaigns for music/podcast tracking.
  """

  alias Frestyl.Studio.RecordingEngine
  alias Frestyl.DataCampaigns.AdvancedTracker
  alias Phoenix.PubSub

  @doc """
  Hooks into recording engine to track audio contributions for campaigns.
  """
  def setup_campaign_recording_hooks(campaign_id, session_id) do
    # Subscribe to recording engine events
    PubSub.subscribe(Frestyl.PubSub, "recording_engine:#{session_id}")

    # Store campaign-session mapping
    :ets.insert(:campaign_sessions, {session_id, campaign_id})

    {:ok, :hooks_setup}
  end

  @doc """
  Processes recording completion and updates campaign metrics.
  """
  def handle_recording_complete(session_id, track_record) do
    case :ets.lookup(:campaign_sessions, session_id) do
      [{^session_id, campaign_id}] ->
        # Calculate contribution metrics from recording
        contribution_data = %{
          duration_seconds: track_record.duration,
          track_type: determine_track_type(track_record),
          quality_settings: track_record.quality_settings,
          audio_data: track_record.audio_data
        }

        # Update campaign tracker
        AdvancedTracker.track_audio_contribution(
          campaign_id,
          track_record.user_id,
          contribution_data
        )

        # Check if this contribution completes any quality gates
        check_audio_contribution_gates(campaign_id, track_record.user_id, contribution_data)

      [] ->
        # Not a campaign recording, ignore
        :ok
    end
  end

  @doc """
  Real-time audio chunk processing for live contribution tracking.
  """
  def handle_audio_chunk(session_id, track_id, user_id, chunk_data) do
    case :ets.lookup(:campaign_sessions, session_id) do
      [{^session_id, campaign_id}] ->
        # Track live audio contribution
        live_contribution = %{
          type: :live_audio_chunk,
          chunk_size: byte_size(chunk_data.data),
          timestamp: chunk_data.timestamp,
          quality_metrics: analyze_chunk_quality(chunk_data)
        }

        # Update live metrics
        update_live_campaign_metrics(campaign_id, user_id, live_contribution)

        # Broadcast live update to campaign participants
        PubSub.broadcast(
          Frestyl.PubSub,
          "campaign:#{campaign_id}:live",
          {:live_contribution, user_id, live_contribution}
        )

      [] -> :ok
    end
  end

  # Private helper functions
  defp determine_track_type(track_record) do
    # Analyze track characteristics to determine type
    cond do
      String.contains?(track_record.metadata["name"] || "", ["vocal", "voice"]) ->
        :vocals
      String.contains?(track_record.metadata["name"] || "", ["beat", "drum"]) ->
        :beat
      String.contains?(track_record.metadata["name"] || "", ["bass"]) ->
        :bass
      String.contains?(track_record.metadata["name"] || "", ["guitar"]) ->
        :guitar
      true ->
        :other_instrument
    end
  end

  defp analyze_chunk_quality(chunk_data) do
    # Basic audio quality analysis
    %{
      signal_strength: calculate_signal_strength(chunk_data.data),
      noise_level: calculate_noise_level(chunk_data.data),
      clipping_detected: detect_clipping(chunk_data.data)
    }
  end

  defp calculate_signal_strength(audio_data) do
    # Simplified signal strength calculation
    case byte_size(audio_data) do
      size when size > 8000 -> 0.9
      size when size > 4000 -> 0.7
      _ -> 0.5
    end
  end

  defp calculate_noise_level(audio_data) do
    # Simplified noise analysis
    :rand.uniform() * 0.3  # Mock noise level 0-30%
  end

  defp detect_clipping(_audio_data) do
    # Mock clipping detection
    :rand.uniform() < 0.1  # 10% chance of clipping
  end

  defp check_audio_contribution_gates(campaign_id, user_id, contribution_data) do
    AdvancedTracker.check_quality_gates(campaign_id, user_id, :audio_contribution)
  end

  defp update_live_campaign_metrics(campaign_id, user_id, live_contribution) do
    # Update ETS with live metrics for real-time display
    case :ets.lookup(:live_campaign_metrics, campaign_id) do
      [{^campaign_id, metrics}] ->
        user_metrics = Map.get(metrics, user_id, %{total_chunks: 0, live_duration: 0})

        updated_user_metrics = %{
          total_chunks: user_metrics.total_chunks + 1,
          live_duration: user_metrics.live_duration + estimate_chunk_duration(live_contribution),
          last_activity: DateTime.utc_now(),
          quality_score: calculate_live_quality_score(user_metrics, live_contribution)
        }

        updated_metrics = Map.put(metrics, user_id, updated_user_metrics)
        :ets.insert(:live_campaign_metrics, {campaign_id, updated_metrics})

      [] ->
        initial_metrics = %{
          user_id => %{
            total_chunks: 1,
            live_duration: estimate_chunk_duration(live_contribution),
            last_activity: DateTime.utc_now(),
            quality_score: 0.8
          }
        }
        :ets.insert(:live_campaign_metrics, {campaign_id, initial_metrics})
    end
  end

  defp estimate_chunk_duration(live_contribution) do
    # Estimate duration based on chunk size
    live_contribution.chunk_size / 8000  # Rough estimate in seconds
  end

  defp calculate_live_quality_score(user_metrics, live_contribution) do
    # Calculate running quality score
    current_score = Map.get(user_metrics, :quality_score, 0.8)
    chunk_quality = live_contribution.quality_metrics

    # Weighted average with more weight on recent contributions
    new_quality = (chunk_quality.signal_strength - chunk_quality.noise_level) *
                  (if chunk_quality.clipping_detected, do: 0.7, else: 1.0)

    (current_score * 0.8) + (new_quality * 0.2)
  end
end
