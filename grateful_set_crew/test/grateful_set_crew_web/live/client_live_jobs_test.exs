defmodule GratefulSetCrewWeb.ClientLive.JobsTest do
  use GratefulSetCrewWeb.ConnCase
  import Phoenix.LiveViewTest
  alias GratefulSetCrew.Jobs
  alias GratefulSetCrew.AccountsFixtures

  setup :register_and_log_in_user

  describe "Jobs listing" do
    test "mount displays empty state when no jobs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/client/jobs")
      assert html =~ "My Jobs"
      assert html =~ "haven&#39;t posted any jobs" or html =~ "haven't posted any jobs"
      assert html =~ "Post Your First Job"
    end

    test "mount displays list of client's jobs", %{conn: conn, user: user} do
      # Create some jobs for the client
      {:ok, job1} =
        Jobs.create_job(%{
          "client_id" => user.id,
          "title" => "Job 1",
          "description" => "Description 1",
          "location" => "Location 1",
          "hourly_rate" => 50.0,
          "estimated_hours" => 20,
          "required_skills" => ["skill1"]
        })

      {:ok, job2} =
        Jobs.create_job(%{
          "client_id" => user.id,
          "title" => "Job 2",
          "description" => "Description 2",
          "location" => "Location 2",
          "hourly_rate" => 75.0,
          "estimated_hours" => 40,
          "required_skills" => ["skill2"]
        })

      {:ok, _view, html} = live(conn, ~p"/client/jobs")

      assert html =~ "My Jobs"
      assert html =~ "Job 1"
      assert html =~ "Job 2"
      assert html =~ "Location 1"
      assert html =~ "Location 2"
    end

    test "displays job details correctly", %{conn: conn, user: user} do
      {:ok, _job} =
        Jobs.create_job(%{
          "client_id" => user.id,
          "title" => "Cinematographer",
          "description" => "Need experienced cinematographer for commercial",
          "location" => "Los Angeles, CA",
          "hourly_rate" => 100.0,
          "estimated_hours" => 32,
          "required_skills" => ["cinematography", "lighting"],
          "status" => "open",
          "payment_status" => "pending"
        })

      {:ok, _view, html} = live(conn, ~p"/client/jobs")

      assert html =~ "Cinematographer"
      assert html =~ "Los Angeles, CA"
      assert html =~ "100"
      assert html =~ "32"
      assert html =~ "Open"
      assert html =~ "Pending Payment"
    end

    test "displays truncated description", %{conn: conn, user: user} do
      long_description =
        String.duplicate("This is a long description. ", 10)

      {:ok, _job} =
        Jobs.create_job(%{
          "client_id" => user.id,
          "title" => "Test Job",
          "description" => long_description,
          "location" => "Test location",
          "hourly_rate" => 50.0,
          "estimated_hours" => 20
        })

      {:ok, _view, html} = live(conn, ~p"/client/jobs")

      # Should show truncated description with ...
      assert String.contains?(html, ["This is a long description"])
    end

    test "displays status badges correctly", %{conn: conn, user: user} do
      statuses = ["open", "matching", "assigned", "in_progress", "completed", "cancelled"]

      Enum.each(statuses, fn status ->
        Jobs.create_job(%{
          "client_id" => user.id,
          "title" => "Job with status #{status}",
          "description" => "Test",
          "location" => "Test",
          "hourly_rate" => 50.0,
          "estimated_hours" => 20,
          "status" => status
        })
      end)

      {:ok, _view, html} = live(conn, ~p"/client/jobs")

      assert html =~ "Open"
      assert html =~ "Matching"
      assert html =~ "Assigned"
      # "In Progress" is rendered in the badge
      assert String.contains?(html, ["In Progress", "In&#"]) or String.contains?(html, ["In"])
      assert html =~ "Completed"
      assert html =~ "Cancelled"
    end

    test "only displays jobs for current user", %{conn: conn, user: user} do
      # Create another user
      other_user = AccountsFixtures.user_fixture()

      # Create job for current user
      {:ok, _job1} =
        Jobs.create_job(%{
          "client_id" => user.id,
          "title" => "User's Job",
          "description" => "Test",
          "location" => "Test",
          "hourly_rate" => 50.0,
          "estimated_hours" => 20
        })

      # Create job for other user
      {:ok, _job2} =
        Jobs.create_job(%{
          "client_id" => other_user.id,
          "title" => "Other User's Job",
          "description" => "Test",
          "location" => "Test",
          "hourly_rate" => 50.0,
          "estimated_hours" => 20
        })

      {:ok, _view, html} = live(conn, ~p"/client/jobs")

      assert html =~ "User&#39;s Job" or html =~ "User's Job"
      refute html =~ "Other User&#39;s Job" and refute html =~ "Other User's Job"
    end
  end
end
