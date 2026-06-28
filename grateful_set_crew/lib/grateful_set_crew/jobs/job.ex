defmodule GratefulSetCrew.Jobs.Job do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :id

  schema "jobs" do
    belongs_to :client, GratefulSetCrew.Accounts.User
    belongs_to :crew, GratefulSetCrew.Accounts.User

    field :title, :string
    field :description, :string
    field :location, :string
    field :required_skills, {:array, :string}, default: []
    field :status, :string, default: "open"
    field :payment_status, :string, default: "pending"
    field :start_date, :utc_datetime
    field :end_date, :utc_datetime
    field :match_score, :float
    field :latitude, :float
    field :longitude, :float
    field :hourly_rate, :float
    field :estimated_hours, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :client_id,
      :crew_id,
      :title,
      :description,
      :location,
      :required_skills,
      :status,
      :payment_status,
      :start_date,
      :end_date,
      :match_score,
      :latitude,
      :longitude,
      :hourly_rate,
      :estimated_hours
    ])
    |> validate_required([:client_id, :title])
    |> validate_inclusion(:status, ["open", "assigned", "completed", "cancelled", "matching"])
    |> validate_inclusion(:payment_status, ["pending", "completed", "failed"])
  end
end
