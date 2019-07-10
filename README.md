# ExBreak

ExBreak is a circuit breaker implementation for Elixir.

When making function calls that may fail, you may find that you want to stop
making those calls for a period of time after an error threshold is hit. This
package provides a way to do that.

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

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be
installed by adding `ex_break` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_break, "~> 0.1.0"}
  ]
end
```

## Architecture

### ExBreak.Application

This module is an `Application` which will start when you include `ex_break` in your application's dependencies. Its only responsibility is to start the `ExBreak.Supervisor`.

### ExBreak.Supervisor

This is a supervisor which starts `ExBreak.DynamicSupervisor` and `ExBreak.Registry`.

### ExBreak.DynamicSupervisor

This module is a `DynamicSupervisor` that dynamically supervises `ExBreak.Breaker` agents on demand as they're needed.

### ExBreak.Registry

This module is a registry of `ExBreak.Breaker` agents. When a call to `ExBreak.call/3` happens, the registry finds or creates the `ExBreak.Breaker` registered for the given function call and returns it to the `ExBreak` module for use.

When an `ExBreak.Breaker` process exits, it is de-registered.

### ExBreak.Breaker

This module is an `Agent` which stores internal state about an individual circuit breaker.

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
       ║ ExBreak.DynamicSupervisor ║░             ║     ExBreak.Registry      ║░
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

Documentation can be generated with
[ExDoc](https://github.com/elixir-lang/ex_doc) and published on
[HexDocs](https://hexdocs.pm). Once published, the docs can be found at
[https://hexdocs.pm/ex_break](https://hexdocs.pm/ex_break).
