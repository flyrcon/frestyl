# File: lib/frestyl/data_campaigns.ex

defmodule Frestyl.DataCampaigns do
  @moduledoc """
  Dynamic Collaborative Content System with revenue sharing and contribution tracking.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.DataCampaigns.{Campaign, Contributor, DynamicTracker}
  alias Phoenix.PubSub
  alias Frestyl.DataCampaigns.AdvancedTracker
  alias Frestyl.Accounts

  # ============================================================================
  # CAMPAIGN MANAGEMENT
  # ============================================================================

  @doc """
  Lists content campaigns for a user (created or participating in).
  """
  def list_user_campaigns(user_id) do
    from(c in Campaign,
      left_join: contrib in Contributor, on: contrib.campaign_id == c.id,
      where: c.creator_id == ^user_id or contrib.user_id == ^user_id,
      distinct: c.id,
      order_by: [desc: c.updated_at],
      preload: [:creator, :contributors]
    )
    |> Repo.all()
  end

  @doc """
  Creates a new content campaign.
  """
  def create_campaign(attrs, creator) do
    %Campaign{}
    |> Campaign.changeset(Map.put(attrs, "creator_id", creator.id))
    |> Repo.insert()
    |> case do
      {:ok, campaign} ->
        # Initialize dynamic tracker
        initialize_campaign_tracker(campaign.id)

        # Broadcast campaign creation
        PubSub.broadcast(
          Frestyl.PubSub,
          "content_campaigns:#{creator.id}",
          {:campaign_created, campaign}
        )

        {:ok, campaign}

      error -> error
    end
  end

  @doc """
  Joins a campaign as a contributor.
  """
  def join_campaign(campaign_id, user) do
    campaign = get_campaign!(campaign_id)

    cond do
      already_joined?(campaign_id, user.id) ->
        {:error, :already_joined}

      campaign_full?(campaign) ->
        {:error, :campaign_full}

      true ->
        %Contributor{}
        |> Contributor.changeset(%{
          campaign_id: campaign_id,
          user_id: user.id,
          role: :contributor,
          revenue_percentage: 0.0,  # Will be calculated dynamically
          joined_at: DateTime.utc_now()
        })
        |> Repo.insert()
        |> case do
          {:ok, contributor} ->
            # Update dynamic tracker
            update_campaign_contributors(campaign_id)

            # Broadcast join event
            PubSub.broadcast(
              Frestyl.PubSub,
              "campaign:#{campaign_id}",
              {:contributor_joined, contributor}
            )

            {:ok, contributor}

          error -> error
        end
    end
  end

  @doc """
  Gets a campaign by ID.
  """
  def get_campaign(id) do
    case Repo.get(Campaign, id) do
      nil -> {:error, :not_found}
      campaign -> {:ok, campaign}
    end
  end

  @doc """
  Gets a campaign by ID, raises if not found.
  """
  def get_campaign!(id) do
    Repo.get!(Campaign, id)
  end

  @doc """
  Updates a campaign with the given attributes.
  """
  def update_campaign(%Campaign{} = campaign, attrs) do
    campaign
    |> Campaign.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a new campaign.
  """
  def create_campaign(attrs \\ %{}) do
    %Campaign{}
    |> Campaign.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a campaign.
  """
  def delete_campaign(%Campaign{} = campaign) do
    Repo.delete(campaign)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking campaign changes.
  """
  def change_campaign(%Campaign{} = campaign, attrs \\ %{}) do
    Campaign.changeset(campaign, attrs)
  end

  @doc """
  Lists all campaigns.
  """
  def list_campaigns do
    Repo.all(Campaign)
  end

  @doc """
  Lists campaigns with optional filters.
  """
  def list_campaigns(filters) when is_map(filters) do
    Campaign
    |> apply_campaign_filters(filters)
    |> Repo.all()
  end

  @doc """
  Lists campaigns for a specific user.
  """
  def list_user_campaigns(user_id) do
    from(c in Campaign,
      where: c.creator_id == ^user_id,
      order_by: [desc: c.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists active campaigns that a user can join.
  """
  def list_joinable_campaigns(user_id) do
    from(c in Campaign,
      where: c.status == :active,
      where: c.creator_id != ^user_id,
      order_by: [desc: c.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets campaigns by content type.
  """
  def get_campaigns_by_type(content_type) do
    from(c in Campaign,
      where: c.content_type == ^content_type,
      order_by: [desc: c.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets campaigns by status.
  """
  def get_campaigns_by_status(status) do
    from(c in Campaign,
      where: c.status == ^status,
      order_by: [desc: c.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Creates a data story campaign that integrates with the existing Stories system.
  """
  def create_data_story_campaign(story_params, creator) do
    # First create the story using existing Stories system
    case Frestyl.Stories.create_story(story_params, creator) do
      {:ok, story} ->
        # Then create associated campaign
        campaign_attrs = %{
          "title" => story.title,
          "description" => story.description || "Collaborative data story",
          "content_type" => :data_story,
          "platform_integrations" => %{
            "story_id" => story.id,
            "stories_integration" => true
          }
        }

        case create_campaign(campaign_attrs, creator) do
          {:ok, campaign} ->
            # Link story to campaign
            Frestyl.Stories.update_story(story, %{campaign_id: campaign.id})
            {:ok, %{story: story, campaign: campaign}}

          error -> error
        end

      error -> error
    end
  end

  @doc """
  Updates story content and tracks contributions for campaign metrics.
  """
  def update_story_with_tracking(story_id, user_id, content_changes) do
    story = Frestyl.Stories.get_story!(story_id)

    # Update the story using existing system
    case Frestyl.Stories.update_story_content(story, content_changes) do
      {:ok, updated_story} ->
        # Track contribution metrics if this is a campaign story
        if story.campaign_id do
          track_story_contribution(story.campaign_id, user_id, content_changes)
        end

        {:ok, updated_story}

      error -> error
    end
  end

  @doc """
  Gets campaign stories with contribution tracking.
  """
  def list_campaign_stories(campaign_id) do
    from(s in Frestyl.Stories.Story,
      where: s.campaign_id == ^campaign_id,
      order_by: [desc: s.updated_at],
      preload: [:creator]
    )
    |> Repo.all()
  end

  @doc """
  Gets a campaign with its contributors loaded.
  """
  def get_campaign_with_contributors(id) do
    case get_campaign(id) do
      {:ok, campaign} ->
        campaign_with_contributors = Repo.preload(campaign, :contributors)
        {:ok, campaign_with_contributors}
      error -> error
    end
  end

  @doc """
  Gets a campaign with all related data loaded.
  """
  def get_campaign_with_all_relations(id) do
    case get_campaign(id) do
      {:ok, campaign} ->
        campaign_with_relations = Repo.preload(campaign, [:contributors, :creator])
        {:ok, campaign_with_relations}
      error -> error
    end
  end


  # ============================================================================
  # DYNAMIC TRACKING SYSTEM
  # ============================================================================

  @doc """
  Updates contribution metrics for a campaign.
  """
  def update_contribution_metrics(campaign_id, user_id, contribution_type, data) do
    case get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        updated_metrics = update_user_metrics(
          tracker.contribution_metrics,
          user_id,
          contribution_type,
          data
        )

        # Calculate new revenue weights
        revenue_weights = calculate_dynamic_revenue_split(updated_metrics)

        updated_tracker = %{tracker |
          contribution_metrics: updated_metrics,
          dynamic_revenue_weights: revenue_weights
        }

        # Persist tracker state
        save_campaign_tracker(campaign_id, updated_tracker)

        # Broadcast metrics update
        PubSub.broadcast(
          Frestyl.PubSub,
          "campaign:#{campaign_id}:metrics",
          {:metrics_updated, updated_tracker}
        )

        {:ok, updated_tracker}

      error -> error
    end
  end

  @doc """
  Calculates dynamic revenue split based on contributions.
  """
  def calculate_dynamic_revenue_split(metrics) do
    # Implementation of the revenue calculation algorithm
    content_weight = 0.4    # 40% content amount
    narrative_weight = 0.3  # 30% story importance
    quality_weight = 0.2    # 20% peer/editorial scores
    unique_weight = 0.1     # 10% irreplaceable contributions

    users = get_contributing_users(metrics)

    Enum.reduce(users, %{}, fn user_id, acc ->
      content_score = get_content_contribution_score(metrics, user_id)
      narrative_score = get_narrative_contribution_score(metrics, user_id)
      quality_score = get_quality_score(metrics, user_id)
      unique_score = get_unique_value_score(metrics, user_id)

      total_score =
        content_score * content_weight +
        narrative_score * narrative_weight +
        quality_score * quality_weight +
        unique_score * unique_weight

      Map.put(acc, user_id, total_score)
    end)
    |> normalize_percentages()
    |> filter_minimum_viable_contributions()
  end

  # ============================================================================
  # PORTFOLIO INTEGRATION
  # ============================================================================

  @doc """
  Gets collaborations for portfolio display.
  """
  def get_user_portfolio_collaborations(user_id) do
    from(c in Campaign,
      join: contrib in Contributor, on: contrib.campaign_id == c.id,
      where: contrib.user_id == ^user_id and c.status in [:completed, :published],
      order_by: [desc: c.completed_at],
      preload: [:creator, :contributors]
    )
    |> Repo.all()
    |> Enum.map(&format_collaboration_for_portfolio/1)
  end

  @doc """
  Gets user campaign metrics for analytics.
  """
  def get_user_campaign_metrics(user_id) do
    campaigns = list_user_campaigns(user_id)

    %{
      total_campaigns: length(campaigns),
      active_campaigns: count_active_campaigns(campaigns),
      completed_campaigns: count_completed_campaigns(campaigns),
      total_revenue: calculate_total_revenue(campaigns, user_id),
      avg_contribution_score: calculate_avg_contribution_score(campaigns, user_id)
    }
  end

  defp apply_campaign_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, acc ->
      apply_filter(acc, key, value)
    end)
  end

  defp apply_filter(query, :status, status) do
    from c in query, where: c.status == ^status
  end

  defp apply_filter(query, :content_type, content_type) do
    from c in query, where: c.content_type == ^content_type
  end

  defp apply_filter(query, :creator_id, creator_id) do
    from c in query, where: c.creator_id == ^creator_id
  end

  defp apply_filter(query, :search, search_term) when is_binary(search_term) do
    search_pattern = "%#{search_term}%"
    from c in query,
      where: ilike(c.title, ^search_pattern) or
            ilike(c.description, ^search_pattern)
  end

  defp apply_filter(query, _key, _value), do: query

  # ============================================================================
  # CAMPAIGN STATISTICS & METRICS
  # ============================================================================

  @doc """
  Gets campaign statistics for analytics.
  """
  def get_campaign_statistics do
    %{
      total_campaigns: count_campaigns(),
      active_campaigns: count_campaigns_by_status(:active),
      completed_campaigns: count_campaigns_by_status(:completed),
      draft_campaigns: count_campaigns_by_status(:draft),
      campaigns_by_type: get_campaigns_count_by_type(),
      recent_campaigns: get_recent_campaigns(5)
    }
  end

  defp count_campaigns do
    Repo.aggregate(Campaign, :count, :id)
  end

  defp count_campaigns_by_status(status) do
    from(c in Campaign, where: c.status == ^status)
    |> Repo.aggregate(:count, :id)
  end

  defp get_campaigns_count_by_type do
    from(c in Campaign,
      group_by: c.content_type,
      select: {c.content_type, count(c.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp get_recent_campaigns(limit) do
    from(c in Campaign,
      order_by: [desc: c.inserted_at],
      limit: ^limit,
      select: [:id, :title, :status, :content_type, :inserted_at]
    )
    |> Repo.all()
  end

  # ============================================================================
  # CAMPAIGN VALIDATION & BUSINESS LOGIC
  # ============================================================================

  @doc """
  Checks if a user can join a campaign.
  """
  def can_user_join_campaign?(campaign_id, user_id) do
    case get_campaign(campaign_id) do
      {:ok, campaign} ->
        cond do
          campaign.status != :active ->
            {:error, :campaign_not_active}

          campaign.creator_id == user_id ->
            {:error, :cannot_join_own_campaign}

          user_already_in_campaign?(campaign_id, user_id) ->
            {:error, :already_joined}

          campaign_at_capacity?(campaign) ->
            {:error, :campaign_full}

          true ->
            {:ok, :can_join}
        end

      error -> error
    end
  end

  @doc """
  Checks if a user can edit a campaign.
  """
  def can_user_edit_campaign?(campaign_id, user_id) do
    case get_campaign(campaign_id) do
      {:ok, campaign} ->
        cond do
          campaign.creator_id == user_id -> {:ok, :can_edit}
          user_is_admin?(user_id) -> {:ok, :can_edit}
          true -> {:error, :unauthorized}
        end

      error -> error
    end
  end

  defp user_already_in_campaign?(campaign_id, user_id) do
    case AdvancedTracker.get_campaign_tracker(campaign_id) do
      {:ok, tracker} -> Map.has_key?(tracker.contribution_weights, user_id)
      _ -> false
    end
  end

  defp campaign_at_capacity?(campaign) do
    max_contributors = campaign.max_contributors

    if max_contributors do
      current_count = count_campaign_contributors(campaign.id)
      current_count >= max_contributors
    else
      false
    end
  end

  defp user_is_admin?(user_id) do
    case Accounts.get_user(user_id) do
      {:ok, user} -> user.role == :admin
      _ -> false
    end
  end

  # ============================================================================
  # ADDITIONAL UTILITY FUNCTIONS
  # ============================================================================

  @doc """
  Gets campaign status summary for dashboard.
  """
  def get_campaign_status_summary(user_id) do
    user_campaigns = list_user_campaigns(user_id)

    %{
      created_campaigns: length(user_campaigns),
      active_campaigns: Enum.count(user_campaigns, &(&1.status == :active)),
      completed_campaigns: Enum.count(user_campaigns, &(&1.status == :completed)),
      draft_campaigns: Enum.count(user_campaigns, &(&1.status == :draft))
    }
  end

  @doc """
  Searches campaigns by title or description.
  """
  def search_campaigns(search_term, limit \\ 20) do
    search_pattern = "%#{search_term}%"

    from(c in Campaign,
      where: c.status == :active,
      where: ilike(c.title, ^search_pattern) or
            ilike(c.description, ^search_pattern),
      order_by: [desc: c.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end


  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp track_story_contribution(campaign_id, user_id, content_changes) do
    # Calculate word count changes
    word_count_change = calculate_word_count_change(content_changes)

    # Update campaign metrics
    update_contribution_metrics(campaign_id, user_id, :word_count, word_count_change)

    # Track chapter/section ownership
    if Map.has_key?(content_changes, "chapters") do
      track_chapter_contributions(campaign_id, user_id, content_changes["chapters"])
    end
  end

  defp calculate_word_count_change(content_changes) do
    # Implementation would calculate actual word count differences
    case content_changes do
      %{"content" => new_content} when is_binary(new_content) ->
        new_content |> String.split() |> length()
      _ -> 0
    end
  end

  defp track_chapter_contributions(campaign_id, user_id, chapters) do
    # Track which chapters this user has contributed to
    Enum.each(chapters, fn {chapter_id, _content} ->
      update_contribution_metrics(campaign_id, user_id, :chapter_ownership, chapter_id)
    end)
  end

  defp already_joined?(campaign_id, user_id) do
    from(c in Contributor,
      where: c.campaign_id == ^campaign_id and c.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  defp campaign_full?(campaign) do
    contributor_count = length(campaign.contributors || [])
    contributor_count >= campaign.max_contributors
  end

  defp initialize_campaign_tracker(campaign_id) do
    tracker = %DynamicTracker{
      campaign_id: campaign_id,
      contribution_metrics: %{
        word_count_by_user: %{},
        chapter_ownership: %{},
        media_contributions: %{},
        peer_review_scores: %{},
        narrative_contribution_score: %{},
        dynamic_revenue_weights: %{}
      }
    }

    save_campaign_tracker(campaign_id, tracker)
  end

  defp get_campaign_tracker(campaign_id) do
    # Implementation would use ETS or Redis for fast access
    # For now, simplified in-memory approach
    case :ets.lookup(:campaign_trackers, campaign_id) do
      [{^campaign_id, tracker}] -> {:ok, tracker}
      [] -> {:error, :tracker_not_found}
    end
  end

  defp save_campaign_tracker(campaign_id, tracker) do
    :ets.insert(:campaign_trackers, {campaign_id, tracker})
  end

  # Contribution scoring algorithms
  defp get_content_contribution_score(metrics, user_id) do
    word_count = get_in(metrics, [:word_count_by_user, user_id]) || 0
    media_count = get_in(metrics, [:media_contributions, user_id, :total]) || 0

    # Normalize scores
    (word_count / 1000) + (media_count * 0.5)
  end

  defp get_narrative_contribution_score(metrics, user_id) do
    get_in(metrics, [:narrative_contribution_score, user_id]) || 0.0
  end

  defp get_quality_score(metrics, user_id) do
    get_in(metrics, [:peer_review_scores, user_id]) || 0.0
  end

  defp get_unique_value_score(metrics, user_id) do
    # Calculate based on unique/irreplaceable contributions
    # This would be more sophisticated in real implementation
    0.5
  end

  defp get_contributing_users(metrics) do
    metrics
    |> Map.get(:word_count_by_user, %{})
    |> Map.keys()
  end

  defp normalize_percentages(scores) do
    total = scores |> Map.values() |> Enum.sum()

    if total > 0 do
      Enum.reduce(scores, %{}, fn {user_id, score}, acc ->
        Map.put(acc, user_id, score / total * 100)
      end)
    else
      scores
    end
  end

  defp filter_minimum_viable_contributions(percentages) do
    # Remove contributors below minimum thresholds
    Enum.filter(percentages, fn {_user_id, percentage} ->
      percentage >= 5.0  # 5% minimum threshold
    end)
    |> Enum.into(%{})
  end

  defp format_collaboration_for_portfolio(campaign) do
    %{
      id: campaign.id,
      title: campaign.title,
      type: campaign.content_type,
      description: campaign.description,
      status: campaign.status,
      completed_at: campaign.completed_at,
      revenue_share: get_user_revenue_share(campaign),
      collaborators: format_collaborators(campaign.contributors),
      metrics: get_campaign_display_metrics(campaign)
    }
  end

  defp update_campaign_contributors(campaign_id) do
    case get_campaign(campaign_id) do
      {:ok, campaign} ->
        # Count current contributors
        contributor_count = count_campaign_contributors(campaign_id)

        # Update campaign with new contributor count
        update_campaign(campaign, %{
          contributor_count: contributor_count,
          last_contributor_joined: DateTime.utc_now()
        })

      error -> error
    end
  end

  @doc """
  Updates user metrics after contribution updates.
  """
  defp update_user_metrics(user_id, campaign_id, contribution_type, metrics_data) do
    # Get current user campaign metrics
    current_metrics = get_user_campaign_metrics(user_id, campaign_id)

    # Calculate updated metrics based on contribution type
    updated_metrics = case contribution_type do
      :content_contribution ->
        %{
          total_contributions: Map.get(current_metrics, :total_contributions, 0) + 1,
          total_word_count: Map.get(current_metrics, :total_word_count, 0) + Map.get(metrics_data, :word_count, 0),
          average_quality_score: calculate_new_average_quality(current_metrics, metrics_data),
          last_contribution_at: DateTime.utc_now()
        }

      :peer_review ->
        %{
          peer_reviews_given: Map.get(current_metrics, :peer_reviews_given, 0) + 1,
          avg_review_helpfulness: calculate_review_helpfulness(current_metrics, metrics_data),
          last_review_at: DateTime.utc_now()
        }

      :quality_improvement ->
        %{
          improvements_made: Map.get(current_metrics, :improvements_made, 0) + 1,
          quality_improvement_rate: calculate_improvement_rate(current_metrics, metrics_data),
          last_improvement_at: DateTime.utc_now()
        }

      _ ->
        current_metrics
    end

    # Merge with existing metrics
    final_metrics = Map.merge(current_metrics, updated_metrics)

    # Store updated metrics
    store_user_campaign_metrics(user_id, campaign_id, final_metrics)

    {:ok, final_metrics}
  end

  @doc """
  Gets user's revenue share for a campaign.
  """
  defp get_user_revenue_share(campaign) do
    # This would typically get the user's current revenue share percentage
    # For now, return a placeholder structure
    %{
      percentage: 0.0,
      projected_amount: Decimal.new("0.00"),
      status: :pending_calculation,
      last_calculated: DateTime.utc_now()
    }
  end

  @doc """
  Formats collaborators for portfolio display.
  """
  defp format_collaborators(contributors) when is_list(contributors) do
    contributors
    |> Enum.map(&format_single_collaborator/1)
    |> Enum.take(5) # Limit to top 5 for display
  end

  defp format_collaborators(_), do: []

  @doc """
  Formats a single collaborator for display.
  """
  defp format_single_collaborator(contributor) do
    %{
      id: contributor.user_id,
      name: get_contributor_name(contributor),
      role: determine_contributor_role(contributor),
      contribution_percentage: get_contribution_percentage(contributor),
      avatar_url: get_contributor_avatar(contributor),
      quality_score: get_contributor_quality_score(contributor)
    }
  end

  @doc """
  Gets campaign display metrics for portfolio integration.
  """
  defp get_campaign_display_metrics(campaign) do
    %{
      status: campaign.status,
      progress_percentage: calculate_campaign_progress(campaign),
      total_contributors: count_campaign_contributors(campaign.id),
      quality_score: calculate_campaign_average_quality(campaign.id),
      revenue_target: campaign.revenue_target || Decimal.new("0"),
      deadline: campaign.deadline,
      content_type: campaign.content_type,
      completion_status: determine_completion_status(campaign),
      last_activity: get_last_campaign_activity(campaign.id)
    }
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp count_campaign_contributors(campaign_id) do
    # Count unique contributors to the campaign
    case AdvancedTracker.get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        tracker.contribution_weights |> Map.keys() |> length()
      _ ->
        0
    end
  end

  defp get_user_campaign_metrics(user_id, campaign_id) do
    # Get stored user metrics for this campaign
    # This would typically come from a database table
    # For now, return empty metrics
    %{
      total_contributions: 0,
      total_word_count: 0,
      average_quality_score: 0.0,
      peer_reviews_given: 0,
      improvements_made: 0,
      last_contribution_at: nil
    }
  end

  defp store_user_campaign_metrics(user_id, campaign_id, metrics) do
    # Store the updated metrics in the database
    # This is a placeholder implementation
    :ok
  end

  defp calculate_new_average_quality(current_metrics, new_data) do
    current_avg = Map.get(current_metrics, :average_quality_score, 0.0)
    current_count = Map.get(current_metrics, :total_contributions, 0)
    new_quality = Map.get(new_data, :quality_score, 0.0)

    if current_count > 0 do
      ((current_avg * current_count) + new_quality) / (current_count + 1)
    else
      new_quality
    end
  end

  defp calculate_review_helpfulness(current_metrics, review_data) do
    current_helpfulness = Map.get(current_metrics, :avg_review_helpfulness, 0.0)
    current_reviews = Map.get(current_metrics, :peer_reviews_given, 0)
    new_helpfulness = Map.get(review_data, :helpfulness_score, 0.0)

    if current_reviews > 0 do
      ((current_helpfulness * current_reviews) + new_helpfulness) / (current_reviews + 1)
    else
      new_helpfulness
    end
  end

  defp calculate_improvement_rate(current_metrics, improvement_data) do
    # Calculate how much quality improved
    before_quality = Map.get(improvement_data, :quality_before, 0.0)
    after_quality = Map.get(improvement_data, :quality_after, 0.0)

    if before_quality > 0 do
      ((after_quality - before_quality) / before_quality) * 100
    else
      0.0
    end
  end

  defp get_contributor_name(contributor) do
    # Get contributor's display name
    case Accounts.get_user(contributor.user_id) do
      {:ok, user} -> user.name || "Anonymous"
      _ -> "Unknown"
    end
  end

  defp determine_contributor_role(contributor) do
    # Determine role based on contribution patterns
    contribution_count = Map.get(contributor, :contribution_count, 0)
    quality_score = Map.get(contributor, :average_quality, 0.0)

    cond do
      contribution_count >= 10 && quality_score >= 4.0 -> "Lead Contributor"
      contribution_count >= 5 && quality_score >= 3.5 -> "Active Contributor"
      quality_score >= 4.0 -> "Quality Contributor"
      contribution_count >= 3 -> "Regular Contributor"
      true -> "Contributor"
    end
  end

  defp get_contribution_percentage(contributor) do
    # Get the contributor's percentage from the tracker
    Map.get(contributor, :contribution_percentage, 0.0)
  end

  defp get_contributor_avatar(contributor) do
    # Get contributor's avatar URL
    case Accounts.get_user(contributor.user_id) do
      {:ok, user} -> user.avatar_url
      _ -> nil
    end
  end

  defp get_contributor_quality_score(contributor) do
    Map.get(contributor, :average_quality, 0.0)
  end

  defp calculate_campaign_progress(campaign) do
    # Calculate campaign progress as percentage
    case campaign.status do
      :draft -> 0
      :active -> calculate_active_campaign_progress(campaign)
      :review -> 80
      :completed -> 100
      :cancelled -> 0
      _ -> 0
    end
  end

  defp calculate_active_campaign_progress(campaign) do
    # Calculate progress based on contributions vs targets
    # This is a simplified calculation
    case AdvancedTracker.get_campaign_tracker(campaign.id) do
      {:ok, tracker} ->
        contributor_count = tracker.contribution_weights |> Map.size()
        target_contributors = campaign.target_contributors || 5

        min(Float.round((contributor_count / target_contributors) * 100), 90)
      _ ->
        10
    end
  end

  defp calculate_campaign_average_quality(campaign_id) do
    case AdvancedTracker.get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        quality_scores = tracker.contribution_weights
        |> Map.values()
        |> Enum.map(& Map.get(&1, :quality_score, 0.0))
        |> Enum.filter(& &1 > 0)

        if length(quality_scores) > 0 do
          Enum.sum(quality_scores) / length(quality_scores)
        else
          0.0
        end
      _ ->
        0.0
    end
  end

  defp determine_completion_status(campaign) do
    case campaign.status do
      :completed -> "Completed"
      :active -> "In Progress"
      :review -> "Under Review"
      :draft -> "Draft"
      :cancelled -> "Cancelled"
      _ -> "Unknown"
    end
  end

  defp get_last_campaign_activity(campaign_id) do
    # Get the timestamp of the last activity in the campaign
    case AdvancedTracker.get_campaign_tracker(campaign_id) do
      {:ok, tracker} -> tracker.last_updated
      _ -> nil
    end
  end

  # ============================================================================
  # ADDITIONAL HELPER FUNCTIONS
  # ============================================================================

  @doc """
  Gets user revenue share with proper error handling.
  """
  def get_user_campaign_revenue_share(campaign_id, user_id) do
    case AdvancedTracker.get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        percentage = Map.get(tracker.dynamic_revenue_weights, user_id, 0.0)
        {:ok, %{
          percentage: percentage,
          user_id: user_id,
          campaign_id: campaign_id,
          calculated_at: DateTime.utc_now()
        }}
      error -> error
    end
  end

  @doc """
  Safely gets campaign with error handling.
  """
  def get_campaign_safe(campaign_id) do
    case get_campaign(campaign_id) do
      {:ok, campaign} -> campaign
      _ -> nil
    end
  end

  defp count_active_campaigns(campaigns) do
    Enum.count(campaigns, &(&1.status in [:active, :open]))
  end

  defp count_completed_campaigns(campaigns) do
    Enum.count(campaigns, &(&1.status == :completed))
  end

  defp calculate_total_revenue(campaigns, user_id) do
    # Implementation would calculate actual revenue
    0.0
  end

  defp calculate_avg_contribution_score(campaigns, user_id) do
    # Implementation would calculate contribution scores
    0.0
  end
end
