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

    test "returns a breaker error when a breaker is tripped", %{opts: opts} do
      fun = fn ret -> ret end
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :circuit_closed}
    end

    test "resets after the breaker timeout", %{opts: opts} do
      fun = fn ret -> ret end
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :circuit_closed}
      ExBreak.rewind_trip(fun, 15)
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      breaker = ExBreak.Registry.get_breaker(fun) |> elem(1) |> Agent.get(& &1)
      refute breaker.tripped
    end
  end
end
