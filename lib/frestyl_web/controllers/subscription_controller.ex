# lib/frestyl_web/controllers/subscription_controller.ex
defmodule FrestylWeb.SubscriptionController do
  use FrestylWeb, :controller
  alias Frestyl.Payments
  alias Frestyl.Accounts

  def index(conn, _params) do
    plans = Payments.list_subscription_plans()
    current_user = conn.assigns.current_user
    user_subscription = Payments.get_user_active_subscription(current_user.id)

    render(conn, :index, plans: plans, user_subscription: user_subscription)
  end

  def new(conn, %{"plan_id" => plan_id}) do
    plan = Payments.get_subscription_plan!(plan_id)
    current_user = conn.assigns.current_user

    render(conn, :new, plan: plan, current_user: current_user)
  end

  def create(conn, %{"payment_method_id" => payment_method_id, "plan_id" => plan_id, "is_yearly" => is_yearly}) do
    is_yearly = is_yearly == "true"
    current_user = conn.assigns.current_user

    case Payments.create_user_subscription(current_user, plan_id, payment_method_id, is_yearly) do
      {:ok, subscription} ->
        conn
        |> put_flash(:info, "Subscription created successfully.")
        |> redirect(to: ~p"/account/subscription")

      {:error, %Ecto.Changeset{} = changeset} ->
        plan = Payments.get_subscription_plan!(plan_id)
        render(conn, :new, plan: plan, current_user: current_user, changeset: changeset)
    end
  end

  def cancel(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    subscription = Payments.get_user_subscription!(id)

    if subscription.user_id != current_user.id do
      conn
      |> put_flash(:error, "Unauthorized action")
      |> redirect(to: ~p"/account/subscription")
    else
      case Payments.cancel_subscription(id) do
        {:ok, _subscription} ->
          conn
          |> put_flash(:info, "Subscription has been canceled and will end at the current billing period.")
          |> redirect(to: ~p"/account/subscription")

        {:error, _reason} ->
          conn
          |> put_flash(:error, "There was a problem canceling your subscription. Please try again.")
          |> redirect(to: ~p"/account/subscription")
      end
    end
  end
end
