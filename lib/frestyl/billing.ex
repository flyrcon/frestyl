# lib/frestyl/billing.ex
defmodule Frestyl.Billing do
  @moduledoc """
  The Billing context for managing subscriptions and payments.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Accounts.User
  alias Frestyl.Billing.{Subscription, StripeService}

  @doc """
  Gets the current subscription for a user.
  """
  def get_user_subscription(user_id) do
    from(s in Subscription,
      where: s.user_id == ^user_id and s.status in ["active", "trialing", "past_due"],
      order_by: [desc: s.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Creates a new subscription.
  """
  def create_subscription(attrs \\ %{}) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a subscription.
  """
  def update_subscription(%Subscription{} = subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Cancels a user's subscription.
  """
  def cancel_subscription(user_id) do
    with subscription when not is_nil(subscription) <- get_user_subscription(user_id),
         {:ok, _stripe_subscription} <- StripeService.cancel_subscription(subscription.stripe_subscription_id),
         {:ok, updated_subscription} <- update_subscription(subscription, %{status: "canceled", canceled_at: DateTime.utc_now()}) do

      # Update user's subscription tier
      user = Repo.get!(User, user_id)
      Frestyl.Accounts.update_user(user, %{subscription_tier: "storyteller"})

      {:ok, updated_subscription}
    else
      nil -> {:error, "No active subscription found"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Handles Stripe webhook events.
  """
  def handle_stripe_webhook(event) do
    case event.type do
      "checkout.session.completed" ->
        handle_checkout_completed(event.data.object)

      "invoice.payment_succeeded" ->
        handle_payment_succeeded(event.data.object)

      "customer.subscription.updated" ->
        handle_subscription_updated(event.data.object)

      "customer.subscription.deleted" ->
        handle_subscription_deleted(event.data.object)

      _ ->
        {:ok, :ignored}
    end
  end

  defp handle_checkout_completed(session) do
    with {:ok, subscription_data} <- StripeService.retrieve_subscription(session.subscription),
         tier <- determine_tier_from_price_id(subscription_data.items.data |> List.first() |> Map.get(:price) |> Map.get(:id)),
         user when not is_nil(user) <- Repo.get_by(User, stripe_customer_id: session.customer) do

      # Create or update subscription record
      subscription_attrs = %{
        user_id: user.id,
        stripe_subscription_id: subscription_data.id,
        stripe_customer_id: session.customer,
        status: subscription_data.status,
        current_period_start: DateTime.from_unix!(subscription_data.current_period_start),
        current_period_end: DateTime.from_unix!(subscription_data.current_period_end),
        tier: tier
      }

      case get_user_subscription(user.id) do
        nil ->
          create_subscription(subscription_attrs)
        existing_sub ->
          update_subscription(existing_sub, subscription_attrs)
      end

      # Update user's subscription tier
      Frestyl.Accounts.update_user(user, %{subscription_tier: tier})

      {:ok, :processed}
    else
      _ -> {:error, "Failed to process checkout completion"}
    end
  end

  defp handle_payment_succeeded(invoice) do
    # Update subscription status and period
    with subscription when not is_nil(subscription) <- Repo.get_by(Subscription, stripe_subscription_id: invoice.subscription) do
      update_subscription(subscription, %{
        status: "active",
        current_period_start: DateTime.from_unix!(invoice.period_start),
        current_period_end: DateTime.from_unix!(invoice.period_end)
      })
    end

    {:ok, :processed}
  end

  defp handle_subscription_updated(stripe_subscription) do
    with subscription when not is_nil(subscription) <- Repo.get_by(Subscription, stripe_subscription_id: stripe_subscription.id) do
      tier = determine_tier_from_price_id(stripe_subscription.items.data |> List.first() |> Map.get(:price) |> Map.get(:id))

      update_subscription(subscription, %{
        status: stripe_subscription.status,
        current_period_start: DateTime.from_unix!(stripe_subscription.current_period_start),
        current_period_end: DateTime.from_unix!(stripe_subscription.current_period_end),
        tier: tier
      })

      # Update user's tier
      user = Repo.get!(User, subscription.user_id)
      Frestyl.Accounts.update_user(user, %{subscription_tier: tier})
    end

    {:ok, :processed}
  end

  defp handle_subscription_deleted(stripe_subscription) do
    with subscription when not is_nil(subscription) <- Repo.get_by(Subscription, stripe_subscription_id: stripe_subscription.id) do
      update_subscription(subscription, %{status: "canceled", canceled_at: DateTime.utc_now()})

      # Downgrade user to free tier
      user = Repo.get!(User, subscription.user_id)
      Frestyl.Accounts.update_user(user, %{subscription_tier: "storyteller"})
    end

    {:ok, :processed}
  end

  defp determine_tier_from_price_id(price_id) do
    stripe_config = Application.get_env(:frestyl, :stripe)

    cond do
      price_id == stripe_config[:professional_price_id] -> "professional"
      price_id == stripe_config[:business_price_id] -> "business"
      true -> "storyteller"
    end
  end
end
