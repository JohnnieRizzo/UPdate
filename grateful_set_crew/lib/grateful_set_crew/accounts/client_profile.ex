defmodule GratefulSetCrew.Accounts.ClientProfile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "client_profiles" do
    belongs_to :user, GratefulSetCrew.Accounts.User, foreign_key: :user_id, type: :id, primary_key: true

    field :full_name, :string
    field :location, :string
    field :company_name, :string
    field :phone, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(client_profile, attrs) do
    client_profile
    |> cast(attrs, [:user_id, :full_name, :location, :company_name, :phone])
    |> validate_required([:user_id])
  end
end
