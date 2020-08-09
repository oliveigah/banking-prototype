defmodule AccountTest do
  use ExUnit.Case
  doctest Account

  test "account deposit" do
    {:ok, bob_account} =
      Account.new()
      |> Account.deposit(%{amount: 5000, date_time: ~U[2020-07-24 10:00:00Z]})

    assert Account.balance(bob_account) == 5000

    operations_list = Account.operations(bob_account, ~D[2020-07-24])

    assert {%Operation{
              type: :deposit,
              status: :done,
              data: %{amount: 5000}
            }, _} = List.pop_at(operations_list, 0)
  end

  test "account transfer in" do
    {:ok, bob_account} =
      Account.new()
      |> Account.transfer_in(%{
        amount: 5000,
        sender_account_id: 1,
        date_time: ~U[2020-07-24 10:00:00Z]
      })

    assert Account.balance(bob_account) == 5000

    assert [
             %Operation{data: %{amount: 5000}, type: :transfer_in, status: :done}
           ] = Account.operations(bob_account, ~D[2020-07-24])
  end

  test "account withdraw success" do
    bob_account = Account.new()

    with {:ok, bob_account} <-
           Account.deposit(bob_account, %{amount: 5000, date_time: ~U[2020-07-24 10:00:00Z]}),
         {:ok, bob_account} <-
           Account.withdraw(bob_account, %{amount: 3000, date_time: ~U[2020-07-24 10:00:00Z]}) do
      assert Account.balance(bob_account) == 2000

      assert [
               %Operation{data: %{amount: 5000}, type: :deposit, status: :done},
               %Operation{data: %{amount: 3000}, type: :withdraw, status: :done}
             ] = Account.operations(bob_account, ~D[2020-07-24])
    end
  end

  test "account withdraw failure" do
    bob_account = Account.new()

    with {:ok, bob_account} <-
           Account.deposit(bob_account, %{amount: 3000, date_time: ~U[2020-07-24 10:00:00Z]}),
         {:denied, _reason, bob_account} <-
           Account.withdraw(bob_account, %{amount: 5000, date_time: ~U[2020-07-24 10:00:00Z]}) do
      assert Account.balance(bob_account) == 3000

      assert [
               %Operation{data: %{amount: 3000}, type: :deposit, status: :done},
               %Operation{data: %{amount: 5000, message: _m}, type: :withdraw, status: :denied}
             ] = Account.operations(bob_account, ~D[2020-07-24])
    end
  end

  test "account transfer_out success" do
    bob_account = Account.new()

    with {:ok, bob_account} <-
           Account.deposit(bob_account, %{amount: 5000, date_time: ~U[2020-07-24 10:00:00Z]}),
         {:ok, bob_account} <-
           Account.transfer_out(bob_account, %{
             amount: 3000,
             recipient_account_id: 1,
             date_time: ~U[2020-07-24 10:00:00Z]
           }) do
      assert Account.balance(bob_account) == 2000

      assert [
               %Operation{data: %{amount: 5000}, type: :deposit, status: :done},
               %Operation{data: %{amount: 3000}, type: :transfer_out, status: :done}
             ] = Account.operations(bob_account, ~D[2020-07-24])
    end
  end

  test "account transfer_out failure" do
    bob_account = Account.new()

    with {:ok, bob_account} <-
           Account.deposit(bob_account, %{amount: 3000, date_time: ~U[2020-07-24 10:00:00Z]}),
         {:denied, _reason, bob_account} <-
           Account.transfer_out(bob_account, %{
             amount: 5000,
             recipient_account_id: 1,
             date_time: ~U[2020-07-24 10:00:00Z]
           }) do
      assert Account.balance(bob_account) == 3000

      assert [
               %Operation{data: %{amount: 3000}, type: :deposit, status: :done},
               %Operation{
                 data: %{amount: 5000, message: _m},
                 type: :transfer_out,
                 status: :denied
               }
             ] = Account.operations(bob_account, ~D[2020-07-24])
    end
  end

  test "account card_transaction success" do
    bob_account = Account.new()

    with {:ok, bob_account} <-
           Account.deposit(bob_account, %{amount: 5000, date_time: ~U[2020-07-24 10:00:00Z]}),
         {:ok, bob_account} <-
           Account.card_transaction(bob_account, %{
             amount: 3000,
             card_id: 1,
             date_time: ~U[2020-07-24 10:00:00Z]
           }) do
      assert Account.balance(bob_account) == 2000

      assert [
               %Operation{
                 data: %{amount: 5000},
                 type: :deposit,
                 status: :done,
                 date_time: ~U[2020-07-24 10:00:00Z]
               },
               %Operation{
                 data: %{amount: 3000},
                 type: :card_transaction,
                 status: :done,
                 date_time: ~U[2020-07-24 10:00:00Z]
               }
             ] = Account.operations(bob_account, ~D[2020-07-24])
    end
  end

  test "account card_transaction failure" do
    bob_account = Account.new()

    with {:ok, bob_account} <-
           Account.deposit(bob_account, %{amount: 3000, date_time: ~U[2020-07-24 10:00:00Z]}),
         {:denied, _reason, bob_account} <-
           Account.card_transaction(bob_account, %{
             amount: 5000,
             card_id: 1,
             date_time: ~U[2020-07-24 10:00:00Z]
           }) do
      assert Account.balance(bob_account) == 3000

      assert [
               %Operation{data: %{amount: 3000}, type: :deposit, status: :done},
               %Operation{
                 data: %{amount: 5000, message: _m},
                 type: :card_transaction,
                 status: :denied
               }
             ] = Account.operations(bob_account, ~D[2020-07-24])
    end
  end

  test "account refund success" do
    bob_account = Account.new()

    with {:ok, bob_account} <-
           Account.deposit(bob_account, %{amount: 5000, date_time: ~U[2020-07-24 10:00:00Z]}),
         {:ok, bob_account} <-
           Account.card_transaction(bob_account, %{
             amount: 3000,
             card_id: 1,
             date_time: ~U[2020-07-24 11:00:00Z]
           }),
         {:ok, bob_account} <-
           Account.refund(bob_account, %{
             operation_to_refund_id: 2,
             date_time: ~U[2020-07-24 12:00:00Z]
           }) do
      assert Account.balance(bob_account) == 5000

      assert [
               %Operation{
                 data: %{amount: 3000, operation_to_refund_id: 2},
                 type: :refund,
                 status: :done
               },
               %Operation{data: %{amount: 3000}, type: :card_transaction, status: :refunded},
               %Operation{data: %{amount: 5000}, type: :deposit, status: :done}
             ] = Account.operations(bob_account, ~D[2020-07-24])
    end
  end

  test "account refund error should not register operation" do
    bob_account = Account.new()

    with {:ok, bob_account} <-
           Account.deposit(bob_account, %{amount: 5000, date_time: ~U[2020-07-24 11:00:00Z]}),
         {:ok, bob_account} <-
           Account.withdraw(bob_account, %{
             amount: 3000,
             card_id: 1,
             date_time: ~U[2020-07-24 12:00:00Z]
           }),
         {:error, _message, bob_account} <-
           Account.refund(bob_account, %{
             operation_to_refund_id: 2,
             date_time: ~U[2020-07-24 13:00:00Z]
           }) do
      assert Account.balance(bob_account) == 2000

      assert [
               %Operation{data: %{amount: 3000}, type: :withdraw, status: :done},
               %Operation{data: %{amount: 5000}, type: :deposit, status: :done}
             ] = Account.operations(bob_account, ~D[2020-07-24])
    end
  end

  test "account operations" do
    bob_account = Account.new()

    with {:ok, bob_account} <-
           Account.deposit(bob_account, %{amount: 5000, date_time: ~U[2020-07-24 10:00:00Z]}),
         {:ok, bob_account} <-
           Account.withdraw(bob_account, %{amount: 5000, date_time: ~U[2020-07-24 11:00:00Z]}),
         {:denied, _, bob_account} <-
           Account.withdraw(bob_account, %{amount: 5000, date_time: ~U[2020-07-26 10:00:00Z]}),
         {:ok, bob_account} <-
           Account.deposit(bob_account, %{amount: 5000, date_time: ~U[2020-07-27 10:00:00Z]}) do
      assert [
               %Operation{data: %{amount: 5000}, type: :withdraw, status: :done},
               %Operation{data: %{amount: 5000}, type: :deposit, status: :done}
             ] = Account.operations(bob_account, ~D[2020-07-24])

      assert [
               %Operation{data: %{amount: 5000}, type: :deposit, status: :done},
               %Operation{data: %{amount: 5000}, type: :withdraw, status: :denied}
             ] = Account.operations(bob_account, ~D[2020-07-25], ~D[2020-07-27])
    end
  end

end
