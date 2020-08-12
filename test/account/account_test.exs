defmodule AccountTest do
  use ExUnit.Case

  doctest Account

  test "account deposit" do
    {:ok, bob_account, operation_data} =
      Account.new()
      |> Account.deposit(%{amount: 5000, currency: :BRL})

    assert Account.balance(bob_account, :BRL) == 5000

    assert %Account.Operation{
             type: :deposit,
             status: :done,
             data: %{amount: 5000, currency: :BRL}
           } = operation_data
  end

  test "account transfer in" do
    {:ok, bob_account, operation_data} =
      Account.new()
      |> Account.transfer_in(%{
        amount: 5000,
        currency: :BRL,
        sender_account_id: 1
      })

    assert Account.balance(bob_account, :BRL) == 5000

    assert %Account.Operation{
             data: %{amount: 5000, currency: :BRL, sender_account_id: 1},
             type: :transfer_in,
             status: :done
           } = operation_data
  end

  test "account withdraw success" do
    {:ok, bob_account, operation_data} =
      Account.new(%{balances: %{BRL: 5000}})
      |> Account.withdraw(%{amount: 3000, currency: :BRL})

    assert Account.balance(bob_account, :BRL) == 2000

    assert %Account.Operation{
             data: %{amount: 3000, currency: :BRL},
             type: :withdraw,
             status: :done
           } = operation_data
  end

  test "account withdraw failure" do
    {:denied, reason, bob_account, operation_data} =
      Account.new(%{balances: %{BRL: 3000}})
      |> Account.withdraw(%{amount: 5000, currency: :BRL})

    assert Account.balance(bob_account, :BRL) == 3000

    assert %Account.Operation{
             data: %{amount: 5000, message: ^reason, currency: :BRL},
             type: :withdraw,
             status: :denied
           } = operation_data
  end

  test "account transfer_out success" do
    {:ok, bob_account, operation_data} =
      Account.new(%{balances: %{BRL: 7000}})
      |> Account.transfer_out(%{amount: 3000, currency: :BRL, recipient_account_id: 1})

    assert Account.balance(bob_account, :BRL) == 4000

    assert %Account.Operation{
             data: %{amount: 3000, currency: :BRL, recipient_account_id: 1},
             type: :transfer_out,
             status: :done
           } = operation_data
  end

  test "account transfer_out failure" do
    {:denied, reason, bob_account, operation_data} =
      Account.new(%{balances: %{BRL: 3000}})
      |> Account.transfer_out(%{amount: 5000, currency: :BRL, recipient_account_id: 1})

    assert Account.balance(bob_account, :BRL) == 3000

    assert %Account.Operation{
             data: %{amount: 5000, message: ^reason, currency: :BRL},
             type: :transfer_out,
             status: :denied
           } = operation_data
  end

  test "account card_transaction success" do
    {:ok, bob_account, operation_data} =
      Account.new(%{balances: %{BRL: 10000}})
      |> Account.card_transaction(%{amount: 3000, currency: :BRL, card_id: 1})

    assert Account.balance(bob_account, :BRL) == 7000

    assert %Account.Operation{
             data: %{amount: 3000, currency: :BRL},
             type: :card_transaction,
             status: :done
           } = operation_data
  end

  test "account card_transaction failure" do
    {:denied, reason, bob_account, operation_data} =
      Account.new(%{balances: %{BRL: 5000}})
      |> Account.card_transaction(%{amount: 7000, currency: :BRL, card_id: 1})

    assert Account.balance(bob_account, :BRL) == 5000

    assert %Account.Operation{
             data: %{amount: 7000, currency: :BRL, message: ^reason},
             type: :card_transaction,
             status: :denied
           } = operation_data
  end

  test "account refund success" do
    bob_account = Account.new(%{balances: %{BRL: 5000}})

    {:ok, bob_account, %{id: card_operation_id} = card_operation} =
      Account.card_transaction(bob_account, %{
        amount: 3000,
        currency: :BRL,
        card_id: 1
      })

    assert Account.balance(bob_account, :BRL) == 2000

    assert %Account.Operation{
             data: %{amount: 3000, currency: :BRL},
             type: :card_transaction,
             status: :done
           } = card_operation

    {:ok, bob_account, refund_operation} =
      Account.refund(bob_account, %{
        operation_to_refund_id: card_operation_id
      })

    assert Account.balance(bob_account, :BRL) == 5000

    assert %Account.Operation{
             data: %{amount: 3000, card_id: 1, currency: :BRL},
             type: :card_transaction,
             status: :refunded
           } = Account.operation(bob_account, card_operation_id)

    assert %Account.Operation{
             data: %{operation_to_refund_id: ^card_operation_id},
             type: :refund,
             status: :done
           } = refund_operation
  end

  test "account refund error should not register operation" do
    bob_account = Account.new(%{balances: %{BRL: 5000}})

    {:ok, bob_account, %{id: other_operation_id} = other_operation} =
      Account.transfer_out(bob_account, %{
        amount: 3000,
        currency: :BRL,
        recipient_account_id: 2
      })

    {:error, _reason, bob_account} =
      Account.refund(bob_account, %{
        operation_to_refund_id: other_operation_id
      })

    assert Account.balance(bob_account, :BRL) == 2000

    assert other_operation == Account.operation(bob_account, other_operation_id)

    assert nil == Account.operation(bob_account, other_operation_id + 1)
  end

  test "account operations" do
    bob_account = Account.new()

    with {:ok, bob_account, _} <-
           Account.deposit(bob_account, %{
             amount: 5000,
             currency: :BRL,
             date_time: ~U[2020-07-24 10:00:00Z]
           }),
         {:ok, bob_account, _} <-
           Account.withdraw(bob_account, %{
             amount: 5000,
             currency: :BRL,
             date_time: ~U[2020-07-24 11:00:00Z]
           }),
         {:denied, _, bob_account, _} <-
           Account.withdraw(bob_account, %{
             amount: 5000,
             currency: :BRL,
             date_time: ~U[2020-07-26 10:00:00Z]
           }),
         {:ok, bob_account, _} <-
           Account.deposit(bob_account, %{
             amount: 5000,
             currency: :BRL,
             date_time: ~U[2020-07-27 10:00:00Z]
           }) do
      assert [
               %Account.Operation{
                 data: %{amount: 5000, currency: :BRL},
                 type: :withdraw,
                 status: :done
               },
               %Account.Operation{
                 data: %{amount: 5000, currency: :BRL},
                 type: :deposit,
                 status: :done
               }
             ] = Account.operations(bob_account, ~D[2020-07-24])

      assert [
               %Account.Operation{
                 data: %{amount: 5000, currency: :BRL},
                 type: :deposit,
                 status: :done
               },
               %Account.Operation{
                 data: %{amount: 5000, currency: :BRL},
                 type: :withdraw,
                 status: :denied
               }
             ] = Account.operations(bob_account, ~D[2020-07-25], ~D[2020-07-27])
    end
  end

  test "transfer out list" do
    bob_account = Account.new(%{balances: %{BRL: 10000}})

    data = %{
      amount: 1000,
      currency: :BRL,
      meta_data: "general meta_data",
      recipients_data: [
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.1, recipient_account_id: 4}
      ]
    }

    {:ok, bob_account, operations_list} = Account.transfer_out(bob_account, data)

    assert Account.balance(bob_account, :BRL) === 9000

    assert %Account.Operation{
             data: %{
               amount: 100,
               recipient_account_id: 4,
               meta_data: "general meta_data",
               currency: :BRL
             },
             type: :transfer_out,
             status: :done
           } = Enum.at(operations_list, 0)

    assert %Account.Operation{
             data: %{
               amount: 200,
               recipient_account_id: 3,
               currency: :BRL,
               meta_data: "specific meta_data"
             },
             type: :transfer_out,
             status: :done
           } = Enum.at(operations_list, 1)

    assert %Account.Operation{
             data: %{
               amount: 700,
               currency: :BRL,
               recipient_account_id: 2,
               meta_data: "general meta_data",
               other_data: "another extra data"
             },
             type: :transfer_out,
             status: :done
           } = Enum.at(operations_list, 2)
  end

  test "exchange balances sucess" do
    bob_account = Account.new(%{balances: %{USD: 1000, BRL: 0}})

    {:ok, bob_account, operation} =
      Account.exchange_balances(bob_account, %{
        current_amount: 100,
        current_currency: :USD,
        new_currency: :BRL
      })

    assert Account.balances(bob_account) === %{USD: 900, BRL: 545}
    assert Map.get(operation, :type) === :exchange
    assert Map.get(operation, :status) === :done
  end

  test "exchange balances denied" do
    bob_account = Account.new(%{balances: %{USD: 100, BRL: 0}})

    {:denied, _reason, bob_account, operation} =
      Account.exchange_balances(bob_account, %{
        current_amount: 1000,
        current_currency: :USD,
        new_currency: :BRL
      })

    assert Account.balances(bob_account) === %{USD: 100, BRL: 0}
    assert Map.get(operation, :type) === :exchange
    assert Map.get(operation, :status) === :denied
  end
end
