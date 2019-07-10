defmodule ExBreak do
  @moduledoc """
  Provides circuit breaker functionality around function calls
  """

  alias ExBreak.Breaker

  @type opt ::
          {:timeout_sec, pos_integer}
          | {:threshold, pos_integer}
          | {:match_exception, (any -> boolean)}
          | {:match_return, (any -> boolean)}
  @type opts :: [opt]

  @default_opts [timeout_sec: 60 * 15, threshold: 10]

  @doc """
  Call a function using a circuit breaker.

  The first option is the function to call, followed by an optional list of
  arguments.

  If the function succeeds, and does not return an error tuple (in the form
  `{:error, any}`), the value returned by the function will be returned.

  If the function fails (meaning it returns an `{:error, any}` tuple), a
  counter is incremented in a circuit breaker for that function. If the
  counter meets or exceeds the configured circuit breaker threshold, the
  breaker for that function is marked as tripped.

  If the function fails and the circuit breaker for that function has been
  marked as tripped (and has not expired), then `{:error, :circuit_breaker_tripped}`
  will be returned.

  A list of options can be provided as the final argument to `call`:

  - `timeout_sec` (default `900`) The number of seconds after which a tripped
  breaker times out and is re-opened
  - `threshold` (default `10`) The number of times an error is permitted
  before further calls will be ignored and will return an `{:error,
  :circuilt_closed}`
  - `match_exception` (default `fn _ -> true end`) A function called when an
  exception is raised during the function call. If it returns true, the
  breaker trip count is incremented.
  - `match_return` (defaults to return `true` when matching `{:error, _}`) A
  function called on the return value of the function. If it returns `true`,
  the breaker trip count is incremented.

  ## Example

  This simple example increments the breaker when the return value is
  `{:error, _}`:

      iex> ExBreak.call(fn ret -> ret end, [:ok])
      :ok

      iex> fun = fn -> {:error, :fail} end
      iex> ExBreak.call(fun, [], threshold: 2)
      {:error, :fail}
      iex> ExBreak.call(fun, [], threshold: 2)
      {:error, :fail}
      iex> ExBreak.call(fun, [], threshold: 2)
      {:error, :circuit_breaker_tripped}

  In this example, we only increment when the return value is exactly
  `{:error, :bad}`:

      iex> fun = fn ret -> ret end
      iex> opts = [threshold: 2, match_return: fn
      ...>     {:error, :bad} -> true
      ...>     _ -> false
      ...>  end]
      iex> ExBreak.call(fun, [{:error, :not_bad}], opts)
      {:error, :not_bad}
      iex> ExBreak.call(fun, [{:error, :not_bad}], opts)
      {:error, :not_bad}
      iex> ExBreak.call(fun, [{:error, :not_bad}], opts)
      {:error, :not_bad}
      iex> ExBreak.call(fun, [{:error, :bad}], opts)
      {:error, :bad}
      iex> ExBreak.call(fun, [{:error, :bad}], opts)
      {:error, :bad}
      iex> ExBreak.call(fun, [{:error, :bad}], opts)
      {:error, :circuit_breaker_tripped}
  """
  @spec call(function, [any], opts) :: any
  def call(fun, args \\ [], opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    lookup(fun, fn pid ->
      if Breaker.is_tripped(pid, opts[:timeout_sec]) do
        {:error, :circuit_breaker_tripped}
      else
        Breaker.reset_tripped(pid)
        call_func(fun, args, opts)
      end
    end)
  end

  # Rewinds a breaker's tripped_at time for testing.
  @doc false
  @spec rewind_trip(function, integer) :: :ok
  def rewind_trip(fun, rewind_sec) do
    lookup(fun, fn pid ->
      Agent.update(pid, fn breaker ->
        tripped_at = DateTime.add(breaker.tripped_at, -rewind_sec, :second)
        Map.put(breaker, :tripped_at, tripped_at)
      end)
    end)
  end

  defp lookup(fun, callback) do
    case ExBreak.Registry.get_breaker(fun) do
      {:ok, pid} -> callback.(pid)
      error -> error
    end
  end

  defp call_func(fun, args, opts) do
    match_exception = Keyword.get(opts, :match_exception, fn _ -> true end)
    match_return = Keyword.get(opts, :match_return, fn ret -> match?({:error, _}, ret) end)

    try do
      apply(fun, args)
    rescue
      exception ->
        if match_exception.(exception) do
          increment_breaker(fun, opts)
        end

        reraise exception, __STACKTRACE__
    else
      return ->
        if match_return.(return) do
          increment_breaker(fun, opts)
          return
        else
          reset_breaker(fun)
          return
        end
    end
  end

  defp increment_breaker(fun, opts) do
    lookup(fun, &Breaker.increment(&1, opts[:threshold]))
  end

  defp reset_breaker(fun) do
    lookup(fun, &Breaker.reset_tripped/1)
  end
end
