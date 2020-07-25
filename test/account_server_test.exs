defmodule AccountServerTest do
  use ExUnit.Case
  doctest Account.Server

  test "account server process deposit" do
    {:ok, bob_account_pid} = Account.Server.start(%{id: 1})
    {:ok, alice_account_pid} = Account.Server.start(%{id: 2})

    Account.Server.deposit(bob_account_pid, %{amount: 5000})
    Account.Server.deposit(alice_account_pid, %{amount: 7000})

    assert Account.Server.balance(bob_account_pid) == 5000
    assert Account.Server.balance(alice_account_pid) == 7000
  end

  test "account server process operations #1" do
    {:ok, bob_account_pid} = Account.Server.start(%{id: 1})

    Account.Server.deposit(bob_account_pid, %{amount: 5000})
    Account.Server.withdraw(bob_account_pid, %{amount: 3000})
    Account.Server.deposit(bob_account_pid, %{amount: 7000})

    assert [
             %Operation{data: %{amount: 5000}, type: :deposit, status: :done},
             %Operation{data: %{amount: 3000}, type: :withdraw, status: :done},
             %Operation{data: %{amount: 7000}, type: :deposit, status: :done}
           ] = Account.Server.operations(bob_account_pid, Date.utc_today())

    assert Account.Server.balance(bob_account_pid) == 9000
  end

  test "account server process operations #2" do
    {:ok, bob_account_pid} = Account.Server.start(%{id: 1})

    Account.Server.deposit(bob_account_pid, %{amount: 5000})
    Account.Server.withdraw(bob_account_pid, %{amount: 10000})
    Account.Server.withdraw(bob_account_pid, %{amount: 1000})
    Account.Server.deposit(bob_account_pid, %{amount: 7000})

    assert [
             %Operation{data: %{amount: 5000}, type: :deposit, status: :done},
             %Operation{data: %{amount: 10000, message: _m}, type: :withdraw, status: :denied},
             %Operation{data: %{amount: 1000}, type: :withdraw, status: :done},
             %Operation{data: %{amount: 7000}, type: :deposit}
           ] = Account.Server.operations(bob_account_pid, Date.utc_today())

    assert Account.Server.balance(bob_account_pid) == 11000
  end
end
