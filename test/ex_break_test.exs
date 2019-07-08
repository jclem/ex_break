defmodule ExBreakTest do
  use ExUnit.Case
  doctest ExBreak

  setup do
    start_supervised({ExBreak, name: ExBreak})
    :ok
  end

  defmodule TestModule do
    def test(value) do
      value
    end
  end

  setup do
    %{fun: fn ret -> ret end, opts: [threshold: 2, timeout_sec: 10]}
  end

  describe ".call/1" do
    test "returns the function return", %{opts: opts} do
      assert ExBreak.call(fn -> :fn_called end, [], opts) == :fn_called
    end

    test "returns the function error", %{fun: fun, opts: opts} do
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
    end

    @tag :focus
    test "returns a breaker error when a breaker is tripped", %{fun: fun, opts: opts} do
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :circuit_closed}
    end

    test "resets after the breaker timeout", %{fun: fun, opts: opts} do
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :circuit_closed}
      GenServer.call(ExBreak, {:rewind_trip, fun, 15})
      assert ExBreak.call(fun, [{:error, :fun_error}], opts) == {:error, :fun_error}
      breaker = ExBreak |> GenServer.call(:get_state) |> ExBreak.State.get(fun)
      refute breaker.tripped
    end
  end
end
