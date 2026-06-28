defmodule GratefulSetCrewWeb.CrewLive.Earnings do
  use GratefulSetCrewWeb, :live_view

  on_mount {GratefulSetCrewWeb.UserAuth, :ensure_current_scope}

  alias GratefulSetCrew.{Accounts, Jobs, Payments}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    crew_profile = Accounts.get_crew_profile(user.id)
    stripe_account = Payments.get_stripe_account(user.id)

    # Calculate earnings from completed jobs
    completed_jobs = Jobs.list_jobs_by_client(user.id)
      |> Enum.filter(&(&1.status == "completed"))

    total_earnings = calculate_total_earnings(completed_jobs)
    pending_earnings = calculate_pending_earnings(completed_jobs)

    socket =
      socket
      |> assign(user_id: user.id)
      |> assign(crew_profile: crew_profile)
      |> assign(stripe_account: stripe_account)
      |> assign(completed_jobs: completed_jobs)
      |> assign(total_earnings: total_earnings)
      |> assign(pending_earnings: pending_earnings)
      |> assign(stripe_connected: is_connected?(stripe_account))

    {:ok, socket}
  end

  @impl true
  def handle_event("connect_stripe", _params, socket) do
    # In production, this would redirect to Stripe OAuth flow
    # For now, we just show a message
    {:noreply, socket}
  end

  defp calculate_total_earnings(jobs) do
    jobs
    |> Enum.reduce(0.0, fn job, acc ->
      rate = job.hourly_rate || 0
      hours = job.estimated_hours || 0
      acc + rate * hours
    end)
  end

  defp calculate_pending_earnings(jobs) do
    jobs
    |> Enum.filter(&(&1.payment_status == "pending"))
    |> calculate_total_earnings()
  end

  defp is_connected?(nil), do: false
  defp is_connected?(%{stripe_user_id: id}) when is_binary(id), do: true
  defp is_connected?(_), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Header -->
      <div class="bg-zinc-900/60 border-b border-zinc-800">
        <div class="mx-auto max-w-7xl px-6 py-8">
          <h1 class="text-3xl font-bold text-white">Earnings & Payments</h1>
          <p class="mt-2 text-zinc-400">Manage your Stripe account and track your earnings</p>
        </div>
      </div>

      <!-- Main Content -->
      <div class="mx-auto max-w-7xl px-6 py-12">
        <!-- Earnings Summary -->
        <div class="grid grid-cols-1 gap-6 md:grid-cols-3 mb-8">
          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
            <h3 class="text-lg font-semibold text-zinc-300">Total Earnings</h3>
            <p class="mt-2 text-3xl font-bold text-[#D4AF37]">
              $<%= Float.round(@total_earnings, 2) %>
            </p>
            <p class="mt-2 text-sm text-zinc-500">From <%= length(@completed_jobs) %> completed jobs</p>
          </div>

          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
            <h3 class="text-lg font-semibold text-zinc-300">Pending Earnings</h3>
            <p class="mt-2 text-3xl font-bold text-yellow-400">
              $<%= Float.round(@pending_earnings, 2) %>
            </p>
            <p class="mt-2 text-sm text-zinc-500">Waiting for client approval</p>
          </div>

          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
            <h3 class="text-lg font-semibold text-zinc-300">Stripe Account</h3>
            <div class="mt-4">
              <%= if @stripe_connected do %>
                <div class="flex items-center gap-2">
                  <span class="text-2xl text-emerald-400">✓</span>
                  <div>
                    <p class="text-sm font-medium text-emerald-400">Connected</p>
                    <p class="text-xs text-zinc-500">Account ID ending in <%= String.slice(@stripe_account.stripe_user_id, -4..-1) %></p>
                  </div>
                </div>
              <% else %>
                <p class="text-sm text-zinc-500 mb-3">Connect your Stripe account to receive payments</p>
                <button
                  phx-click="connect_stripe"
                  class="bg-[#D4AF37] text-black hover:bg-[#c9a227] font-semibold rounded-lg px-4 py-2 text-sm transition-colors"
                >
                  Connect Stripe
                </button>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Stripe Connection Info -->
        <%= if !@stripe_connected do %>
          <div class="rounded-xl bg-zinc-900/60 border-l-4 border-[#D4AF37] p-6 mb-8">
            <h3 class="text-lg font-semibold text-white mb-2">Ready to get paid?</h3>
            <p class="text-zinc-400 mb-4">
              Connect your Stripe account to receive payments directly for completed jobs. We use Stripe Connect to handle secure payments.
            </p>
            <div class="flex gap-4">
              <button
                phx-click="connect_stripe"
                class="bg-[#D4AF37] text-black px-6 py-2 text-white font-semibold hover:bg-[#c9a227] transition-colors rounded-lg"
              >
                Connect Stripe Account
              </button>
              <button
                class="border border-zinc-700 text-zinc-400 font-semibold rounded-lg px-6 py-2 hover:border-[#D4AF37] hover:text-[#D4AF37] transition-colors"
              >
                Learn More
              </button>
            </div>
          </div>
        <% end %>

        <!-- Earnings History -->
        <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-8">
          <h2 class="text-2xl font-bold text-white mb-6">Earnings by Job</h2>

          <%= if length(@completed_jobs) > 0 do %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-zinc-800">
                <thead class="bg-zinc-800/50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-semibold text-zinc-400 uppercase tracking-wider">Job Title</th>
                    <th class="px-6 py-3 text-left text-xs font-semibold text-zinc-400 uppercase tracking-wider">Client</th>
                    <th class="px-6 py-3 text-right text-xs font-semibold text-zinc-400 uppercase tracking-wider">Rate/Hour</th>
                    <th class="px-6 py-3 text-right text-xs font-semibold text-zinc-400 uppercase tracking-wider">Hours</th>
                    <th class="px-6 py-3 text-right text-xs font-semibold text-zinc-400 uppercase tracking-wider">Total</th>
                    <th class="px-6 py-3 text-left text-xs font-semibold text-zinc-400 uppercase tracking-wider">Status</th>
                    <th class="px-6 py-3 text-left text-xs font-semibold text-zinc-400 uppercase tracking-wider">Completed</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-zinc-800">
                  <%= for job <- @completed_jobs do %>
                    <tr class="hover:bg-zinc-800/30 transition-colors">
                      <td class="px-6 py-4 text-sm font-medium text-white">
                        <%= String.slice(job.title, 0..39) %>
                      </td>
                      <td class="px-6 py-4 text-sm text-zinc-400">
                        Client #<%= String.slice(job.client_id || "", 0..7) %>
                      </td>
                      <td class="px-6 py-4 text-right text-sm text-zinc-400">
                        $<%= Float.round(job.hourly_rate || 0, 2) %>
                      </td>
                      <td class="px-6 py-4 text-right text-sm text-zinc-400">
                        <%= job.estimated_hours || 0 %>
                      </td>
                      <td class="px-6 py-4 text-right text-sm font-semibold text-white">
                        $<%= Float.round((job.hourly_rate || 0) * (job.estimated_hours || 0), 2) %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={
                          "inline-block px-3 py-1 rounded-full text-xs font-medium #{payment_status_badge(job.payment_status)}"
                        }>
                          <%= String.capitalize(job.payment_status) %>
                        </span>
                      </td>
                      <td class="px-6 py-4 text-sm text-zinc-400">
                        <%= format_date(job.updated_at) %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% else %>
            <div class="text-center py-12">
              <p class="text-zinc-400 text-lg">No completed jobs yet</p>
              <p class="text-zinc-500 mt-2">Your earnings will appear here once you complete jobs</p>
            </div>
          <% end %>
        </div>

        <!-- Payment Info -->
        <div class="mt-8 grid grid-cols-1 gap-6 md:grid-cols-2">
          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
            <h3 class="text-lg font-semibold text-white mb-4">How Payments Work</h3>
            <ol class="space-y-3 text-sm text-zinc-400">
              <li class="flex gap-3">
                <span class="font-semibold text-[#D4AF37] flex-shrink-0">1</span>
                <span>Complete a job and mark it as done</span>
              </li>
              <li class="flex gap-3">
                <span class="font-semibold text-[#D4AF37] flex-shrink-0">2</span>
                <span>Client reviews and approves the work</span>
              </li>
              <li class="flex gap-3">
                <span class="font-semibold text-[#D4AF37] flex-shrink-0">3</span>
                <span>Payment is processed to your Stripe account</span>
              </li>
              <li class="flex gap-3">
                <span class="font-semibold text-[#D4AF37] flex-shrink-0">4</span>
                <span>Funds are transferred to your bank account</span>
              </li>
            </ol>
          </div>

          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
            <h3 class="text-lg font-semibold text-white mb-4">Fees & Payouts</h3>
            <div class="space-y-4">
              <div class="flex justify-between">
                <span class="text-sm text-zinc-400">GratefulSetCrew service fee</span>
                <span class="text-sm font-medium text-white">10%</span>
              </div>
              <div class="flex justify-between">
                <span class="text-sm text-zinc-400">Stripe processing fee</span>
                <span class="text-sm font-medium text-white">2.9% + $0.30</span>
              </div>
              <div class="border-t border-zinc-800 pt-4 flex justify-between">
                <span class="text-sm font-medium text-white">You receive (approx.)</span>
                <span class="text-sm font-bold text-[#D4AF37]">~87% of job rate</span>
              </div>
              <p class="text-xs text-zinc-600 pt-2">
                Payouts are processed weekly to your connected bank account.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp payment_status_badge(status) do
    case status do
      "pending" -> "bg-yellow-900/60 text-yellow-400"
      "completed" -> "bg-emerald-900/60 text-emerald-400"
      "failed" -> "bg-red-900/60 text-red-400"
      _ -> "bg-zinc-800 text-zinc-400"
    end
  end

  defp format_date(datetime) do
    if datetime do
      datetime
      |> DateTime.shift_zone!("America/Los_Angeles")
      |> Calendar.strftime("%b %d, %Y")
    else
      "N/A"
    end
  end
end
