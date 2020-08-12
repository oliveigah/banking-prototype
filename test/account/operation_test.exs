defmodule OperationTest do
  use ExUnit.Case
  doctest Account.Operation

  test "key values should overwrite" do
    new_operation =
      Account.Operation.new(:deposit, %{
        amount: 1000,
        status: :my_custom_status,
        date_time: ~U[2020-07-24 10:00:00Z]
      })

    assert %{
             date_time: ~U[2020-07-24 10:00:00Z],
             type: :deposit,
             status: :my_custom_status,
             data: %{amount: 1000}
           } = new_operation
  end
end
