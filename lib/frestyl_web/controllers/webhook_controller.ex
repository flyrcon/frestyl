defmodule FrestylWeb.WebhookController do
  use FrestylWeb, :controller
  alias Frestyl.Payments

  @stripe_webhook_secret Application.compile_env(:frestyl, :stripe_webhook_secret)

  # Disable CSRF protection for webhook endpoints
  plug :protect_from_forgery, with: :null_session

  def stripe(conn, _params) do
    payload = conn.assigns.raw_body
    signature = get_req_header(conn, "stripe-signature") |> List.first()

    case Stripe.Webhook.construct_event(payload, signature, @stripe_webhook_secret) do
      {:ok, %{type: event_type} = event} ->
        handle_stripe_event(event_type, event)
        send_resp(conn, 200, "")

      {:error, _reason} ->
        conn
        |> put_status(400)
        |> text("Invalid webhook signature")
    end
  end

  defp handle_stripe_event("checkout.session.completed", %{data: %{object: session}}) do
    Payments.process_successful_checkout(session)
  end

  defp handle_stripe_event("customer.subscription.updated", %{data: %{object: subscription}}) do
    Payments.update_subscription_status(subscription)
  end

  defp handle_stripe_event("customer.subscription.deleted", %{data: %{object: subscription}}) do
    Payments.mark_subscription_as_canceled(subscription)
  end

  defp handle_stripe_event("invoice.payment_succeeded", %{data: %{object: invoice}}) do
    Payments.process_invoice_payment(invoice)
  end

  defp handle_stripe_event("invoice.payment_failed", %{data: %{object: invoice}}) do
    Payments.handle_failed_payment(invoice)
  end

  defp handle_stripe_event(_event_type, _event), do: :ok
end
