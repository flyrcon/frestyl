# lib/frestyl/admin/stats.ex
defmodule Frestyl.Admin.Stats do
  @moduledoc """
  Admin dashboard statistics and metrics.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Accounts.{User, Account}
  alias Frestyl.Portfolios.Portfolio
  alias Frestyl.Channels.Channel
  alias Frestyl.Billing.Transaction

  def total_users do
    from(u in User) |> Repo.aggregate(:count, :id)
  end

  def active_users_today do
    today = DateTime.utc_now() |> DateTime.to_date()

    from(u in User,
      where: fragment("date(?)", u.last_sign_in_at) == ^today
    )
    |> Repo.aggregate(:count, :id)
  end

  def total_portfolios do
    from(p in Portfolio) |> Repo.aggregate(:count, :id)
  end

  def total_channels do
    from(c in Channel) |> Repo.aggregate(:count, :id)
  end

  def revenue_today do
    today = DateTime.utc_now() |> DateTime.to_date()

    result = from(t in Transaction,
      where: fragment("date(?)", t.inserted_at) == ^today
      and t.status == "completed"
      and t.transaction_type == "payment",
      select: sum(t.amount)
    )
    |> Repo.one()

    (result || Decimal.new(0)) |> Decimal.to_float() |> Float.round(2)
  end

  def revenue_this_month do
    start_of_month = DateTime.utc_now() |> DateTime.to_date() |> Date.beginning_of_month()

    result = from(t in Transaction,
      where: fragment("date(?)", t.inserted_at) >= ^start_of_month
      and t.status == "completed"
      and t.transaction_type == "payment",
      select: sum(t.amount)
    )
    |> Repo.one()

    (result || Decimal.new(0)) |> Decimal.to_float() |> Float.round(2)
  end

  def conversion_rate_this_month do
    start_of_month = DateTime.utc_now() |> DateTime.to_date() |> Date.beginning_of_month()

    # Users who signed up this month
    signups = from(u in User,
      where: fragment("date(?)", u.inserted_at) >= ^start_of_month
    )
    |> Repo.aggregate(:count, :id)

    # Users who upgraded from free this month
    upgrades = from(a in Account,
      where: fragment("date(?)", a.updated_at) >= ^start_of_month
      and a.subscription_tier != "personal"
      and not is_nil(a.previous_tier)
    )
    |> Repo.aggregate(:count, :id)

    if signups > 0 do
      (upgrades / signups * 100) |> Float.round(1)
    else
      0.0
    end
  end

  def churn_rate_this_month do
    start_of_month = DateTime.utc_now() |> DateTime.to_date() |> Date.beginning_of_month()

    # Active subscribers at start of month
    active_start = from(a in Account,
      where: a.subscription_tier != "personal"
      and (is_nil(a.cancelled_at) or a.cancelled_at >= ^start_of_month)
    )
    |> Repo.aggregate(:count, :id)

    # Cancellations this month
    cancellations = from(a in Account,
      where: fragment("date(?)", a.cancelled_at) >= ^start_of_month
    )
    |> Repo.aggregate(:count, :id)

    if active_start > 0 do
      (cancellations / active_start * 100) |> Float.round(1)
    else
      0.0
    end
  end

  def open_support_tickets do
    # This would integrate with your support ticket system
    # For now, return a mock number
    :rand.uniform(15) + 5
  end

  def system_uptime do
    # This would check actual system uptime
    # For now, return a high uptime percentage
    99.8
  end

  def user_growth_last_30_days do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30 * 24 * 3600, :second)

    daily_signups = from(u in User,
      where: u.inserted_at >= ^thirty_days_ago,
      group_by: fragment("date(?)", u.inserted_at),
      order_by: fragment("date(?)", u.inserted_at),
      select: {fragment("date(?)", u.inserted_at), count(u.id)}
    )
    |> Repo.all()

    total_30_days_ago = from(u in User,
      where: u.inserted_at < ^thirty_days_ago
    )
    |> Repo.aggregate(:count, :id)

    total_now = total_users()

    growth_count = total_now - total_30_days_ago
    growth_percentage = if total_30_days_ago > 0 do
      (growth_count / total_30_days_ago * 100) |> Float.round(1)
    else
      0.0
    end

    %{
      daily_data: daily_signups,
      total_growth: growth_count,
      percentage: growth_percentage
    }
  end
end
