defmodule Frestyl.Billing.UsageTracker do
  @moduledoc "Track usage for subscription billing"

  alias Frestyl.Accounts
  alias Frestyl.Billing
  alias Frestyl.Repo
  import Ecto.Query
  require Logger

  def track_usage(account, usage_type, amount, metadata \\ %{}) do
    # Create usage record
    usage_record = %{
      account_id: account.id,
      usage_type: usage_type,
      amount: amount,
      metadata: metadata,
      recorded_at: DateTime.utc_now()
    }

    {:ok, _} = create_usage_record(usage_record)

    # Update account usage totals
    update_account_usage(account, usage_type, amount)

    # Check for overage billing
    check_overage_billing(account, usage_type)

    {:ok, usage_record}
  end

  def create_usage_record(usage_record) do
    # Placeholder - create usage record in database
    Logger.info("Creating usage record: #{usage_record.usage_type} = #{usage_record.amount}")

    # In real implementation:
    # %UsageRecord{}
    # |> UsageRecord.changeset(usage_record)
    # |> Repo.insert()

    {:ok, Map.put(usage_record, :id, System.unique_integer([:positive]))}
  end

  def update_account_usage(account, usage_type, amount) do
    # Placeholder - update account's running totals
    Logger.info("Updating account #{account.id} usage: #{usage_type} += #{amount}")

    # In real implementation, you'd update the account record:
    # current_usage = Map.get(account.usage_totals, usage_type, 0)
    # new_totals = Map.put(account.usage_totals, usage_type, current_usage + amount)
    # Accounts.update_account(account, %{usage_totals: new_totals})

    :ok
  end

  def check_overage_billing(account, usage_type) do
    # Check if usage exceeds plan limits and apply overage charges
    limits = get_usage_limits(account)
    current_usage = get_current_usage_for_type(account, usage_type)
    limit = Map.get(limits, usage_type, 0)

    if current_usage > limit do
      overage_amount = current_usage - limit
      apply_overage_charges(account, usage_type, overage_amount)
    else
      :ok
    end
  end

  def apply_overage_charges(account, usage_type, overage_amount) do
    # Calculate and apply overage charges
    rate = get_overage_rate(usage_type)
    charge_amount = overage_amount * rate

    if charge_amount > 0 do
      # Create billing charge for overage
      billing_record = %{
        account_id: account.id,
        charge_type: :overage,
        usage_type: usage_type,
        amount: charge_amount,
        overage_units: overage_amount,
        rate: rate,
        charged_at: DateTime.utc_now()
      }

      Logger.info("Applying overage charge: #{charge_amount} for #{overage_amount} units of #{usage_type}")

      # In real implementation, you'd create a billing record and process payment
      # Billing.create_overage_charge(billing_record)

      {:ok, billing_record}
    else
      :ok
    end
  end

  def get_overage_rate(usage_type) do
    # Define overage rates per unit
    case usage_type do
      :storage -> 0.10           # $0.10 per GB over limit
      :collaboration_time -> 0.05 # $0.05 per hour over limit
      :api_calls -> 0.001        # $0.001 per API call over limit
      :exports -> 0.50           # $0.50 per export over limit
      _ -> 0.0
    end
  end

  # ============================================================================
  # Usage Reporting
  # ============================================================================

  def get_account_usage_summary(account, period \\ :current_month) do
    # Get usage summary for an account
    case period do
      :current_month ->
        %{
          storage_gb: get_current_usage_for_type(account, :storage),
          collaboration_hours: get_current_usage_for_type(account, :collaboration_time),
          api_calls: get_current_usage_for_type(account, :api_calls),
          export_count: get_current_usage_for_type(account, :exports)
        }

      :last_30_days ->
        # Return usage for last 30 days
        get_usage_for_period(account, Date.add(Date.utc_today(), -30), Date.utc_today())

      _ ->
        %{}
    end
  end

  def get_usage_limits(account) do
    tier = Map.get(account, :subscription_tier, "free")

    case tier do
      "free" ->
        %{
          storage: 1.0,        # 1 GB
          collaboration_time: 10,  # 10 hours
          api_calls: 1000,     # 1000 calls
          exports: 5           # 5 exports
        }
      "pro" ->
        %{
          storage: 10.0,       # 10 GB
          collaboration_time: 100, # 100 hours
          api_calls: 10000,    # 10k calls
          exports: 50          # 50 exports
        }
      "premium" ->
        %{
          storage: 100.0,      # 100 GB
          collaboration_time: 500, # 500 hours
          api_calls: 100000,   # 100k calls
          exports: 500         # 500 exports
        }
      "enterprise" ->
        %{
          storage: -1,         # Unlimited
          collaboration_time: -1, # Unlimited
          api_calls: -1,       # Unlimited
          exports: -1          # Unlimited
        }
      _ ->
        %{storage: 0, collaboration_time: 0, api_calls: 0, exports: 0}
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  def get_current_usage_for_type(account, usage_type) do
    # Placeholder - get current usage for specific type
    # In real implementation, you'd query usage records
    case usage_type do
      :storage -> 0.5        # 0.5 GB
      :collaboration_time -> 2  # 2 hours
      :api_calls -> 150      # 150 calls
      :exports -> 1          # 1 export
      _ -> 0
    end
  end

    def get_current_usage(account) do
    usage = account.current_usage || %{}

    %{
      story_count: Map.get(usage, "story_count", 0),
      storage_used_gb: Map.get(usage, "storage_used_gb", 0),
      video_minutes_used: Map.get(usage, "video_minutes_used", 0),
      collaboration_time: Map.get(usage, "collaboration_time", 0),
      active_collaborators: count_active_collaborators(account)
    }
  end

  def reset_billing_cycle_usage(account) do
    # Called at the start of each billing cycle
    billing_usage = account.current_usage || %{}

    Accounts.update_account(account, %{
      billing_cycle_usage: billing_usage,
      current_usage: %{}
    })
  end

  defp increment_usage(account, metric, amount, metadata) do
    current_usage = account.current_usage || %{}
    metric_str = to_string(metric)

    new_value = Map.get(current_usage, metric_str, 0) + amount
    updated_usage = Map.put(current_usage, metric_str, new_value)

    # Update account
    Accounts.update_account(account, %{current_usage: updated_usage})

    # Create usage record for detailed tracking
    create_usage_record(account, metric, amount, metadata)
  end

  defp create_usage_record(account, metric, amount, metadata) do
    # This would insert into a usage_records table for detailed billing
    # For now, just log it
    IO.puts("Usage: Account #{account.id} used #{amount} #{metric} - #{inspect(metadata)}")
  end

  defp count_active_collaborators(account) do
    # Count unique collaborators across all stories in the last 30 days
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    from(c in "story_collaborations",
      join: s in "portfolios", on: s.id == c.story_id,
      where: s.account_id == ^account.id,
      where: c.last_active_at > ^thirty_days_ago,
      select: count(fragment("DISTINCT ?", c.collaborator_user_id))
    )
    |> Repo.one() || 0
  end

  def get_usage_for_period(account, start_date, end_date) do
    # Placeholder - get usage for specific date range
    Logger.info("Getting usage for account #{account.id} from #{start_date} to #{end_date}")

    %{
      period: %{start: start_date, end: end_date},
      storage_gb: 0.3,
      collaboration_hours: 1.5,
      api_calls: 75,
      export_count: 0
    }
  end

  # ============================================================================
  # Quota Management
  # ============================================================================

  def check_quota_available(account, usage_type, requested_amount) do
    limits = get_usage_limits(account)
    current_usage = get_current_usage_for_type(account, usage_type)
    limit = Map.get(limits, usage_type, 0)

    cond do
      limit == -1 -> {:ok, :unlimited}  # Unlimited tier
      current_usage + requested_amount <= limit -> {:ok, :within_quota}
      true ->
        available = max(0, limit - current_usage)
        {:error, {:quota_exceeded, available}}
    end
  end

  def get_quota_status(account) do
    limits = get_usage_limits(account)

    Enum.map(limits, fn {usage_type, limit} ->
      current = get_current_usage_for_type(account, usage_type)

      status = cond do
        limit == -1 -> :unlimited
        current >= limit -> :exceeded
        current >= limit * 0.9 -> :warning  # 90% of limit
        current >= limit * 0.8 -> :caution  # 80% of limit
        true -> :ok
      end

      {usage_type, %{
        current: current,
        limit: limit,
        percentage: if(limit > 0, do: (current / limit * 100), else: 0),
        status: status
      }}
    end)
    |> Enum.into(%{})
  end

  # ============================================================================
  # Usage Analytics
  # ============================================================================

  def get_usage_trends(account, days \\ 30) do
    # Get usage trends over time
    end_date = Date.utc_today()
    start_date = Date.add(end_date, -days)

    # Placeholder - generate sample trend data
    daily_usage = for day_offset <- 0..days do
      date = Date.add(start_date, day_offset)
      %{
        date: date,
        storage: :rand.uniform() * 0.1,
        collaboration_time: :rand.uniform() * 2,
        api_calls: :rand.uniform(50),
        exports: if(:rand.uniform() > 0.8, do: 1, else: 0)
      }
    end

    %{
      period: %{start: start_date, end: end_date},
      daily_usage: daily_usage,
      totals: %{
        storage: Enum.sum(Enum.map(daily_usage, & &1.storage)),
        collaboration_time: Enum.sum(Enum.map(daily_usage, & &1.collaboration_time)),
        api_calls: Enum.sum(Enum.map(daily_usage, & &1.api_calls)),
        exports: Enum.sum(Enum.map(daily_usage, & &1.exports))
      }
    }
  end

  def predict_monthly_usage(account) do
    # Predict end-of-month usage based on current trends
    current_usage = get_account_usage_summary(account, :current_month)
    days_elapsed = Date.day_of_month(Date.utc_today())
    days_in_month = Date.days_in_month(Date.utc_today())

    projection_factor = days_in_month / days_elapsed

    %{
      projected_storage: current_usage.storage_gb * projection_factor,
      projected_collaboration_hours: current_usage.collaboration_hours * projection_factor,
      projected_api_calls: current_usage.api_calls * projection_factor,
      projected_exports: current_usage.export_count * projection_factor,
      confidence: min(days_elapsed / days_in_month, 1.0)
    }
  end

  def track_story_creation(account, story) do
    track_usage(account, :story_creation, 1, %{
      story_id: story.id,
      story_type: story.story_type
    })
  end

  def track_storage_usage(account, size_mb, media_type) do
    increment_usage(account, :storage_used_gb, size_mb / 1024, %{
      media_type: media_type,
      size_mb: size_mb
    })
  end

  def track_collaboration_session(account, duration_minutes, participant_count) do
    collaboration_units = duration_minutes * participant_count

    increment_usage(account, :collaboration_time, collaboration_units, %{
      duration_minutes: duration_minutes,
      participant_count: participant_count
    })
  end

  def track_collaboration_minutes(account, minutes, collaboration_type) do
    track_usage(account, :collaboration_time, minutes, %{
      collaboration_type: collaboration_type
    })
  end

  def track_video_recording(account, duration_minutes, quality) do
    # Different billing weights for quality levels
    billing_minutes = case quality do
      :standard -> duration_minutes
      :hd -> duration_minutes * 1.5
      :premium -> duration_minutes * 2.0
    end

    increment_usage(account, :video_minutes_used, billing_minutes, %{
      raw_minutes: duration_minutes,
      quality: quality
    })
  end
end
