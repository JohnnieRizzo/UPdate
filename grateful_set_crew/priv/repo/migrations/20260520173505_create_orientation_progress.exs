defmodule GratefulSetCrew.Repo.Migrations.CreateOrientationProgress do
  use Ecto.Migration

  def change do
    create table(:orientation_progress) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :current_step, :string, default: "intro"
      add :modules_completed, {:array, :string}, default: []
      add :quiz_passed, :boolean, default: false
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:orientation_progress, [:user_id])
  end
end
