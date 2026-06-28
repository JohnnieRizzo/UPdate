defmodule GratefulSetCrew.Payments do
  @moduledoc """
  The Payments context.
  """

  import Ecto.Query, warn: false
  alias GratefulSetCrew.Repo
  alias GratefulSetCrew.Payments.StripeAccount
  alias GratefulSetCrew.Jobs

  @doc """
  Returns the Stripe account for a user.
  """
  def get_stripe_account(user_id) do
    Repo.get_by(StripeAccount, user_id: user_id)
  end

  @doc """
  Gets a single Stripe account, raising an error if not found.
  """
  def get_stripe_account!(user_id) do
    Repo.get_by!(StripeAccount, user_id: user_id)
  end

  @doc """
  Creates a Stripe account record.
  """
  def create_stripe_account(attrs \\ %{}) do
    %StripeAccount{}
    |> StripeAccount.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a Stripe account.
  """
  def update_stripe_account(%StripeAccount{} = stripe_account, attrs) do
    stripe_account
    |> StripeAccount.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Checks if a user has a connected Stripe account with charges enabled.
  """
  def has_charges_enabled?(user_id) do
    case get_stripe_account(user_id) do
      %StripeAccount{charges_enabled: true} -> true
      _ -> false
    end
  end

  @doc """
  Checks if a user has a connected Stripe account with payouts enabled.
  """
  def has_payouts_enabled?(user_id) do
    case get_stripe_account(user_id) do
      %StripeAccount{payouts_enabled: true} -> true
      _ -> false
    end
  end

  @doc """
  Creates a Stripe Connect account for a crew member.
  """
  def create_crew_connect_account(user) do
    with {:ok, stripe_account} <- Stripe.Account.create(%{type: "express", email: user.email}) do
      case create_stripe_account(%{
        user_id: user.id,
        stripe_account_id: stripe_account.id,
        charges_enabled: false,
        payouts_enabled: false,
        onboarding_completed: false
      }) do
        {:ok, account} -> {:ok, account}
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Creates an onboarding link for Stripe Connect account.
  """
  def create_onboarding_link(stripe_account_id, return_url) do
    Stripe.AccountLink.create(%{
      account: stripe_account_id,
      type: "account_onboarding",
      return_url: return_url,
      refresh_url: return_url
    })
  end

  @doc """
  Creates a payment intent for a job.
  Calculates 20% platform fee and transfers 80% to crew's Stripe account.
  """
  def create_payment_intent(job, amount) when is_integer(amount) and amount > 0 do
    # Calculate platform fee (20%)
    platform_fee = round(amount * 0.20)

    # Get crew's Stripe account ID
    case get_stripe_account(job.crew_id) do
      %StripeAccount{stripe_account_id: stripe_account_id} when not is_nil(stripe_account_id) ->
        Stripe.PaymentIntent.create(%{
          amount: amount,
          currency: "usd",
          application_fee_amount: platform_fee,
          transfer_data: %{
            destination: stripe_account_id
          },
          metadata: %{
            job_id: job.id,
            client_id: job.client_id,
            crew_id: job.crew_id
          }
        })

      _ ->
        {:error, "Crew member has no connected Stripe account"}
    end
  end

  def create_payment_intent(_job, _amount) do
    {:error, "Invalid amount"}
  end

  @doc """
  Handles a successful payment webhook from Stripe.
  Updates the job's payment_status to "completed".
  """
  def handle_payment_succeeded(_payment_intent_id, metadata) do
    case metadata && Map.get(metadata, "job_id") do
      job_id when not is_nil(job_id) ->
        case Jobs.get_job!(job_id) do
          %{} = job ->
            case Jobs.update_job(job, %{payment_status: "completed"}) do
              {:ok, _job} -> {:ok, :payment_processed}
              {:error, reason} -> {:error, reason}
            end

          nil ->
            {:error, :job_not_found}
        end

      _ ->
        {:error, :invalid_metadata}
    end
  rescue
    _e in Ecto.NoResultsError -> {:error, :job_not_found}
  end

  @doc """
  Handles a successful account update webhook from Stripe.
  """
  def handle_account_updated(stripe_account_id, charges_enabled, payouts_enabled) do
    case Repo.get_by(StripeAccount, stripe_account_id: stripe_account_id) do
      %StripeAccount{} = stripe_account ->
        update_stripe_account(stripe_account, %{
          charges_enabled: charges_enabled,
          payouts_enabled: payouts_enabled,
          onboarding_completed: charges_enabled and payouts_enabled
        })
      nil ->
        {:error, :stripe_account_not_found}
    end
  end
end
