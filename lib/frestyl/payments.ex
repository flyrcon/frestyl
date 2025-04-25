# lib/frestyl/payments.ex
defmodule Frestyl.Payments do
  @moduledoc """
  The Payments context: handles subscriptions, ticket purchases, and payment processing.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Payments.{SubscriptionPlan, UserSubscription, TicketType,
                          TicketPurchase, Payout, RevenueReport}
  alias Frestyl.Accounts.User
  alias Frestyl.Events.Event

  @doc """
  Returns the list of subscription plans.
  """
  def list_subscription_plans do
    Repo.all(from p in SubscriptionPlan, where: p.is_active == true, order_by: p.price_monthly_cents)
  end

  @doc """
  Gets a single subscription_plan.
  """
  def get_subscription_plan!(id), do: Repo.get!(SubscriptionPlan, id)

  @doc """
  Creates a subscription_plan.
  """
  def create_subscription_plan(attrs \\ %{}) do
    %SubscriptionPlan{}
    |> SubscriptionPlan.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a subscription_plan.
  """
  def update_subscription_plan(%SubscriptionPlan{} = subscription_plan, attrs) do
    subscription_plan
    |> SubscriptionPlan.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a user subscription and initializes it with Stripe.
  """
  def create_user_subscription(user, subscription_plan_id, payment_method_id, is_yearly \\ false) do
    with %User{} = user <- Repo.get(User, user.id),
         %SubscriptionPlan{} = plan <- Repo.get(SubscriptionPlan, subscription_plan_id) do

      # Get or create Stripe customer
      {:ok, stripe_customer_id} = ensure_stripe_customer(user)

      # Attach payment method to customer
      :ok = Stripe.PaymentMethod.attach(%{
        payment_method: payment_method_id,
        customer: stripe_customer_id
      })

      # Set as default payment method
      Stripe.Customer.update(stripe_customer_id, %{
        invoice_settings: %{default_payment_method: payment_method_id}
      })

      # Create subscription in Stripe
      stripe_price_id = if is_yearly, do: plan.stripe_price_id_yearly, else: plan.stripe_price_id_monthly

      {:ok, stripe_subscription} = Stripe.Subscription.create(%{
        customer: stripe_customer_id,
        items: [%{price: stripe_price_id}],
        expand: ["latest_invoice.payment_intent"]
      })

      # Create subscription record in database
      attrs = %{
        user_id: user.id,
        subscription_plan_id: plan.id,
        stripe_subscription_id: stripe_subscription.id,
        stripe_customer_id: stripe_customer_id,
        current_period_start: DateTime.from_unix!(stripe_subscription.current_period_start),
        current_period_end: DateTime.from_unix!(stripe_subscription.current_period_end),
        status: stripe_subscription.status,
        payment_method_id: payment_method_id,
        is_yearly: is_yearly,
        auto_renew: true
      }

      %UserSubscription{}
      |> UserSubscription.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Cancels a user subscription.
  """
  def cancel_subscription(subscription_id) do
    subscription = Repo.get!(UserSubscription, subscription_id)

    {:ok, stripe_sub} = Stripe.Subscription.update(
      subscription.stripe_subscription_id,
      %{cancel_at_period_end: true}
    )

    subscription
    |> UserSubscription.changeset(%{
      auto_renew: false,
      canceled_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Creates a ticket purchase checkout session.
  """
  def create_ticket_purchase_session(user_id, ticket_type_id, quantity) do
    with %User{} = user <- Repo.get(User, user_id),
         %TicketType{} = ticket_type <- Repo.get(TicketType, ticket_type_id) |> Repo.preload(:event) do

      # Ensure we have availability
      if ticket_type.quantity_available != nil &&
         ticket_type.quantity_sold + quantity > ticket_type.quantity_available do
        {:error, :insufficient_tickets}
      else
        # Get or create Stripe customer
        {:ok, stripe_customer_id} = ensure_stripe_customer(user)

        # Calculate amounts
        total_amount_cents = ticket_type.price_cents * quantity

        # Get organizer subscription to determine platform fee
        organizer = Repo.get!(User, ticket_type.event.user_id)
        organizer_subscription = get_active_subscription(organizer.id)
        fee_percentage = if organizer_subscription,
          do: organizer_subscription.subscription_plan.platform_fee_percentage,
          else: Decimal.new("10.00")  # Default 10% fee for free tier

        platform_fee_cents = Decimal.mult(
          Decimal.div(fee_percentage, Decimal.new("100")),
          Decimal.new(total_amount_cents)
        ) |> Decimal.to_integer()

        # Create confirmation code
        confirmation_code = generate_confirmation_code()

        # Create pending purchase record
        {:ok, purchase} = %TicketPurchase{}
          |> TicketPurchase.changeset(%{
            user_id: user.id,
            ticket_type_id: ticket_type.id,
            event_id: ticket_type.event.id,
            quantity: quantity,
            total_amount_cents: total_amount_cents,
            platform_fee_cents: platform_fee_cents,
            payment_status: "pending",
            confirmation_code: confirmation_code
          })
          |> Repo.insert()

        # Create Stripe Checkout Session
        success_url = "#{FrestylWeb.Endpoint.url()}/events/#{ticket_type.event.id}/tickets/success?session_id={CHECKOUT_SESSION_ID}"
        cancel_url = "#{FrestylWeb.Endpoint.url()}/events/#{ticket_type.event.id}"

        session_params = %{
          customer: stripe_customer_id,
          payment_method_types: ["card"],
          line_items: [
            %{
              price: ticket_type.stripe_price_id,
              quantity: quantity
            }
          ],
          mode: "payment",
          success_url: success_url,
          cancel_url: cancel_url,
          client_reference_id: purchase.id,
          metadata: %{
            purchase_id: purchase.id,
            event_id: ticket_type.event.id,
            ticket_type_id: ticket_type.id,
            confirmation_code: confirmation_code
          }
        }

        with {:ok, session} <- Stripe.Session.create(session_params) do
          # Update purchase with session ID
          purchase
          |> TicketPurchase.changeset(%{stripe_checkout_session_id: session.id})
          |> Repo.update()

          {:ok, %{session_id: session.id, purchase: purchase}}
        end
      end
    end
  end

  # More helper functions would be implemented here...

  # Get user's active subscription with plan details
  defp get_active_subscription(user_id) do
    query = from s in UserSubscription,
            where: s.user_id == ^user_id and s.status == "active",
            preload: [:subscription_plan],
            limit: 1
    Repo.one(query)
  end

  # Ensure user has a Stripe customer ID
  defp ensure_stripe_customer(user) do
    case Repo.one(from s in UserSubscription, where: s.user_id == ^user.id, select: s.stripe_customer_id, limit: 1) do
      nil ->
        # Create new Stripe customer
        {:ok, customer} = Stripe.Customer.create(%{
          email: user.email,
          name: "#{user.first_name} #{user.last_name}",
          metadata: %{
            user_id: user.id
          }
        })
        {:ok, customer.id}
      stripe_customer_id ->
        {:ok, stripe_customer_id}
    end
  end

  # Generate a unique confirmation code for tickets
  defp generate_confirmation_code do
    code = :crypto.strong_rand_bytes(8) |> Base.encode32() |> binary_part(0, 8)

    # Check for collisions
    case Repo.one(from p in TicketPurchase, where: p.confirmation_code == ^code, limit: 1) do
      nil -> code
      _purchase -> generate_confirmation_code() # Recursively try again
    end
  end
end
