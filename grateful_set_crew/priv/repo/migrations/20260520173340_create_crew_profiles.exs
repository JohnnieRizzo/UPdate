defmodule GratefulSetCrew.Repo.Migrations.CreateCrewProfiles do
  use Ecto.Migration

  def change do
    create table(:crew_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false, primary_key: true
      add :full_name, :string
      add :location, :string
      add :skills, {:array, :string}, default: []
      add :certifications, {:array, :string}, default: []
      add :rating, :float, default: 0.0
      add :completed_jobs, :integer, default: 0
      add :hourly_rate, :float
      add :availability_status, :string, default: "offline"
      add :onboarding_status, :string, default: "not_started"
      add :latitude, :float
      add :longitude, :float

      timestamps(type: :utc_datetime)
    end

    create index(:crew_profiles, [:user_id])
    create index(:crew_profiles, [:onboarding_status])
    create index(:crew_profiles, [:availability_status])
  end
end
