defmodule GratefulSetCrew.Repo.Migrations.ExtendUsersTableWithProfileFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, default: "client"
      add :full_name, :string
      add :phone, :string
      add :availability, :boolean, default: false
      add :onboarding_status, :string, default: "not_started"
    end

    create index(:users, [:role])
  end
end
