defmodule GratefulSetCrewWeb.CrewLive.JobsTest do
  use GratefulSetCrewWeb.ConnCase

  import Phoenix.LiveViewTest
  alias GratefulSetCrew.{Accounts, Jobs}

  setup :register_and_log_in_crew

  describe "Jobs browse page" do
    test "displays available jobs", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/crew/jobs")
      assert html =~ "Browse Jobs"
      assert html =~ "Discover and apply for available gigs"
    end

    test "shows empty state when no jobs available", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/crew/jobs")
      assert html =~ "No jobs found"
    end

    test "displays job cards with available jobs", %{conn: conn, user: crew} do
      client = user_fixture()
      {:ok, job} = Jobs.create_job(%{
        client_id: client.id,
        title: "Test Job",
        description: "A test job description",
        location: "New York, NY",
        hourly_rate: 25.0,
        estimated_hours: 10,
        required_skills: ["Ruby", "Rails"],
        status: "open"
      })

      {:ok, lv, _html} = live(conn, ~p"/crew/jobs")
      html = render(lv)

      assert html =~ job.title
      assert html =~ "Test Job"
      assert html =~ "$25.0/hr"
    end

    test "search filters jobs by title", %{conn: conn} do
      client = user_fixture()
      Jobs.create_job(%{
        client_id: client.id,
        title: "Ruby Developer Needed",
        description: "Build amazing features",
        location: "New York, NY",
        hourly_rate: 50.0,
        estimated_hours: 20,
        status: "open"
      })

      Jobs.create_job(%{
        client_id: client.id,
        title: "JavaScript Frontend Engineer",
        description: "Work on UI components",
        location: "Boston, MA",
        hourly_rate: 45.0,
        estimated_hours: 15,
        status: "open"
      })

      {:ok, lv, _html} = live(conn, ~p"/crew/jobs")

      html = render_change(lv, :search, %{"query" => "Ruby"})
      assert html =~ "Ruby Developer Needed"
      refute html =~ "JavaScript Frontend Engineer"
    end

    test "filter by location", %{conn: conn} do
      client = user_fixture()
      Jobs.create_job(%{
        client_id: client.id,
        title: "Job in New York",
        description: "Description",
        location: "New York, NY",
        hourly_rate: 30.0,
        estimated_hours: 10,
        status: "open"
      })

      Jobs.create_job(%{
        client_id: client.id,
        title: "Job in Boston",
        description: "Description",
        location: "Boston, MA",
        hourly_rate: 30.0,
        estimated_hours: 10,
        status: "open"
      })

      {:ok, lv, _html} = live(conn, ~p"/crew/jobs")

      html = render_change(lv, :update_filters, %{"location" => "New York"})
      assert html =~ "Job in New York"
      refute html =~ "Job in Boston"
    end

    test "filter by rate range", %{conn: conn} do
      client = user_fixture()
      Jobs.create_job(%{
        client_id: client.id,
        title: "Cheap Job",
        description: "Description",
        location: "New York, NY",
        hourly_rate: 15.0,
        estimated_hours: 10,
        status: "open"
      })

      Jobs.create_job(%{
        client_id: client.id,
        title: "Expensive Job",
        description: "Description",
        location: "New York, NY",
        hourly_rate: 100.0,
        estimated_hours: 10,
        status: "open"
      })

      {:ok, lv, _html} = live(conn, ~p"/crew/jobs")

      html = render_change(lv, :update_filters, %{"min_rate" => "50", "max_rate" => "150"})
      assert html =~ "Expensive Job"
      refute html =~ "Cheap Job"
    end

    test "sort by posted date (newest first)", %{conn: conn} do
      client = user_fixture()
      Jobs.create_job(%{
        client_id: client.id,
        title: "Old Job",
        description: "Description",
        location: "New York, NY",
        hourly_rate: 30.0,
        estimated_hours: 10,
        status: "open"
      })

      Process.sleep(100)

      Jobs.create_job(%{
        client_id: client.id,
        title: "New Job",
        description: "Description",
        location: "New York, NY",
        hourly_rate: 30.0,
        estimated_hours: 10,
        status: "open"
      })

      {:ok, lv, _html} = live(conn, ~p"/crew/jobs")

      html = render_change(lv, :change_sort, %{"sort" => "posted_date"})
      # New job should appear before old job in the HTML
      new_pos = String.length(html) - String.length(String.trim_leading(html, String.slice(html, 0, String.length(html) - String.length("New Job"))))
      old_pos = String.length(html) - String.length(String.trim_leading(html, String.slice(html, 0, String.length(html) - String.length("Old Job"))))
      assert new_pos > old_pos
    end
  end

  describe "Job application" do
    test "can apply for a job", %{conn: conn, user: crew} do
      client = user_fixture()
      {:ok, job} = Jobs.create_job(%{
        client_id: client.id,
        title: "Test Job",
        description: "Description",
        location: "New York, NY",
        hourly_rate: 30.0,
        estimated_hours: 10,
        status: "open"
      })

      {:ok, lv, _html} = live(conn, ~p"/crew/jobs")
      html = render_click(lv, :apply_for_job, %{"job_id" => job.id})

      # After applying, button should change to show applied status
      assert html =~ "applied" or html =~ "Apply Now"

      # Verify application was created
      app = Jobs.get_job_application(job.id, crew.id)
      assert app.status == "applied"
      assert app.crew_id == crew.id
      assert app.job_id == job.id
    end

    test "prevents duplicate applications", %{conn: conn, user: crew} do
      client = user_fixture()
      {:ok, job} = Jobs.create_job(%{
        client_id: client.id,
        title: "Test Job",
        description: "Description",
        location: "New York, NY",
        hourly_rate: 30.0,
        estimated_hours: 10,
        status: "open"
      })

      # Apply once
      {:ok, app1} = Jobs.apply_for_job(job.id, crew.id)
      assert app1.status == "applied"

      # Try to apply again
      result = Jobs.apply_for_job(job.id, crew.id)
      assert {:error, _changeset} = result
    end

    test "shows application status on job card", %{conn: conn, user: crew} do
      client = user_fixture()
      {:ok, job} = Jobs.create_job(%{
        client_id: client.id,
        title: "Test Job",
        description: "Description",
        location: "New York, NY",
        hourly_rate: 30.0,
        estimated_hours: 10,
        status: "open"
      })

      # Apply for the job
      Jobs.apply_for_job(job.id, crew.id)

      {:ok, lv, _html} = live(conn, ~p"/crew/jobs")
      html = render(lv)

      # Should show applied status instead of apply button
      assert html =~ "applied"
    end
  end

  describe "Job detail modal" do
    test "opens job detail modal", %{conn: conn} do
      client = user_fixture()
      {:ok, job} = Jobs.create_job(%{
        client_id: client.id,
        title: "Test Job",
        description: "Full description of the job",
        location: "New York, NY",
        hourly_rate: 30.0,
        estimated_hours: 10,
        required_skills: ["Ruby"],
        status: "open"
      })

      {:ok, lv, _html} = live(conn, ~p"/crew/jobs")
      html = render_click(lv, :view_details, %{"job_id" => job.id})

      assert html =~ job.title
      assert html =~ "Full description of the job"
      assert html =~ "$30.0/hr"
    end

    test "closes job detail modal", %{conn: conn} do
      client = user_fixture()
      {:ok, job} = Jobs.create_job(%{
        client_id: client.id,
        title: "Test Job",
        description: "Description",
        location: "New York, NY",
        hourly_rate: 30.0,
        estimated_hours: 10,
        status: "open"
      })

      {:ok, lv, _html} = live(conn, ~p"/crew/jobs")
      render_click(lv, :view_details, %{"job_id" => job.id})
      html = render_click(lv, :close_detail, %{})

      # Modal should be gone
      refute html =~ "Full description"
    end
  end

  # Helper functions
  defp register_and_log_in_crew(_context) do
    crew = crew_fixture()
    %{conn: log_in_user(build_conn(), crew), user: crew}
  end

  defp crew_fixture do
    {:ok, user} = Accounts.register_user(%{
      email: unique_user_email(),
      password: "password1234",
      role: "crew"
    })

    {:ok, _crew_profile} = Accounts.create_crew_profile(user, %{
      full_name: "Test Crew",
      location: "New York, NY",
      skills: ["Ruby", "Rails", "JavaScript"],
      hourly_rate: 50.0
    })

    user
  end

  defp user_fixture do
    {:ok, user} = Accounts.register_user(%{
      email: unique_user_email(),
      password: "password1234",
      role: "client"
    })
    user
  end

  defp unique_user_email, do: "user#{System.unique_integer()}@example.com"
end
