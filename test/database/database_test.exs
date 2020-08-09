defmodule DatabaseTest do
  use ExUnit.Case

  test "initialization" do
    %{workers: workers_processes} = Supervisor.count_children(Database)
    assert workers_processes == 3
  end

  test "connection pooling - same workers for same keys" do
    Database.store_async("test1", %{hello: "world"}, "test")
    result = Database.get("test1", "test")

    assert result == %{hello: "world"}
  end

  test "storage" do
    Database.store_sync("test1", %{hello: "world"}, "test")
    result = Database.get("test1", "test")

    assert result == %{hello: "world"}
  end
end
