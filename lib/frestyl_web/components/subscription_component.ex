defmodule FrestylWeb.SubscriptionComponent do
  use Phoenix.Component
  alias FrestylWeb.CoreComponents

  import Frestyl.Payments
  import FrestylWeb.Auth

  attr :plan, :map, required: true
  attr :billing_period, :string, default: "monthly"
  attr :is_current, :boolean, default: false
  def plan_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-md p-6 border border-gray-200 hover:shadow-lg transition-shadow">
      <div class="flex flex-col h-full">
        <div class="mb-4">
          <h3 class="text-xl font-bold text-gray-900"><%= @plan.name %></h3>
          <div class="mt-2 flex items-baseline">
            <span class="text-3xl font-bold tracking-tight text-gray-900">
              $<%= format_price(@plan, @billing_period) %>
            </span>
            <span class="ml-1 text-sm font-medium text-gray-500">/<%= @billing_period %></span>
          </div>
          <p class="mt-4 text-sm text-gray-500"><%= @plan.description %></p>
        </div>

        <div class="mt-2 flex-grow">
          <ul class="space-y-3">
            <%= for feature <- @plan.features do %>
              <li class="flex items-start">
                <span class="flex-shrink-0 h-5 w-5 text-green-500">
                  <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                </span>
                <span class="ml-3 text-sm text-gray-700"><%= feature %></span>
              </li>
            <% end %>
          </ul>
        </div>

        <div class="mt-6">
          <%= if @is_current do %>
            <div class="w-full bg-green-100 text-green-800 py-2 px-4 rounded-md text-center font-medium">
              Current Plan
            </div>
          <% else %>
            <a href={~p"/subscriptions/new/#{@plan.id}"} class="block w-full bg-brand hover:bg-brand-dark text-white py-2 px-4 rounded-md text-center font-medium">
              Subscribe
            </a>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :plan, :map, required: true
  def payment_form(assigns) do
    ~H"""
    <div class="mt-8">
      <h2 class="text-lg font-medium text-gray-900">Payment Method</h2>

      <div class="mt-4" id="payment-form" phx-hook="StripePaymentForm" data-public-key={stripe_public_key()}>
        <div class="bg-white rounded-md shadow-sm p-6 border border-gray-300">
          <div class="mb-4">
            <label for="card-element" class="block text-sm font-medium text-gray-700">Credit or debit card</label>
            <div id="card-element" class="mt-1 p-3 border border-gray-300 rounded-md"></div>
            <div id="card-errors" class="mt-2 text-sm text-red-600" role="alert"></div>
          </div>

          <div class="mt-4">
            <label class="inline-flex items-center">
              <input type="radio" name="billing_period" value="monthly" checked class="form-radio h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500">
              <span class="ml-2 text-gray-700">Monthly - $<%= format_price(@plan, "monthly") %>/month</span>
            </label>
          </div>

          <div class="mt-2">
            <label class="inline-flex items-center">
              <input type="radio" name="billing_period" value="yearly" class="form-radio h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500">
              <span class="ml-2 text-gray-700">
                Yearly - $<%= format_price(@plan, "yearly") %>/year
                <span class="ml-2 text-sm text-green-600 font-medium">
                  Save <%= calculate_yearly_savings(@plan) %>%
                </span>
              </span>
            </label>
          </div>

          <input type="hidden" id="payment_method_id" name="payment_method_id" value="">
          <input type="hidden" id="plan_id" name="plan_id" value={@plan.id}>

          <div class="mt-6">
            <button id="submit-payment" type="button" class="w-full bg-brand hover:bg-brand-dark text-white py-2 px-4 rounded-md font-medium">
              Subscribe Now
            </button>
          </div>
        </div>
      </div>

      <div class="mt-4 text-sm text-gray-500">
        <p>
          By subscribing, you agree to our Terms of Service and Privacy Policy.
          You can cancel your subscription at any time from your account settings.
        </p>
      </div>
    </div>
    """
  end

  attr :ticket_types, :list, required: true
  def ticket_purchase_form(assigns) do
    ~H"""
    <div class="mt-8">
      <h2 class="text-lg font-medium text-gray-900">Purchase Tickets</h2>

      <div class="mt-4 space-y-4">
        <%= for ticket_type <- @ticket_types do %>
          <div class="bg-white rounded-md shadow-sm p-6 border border-gray-300">
            <div class="flex justify-between">
              <div>
                <h3 class="text-lg font-medium text-gray-900"><%= ticket_type.name %></h3>
                <p class="text-sm text-gray-500"><%= ticket_type.description %></p>
              </div>
              <div class="text-right">
                <div class="text-xl font-bold text-gray-900">
                  $<%= format_cents(ticket_type.price_cents) %>
                </div>
                <%= if ticket_type.quantity_available && ticket_type.quantity_available > 0 do %>
                  <div class="text-sm text-gray-500">
                    <%= ticket_type.quantity_available - ticket_type.quantity_sold %> remaining
                  </div>
                <% end %>
              </div>
            </div>

            <div class="mt-4 flex items-end justify-between">
              <div class="w-1/3">
                <label for={"quantity-#{ticket_type.id}"} class="block text-sm font-medium text-gray-700">Quantity</label>
                <select id={"quantity-#{ticket_type.id}"} name={"quantity-#{ticket_type.id}"} class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md">
                  <%= for i <- 1..10 do %>
                    <option value={i}><%= i %></option>
                  <% end %>
                </select>
              </div>

              <button
                phx-click="purchase-ticket"
                phx-value-ticket-type-id={ticket_type.id}
                class="bg-brand hover:bg-brand-dark text-white py-2 px-4 rounded-md font-medium"
              >
                Buy Tickets
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_price(plan, "monthly"), do: div(plan.price_monthly_cents, 100)
  defp format_price(plan, "yearly"), do: (plan.price_yearly_cents / 100 / 12) |> Float.round(2)

  defp format_cents(cents), do: (cents / 100) |> Float.round(2)

  defp calculate_yearly_savings(plan) do
    monthly_yearly = plan.price_monthly_cents * 12
    yearly = plan.price_yearly_cents

    savings_percentage = (monthly_yearly - yearly) / monthly_yearly * 100
    trunc(savings_percentage)
  end

  defp stripe_public_key, do: Application.get_env(:frestyl, :stripe_public_key)
end
