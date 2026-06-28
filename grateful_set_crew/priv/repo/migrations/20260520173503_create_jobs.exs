defmodule GratefulSetCrew.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id, references(:users, on_delete: :restrict), null: false
      add :crew_id, references(:users, on_delete: :nilify_all)
      add :title, :string, null: false
      add :description, :text
      add :location, :string
      add :required_skills, {:array, :string}, default: []
      add :status, :string, default: "open"
      add :payment_status, :string, default: "pending"
      add :start_date, :utc_datetime
      add :end_date, :utc_datetime
      add :match_score, :float
      add :latitude, :float
      add :longitude, :float

      timestamps(type: :utc_datetime)
    end

    create index(:jobs, [:client_id])
    create index(:jobs, [:crew_id])
    create index(:jobs, [:status])
  end
end
