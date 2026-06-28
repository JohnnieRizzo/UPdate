defmodule GratefulSetCrew.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :id

  schema "notifications" do
    belongs_to :user, GratefulSetCrew.Accounts.User

    field :title, :string
    field :body, :string
    field :type, :string, default: "info"
    field :link, :string
    field :read, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :title, :body, :type, :link, :read])
    |> validate_required([:user_id, :title, :body])
    |> validate_inclusion(:type, ["info", "job", "warning", "error"])
  end
end
