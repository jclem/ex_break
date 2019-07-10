defmodule ExBreak.RegistryTest do
  use ExUnit.Case, async: true
  doctest ExBreak.Registry

  alias ExBreak.Registry

  describe ".find_breaker/1" do
    test "finds an existing breaker" do
      func = fn -> :ok end
      {:ok, pid} = Registry.get_breaker(func)
      assert Registry.find_breaker(func) == {:ok, pid}
    end

    test "returns an error when the breaker does not exist" do
      assert Registry.find_breaker(fn -> :ok end) == :error
    end
  end

  describe ".get_breaker/1" do
    test "registers a new breaker" do
      func = fn -> :ok end
      {:ok, pid} = Registry.get_breaker(func)
      assert Registry.find_breaker(func) == {:ok, pid}
    end

    test "finds an existing breaker" do
      func = fn -> :ok end
      {:ok, pid} = Registry.get_breaker(func)
      {:ok, ^pid} = Registry.get_breaker(func)
      assert Registry.find_breaker(func) == {:ok, pid}
    end

    test "removes a breaker when its process dies" do
      func = fn -> :ok end
      {:ok, pid} = Registry.get_breaker(func)
      Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, _, :process, ^pid, _}
      assert Registry.find_breaker(func) == :error
    end
  end
end
