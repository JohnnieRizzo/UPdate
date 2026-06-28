defmodule GratefulSetCrewWeb.ClientLive.Dashboard do
  use GratefulSetCrewWeb, :live_view

  on_mount {GratefulSetCrewWeb.UserAuth, :ensure_current_scope}

  alias GratefulSetCrew.{Accounts, Jobs, Notifications}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Subscribe to real-time updates
    Phoenix.PubSub.subscribe(GratefulSetCrew.PubSub, "jobs:updated")

    # Load initial data
    client_jobs = Jobs.list_jobs_by_client(user.id)
    client_profile = Accounts.get_client_profile(user.id)

    socket =
      socket
      |> assign(user_id: user.id)
      |> assign(client_profile: client_profile)
      |> assign(jobs: client_jobs)
      |> assign(show_form: false)
      |> assign(form_data: %{
        "title" => "",
        "description" => "",
        "location" => "",
        "required_skills" => "",
        "hourly_rate" => "",
        "estimated_hours" => ""
      })

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, update(socket, :show_form, &!&1)}
  end

  @impl true
  def handle_event("update_form", %{"job" => form_data}, socket) do
    {:noreply, assign(socket, form_data: form_data)}
  end

  @impl true
  def handle_event("submit_job", %{"job" => form_data}, socket) do
    case create_job(form_data, socket.assigns.user_id) do
      {:ok, _job} ->
        # Reset form
        socket =
          socket
          |> assign(show_form: false)
          |> assign(form_data: %{
            "title" => "",
            "description" => "",
            "location" => "",
            "required_skills" => "",
            "hourly_rate" => "",
            "estimated_hours" => ""
          })

        # Reload jobs
        client_jobs = Jobs.list_jobs_by_client(socket.assigns.user_id)
        {:noreply, assign(socket, jobs: client_jobs)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_job", %{"job_id" => job_id}, socket) do
    job = Jobs.get_job!(job_id)
    Jobs.update_job(job, %{status: "cancelled"})

    # Notify assigned crew if any
    if job.crew_id do
      Notifications.notify(
        job.crew_id,
        "Job Cancelled",
        "The job #{job.title} has been cancelled",
        "job_cancelled"
      )
    end

    # Reload jobs
    client_jobs = Jobs.list_jobs_by_client(socket.assigns.user_id)
    {:noreply, assign(socket, jobs: client_jobs)}
  end

  @impl true
  def handle_info({:job_updated, updated_job}, socket) do
    if updated_job.client_id == socket.assigns.user_id do
      client_jobs = Jobs.list_jobs_by_client(socket.assigns.user_id)
      {:noreply, assign(socket, jobs: client_jobs)}
    else
      {:noreply, socket}
    end
  end

  defp create_job(form_data, client_id) do
    attrs = %{
      client_id: client_id,
      title: form_data["title"],
      description: form_data["description"],
      location: form_data["location"],
      required_skills: parse_skills(form_data["required_skills"]),
      hourly_rate: parse_float(form_data["hourly_rate"]),
      estimated_hours: parse_integer(form_data["estimated_hours"]),
      status: "open"
    }

    Jobs.create_job(attrs)
  end

  defp parse_skills(skills_string) when is_binary(skills_string) do
    skills_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(byte_size(&1) > 0))
  end

  defp parse_skills(_), do: []

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> nil
    end
  end

  defp parse_float(_), do: nil

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_integer(_), do: nil

  defp job_status_badge(status) do
    case status do
      "open" -> "bg-[#D4AF37]/10 text-[#D4AF37]"
      "assigned" -> "bg-blue-900/60 text-blue-400"
      "completed" -> "bg-emerald-900/60 text-emerald-400"
      "cancelled" -> "bg-red-900/60 text-red-400"
      _ -> "bg-zinc-800 text-zinc-400"
    end
  end

  defp active_jobs(jobs) do
    Enum.filter(jobs, &(&1.status in ["open", "assigned", "matching"]))
  end

  defp completed_jobs(jobs) do
    Enum.filter(jobs, &(&1.status == "completed"))
  end

  defp total_spent(jobs) do
    jobs
    |> Enum.filter(&(&1.status == "completed"))
    |> Enum.reduce(0.0, fn job, acc ->
      rate = job.hourly_rate || 0
      hours = job.estimated_hours || 0
      acc + rate * hours
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Header -->
      <div class="bg-zinc-900/60 border-b border-zinc-800 px-6 py-8">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-white">Client Dashboard</h1>
              <p class="mt-2 text-zinc-400">Post jobs and find crew members to complete them</p>
            </div>

            <button
              phx-click="toggle_form"
              class="bg-[#D4AF37] text-black hover:bg-[#c9a227] font-semibold rounded-lg px-6 py-3 transition-colors"
            >
              + Post a Job
            </button>
          </div>
        </div>
      </div>

      <!-- Main Content -->
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12">
        <!-- Metrics -->
        <div class="grid grid-cols-1 gap-6 md:grid-cols-3 mb-12">
          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
            <h3 class="text-lg font-semibold text-zinc-300">Active Jobs</h3>
            <p class="mt-2 text-3xl font-bold text-[#D4AF37]"><%= length(active_jobs(@jobs)) %></p>
          </div>
          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
            <h3 class="text-lg font-semibold text-zinc-300">Completed Jobs</h3>
            <p class="mt-2 text-3xl font-bold text-emerald-400"><%= length(completed_jobs(@jobs)) %></p>
          </div>
          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
            <h3 class="text-lg font-semibold text-zinc-300">Total Spent</h3>
            <p class="mt-2 text-3xl font-bold text-[#D4AF37]">$<%= Float.round(total_spent(@jobs), 2) %></p>
          </div>
        </div>

        <!-- Job Posting Form -->
        <%= if @show_form do %>
          <div class="mb-8 rounded-xl bg-zinc-900 border border-zinc-800 p-8">
            <div class="h-0.5 bg-gradient-to-r from-[#D4AF37] via-[#f0d060] to-[#D4AF37] -mx-8 mb-8 -mt-8 rounded-t-xl"></div>
            <h2 class="text-2xl font-bold text-white mb-6">Post a New Job</h2>

            <form phx-submit="submit_job" class="space-y-6">
              <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">Job Title</label>
                  <input
                    type="text"
                    name="job[title]"
                    value={@form_data["title"]}
                    phx-change="update_form"
                    required
                    class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                    placeholder="e.g., Landscaping service needed"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">Location</label>
                  <input
                    type="text"
                    name="job[location]"
                    value={@form_data["location"]}
                    phx-change="update_form"
                    required
                    class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                    placeholder="e.g., 123 Main St, San Francisco"
                  />
                </div>
              </div>

              <div>
                <label class="block text-sm font-medium text-zinc-300 mb-2">Description</label>
                <textarea
                  name="job[description]"
                  value={@form_data["description"]}
                  phx-change="update_form"
                  required
                  rows="4"
                  class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                  placeholder="Describe the job details..."
                />
              </div>

              <div class="grid grid-cols-1 gap-6 md:grid-cols-3">
                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">Hourly Rate ($)</label>
                  <input
                    type="number"
                    name="job[hourly_rate]"
                    value={@form_data["hourly_rate"]}
                    phx-change="update_form"
                    step="0.01"
                    min="0"
                    class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                    placeholder="50.00"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">Estimated Hours</label>
                  <input
                    type="number"
                    name="job[estimated_hours]"
                    value={@form_data["estimated_hours"]}
                    phx-change="update_form"
                    min="1"
                    class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                    placeholder="8"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">Estimated Cost</label>
                  <div class="mt-8 text-2xl font-bold text-[#D4AF37]">
                    $<%= Float.round(
                      (parse_float(@form_data["hourly_rate"]) || 0.0) * (parse_integer(@form_data["estimated_hours"]) || 0),
                      2
                    ) %>
                  </div>
                </div>
              </div>

              <div>
                <label class="block text-sm font-medium text-zinc-300 mb-2">Required Skills (comma-separated)</label>
                <input
                  type="text"
                  name="job[required_skills]"
                  value={@form_data["required_skills"]}
                  phx-change="update_form"
                  class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                  placeholder="e.g., pruning, landscaping, safety certification"
                />
              </div>

              <div class="flex gap-4 pt-4">
                <button
                  type="submit"
                  class="flex-1 bg-[#D4AF37] text-black hover:bg-[#c9a227] font-semibold rounded-lg px-6 py-3 transition-colors"
                >
                  Post Job
                </button>
                <button
                  type="button"
                  phx-click="toggle_form"
                  class="flex-1 border border-zinc-700 text-zinc-400 hover:border-[#D4AF37] hover:text-[#D4AF37] font-semibold rounded-lg px-6 py-3 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        <% end %>

        <!-- Jobs List -->
        <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-8">
          <h2 class="text-2xl font-bold text-white mb-6">Your Jobs</h2>

          <%= if length(@jobs) > 0 do %>
            <div class="space-y-4">
              <%= for job <- @jobs do %>
                <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6 hover:border-zinc-700 transition-colors">
                  <div class="flex items-start justify-between mb-4">
                    <div class="flex-1">
                      <h3 class="text-lg font-semibold text-white"><%= job.title %></h3>
                      <p class="mt-1 text-sm text-zinc-500"><%= job.location %></p>
                    </div>
                    <span class={"inline-block px-3 py-1 rounded-full text-sm font-medium " <> job_status_badge(job.status)}>
                      <%= String.capitalize(job.status) %>
                    </span>
                  </div>

                  <p class="text-zinc-400 mb-4"><%= job.description %></p>

                  <div class="grid grid-cols-1 gap-3 md:grid-cols-4 text-sm mb-4">
                    <div>
                      <span class="font-medium text-zinc-400">Rate:</span>
                      <p class="text-zinc-300">$<%= Float.round(job.hourly_rate || 0.0, 2) %>/hr</p>
                    </div>
                    <div>
                      <span class="font-medium text-zinc-400">Duration:</span>
                      <p class="text-zinc-300"><%= job.estimated_hours || 0 %> hours</p>
                    </div>
                    <div>
                      <span class="font-medium text-zinc-400">Total Cost:</span>
                      <p class="text-zinc-300">$<%= Float.round((job.hourly_rate || 0.0) * (job.estimated_hours || 0), 2) %></p>
                    </div>
                    <div>
                      <span class="font-medium text-zinc-400">Assigned To:</span>
                      <p class="text-zinc-300">
                        <%= if job.crew_id do %>
                          Crew Member #<%= String.slice(job.crew_id, 0..7) %>
                        <% else %>
                          Looking for crew
                        <% end %>
                      </p>
                    </div>
                  </div>

                  <%= if job.required_skills && length(job.required_skills) > 0 do %>
                    <div class="mb-4">
                      <span class="text-sm font-medium text-zinc-400 block mb-2">Required Skills:</span>
                      <div class="flex flex-wrap gap-2">
                        <%= for skill <- job.required_skills do %>
                          <span class="inline-block bg-zinc-800 text-zinc-300 rounded-full px-3 py-1 text-sm">
                            <%= skill %>
                          </span>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <%= if job.status != "completed" && job.status != "cancelled" do %>
                    <div class="flex gap-2 pt-4 border-t border-zinc-800">
                      <button
                        phx-click="cancel_job"
                        phx-value-job-id={job.id}
                        class="bg-red-600 text-white hover:bg-red-700 font-semibold rounded px-4 py-2 transition-colors text-sm"
                      >
                        Cancel Job
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% else %>
            <div class="text-center py-12">
              <p class="text-zinc-400 text-lg">No jobs posted yet</p>
              <p class="text-zinc-500 mt-2">Start by posting your first job above</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
