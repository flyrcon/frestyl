defmodule Frestyl.Services.PaymentHandler do
  @moduledoc """
  Handle service booking payments through Stripe
  """

  alias Frestyl.Services.ServiceBooking
  alias Frestyl.Payments.SubscriptionPlan
  alias Frestyl.Billing.ServiceRevenueTracker

  @stripe_api Application.compile_env(:frestyl, :stripe_api, Stripe)

  def create_payment_intent(%ServiceBooking{} = booking) do
    platform_fee = calculate_platform_fee(booking)

    payment_params = %{
      amount: booking.total_amount_cents,
      currency: booking.service.currency || "usd",
      application_fee_amount: platform_fee,
      transfer_data: %{
        destination: get_provider_stripe_account(booking.provider_id)
      },
      metadata: %{
        booking_reference: booking.booking_reference,
        service_id: booking.service_id,
        provider_id: booking.provider_id
      }
    }

    case @stripe_api.PaymentIntent.create(payment_params) do
      {:ok, payment_intent} ->
        update_booking_with_payment_intent(booking, payment_intent)

      {:error, error} ->
        {:error, format_stripe_error(error)}
    end
  end

  def create_checkout_session(%ServiceBooking{} = booking, success_url, cancel_url) do
    platform_fee = calculate_platform_fee(booking)

    session_params = %{
      payment_method_types: ["card"],
      line_items: [
        %{
          price_data: %{
            currency: booking.service.currency || "usd",
            product_data: %{
              name: booking.service.title,
              description: "#{booking.service.duration_minutes} minute session with #{booking.provider.first_name}"
            },
            unit_amount: booking.total_amount_cents
          },
          quantity: 1
        }
      ],
      mode: "payment",
      success_url: success_url,
      cancel_url: cancel_url,
      client_reference_id: booking.booking_reference,
      payment_intent_data: %{
        application_fee_amount: platform_fee,
        transfer_data: %{
          destination: get_provider_stripe_account(booking.provider_id)
        },
        metadata: %{
          booking_reference: booking.booking_reference,
          service_id: booking.service_id,
          provider_id: booking.provider_id
        }
      }
    }

    case @stripe_api.Session.create(session_params) do
      {:ok, session} ->
        update_booking_with_checkout_session(booking, session)

      {:error, error} ->
        {:error, format_stripe_error(error)}
    end
  end

  def handle_payment_success(payment_intent_id) do
    case get_booking_by_payment_intent(payment_intent_id) do
      nil ->
        {:error, :booking_not_found}

      booking ->
        with {:ok, booking} <- update_payment_status(booking, :fully_paid),
             {:ok, booking} <- confirm_booking(booking),
             :ok <- send_confirmation_emails(booking),
             :ok <- track_revenue(booking) do
          {:ok, booking}
        end
    end
  end

  def handle_payment_failure(payment_intent_id, reason) do
    case get_booking_by_payment_intent(payment_intent_id) do
      nil ->
        {:error, :booking_not_found}

      booking ->
        Services.update_booking(booking, %{
          payment_status: :failed,
          status: :cancelled,
          cancellation_reason: "Payment failed: #{reason}"
        })
    end
  end

  def process_refund(%ServiceBooking{} = booking, amount_cents \\ nil) do
    refund_amount = amount_cents || booking.total_amount_cents

    refund_params = %{
      payment_intent: booking.stripe_payment_intent_id,
      amount: refund_amount,
      reason: "requested_by_customer",
      metadata: %{
        booking_reference: booking.booking_reference,
        original_amount: booking.total_amount_cents
      }
    }

    case @stripe_api.Refund.create(refund_params) do
      {:ok, refund} ->
        update_booking_refund(booking, refund)

      {:error, error} ->
        {:error, format_stripe_error(error)}
    end
  end

  # Private functions

  defp calculate_platform_fee(%ServiceBooking{} = booking) do
    provider = booking.provider
    fee_percentage = get_platform_fee_percentage(provider)

    booking.total_amount_cents
    |> Decimal.new()
    |> Decimal.mult(fee_percentage)
    |> Decimal.div(100)
    |> Decimal.round(0)
    |> Decimal.to_integer()
  end

  defp get_platform_fee_percentage(provider) do
    case get_provider_subscription_plan(provider) do
      %SubscriptionPlan{platform_fee_percentage: fee} -> fee
      _ -> Decimal.new("5.0") # Default Creator tier fee
    end
  end

  defp get_provider_stripe_account(provider_id) do
    # Get provider's Stripe Connect account ID
    # This would be stored in user profile or separate table
    case Frestyl.Accounts.get_user_stripe_account(provider_id) do
      %{stripe_account_id: account_id} -> account_id
      _ -> nil
    end
  end

  defp update_booking_with_payment_intent(booking, payment_intent) do
    Services.update_booking(booking, %{
      stripe_payment_intent_id: payment_intent.id,
      payment_status: :pending
    })
  end

  defp update_booking_with_checkout_session(booking, session) do
    Services.update_booking(booking, %{
      stripe_checkout_session_id: session.id,
      payment_status: :pending
    })
  end

  defp get_booking_by_payment_intent(payment_intent_id) do
    Frestyl.Repo.get_by(ServiceBooking, stripe_payment_intent_id: payment_intent_id)
  end

  defp update_payment_status(booking, status) do
    Services.update_booking(booking, %{payment_status: status})
  end

  defp confirm_booking(booking) do
    Services.confirm_booking(booking)
  end

  defp send_confirmation_emails(booking) do
    # Send to both client and provider
    Frestyl.Emails.send_booking_confirmation(booking)
    Frestyl.Emails.send_provider_booking_notification(booking)
    :ok
  end

  defp track_revenue(booking) do
    ServiceRevenueTracker.track_booking_completion(booking)
    :ok
  end

  defp update_booking_refund(booking, refund) do
    Services.update_booking(booking, %{
      status: :cancelled,
      payment_status: :refunded,
      cancelled_at: DateTime.utc_now(),
      cancellation_reason: "Refunded: #{refund.reason}"
    })
  end

  defp get_provider_subscription_plan(provider) do
    Frestyl.Payments.get_user_subscription_plan(provider.id)
  end

  defp format_stripe_error(error) do
    case error do
      %Stripe.Error{message: message} -> message
      %{message: message} -> message
      _ -> "Payment processing error"
    end
  end
end
