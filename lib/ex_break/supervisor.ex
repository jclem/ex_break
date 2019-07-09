defmodule ExBreak.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      {DynamicSupervisor, name: ExBreak.BreakerSupervisor, strategy: :one_for_one},
      {ExBreak.Registry, name: ExBreak.Registry}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
