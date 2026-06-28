defmodule GratefulSetCrew.Jobs.Application do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "job_applications" do
    # Foreign keys and relationships
    belongs_to :job, GratefulSetCrew.Job, type: :binary_id # Assuming Job schema exists
    belongs_to :crew, GratefulSetCrew.User, type: :id

    # Fields
    field :status, :string, default: "applied" # applied, accepted, rejected, expired
    field :applied_at, :utc_datetime
    field :responded_at, :utc_datetime
    field :match_score, :float

    timestamps(type: :utc_datetime)
  end

  @doc """
  Validates the required fields for a new job application.
  """
  def changeset(application, attrs) do
    application
    |> Ecto.Changeset.cast(attrs, [:job_id, :crew_id, :status, :match_score])
    |> Ecto.Changeset.validate_required([:job_id, :crew_id, :status])
    |> Ecto.Changeset.validate_inclusion(:status, ["applied", "accepted", "rejected", "expired"])
  end

  @doc """
  Scopes the changeset to ensure only one application exists per job and crew member.
  """
  def unique_job_application_changeset(_application, attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:job_id, :crew_id, :status, :match_score])
    |> Ecto.Changeset.validate_required([:job_id, :crew_id, :status])
    |> Ecto.Changeset.validate_inclusion(:status, ["applied", "accepted", "rejected", "expired"])
    # Note: The unique constraint is enforced at the database level via migration/index
  end
end
