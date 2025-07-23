# lib/frestyl/content/publishers.ex
defmodule Frestyl.Content.Publishers do
  @moduledoc """
  Multi-platform content publishing with tier-based limitations
  """

  alias Frestyl.Features.TierManager
  alias Frestyl.Content.{Document, Syndication}
  alias Frestyl.Accounts.Account

  @doc """
  Get syndication limits based on account tier
  """
  def get_syndication_limits(account) do
    tier = TierManager.get_account_tier(account)

    case tier do
      "personal" -> %{max_platforms: 2, monthly_publishes: 10, concurrent_campaigns: 1}
      "creator" -> %{max_platforms: 4, monthly_publishes: 50, concurrent_campaigns: 3}
      "professional" -> %{max_platforms: 8, monthly_publishes: 200, concurrent_campaigns: 10}
      "enterprise" -> %{max_platforms: :unlimited, monthly_publishes: :unlimited, concurrent_campaigns: :unlimited}
    end
  end

  @doc """
  Check if account can syndicate to specific platforms
  """
  def can_syndicate_to_platforms?(account, platforms) when is_list(platforms) do
    limits = get_syndication_limits(account)
    current_usage = get_current_syndication_usage(account)

    cond do
      limits.max_platforms == :unlimited ->
        {:ok, platforms}

      length(platforms) + current_usage.active_platforms > limits.max_platforms ->
        {:error, :platform_limit_exceeded, limits}

      current_usage.monthly_publishes >= limits.monthly_publishes ->
        {:error, :monthly_limit_exceeded, limits}

      true ->
        {:ok, platforms}
    end
  end

  @doc """
  Publish document to multiple platforms respecting tier limits
  """
  def publish_to_platforms(document_id, platforms, account) do
    with {:ok, validated_platforms} <- can_syndicate_to_platforms?(account, platforms),
         {:ok, document} <- get_publishable_document(document_id, account) do

      results = Enum.map(validated_platforms, fn platform ->
        publish_to_platform(document, platform, account)
      end)

      {:ok, results}
    end
  end

  # Platform-specific publishers
  defp publish_to_platform(document, platform, account) do
    case platform do
      "medium" -> MediumPublisher.publish(document, account)
      "linkedin" -> LinkedInPublisher.publish(document, account)
      "hashnode" -> HashnodePublisher.publish(document, account)
      "dev_to" -> DevToPublisher.publish(document, account)
      "ghost" -> GhostPublisher.publish(document, account)
      "wordpress" -> WordPressPublisher.publish(document, account)
      "custom" -> CustomWebhookPublisher.publish(document, account)
      _ -> {:error, :unsupported_platform}
    end
  end

  defp get_current_syndication_usage(account) do
    # Query current usage from syndications table
    %{
      active_platforms: 0, # Count of distinct platforms used this month
      monthly_publishes: 0  # Count of publishes this month
    }
  end

  defp get_publishable_document(document_id, account) do
    # Verify document exists, is owned by account, and is ready for publishing
    {:ok, %Document{}}
  end
end
