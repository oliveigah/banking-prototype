defmodule AccountCacheTest do
  use ExUnit.Case

  test "account server process" do
    {:ok, server} = Account.Cache.start()
    bob_account_pid = Account.Cache.account_server_process(server, 1)
    alice_account_pid = Account.Cache.account_server_process(server, 2)

    assert bob_account_pid != alice_account_pid
    assert bob_account_pid == Account.Cache.account_server_process(server, 1)
    assert alice_account_pid == Account.Cache.account_server_process(server, 2)
  end
end
