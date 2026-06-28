defmodule GratefulSetCrew.Repo.Migrations.AddBioToCrewProfiles do
  use Ecto.Migration

  def change do
    alter table(:crew_profiles) do
      add :bio, :text
    end
  end
end
