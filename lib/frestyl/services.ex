defmodule Frestyl.Services do
  @moduledoc """
  Service booking system for frestyl platform
  """

  import Ecto.Query
  alias Frestyl.Repo
  alias Frestyl.Services.{Service, ServiceBooking, ServiceAvailability}
  alias Frestyl.Billing.UsageTracker
  alias Frestyl.Features.FeatureGate
  alias Frestyl.Payments.SubscriptionPlan

  # ============================================================================
  # Service Management
  # ============================================================================

  def list_user_services(user_id) do
    Service
    |> where([s], s.user_id == ^user_id)
    |> order_by([s], desc: s.inserted_at)
    |> preload([:bookings, :availabilities])
    |> Repo.all()
  end

  def get_service!(id), do: Repo.get!(Service, id)

  def get_service_with_availability(id) do
    Service
    |> where([s], s.id == ^id)
    |> preload([:availabilities, :user])
    |> Repo.one()
  end

  def create_service(user, attrs) do
    # Check feature access and limits
    account = get_user_account(user)

    with {:ok, :can_create} <- check_service_creation_limits(account),
         {:ok, service} <- create_service_record(user, attrs),
         :ok <- track_service_creation(account) do
      {:ok, service}
    end
  end

  defp create_service_record(user, attrs) do
    %Service{}
    |> Service.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  def update_service(%Service{} = service, attrs) do
    service
    |> Service.changeset(attrs)
    |> Repo.update()
  end

  def delete_service(%Service{} = service) do
    Repo.delete(service)
  end

  # ============================================================================
  # Service Booking Management
  # ============================================================================

  def create_booking(service, client_attrs, provider) do
    # Calculate platform fees based on subscription plan
    platform_fee_percentage = get_platform_fee_percentage(provider)
    total_amount = service.price_cents
    platform_fee = calculate_platform_fee(total_amount, platform_fee_percentage)
    provider_amount = total_amount - platform_fee

    booking_attrs = Map.merge(client_attrs, %{
      service_id: service.id,
      provider_id: provider.id,
      total_amount_cents: total_amount,
      platform_fee_cents: platform_fee,
      provider_amount_cents: provider_amount
    })

    with {:ok, booking} <- create_booking_record(booking_attrs),
         :ok <- track_booking_usage(provider, booking) do
      {:ok, booking}
    end
  end

  defp create_booking_record(attrs) do
    %ServiceBooking{}
    |> ServiceBooking.changeset(attrs)
    |> Repo.insert()
  end

  def update_booking(%ServiceBooking{} = booking, attrs) do
    booking
    |> ServiceBooking.changeset(attrs)
    |> Repo.update()
  end

  def confirm_booking(%ServiceBooking{} = booking) do
    update_booking(booking, %{
      status: :confirmed,
      confirmation_sent_at: DateTime.utc_now()
    })
  end

  def cancel_booking(%ServiceBooking{} = booking, reason) do
    update_booking(booking, %{
      status: :cancelled,
      cancelled_at: DateTime.utc_now(),
      cancellation_reason: reason
    })
  end

  def complete_booking(%ServiceBooking{} = booking, provider_notes \\ nil) do
    update_booking(booking, %{
      status: :completed,
      completed_at: DateTime.utc_now(),
      provider_notes: provider_notes
    })
  end

  # ============================================================================
  # Availability Management
  # ============================================================================

  def create_availability(service, attrs) do
    %ServiceAvailability{}
    |> ServiceAvailability.changeset(Map.put(attrs, :service_id, service.id))
    |> Repo.insert()
  end

  def get_available_slots(service_id, date) do
    # Implementation to calculate available time slots
    # This would integrate with the availability system
    service = get_service_with_availability(service_id)
    existing_bookings = get_bookings_for_date(service_id, date)

    calculate_available_slots(service, date, existing_bookings)
  end

  # ============================================================================
  # Payment Integration
  # ============================================================================

  def process_booking_payment(booking, payment_method) do
    # Integrate with existing Stripe payment system
    # This would use the existing payment infrastructure

    case create_stripe_payment_intent(booking, payment_method) do
      {:ok, payment_intent} ->
        update_booking(booking, %{
          stripe_payment_intent_id: payment_intent.id,
          payment_status: :pending
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_payment_success(booking) do
    with {:ok, booking} <- update_booking(booking, %{payment_status: :fully_paid}),
         {:ok, booking} <- confirm_booking(booking),
         :ok <- send_confirmation_email(booking) do
      {:ok, booking}
    end
  end

  # ============================================================================
  # Platform Fee Calculation
  # ============================================================================

  defp get_platform_fee_percentage(user) do
    # Get from existing subscription plan
    case get_user_subscription_plan(user) do
      %SubscriptionPlan{platform_fee_percentage: fee} -> fee
      _ -> Decimal.new("5.0") # Default 5% for Creator tier
    end
  end

  defp calculate_platform_fee(amount_cents, fee_percentage) do
    amount_cents
    |> Decimal.new()
    |> Decimal.mult(fee_percentage)
    |> Decimal.div(100)
    |> Decimal.round(0)
    |> Decimal.to_integer()
  end

  # ============================================================================
  # Usage Tracking
  # ============================================================================

  defp track_service_creation(account) do
    UsageTracker.track_usage(account, :services, 1, %{action: :create})
  end

  defp track_booking_usage(provider, booking) do
    account = get_user_account(provider)
    UsageTracker.track_usage(account, :bookings, 1, %{
      booking_id: booking.id,
      amount_cents: booking.total_amount_cents
    })
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp check_service_creation_limits(account) do
    if FeatureGate.can_access_feature?(account, :service_creation) do
      {:ok, :can_create}
    else
      {:error, :limit_reached}
    end
  end

  defp get_user_account(user) do
    # This would integrate with your existing account system
    Frestyl.Accounts.get_user_primary_account(user.id)
  end

  defp get_user_subscription_plan(user) do
    # Get from existing subscription system
    Frestyl.Payments.get_user_subscription_plan(user.id)
  end

  defp get_bookings_for_date(service_id, date) do
    ServiceBooking
    |> where([b], b.service_id == ^service_id)
    |> where([b], fragment("?::date", b.scheduled_at) == ^date)
    |> where([b], b.status not in [:cancelled])
    |> Repo.all()
  end

  defp calculate_available_slots(service, date, existing_bookings) do
    # Implementation for slot calculation
    # This would be a complex function that:
    # 1. Gets service availability for the day
    # 2. Subtracts existing bookings
    # 3. Accounts for buffer time
    # 4. Returns available time slots
    []
  end

  defp send_confirmation_email(_booking) do
    # Integrate with existing email system
    :ok
  end

  defp create_stripe_payment_intent(_booking, _payment_method) do
    # Integrate with existing Stripe setup
    {:ok, %{id: "pi_test"}}
  end
end
