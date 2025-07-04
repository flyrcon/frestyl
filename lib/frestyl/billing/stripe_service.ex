# lib/frestyl/billing/stripe_service.ex
defmodule Frestyl.Billing.StripeService do
  @moduledoc """
  Service for interacting with Stripe API.
  """

  @doc """
  Creates a Stripe checkout session for upgrading to a tier.
  """
  def create_checkout_session(user, tier) do
    stripe_config = Application.get_env(:frestyl, :stripe)

    price_id = case tier do
      "professional" -> stripe_config[:professional_price_id]
      "business" -> stripe_config[:business_price_id]
      _ -> nil
    end

    if price_id do
      params = %{
        success_url: "#{get_base_url()}/account/subscription?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{get_base_url()}/account/subscription",
        payment_method_types: ["card"],
        mode: "subscription",
        customer_email: user.email,
        client_reference_id: user.id,
        line_items: [
          %{
            price: price_id,
            quantity: 1
          }
        ],
        metadata: %{
          user_id: user.id,
          tier: tier
        }
      }

      case Stripe.Checkout.Session.create(params) do
        {:ok, session} -> {:ok, session}
        {:error, error} -> {:error, error.message}
      end
    else
      {:error, "Invalid subscription tier"}
    end
  end

  @doc """
  Retrieves a Stripe subscription.
  """
  def retrieve_subscription(subscription_id) do
    case Stripe.Subscription.retrieve(subscription_id) do
      {:ok, subscription} -> {:ok, subscription}
      {:error, error} -> {:error, error.message}
    end
  end

  @doc """
  Cancels a Stripe subscription.
  """
  def cancel_subscription(subscription_id) do
    case Stripe.Subscription.delete(subscription_id) do
      {:ok, subscription} -> {:ok, subscription}
      {:error, error} -> {:error, error.message}
    end
  end

  @doc """
  Creates or retrieves a Stripe customer.
  """
  def get_or_create_customer(user) do
    if user.stripe_customer_id do
      case Stripe.Customer.retrieve(user.stripe_customer_id) do
        {:ok, customer} -> {:ok, customer}
        {:error, _} -> create_customer(user)
      end
    else
      create_customer(user)
    end
  end

  defp create_customer(user) do
    params = %{
      email: user.email,
      name: user.name,
      metadata: %{
        user_id: user.id
      }
    }

    case Stripe.Customer.create(params) do
      {:ok, customer} ->
        # Update user with Stripe customer ID
        Frestyl.Accounts.update_user(user, %{stripe_customer_id: customer.id})
        {:ok, customer}
      {:error, error} -> {:error, error.message}
    end
  end

  defp get_base_url do
    FrestylWeb.Endpoint.url()
  end
end
