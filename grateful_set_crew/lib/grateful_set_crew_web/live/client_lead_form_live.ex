defmodule GratefulSetCrewWeb.ClientLeadFormLive do
  use GratefulSetCrewWeb, :live_view

  # Initialize state with empty data structures for all sections
  @impl true
  def mount(_params, _session, socket) do
    initial_attributes = %{
      company_name: "",
      contact_email: "",
      # Required identifier
      tax_id: "",
      client_description: "",
      # Full address for venue mapping
      target_location_address: "",
      venue_name: "",
      # List of equipment/staff needed
      staffing_needs: [],
      budget_range: "",
      deposit_amount: nil,
      estimated_total_price: nil
    }

    # Load any existing lead data if viewing an ID (omitted for initial form)
    {:ok, assign(socket, lead_form_attributes: initial_attributes)}
  end

  @impl true
  def handle_event("submit_lead", _params, socket) do
    # 1. Validate all mandatory fields (Company Name, Email, Tax ID, etc.)
    # 2. Call the backend service: GratefulSetCrew.Jobs.create_initial_contract/2
    # 3. Handle success/error states and display confirmation.

    IO.puts("Handling submission for new client lead...")
    # Placeholder action
    {:noreply, assign(socket, status: :success)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto py-12 max-w-6xl">
      <h1 class="text-4xl font-bold mb-2 text-gray-900">Intake Form: Project Lead Submission</h1>
      <.flash :if={assigns[:status] == :success} kind={:info}>Form submitted successfully</.flash>

    <!-- Tab Navigation Placeholder -->
        <div class="border-b border-gray-200 flex space-x-4 mb-8">
          <button
            phx-click="submit_lead"
            id="tab-general"
            class="p-3 text-lg font-medium text-indigo-600 border-b-2 border-indigo-600 transition hover:text-indigo-700"
          >
            General Info
          </button>
          <button phx-click="" id="tab-venue">Venue & Location</button>
          <button phx-click="" id="tab-scope">Scope & Staffing</button>
          <button phx-click="" id="tab-finance">Financials</button>
        </div>

        <.client_lead_form_component />
    </div>
    """
  end

  defp client_lead_form_component(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-md p-6">
      <form phx-submit="submit_lead" class="space-y-6">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Company Name</label>
            <input type="text" class="mt-1 block w-full rounded-md border-gray-300" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Contact Email</label>
            <input type="email" class="mt-1 block w-full rounded-md border-gray-300" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Tax ID</label>
            <input type="text" class="mt-1 block w-full rounded-md border-gray-300" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Venue Name</label>
            <input type="text" class="mt-1 block w-full rounded-md border-gray-300" />
          </div>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Venue Address</label>
          <input type="text" class="mt-1 block w-full rounded-md border-gray-300" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Project Description</label>
          <textarea class="mt-1 block w-full rounded-md border-gray-300 rows-4"></textarea>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Budget Range</label>
            <input type="text" class="mt-1 block w-full rounded-md border-gray-300" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Deposit Amount</label>
            <input type="number" class="mt-1 block w-full rounded-md border-gray-300" />
          </div>
        </div>
        <button type="submit" class="bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700">
          Submit
        </button>
      </form>
    </div>
    """
  end
end
