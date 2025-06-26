defmodule FrestylWeb.StripeWebhookController do
  use FrestylWeb, :controller

  alias Frestyl.Billing

  def handle(conn, _params) do
    stripe_config = Application.get_env(:frestyl, :stripe)

    with {:ok, body} <- read_request_body(conn),  # <- Changed function name
         sig_header <- get_req_header(conn, "stripe-signature") |> List.first(),
         {:ok, event} <- Stripe.Webhook.construct_event(body, sig_header, stripe_config[:webhook_secret]) do

      case Billing.handle_stripe_webhook(event) do
        {:ok, _} ->
          conn |> put_status(200) |> json(%{status: "success"})
        {:error, reason} ->
          conn |> put_status(400) |> json(%{error: reason})
      end
    else
      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: reason})
    end
  end

  defp read_request_body(conn) do  # <- Renamed function
    case Plug.Conn.read_body(conn) do
      {:ok, body, _conn} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end
end
