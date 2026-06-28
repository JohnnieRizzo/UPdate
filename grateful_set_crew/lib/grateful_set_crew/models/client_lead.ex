defmodule GratefulSetCrew.Models.ClientLead do
  use Ecto.Schema

  schema "client_leads" do
    # Client info gathered via intake form
    field :company_name, :string
    field :contact_email, :string
    field :description, :string # Detailed need/scope of work
    field :target_location, :string # Miami, Florida etc.
    field :budget_range, :string # e.g., "$5k - $10k"

    # Agent assessment and status
    field :status, :string, default: "intake" # intake, researching, qualified, lead_created
    field :assigned_agent, :string # e.g., "Miami Scout", "Super Agent"

    timestamps()
  end

  def changeset(lead, attrs) do
    lead
    |> Ecto.Changeset.cast(attrs, [:company_name, :contact_email, :description, :target_location, :budget_range])
    |> Ecto.Changeset.validate_required([:company_name, :contact_email])
  end

  # Add validation for specific fields as required (e.g., valid email format)
end
