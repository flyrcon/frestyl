# lib/frestyl/content/headless_cms.ex
defmodule Frestyl.Content.HeadlessCMS do
  @moduledoc """
  Main entry point for headless CMS functionality
  Orchestrates all CMS features while respecting tier limits
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo

  alias Frestyl.Content.{
    CollaborationCampaign,
    CampaignContributor,
    Publishers,
    CollaborationTracker,
    Syndication
  }
  alias Frestyl.Features.{TierManager, FeatureGate}

  @doc """
  Create a collaborative writing campaign
  """
  def create_campaign(attrs, account) do
    with :ok <- validate_campaign_limits(account),
         {:ok, campaign} <- do_create_campaign(attrs, account) do

      # Broadcast campaign creation
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "content_campaigns:#{account.id}",
        {:campaign_created, campaign}
      )

      {:ok, campaign}
    end
  end

  @doc """
  Join an existing campaign
  """
  def join_campaign(campaign_id, user, account) do
    with {:ok, campaign} <- get_joinable_campaign(campaign_id),
         :ok <- validate_join_permissions(campaign, account),
         {:ok, contributor} <- create_contributor(campaign, user, account) do

      # Broadcast new contributor
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "collaboration_campaign:#{campaign_id}",
        {:contributor_joined, contributor}
      )

      {:ok, contributor}
    end
  end

  @doc """
  Publish document to multiple platforms
  """
  def syndicate_content(document_id, platforms, account) do
    with :ok <- validate_syndication_permissions(account),
         {:ok, results} <- Publishers.publish_to_platforms(document_id, platforms, account) do

      # Track usage
      FeatureGate.track_usage(account, :content_syndications, length(platforms))

      # Broadcast syndication results
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "document:#{document_id}",
        {:content_syndicated, results}
      )

      {:ok, results}
    end
  end

  @doc """
  Get collaboration analytics for account
  """
  def get_collaboration_analytics(account, opts \\ []) do
    if FeatureGate.can_access_feature?(account, :advanced_analytics) do
      Frestyl.Analytics.ContentAnalytics.get_account_analytics(account, opts[:date_range] || :last_30_days)
    else
      {:error, :upgrade_required}
    end
  end

  # Private functions
  defp validate_campaign_limits(account) do
    limits = Publishers.get_syndication_limits(account)
    current_campaigns = count_active_campaigns(account)

    case limits.concurrent_campaigns do
      :unlimited -> :ok
      limit when current_campaigns < limit -> :ok
      _ -> {:error, :campaign_limit_exceeded}
    end
  end

  defp do_create_campaign(attrs, account) do
    attrs
    |> Map.put("account_id", account.id)
    |> CollaborationCampaign.changeset(%CollaborationCampaign{})
    |> Frestyl.Repo.insert()
  end

  defp validate_syndication_permissions(account) do
    if FeatureGate.can_access_feature?(account, :content_syndication) do
      :ok
    else
      {:error, :upgrade_required}
    end
  end

  defp count_active_campaigns(account) do
    from(c in CollaborationCampaign,
      where: c.account_id == ^account.id and c.status in ["open", "active"],
      select: count(c.id)
    ) |> Frestyl.Repo.one() || 0
  end

  defp get_joinable_campaign(campaign_id) do
    case Repo.get(CollaborationCampaign, campaign_id) do
      nil -> {:error, :not_found}
      %{status: "completed"} -> {:error, :campaign_completed}
      %{status: "cancelled"} -> {:error, :campaign_cancelled}
      campaign -> {:ok, campaign}
    end
  end

  defp validate_join_permissions(campaign, account) do
    with :ok <- check_campaign_not_full(campaign),
        :ok <- check_not_already_joined(campaign, account),
        :ok <- check_account_tier_allows_joining(account) do
      :ok
    end
  end

  defp create_contributor(campaign, user, account) do
    contributor_attrs = %{
      campaign_id: campaign.id,
      user_id: user.id,
      account_id: account.id,
      role: "contributor",
      agreed_revenue_share: calculate_default_revenue_share(campaign),
      joined_at: DateTime.utc_now(),
      status: "active"
    }

    %Frestyl.Content.CampaignContributor{}
    |> Frestyl.Content.CampaignContributor.changeset(contributor_attrs)
    |> Repo.insert()
  end

  defp check_campaign_not_full(campaign) do
    current_contributors = from(cc in Frestyl.Content.CampaignContributor,
      where: cc.campaign_id == ^campaign.id and cc.status == "active",
      select: count(cc.id)
    ) |> Repo.one() || 0

    if current_contributors >= campaign.max_contributors do
      {:error, :campaign_full}
    else
      :ok
    end
  end

  defp check_not_already_joined(campaign, account) do
    existing = from(cc in Frestyl.Content.CampaignContributor,
      where: cc.campaign_id == ^campaign.id and cc.account_id == ^account.id,
      select: count(cc.id)
    ) |> Repo.one() || 0

    if existing > 0 do
      {:error, :already_joined}
    else
      :ok
    end
  end

  defp check_account_tier_allows_joining(account) do
    limits = Publishers.get_syndication_limits(account)
    current_campaigns = count_active_campaigns(account)

    case limits.concurrent_campaigns do
      :unlimited -> :ok
      limit when current_campaigns < limit -> :ok
      _ -> {:error, :campaign_limit_exceeded}
    end
  end

  defp calculate_default_revenue_share(campaign) do
    case campaign.revenue_split_config do
      %{"type" => "equal", "per_contributor" => share} -> Decimal.new(to_string(share))
      %{"default_share" => share} -> Decimal.new(to_string(share))
      _ -> Decimal.new("10.0")  # Default 10% share
    end
  end
end
