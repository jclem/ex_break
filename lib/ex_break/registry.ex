defmodule ExBreak.Registry do
  @moduledoc """
  A registry of all running breakers
  """

  use GenServer

  @impl true
  def init(init_arg) do
    {:ok, init_arg}
  end

  def start_link(opts) do
    breakers = %{}
    refs = %{}
    GenServer.start_link(__MODULE__, {breakers, refs}, opts)
  end

  @doc """
  Look up a breaker, and create one if it does not exist.
  """
  @spec get_breaker(function) :: {:ok, pid} | {:error, any}
  def get_breaker(key) do
    GenServer.call(__MODULE__, {:get_breaker, key})
  end

  @doc """
  Find a breaker, and return an error if it does not exist.
  """
  @spec find_breaker(function) :: {:ok, pid} | :error
  def find_breaker(key) do
    GenServer.call(__MODULE__, {:find_breaker, key})
  end

  @impl true
  def handle_call({:get_breaker, key}, _from, {breakers, refs}) do
    if pid = Map.get(breakers, key) do
      {:reply, {:ok, pid}, {breakers, refs}}
    else
      case DynamicSupervisor.start_child(ExBreak.BreakerSupervisor, ExBreak.Breaker) do
        {:ok, pid} ->
          ref = Process.monitor(pid)
          {:reply, {:ok, pid}, {Map.put(breakers, key, pid), Map.put(refs, ref, key)}}

        error ->
          {:reply, error, {breakers, refs}}
      end
    end
  end

  def handle_call({:find_breaker, key}, _from, {breakers, refs}) do
    {:reply, Map.fetch(breakers, key), {breakers, refs}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {breakers, refs}) do
    {key, refs} = Map.pop(refs, ref)
    breakers = Map.delete(breakers, key)
    {:noreply, {breakers, refs}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
