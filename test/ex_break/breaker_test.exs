defmodule ExBreak.BreakerTest do
  use ExUnit.Case, async: true
  doctest ExBreak.Breaker

  alias ExBreak.Breaker

  describe ".is_tripped/2" do
    test "returns false if the breaker is not tripped" do
      breaker = %Breaker{tripped: false}
      refute Breaker.is_tripped(breaker, 10)
    end

    test "returns false if the breaker is tripped, but expired" do
      breaker = %Breaker{
        tripped: true,
        tripped_at: DateTime.add(DateTime.utc_now(), -60, :second)
      }

      refute Breaker.is_tripped(breaker, 10)
    end

    test "returns true if the breaker is tripped and not expired" do
      breaker = %Breaker{
        tripped: true,
        tripped_at: DateTime.add(DateTime.utc_now(), -60, :second)
      }

      assert Breaker.is_tripped(breaker, 70)
    end
  end
end
