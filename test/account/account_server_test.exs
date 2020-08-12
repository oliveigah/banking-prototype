defmodule AccountServerTest do
  use ExUnit.Case

  setup do
    Helpers.reset_account_system()
  end

  doctest Account.Server

  test "account server process operations #1" do
    bob_account_pid = Account.Cache.server_process(1)

    Account.Server.deposit(bob_account_pid, %{
      amount: 5000,
      currency: :BRL,
      date_time: ~U[2020-07-24 10:00:00Z]
    })

    Account.Server.withdraw(bob_account_pid, %{
      amount: 3000,
      currency: :BRL,
      date_time: ~U[2020-07-24 11:00:00Z]
    })

    Account.Server.deposit(bob_account_pid, %{
      amount: 7000,
      currency: :BRL,
      date_time: ~U[2020-07-24 12:00:00Z]
    })

    assert [
             %Account.Operation{
               data: %{amount: 7000, currency: :BRL},
               type: :deposit,
               status: :done
             },
             %Account.Operation{
               data: %{amount: 3000, currency: :BRL},
               type: :withdraw,
               status: :done
             },
             %Account.Operation{
               data: %{amount: 5000, currency: :BRL},
               type: :deposit,
               status: :done
             }
           ] = Account.Server.operations(bob_account_pid, ~D[2020-07-24])

    assert Account.Server.balance(bob_account_pid, :BRL) == 9000
  end

  test "account server process operations #2" do
    bob_account_pid = Account.Cache.server_process(1)

    Account.Server.deposit(bob_account_pid, %{
      amount: 5000,
      currency: :BRL,
      date_time: ~U[2020-07-24 10:00:00Z]
    })

    Account.Server.withdraw(bob_account_pid, %{
      amount: 10000,
      currency: :BRL,
      date_time: ~U[2020-07-24 10:00:00Z]
    })

    Account.Server.withdraw(bob_account_pid, %{
      amount: 1000,
      currency: :BRL,
      date_time: ~U[2020-07-24 10:00:00Z]
    })

    Account.Server.deposit(bob_account_pid, %{
      amount: 7000,
      currency: :BRL,
      date_time: ~U[2020-07-24 10:00:00Z]
    })

    assert [
             %Account.Operation{
               data: %{currency: :BRL, amount: 5000},
               type: :deposit,
               status: :done
             },
             %Account.Operation{
               data: %{currency: :BRL, amount: 10000, message: _m},
               type: :withdraw,
               status: :denied
             },
             %Account.Operation{
               data: %{currency: :BRL, amount: 1000},
               type: :withdraw,
               status: :done
             },
             %Account.Operation{
               data: %{currency: :BRL, amount: 7000},
               type: :deposit,
               status: :done
             }
           ] = Account.Server.operations(bob_account_pid, ~D[2020-07-24])

    assert Account.Server.balance(bob_account_pid, :BRL) == 11000
  end

  test "account server process operations #3" do
    bob_account_pid = Account.Cache.server_process(1)
    alice_account_pid = Account.Cache.server_process(2)

    Account.Server.deposit(bob_account_pid, %{
      amount: 7000,
      currency: :BRL,
      date_time: ~U[2020-07-24 10:00:00Z]
    })

    Account.Server.transfer_out(bob_account_pid, %{
      amount: 1100,
      currency: :BRL,
      recipient_account_id: 2,
      date_time: ~U[2020-07-24 11:00:00Z]
    })

    Account.Server.transfer_out(bob_account_pid, %{
      amount: 1200,
      currency: :BRL,
      recipient_account_id: 2,
      date_time: ~U[2020-07-24 12:00:00Z]
    })

    Account.Server.transfer_out(bob_account_pid, %{
      amount: 10000,
      currency: :BRL,
      recipient_account_id: 2,
      date_time: ~U[2020-07-24 13:00:00Z]
    })

    Account.Server.transfer_out(bob_account_pid, %{
      amount: 1300,
      currency: :BRL,
      recipient_account_id: 2,
      date_time: ~U[2020-07-24 14:00:00Z]
    })

    assert [
             %Account.Operation{
               data: %{currency: :BRL, amount: 1300, recipient_account_id: 2},
               type: :transfer_out,
               status: :done
             },
             %Account.Operation{
               data: %{currency: :BRL, amount: 10000, recipient_account_id: 2},
               type: :transfer_out,
               status: :denied
             },
             %Account.Operation{
               data: %{currency: :BRL, amount: 1200, recipient_account_id: 2},
               type: :transfer_out,
               status: :done
             },
             %Account.Operation{
               data: %{currency: :BRL, amount: 1100, recipient_account_id: 2},
               type: :transfer_out,
               status: :done
             },
             %Account.Operation{
               data: %{currency: :BRL, amount: 7000},
               type: :deposit,
               status: :done
             }
           ] = Account.Server.operations(bob_account_pid, ~D[2020-07-24])

    assert [
             %Account.Operation{
               data: %{currency: :BRL, amount: 1300, sender_account_id: 1},
               type: :transfer_in,
               status: :done
             },
             %Account.Operation{
               data: %{currency: :BRL, amount: 1200, sender_account_id: 1},
               type: :transfer_in,
               status: :done
             },
             %Account.Operation{
               data: %{currency: :BRL, amount: 1100, sender_account_id: 1},
               type: :transfer_in,
               status: :done
             }
           ] = Account.Server.operations(alice_account_pid, ~D[2020-07-24])

    assert Account.Server.balance(bob_account_pid, :BRL) == 3400
    assert Account.Server.balance(alice_account_pid, :BRL) == 3600
  end

  test "account server process operations #4" do
    bob_account_pid = Account.Cache.server_process(1)

    Account.Server.deposit(bob_account_pid, %{
      amount: 7000,
      currency: :BRL,
      date_time: ~U[2020-07-23 10:00:00Z]
    })

    data = %{
      amount: 1000,
      meta_data: "general meta_data",
      currency: :BRL,
      date_time: ~U[2020-07-24 10:00:00Z],
      recipients_data: [
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.1, recipient_account_id: 4}
      ]
    }

    Account.Server.transfer_out(bob_account_pid, data)

    assert Account.Server.balance(bob_account_pid, :BRL) == 6000

    assert [
             %Account.Operation{
               data: %{
                 amount: 700,
                 currency: :BRL,
                 recipient_account_id: 2,
                 meta_data: "general meta_data",
                 other_data: "another extra data"
               },
               type: :transfer_out,
               status: :done
             },
             %Account.Operation{
               data: %{
                 amount: 200,
                 currency: :BRL,
                 recipient_account_id: 3,
                 meta_data: "specific meta_data"
               },
               type: :transfer_out,
               status: :done
             },
             %Account.Operation{
               data: %{
                 amount: 100,
                 currency: :BRL,
                 recipient_account_id: 4,
                 meta_data: "general meta_data"
               },
               type: :transfer_out,
               status: :done
             }
           ] = Account.Server.operations(bob_account_pid, ~D[2020-07-24])

    alice_account_pid = Account.Cache.server_process(2)

    assert Account.Server.balance(alice_account_pid, :BRL) == 700

    assert [
             %Account.Operation{
               data: %{
                 amount: 700,
                 currency: :BRL,
                 sender_account_id: 1,
                 meta_data: "general meta_data",
                 other_data: "another extra data"
               },
               type: :transfer_in,
               status: :done
             }
           ] = Account.Server.operations(alice_account_pid, ~D[2020-07-24])

    jhon_account_pid = Account.Cache.server_process(3)

    assert Account.Server.balance(jhon_account_pid, :BRL) == 200

    assert [
             %Account.Operation{
               data: %{
                 amount: 200,
                 currency: :BRL,
                 sender_account_id: 1,
                 meta_data: "specific meta_data"
               },
               type: :transfer_in,
               status: :done
             }
           ] = Account.Server.operations(jhon_account_pid, ~D[2020-07-24])

    mary_account_pid = Account.Cache.server_process(4)

    assert Account.Server.balance(mary_account_pid, :BRL) == 100

    assert [
             %Account.Operation{
               data: %{
                 amount: 100,
                 currency: :BRL,
                 sender_account_id: 1,
                 meta_data: "general meta_data"
               },
               type: :transfer_in,
               status: :done
             }
           ] = Account.Server.operations(mary_account_pid, ~D[2020-07-24])
  end

  test "account server process operations #5" do
    bob_account_pid = Account.Cache.server_process(1)

    Account.Server.deposit(bob_account_pid, %{
      amount: 1000,
      currency: :USD,
      date_time: ~U[2020-07-23 10:00:00Z]
    })

    Account.Server.exchange_balances(bob_account_pid, %{
      current_amount: 500,
      current_currency: :USD,
      new_currency: :BRL,
      date_time: ~U[2020-07-23 10:00:00Z]
    })

    assert Account.Server.balances(bob_account_pid) == %{USD: 500, BRL: 2725}

    data = %{
      amount: 1000,
      meta_data: "general meta_data",
      currency: :BRL,
      date_time: ~U[2020-07-24 10:00:00Z],
      recipients_data: [
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.1, recipient_account_id: 4}
      ]
    }

    Account.Server.transfer_out(bob_account_pid, data)

    assert Account.Server.balance(bob_account_pid, :BRL) == 1725

    assert [
             %Account.Operation{
               data: %{
                 amount: 700,
                 currency: :BRL,
                 recipient_account_id: 2,
                 meta_data: "general meta_data",
                 other_data: "another extra data"
               },
               type: :transfer_out,
               status: :done
             },
             %Account.Operation{
               data: %{
                 amount: 200,
                 currency: :BRL,
                 recipient_account_id: 3,
                 meta_data: "specific meta_data"
               },
               type: :transfer_out,
               status: :done
             },
             %Account.Operation{
               data: %{
                 amount: 100,
                 currency: :BRL,
                 recipient_account_id: 4,
                 meta_data: "general meta_data"
               },
               type: :transfer_out,
               status: :done
             }
           ] = Account.Server.operations(bob_account_pid, ~D[2020-07-24])

    alice_account_pid = Account.Cache.server_process(2)

    assert Account.Server.balance(alice_account_pid, :BRL) == 700

    assert [
             %Account.Operation{
               data: %{
                 amount: 700,
                 currency: :BRL,
                 sender_account_id: 1,
                 meta_data: "general meta_data",
                 other_data: "another extra data"
               },
               type: :transfer_in,
               status: :done
             }
           ] = Account.Server.operations(alice_account_pid, ~D[2020-07-24])

    jhon_account_pid = Account.Cache.server_process(3)

    assert Account.Server.balance(jhon_account_pid, :BRL) == 200

    assert [
             %Account.Operation{
               data: %{
                 amount: 200,
                 currency: :BRL,
                 sender_account_id: 1,
                 meta_data: "specific meta_data"
               },
               type: :transfer_in,
               status: :done
             }
           ] = Account.Server.operations(jhon_account_pid, ~D[2020-07-24])

    mary_account_pid = Account.Cache.server_process(4)

    assert Account.Server.balance(mary_account_pid, :BRL) == 100

    assert [
             %Account.Operation{
               data: %{
                 amount: 100,
                 currency: :BRL,
                 sender_account_id: 1,
                 meta_data: "general meta_data"
               },
               type: :transfer_in,
               status: :done
             }
           ] = Account.Server.operations(mary_account_pid, ~D[2020-07-24])
  end
end
