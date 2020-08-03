defmodule AccountCacheTest do
  use ExUnit.Case

  doctest Account.Cache

  test "account server process" do
    bob_account_pid = Account.Cache.server_process(1)
    alice_account_pid = Account.Cache.server_process(2)

    assert bob_account_pid != alice_account_pid
    assert bob_account_pid == Account.Cache.server_process(1)
    assert alice_account_pid == Account.Cache.server_process(2)
  end
end
