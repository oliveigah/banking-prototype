defmodule HttpAccountTest do
  use ExUnit.Case

  setup do
    Helpers.reset_account_system()
  end

  @base_url "localhost:7000/account/"
  @base_headers [
    {"Authorization", 1},
    {"Content-Type", "Application/json"},
    {"Accept", "Application/json"}
  ]

  def add_funds(account_id, value, currency) do
    Account.Cache.server_process(account_id)
    |> Account.Server.deposit(%{amount: value, currency: currency})
  end

  def create_card_operation(account_id, amount, currency, card_id) do
    Account.Cache.server_process(account_id)
    |> Account.Server.card_transaction(%{amount: amount, currency: currency, card_id: card_id})
  end

  def http_post(path, data, headers \\ @base_headers) do
    route = @base_url <> path
    {:ok, body} = Poison.encode(data)
    {:ok, http_result} = HTTPoison.post(route, body, headers)

    {:ok, http_result} = Poison.decode(Map.get(http_result, :body))

    Helpers.parse_body_response(http_result)
  end

  def http_get(path, params, headers \\ @base_headers) do
    route = @base_url <> path

    {:ok, http_result} = HTTPoison.get(route, headers, params)

    {:ok, http_result} = Poison.decode(Map.get(http_result, :body))

    Helpers.parse_body_response(http_result)
  end

  test "Post deposit success" do
    data = %{amount: 1000, currency: "BRL", custom_meta_data: "custom value"}

    http_result = http_post("deposit", data)

    response = Map.get(http_result, :response)
    operation = Map.get(response, :operation)
    operation_data = Map.get(operation, :data)

    assert Map.get(http_result, :success) === true
    assert Map.get(response, :approved) === true
    assert Map.get(response, :new_balance) === 1000
    assert Map.get(operation, :id) === 1
    assert Map.get(operation, :type) === "deposit"
    assert Map.get(operation, :status) === "done"
    assert Map.get(operation_data, :amount) === 1000
    assert Map.get(operation_data, :custom_meta_data) === "custom value"
  end

  test "Post withdraw success" do
    add_funds(1, 1000, :BRL)

    data = %{amount: 700, currency: "BRL", custom_meta_data: "custom value"}

    http_result = http_post("withdraw", data)

    response = Map.get(http_result, :response)
    operation = Map.get(response, :operation)
    operation_data = Map.get(operation, :data)

    assert Map.get(http_result, :success) === true
    assert Map.get(response, :approved) === true
    assert Map.get(response, :new_balance) === 300
    assert Map.get(operation, :id) === 2
    assert Map.get(operation, :type) === "withdraw"
    assert Map.get(operation, :status) === "done"
    assert Map.get(operation_data, :amount) === 700
    assert Map.get(operation_data, :custom_meta_data) === "custom value"
  end

  test "Post withdraw denied" do
    add_funds(1, 100, :BRL)

    data = %{amount: 700, currency: "BRL", custom_meta_data: "custom value"}

    http_result = http_post("withdraw", data)

    response = Map.get(http_result, :response)
    operation = Map.get(response, :operation)
    operation_data = Map.get(operation, :data)

    assert Map.get(http_result, :success) === true
    assert Map.get(response, :approved) === false
    assert Map.get(response, :new_balance) === 100
    assert Map.get(operation, :id) === 2
    assert Map.get(operation, :type) === "withdraw"
    assert Map.get(operation, :status) === "denied"
    assert Map.get(operation_data, :amount) === 700
    assert Map.get(operation_data, :custom_meta_data) === "custom value"
  end

  test "Post card transaction success" do
    add_funds(1, 1000, :BRL)

    data = %{amount: 700, currency: "BRL", card_id: 1, custom_meta_data: "custom value"}

    http_result = http_post("card/transaction", data)

    response = Map.get(http_result, :response)
    operation = Map.get(response, :operation)
    operation_data = Map.get(operation, :data)

    assert Map.get(http_result, :success) === true
    assert Map.get(response, :approved) === true
    assert Map.get(response, :new_balance) === 300
    assert Map.get(operation, :id) === 2
    assert Map.get(operation, :type) === "card_transaction"
    assert Map.get(operation, :status) === "done"
    assert Map.get(operation_data, :amount) === 700
    assert Map.get(operation_data, :custom_meta_data) === "custom value"
  end

  test "Post card transaction denied" do
    add_funds(1, 100, :BRL)

    data = %{amount: 700, currency: "BRL", card_id: 1, custom_meta_data: "custom value"}

    http_result = http_post("card/transaction", data)

    response = Map.get(http_result, :response)
    operation = Map.get(response, :operation)
    operation_data = Map.get(operation, :data)

    assert Map.get(http_result, :success) === true
    assert Map.get(response, :approved) === false
    assert Map.get(response, :new_balance) === 100
    assert Map.get(operation, :id) === 2
    assert Map.get(operation, :type) === "card_transaction"
    assert Map.get(operation, :status) === "denied"
    assert Map.get(operation_data, :amount) === 700
    assert Map.get(operation_data, :custom_meta_data) === "custom value"
  end

  test "Post refund success" do
    add_funds(1, 1000, :BRL)
    create_card_operation(1, 300, :BRL, 1)

    data = %{operation_to_refund_id: 2, custom_meta_data: "custom value"}

    http_result = http_post("refund", data)

    response = Map.get(http_result, :response)
    operation = Map.get(response, :operation)
    operation_data = Map.get(operation, :data)

    assert Map.get(http_result, :success) === true
    assert Map.get(response, :approved) === true
    assert Map.get(response, :new_balance) === %{BRL: 1000}
    assert Map.get(operation, :id) === 3
    assert Map.get(operation, :type) === "refund"
    assert Map.get(operation, :status) === "done"
    assert Map.get(operation_data, :amount) === 300
    assert Map.get(operation_data, :operation_to_refund_id) === 2
    assert Map.get(operation_data, :custom_meta_data) === "custom value"
  end

  test "Post transfer success" do
    add_funds(1, 1000, :BRL)

    data = %{
      amount: 700,
      currency: "BRL",
      recipient_account_id: 2,
      custom_meta_data: "custom value"
    }

    http_result = http_post("transfer", data)

    response = Map.get(http_result, :response)
    operation = Map.get(response, :operation)
    operation_data = Map.get(operation, :data)

    assert Map.get(http_result, :success) === true
    assert Map.get(response, :approved) === true
    assert Map.get(response, :new_balance) === 300
    assert Map.get(operation, :id) === 2
    assert Map.get(operation, :type) === "transfer_out"
    assert Map.get(operation, :status) === "done"
    assert Map.get(operation_data, :amount) === 700
    assert Map.get(operation_data, :custom_meta_data) === "custom value"

    new_header = List.update_at(@base_headers, 0, fn _ -> {"Authorization", 2} end)

    http_result =
      http_get(
        "operation",
        [params: %{operation: 1}],
        new_header
      )

    response = Map.get(http_result, :response)
    operation_data = Map.get(response, :data)

    assert Map.get(http_result, :success) === true
    assert Map.get(response, :type) === "transfer_in"
    assert Map.get(response, :id) === 1
    assert Map.get(operation_data, :amount) === 700
    assert Map.get(operation_data, :currency) === "BRL"
    assert Map.get(operation_data, :sender_account_id) === 1
  end

  test "Post transfer denied" do
    add_funds(1, 100, :BRL)

    data = %{
      amount: 700,
      currency: "BRL",
      recipient_account_id: 2,
      custom_meta_data: "custom value"
    }

    http_result = http_post("transfer", data)

    response = Map.get(http_result, :response)
    operation = Map.get(response, :operation)
    operation_data = Map.get(operation, :data)

    assert Map.get(http_result, :success) === true
    assert Map.get(response, :approved) === false
    assert Map.get(response, :new_balance) === 100
    assert Map.get(operation, :id) === 2
    assert Map.get(operation, :type) === "transfer_out"
    assert Map.get(operation, :status) === "denied"
    assert Map.get(operation_data, :amount) === 700
    assert Map.get(operation_data, :custom_meta_data) === "custom value"

    new_header = List.update_at(@base_headers, 0, fn _ -> {"Authorization", 2} end)

    http_result =
      http_get(
        "operation",
        [params: %{operation: 1}],
        new_header
      )

    assert Map.get(http_result, :success) === false
  end

  test "Post multi transfer success" do
    add_funds(1, 10000, :BRL)

    data = %{
      amount: 1000,
      meta_data: "general meta_data",
      currency: :BRL,
      recipients_data: [
        %{percentage: 0.7, recipient_account_id: 2, other_data: "another extra data"},
        %{percentage: 0.2, recipient_account_id: 3, meta_data: "specific meta_data"},
        %{percentage: 0.1, recipient_account_id: 4}
      ]
    }

    http_result = http_post("multi-transfer", data)

    response = Map.get(http_result, :response)
    operations = Map.get(response, :operations)
    _recipients_operations = Map.get(response, :recipients_operations_data)

    {first_operation, operations} = List.pop_at(operations, 0)
    first_operation_data = Map.get(first_operation, :data)

    assert Map.get(first_operation, :type) === "transfer_out"
    assert Map.get(first_operation, :id) === 4
    assert Map.get(first_operation_data, :amount) === 100
    assert Map.get(first_operation_data, :currency) === "BRL"
    assert Map.get(first_operation_data, :recipient_account_id) === 4

    {second_operation, operations} = List.pop_at(operations, 0)
    second_operation_data = Map.get(second_operation, :data)

    assert Map.get(second_operation, :type) === "transfer_out"
    assert Map.get(second_operation, :id) === 3
    assert Map.get(second_operation_data, :amount) === 200
    assert Map.get(second_operation_data, :currency) === "BRL"
    assert Map.get(second_operation_data, :recipient_account_id) === 3

    {third_operation, _operations} = List.pop_at(operations, 0)
    third_operation_data = Map.get(third_operation, :data)

    assert Map.get(third_operation, :type) === "transfer_out"
    assert Map.get(third_operation, :id) === 2
    assert Map.get(third_operation_data, :amount) === 700
    assert Map.get(third_operation_data, :currency) === "BRL"
    assert Map.get(third_operation_data, :recipient_account_id) === 2
  end

  test "Post exchange success" do
    add_funds(1, 1000, :USD)

    data = %{
      current_amount: 100,
      current_currency: "USD",
      new_currency: "BRL",
      custom_meta_data: "custom value"
    }

    http_result = http_post("exchange", data)

    response = Map.get(http_result, :response)
    operation = Map.get(response, :operation)
    operation_data = Map.get(operation, :data)

    assert Map.get(http_result, :success) === true
    assert Map.get(response, :approved) === true
    assert Map.get(response, :new_balances) === %{USD: 900, BRL: 545}
    assert Map.get(operation, :id) === 2
    assert Map.get(operation, :type) === "exchange"
    assert Map.get(operation, :status) === "done"
    assert Map.get(operation_data, :custom_meta_data) === "custom value"
  end
end
