defmodule Frestyl.Billing.ServiceRevenueTracker do
  @moduledoc """
  Track service booking revenue and platform fees
  """

  alias Frestyl.Billing.UsageTracker
  alias Frestyl.Services.ServiceBooking
  alias Frestyl.Payments.Payout
  alias Frestyl.Repo
  import Ecto.Query

  def track_booking_completion(%ServiceBooking{} = booking) do
    # Track revenue for usage billing
    account = get_provider_account(booking.provider_id)

    UsageTracker.track_usage(account, :service_revenue_cents, booking.provider_amount_cents, %{
      booking_id: booking.id,
      service_id: booking.service_id,
      platform_fee_cents: booking.platform_fee_cents
    })

    # Create payout record for the provider
    create_payout_record(booking)
  end

  def calculate_monthly_service_revenue(user_id, month, year) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)

    query = from b in ServiceBooking,
      join: s in assoc(b, :service),
      where: s.user_id == ^user_id,
      where: b.status == :completed,
      where: fragment("?::date", b.completed_at) >= ^start_date,
      where: fragment("?::date", b.completed_at) <= ^end_date,
      select: %{
        total_bookings: count(b.id),
        gross_revenue_cents: sum(b.total_amount_cents),
        platform_fees_cents: sum(b.platform_fee_cents),
        net_revenue_cents: sum(b.provider_amount_cents)
      }

    Repo.one(query) || %{
      total_bookings: 0,
      gross_revenue_cents: 0,
      platform_fees_cents: 0,
      net_revenue_cents: 0
    }
  end

  def get_service_analytics(service_id, user_id) do
    # Verify ownership
    query = from s in Frestyl.Services.Service,
      where: s.id == ^service_id and s.user_id == ^user_id

    if Repo.exists?(query) do
      booking_stats = from b in ServiceBooking,
        where: b.service_id == ^service_id,
        group_by: b.status,
        select: {b.status, count(b.id)}

      revenue_stats = from b in ServiceBooking,
        where: b.service_id == ^service_id and b.status == :completed,
        select: %{
          total_revenue_cents: sum(b.provider_amount_cents),
          total_bookings: count(b.id),
          avg_booking_value_cents: avg(b.total_amount_cents)
        }

      %{
        booking_counts: Repo.all(booking_stats) |> Enum.into(%{}),
        revenue: Repo.one(revenue_stats) || %{total_revenue_cents: 0, total_bookings: 0, avg_booking_value_cents: 0}
      }
    else
      {:error, :unauthorized}
    end
  end

  defp create_payout_record(%ServiceBooking{} = booking) do
    %Payout{}
    |> Payout.changeset(%{
      user_id: booking.provider_id,
      amount_cents: booking.provider_amount_cents,
      status: "pending",
      notes: "Service booking payout - #{booking.booking_reference}"
    })
    |> Repo.insert()
  end

  defp get_provider_account(user_id) do
    Frestyl.Accounts.get_user_primary_account(user_id)
  end
end
