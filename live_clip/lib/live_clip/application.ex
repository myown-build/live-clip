defmodule LiveClip.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do

    children = [
      LiveClipWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:live_clip, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LiveClip.PubSub},
      {DynamicSupervisor, name: LiveClip.DynamicSupervisor, strategy: :one_for_one},
      LiveClip.Cache,
      LiveClipWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveClip.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveClipWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
