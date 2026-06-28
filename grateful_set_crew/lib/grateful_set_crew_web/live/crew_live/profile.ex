defmodule GratefulSetCrewWeb.CrewLive.Profile do
  use GratefulSetCrewWeb, :live_view

  on_mount {GratefulSetCrewWeb.UserAuth, :ensure_current_scope}

  alias GratefulSetCrew.{Accounts}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    crew_profile = Accounts.get_crew_profile(user.id)

    socket =
      socket
      |> assign(user_id: user.id)
      |> assign(user: user)
      |> assign(crew_profile: crew_profile)
      |> assign(edit_mode: false)
      |> assign(form_data: %{
        "full_name" => user.full_name || "",
        "phone" => user.phone || "",
        "skills" => Enum.join(crew_profile.skills || [], ", "),
        "certifications" => Enum.join(crew_profile.certifications || [], ", "),
        "bio" => crew_profile.bio || ""
      })
      |> assign(message: nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    {:noreply, update(socket, :edit_mode, &!&1)}
  end

  @impl true
  def handle_event("update_form", %{"profile" => form_data}, socket) do
    {:noreply, assign(socket, form_data: form_data)}
  end

  @impl true
  def handle_event("save_profile", %{"profile" => form_data}, socket) do
    case update_profile(socket, form_data) do
      {:ok, _user, _crew} ->
        user = Accounts.get_user!(socket.assigns.user_id)
        crew_profile = Accounts.get_crew_profile(socket.assigns.user_id)

        socket =
          socket
          |> assign(user: user)
          |> assign(crew_profile: crew_profile)
          |> assign(edit_mode: false)
          |> assign(message: "Profile updated successfully!")

        Process.send_after(self(), :clear_message, 3000)
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, assign(socket, message: "Error updating profile")}
    end
  end

  @impl true
  def handle_info(:clear_message, socket) do
    {:noreply, assign(socket, message: nil)}
  end

  defp update_profile(socket, form_data) do
    user = socket.assigns.user
    crew_profile = socket.assigns.crew_profile

    # Update user
    user_attrs = %{
      full_name: form_data["full_name"],
      phone: form_data["phone"]
    }

    user_changeset = Accounts.change_user(user, user_attrs)

    # Update crew profile
    crew_attrs = %{
      skills: parse_list(form_data["skills"]),
      certifications: parse_list(form_data["certifications"]),
      bio: form_data["bio"]
    }

    crew_changeset = Accounts.update_crew_profile(crew_profile, crew_attrs)

    case {Ecto.Changeset.apply_changes(user_changeset), crew_changeset} do
      {_, {:ok, updated_crew}} ->
        GratefulSetCrew.Repo.insert_or_update(user_changeset)
        {:ok, user, updated_crew}

      {_, {:error, reason}} ->
        {:error, reason}

      {_, error} ->
        {:error, error}
    end
  end

  defp parse_list(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(byte_size(&1) > 0))
  end

  defp parse_list(_), do: []

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Header -->
      <div class="bg-zinc-900/60 border-b border-zinc-800">
        <div class="mx-auto max-w-7xl px-6 py-8">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-white">My Profile</h1>
              <p class="mt-2 text-zinc-400">Update your skills, certifications, and profile information</p>
            </div>

            <button
              phx-click="toggle_edit"
              class={
                "rounded-lg px-6 py-3 text-white font-semibold transition-colors #{
                  if @edit_mode,
                  do: "bg-red-600 hover:bg-red-700",
                  else: "bg-[#D4AF37] text-black hover:bg-[#c9a227]"
                }"
              }
            >
              <%= if @edit_mode, do: "Cancel", else: "Edit Profile" %>
            </button>
          </div>
        </div>
      </div>

      <!-- Success Message -->
      <%= if @message do %>
        <div class="bg-emerald-950/60 border-l-4 border-emerald-500 text-emerald-400 p-4 mx-auto max-w-7xl mt-4 rounded-r-lg">
          <p><%= @message %></p>
        </div>
      <% end %>

      <!-- Main Content -->
      <div class="mx-auto max-w-7xl px-6 py-12">
        <%= if @edit_mode do %>
          <!-- Edit Form -->
          <form phx-submit="save_profile" class="space-y-6 rounded-xl bg-zinc-900 border border-zinc-800 p-8">
            <div>
              <label class="block text-sm font-medium text-zinc-300 mb-2">Full Name</label>
              <input
                type="text"
                name="profile[full_name]"
                value={@form_data["full_name"]}
                phx-change="update_form"
                class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                placeholder="Enter your full name"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-zinc-300 mb-2">Phone Number</label>
              <input
                type="tel"
                name="profile[phone]"
                value={@form_data["phone"]}
                phx-change="update_form"
                class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                placeholder="(555) 123-4567"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-zinc-300 mb-2">Bio</label>
              <textarea
                name="profile[bio]"
                value={@form_data["bio"]}
                phx-change="update_form"
                rows="4"
                class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                placeholder="Tell clients about yourself..."
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-zinc-300 mb-2">Skills (comma-separated)</label>
              <input
                type="text"
                name="profile[skills]"
                value={@form_data["skills"]}
                phx-change="update_form"
                class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                placeholder="e.g., landscaping, pruning, lawn care"
              />
              <p class="mt-2 text-sm text-zinc-500">Add skills separated by commas to help clients find you</p>
            </div>

            <div>
              <label class="block text-sm font-medium text-zinc-300 mb-2">
                Certifications (comma-separated)
              </label>
              <input
                type="text"
                name="profile[certifications]"
                value={@form_data["certifications"]}
                phx-change="update_form"
                class="w-full bg-zinc-800 border border-zinc-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] placeholder-zinc-500"
                placeholder="e.g., First Aid CPR, Safety Certification"
              />
              <p class="mt-2 text-sm text-zinc-500">List any professional certifications you hold</p>
            </div>

            <div class="flex gap-4 pt-4">
              <button
                type="submit"
                class="flex-1 bg-[#D4AF37] text-black hover:bg-[#c9a227] font-semibold rounded-lg px-6 py-3 transition-colors"
              >
                Save Changes
              </button>
              <button
                type="button"
                phx-click="toggle_edit"
                class="flex-1 border border-zinc-700 text-zinc-400 font-semibold rounded-lg px-6 py-3 hover:border-[#D4AF37] hover:text-[#D4AF37] transition-colors"
              >
                Cancel
              </button>
            </div>
          </form>
        <% else %>
          <!-- View Profile -->
          <div class="space-y-6">
            <!-- Basic Info -->
            <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-8">
              <h2 class="text-2xl font-bold text-white mb-6">Basic Information</h2>

              <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
                <div>
                  <p class="text-sm font-medium text-zinc-500">Full Name</p>
                  <p class="mt-1 text-lg text-zinc-300"><%= @user.full_name || "Not set" %></p>
                </div>
                <div>
                  <p class="text-sm font-medium text-zinc-500">Email</p>
                  <p class="mt-1 text-lg text-zinc-300"><%= @user.email %></p>
                </div>
                <div>
                  <p class="text-sm font-medium text-zinc-500">Phone</p>
                  <p class="mt-1 text-lg text-zinc-300"><%= @user.phone || "Not set" %></p>
                </div>
                <div>
                  <p class="text-sm font-medium text-zinc-500">Member Since</p>
                  <p class="mt-1 text-lg text-zinc-300">
                    <%= format_date(@user.inserted_at) %>
                  </p>
                </div>
              </div>
            </div>

            <!-- Bio -->
            <%= if @crew_profile.bio && byte_size(@crew_profile.bio) > 0 do %>
              <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-8">
                <h2 class="text-2xl font-bold text-white mb-4">About You</h2>
                <p class="text-zinc-400"><%= @crew_profile.bio %></p>
              </div>
            <% end %>

            <!-- Stats -->
            <div class="grid grid-cols-1 gap-6 md:grid-cols-3">
              <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
                <p class="text-sm font-medium text-zinc-500">Completed Jobs</p>
                <p class="mt-2 text-3xl font-bold text-[#D4AF37]"><%= @crew_profile.completed_jobs || 0 %></p>
              </div>
              <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
                <p class="text-sm font-medium text-zinc-500">Rating</p>
                <p class="mt-2 text-3xl font-bold text-yellow-400"><%= Float.round(@crew_profile.rating || 0, 1) %> ⭐</p>
              </div>
              <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
                <p class="text-sm font-medium text-zinc-500">Status</p>
                <p class="mt-2 text-lg font-bold">
                  <%= if @crew_profile.availability_status == "available" do %>
                    <span class="text-emerald-400">● Available</span>
                  <% else %>
                    <span class="text-zinc-500">● Offline</span>
                  <% end %>
                </p>
              </div>
            </div>

            <!-- Skills -->
            <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-8">
              <h2 class="text-2xl font-bold text-white mb-6">Skills</h2>

              <%= if @crew_profile.skills && length(@crew_profile.skills) > 0 do %>
                <div class="flex flex-wrap gap-2">
                  <%= for skill <- @crew_profile.skills do %>
                    <span class="inline-block bg-zinc-800 text-zinc-300 rounded-full px-4 py-2 text-sm font-medium">
                      <%= skill %>
                    </span>
                  <% end %>
                </div>
              <% else %>
                <p class="text-zinc-500">No skills added yet. Edit your profile to add skills.</p>
              <% end %>
            </div>

            <!-- Certifications -->
            <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-8">
              <h2 class="text-2xl font-bold text-white mb-6">Certifications</h2>

              <%= if @crew_profile.certifications && length(@crew_profile.certifications) > 0 do %>
                <div class="flex flex-wrap gap-2">
                  <%= for cert <- @crew_profile.certifications do %>
                    <span class="inline-block bg-emerald-900/60 text-emerald-400 px-4 py-2 rounded-full text-sm font-medium">
                      ✓ <%= cert %>
                    </span>
                  <% end %>
                </div>
              <% else %>
                <p class="text-zinc-500">No certifications added yet. Edit your profile to add certifications.</p>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_date(datetime) do
    if datetime do
      datetime
      |> DateTime.shift_zone!("America/Los_Angeles")
      |> Calendar.strftime("%B %d, %Y")
    else
      "N/A"
    end
  end
end
