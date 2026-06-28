defmodule GratefulSetCrewWeb.AdminLive.Dashboard do
  use GratefulSetCrewWeb, :live_view

  alias GratefulSetCrew.{Accounts, Jobs, Notifications}

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to system logs
    Phoenix.PubSub.subscribe(GratefulSetCrew.PubSub, "system_logs:new")

    # Load initial data
    system_logs = Notifications.list_system_logs(50)
    open_jobs = Jobs.list_available_jobs()
    all_users = count_users()
    available_crew = Accounts.list_available_crew()

    socket =
      socket
      |> assign(active_tab: "overview")
      |> assign(system_logs: system_logs)
      |> assign(open_jobs: open_jobs)
      |> assign(total_users: all_users)
      |> assign(available_crew: available_crew)
      |> assign(log_filter: "all")

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def handle_event("filter_logs", %{"filter" => filter}, socket) do
    logs =
      if filter == "all" do
        Notifications.list_system_logs(50)
      else
        Notifications.list_system_logs_by_event(filter, 50)
      end

    {:noreply, assign(socket, log_filter: filter, system_logs: logs)}
  end

  @impl true
  def handle_event("run_dispatch", _params, socket) do
    # Trigger dispatch algorithm for all open jobs
    open_jobs = Jobs.list_available_jobs()

    Enum.each(open_jobs, fn job ->
      Notifications.log("dispatch.run", %{
        job_id: job.id,
        job_title: job.title,
        status: "initiated"
      })
    end)

    system_logs = Notifications.list_system_logs(50)
    {:noreply, assign(socket, system_logs: system_logs)}
  end

  @impl true
  def handle_info({:system_log_created, _log}, socket) do
    system_logs = Notifications.list_system_logs(50)
    {:noreply, assign(socket, system_logs: system_logs)}
  end

  defp count_users do
    # Placeholder - in production, query all users from database
    5
  end

  defp active_jobs_count(jobs) do
    Enum.count(jobs, &(&1.status in ["open", "matching", "assigned"]))
  end

  defp completed_jobs_count(jobs) do
    Enum.count(jobs, &(&1.status == "completed"))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Header -->
      <div class="bg-zinc-900/60 border-b border-zinc-800 px-6 py-8">
        <div class="mx-auto max-w-7xl">
          <h1 class="text-3xl font-bold text-white">Admin Dashboard</h1>
          <p class="mt-2 text-zinc-400">Manage users, jobs, and monitor system activity</p>
        </div>
      </div>

      <!-- Tabs -->
      <div class="bg-zinc-900/60 border-b border-zinc-800">
        <div class="mx-auto max-w-7xl px-6 flex gap-8">
          <button
            phx-click="switch_tab"
            phx-value-tab="overview"
            class={
              "py-4 px-1 border-b-2 font-medium text-sm #{
                if @active_tab == "overview",
                do: "border-[#D4AF37] text-[#D4AF37]",
                else: "border-transparent text-zinc-500 hover:text-zinc-300"
              }"
            }
          >
            Overview
          </button>
          <button
            phx-click="switch_tab"
            phx-value-tab="logs"
            class={
              "py-4 px-1 border-b-2 font-medium text-sm #{
                if @active_tab == "logs",
                do: "border-[#D4AF37] text-[#D4AF37]",
                else: "border-transparent text-zinc-500 hover:text-zinc-300"
              }"
            }
          >
            System Logs
          </button>
          <button
            phx-click="switch_tab"
            phx-value-tab="jobs"
            class={
              "py-4 px-1 border-b-2 font-medium text-sm #{
                if @active_tab == "jobs",
                do: "border-[#D4AF37] text-[#D4AF37]",
                else: "border-transparent text-zinc-500 hover:text-zinc-300"
              }"
            }
          >
            Jobs
          </button>
          <button
            phx-click="switch_tab"
            phx-value-tab="crew"
            class={
              "py-4 px-1 border-b-2 font-medium text-sm #{
                if @active_tab == "crew",
                do: "border-[#D4AF37] text-[#D4AF37]",
                else: "border-transparent text-zinc-500 hover:text-zinc-300"
              }"
            }
          >
            Available Crew
          </button>
        </div>
      </div>

      <!-- Content -->
      <div class="mx-auto max-w-7xl px-6 py-12">
        <!-- Overview Tab -->
        <%= if @active_tab == "overview" do %>
          <div>
            <div class="grid grid-cols-1 gap-6 md:grid-cols-4 mb-8">
              <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
                <h3 class="text-lg font-semibold text-zinc-300">Total Users</h3>
                <p class="mt-2 text-3xl font-bold text-[#D4AF37]"><%= @total_users %></p>
              </div>
              <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
                <h3 class="text-lg font-semibold text-zinc-300">Active Jobs</h3>
                <p class="mt-2 text-3xl font-bold text-yellow-400"><%= active_jobs_count(@open_jobs) %></p>
              </div>
              <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
                <h3 class="text-lg font-semibold text-zinc-300">Completed Jobs</h3>
                <p class="mt-2 text-3xl font-bold text-emerald-400"><%= completed_jobs_count(@open_jobs) %></p>
              </div>
              <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
                <h3 class="text-lg font-semibold text-zinc-300">Available Crew</h3>
                <p class="mt-2 text-3xl font-bold text-[#D4AF37]"><%= length(@available_crew) %></p>
              </div>
            </div>

            <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-8">
              <h2 class="text-2xl font-bold text-white mb-4">System Actions</h2>
              <button
                phx-click="run_dispatch"
                class="bg-[#D4AF37] text-black hover:bg-[#c9a227] font-semibold rounded-lg px-6 py-3 transition-colors"
              >
                Run Job Dispatch Algorithm
              </button>
              <p class="mt-4 text-sm text-zinc-500">
                This will run the matching algorithm to assign available crew members to open jobs.
              </p>
            </div>
          </div>
        <% end %>

        <!-- Logs Tab -->
        <%= if @active_tab == "logs" do %>
          <div>
            <div class="mb-6 flex gap-4">
              <label class="block">
                <span class="block text-sm font-medium text-zinc-400 mb-1">Filter by Event Type:</span>
                <select
                  phx-change="filter_logs"
                  class="mt-1 block rounded-lg bg-zinc-800 border border-zinc-700 text-white px-4 py-2 focus:outline-none focus:border-[#D4AF37]"
                >
                  <option value="all" selected={@log_filter == "all"}>All Events</option>
                  <option value="dispatch.run" selected={@log_filter == "dispatch.run"}>Dispatch Run</option>
                  <option value="job.created" selected={@log_filter == "job.created"}>Job Created</option>
                  <option value="job.assigned" selected={@log_filter == "job.assigned"}>Job Assigned</option>
                  <option value="notification.created" selected={@log_filter == "notification.created"}>Notifications</option>
                </select>
              </label>
            </div>

            <div class="rounded-xl bg-zinc-900 border border-zinc-800 overflow-hidden">
              <table class="min-w-full divide-y divide-zinc-800">
                <thead class="bg-zinc-800/50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-semibold text-zinc-400 uppercase tracking-wider">Event</th>
                    <th class="px-6 py-3 text-left text-xs font-semibold text-zinc-400 uppercase tracking-wider">Details</th>
                    <th class="px-6 py-3 text-left text-xs font-semibold text-zinc-400 uppercase tracking-wider">Time</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-zinc-800">
                  <%= for log <- @system_logs do %>
                    <tr class="hover:bg-zinc-800/30 transition-colors">
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-semibold text-white">
                        <%= log.event_type %>
                      </td>
                      <td class="px-6 py-4 text-sm text-zinc-300">
                        <%= inspect(log.details, pretty: true) %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-300">
                        <%= format_datetime(log.inserted_at) %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>

        <!-- Jobs Tab -->
        <%= if @active_tab == "jobs" do %>
          <div>
            <h2 class="text-2xl font-bold text-gray-900 mb-6">All Jobs</h2>

            <%= if length(@open_jobs) > 0 do %>
              <div class="rounded-lg bg-white shadow overflow-hidden">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Title</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Client</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Status</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Rate</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase">Posted</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-200">
                    <%= for job <- @open_jobs do %>
                      <tr class="hover:bg-gray-50">
                        <td class="px-6 py-4 text-sm font-medium text-gray-900">
                          <%= String.slice(job.title, 0..49) %>
                        </td>
                        <td class="px-6 py-4 text-sm text-gray-600">
                          <%= String.slice(job.client_id || "", 0..7) %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                          <span class="inline-block px-3 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                            <%= job.status %>
                          </span>
                        </td>
                        <td class="px-6 py-4 text-sm text-gray-600">
                          $<%= Float.round(job.hourly_rate || 0, 2) %>/hr
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                          <%= format_datetime(job.inserted_at) %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% else %>
              <div class="text-center py-12">
                <p class="text-gray-600 text-lg">No jobs found</p>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Available Crew Tab -->
        <%= if @active_tab == "crew" do %>
          <div>
            <h2 class="text-2xl font-bold text-gray-900 mb-6">Available Crew Members</h2>

            <%= if length(@available_crew) > 0 do %>
              <div class="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
                <%= for crew <- @available_crew do %>
                  <div class="rounded-lg bg-white p-6 shadow hover:shadow-lg transition-shadow">
                    <h3 class="text-lg font-semibold text-gray-900">
                      <%= crew.user.full_name || "Crew Member" %>
                    </h3>
                    <div class="mt-4 space-y-2 text-sm text-gray-600">
                      <div>
                        <span class="font-medium text-gray-700">Status:</span>
                        <span class="ml-2 inline-block px-2 py-1 rounded bg-light-bg text-navy text-xs font-medium">
                          Available
                        </span>
                      </div>
                      <div>
                        <span class="font-medium text-gray-700">Completed Jobs:</span>
                        <span class="ml-2"><%= crew.completed_jobs || 0 %></span>
                      </div>
                      <div>
                        <span class="font-medium text-gray-700">Rating:</span>
                        <span class="ml-2"><%= Float.round(crew.rating || 0, 1) %> ⭐</span>
                      </div>
                      <%= if crew.skills && length(crew.skills) > 0 do %>
                        <div>
                          <span class="font-medium text-gray-700 block mb-1">Skills:</span>
                          <div class="flex flex-wrap gap-1">
                            <%= for skill <- crew.skills do %>
                              <span class="inline-block bg-blue-100 text-blue-800 px-2 py-1 rounded text-xs">
                                <%= skill %>
                              </span>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="text-center py-12">
                <p class="text-gray-600 text-lg">No available crew members</p>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_datetime(datetime) do
    if datetime do
      datetime
      |> DateTime.shift_zone!("America/Los_Angeles")
      |> Calendar.strftime("%b %d, %l:%M %p")
    else
      "N/A"
    end
  end
end
