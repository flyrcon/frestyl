# File: lib/frestyl_web/api/content_campaigns_api.ex

defmodule FrestylWeb.API.ContentCampaignsAPI do
  @moduledoc """
  REST API for external tools to integrate with content campaigns system.
  Provides endpoints for campaign management, contribution tracking, and revenue data.
  """

  use FrestylWeb, :controller
  alias Frestyl.DataCampaigns
  alias Frestyl.DataCampaigns.{RevenueManager, AdvancedTracker}

  # ============================================================================
  # CAMPAIGN MANAGEMENT ENDPOINTS
  # ============================================================================

  @doc """
  GET /api/campaigns - List user's campaigns
  """
  def index(conn, params) do
    user = get_api_user(conn)

    campaigns = DataCampaigns.list_user_campaigns(user.id)
    |> Enum.map(&format_campaign_for_api/1)

    json(conn, %{
      campaigns: campaigns,
      pagination: build_pagination(params),
      meta: %{
        total_campaigns: length(campaigns),
        active_campaigns: Enum.count(campaigns, &(&1.status in ["active", "open"]))
      }
    })
  end

  @doc """
  GET /api/campaigns/:id - Get campaign details
  """
  def show(conn, %{"id" => campaign_id}) do
    user = get_api_user(conn)

    with {:ok, campaign} <- get_user_campaign(campaign_id, user.id),
         {:ok, tracker} <- AdvancedTracker.get_campaign_tracker(campaign_id) do

      campaign_data = format_detailed_campaign_for_api(campaign, tracker)

      json(conn, %{campaign: campaign_data})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Campaign not found"})

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Access denied"})
    end
  end

  @doc """
  POST /api/campaigns - Create new campaign
  """
  def create(conn, %{"campaign" => campaign_params}) do
    user = get_api_user(conn)

    case DataCampaigns.create_campaign(campaign_params, user) do
      {:ok, campaign} ->
        campaign_data = format_campaign_for_api(campaign)

        conn
        |> put_status(:created)
        |> json(%{campaign: campaign_data})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  # ============================================================================
  # CONTRIBUTION TRACKING ENDPOINTS
  # ============================================================================

  @doc """
  POST /api/campaigns/:id/contributions - Track new contribution
  """
  def create_contribution(conn, %{"id" => campaign_id, "contribution" => contribution_params}) do
    user = get_api_user(conn)

    with {:ok, campaign} <- get_user_campaign(campaign_id, user.id),
         {:ok, contribution} <- track_api_contribution(campaign, user.id, contribution_params) do

      json(conn, %{
        contribution: format_contribution_for_api(contribution),
        updated_metrics: get_user_campaign_metrics(campaign_id, user.id)
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  @doc """
  GET /api/campaigns/:id/metrics - Get campaign metrics
  """
  def metrics(conn, %{"id" => campaign_id}) do
    user = get_api_user(conn)

    with {:ok, campaign} <- get_user_campaign(campaign_id, user.id),
         {:ok, tracker} <- AdvancedTracker.get_campaign_tracker(campaign_id) do

      metrics_data = %{
        contribution_metrics: tracker.contribution_metrics,
        revenue_weights: tracker.dynamic_revenue_weights,
        user_metrics: get_user_campaign_metrics(campaign_id, user.id),
        quality_gates: get_campaign_quality_gates_status(campaign_id, user.id),
        last_updated: DateTime.utc_now()
      }

      json(conn, %{metrics: metrics_data})
    else
      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: reason})
    end
  end

  # ============================================================================
  # REVENUE & CONTRACT ENDPOINTS
  # ============================================================================

  @doc """
  GET /api/campaigns/:id/revenue - Get revenue information
  """
  def revenue(conn, %{"id" => campaign_id}) do
    user = get_api_user(conn)

    with {:ok, campaign} <- get_user_campaign(campaign_id, user.id) do
      revenue_data = %{
        current_revenue_share: get_user_current_revenue_share(campaign_id, user.id),
        projected_earnings: calculate_projected_earnings(campaign_id, user.id),
        payment_history: RevenueManager.get_user_campaign_payments(campaign_id, user.id),
        next_payment_date: calculate_next_payment_date(campaign_id),
        revenue_milestones: get_campaign_revenue_milestones(campaign_id)
      }

      json(conn, %{revenue: revenue_data})
    else
      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: reason})
    end
  end

  @doc """
  GET /api/campaigns/:id/contract - Get contract information
  """
  def contract(conn, %{"id" => campaign_id}) do
    user = get_api_user(conn)

    with {:ok, contract} <- RevenueManager.get_user_campaign_contract(campaign_id, user.id) do
      contract_data = %{
        id: contract.id,
        status: contract.status,
        revenue_split: contract.revenue_split,
        quality_requirements: contract.quality_requirements,
        signed_at: contract.signed_at,
        terms_summary: extract_contract_terms_summary(contract)
      }

      json(conn, %{contract: contract_data})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Contract not found"})
    end
  end

  @doc """
  POST /api/campaigns/:id/contract/sign - Sign contract via API
  """
  def sign_contract(conn, %{"id" => campaign_id, "signature" => signature_params}) do
    user = get_api_user(conn)

    signature_data = %{
      legal_name: signature_params["legal_name"],
      digital_signature: signature_params["digital_signature"],
      ip_address: get_client_ip(conn),
      user_agent: get_req_header(conn, "user-agent") |> List.first(),
      timestamp: DateTime.utc_now(),
      api_signature: true
    }

    case RevenueManager.sign_contract(campaign_id, user.id, signature_data) do
      {:ok, signed_contract} ->
        json(conn, %{
          message: "Contract signed successfully",
          contract: format_contract_for_api(signed_contract)
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  # ============================================================================
  # WEBHOOK ENDPOINTS FOR EXTERNAL INTEGRATIONS
  # ============================================================================

  @doc """
  POST /api/webhooks/campaign_update - Receive campaign updates from external tools
  """
  def webhook_campaign_update(conn, %{"campaign_id" => campaign_id, "update" => update_data}) do
    # Verify webhook signature
    with {:ok, :valid} <- verify_webhook_signature(conn),
         {:ok, campaign} <- DataCampaigns.get_campaign(campaign_id) do

      # Process external update
      process_external_campaign_update(campaign, update_data)

      json(conn, %{status: "processed", timestamp: DateTime.utc_now()})
    else
      {:error, :invalid_signature} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid webhook signature"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  @doc """
  POST /api/webhooks/revenue_update - Receive revenue updates from external platforms
  """
  def webhook_revenue_update(conn, %{"campaign_id" => campaign_id, "revenue_data" => revenue_data}) do
    with {:ok, :valid} <- verify_webhook_signature(conn),
         {:ok, campaign} <- DataCampaigns.get_campaign(campaign_id) do

      # Update revenue from external source
      RevenueManager.update_external_revenue(campaign_id, revenue_data)

      json(conn, %{status: "revenue_updated", timestamp: DateTime.utc_now()})
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  # ============================================================================
  # ANALYTICS & REPORTING ENDPOINTS
  # ============================================================================

  @doc """
  GET /api/analytics/campaigns - Campaign analytics overview
  """
  def analytics_overview(conn, params) do
    user = get_api_user(conn)

    date_range = parse_date_range(params)

    analytics_data = %{
      overview: %{
        total_campaigns: count_user_campaigns(user.id, date_range),
        total_revenue: calculate_user_total_revenue(user.id, date_range),
        avg_quality_score: calculate_user_avg_quality(user.id, date_range),
        completion_rate: calculate_user_completion_rate(user.id, date_range)
      },
      trends: %{
        campaign_creation_trend: get_campaign_creation_trend(user.id, date_range),
        revenue_trend: get_revenue_trend(user.id, date_range),
        quality_trend: get_quality_trend(user.id, date_range)
      },
      top_campaigns: get_top_performing_campaigns(user.id, date_range),
      collaboration_stats: get_collaboration_statistics(user.id, date_range)
    }

    json(conn, %{analytics: analytics_data})
  end

  @doc """
  GET /api/analytics/campaigns/:id - Detailed campaign analytics
  """
  def campaign_analytics(conn, %{"id" => campaign_id}) do
    user = get_api_user(conn)

    with {:ok, campaign} <- get_user_campaign(campaign_id, user.id) do
      analytics = RevenueManager.generate_revenue_analytics(campaign_id)

      # Format for API response
      formatted_analytics = %{
        campaign_info: analytics.campaign_info,
        revenue_metrics: analytics.revenue_metrics,
        contribution_analysis: analytics.contribution_analysis,
        timeline_analysis: analytics.timeline_analysis,
        performance_insights: analytics.performance_insights,
        generated_at: DateTime.utc_now()
      }

      json(conn, %{analytics: formatted_analytics})
    else
      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: reason})
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_api_user(conn) do
    # Extract user from API authentication (JWT, API key, etc.)
    # This would integrate with your existing auth system
    %{id: 1, email: "user@example.com"} # Mock user
  end

  defp get_user_campaign(campaign_id, user_id) do
    # Verify user has access to campaign
    case DataCampaigns.get_campaign(campaign_id) do
      {:ok, campaign} ->
        if user_has_campaign_access?(campaign, user_id) do
          {:ok, campaign}
        else
          {:error, :unauthorized}
        end

      error -> error
    end
  end

  defp user_has_campaign_access?(campaign, user_id) do
    # Check if user is creator or contributor
    campaign.creator_id == user_id or
    Enum.any?(campaign.contributors || [], &(&1.user_id == user_id))
  end

  defp format_campaign_for_api(campaign) do
    %{
      id: campaign.id,
      title: campaign.title,
      description: campaign.description,
      content_type: campaign.content_type,
      status: campaign.status,
      deadline: campaign.deadline,
      max_contributors: campaign.max_contributors,
      current_contributors: length(campaign.contributors || []),
      revenue_target: campaign.revenue_target,
      created_at: campaign.inserted_at,
      updated_at: campaign.updated_at
    }
  end

  defp format_detailed_campaign_for_api(campaign, tracker) do
    basic_campaign = format_campaign_for_api(campaign)

    Map.merge(basic_campaign, %{
      contribution_metrics: tracker.contribution_metrics,
      revenue_weights: tracker.dynamic_revenue_weights,
      quality_gates: get_campaign_quality_gates_summary(campaign.id),
      collaboration_stats: get_campaign_collaboration_stats(campaign.id),
      recent_activity: get_campaign_recent_activity(campaign.id)
    })
  end

  defp track_api_contribution(campaign, user_id, contribution_params) do
    case contribution_params["type"] do
      "content" ->
        AdvancedTracker.track_content_contribution(
          campaign.id,
          user_id,
          contribution_params["data"]
        )

      "audio" ->
        AdvancedTracker.track_audio_contribution(
          campaign.id,
          user_id,
          contribution_params["data"]
        )

      "research" ->
        AdvancedTracker.track_research_contribution(
          campaign.id,
          user_id,
          contribution_params["data"]
        )

      _ ->
        {:error, "Unsupported contribution type"}
    end
  end

  defp format_contribution_for_api(contribution) do
    %{
      type: contribution.type,
      timestamp: contribution.timestamp,
      metrics: contribution.metrics || %{},
      quality_score: contribution.quality_score || 0
    }
  end

  defp get_user_campaign_metrics(campaign_id, user_id) do
    case AdvancedTracker.get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        user_percentage = Map.get(tracker.dynamic_revenue_weights, user_id, 0.0)

        %{
          revenue_percentage: user_percentage,
          contribution_score: calculate_user_contribution_score(tracker, user_id),
          quality_gates_passed: count_user_quality_gates_passed(campaign_id, user_id),
          last_contribution: get_last_contribution_time(tracker, user_id)
        }

      _ ->
        %{revenue_percentage: 0, contribution_score: 0, quality_gates_passed: 0}
    end
  end

  defp build_pagination(params) do
    page = String.to_integer(params["page"] || "1")
    per_page = String.to_integer(params["per_page"] || "20")

    %{
      current_page: page,
      per_page: per_page,
      total_pages: 1, # Would calculate based on actual data
      total_count: 0  # Would calculate based on actual data
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp verify_webhook_signature(conn) do
    # Verify webhook signature for security
    # This would check HMAC signature or similar
    {:ok, :valid}
  end

  defp process_external_campaign_update(campaign, update_data) do
    # Process updates from external tools
    # This could update campaign status, content, or metrics
    :ok
  end

  defp parse_date_range(params) do
    start_date = parse_date(params["start_date"]) || Date.add(Date.utc_today(), -30)
    end_date = parse_date(params["end_date"]) || Date.utc_today()

    {start_date, end_date}
  end

  defp parse_date(nil), do: nil
  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> String.split(ip, ",") |> List.first() |> String.trim()
      [] ->
        case conn.remote_ip do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
          _ -> "unknown"
        end
    end
  end

  # Analytics helper functions (simplified implementations)
  defp count_user_campaigns(user_id, date_range), do: 5
  defp calculate_user_total_revenue(user_id, date_range), do: 1250.00
  defp calculate_user_avg_quality(user_id, date_range), do: 4.2
  defp calculate_user_completion_rate(user_id, date_range), do: 0.85
  defp get_campaign_creation_trend(user_id, date_range), do: []
  defp get_revenue_trend(user_id, date_range), do: []
  defp get_quality_trend(user_id, date_range), do: []
  defp get_top_performing_campaigns(user_id, date_range), do: []
  defp get_collaboration_statistics(user_id, date_range), do: %{}
  defp get_campaign_quality_gates_summary(campaign_id), do: []
  defp get_campaign_collaboration_stats(campaign_id), do: %{}
  defp get_campaign_recent_activity(campaign_id), do: []
  defp calculate_user_contribution_score(tracker, user_id), do: 85
  defp count_user_quality_gates_passed(campaign_id, user_id), do: 3
  defp get_last_contribution_time(tracker, user_id), do: DateTime.utc_now()
  defp get_user_current_revenue_share(campaign_id, user_id), do: 15.5
  defp calculate_projected_earnings(campaign_id, user_id), do: 450.00
  defp calculate_next_payment_date(campaign_id), do: DateTime.add(DateTime.utc_now(), 30, :day)
  defp get_campaign_revenue_milestones(campaign_id), do: []
  defp extract_contract_terms_summary(contract), do: %{}
  defp format_contract_for_api(contract), do: %{id: contract.id, status: contract.status}

    defp get_campaign_quality_gates_status(campaign_id, user_id) do
    case :ets.lookup(:quality_gates_status, {campaign_id, user_id}) do
      [{{^campaign_id, ^user_id}, gates_status}] ->
        format_quality_gates_for_api(gates_status)
      [] ->
        %{
          gates: [],
          total_gates: 0,
          passed_gates: 0,
          failed_gates: 0,
          pending_gates: 0
        }
    end
  end

  defp format_quality_gates_for_api(gates_status) when is_list(gates_status) do
    gates = Enum.map(gates_status, fn gate ->
      %{
        name: gate.name,
        status: gate.status,
        threshold: gate.threshold,
        current_value: gate.current_value,
        last_checked: gate.last_checked_at
      }
    end)

    %{
      gates: gates,
      total_gates: length(gates),
      passed_gates: Enum.count(gates, &(&1.status == :passed)),
      failed_gates: Enum.count(gates, &(&1.status == :failed)),
      pending_gates: Enum.count(gates, &(&1.status == :pending))
    }
  end

  defp format_quality_gates_for_api(gates_status) when is_map(gates_status) do
    gates = Enum.map(gates_status, fn {gate_name, gate_data} ->
      %{
        name: gate_name,
        status: Map.get(gate_data, :status, :pending),
        threshold: Map.get(gate_data, :threshold, 0),
        current_value: Map.get(gate_data, :current_value, 0),
        last_checked: Map.get(gate_data, :last_checked_at)
      }
    end)

    %{
      gates: gates,
      total_gates: length(gates),
      passed_gates: Enum.count(gates, &(&1.status == :passed)),
      failed_gates: Enum.count(gates, &(&1.status == :failed)),
      pending_gates: Enum.count(gates, &(&1.status == :pending))
    }
  end

  defp format_quality_gates_for_api(_), do: %{gates: [], total_gates: 0, passed_gates: 0, failed_gates: 0, pending_gates: 0}

  # ============================================================================
  # OTHER MISSING HELPER FUNCTIONS
  # ============================================================================

  defp get_user_campaign_revenue_share(campaign_id, user_id) do
    case AdvancedTracker.get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        Map.get(tracker.dynamic_revenue_weights, user_id, 0.0)
      _ ->
        0.0
    end
  end

  defp calculate_projected_earnings(campaign_id, user_id) do
    campaign = DataCampaigns.get_campaign!(campaign_id)
    revenue_share = get_user_campaign_revenue_share(campaign_id, user_id)
    revenue_target = campaign.revenue_target || Decimal.new("1000.00")

    gross_projection = Decimal.mult(revenue_target, Decimal.div(Decimal.new(revenue_share), 100))

    # Apply platform fees (30% platform + 2.9% processing)
    platform_fee = Decimal.mult(gross_projection, Decimal.new("0.30"))
    processing_fee = Decimal.mult(gross_projection, Decimal.new("0.029"))
    total_fees = Decimal.add(platform_fee, processing_fee)

    net_projection = Decimal.sub(gross_projection, total_fees)
    Decimal.to_float(net_projection)
  end

  defp calculate_next_payment_date(campaign_id) do
    campaign = DataCampaigns.get_campaign!(campaign_id)

    case campaign.status do
      :completed -> DateTime.add(DateTime.utc_now(), 7, :day) # 7 days after completion
      :active ->
        if campaign.deadline do
          DateTime.add(campaign.deadline, 7, :day)
        else
          DateTime.add(DateTime.utc_now(), 30, :day)
        end
      _ -> DateTime.add(DateTime.utc_now(), 30, :day)
    end
  end

  defp get_campaign_revenue_milestones(campaign_id) do
    case :ets.match(:revenue_milestones, {'$1', %{campaign_id: campaign_id}}) do
      milestones when is_list(milestones) ->
        Enum.map(milestones, fn [milestone_id] ->
          [{^milestone_id, milestone}] = :ets.lookup(:revenue_milestones, milestone_id)
          format_milestone_for_api(milestone)
        end)
      _ ->
        []
    end
  end

  defp format_milestone_for_api(milestone) do
    %{
      id: milestone.id,
      type: milestone.milestone_type,
      description: milestone.description || "Revenue milestone",
      threshold: milestone.threshold_amount,
      triggered: milestone.triggered,
      triggered_at: milestone.triggered_at,
      processed: milestone.processed
    }
  end

  defp extract_contract_terms_summary(contract) do
    %{
      revenue_percentage: get_in(contract.revenue_split, ["percentage"]) || 0,
      quality_requirements: length(contract.quality_requirements || []),
      deadline: get_in(contract.timeline, ["deadline"]),
      improvement_periods_allowed: get_in(contract.timeline, ["improvement_period_allowed"]) || false,
      platform_fee: "30%",
      payment_schedule: "Upon campaign completion"
    }
  end

  defp format_contract_for_api(contract) do
    %{
      id: contract.id,
      status: contract.status,
      revenue_split: contract.revenue_split,
      signed_at: contract.signed_at,
      total_payments_made: contract.total_payments_made,
      contract_type: contract.contract_type
    }
  end

  # ============================================================================
  # MOCK DATA FUNCTIONS (Replace with real implementations)
  # ============================================================================

  # These functions provide mock data for development/testing
  # Replace with actual database queries in production

  defp count_user_campaigns(user_id, {start_date, end_date}) do
    # Mock implementation - replace with actual query
    case DataCampaigns.list_user_campaigns(user_id) do
      campaigns when is_list(campaigns) ->
        # Filter by date range if needed
        campaigns
        |> Enum.filter(fn campaign ->
          campaign_date = Date.from_iso8601!(DateTime.to_date(campaign.inserted_at))
          Date.compare(campaign_date, start_date) != :lt and
          Date.compare(campaign_date, end_date) != :gt
        end)
        |> length()
      _ -> 0
    end
  end

  defp calculate_user_total_revenue(user_id, date_range) do
    # Mock implementation - replace with actual revenue calculation
    campaigns = DataCampaigns.list_user_campaigns(user_id)

    campaigns
    |> Enum.filter(&(&1.status == :completed))
    |> Enum.reduce(0.0, fn campaign, acc ->
      user_revenue = get_user_campaign_revenue_amount(campaign.id, user_id)
      acc + user_revenue
    end)
  end

  defp get_user_campaign_revenue_amount(campaign_id, user_id) do
    revenue_share = get_user_campaign_revenue_share(campaign_id, user_id)

    # Mock calculation - replace with actual payment records
    case revenue_share > 0 do
      true -> revenue_share * 10.0 # Mock: $10 per percentage point
      false -> 0.0
    end
  end

  defp calculate_user_avg_quality(user_id, date_range) do
    # Mock implementation - replace with actual quality score aggregation
    campaigns = DataCampaigns.list_user_campaigns(user_id)

    if length(campaigns) > 0 do
      total_quality = campaigns
      |> Enum.reduce(0.0, fn campaign, acc ->
        quality_score = get_user_campaign_quality_score(campaign.id, user_id)
        acc + quality_score
      end)

      total_quality / length(campaigns)
    else
      0.0
    end
  end

  defp get_user_campaign_quality_score(campaign_id, user_id) do
    case AdvancedTracker.get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        quality_scores = get_in(tracker.contribution_metrics, [:peer_review_scores, user_id]) || []
        case quality_scores do
          scores when is_list(scores) and length(scores) > 0 ->
            Enum.sum(scores) / length(scores)
          score when is_number(score) ->
            score
          _ ->
            3.5 # Default quality score
        end
      _ ->
        3.5
    end
  end

  defp calculate_user_completion_rate(user_id, date_range) do
    campaigns = DataCampaigns.list_user_campaigns(user_id)
    total_campaigns = length(campaigns)

    if total_campaigns > 0 do
      completed_campaigns = Enum.count(campaigns, &(&1.status in [:completed, :published]))
      completed_campaigns / total_campaigns
    else
      0.0
    end
  end

  defp get_campaign_creation_trend(user_id, {start_date, end_date}) do
    # Mock implementation - return trend data points
    campaigns = DataCampaigns.list_user_campaigns(user_id)

    # Group campaigns by month and count
    campaigns
    |> Enum.group_by(fn campaign ->
      campaign.inserted_at
      |> DateTime.to_date()
      |> Date.beginning_of_month()
    end)
    |> Enum.map(fn {month, month_campaigns} ->
      %{
        date: month,
        count: length(month_campaigns)
      }
    end)
    |> Enum.sort_by(& &1.date, Date)
  end

  defp get_revenue_trend(user_id, date_range) do
    # Mock implementation - return revenue trend
    [
      %{date: Date.add(Date.utc_today(), -30), revenue: 150.0},
      %{date: Date.add(Date.utc_today(), -20), revenue: 275.0},
      %{date: Date.add(Date.utc_today(), -10), revenue: 420.0},
      %{date: Date.utc_today(), revenue: 580.0}
    ]
  end

  defp get_quality_trend(user_id, date_range) do
    # Mock implementation - return quality trend
    [
      %{date: Date.add(Date.utc_today(), -30), quality_score: 3.2},
      %{date: Date.add(Date.utc_today(), -20), quality_score: 3.8},
      %{date: Date.add(Date.utc_today(), -10), quality_score: 4.1},
      %{date: Date.utc_today(), quality_score: 4.3}
    ]
  end

  defp get_top_performing_campaigns(user_id, date_range) do
    campaigns = DataCampaigns.list_user_campaigns(user_id)

    campaigns
    |> Enum.map(fn campaign ->
      revenue = get_user_campaign_revenue_amount(campaign.id, user_id)
      quality = get_user_campaign_quality_score(campaign.id, user_id)

      %{
        id: campaign.id,
        title: campaign.title,
        revenue: revenue,
        quality_score: quality,
        performance_score: revenue * quality
      }
    end)
    |> Enum.sort_by(& &1.performance_score, :desc)
    |> Enum.take(5)
  end

  defp get_collaboration_statistics(user_id, date_range) do
    campaigns = DataCampaigns.list_user_campaigns(user_id)

    %{
      total_collaborations: length(campaigns),
      active_collaborations: Enum.count(campaigns, &(&1.status in [:active, :open])),
      successful_collaborations: Enum.count(campaigns, &(&1.status == :completed)),
      avg_collaborators_per_campaign: calculate_avg_collaborators(campaigns),
      total_collaborators_worked_with: count_unique_collaborators(campaigns, user_id)
    }
  end

  defp calculate_avg_collaborators(campaigns) do
    if length(campaigns) > 0 do
      total_collaborators = campaigns
      |> Enum.map(&(length(&1.contributors || [])))
      |> Enum.sum()

      total_collaborators / length(campaigns)
    else
      0.0
    end
  end

  defp count_unique_collaborators(campaigns, user_id) do
    campaigns
    |> Enum.flat_map(&(&1.contributors || []))
    |> Enum.map(& &1.user_id)
    |> Enum.filter(&(&1 != user_id))
    |> Enum.uniq()
    |> length()
  end

  # ============================================================================
  # ADDITIONAL HELPER FUNCTIONS FOR API COMPLETENESS
  # ============================================================================

  defp get_campaign_quality_gates_summary(campaign_id) do
    # Get all users' quality gates for this campaign
    case :ets.match(:quality_gates_status, {{campaign_id, '$1'}, '$2'}) do
      matches when is_list(matches) ->
        Enum.map(matches, fn [user_id, gates_data] ->
          %{
            user_id: user_id,
            gates: format_quality_gates_for_api(gates_data)
          }
        end)
      _ ->
        []
    end
  end

  defp get_campaign_collaboration_stats(campaign_id) do
    campaign = DataCampaigns.get_campaign!(campaign_id)

    %{
      total_contributors: length(campaign.contributors || []),
      active_contributors: count_active_contributors(campaign_id),
      contributions_today: count_contributions_today(campaign_id),
      avg_quality_score: calculate_campaign_avg_quality(campaign_id),
      collaboration_efficiency: calculate_collaboration_efficiency(campaign_id)
    }
  end

  defp count_active_contributors(campaign_id) do
    # Count contributors who made contributions in the last 24 hours
    case AdvancedTracker.get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        # Mock implementation - count users with recent activity
        Map.keys(tracker.contribution_metrics[:word_count_by_user] || %{}) |> length()
      _ ->
        0
    end
  end

  defp count_contributions_today(campaign_id) do
    # Mock implementation - count contributions made today
    :rand.uniform(10)
  end

  defp calculate_campaign_avg_quality(campaign_id) do
    case AdvancedTracker.get_campaign_tracker(campaign_id) do
      {:ok, tracker} ->
        quality_scores = Map.values(tracker.contribution_metrics[:peer_review_scores] || %{})
        if length(quality_scores) > 0 do
          Enum.sum(quality_scores) / length(quality_scores)
        else
          0.0
        end
      _ ->
        0.0
    end
  end

  defp calculate_collaboration_efficiency(campaign_id) do
    # Mock calculation of how efficiently the team is collaborating
    # Based on contribution frequency, quality scores, and time to completion
    0.85
  end

  defp get_campaign_recent_activity(campaign_id) do
    # Mock recent activity feed
    [
      %{
        type: "contribution_added",
        user: "john_doe",
        description: "Added 500 words to Chapter 2",
        timestamp: DateTime.add(DateTime.utc_now(), -2, :hour)
      },
      %{
        type: "peer_review_completed",
        user: "jane_smith",
        description: "Completed peer review with score 4.5/5",
        timestamp: DateTime.add(DateTime.utc_now(), -4, :hour)
      },
      %{
        type: "quality_gate_passed",
        user: "bob_wilson",
        description: "Passed minimum word count requirement",
        timestamp: DateTime.add(DateTime.utc_now(), -6, :hour)
      }
    ]
  end

  defp calculate_user_contribution_score(tracker, user_id) do
    # Calculate overall contribution score based on multiple factors
    word_count = get_in(tracker.contribution_metrics, [:word_count_by_user, user_id]) || 0
    quality_score = get_in(tracker.contribution_metrics, [:peer_review_scores, user_id]) || 3.0

    # Normalize and combine scores
    word_score = min(100, word_count / 50) # 1 point per 50 words, max 100
    quality_contribution = quality_score * 20 # Convert 5-point scale to 100-point scale

    round((word_score + quality_contribution) / 2)
  end

  defp count_user_quality_gates_passed(campaign_id, user_id) do
    case get_campaign_quality_gates_status(campaign_id, user_id) do
      %{passed_gates: count} -> count
      _ -> 0
    end
  end

  defp get_last_contribution_time(tracker, user_id) do
    # Get the most recent contribution timestamp for this user
    # This is a simplified version - in real implementation, you'd track timestamps
    DateTime.add(DateTime.utc_now(), -:rand.uniform(24), :hour)
  end

  # These functions would normally be defined in RevenueManager
  # Adding here for API completeness

  def get_user_pending_contracts(user_id) do
    # Mock implementation - get contracts pending signature
    [
      %{
        id: "contract_1",
        campaign_id: "campaign_1",
        campaign_title: "Tech Blog Series",
        revenue_percentage: 15.5,
        status: "pending_signature",
        created_at: DateTime.add(DateTime.utc_now(), -2, :day)
      }
    ]
  end

  def get_recent_campaign_payments(user_id, limit) do
    # Mock implementation - get recent payments
    [
      %{
        id: "payment_1",
        campaign_title: "Data Science Guide",
        amount: 125.50,
        processed_at: DateTime.add(DateTime.utc_now(), -5, :day),
        status: "completed"
      },
      %{
        id: "payment_2",
        campaign_title: "Marketing Podcast",
        amount: 89.25,
        processed_at: DateTime.add(DateTime.utc_now(), -12, :day),
        status: "completed"
      }
    ]
    |> Enum.take(limit)
  end

  def get_user_campaign_contract(campaign_id, user_id) do
    # Mock implementation - get user's contract for campaign
    {:ok, %{
      id: "contract_1",
      campaign_id: campaign_id,
      contributor_id: user_id,
      status: :active,
      revenue_split: %{"percentage" => 15.5},
      quality_requirements: [
        %{name: "minimum_word_count", threshold: 2000},
        %{name: "peer_review_score", threshold: 3.5}
      ],
      signed_at: DateTime.add(DateTime.utc_now(), -10, :day),
      legal_terms: "Standard collaborative content creation agreement..."
    }}
  end

  def update_external_revenue(campaign_id, revenue_data) do
    # Mock implementation - update revenue from external sources
    IO.puts("Updating external revenue for campaign #{campaign_id}: #{inspect(revenue_data)}")
    :ok
  end

  # ============================================================================
  # ERROR HANDLING HELPERS
  # ============================================================================

  defp handle_api_error({:error, :not_found}, conn) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Resource not found"})
  end

  defp handle_api_error({:error, :unauthorized}, conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "Access denied"})
  end

  defp handle_api_error({:error, reason}, conn) when is_binary(reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: reason})
  end

  defp handle_api_error({:error, reason}, conn) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: "Internal server error", details: inspect(reason)})
  end

  defp handle_api_error(_, conn) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: "Unknown error occurred"})
  end
end
