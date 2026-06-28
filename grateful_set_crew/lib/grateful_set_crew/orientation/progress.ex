defmodule GratefulSetCrew.Orientation.Progress do
  use Ecto.Schema
  import Ecto.Changeset

  schema "orientation_progress" do
    belongs_to :user, GratefulSetCrew.Accounts.User

    field :current_step, :string, default: "skills"
    field :selected_skills, {:array, :string}, default: []
    field :selected_certifications, {:array, :string}, default: []
    field :modules_completed, {:array, :integer}, default: []
    field :rulebook_read, :boolean, default: false
    field :quiz_score, :integer
    field :quiz_attempts, :integer, default: 0
    field :completed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(progress, attrs) do
    progress
    |> cast(attrs, [
      :user_id, :current_step, :selected_skills, :selected_certifications,
      :modules_completed, :rulebook_read, :quiz_score, :quiz_attempts, :completed_at
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:current_step, ["skills", "modules", "quiz", "complete"])
    |> unique_constraint(:user_id)
  end
end
