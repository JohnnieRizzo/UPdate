defmodule GratefulSetCrewWeb.HomeLive do
  use GratefulSetCrewWeb, :live_view

  on_mount {GratefulSetCrewWeb.UserAuth, :ensure_current_scope}

  alias GratefulSetCrew.Accounts

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to crew status changes
    Phoenix.PubSub.subscribe(GratefulSetCrew.PubSub, "crew:status_changed")

    # Load available crew
    available_crew = Accounts.list_available_crew()

    {:ok, assign(socket, crew: available_crew)}
  end

  @impl true
  def handle_info({:crew_status_changed, _crew_id}, socket) do
    # Reload crew list when status changes
    available_crew = Accounts.list_available_crew()
    {:noreply, assign(socket, crew: available_crew)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Main Content -->
      <div class="mx-auto max-w-7xl px-6 py-12">
        <!-- CTA Section for unauthenticated users -->
        <% current_scope = Map.get(assigns, :current_scope) %>
        <%= if !current_scope || !current_scope.user do %>
          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-8 mb-12">
            <div class="h-0.5 bg-gradient-to-r from-[#D4AF37] via-[#f0d060] to-[#D4AF37] -mx-8 -mt-8 mb-8 rounded-t-xl"></div>
            <h2 class="text-2xl font-bold text-white">Get Started</h2>
            <p class="mt-2 text-zinc-400">Join GratefulSetCrew to post jobs or find work</p>
            <div class="mt-6 space-x-4">
              <a href={~p"/users/register"} class="bg-[#D4AF37] text-black font-semibold rounded-lg px-6 py-2 hover:bg-[#c9a227] transition-colors inline-block">
                Sign Up
              </a>
              <a href={~p"/users/log-in"} class="border border-zinc-700 text-zinc-400 font-semibold rounded-lg px-6 py-2 hover:border-[#D4AF37] hover:text-[#D4AF37] transition-colors inline-block">
                Log In
              </a>
            </div>
          </div>
        <% end %>

        <!-- Crew Grid -->
        <div class="mt-12">
          <h2 class="mb-8 text-2xl font-bold text-white">Available Crew Members</h2>

          <%= if Enum.empty?(@crew) do %>
            <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-8 text-center">
              <p class="text-zinc-500">No crew members available at the moment.</p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
              <%= for crew <- @crew do %>
                <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6 hover:border-zinc-700 transition-colors">
                  <div class="flex items-start justify-between">
                    <div>
                      <h3 class="text-lg font-semibold text-white">
                        <%= crew.full_name || "Crew Member" %>
                      </h3>
                      <p class="text-sm text-zinc-500"><%= crew.location %></p>
                    </div>
                    <div class="inline-block rounded-full bg-emerald-900/60 px-3 py-1">
                      <span class="text-sm font-semibold text-emerald-400">Available</span>
                    </div>
                  </div>

                  <div class="mt-4">
                    <p class="text-sm text-zinc-400">
                      <strong>Rating:</strong> <%= Float.round(crew.rating || 0, 1) %>/5.0
                    </p>
                    <p class="mt-1 text-sm text-zinc-400">
                      <strong>Jobs Completed:</strong> <%= crew.completed_jobs || 0 %>
                    </p>
                  </div>

                  <%= if !Enum.empty?(crew.skills) do %>
                    <div class="mt-4">
                      <p class="mb-2 text-sm font-semibold text-zinc-400">Skills:</p>
                      <div class="flex flex-wrap gap-2">
                        <%= for skill <- Enum.take(crew.skills, 3) do %>
                          <span class="inline-block rounded-full bg-zinc-800 text-zinc-300 px-3 py-1 text-sm font-medium">
                            <%= skill %>
                          </span>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <%= if current_scope && current_scope.user && current_scope.user.role == "client" do %>
                    <div class="mt-6">
                      <button class="w-full bg-[#D4AF37] text-black px-4 py-2 text-white font-semibold hover:bg-[#c9a227] transition-colors rounded-lg">
                        Contact
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
