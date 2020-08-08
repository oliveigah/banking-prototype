defmodule AccountServerTest do
  use ExUnit.Case

  setup do
    # Get the pids of all currently alive processes
    accounts_used_pids =
      DynamicSupervisor.which_children(Account.Cache)
      |> Stream.map(fn entry ->
        case entry do
          {_, pid, :worker, [Account.Server]} -> pid
          _ -> nil
        end
      end)
      |> Enum.filter(fn ele -> ele !== nil end)

    # Terminate all processes
    Enum.each(accounts_used_pids, &Process.exit(&1, :clean_up))

    # Reset the "database"
    File.rm_rf("./persist/")
    :ok
  end

  doctest Account.Server

  test "account server process deposit" do
    bob_account_pid = Account.Cache.server_process(1)
    alice_account_pid = Account.Cache.server_process(2)

    Account.Server.deposit(bob_account_pid, %{amount: 5000})

    Account.Server.deposit(alice_account_pid, %{amount: 7000})

    assert Account.Server.balance(bob_account_pid) == 5000
    assert Account.Server.balance(alice_account_pid) == 7000
  end

  test "account server process operations #1" do
    bob_account_pid = Account.Cache.server_process(1)

    Account.Server.deposit(bob_account_pid, %{amount: 5000, date_time: ~U[2020-07-24 10:00:00Z]})
    Account.Server.withdraw(bob_account_pid, %{amount: 3000, date_time: ~U[2020-07-24 10:00:00Z]})
    Account.Server.deposit(bob_account_pid, %{amount: 7000, date_time: ~U[2020-07-24 10:00:00Z]})

    assert [
             %Operation{data: %{amount: 5000}, type: :deposit, status: :done},
             %Operation{data: %{amount: 3000}, type: :withdraw, status: :done},
             %Operation{data: %{amount: 7000}, type: :deposit, status: :done}
           ] = Account.Server.operations(bob_account_pid, ~D[2020-07-24])

    assert Account.Server.balance(bob_account_pid) == 9000
  end

  test "account server process operations #2" do
    bob_account_pid = Account.Cache.server_process(1)

    Account.Server.deposit(bob_account_pid, %{amount: 5000, date_time: ~U[2020-07-24 10:00:00Z]})

    Account.Server.withdraw(bob_account_pid, %{amount: 10000, date_time: ~U[2020-07-24 10:00:00Z]})

    Account.Server.withdraw(bob_account_pid, %{amount: 1000, date_time: ~U[2020-07-24 10:00:00Z]})
    Account.Server.deposit(bob_account_pid, %{amount: 7000, date_time: ~U[2020-07-24 10:00:00Z]})

    assert [
             %Operation{data: %{amount: 5000}, type: :deposit, status: :done},
             %Operation{data: %{amount: 10000, message: _m}, type: :withdraw, status: :denied},
             %Operation{data: %{amount: 1000}, type: :withdraw, status: :done},
             %Operation{data: %{amount: 7000}, type: :deposit}
           ] = Account.Server.operations(bob_account_pid, ~D[2020-07-24])

    assert Account.Server.balance(bob_account_pid) == 11000
  end
end
