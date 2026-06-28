defmodule GratefulSetCrew.Orientation do
  import Ecto.Query, warn: false
  alias GratefulSetCrew.Repo
  alias GratefulSetCrew.Orientation.Progress

  def get_progress!(user_id), do: Repo.get_by!(Progress, user_id: user_id)
  def get_progress(user_id), do: Repo.get_by(Progress, user_id: user_id)

  def create_progress(user_id) do
    %Progress{}
    |> Progress.changeset(%{user_id: user_id})
    |> Repo.insert()
  end

  def update_progress(%Progress{} = progress, attrs) do
    progress
    |> Progress.changeset(attrs)
    |> Repo.update()
  end

  def save_skills(%Progress{} = progress, attrs) do
    update_progress(progress, attrs)
  end

  def save_modules(%Progress{} = progress, attrs) do
    update_progress(progress, attrs)
  end

  def complete_onboarding(%Progress{} = progress, score) do
    update_progress(progress, %{
      quiz_score: score,
      current_step: "complete",
      completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  def increment_quiz_attempts(%Progress{} = progress, score) do
    update_progress(progress, %{
      quiz_score: score,
      quiz_attempts: (progress.quiz_attempts || 0) + 1
    })
  end

  def is_complete?(%Progress{} = progress), do: progress.current_step == "complete"
end
