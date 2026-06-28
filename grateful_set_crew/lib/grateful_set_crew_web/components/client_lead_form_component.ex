defmodule GratefulSetCrewWeb.Components.ClientLeadFormComponent do
  use Phoenix.Component

  @doc """
  Renders the client lead intake form with all required fields.
  """
  def client_lead_form(assigns) do
    ~H"""
    <form phx-submit="submit_lead" class="space-y-8">
      <!-- General Information Section -->
      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">General Information</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label for="company_name" class="block text-sm font-medium text-gray-700 mb-1">
              Company Name *
            </label>
            <input
              type="text"
              id="company_name"
              name="company_name"
              value={@lead_form_attributes[:company_name]}
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>

          <div>
            <label for="contact_email" class="block text-sm font-medium text-gray-700 mb-1">
              Contact Email *
            </label>
            <input
              type="email"
              id="contact_email"
              name="contact_email"
              value={@lead_form_attributes[:contact_email]}
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>

          <div>
            <label for="tax_id" class="block text-sm font-medium text-gray-700 mb-1">
              Tax ID (EIN/TIN) *
            </label>
            <input
              type="text"
              id="tax_id"
              name="tax_id"
              value={@lead_form_attributes[:tax_id]}
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>

          <div>
            <label for="client_description" class="block text-sm font-medium text-gray-700 mb-1">
              Client Description
            </label>
            <input
              type="text"
              id="client_description"
              name="client_description"
              value={@lead_form_attributes[:client_description]}
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>
        </div>
      </div>

      <!-- Venue & Location Section -->
      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">Venue & Location</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label for="venue_name" class="block text-sm font-medium text-gray-700 mb-1">
              Venue Name
            </label>
            <input
              type="text"
              id="venue_name"
              name="venue_name"
              value={@lead_form_attributes[:venue_name]}
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>

          <div class="md:col-span-2">
            <label for="target_location_address" class="block text-sm font-medium text-gray-700 mb-1">
              Full Address
            </label>
            <input
              type="text"
              id="target_location_address"
              name="target_location_address"
              value={@lead_form_attributes[:target_location_address]}
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>
        </div>
      </div>

      <!-- Scope & Staffing Section -->
      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">Scope & Staffing</h2>
        <div>
          <label for="staffing_needs" class="block text-sm font-medium text-gray-700 mb-1">
            Staffing & Equipment Needs
          </label>
          <textarea
            id="staffing_needs"
            name="staffing_needs"
            rows="4"
            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
          ><%= Enum.join(@lead_form_attributes[:staffing_needs], ", ") %></textarea>
          <p class="mt-1 text-xs text-gray-500">Enter items separated by commas</p>
        </div>
      </div>

      <!-- Financials Section -->
      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">Financials</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label for="budget_range" class="block text-sm font-medium text-gray-700 mb-1">
              Budget Range
            </label>
            <select
              id="budget_range"
              name="budget_range"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            >
              <option value="">Select a range</option>
              <option value="under_5k" selected={@lead_form_attributes[:budget_range] == "under_5k"}>
                Under $5,000
              </option>
              <option value="5k_10k" selected={@lead_form_attributes[:budget_range] == "5k_10k"}>
                $5,000 - $10,000
              </option>
              <option value="10k_25k" selected={@lead_form_attributes[:budget_range] == "10k_25k"}>
                $10,000 - $25,000
              </option>
              <option value="25k_plus" selected={@lead_form_attributes[:budget_range] == "25k_plus"}>
                $25,000+
              </option>
            </select>
          </div>

          <div>
            <label for="deposit_amount" class="block text-sm font-medium text-gray-700 mb-1">
              Deposit Amount
            </label>
            <input
              type="number"
              id="deposit_amount"
              name="deposit_amount"
              value={@lead_form_attributes[:deposit_amount]}
              step="0.01"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>

          <div>
            <label for="estimated_total_price" class="block text-sm font-medium text-gray-700 mb-1">
              Estimated Total Price
            </label>
            <input
              type="number"
              id="estimated_total_price"
              name="estimated_total_price"
              value={@lead_form_attributes[:estimated_total_price]}
              step="0.01"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>
        </div>
      </div>

      <!-- Submit Button -->
      <div class="flex gap-4">
        <button
          type="submit"
          class="px-6 py-3 bg-indigo-600 text-white font-medium rounded-md hover:bg-indigo-700 transition-colors"
        >
          Submit Lead
        </button>
        <button
          type="reset"
          class="px-6 py-3 bg-gray-200 text-gray-800 font-medium rounded-md hover:bg-gray-300 transition-colors"
        >
          Clear Form
        </button>
      </div>
    </form>
    """
  end
end
