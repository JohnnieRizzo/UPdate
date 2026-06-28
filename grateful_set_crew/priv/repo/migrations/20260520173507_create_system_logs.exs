defmodule GratefulSetCrew.Repo.Migrations.CreateSystemLogs do
  use Ecto.Migration

  def change do
    create table(:system_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :nilify_all)
      add :job_id, references(:jobs, type: :binary_id, on_delete: :nilify_all)
      add :event_type, :string, null: false
      add :details, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:system_logs, [:event_type])
    create index(:system_logs, [:user_id])
    create index(:system_logs, [:job_id])
  end
end
