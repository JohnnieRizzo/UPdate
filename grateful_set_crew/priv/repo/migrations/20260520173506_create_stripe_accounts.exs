defmodule GratefulSetCrew.Repo.Migrations.CreateStripeAccounts do
  use Ecto.Migration

  def change do
    create table(:stripe_accounts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :stripe_account_id, :string, null: false
      add :charges_enabled, :boolean, default: false
      add :payouts_enabled, :boolean, default: false
      add :onboarding_completed, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:stripe_accounts, [:user_id])
    create unique_index(:stripe_accounts, [:stripe_account_id])
  end
end
