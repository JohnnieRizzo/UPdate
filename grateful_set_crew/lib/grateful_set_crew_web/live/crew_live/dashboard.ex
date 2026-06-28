defmodule GratefulSetCrewWeb.CrewLive.Dashboard do
  use GratefulSetCrewWeb, :live_view

  on_mount {GratefulSetCrewWeb.UserAuth, :ensure_current_scope}

  alias GratefulSetCrew.{Accounts, Notifications}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Subscribe to real-time updates
    Phoenix.PubSub.subscribe(GratefulSetCrew.PubSub, "jobs:open")
    Phoenix.PubSub.subscribe(GratefulSetCrew.PubSub, "notifications:#{user.id}")

    # Load initial data
    crew_profile =
      case Accounts.get_crew_profile(user.id) do
        nil ->
          {:ok, profile} = Accounts.create_crew_profile(%{user_id: user.id})
          profile

        profile ->
          profile
      end

    notifications = Notifications.list_unread_notifications(user.id)

    socket =
      socket
      |> assign(user_id: user.id)
      |> assign(crew_profile: crew_profile)
      |> assign(notifications: notifications)
      |> assign(show_notifications: false)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_availability", _params, socket) do
    crew_profile = socket.assigns.crew_profile
    new_status = if crew_profile.availability_status == "available", do: "offline", else: "available"

    case Accounts.update_crew_availability(socket.assigns.user_id, new_status == "available") do
      {:ok, updated_crew} ->
        {:noreply, assign(socket, crew_profile: updated_crew)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end


  @impl true
  def handle_event("toggle_notifications", _params, socket) do
    {:noreply, update(socket, :show_notifications, &!&1)}
  end

  @impl true
  def handle_event("mark_notification_read", %{"notification_id" => notification_id}, socket) do
    notification = Notifications.get_notification!(notification_id)
    Notifications.mark_notification_read(notification)

    notifications = Notifications.list_unread_notifications(socket.assigns.user_id)
    {:noreply, assign(socket, notifications: notifications)}
  end

  @impl true
  def handle_info({:job_created, _job}, socket) do
    # New jobs are available - no action needed on dashboard
    # Users can browse at /crew/jobs
    {:noreply, socket}
  end

  @impl true
  def handle_info({:notification_created, notification}, socket) do
    if notification.user_id == socket.assigns.user_id do
      notifications = Notifications.list_unread_notifications(socket.assigns.user_id)
      {:noreply, assign(socket, notifications: notifications)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Header with availability toggle -->
      <div class="bg-zinc-900/60 border-b border-zinc-800 px-6 py-8">
        <div class="mx-auto max-w-7xl">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-white">Crew Dashboard</h1>
              <p class="mt-2 text-zinc-400">Manage your work and earnings</p>
            </div>

            <div class="flex items-center gap-4">
              <!-- Notifications bell -->
              <div class="relative">
                <button
                  phx-click="toggle_notifications"
                  class="relative rounded-lg p-2 text-zinc-400 hover:bg-zinc-800"
                >
                  🔔
                  <%= if length(@notifications) > 0 do %>
                    <span class="absolute right-0 top-0 inline-flex items-center justify-center rounded-full bg-red-600 px-2 py-1 text-xs font-bold leading-none text-white">
                      <%= length(@notifications) %>
                    </span>
                  <% end %>
                </button>

                <!-- Notifications dropdown -->
                <%= if @show_notifications do %>
                  <div class="absolute right-0 mt-2 w-96 rounded-xl bg-zinc-900 border border-zinc-800 shadow-2xl z-50">
                    <div class="p-4 border-b border-zinc-800">
                      <h3 class="font-semibold text-white">Notifications</h3>
                    </div>
                    <%= if length(@notifications) > 0 do %>
                      <div class="max-h-96 overflow-y-auto">
                        <%= for notification <- @notifications do %>
                          <div class="border-b border-zinc-800 p-4 hover:bg-zinc-800/50">
                            <div class="flex items-start justify-between">
                              <div class="flex-1">
                                <h4 class="font-medium text-white"><%= notification.title %></h4>
                                <p class="mt-1 text-sm text-zinc-400"><%= notification.body %></p>
                              </div>
                              <button
                                phx-click="mark_notification_read"
                                phx-value-notification-id={notification.id}
                                class="text-[#D4AF37] hover:text-[#c9a227] text-sm"
                              >
                                ✓
                              </button>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    <% else %>
                      <div class="p-4 text-center text-zinc-500">
                        No notifications
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <!-- Availability toggle -->
              <button
                phx-click="toggle_availability"
                class={
                  "font-semibold rounded-lg px-6 py-2 transition-colors #{
                    if @crew_profile.availability_status == "available",
                    do: "bg-emerald-600 text-white hover:bg-emerald-700",
                    else: "bg-zinc-700 text-zinc-300 hover:bg-zinc-600"
                  }"
                }
              >
                <%= if @crew_profile.availability_status == "available", do: "● Available", else: "● Offline" %>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Main content -->
      <div class="mx-auto max-w-7xl px-6 py-12">
        <!-- Metrics -->
        <div class="grid grid-cols-1 gap-6 md:grid-cols-3 mb-12">
          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
            <p class="text-sm font-semibold text-[#D4AF37] uppercase tracking-widest">Status</p>
            <p class={
              ["mt-2 text-3xl font-bold",
               (if @crew_profile.availability_status == "available", do: "text-emerald-400", else: "text-zinc-500")]
            }>
              <%= @crew_profile.availability_status |> String.capitalize() %>
            </p>
          </div>
          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
            <p class="text-sm font-semibold text-[#D4AF37] uppercase tracking-widest">Completed Jobs</p>
            <p class="mt-2 text-3xl font-bold text-[#D4AF37]"><%= @crew_profile.completed_jobs || 0 %></p>
          </div>
          <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
            <p class="text-sm font-semibold text-[#D4AF37] uppercase tracking-widest">Rating</p>
            <p class="mt-2 text-3xl font-bold text-yellow-400"><%= Float.round(@crew_profile.rating || 0, 1) %> ⭐</p>
          </div>
        </div>

        <!-- Browse Jobs CTA -->
        <div class="bg-zinc-900 border border-zinc-800 rounded-xl p-8">
          <h2 class="text-2xl font-bold text-white mb-2">Looking for work?</h2>
          <p class="text-zinc-400 mb-6">Browse and apply for available jobs in your area</p>
          <a
            href={~p"/crew/jobs"}
            class="inline-block bg-[#D4AF37] text-black hover:bg-[#c9a227] font-semibold rounded-lg px-6 py-2 transition-colors"
          >
            Browse Jobs →
          </a>
        </div>
      </div>
    </div>
    """
  end
end
