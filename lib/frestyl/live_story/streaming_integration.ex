# lib/frestyl/live_story/streaming_integration.ex
defmodule Frestyl.LiveStory.StreamingIntegration do
  @moduledoc """
  Integration utilities for streaming platforms and services.
  """

  @doc """
  Get supported streaming platforms
  """
  def get_supported_platforms do
    %{
      "youtube" => %{
        name: "YouTube Live",
        api_required: true,
        features: ["live_streaming", "chat_integration", "audience_metrics"],
        setup_requirements: ["youtube_api_key", "channel_verification"]
      },
      "twitch" => %{
        name: "Twitch",
        api_required: true,
        features: ["live_streaming", "chat_integration", "interactive_extensions"],
        setup_requirements: ["twitch_client_id", "channel_authorization"]
      },
      "discord" => %{
        name: "Discord",
        api_required: true,
        features: ["voice_channels", "screen_sharing", "server_integration"],
        setup_requirements: ["discord_bot_token", "server_permissions"]
      },
      "zoom" => %{
        name: "Zoom",
        api_required: true,
        features: ["video_conferencing", "breakout_rooms", "recording"],
        setup_requirements: ["zoom_api_credentials", "meeting_permissions"]
      },
      "native" => %{
        name: "Frestyl Native Streaming",
        api_required: false,
        features: ["integrated_chat", "audience_voting", "session_recording"],
        setup_requirements: []
      }
    }
  end

  @doc """
  Configure streaming for a live story session
  """
  def configure_streaming(session, platform, config) do
    case validate_platform_config(platform, config) do
      {:ok, validated_config} ->
        streaming_config = %{
          platform: platform,
          config: validated_config,
          status: "configured",
          configured_at: DateTime.utc_now()
        }

        {:ok, streaming_config}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_platform_config("native", _config) do
    {:ok, %{}}
  end

  defp validate_platform_config("youtube", config) do
    required_fields = ["api_key", "channel_id"]

    case validate_required_fields(config, required_fields) do
      :ok -> {:ok, config}
      error -> error
    end
  end

  defp validate_platform_config("twitch", config) do
    required_fields = ["client_id", "channel_name"]

    case validate_required_fields(config, required_fields) do
      :ok -> {:ok, config}
      error -> error
    end
  end

  defp validate_platform_config(platform, _config) do
    {:error, "Unsupported platform: #{platform}"}
  end

  defp validate_required_fields(config, required_fields) do
    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(config, field) or is_nil(config[field])
    end)

    case missing_fields do
      [] -> :ok
      fields -> {:error, "Missing required fields: #{Enum.join(fields, ", ")}"}
    end
  end
end
