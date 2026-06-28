defmodule GratefulSetCrew.JobsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `GratefulSetCrew.Jobs` context.
  """

  import GratefulSetCrew.AccountsFixtures

  alias GratefulSetCrew.Jobs

  def valid_job_attributes(attrs \\ %{}) do
    client = attrs[:client] || user_fixture(%{role: "client"})

    Enum.into(attrs, %{
      title: "Test Job #{System.unique_integer()}",
      description: "A test job for testing purposes",
      location: "San Francisco, CA",
      hourly_rate: 50.0,
      estimated_hours: 40,
      status: "open",
      client_id: client.id
    })
  end

  def job_fixture(attrs \\ %{}) do
    {:ok, job} =
      attrs
      |> valid_job_attributes()
      |> Jobs.create_job()

    job
  end

  def completed_job_fixture(attrs \\ %{}) do
    {:ok, job} =
      attrs
      |> valid_job_attributes()
      |> Map.put(:status, "completed")
      |> Jobs.create_job()

    job
  end
end
