defmodule GratefulSetCrew.Jobs do
  @moduledoc """
  The Jobs context.
  """

  import Ecto.Query, warn: false
  alias GratefulSetCrew.Repo
  alias GratefulSetCrew.Jobs.Job
  alias GratefulSetCrew.Jobs.Application, as: JobApplication
  alias GratefulSetCrew.Jobs.Dispatch
  alias GratefulSetCrew.Accounts.CrewProfile

  @doc """
  Returns the list of jobs.
  """
  def list_jobs do
    Repo.all(Job)
  end

  @doc """
  Returns the list of jobs for a client.
  """
  def list_jobs_by_client(client_id) do
    Repo.all(from j in Job, where: j.client_id == ^client_id)
  end

  @doc """
  Returns the list of available jobs for crew.
  """
  def list_available_jobs do
    Repo.all(from j in Job, where: j.status in ["open", "matching"])
  end

  @doc """
  Gets a single job.
  """
  def get_job!(id) do
    Repo.get!(Job, id)
  end

  @doc """
  Creates a job.
  """
  def create_job(attrs \\ %{}) do
    with {:ok, job} <- %Job{}
    |> Job.changeset(attrs)
    |> Repo.insert() do
      # Broadcast the new job
      broadcast_job_created(job)
      {:ok, job}
    else
      error -> error
    end
  end

  @doc """
  Updates a job.
  """
  def update_job(%Job{} = job, attrs) do
    with {:ok, updated_job} <- job
    |> Job.changeset(attrs)
    |> Repo.update() do
      # Broadcast the job update
      broadcast_job_updated(updated_job)
      {:ok, updated_job}
    else
      error -> error
    end
  end

  defp broadcast_job_created(job) do
    Phoenix.PubSub.broadcast(
      GratefulSetCrew.PubSub,
      "jobs:open",
      {:job_created, job}
    )
    Phoenix.PubSub.broadcast(
      GratefulSetCrew.PubSub,
      "jobs:updated",
      {:job_updated, job}
    )
  end

  defp broadcast_job_updated(job) do
    Phoenix.PubSub.broadcast(
      GratefulSetCrew.PubSub,
      "jobs:updated",
      {:job_updated, job}
    )
  end

  @doc """
  Deletes a job.
  """
  def delete_job(%Job{} = job) do
    Repo.delete(job)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking job changes.
  """
  def change_job(%Job{} = job, attrs \\ %{}) do
    Job.changeset(job, attrs)
  end

  @doc """
  Returns available jobs for a crew with optional filters.

  Filters:
  - search: Text search in title and description
  - location: Filter by city (exact match)
  - min_rate: Minimum hourly rate
  - max_rate: Maximum hourly rate
  - skills: List of required skills (filters jobs needing any of these)
  - status: Job status (defaults to ["open", "matching"])
  - sort: Sort order (:posted_date, :rate_high, :rate_low, :relevance)
  """
  def list_available_jobs_for_crew(crew_id, filters \\ %{}) do
    crew = Repo.get!(CrewProfile, crew_id)

    query = from j in Job,
      where: j.status in ^(filters[:status] || ["open", "matching"])

    # Apply search filter
    query = if Map.has_key?(filters, :search) && filters[:search] != "" do
      search = "%#{filters[:search]}%"
      from j in query,
        where: ilike(j.title, ^search) or ilike(j.description, ^search)
    else
      query
    end

    # Apply location filter
    query = if Map.has_key?(filters, :location) && filters[:location] != "" do
      location = filters[:location]
      from j in query,
        where: ilike(j.location, ^"%#{location}%")
    else
      query
    end

    # Apply rate range filter
    query = if Map.has_key?(filters, :min_rate) && filters[:min_rate] != nil do
      min_rate = filters[:min_rate]
      from j in query,
        where: j.hourly_rate >= ^min_rate
    else
      query
    end

    query = if Map.has_key?(filters, :max_rate) && filters[:max_rate] != nil do
      max_rate = filters[:max_rate]
      from j in query,
        where: j.hourly_rate <= ^max_rate
    else
      query
    end

    # Apply skills filter - gets jobs that have any of the crew's skills
    query = if Map.has_key?(filters, :skills) && is_list(filters[:skills]) && length(filters[:skills]) > 0 do
      skills = filters[:skills]
      from j in query,
        where: fragment("? && ?", j.required_skills, ^skills)
    else
      query
    end

    # Apply sorting
    sort_by = filters[:sort_by] || :posted_date
    query = case sort_by do
      :rate_high ->
        from j in query, order_by: [desc: j.hourly_rate]
      :rate_low ->
        from j in query, order_by: [asc: j.hourly_rate]
      :relevance ->
        # Sort by match score descending, then by posted date
        from j in query, order_by: [desc: j.match_score, desc: j.inserted_at]
      _ ->
        # Default: posted date (newest first)
        from j in query, order_by: [desc: j.inserted_at]
    end

    jobs = Repo.all(query)

    # Add match scores and check application status
    Enum.map(jobs, fn job ->
      match_score = calculate_crew_job_match(job, crew)
      application = get_job_application(job.id, crew_id)

      %{
        job: job,
        match_score: match_score,
        application_status: if(application, do: application.status, else: nil)
      }
    end)
  end

  @doc """
  Calculates match score between a job and crew using Dispatch scoring algorithm.
  Returns a score between 0-100.
  """
  def calculate_crew_job_match(job, crew) do
    # Use the same scoring algorithm as Dispatch
    struct = %Dispatch.ScoredCrew{
      crew_id: crew.user_id,
      crew_name: crew.full_name || "Unknown",
      score: 0.0,
      location_score: score_location(job, crew),
      skills_score: score_skills(job, crew),
      rating_score: score_rating(crew),
      avail_score: score_availability(crew),
      rank: 0
    }

    struct.location_score + struct.skills_score + struct.rating_score + struct.avail_score
    |> Float.round(2)
  end

  defp score_location(_job, crew) when is_nil(crew.location), do: 20.0
  defp score_location(job, _crew) when is_nil(job.location), do: 20.0

  defp score_location(job, crew) do
    job_city = job.location
      |> String.split(",")
      |> List.first()
      |> String.trim()
      |> String.downcase()

    crew_city = crew.location
      |> String.split(",")
      |> List.first()
      |> String.trim()
      |> String.downcase()

    if job_city == crew_city do
      40.0
    else
      score_by_haversine(job, crew)
    end
  end

  defp score_by_haversine(job, crew) do
    max_radius_km = 80
    with lat1 when not is_nil(lat1) <- job.latitude,
         lng1 when not is_nil(lng1) <- job.longitude,
         lat2 when not is_nil(lat2) <- crew.latitude,
         lng2 when not is_nil(lng2) <- crew.longitude do
      km = haversine_km(lat1, lng1, lat2, lng2)
      if km > max_radius_km do
        0.0
      else
        score = (1 - km / max_radius_km) * 40
        Float.round(max(0, score), 2)
      end
    else
      _ -> 0.0
    end
  end

  defp score_skills(job, crew) do
    required = job.required_skills || []
    if Enum.empty?(required) do
      40.0
    else
      crew_skills = (crew.skills || [])
        |> Enum.map(&String.downcase/1)
        |> MapSet.new()

      matched = required
        |> Enum.map(&String.downcase/1)
        |> Enum.count(&MapSet.member?(crew_skills, &1))

      Float.round((matched / Enum.count(required)) * 40, 2)
    end
  end

  defp score_rating(crew) do
    rating = crew.rating || 0.0
    Float.round((rating / 5.0) * 10, 2)
  end

  defp score_availability(crew) do
    jobs = min(crew.completed_jobs || 0, 50)
    Float.round((jobs / 50) * 10, 2)
  end

  defp haversine_km(lat1, lng1, lat2, lng2) do
    r = 6371  # Earth radius in km
    dlat = (lat2 - lat1) * :math.pi() / 180
    dlng = (lng2 - lng1) * :math.pi() / 180

    a = :math.sin(dlat / 2) ** 2 +
        :math.cos(lat1 * :math.pi() / 180) *
        :math.cos(lat2 * :math.pi() / 180) *
        :math.sin(dlng / 2) ** 2

    r * 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
  end

  @doc """
  Creates a job application for a crew member expressing interest in a job.
  """
  def apply_for_job(job_id, crew_id, _opts \\ []) do
    job = get_job!(job_id)
    crew = Repo.get!(CrewProfile, crew_id)
    match_score = calculate_crew_job_match(job, crew)

    %JobApplication{}
    |> JobApplication.changeset(%{
      job_id: job_id,
      crew_id: crew_id,
      status: "applied",
      applied_at: DateTime.utc_now(),
      match_score: match_score
    })
    |> Repo.insert()
  end

  @doc """
  Gets a job application if it exists.
  """
  def get_job_application(job_id, crew_id) do
    Repo.one(
      from ja in JobApplication,
      where: ja.job_id == ^job_id and ja.crew_id == ^crew_id
    )
  end

  @doc """
  Lists all applications for a job.
  """
  def list_job_applications(job_id) do
    Repo.all(
      from ja in JobApplication,
      where: ja.job_id == ^job_id,
      order_by: [desc: ja.match_score]
    )
  end

  @doc """
  Lists all applications for a crew member.
  """
  def list_crew_applications(crew_id) do
    Repo.all(
      from ja in JobApplication,
      where: ja.crew_id == ^crew_id,
      preload: [:job],
      order_by: [desc: ja.applied_at]
    )
  end

  @doc """
  Gets all unique skills from crew profiles.
  """
  def get_all_skills do
    Repo.all(
      from cp in CrewProfile,
      where: not is_nil(cp.skills),
      select: cp.skills
    )
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end
end
