defmodule GratefulSetCrew.PaymentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `GratefulSetCrew.Payments` context.
  """

  import GratefulSetCrew.AccountsFixtures

  alias GratefulSetCrew.Payments

  def valid_stripe_account_attributes(attrs \\ %{}) do
    user = attrs[:user] || user_fixture(%{role: "crew"})

    Enum.into(attrs, %{
      user_id: user.id,
      stripe_account_id: "acct_#{System.unique_integer()}",
      charges_enabled: false,
      payouts_enabled: false,
      onboarding_completed: false
    })
  end

  def stripe_account_fixture(attrs \\ %{}) do
    {:ok, account} =
      attrs
      |> valid_stripe_account_attributes()
      |> Payments.create_stripe_account()

    account
  end

  def completed_stripe_account_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture(%{role: "crew"})

    {:ok, account} =
      valid_stripe_account_attributes(%{
        user: user,
        charges_enabled: true,
        payouts_enabled: true,
        onboarding_completed: true
      })
      |> Payments.create_stripe_account()

    account
  end
end
