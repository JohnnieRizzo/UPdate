defmodule GratefulSetCrew.Accounts.CrewProfile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "crew_profiles" do
    belongs_to :user, GratefulSetCrew.Accounts.User, foreign_key: :user_id, type: :id, primary_key: true

    field :bio, :string
    field :full_name, :string
    field :location, :string
    field :union, :string
    field :skills, {:array, :string}, default: []
    field :certifications, {:array, :string}, default: []
    field :rating, :float, default: 0.0
    field :completed_jobs, :integer, default: 0
    field :hourly_rate, :float
    field :availability_status, :string, default: "offline"
    field :onboarding_status, :string, default: "not_started"
    field :latitude, :float
    field :longitude, :float

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(crew_profile, attrs) do
    crew_profile
    |> cast(attrs, [
      :user_id,
      :bio,
      :full_name,
      :location,
      :union,
      :skills,
      :certifications,
      :rating,
      :completed_jobs,
      :hourly_rate,
      :availability_status,
      :onboarding_status,
      :latitude,
      :longitude
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:availability_status, ["available", "busy", "offline"])
    |> validate_inclusion(:onboarding_status, ["not_started", "in_progress", "complete"])
  end
end
