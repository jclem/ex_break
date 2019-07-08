# ExBreak

ExBreak is a circuit breaker implementation for Elixir.

When making function calls that may fail, you may find that you want to stop
making those calls for a period of time after an error threshold is hit. This
package provides a way to do that.

```elixir
ExBreak.start_link(name: ExBreak)
func = fn ret -> ret end
ExBreak.call(func, [{:error, :oops}], threshold: 10, timeout_sec: 120)
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

Documentation can be generated with
[ExDoc](https://github.com/elixir-lang/ex_doc) and published on
[HexDocs](https://hexdocs.pm). Once published, the docs can be found at
[https://hexdocs.pm/ex_break](https://hexdocs.pm/ex_break).
