defmodule ExBreak.Breaker do
  @moduledoc """
  A server that serves as a circuit breaker for a single function
  """

  @typedoc """
  A struct representing the state of a circuit breaker

  - `break_count` The number of breaks that have occurred
  - `tripped` Whether the circuit breaker is tripped
  - `tripped_at` The time at which the circuit breaker was tripped (or `nil`, if un-tripped)
  """
  @type t :: %__MODULE__{
          break_count: non_neg_integer,
          tripped: boolean,
          tripped_at: DateTime.t() | nil
        }

  defstruct break_count: 0, tripped: false, tripped_at: nil

  @doc false
  use Agent, restart: :temporary

  @doc """
  Start a new breaker.
  """
  @spec start_link(Keyword.t()) :: Agent.on_start()
  def start_link(_opts) do
    Agent.start_link(fn -> new() end)
  end

  @doc """
  Create a new circuit breaker.
  """
  @spec new :: t
  def new do
    %__MODULE__{}
  end

  @doc """
  Increment a circuit breaker.

  If the new break count exceeds the given threshold, the breaker is also
  marked as tripped.

      iex> {:ok, pid} = ExBreak.Breaker.start_link([])
      iex> ExBreak.Breaker.increment(pid, 10)
      iex> ExBreak.Breaker.is_tripped(pid, 60)
      false
  """
  @spec increment(pid, pos_integer) :: :ok
  def increment(pid, threshold) do
    Agent.update(pid, fn breaker ->
      break_count = breaker.break_count + 1
      tripped = break_count >= threshold
      tripped_at = if tripped, do: DateTime.utc_now()
      Map.merge(breaker, %{break_count: break_count, tripped: tripped, tripped_at: tripped_at})
    end)
  end

  @doc """
  Determine whether the given circuit breaker is tripped.

  The second argument, timeout_sec, is the time that must pass for a tripped
  circuit breaker to re-open.

      iex> {:ok, pid} = ExBreak.Breaker.start_link([])
      iex> ExBreak.Breaker.increment(pid, 10)
      iex> ExBreak.Breaker.is_tripped(pid, 10)
      false

      iex> {:ok, pid} = ExBreak.Breaker.start_link([])
      iex> ExBreak.Breaker.increment(pid, 1)
      iex> ExBreak.Breaker.is_tripped(pid, 10)
      true

      iex> {:ok, pid} = ExBreak.Breaker.start_link([])
      iex> ExBreak.Breaker.increment(pid, 1)
      iex> ExBreak.Breaker.is_tripped(pid, 0)
      false
  """
  @spec is_tripped(pid, pos_integer) :: boolean
  def is_tripped(pid, timeout_sec) do
    Agent.get(pid, fn breaker ->
      if breaker.tripped do
        DateTime.diff(DateTime.utc_now(), breaker.tripped_at, :second) < timeout_sec
      else
        false
      end
    end)
  end

  @doc """
  Reset a tripped circuit breaker by creating a new circuit breaker.

  If the circuit breaker is not tripped, it is simply returned.

      iex> {:ok, pid} = ExBreak.Breaker.start_link([])
      iex> ExBreak.Breaker.increment(pid, 1)
      iex> ExBreak.Breaker.is_tripped(pid, 10)
      true
      iex> ExBreak.Breaker.reset_tripped(pid)
      iex> ExBreak.Breaker.is_tripped(pid, 10)
      false
  """
  @spec reset_tripped(pid) :: :ok
  def reset_tripped(pid) do
    Agent.update(pid, fn breaker ->
      if breaker.tripped, do: new(), else: breaker
    end)
  end
end
