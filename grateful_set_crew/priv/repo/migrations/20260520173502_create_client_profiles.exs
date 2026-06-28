defmodule GratefulSetCrew.Repo.Migrations.CreateClientProfiles do
  use Ecto.Migration

  def change do
    create table(:client_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false, primary_key: true
      add :full_name, :string
      add :location, :string
      add :company_name, :string
      add :phone, :string

      timestamps(type: :utc_datetime)
    end

    create index(:client_profiles, [:user_id])
  end
end
