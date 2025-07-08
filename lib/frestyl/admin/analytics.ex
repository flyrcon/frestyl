# lib/frestyl/admin/analytics.ex
defmodule Frestyl.Admin.Analytics do
  @moduledoc """
  Advanced analytics for admin dashboard.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Accounts.{User, Account}
  alias Frestyl.Portfolios.Portfolio
  alias Frestyl.Channels.{Channel, ChannelMembership}
  alias Frestyl.Chat.Message

  def engagement_metrics do
    %{
      daily_active_users: get_daily_active_users(),
      weekly_active_users: get_weekly_active_users(),
      monthly_active_users: get_monthly_active_users(),
      average_session_duration: get_average_session_duration(),
      bounce_rate: get_bounce_rate(),
      user_retention: get_user_retention_rates()
    }
  end

  def feature_usage_stats do
    [
      {"Portfolio Creation", get_portfolio_usage_percentage()},
      {"Channel Participation", get_channel_participation_percentage()},
      {"Collaboration Features", get_collaboration_usage_percentage()},
      {"Creator Tools", get_creator_tools_usage_percentage()},
      {"Monetization Features", get_monetization_usage_percentage()}
    ]
  end

  def geographic_distribution do
    # This would integrate with user location data
    # For now, return mock data
    [
      {"United States", 45.2},
      {"Canada", 12.8},
      {"United Kingdom", 8.9},
      {"Germany", 6.7},
      {"Australia", 5.4},
      {"France", 4.2},
      {"Japan", 3.8},
      {"Other", 13.0}
    ]
  end

  def device_usage_stats do
    # This would track actual device usage
    # For now, return representative data
    %{
      desktop: 62.5,
      mobile: 28.3,
      tablet: 9.2
    }
  end

  def subscription_conversion_funnel do
    %{
      visitors: get_unique_visitors_count(),
      signups: get_signups_count(),
      trial_users: get_trial_users_count(),
      paid_users: get_paid_users_count(),
      conversion_rates: calculate_conversion_rates()
    }
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp get_daily_active_users do
    today = DateTime.utc_now() |> DateTime.to_date()

    from(u in User,
      where: fragment("date(?)", u.last_sign_in_at) == ^today
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_weekly_active_users do
    week_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 3600, :second)

    from(u in User,
      where: u.last_sign_in_at >= ^week_ago
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_monthly_active_users do
    month_ago = DateTime.utc_now() |> DateTime.add(-30 * 24 * 3600, :second)

    from(u in User,
      where: u.last_sign_in_at >= ^month_ago
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_average_session_duration do
    # This would calculate based on actual session tracking
    # For now, return a representative duration in minutes
    42.5
  end

  defp get_bounce_rate do
    # This would calculate actual bounce rate
    # For now, return a percentage
    23.7
  end

  defp get_user_retention_rates do
    %{
      day_1: 78.5,
      day_7: 45.2,
      day_30: 28.9
    }
  end

  defp get_portfolio_usage_percentage do
    total_users = from(u in User) |> Repo.aggregate(:count, :id)
    users_with_portfolios = from(p in Portfolio,
      distinct: p.user_id
    ) |> Repo.aggregate(:count, :user_id)

    if total_users > 0 do
      (users_with_portfolios / total_users * 100) |> Float.round(1)
    else
      0.0
    end
  end

  defp get_channel_participation_percentage do
    total_users = from(u in User) |> Repo.aggregate(:count, :id)
    users_in_channels = from(cm in ChannelMembership,
      where: cm.status == "active",
      distinct: cm.user_id
    ) |> Repo.aggregate(:count, :user_id)

    if total_users > 0 do
      (users_in_channels / total_users * 100) |> Float.round(1)
    else
      0.0
    end
  end

  defp get_collaboration_usage_percentage do
    # Calculate based on collaboration features usage
    # This would integrate with actual collaboration tracking
    67.3
  end

  defp get_creator_tools_usage_percentage do
    total_users = from(u in User) |> Repo.aggregate(:count, :id)
    creator_tier_users = from(a in Account,
      where: a.subscription_tier in ["creator", "professional", "enterprise"]
    ) |> Repo.aggregate(:count, :id)

    if total_users > 0 do
      (creator_tier_users / total_users * 100) |> Float.round(1)
    else
      0.0
    end
  end

  defp get_monetization_usage_percentage do
    # This would track actual monetization feature usage
    24.6
  end

  defp get_unique_visitors_count do
    # This would integrate with analytics tracking
    # For now, return a representative number
    15_847
  end

  defp get_signups_count do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30 * 24 * 3600, :second)

    from(u in User,
      where: u.inserted_at >= ^thirty_days_ago
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_trial_users_count do
    from(a in Account,
      where: a.subscription_tier != "personal" and not is_nil(a.trial_ends_at)
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_paid_users_count do
    from(a in Account,
      where: a.subscription_tier != "personal" and is_nil(a.trial_ends_at)
    )
    |> Repo.aggregate(:count, :id)
  end

  defp calculate_conversion_rates do
    visitors = get_unique_visitors_count()
    signups = get_signups_count()
    paid = get_paid_users_count()

    %{
      visitor_to_signup: if(visitors > 0, do: (signups / visitors * 100) |> Float.round(1), else: 0.0),
      signup_to_paid: if(signups > 0, do: (paid / signups * 100) |> Float.round(1), else: 0.0),
      visitor_to_paid: if(visitors > 0, do: (paid / visitors * 100) |> Float.round(1), else: 0.0)
    }
  end
end
