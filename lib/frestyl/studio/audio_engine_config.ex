defmodule Frestyl.Studio.AudioEngineConfig do
  @moduledoc """
  Configuration module for audio engine settings based on user subscription tiers.
  """

  @doc """
  Gets the user tier based on their subscription.
  Returns an atom representing the tier: :free, :premium, :pro, or :enterprise
  """
  def get_user_tier(%{subscription_tier: tier}) when is_binary(tier) do
    case String.downcase(tier) do
      "premium" -> :premium
      "pro" -> :pro
      "enterprise" -> :enterprise
      _ -> :free
    end
  end

  def get_user_tier(%{subscription_tier: nil}), do: :free
  def get_user_tier(_user), do: :free

  @doc """
  Gets audio configuration settings based on user tier.
  """
  def get_audio_config(user_tier) when user_tier in [:free, :premium, :pro, :enterprise] do
    case user_tier do
      :enterprise -> %{
        max_bitrate: 320,
        sample_rate: 48000,
        buffer_size: 128,
        noise_reduction: true,
        echo_cancellation: true,
        advanced_features: true,
        max_participants: 100,
        recording_quality: "high"
      }

      :pro -> %{
        max_bitrate: 256,
        sample_rate: 44100,
        buffer_size: 256,
        noise_reduction: true,
        echo_cancellation: true,
        advanced_features: true,
        max_participants: 50,
        recording_quality: "medium"
      }

      :premium -> %{
        max_bitrate: 192,
        sample_rate: 44100,
        buffer_size: 512,
        noise_reduction: true,
        echo_cancellation: false,
        advanced_features: false,
        max_participants: 20,
        recording_quality: "medium"
      }

      :free -> %{
        max_bitrate: 128,
        sample_rate: 22050,
        buffer_size: 1024,
        noise_reduction: false,
        echo_cancellation: false,
        advanced_features: false,
        max_participants: 5,
        recording_quality: "low"
      }
    end
  end

  @doc """
  Checks if a user has access to a specific audio feature.
  """
  def has_feature?(user, feature) when is_atom(feature) do
    user_tier = get_user_tier(user)
    config = get_audio_config(user_tier)

    case feature do
      :noise_reduction -> config.noise_reduction
      :echo_cancellation -> config.echo_cancellation
      :advanced_features -> config.advanced_features
      :high_quality_recording -> config.recording_quality in ["high", "medium"]
      _ -> false
    end
  end

  @doc """
  Gets the maximum number of participants allowed for a user's tier.
  """
  def max_participants(user) do
    user_tier = get_user_tier(user)
    config = get_audio_config(user_tier)
    config.max_participants
  end

  @doc """
  Gets the audio quality settings for a user.
  """
  def get_quality_settings(user) do
    user_tier = get_user_tier(user)
    config = get_audio_config(user_tier)

    %{
      bitrate: config.max_bitrate,
      sample_rate: config.sample_rate,
      buffer_size: config.buffer_size,
      quality: config.recording_quality
    }
  end
end
