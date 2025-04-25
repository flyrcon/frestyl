# lib/frestyl_web/live/event_live/payment_component.ex
defmodule FrestylWeb.EventLive.PaymentComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Events

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"payment-form-#{@event.id}"}>
      <h3 class="text-lg font-semibold mb-4">Payment Required</h3>
      <p class="mb-4">
        This event requires a payment of <%= format_price(@event.price_in_cents) %> to attend.
      </p>

      <div class="border rounded p-4 mb-4">
        <h4 class="font-semibold mb-2">Payment Details</h4>

        <.simple_form for={@form} phx-submit="process_payment" phx-target={@myself}>
          <.input field={@form[:card_number]} type="text" label="Card Number" placeholder="4242 4242 4242 4242" />
          <div class="flex space-x-4">
            <div class="w-1/2">
              <.input field={@form[:expiry]} type="text" label="Expiry (MM/YY)" placeholder="12/25" />
            </div>
            <div class="w-1/2">
              <.input field={@form[:cvc]} type="text" label="CVC" placeholder="123" />
            </div>
          </div>
          <.input field={@form[:name]} type="text" label="Name on Card" />

          <:actions>
            <.button phx-disable-with="Processing..." class="w-full">
              Pay <%= format_price(@event.price_in_cents) %>
            </.button>
          </:actions>
        </.simple_form>
      </div>

      <p class="text-sm text-gray-500">
        Note: This is a demonstration form and no actual charges will be made.
      </p>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = payment_changeset(%{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("process_payment", %{"payment" => payment_params}, socket) do
    # In a real application, you would integrate with a payment processor like Stripe here
    # For demonstration purposes, we'll simulate a successful payment

    event = socket.assigns.event
    attendee = socket.assigns.attendee

    # Process the payment (simulated)
    case simulate_payment_processing(payment_params, event.price_in_cents) do
      :ok ->
        # Update attendee payment status
        {:ok, updated_attendee} = Events.update_payment_status(
          attendee,
          :completed,
          event.price_in_cents
        )

        # Admit the attendee
        {:ok, admitted_attendee} = Events.admit_attendee(updated_attendee)

        # Send payment confirmation email (in a real app)
        # EventNotifications.send_payment_confirmation(event, admitted_attendee)

        send(self(), {:payment_processed, admitted_attendee})

        {:noreply,
         socket
         |> put_flash(:info, "Payment processed successfully. You are now registered for the event.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Payment failed: #{reason}")
         |> assign_form(payment_changeset(payment_params))}
    end
  end

  defp payment_changeset(attrs) do
    types = %{
      card_number: :string,
      expiry: :string,
      cvc: :string,
      name: :string
    }

    {%{}, types}
    |> Ecto.Changeset.cast(attrs, Map.keys(types))
    |> Ecto.Changeset.validate_required([:card_number, :expiry, :cvc, :name])
    |> Ecto.Changeset.validate_format(:card_number, ~r/^\d{16}$/, message: "must be 16 digits")
    |> Ecto.Changeset.validate_format(:expiry, ~r/^\d{2}\/\d{2}$/, message: "must be in format MM/YY")
    |> Ecto.Changeset.validate_format(:cvc, ~r/^\d{3,4}$/, message: "must be 3 or 4 digits")
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :payment))
  end

  # Simulate payment processing (in a real app, you would integrate with a payment processor)
  defp simulate_payment_processing(params, _amount) do
    # Check for test card number
    if params["card_number"] == "4242424242424242" do
      :ok
    else
      {:error, "Invalid test card. Use 4242424242424242 for testing."}
    end
  end
end
