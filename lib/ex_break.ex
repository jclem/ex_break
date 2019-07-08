defmodule ExBreak do
  @moduledoc """
  Provides circuit breaker functionality around function calls
  """

  @doc false
  use GenServer

  import Access, only: [key!: 1]

  alias __MODULE__.Breaker

  @type opt :: {:timeout_sec, pos_integer} | {:threshold, pos_integer}
  @type opts :: [opt]

  @default_opts [timeout_sec: 60 * 15, threshold: 10]

  defmodule State do
    @moduledoc false

    @type t :: %{breakers: %{optional(function) => Breaker.t()}}

    defstruct breakers: %{}

    def new do
      %__MODULE__{}
    end

    @spec get(t, function) :: Breaker.t() | nil
    def get(state, key) do
      Map.get(state.breakers, key)
    end

    @spec put(t, function, Breaker.t()) :: t
    def put(state, key, breaker) do
      put_in(state, [key!(:breakers), key], breaker)
    end
  end

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
  marked as tripped (and has not expired), then `{:error, :circuit_closed}`
  will be returned.

  A list of options can be provided as the final argument to `call`:

  - `timeout_sec` (default `900`) The number of seconds after which a tripped
  breaker times out and is re-opened
  - `threshold` (default `10`) The number of times an error is permitted
  before further calls will be ignored and will return an `{:error,
  :circuilt_closed}`

  ## Example

      iex> ExBreak.call(fn ret -> ret end, [:ok])
      :ok

      iex> fun = fn -> {:error, :fail} end
      iex> ExBreak.call(fun, [], threshold: 2)
      {:error, :fail}
      iex> ExBreak.call(fun, [], threshold: 2)
      {:error, :fail}
      iex> ExBreak.call(fun, [], threshold: 2)
      {:error, :circuit_closed}
  """
  @spec call(function, [any], opts) :: any
  def call(fun, args \\ [], opts \\ []) do
    GenServer.call(__MODULE__, {:call, fun, args, opts})
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    {:ok, State.new()}
  end

  @impl true
  def handle_call({:call, fun, args, opts}, from, state) do
    opts = Keyword.merge(@default_opts, opts)

    breaker = State.get(state, fun) || Breaker.new()
    state = State.put(state, fun, breaker)

    if Breaker.is_tripped(breaker, opts[:timeout_sec]) do
      {:reply, {:error, :circuit_closed}, state}
    else
      server = self()
      spawn_link(fn -> call_func(fun, args, opts, from, server) end)
      {:noreply, State.put(state, fun, Breaker.reset_tripped(breaker))}
    end
  end

  def handle_call({:increment_breaker, key, opts}, _from, state) do
    if breaker = State.get(state, key) do
      breaker = Breaker.increment(breaker, opts[:threshold])
      {:reply, :ok, State.put(state, key, breaker)}
    else
      {:reply, {:error, "No such breaker found"}, state}
    end
  end

  def handle_call({:reset_breaker, key}, _from, state) do
    state = State.put(state, key, Breaker.new())
    {:reply, :ok, state}
  end

  if Mix.env() == :test do
    def handle_call(:get_state, _from, state) do
      {:reply, state, state}
    end

    def handle_call({:rewind_trip, fun, rewind_sec}, _from, state) do
      breaker = State.get(state, fun)
      tripped_at = DateTime.add(breaker.tripped_at, -rewind_sec, :second)
      state = put_in(state, [key!(:breakers), fun, key!(:tripped_at)], tripped_at)
      {:reply, :ok, state}
    end
  end

  defp call_func(fun, args, opts, from, server) do
    case apply(fun, args) do
      {:error, err} ->
        GenServer.call(server, {:increment_breaker, fun, opts})
        GenServer.reply(from, {:error, err})

      value ->
        GenServer.call(server, {:reset_breaker, fun})
        GenServer.reply(from, value)
    end
  end
end
