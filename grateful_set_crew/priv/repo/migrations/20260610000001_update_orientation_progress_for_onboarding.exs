defmodule GratefulSetCrew.Repo.Migrations.UpdateOrientationProgressForOnboarding do
  use Ecto.Migration

  def up do
    alter table(:orientation_progress) do
      remove :modules_completed
      remove :quiz_passed
    end

    alter table(:orientation_progress) do
      add :selected_skills, {:array, :string}, default: []
      add :selected_certifications, {:array, :string}, default: []
      add :modules_completed, {:array, :integer}, default: []
      add :rulebook_read, :boolean, default: false
      add :quiz_score, :integer
      add :quiz_attempts, :integer, default: 0
    end

    execute "UPDATE orientation_progress SET current_step = 'skills' WHERE current_step = 'intro'"
  end

  def down do
    alter table(:orientation_progress) do
      remove :selected_skills
      remove :selected_certifications
      remove :modules_completed
      remove :rulebook_read
      remove :quiz_score
      remove :quiz_attempts
    end

    alter table(:orientation_progress) do
      add :modules_completed, {:array, :string}, default: []
      add :quiz_passed, :boolean, default: false
    end

    execute "UPDATE orientation_progress SET current_step = 'intro' WHERE current_step = 'skills'"
  end
end
