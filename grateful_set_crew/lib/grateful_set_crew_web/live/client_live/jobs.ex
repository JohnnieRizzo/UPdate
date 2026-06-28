defmodule GratefulSetCrewWeb.ClientLive.Jobs do
  use GratefulSetCrewWeb, :live_view

  alias GratefulSetCrew.Jobs

  on_mount {GratefulSetCrewWeb.UserAuth, :ensure_current_user}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    jobs = Jobs.list_jobs_by_client(current_user.id)

    {:ok,
     socket
     |> assign(:page_title, "My Jobs")
     |> assign(:jobs, jobs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12">
        <!-- Header -->
        <div class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-white">My Jobs</h1>
            <p class="mt-2 text-zinc-400">Manage all your posted jobs and applications</p>
          </div>
          <.link
            navigate={~p"/client/jobs/new"}
            class="bg-[#D4AF37] text-black hover:bg-[#c9a227] font-semibold rounded-lg px-6 py-3 transition-colors"
          >
            Post New Job
          </.link>
        </div>

        <!-- Jobs List -->
        <%= if Enum.empty?(@jobs) do %>
          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-12 text-center">
            <p class="text-zinc-400 mb-4">You haven't posted any jobs yet.</p>
            <.link
              navigate={~p"/client/jobs/new"}
              class="bg-[#D4AF37] text-black hover:bg-[#c9a227] font-semibold rounded-lg px-6 py-3 transition-colors inline-block"
            >
              Post Your First Job
            </.link>
          </div>
        <% else %>
          <div class="grid gap-6">
            <%= for job <- @jobs do %>
              <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6 hover:border-zinc-700 transition-colors">
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <h2 class="text-2xl font-bold text-white mb-2">
                      <%= job.title %>
                    </h2>
                    <p class="text-zinc-400 mb-4">
                      <%= String.slice(job.description, 0, 150) %><%= if String.length(job.description) > 150 do %>...<% end %>
                    </p>
                    <div class="flex gap-6 mb-4">
                      <div class="flex items-center gap-2 text-zinc-300">
                        <span class="font-semibold">📍</span>
                        <%= job.location || "Remote" %>
                      </div>
                      <div class="flex items-center gap-2 text-zinc-300">
                        <span class="font-semibold">💵</span>
                        $<%= number_to_string(job.hourly_rate) %>/hr
                      </div>
                      <div class="flex items-center gap-2 text-zinc-300">
                        <span class="font-semibold">⏱️</span>
                        ~<%= job.estimated_hours %> hours
                      </div>
                    </div>
                    <div class="flex gap-2">
                      <%!-- <span class={status_badge_class(job.status)}>
                        <%= status_badge(job.status) %>
                      </span>
                      <span class={payment_status_badge_class(job.payment_status)}>
                        <%= payment_status_badge(job.payment_status) %>
                      </span> --%>
                    </div>
                  </div>
                  <div class="flex gap-2 ml-4">
                    <.link
                      navigate={~p"/client/jobs/#{job.id}/edit"}
                      class="bg-zinc-800 text-zinc-300 hover:bg-zinc-700 font-semibold rounded-lg px-4 py-2 transition-colors text-sm"
                    >
                      Edit
                    </.link>
                    <button
                      class="bg-red-600 text-white hover:bg-red-700 font-semibold rounded-lg px-4 py-2 transition-colors text-sm"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp status_badge(status) do
    case status do
      "open" -> "Open"
      "matching" -> "Matching"
      "assigned" -> "Assigned"
      "in_progress" -> "In Progress"
      "completed" -> "Completed"
      "cancelled" -> "Cancelled"
      _ -> String.capitalize(status)
    end
  end

  defp payment_status_badge(status) do
    case status do
      "pending" -> "Pending Payment"
      "completed" -> "Paid"
      _ -> String.capitalize(status)
    end
  end

  defp number_to_string(nil), do: "0"
  defp number_to_string(num), do: Float.round(num, 2) |> Float.to_string()
end
