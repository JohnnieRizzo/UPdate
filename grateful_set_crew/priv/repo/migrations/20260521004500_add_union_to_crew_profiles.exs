defmodule GratefulSetCrew.Repo.Migrations.AddUnionToCrewProfiles do
  use Ecto.Migration

  def change do
    alter table(:crew_profiles) do
      add :union, :string, default: nil
    end
  end
end
