defmodule GratefulSetCrew.Repo.Migrations.CreateJobApplications do
  use Ecto.Migration

  def change do
    create table(:job_applications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :job_id, references(:jobs, on_delete: :delete_all, type: :binary_id), null: false
      add :crew_id, references(:users, on_delete: :delete_all, type: :id), null: false

      add :status, :string, default: "applied", null: false
      add :applied_at, :utc_datetime
      add :responded_at, :utc_datetime
      add :match_score, :float

      timestamps(type: :utc_datetime)
    end

    create index(:job_applications, [:job_id])
    create index(:job_applications, [:crew_id])
    create index(:job_applications, [:status])
    create index(:job_applications, [:applied_at])
    create unique_index(:job_applications, [:job_id, :crew_id], name: :job_applications_job_crew_unique)
  end
end
