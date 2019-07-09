defmodule ExBreak.Application do
  @moduledoc """
  The main ExBreak application, which starts the ExBreak.Supervisor
  """

  use Application

  def start(_type, _args) do
    ExBreak.Supervisor.start_link(name: ExBreak.Supervisor)
  end
end
