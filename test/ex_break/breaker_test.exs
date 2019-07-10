defmodule ExBreak.BreakerTest do
  use ExUnit.Case, async: true
  doctest ExBreak.Breaker

  alias ExBreak.Breaker

  setup do
    pid = start_supervised!(Breaker)
    %{breaker: pid}
  end

  describe ".increment/2" do
    test "increments the breaker's tripped count", %{breaker: pid} do
      Breaker.increment(pid, 0)
      assert Agent.get(pid, & &1.break_count) == 1
    end

    test "set no tripped and tripped_at if count does not exceed threshold", %{breaker: pid} do
      Breaker.increment(pid, 2)
      assert Agent.get(pid, & &1) == %Breaker{break_count: 1, tripped: false, tripped_at: nil}
    end

    test "sets tripped and tripped_at if count exceeds threshold", %{breaker: pid} do
      Breaker.increment(pid, 1)
      breaker = Agent.get(pid, & &1)
      assert breaker.tripped
      assert breaker.tripped_at
    end
  end

  describe ".is_tripped/2" do
    test "returns false if the breaker is not tripped", %{breaker: pid} do
      Agent.update(pid, &Map.put(&1, :tripped, false))
      refute Breaker.is_tripped(pid, 10)
    end

    test "returns false if the breaker is tripped, but expired", %{breaker: pid} do
      Agent.update(
        pid,
        &Map.merge(&1, %{
          tripped: true,
          tripped_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })
      )

      refute Breaker.is_tripped(pid, 10)
    end

    test "returns true if the breaker is tripped and not expired", %{breaker: pid} do
      Agent.update(
        pid,
        &Map.merge(&1, %{
          tripped: true,
          tripped_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })
      )

      assert Breaker.is_tripped(pid, 70)
    end
  end

  describe ".reset_tripped/1" do
    test "resets the breaker if it is tripped", %{breaker: pid} do
      Breaker.increment(pid, 1)
      breaker = Agent.get(pid, & &1)
      assert breaker.tripped
      Breaker.reset_tripped(pid)
      breaker = Agent.get(pid, & &1)
      refute breaker.tripped
      assert breaker.break_count == 0
    end

    test "returns the breaker if it is not tripped", %{breaker: pid} do
      Breaker.increment(pid, 2)
      Breaker.reset_tripped(pid)
      breaker = Agent.get(pid, & &1)
      assert breaker.break_count == 1
    end
  end
end
