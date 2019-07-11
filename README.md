# ExBreak

ExBreak is a circuit breaker implementation for Elixir.

When making function calls that may fail, you may find that you want to stop making those calls for a period of time after an error threshold is hit. This package provides a way to do that.

```elixir
defmodule GitHub do
  @moduledoc """
  Makes calls to the GitHub API
  """

  @base_url "https://api.github.com"

  @doc """
  Make a GET request to the GitHub API.

  This request is wrapped in a circuit breaker—after 10 calls that return an
  error tuple (`{:error, any}`), the circuit breaker will trip, and the
  function will immediately return `{:error, :circuit_breaker_tripped}` for
  the next two minutes (120 seconds).
  """
  def get(path, token: token) do
    ExBreak.call(&do_get/2, [path, token], threshold: 10, timeout_sec: 120)
  end

  defp do_get(path, token) do
    HTTPoison.get("#{@base_url}#{path}", authorization: "Bearer #{token}")
  end
end
```

It is also possible to have more fine-grained control over when a circuit breaker's trip counter is incremented. For example, to ensure that only `RuntimeError`s increment the counter, but not other exceptions, the `match_exception` option can be used.

The `match_exception` option is a function that will be called with the exception. If it returns `true`, the trip counter will be incremented when an exception occurs. Otherwise, it will not.

```elixir
ExBreak.call(
  &do_get/2,
  [path, token],
  threshold: 10,
  timeout_sec: 120,
  match_exception: fn
    %RuntimeError{} -> true
    _ -> false
  end
)
```

Likewise, `match_return` can be used to designate what return values increment the trip counter. This option is a function that is called with the return value of the function passed to `call/3`. If it returns `true`, the trip counter will be incremented. Otherwise, it will not.

```elixir
ExBreak.call(
  &do_get/2,
  [path, token],
  timeout_sec: 120,
  match_return: fn
    {:error, :service_unavailable} -> true
    _ -> false
  end
)
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed by adding `ex_break` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_break, "~> 0.1.0"}
  ]
end
```

## Architecture

When a call `ExBreak.call/3` happens, the `ExBreak` module asks the `ExBreak.Registry` to get an `ExBreak.Breaker` state agent for the function passed to `call/3`. If an agent already exists, the registry returns it. Otherwise, it starts a new one using `ExBreak.BreakerSupervisor` and monitors it.

If the breaker has already been tripped and the tripped state has not expired, the function passed to `call/3` is never called and the value `{:error, :circuit_breaker_tripped}` is returned, instead.

If, however, the breaker has not been tripped (or its tripped state has expired), the function passed to `call/3` is called. If an exception is raised when calling the function, or if the return value of the function matches the pattern `{:error, _}`, a counter in the breaker's internal state is incremented, and either the exception is re-raised or the return value is returned.

If the counter in the breaker's internal state meets a configured threshold, the breaker is marked as "tripped", and subsequent calls to `call/3` with the same function will return `{:error, :circuit_breaker_tripped}` immediately until the tripped state expires once again.

### [ExBreak.Application](https://github.com/jclem/ex_break/blob/master/lib/ex_break/application.ex)

This module is an [`Application`](https://hexdocs.pm/elixir/Application.html) which will start when you include `ex_break` in your application's dependencies. Its only responsibility is to start the `ExBreak.Supervisor`.

### [ExBreak.Supervisor](https://github.com/jclem/ex_break/blob/master/lib/ex_break/supervisor.ex)

This is a [`Supervisor`](https://hexdocs.pm/elixir/Supervisor.html) which starts `ExBreak.DynamicSupervisor` and `ExBreak.Registry`.

### [ExBreak.BreakerSupervisor](https://github.com/jclem/ex_break/blob/master/lib/ex_break/supervisor.ex#L10)

This module is a [`DynamicSupervisor`](https://hexdocs.pm/elixir/DynamicSupervisor.html) that dynamically supervises `ExBreak.Breaker` agents on demand as they're needed.

### [ExBreak.Registry](https://github.com/jclem/ex_break/blob/master/lib/ex_break/registry.ex)

This module is a registry of `ExBreak.Breaker` agents. When a call to `ExBreak.call/3` happens, the registry finds or creates the `ExBreak.Breaker` registered for the given function call and returns it to the `ExBreak` module for use.

When an `ExBreak.Breaker` process exits, it is de-registered.

### [ExBreak.Breaker](https://github.com/jclem/ex_break/blob/master/lib/ex_break/breaker.ex)

This module is an [`Agent`](https://hexdocs.pm/elixir/Agent.html) which stores internal state about an individual circuit breaker.

<details><summary>Architecture Diagram</summary>

<pre><code>                     ╔═══════════════════════════╗
                     ║                           ║░
                     ║    ExBreak.Application    ║░
                     ║                           ║░
                     ╚═══════════════════════════╝░
                      ░░░░░░░░░░░░░│░░░░░░░░░░░░░░░
                                   │
                                   ▼
                     ╔═══════════════════════════╗
                     ║                           ║░
                     ║    ExBreak.Supervisor     ║░
                     ║                           ║░
                     ╚═══════════════════════════╝░
                      ░░░░░░░░░░░░░│░░░░░░░░░░░░░░░
                                   │
                     ┌─────────────┴────────────────────────────┐
                     │                                          │
                     ▼                                          ▼
       ╔═══════════════════════════╗              ╔═══════════════════════════╗
       ║                           ║░             ║                           ║░
       ║ ExBreak.BreakerSupervisor ║░             ║     ExBreak.Registry      ║░
       ║                           ║░             ║                           ║░
       ╚═══════════════════════════╝░             ╚═══════════════════════════╝░
        ░░░░░░░░░░░░░│░░░░░░░░░░░░░░░              ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
                     │
          ┌──────────┴───────────┬──────────────────────┐
          │                      │                      │
          ▼                      ▼                      ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│  ExBreak.Breaker  │  │  ExBreak.Breaker  │  │  ExBreak.Breaker  │
└───────────────────┘  └───────────────────┘  └───────────────────┘</code></pre></details>

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at [https://hexdocs.pm/ex_break](https://hexdocs.pm/ex_break).
