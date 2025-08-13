defmodule Activamente.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ActivamenteWeb.Telemetry,
      Activamente.Repo,
      {DNSCluster, query: Application.get_env(:activamente, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Activamente.PubSub},
      # Start a worker by calling: Activamente.Worker.start_link(arg)
      # {Activamente.Worker, arg},
      # Start to serve requests, typically the last entry
      ActivamenteWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Activamente.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ActivamenteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
