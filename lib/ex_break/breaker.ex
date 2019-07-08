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

      iex> breaker = ExBreak.Breaker.new()
      iex> breaker = ExBreak.Breaker.increment(breaker, 10)
      iex> {breaker.break_count, breaker.tripped}
      {1, false}

      iex> breaker = ExBreak.Breaker.new()
      iex> breaker = ExBreak.Breaker.increment(breaker, 1)
      iex> {breaker.break_count, breaker.tripped}
      {1, true}
  """
  @spec increment(t, pos_integer) :: t
  def increment(breaker, threshold) do
    break_count = breaker.break_count + 1
    tripped = break_count >= threshold
    tripped_at = if tripped, do: DateTime.utc_now()
    Map.merge(breaker, %{break_count: break_count, tripped: tripped, tripped_at: tripped_at})
  end

  @doc """
  Determine whether the given circuit breaker is tripped.

  The second argument, timeout_sec, is the time that must pass for a tripped
  circuit breaker to re-open.

      iex> breaker = ExBreak.Breaker.new()
      iex> breaker = ExBreak.Breaker.increment(breaker, 10)
      iex> ExBreak.Breaker.is_tripped(breaker, 10)
      false

      iex> breaker = ExBreak.Breaker.new()
      iex> breaker = ExBreak.Breaker.increment(breaker, 1)
      iex> ExBreak.Breaker.is_tripped(breaker, 10)
      true

      iex> breaker = ExBreak.Breaker.new()
      iex> breaker = ExBreak.Breaker.increment(breaker, 1)
      iex> ExBreak.Breaker.is_tripped(breaker, 0)
      false
  """
  @spec is_tripped(t, pos_integer) :: boolean
  def is_tripped(breaker = %__MODULE__{tripped: true}, timeout_sec) do
    DateTime.diff(DateTime.utc_now(), breaker.tripped_at, :second) < timeout_sec
  end

  def is_tripped(_, _) do
    false
  end

  @doc """
  Reset a tripped circuit breaker by creating a new circuit breaker.

  If the circuit breaker is not tripped, it is simply returned.

      iex> breaker = ExBreak.Breaker.new()
      iex> breaker = ExBreak.Breaker.increment(breaker, 1)
      iex> ExBreak.Breaker.is_tripped(breaker, 10)
      true
      iex> breaker = ExBreak.Breaker.reset_tripped(breaker)
      iex> ExBreak.Breaker.is_tripped(breaker, 10)
      false
  """
  @spec reset_tripped(t) :: t
  def reset_tripped(breaker) do
    if breaker.tripped, do: new(), else: breaker
  end
end
