defmodule GratefulSetCrewWeb.StripeWebhookController do
  use GratefulSetCrewWeb, :controller

  require Logger

  alias GratefulSetCrew.Payments

  @doc """
  Handle Stripe webhook events.
  """
  def handle(conn, _params) do
    with {:ok, body, _conn} <- Plug.Conn.read_body(conn),
         {:ok, event} <- verify_stripe_signature(body, conn),
         :ok <- process_event(event) do
      send_resp(conn, 200, "")
    else
      {:error, reason} ->
        Logger.error("Stripe webhook error: #{inspect(reason)}")
        send_resp(conn, 400, "")
    end
  end

  defp verify_stripe_signature(body, conn) do
    # Get the Stripe signature header
    case Plug.Conn.get_req_header(conn, "stripe-signature") do
      [signature] ->
        # Get webhook secret from config
        webhook_secret = Application.get_env(:stripity_stripe, :webhook_secret)

        case Stripe.Webhook.construct_event(body, signature, webhook_secret) do
          {:ok, event} -> {:ok, event}
          {:error, reason} -> {:error, "Webhook signature verification failed: #{inspect(reason)}"}
        end

      _ ->
        {:error, "Missing Stripe-Signature header"}
    end
  end

  defp process_event(%{"type" => "payment_intent.succeeded", "data" => %{"object" => payment_intent}}) do
    Logger.info("Processing payment_intent.succeeded: #{inspect(payment_intent)}")
    Payments.handle_payment_succeeded(
      payment_intent["id"],
      payment_intent["metadata"]
    )
    :ok
  end

  defp process_event(%{"type" => "account.updated", "data" => %{"object" => account}}) do
    Logger.info("Processing account.updated: #{inspect(account)}")
    Payments.handle_account_updated(
      account["id"],
      account["charges_enabled"],
      account["payouts_enabled"]
    )
    :ok
  end

  defp process_event(event) do
    Logger.info("Ignoring unhandled event type: #{event["type"]}")
    :ok
  end
end
