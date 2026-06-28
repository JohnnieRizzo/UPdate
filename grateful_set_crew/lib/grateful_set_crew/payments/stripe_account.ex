defmodule GratefulSetCrew.Payments.StripeAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stripe_accounts" do
    belongs_to :user, GratefulSetCrew.Accounts.User

    field :stripe_account_id, :string
    field :charges_enabled, :boolean, default: false
    field :payouts_enabled, :boolean, default: false
    field :onboarding_completed, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(stripe_account, attrs) do
    stripe_account
    |> cast(attrs, [:user_id, :stripe_account_id, :charges_enabled, :payouts_enabled, :onboarding_completed])
    |> validate_required([:user_id, :stripe_account_id])
    |> unique_constraint(:user_id)
    |> unique_constraint(:stripe_account_id)
  end
end
