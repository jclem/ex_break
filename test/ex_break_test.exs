defmodule ExBreakTest do
  use ExUnit.Case
  doctest ExBreak

  defmodule TestModule do
    def test(value) do
      value
    end
  end

  setup do
    %{opts: [threshold: 2, timeout_sec: 10]}
  end

  describe ".call/1" do
    test "returns the function return", %{opts: opts} do
      assert ExBreak.call(fn -> :fn_called end, [], opts) == :fn_called
    end

    test "returns the function error", %{opts: opts} do
      fun = fn ret -> ret end
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
    end

    test "calls on_trip on trip", %{opts: opts} do
      self_pid = self()
      opts = Keyword.put(opts, :on_trip, fn breaker -> send(self_pid, breaker) end)

      fun = fn ret -> ret end
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}

      assert_receive %ExBreak.Breaker{break_count: 2, tripped: true}
    end

    test "returns a breaker error when a breaker is tripped", %{opts: opts} do
      fun = fn ret -> ret end
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :circuit_breaker_tripped}
    end

    test "resets after the breaker timeout", %{opts: opts} do
      fun = fn ret -> ret end
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :circuit_breaker_tripped}
      ExBreak.rewind_trip(fun, 15)
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      breaker = ExBreak.Registry.get_breaker(fun) |> elem(1) |> Agent.get(& &1)
      refute breaker.tripped
    end

    test "increments on raised errors when not configure to", %{opts: opts} do
      fun = fn -> raise "Oops" end
      assert_raise RuntimeError, "Oops", fn -> ExBreak.call(fun, [], opts) end
      assert_raise RuntimeError, "Oops", fn -> ExBreak.call(fun, [], opts) end
      assert ExBreak.call(fun, [], opts) == {:error, :circuit_breaker_tripped}
    end

    test "increments on raised errors when configure to", %{opts: opts} do
      opts =
        Keyword.put(opts, :match_exception, fn
          %RuntimeError{} -> true
          _ -> false
        end)

      fun = fn -> raise "Oops" end
      assert_raise RuntimeError, "Oops", fn -> ExBreak.call(fun, [], opts) end
      assert_raise RuntimeError, "Oops", fn -> ExBreak.call(fun, [], opts) end
      assert ExBreak.call(fun, [], opts) == {:error, :circuit_breaker_tripped}
    end

    test "can handle pattern matches", %{opts: opts} do
      opts =
        Keyword.put(opts, :match_return, fn
          {:ok, _} -> true
          _ -> false
        end)

      fun = fn -> {:ok, "foo"} end
      assert ExBreak.call(fun, [], opts) == {:ok, "foo"}
      assert ExBreak.call(fun, [], opts) == {:ok, "foo"}
      assert ExBreak.call(fun, [], opts) == {:error, :circuit_breaker_tripped}
    end
  end
end
