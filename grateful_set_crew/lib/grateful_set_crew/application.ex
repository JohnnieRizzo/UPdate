defmodule GratefulSetCrew.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GratefulSetCrewWeb.Telemetry,
      GratefulSetCrew.Repo,
      {DNSCluster, query: Application.get_env(:grateful_set_crew, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GratefulSetCrew.PubSub},
      # Start a worker by calling: GratefulSetCrew.Worker.start_link(arg)
      # {GratefulSetCrew.Worker, arg},
      # Start to serve requests, typically the last entry
      GratefulSetCrewWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GratefulSetCrew.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GratefulSetCrewWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
