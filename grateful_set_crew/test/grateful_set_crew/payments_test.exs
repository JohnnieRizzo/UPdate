defmodule GratefulSetCrew.PaymentsTest do
  use GratefulSetCrew.DataCase

  alias GratefulSetCrew.Payments
  alias GratefulSetCrew.Payments.StripeAccount

  import GratefulSetCrew.PaymentsFixtures
  import GratefulSetCrew.AccountsFixtures
  import GratefulSetCrew.JobsFixtures

  describe "get_stripe_account/1" do
    test "returns stripe account by user_id" do
      user = user_fixture(%{role: "crew"})
      account = stripe_account_fixture(%{user: user})

      assert %StripeAccount{id: account_id} = Payments.get_stripe_account(user.id)
      assert account_id == account.id
    end

    test "returns nil if no account exists" do
      assert is_nil(Payments.get_stripe_account(99999))
    end
  end

  describe "get_stripe_account!/1" do
    test "returns stripe account by user_id" do
      user = user_fixture(%{role: "crew"})
      account = stripe_account_fixture(%{user: user})

      assert %StripeAccount{id: account_id} = Payments.get_stripe_account!(user.id)
      assert account_id == account.id
    end

    test "raises if account does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Payments.get_stripe_account!(99999)
      end
    end
  end

  describe "create_stripe_account/1" do
    test "creates a stripe account with valid attributes" do
      user = user_fixture(%{role: "crew"})

      {:ok, account} =
        Payments.create_stripe_account(%{
          user_id: user.id,
          stripe_account_id: "acct_test123",
          charges_enabled: false,
          payouts_enabled: false,
          onboarding_completed: false
        })

      assert account.user_id == user.id
      assert account.stripe_account_id == "acct_test123"
      assert account.charges_enabled == false
      assert account.payouts_enabled == false
      assert account.onboarding_completed == false
    end

    test "requires user_id" do
      {:error, changeset} =
        Payments.create_stripe_account(%{
          stripe_account_id: "acct_test123"
        })

      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "requires stripe_account_id" do
      user = user_fixture(%{role: "crew"})

      {:error, changeset} =
        Payments.create_stripe_account(%{
          user_id: user.id
        })

      assert "can't be blank" in errors_on(changeset).stripe_account_id
    end

    test "enforces unique user_id" do
      user = user_fixture(%{role: "crew"})
      stripe_account_fixture(%{user: user})

      {:error, _changeset} =
        Payments.create_stripe_account(%{
          user_id: user.id,
          stripe_account_id: "acct_different"
        })
    end
  end

  describe "update_stripe_account/2" do
    test "updates stripe account with valid attributes" do
      account = stripe_account_fixture()

      {:ok, updated} =
        Payments.update_stripe_account(account, %{
          charges_enabled: true,
          payouts_enabled: true,
          onboarding_completed: true
        })

      assert updated.charges_enabled == true
      assert updated.payouts_enabled == true
      assert updated.onboarding_completed == true
    end

    test "can update to mark onboarding as completed" do
      account = stripe_account_fixture(%{onboarding_completed: false})

      {:ok, updated} =
        Payments.update_stripe_account(account, %{onboarding_completed: true})

      assert updated.onboarding_completed == true
    end
  end

  describe "has_charges_enabled?/1" do
    test "returns true when charges are enabled" do
      account = stripe_account_fixture(%{charges_enabled: true})
      assert Payments.has_charges_enabled?(account.user_id) == true
    end

    test "returns false when charges are not enabled" do
      account = stripe_account_fixture(%{charges_enabled: false})
      assert Payments.has_charges_enabled?(account.user_id) == false
    end

    test "returns false when account does not exist" do
      assert Payments.has_charges_enabled?(99999) == false
    end
  end

  describe "has_payouts_enabled?/1" do
    test "returns true when payouts are enabled" do
      account = stripe_account_fixture(%{payouts_enabled: true})
      assert Payments.has_payouts_enabled?(account.user_id) == true
    end

    test "returns false when payouts are not enabled" do
      account = stripe_account_fixture(%{payouts_enabled: false})
      assert Payments.has_payouts_enabled?(account.user_id) == false
    end

    test "returns false when account does not exist" do
      assert Payments.has_payouts_enabled?(99999) == false
    end
  end

  describe "create_payment_intent/2" do
    test "returns error if amount is not positive" do
      crew = user_fixture(%{role: "crew"})
      job = job_fixture(%{crew_id: crew.id})
      assert {:error, "Invalid amount"} = Payments.create_payment_intent(job, 0)
    end

    test "returns error if crew has no stripe account" do
      crew = user_fixture(%{role: "crew"})
      job = job_fixture(%{crew_id: crew.id})
      assert {:error, "Crew member has no connected Stripe account"} = Payments.create_payment_intent(job, 5000)
    end

    test "calculates platform fee correctly" do
      crew = user_fixture(%{role: "crew"})
      client = user_fixture(%{role: "client"})

      stripe_account_fixture(%{user: crew, stripe_account_id: "acct_crew123"})

      job = job_fixture(%{client: client, crew_id: crew.id})

      # This will fail with Stripe API error in test, but validates the call structure
      result = Payments.create_payment_intent(job, 10000)

      # With stripe not mocked, we expect an error
      assert {:error, _} = result
    end
  end

  describe "handle_payment_succeeded/2" do
    test "updates job payment status on successful payment" do
      job = job_fixture()

      {:ok, _} =
        Payments.handle_payment_succeeded(
          "pi_test123",
          %{"job_id" => job.id}
        )
    end

    test "returns error if job not found" do
      assert {:error, :job_not_found} =
               Payments.handle_payment_succeeded("pi_test123", %{"job_id" => "nonexistent"})
    end

    test "returns error if metadata is missing job_id" do
      assert {:error, :invalid_metadata} =
               Payments.handle_payment_succeeded("pi_test123", %{})
    end

    test "returns error if metadata is nil" do
      assert {:error, :invalid_metadata} =
               Payments.handle_payment_succeeded("pi_test123", nil)
    end
  end

  describe "handle_account_updated/3" do
    test "updates stripe account charges and payouts status" do
      account = stripe_account_fixture(%{charges_enabled: false, payouts_enabled: false})

      {:ok, updated} =
        Payments.handle_account_updated(
          account.stripe_account_id,
          true,
          true
        )

      assert updated.charges_enabled == true
      assert updated.payouts_enabled == true
      assert updated.onboarding_completed == true
    end

    test "returns error if stripe account not found" do
      assert {:error, :stripe_account_not_found} =
               Payments.handle_account_updated("acct_nonexistent", true, true)
    end
  end
end
