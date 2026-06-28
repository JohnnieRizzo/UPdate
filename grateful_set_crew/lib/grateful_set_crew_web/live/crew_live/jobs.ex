defmodule GratefulSetCrewWeb.CrewLive.Jobs do
  use GratefulSetCrewWeb, :live_view

  on_mount {GratefulSetCrewWeb.UserAuth, :ensure_current_scope}

  alias GratefulSetCrew.{Accounts, Jobs}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Subscribe to real-time job updates
    Phoenix.PubSub.subscribe(GratefulSetCrew.PubSub, "jobs:open")
    Phoenix.PubSub.subscribe(GratefulSetCrew.PubSub, "jobs:updated")

    crew_profile = Accounts.get_crew_profile(user.id)

    # Get all available skills for filter dropdown
    available_skills = Jobs.get_all_skills()

    # Initial load with default filters
    filters = %{
      search: "",
      location: "",
      min_rate: nil,
      max_rate: nil,
      skills: [],
      status: ["open", "matching"],
      sort_by: :posted_date
    }

    jobs_with_scores = Jobs.list_available_jobs_for_crew(user.id, filters)

    socket =
      socket
      |> assign(user_id: user.id)
      |> assign(crew_profile: crew_profile)
      |> assign(jobs_with_scores: jobs_with_scores)
      |> assign(filters: filters)
      |> assign(available_skills: available_skills)
      |> assign(show_filters: false)
      |> assign(show_detail: false)
      |> assign(selected_job: nil)
      |> assign(selected_job_match_score: nil)
      |> assign(selected_job_application_status: nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    filters = Map.put(socket.assigns.filters, :search, query)
    jobs_with_scores = Jobs.list_available_jobs_for_crew(socket.assigns.user_id, filters)

    {:noreply, assign(socket, filters: filters, jobs_with_scores: jobs_with_scores)}
  end

  @impl true
  def handle_event("update_filters", params, socket) do
    filters = parse_filter_params(params, socket.assigns.filters)
    jobs_with_scores = Jobs.list_available_jobs_for_crew(socket.assigns.user_id, filters)

    {:noreply, assign(socket, filters: filters, jobs_with_scores: jobs_with_scores)}
  end

  @impl true
  def handle_event("change_sort", %{"sort" => sort}, socket) do
    sort_atom = String.to_existing_atom(sort)
    filters = Map.put(socket.assigns.filters, :sort_by, sort_atom)
    jobs_with_scores = Jobs.list_available_jobs_for_crew(socket.assigns.user_id, filters)

    {:noreply, assign(socket, filters: filters, jobs_with_scores: jobs_with_scores)}
  end

  @impl true
  def handle_event("toggle_filter", _params, socket) do
    {:noreply, update(socket, :show_filters, &!&1)}
  end

  @impl true
  def handle_event("view_details", %{"job_id" => job_id}, socket) do
    job_with_score = Enum.find(socket.assigns.jobs_with_scores, &(&1.job.id == job_id))

    if job_with_score do
      {:noreply,
       assign(socket,
         show_detail: true,
         selected_job: job_with_score.job,
         selected_job_match_score: job_with_score.match_score,
         selected_job_application_status: job_with_score.application_status
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_detail", _params, socket) do
    {:noreply, assign(socket, show_detail: false, selected_job: nil)}
  end

  @impl true
  def handle_event("apply_for_job", %{"job_id" => job_id}, socket) do
    case Jobs.apply_for_job(job_id, socket.assigns.user_id) do
      {:ok, _application} ->
        # Reload the jobs to update application status
        jobs_with_scores = Jobs.list_available_jobs_for_crew(socket.assigns.user_id, socket.assigns.filters)

        # Update selected job status if it's currently displayed
        updated_socket = assign(socket, jobs_with_scores: jobs_with_scores)

        if socket.assigns.show_detail && socket.assigns.selected_job.id == job_id do
          updated_job_with_score = Enum.find(jobs_with_scores, &(&1.job.id == job_id))

          {:noreply,
           assign(updated_socket,
             selected_job_application_status: updated_job_with_score.application_status
           )}
        else
          {:noreply, updated_socket}
        end

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:job_created, _job}, socket) do
    jobs_with_scores = Jobs.list_available_jobs_for_crew(socket.assigns.user_id, socket.assigns.filters)
    {:noreply, assign(socket, jobs_with_scores: jobs_with_scores)}
  end

  @impl true
  def handle_info({:job_updated, _job}, socket) do
    jobs_with_scores = Jobs.list_available_jobs_for_crew(socket.assigns.user_id, socket.assigns.filters)
    {:noreply, assign(socket, jobs_with_scores: jobs_with_scores)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Header -->
      <div class="bg-zinc-900/60 border-b border-zinc-800 px-6 py-8">
        <div class="mx-auto max-w-7xl">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-white">Browse Jobs</h1>
              <p class="mt-2 text-zinc-400">Discover and apply for available gigs</p>
            </div>

            <button
              phx-click="toggle_filter"
              class="border border-zinc-700 text-zinc-400 hover:border-[#D4AF37] hover:text-[#D4AF37] font-semibold rounded-lg px-6 py-2 transition-colors md:hidden"
            >
              <%= if @show_filters, do: "Hide Filters", else: "Show Filters" %>
            </button>
          </div>
        </div>
      </div>

      <!-- Main content -->
      <div class="mx-auto max-w-7xl px-6 py-12">
        <div class="grid grid-cols-1 gap-8 md:grid-cols-4">
          <!-- Filters Panel -->
          <div class={
            [
              "space-y-6",
              "md:block md:col-span-1",
              (if !@show_filters, do: "hidden", else: "block")
            ]
          }>
            <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
              <h2 class="mb-4 text-lg font-bold text-white">Search & Filter</h2>

              <!-- Search -->
              <div class="mb-6">
                <label class="block text-sm font-medium text-zinc-400 mb-2">Search</label>
                <input
                  type="text"
                  name="search"
                  value={@filters.search}
                  phx-debounce="300"
                  phx-change="search"
                  placeholder="Job title or keywords"
                  class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                />
              </div>

              <!-- Location filter -->
              <div class="mb-6">
                <label class="block text-sm font-medium text-zinc-400 mb-2">Location</label>
                <input
                  type="text"
                  name="location"
                  value={@filters.location}
                  phx-debounce="300"
                  phx-change="update_filters"
                  placeholder="City or region"
                  class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                />
              </div>

              <!-- Rate range -->
              <div class="mb-6">
                <label class="block text-sm font-medium text-zinc-400 mb-2">Hourly Rate</label>
                <div class="grid grid-cols-2 gap-2">
                  <input
                    type="number"
                    name="min_rate"
                    value={@filters.min_rate}
                    phx-change="update_filters"
                    placeholder="Min"
                    class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                  />
                  <input
                    type="number"
                    name="max_rate"
                    value={@filters.max_rate}
                    phx-change="update_filters"
                    placeholder="Max"
                    class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                  />
                </div>
              </div>

              <!-- Skills filter -->
              <div class="mb-6">
                <label class="block text-sm font-medium text-zinc-400 mb-2">Skills</label>
                <div class="space-y-2">
                  <%= for skill <- @available_skills do %>
                    <label class="flex items-center">
                      <input
                        type="checkbox"
                        name="skills"
                        value={skill}
                        checked={skill in @filters.skills}
                        phx-change="update_filters"
                        class="h-4 w-4 rounded border-zinc-600 bg-zinc-800 text-[#D4AF37] focus:ring-[#D4AF37]"
                      />
                      <span class="ml-2 text-sm text-zinc-300"><%= skill %></span>
                    </label>
                  <% end %>
                </div>
              </div>

              <!-- Sort -->
              <div class="mb-6">
                <label class="block text-sm font-medium text-zinc-400 mb-2">Sort By</label>
                <select
                  name="sort"
                  value={Atom.to_string(@filters.sort_by)}
                  phx-change="change_sort"
                  class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37]"
                >
                  <option value="posted_date">Newest First</option>
                  <option value="rate_high">Hourly Rate (High to Low)</option>
                  <option value="rate_low">Hourly Rate (Low to High)</option>
                  <option value="relevance">Match Score</option>
                </select>
              </div>
            </div>
          </div>

          <!-- Job Cards -->
          <div class="md:col-span-3">
            <%= if length(@jobs_with_scores) > 0 do %>
              <div class="space-y-4">
                <%= for job_with_score <- @jobs_with_scores do %>
                  <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6 hover:border-zinc-700 transition-colors">
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <h3 class="text-lg font-semibold text-white">
                          <%= job_with_score.job.title %>
                        </h3>

                        <p class="mt-2 text-zinc-300 line-clamp-2">
                          <%= job_with_score.job.description %>
                        </p>

                        <!-- Job details -->
                        <div class="mt-4 grid grid-cols-2 gap-4 md:grid-cols-4">
                          <div>
                            <span class="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Location</span>
                            <p class="text-zinc-300"><%= job_with_score.job.location %></p>
                          </div>
                          <div>
                            <span class="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Rate</span>
                            <p class="text-zinc-300">$<%= Float.round(job_with_score.job.hourly_rate, 2) %>/hr</p>
                          </div>
                          <div>
                            <span class="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Duration</span>
                            <p class="text-zinc-300"><%= job_with_score.job.estimated_hours %> hours</p>
                          </div>
                          <div>
                            <span class="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Match</span>
                            <p class="text-lg font-bold text-[#D4AF37]">
                              <%= Float.round(job_with_score.match_score, 0) %>%
                            </p>
                          </div>
                        </div>

                        <!-- Skills -->
                        <%= if job_with_score.job.required_skills && length(job_with_score.job.required_skills) > 0 do %>
                          <div class="mt-4">
                            <span class="text-xs font-semibold text-zinc-400 uppercase tracking-wider block mb-2">
                              Required Skills
                            </span>
                            <div class="flex flex-wrap gap-2">
                              <%= for skill <- job_with_score.job.required_skills do %>
                                <span class="bg-zinc-800 text-zinc-300 rounded-full px-3 py-1 text-xs font-medium">
                                  <%= skill %>
                                </span>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>

                      <!-- Action buttons -->
                      <div class="ml-4 flex flex-col gap-2">
                        <button
                          phx-click="view_details"
                          phx-value-job-id={job_with_score.job.id}
                          class="whitespace-nowrap border border-zinc-700 text-zinc-400 hover:border-[#D4AF37] hover:text-[#D4AF37] font-semibold rounded-lg px-6 py-2 transition-colors"
                        >
                          Details
                        </button>

                        <%= if job_with_score.application_status do %>
                          <div class="rounded-lg bg-zinc-800 px-4 py-2 text-center">
                            <span class="text-xs font-semibold text-zinc-400 uppercase">
                              <%= job_with_score.application_status %>
                            </span>
                          </div>
                        <% else %>
                          <button
                            phx-click="apply_for_job"
                            phx-value-job-id={job_with_score.job.id}
                            class="whitespace-nowrap bg-emerald-600 text-white hover:bg-emerald-700 font-semibold rounded-lg px-6 py-2 transition-colors"
                          >
                            Apply Now
                          </button>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-12 text-center">
                <p class="text-zinc-400 text-lg">No jobs found matching your criteria</p>
                <p class="text-zinc-500 mt-2">Try adjusting your filters or check back soon</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Detail Modal -->
      <%= if @show_detail && @selected_job do %>
        <.job_detail_modal
          job={@selected_job}
          match_score={@selected_job_match_score}
          application_status={@selected_job_application_status}
        />
      <% end %>
    </div>
    """
  end

  defp job_detail_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <div class="flex min-h-full items-end justify-center px-4 pt-4 pb-20 text-center sm:block sm:p-0">
        <!-- Backdrop -->
        <div
          phx-click="close_detail"
          class="fixed inset-0 bg-black/80"
        ></div>

        <!-- Modal -->
        <div class="relative inline-block rounded-xl bg-zinc-900 border border-zinc-800 text-left shadow-2xl w-full max-w-2xl">
          <!-- Header -->
          <div class="border-b border-zinc-800 px-6 py-4 flex items-center justify-between">
            <h3 class="text-xl font-bold text-white"><%= @job.title %></h3>
            <button
              phx-click="close_detail"
              class="text-zinc-500 hover:text-zinc-300"
            >
              ✕
            </button>
          </div>

          <!-- Content -->
          <div class="px-6 py-4">
            <!-- Description -->
            <div class="mb-6">
              <h4 class="text-xs font-semibold text-zinc-400 uppercase mb-2">Description</h4>
              <p class="text-zinc-300"><%= @job.description %></p>
            </div>

            <!-- Details grid -->
            <div class="grid grid-cols-2 gap-6 mb-6">
              <div>
                <span class="text-xs font-semibold text-zinc-400 uppercase">Location</span>
                <p class="text-white text-lg"><%= @job.location %></p>
              </div>
              <div>
                <span class="text-xs font-semibold text-zinc-400 uppercase">Hourly Rate</span>
                <p class="text-white text-lg">$<%= Float.round(@job.hourly_rate, 2) %>/hr</p>
              </div>
              <div>
                <span class="text-xs font-semibold text-zinc-400 uppercase">Estimated Hours</span>
                <p class="text-white text-lg"><%= @job.estimated_hours %></p>
              </div>
              <div>
                <span class="text-xs font-semibold text-zinc-400 uppercase">Your Match Score</span>
                <p class="text-lg font-bold text-[#D4AF37]"><%= Float.round(@match_score, 0) %>%</p>
              </div>
            </div>

            <!-- Required skills -->
            <%= if @job.required_skills && length(@job.required_skills) > 0 do %>
              <div class="mb-6">
                <h4 class="text-xs font-semibold text-zinc-400 uppercase mb-2">Required Skills</h4>
                <div class="flex flex-wrap gap-2">
                  <%= for skill <- @job.required_skills do %>
                    <span class="bg-zinc-800 text-zinc-300 rounded-full px-3 py-1 text-xs font-medium">
                      <%= skill %>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Footer -->
          <div class="border-t border-zinc-800 px-6 py-4 flex justify-between">
            <button
              phx-click="close_detail"
              class="border border-zinc-700 text-zinc-400 hover:border-[#D4AF37] hover:text-[#D4AF37] font-semibold rounded-lg px-6 py-2 transition-colors"
            >
              Close
            </button>

            <%= if @application_status do %>
              <div class="rounded-lg bg-zinc-800 px-6 py-2 flex items-center">
                <span class="text-zinc-400 font-semibold uppercase text-sm"><%= @application_status %></span>
              </div>
            <% else %>
              <button
                phx-click="apply_for_job"
                phx-value-job-id={@job.id}
                class="bg-emerald-600 text-white hover:bg-emerald-700 font-semibold rounded-lg px-6 py-2 transition-colors"
              >
                Apply Now
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp parse_filter_params(params, current_filters) do
    filters = current_filters

    # Handle location
    filters = if Map.has_key?(params, "location") do
      Map.put(filters, :location, params["location"])
    else
      filters
    end

    # Handle min_rate
    filters = if Map.has_key?(params, "min_rate") && params["min_rate"] != "" do
      Map.put(filters, :min_rate, String.to_float(params["min_rate"]))
    else
      Map.put(filters, :min_rate, nil)
    end

    # Handle max_rate
    filters = if Map.has_key?(params, "max_rate") && params["max_rate"] != "" do
      Map.put(filters, :max_rate, String.to_float(params["max_rate"]))
    else
      Map.put(filters, :max_rate, nil)
    end

    # Handle skills (can be list or single value)
    skills = case Map.get(params, "skills") do
      nil -> []
      skills when is_list(skills) -> skills
      skill when is_binary(skill) -> [skill]
    end

    Map.put(filters, :skills, skills)
  end

end
