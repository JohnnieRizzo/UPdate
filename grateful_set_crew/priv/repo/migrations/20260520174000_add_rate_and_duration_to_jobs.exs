defmodule GratefulSetCrew.Repo.Migrations.AddRateAndDurationToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :hourly_rate, :float
      add :estimated_hours, :integer
    end
  end
end
