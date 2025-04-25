# lib/frestyl_web/controllers/ticket_controller.ex
defmodule FrestylWeb.TicketController do
  use FrestylWeb, :controller
  alias Frestyl.Payments
  alias Frestyl.Events

  def buy(conn, %{"event_id" => event_id}) do
    event = Events.get_event!(event_id)
    ticket_types = Payments.list_event_ticket_types(event_id)

    render(conn, :buy, event: event, ticket_types: ticket_types)
  end

  def create_checkout(conn, %{"ticket_type_id" => ticket_type_id, "quantity" => quantity}) do
    quantity = String.to_integer(quantity)
    current_user = conn.assigns.current_user

    case Payments.create_ticket_purchase_session(current_user.id, ticket_type_id, quantity) do
      {:ok, %{session_id: session_id}} ->
        json(conn, %{sessionId: session_id})

      {:error, :insufficient_tickets} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Not enough tickets available"})

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Could not process ticket purchase"})
    end
  end

  def success(conn, %{"event_id" => event_id, "session_id" => session_id}) do
    current_user = conn.assigns.current_user

    case Payments.confirm_ticket_purchase(session_id, current_user.id) do
      {:ok, purchase} ->
        event = Events.get_event!(event_id)

        conn
        |> put_flash(:info, "Ticket purchase successful! Confirmation code: #{purchase.confirmation_code}")
        |> render(:confirmation, purchase: purchase, event: event)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "There was a problem confirming your purchase. Please contact support.")
        |> redirect(to: ~p"/events/#{event_id}")
    end
  end

  def my_tickets(conn, _params) do
    current_user = conn.assigns.current_user
    tickets = Payments.list_user_ticket_purchases(current_user.id)

    render(conn, :my_tickets, tickets: tickets)
  end
end
