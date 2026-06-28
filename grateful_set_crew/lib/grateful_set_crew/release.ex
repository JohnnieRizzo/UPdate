defmodule GratefulSetCrew.Release do
  @moduledoc """
  Used for performing release tasks when running in production without a shell.
  """

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _fun_return, _apps} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _fun_return, _apps} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.load(:grateful_set_crew)
    Application.fetch_env!(:grateful_set_crew, :ecto_repos)
  end

  defp load_app do
    Application.load(:grateful_set_crew)
  end
end
