defmodule ExBreak.BreakerTest do
  use ExUnit.Case, async: true
  doctest ExBreak.Breaker

  alias ExBreak.Breaker

  setup do
    pid = start_supervised!(Breaker)
    %{breaker: pid}
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
end
