defmodule GratefulSetCrew.JobsTest do
  use GratefulSetCrew.DataCase

  alias GratefulSetCrew.Jobs
  alias GratefulSetCrew.Jobs.Job

  import GratefulSetCrew.JobsFixtures
  import GratefulSetCrew.AccountsFixtures

  describe "list_jobs/0" do
    test "returns all jobs" do
      job = job_fixture()
      assert [%Job{id: job_id}] = Jobs.list_jobs()
      assert job_id == job.id
    end

    test "returns empty list when no jobs" do
      assert [] = Jobs.list_jobs()
    end
  end

  describe "list_jobs_by_client/1" do
    test "returns jobs for a specific client" do
      client1 = user_fixture(%{role: "client"})
      client2 = user_fixture(%{role: "client"})

      job1 = job_fixture(%{client: client1})
      job2 = job_fixture(%{client: client1})
      _job3 = job_fixture(%{client: client2})

      jobs = Jobs.list_jobs_by_client(client1.id)
      job_ids = Enum.map(jobs, & &1.id)

      assert length(jobs) == 2
      assert job1.id in job_ids
      assert job2.id in job_ids
    end

    test "returns empty list for client with no jobs" do
      client = user_fixture(%{role: "client"})
      assert [] = Jobs.list_jobs_by_client(client.id)
    end
  end

  describe "list_available_jobs/0" do
    test "returns only open and matching jobs" do
      _open_job = job_fixture(%{status: "open"})
      _matching_job = job_fixture(%{status: "matching"})
      _completed_job = completed_job_fixture()

      available = Jobs.list_available_jobs()

      assert length(available) == 2
      assert Enum.all?(available, fn j -> j.status in ["open", "matching"] end)
    end
  end

  describe "get_job!/1" do
    test "returns the job with given id" do
      job = job_fixture()
      assert %Job{id: job_id} = Jobs.get_job!(job.id)
      assert job_id == job.id
    end

    test "raises Ecto.NoResultsError if job does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Jobs.get_job!("00000000-0000-0000-0000-000000000000")
      end
    end
  end

  describe "create_job/1" do
    test "creates a job with valid attributes" do
      client = user_fixture(%{role: "client"})

      {:ok, job} =
        Jobs.create_job(%{
          title: "New Job",
          description: "Job description",
          location: "Los Angeles, CA",
          hourly_rate: 75.0,
          estimated_hours: 50,
          client_id: client.id
        })

      assert job.title == "New Job"
      assert job.description == "Job description"
      assert job.location == "Los Angeles, CA"
      assert job.hourly_rate == 75.0
      assert job.estimated_hours == 50
      assert job.status == "open"
      assert job.client_id == client.id
    end

    test "requires title" do
      client = user_fixture(%{role: "client"})

      {:error, changeset} =
        Jobs.create_job(%{
          description: "Job description",
          client_id: client.id
        })

      assert "can't be blank" in errors_on(changeset).title
    end

    test "defaults status to open" do
      client = user_fixture(%{role: "client"})

      {:ok, job} =
        Jobs.create_job(%{
          title: "New Job",
          description: "Job description",
          client_id: client.id
        })

      assert job.status == "open"
    end

    test "requires client_id" do
      {:error, changeset} =
        Jobs.create_job(%{
          title: "New Job",
          description: "Job description"
        })

      assert "can't be blank" in errors_on(changeset).client_id
    end
  end

  describe "update_job/2" do
    test "updates a job with valid attributes" do
      job = job_fixture()

      {:ok, updated_job} =
        Jobs.update_job(job, %{
          title: "Updated Title",
          status: "completed"
        })

      assert updated_job.title == "Updated Title"
      assert updated_job.status == "completed"
    end

    test "returns error if required field is removed" do
      job = job_fixture()

      {:error, changeset} =
        Jobs.update_job(job, %{title: nil})

      assert "can't be blank" in errors_on(changeset).title
    end
  end

  describe "delete_job/1" do
    test "deletes a job" do
      job = job_fixture()

      {:ok, deleted_job} = Jobs.delete_job(job)
      assert deleted_job.id == job.id

      assert_raise Ecto.NoResultsError, fn ->
        Jobs.get_job!(job.id)
      end
    end
  end

  describe "change_job/1" do
    test "returns a job changeset" do
      job = job_fixture()
      assert %Ecto.Changeset{} = Jobs.change_job(job)
    end
  end
end
