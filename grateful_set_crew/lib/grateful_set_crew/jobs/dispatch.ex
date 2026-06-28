defmodule GratefulSetCrew.Jobs.Dispatch do
  @moduledoc """
  Job dispatch engine with 40/40/10/10 scoring algorithm.

  Scoring breakdown:
  - Location: 40 points
  - Skills: 40 points
  - Rating: 10 points
  - Availability/Experience: 10 points
  """

  import Ecto.Query
  alias GratefulSetCrew.Repo
  alias GratefulSetCrew.Notifications
  alias GratefulSetCrew.Accounts.CrewProfile
  alias GratefulSetCrew.Jobs.Job

  @max_radius_km 80
  @top_n 3

  defmodule ScoredCrew do
    defstruct [
      :crew_id,
      :crew_name,
      :score,
      :location_score,
      :skills_score,
      :rating_score,
      :avail_score,
      :rank
    ]
  end

  @doc """
  Run dispatch for a job, finding and potentially assigning crew.
  """
  def run(job_id) do
    # Load the job
    job = Repo.get!(Job, job_id)

    # Load eligible crew: onboarding complete + currently available
    eligible_crew = Repo.all(
      from cp in CrewProfile,
      where: cp.onboarding_status == "complete" and cp.availability_status == "available",
      preload: [:user]
    )

    if Enum.empty?(eligible_crew) do
      log_dispatch_event(job, "dispatch.no_crew", %{
        job_title: job.title,
        location: job.location
      })

      {:ok, job_id, [], nil, "no_crew_available"}
    else
      # Score every eligible crew member
      scored = Enum.map(eligible_crew, &score_crew(job, &1))
      # Sort by score descending and assign ranks
      scored = scored
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.with_index()
      |> Enum.map(fn {crew, idx} -> %{crew | rank: idx + 1} end)

      top_n = Enum.take(scored, @top_n)
      top_crew = List.first(top_n)

      # Update job status → 'matching', store top match_score
      {:ok, job} = Repo.update(Job.changeset(job, %{
        status: "matching",
        match_score: top_crew.score
      }))

      final_top_match = handle_assignment(job, top_crew, top_n)

      # Log the dispatch event
      log_dispatch_event(job, "dispatch.run", %{
        job_title: job.title,
        eligible_crew: Enum.count(eligible_crew),
        matches_found: Enum.count(top_n),
        top_score: top_crew.score,
        auto_assigned: top_crew && top_crew.score >= 70
      })

      {:ok, job_id, top_n, final_top_match, "matched"}
    end
  end

  # Auto-assign if score >= 70, otherwise notify top 3
  defp handle_assignment(_job, top_crew, _top_n) when is_nil(top_crew) do
    nil
  end

  defp handle_assignment(job, top_crew, _top_n) when top_crew.score >= 70 do
    # Auto-assign to top crew
    crew_id = top_crew.crew_id
    {:ok, _job} = Repo.update(Job.changeset(job, %{
      status: "assigned",
      crew_id: crew_id
    }))

    # Mark crew as busy
    crew_profile = Repo.get!(CrewProfile, crew_id)
    Repo.update(CrewProfile.changeset(crew_profile, %{availability_status: "busy"}))

    # Send notification
    notify_crew_assigned(crew_id, job)

    crew_id
  end

  defp handle_assignment(job, _top_crew, top_n) do
    # Notify top 3 to accept/decline
    Enum.each(top_n, fn crew ->
      notify_crew_available(crew.crew_id, job, crew.score)
    end)

    # Return first crew as candidate
    top_n
    |> List.first()
    |> then(fn crew -> crew.crew_id end)
  end

  # Scoring functions
  defp score_crew(job, crew) do
    loc_score = score_location(job, crew)
    skl_score = score_skills(job, crew)
    rat_score = score_rating(crew)
    avl_score = score_availability(crew)
    total = loc_score + skl_score + rat_score + avl_score

    %ScoredCrew{
      crew_id: crew.user_id,
      crew_name: crew.full_name || "Unknown",
      score: Float.round(total, 2),
      location_score: loc_score,
      skills_score: skl_score,
      rating_score: rat_score,
      avail_score: avl_score,
      rank: 0
    }
  end

  defp score_location(_job, crew) when is_nil(crew.location), do: 20
  defp score_location(job, _crew) when is_nil(job.location), do: 20

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
      # Try lat/lng fallback
      score_by_haversine(job, crew)
    end
  end

  defp score_by_haversine(job, crew) do
    with lat1 when not is_nil(lat1) <- job.latitude,
         lng1 when not is_nil(lng1) <- job.longitude,
         lat2 when not is_nil(lat2) <- crew.latitude,
         lng2 when not is_nil(lng2) <- crew.longitude do
      km = haversine_km(lat1, lng1, lat2, lng2)
      if km > @max_radius_km do
        0.0
      else
        score = (1 - km / @max_radius_km) * 40
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

  # Haversine distance formula
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

  defp notify_crew_assigned(crew_id, job) do
    start_date = if job.start_date do
      job.start_date
      |> DateTime.to_date()
      |> Date.to_string()
    else
      "TBD"
    end

    Notifications.create_notification(%{
      user_id: crew_id,
      title: "🎉 New Job Assigned!",
      body: "You've been matched for \"#{job.title}\" on #{start_date}. Check your dashboard.",
      type: "job",
      link: "/crew/dashboard"
    })
  end

  defp notify_crew_available(crew_id, job, score) do
    Notifications.create_notification(%{
      user_id: crew_id,
      title: "📋 New Job Available",
      body: "New gig: \"#{job.title}\" at #{job.location}. Match score: #{Float.round(score, 0)}/100. Accept now!",
      type: "job",
      link: "/crew/dashboard"
    })
  end

  defp log_dispatch_event(job, event_type, details) do
    Notifications.create_system_log(%{
      job_id: job.id,
      event_type: event_type,
      details: details
    })
  end
end
