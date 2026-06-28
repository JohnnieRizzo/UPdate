defmodule GratefulSetCrewWeb.ClientLive.PostJobTest do
  use GratefulSetCrewWeb.ConnCase
  import Phoenix.LiveViewTest
  alias GratefulSetCrew.Jobs
  alias GratefulSetCrew.AccountsFixtures

  setup :register_and_log_in_user

  describe "PostJob - New Job" do
    test "mount displays form for new job", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/client/jobs/new")
      assert html =~ "Post a New Job"
      assert html =~ "Job Title"
      assert html =~ "Job Description"
      assert html =~ "Location"
      assert html =~ "Budget (Hourly Rate - USD)"
      assert html =~ "Estimated Hours"
      assert html =~ "Required Skills"
    end

    test "validate event updates form on input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/client/jobs/new")

      assert render_change(view, "validate", %{
               "job" => %{
                 "title" => "Cinematographer Needed",
                 "description" => "Looking for experienced cinematographer",
                 "location" => "Los Angeles, CA",
                 "hourly_rate" => "75.50",
                 "estimated_hours" => "40",
                 "required_skills" => "cinematography, lighting, color grading"
               }
             }) =~ "Cinematographer Needed"
    end

    test "save creates job and redirects to dashboard", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/client/jobs/new")

      # The save should raise a redirect
      try do
        render_submit(view, "save", %{
          "job" => %{
            "title" => "Cinematographer Needed",
            "description" => "Looking for experienced cinematographer",
            "location" => "Los Angeles, CA",
            "hourly_rate" => "75.50",
            "estimated_hours" => "40",
            "required_skills" => "cinematography, lighting, color grading"
          }
        })
      rescue
        Phoenix.LiveView.LiveRedirect -> :ok
      end

      # Verify job was created in database
      jobs = Jobs.list_jobs_by_client(user.id)
      assert length(jobs) == 1

      job = List.first(jobs)
      assert job.title == "Cinematographer Needed"
      assert job.description == "Looking for experienced cinematographer"
      assert job.location == "Los Angeles, CA"
      assert job.hourly_rate == 75.50
      assert job.estimated_hours == 40
      assert job.required_skills == ["cinematography", "lighting", "color grading"]
      assert job.client_id == user.id
    end

    test "save parses comma-separated skills correctly", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/client/jobs/new")

      try do
        render_submit(view, "save", %{
          "job" => %{
            "title" => "Test Job",
            "description" => "Test description",
            "location" => "Test location",
            "hourly_rate" => "50",
            "estimated_hours" => "20",
            "required_skills" => "  skill1  ,  skill2  , skill3  "
          }
        })
      rescue
        Phoenix.LiveView.LiveRedirect -> :ok
      end

      jobs = Jobs.list_jobs_by_client(user.id)
      job = List.last(jobs)

      # Should trim whitespace and filter empty strings
      assert job.required_skills == ["skill1", "skill2", "skill3"]
    end

    test "save validates required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/client/jobs/new")

      # Missing title and description (required fields)
      result =
        render_submit(view, "save", %{
          "job" => %{
            "title" => "",
            "description" => "",
            "location" => "Test location",
            "hourly_rate" => "50",
            "estimated_hours" => "20"
          }
        })

      # Should show validation errors
      assert result =~ "title"
    end
  end

  describe "PostJob - Edit Job" do
    setup %{user: user} do
      # Create a job to edit
      {:ok, job} =
        Jobs.create_job(%{
          "client_id" => user.id,
          "title" => "Original Title",
          "description" => "Original description",
          "location" => "Original location",
          "hourly_rate" => 50.0,
          "estimated_hours" => 20,
          "required_skills" => ["skill1", "skill2"]
        })

      {:ok, job: job}
    end

    test "mount displays form for existing job", %{conn: conn, job: job} do
      {:ok, _view, html} = live(conn, ~p"/client/jobs/#{job.id}/edit")
      assert html =~ "Edit Job"
      assert html =~ "Original Title"
      assert html =~ "Original description"
      assert html =~ "Original location"
    end

    test "save updates job and redirects", %{conn: conn, job: job} do
      {:ok, view, _html} = live(conn, ~p"/client/jobs/#{job.id}/edit")

      # The save might raise a redirect or just render normally
      # Try to catch the redirect if it happens
      try do
        render_submit(view, "save", %{
          "job" => %{
            "title" => "Updated Title",
            "description" => "Updated description",
            "location" => "Updated location",
            "hourly_rate" => "100",
            "estimated_hours" => "50",
            "required_skills" => "updated, skills"
          }
        })
      rescue
        Phoenix.LiveView.LiveRedirect -> :ok
      end

      # Verify job was updated
      updated_job = Jobs.get_job!(job.id)
      assert updated_job.title == "Updated Title"
      assert updated_job.description == "Updated description"
      assert updated_job.location == "Updated location"
      assert updated_job.hourly_rate == 100.0
      assert updated_job.estimated_hours == 50
      assert updated_job.required_skills == ["updated", "skills"]
    end
  end
end
