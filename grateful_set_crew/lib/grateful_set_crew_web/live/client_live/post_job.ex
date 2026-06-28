defmodule GratefulSetCrewWeb.ClientLive.PostJob do
  use GratefulSetCrewWeb, :live_view

  alias GratefulSetCrew.Jobs
  alias GratefulSetCrew.Jobs.Job

  on_mount {GratefulSetCrewWeb.UserAuth, :ensure_current_user}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job = Jobs.get_job!(id)
    changeset = Jobs.change_job(job)

    {:ok,
     socket
     |> assign(:page_title, "Edit Job")
     |> assign(:job, job)
     |> assign(:changeset, changeset)}
  end

  def mount(_params, _session, socket) do
    changeset = Jobs.change_job(%Job{})

    {:ok,
     socket
     |> assign(:page_title, "Post a New Job")
     |> assign(:job, nil)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"job" => job_params}, socket) do
    # Parse required_skills for validation
    job_params = parse_skills(job_params)

    job = socket.assigns.job || %Job{}

    changeset =
      job
      |> Jobs.change_job(job_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"job" => job_params}, socket) do
    # Parse required_skills from comma-separated string to array
    job_params = parse_skills(job_params)

    case socket.assigns.job do
      # Editing existing job
      %Job{} = job ->
        case Jobs.update_job(job, job_params) do
          {:ok, _job} ->
            {:noreply,
             socket
             |> put_flash(:info, "Job updated successfully!")
             |> push_navigate(to: ~p"/client/dashboard")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}
        end

      # Creating new job
      nil ->
        job_params = Map.put(job_params, "client_id", socket.assigns.current_user.id)

        case Jobs.create_job(job_params) do
          {:ok, _job} ->
            {:noreply,
             socket
             |> put_flash(:info, "Job posted successfully!")
             |> push_navigate(to: ~p"/client/dashboard")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}
        end
    end
  end

  defp parse_skills(params) do
    case params do
      %{"required_skills" => skills} when is_binary(skills) ->
        parsed_skills =
          skills
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(byte_size(&1) > 0))

        Map.put(params, "required_skills", parsed_skills)

      _ ->
        params
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 py-12">
        <div class="rounded-xl bg-zinc-900 border border-zinc-800 p-8">
          <div class="h-0.5 bg-gradient-to-r from-[#D4AF37] via-[#f0d060] to-[#D4AF37] -mx-8 -mt-8 mb-8 rounded-t-xl"></div>
          <div class="mb-8">
            <h1 class="text-3xl font-bold text-white"><%= @page_title %></h1>
            <p class="mt-2 text-zinc-400">
              Describe the job and what skills you need.
            </p>
          </div>

          <form phx-change="validate" phx-submit="save">
            <div class="space-y-6">
              <!-- Job Title -->
              <div>
                <label class="block text-sm font-medium text-zinc-300 mb-2">
                  Job Title
                </label>
                <input
                  type="text"
                  name="job[title]"
                  value={Ecto.Changeset.get_field(@changeset, :title) || ""}
                  placeholder="e.g., Need experienced cinematographer for commercial shoot"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-navy focus:border-transparent"
                  required
                />
                <.error_message changeset={@changeset} field={:title} />
              </div>

              <!-- Description -->
              <div>
                <label class="block text-sm font-medium text-zinc-300 mb-2">
                  Job Description
                </label>
                <textarea
                  name="job[description]"
                  rows="6"
                  placeholder="Describe the job, requirements, and what the crew will be doing..."
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-navy focus:border-transparent"
                ><%= Ecto.Changeset.get_field(@changeset, :description) || "" %></textarea>
                <.error_message changeset={@changeset} field={:description} />
              </div>

              <!-- Location -->
              <div>
                <label class="block text-sm font-medium text-zinc-300 mb-2">
                  Location
                </label>
                <input
                  type="text"
                  name="job[location]"
                  value={Ecto.Changeset.get_field(@changeset, :location) || ""}
                  placeholder="e.g., Los Angeles, CA or Remote"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-navy focus:border-transparent"
                />
                <.error_message changeset={@changeset} field={:location} />
              </div>

              <div class="grid grid-cols-2 gap-6">
                <!-- Hourly Rate -->
                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">
                    Budget (Hourly Rate - USD)
                  </label>
                  <input
                    type="number"
                    name="job[hourly_rate]"
                    value={Ecto.Changeset.get_field(@changeset, :hourly_rate) || ""}
                    placeholder="e.g., 50"
                    step="0.01"
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-navy focus:border-transparent"
                  />
                  <.error_message changeset={@changeset} field={:hourly_rate} />
                </div>

                <!-- Estimated Hours -->
                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">
                    Estimated Hours
                  </label>
                  <input
                    type="number"
                    name="job[estimated_hours]"
                    value={Ecto.Changeset.get_field(@changeset, :estimated_hours) || ""}
                    placeholder="e.g., 40"
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-navy focus:border-transparent"
                  />
                  <.error_message changeset={@changeset} field={:estimated_hours} />
                </div>
              </div>

              <!-- Required Skills -->
              <div>
                <label class="block text-sm font-medium text-zinc-300 mb-2">
                  Required Skills (comma separated, optional)
                </label>
                <input
                  type="text"
                  name="job[required_skills]"
                  value={Enum.join(Ecto.Changeset.get_field(@changeset, :required_skills) || [], ", ")}
                  placeholder="e.g., cinematography, lighting, color grading"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-navy focus:border-transparent"
                />
                <p class="mt-1 text-sm text-gray-500">These help crew members find relevant jobs</p>
              </div>

              <!-- Submit Button -->
              <div class="flex gap-4">
                <button
                  type="submit"
                  class="bg-[#D4AF37] text-black hover:bg-[#c9a227] font-semibold rounded-lg px-6 py-3 transition-colors"
                >
                  Post Job
                </button>
                <.link
                  navigate={~p"/client/dashboard"}
                  class="border border-zinc-700 text-zinc-400 font-semibold rounded-lg px-6 py-3 hover:border-[#D4AF37] hover:text-[#D4AF37] transition-colors"
                >
                  Cancel
                </.link>
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp error_message(assigns) do
    ~H"""
    <%= if Enum.any?(@changeset.errors, fn {field, _} -> field == @field end) do %>
      <p class="mt-1 text-sm text-red-600">
        <%= elem(List.first(Enum.filter(@changeset.errors, fn {field, _} -> field == @field end)), 1)
            |> elem(0) %>
      </p>
    <% end %>
    """
  end
end
