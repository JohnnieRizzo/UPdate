defmodule GratefulSetCrew.Notifications.SystemLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :id

  schema "system_logs" do
    belongs_to :user, GratefulSetCrew.Accounts.User, type: :id
    belongs_to :job, GratefulSetCrew.Jobs.Job

    field :event_type, :string
    field :details, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(system_log, attrs) do
    system_log
    |> cast(attrs, [:user_id, :job_id, :event_type, :details])
    |> validate_required([:event_type])
  end
end
