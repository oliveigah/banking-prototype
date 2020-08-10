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

  def add_funds(account_id, value) do
    Account.Cache.server_process(account_id)
    |> Account.Server.deposit(%{amount: value})
  end

  def create_card_operation(account_id, amount, card_id) do
    Account.Cache.server_process(account_id)
    |> Account.Server.card_transaction(%{amount: amount, card_id: card_id})
  end

  def http_request(path, data) do
    route = @base_url <> path
    {:ok, body} = Poison.encode(data)
    headers = @base_headers
    {:ok, http_result} = HTTPoison.post(route, body, headers)

    {:ok, http_result} = Poison.decode(Map.get(http_result, :body))

    Helpers.map_keys_string_to_atom(http_result)
  end

  test "Post deposit success" do
    data = %{amount: 1000, custom_meta_data: "custom value"}

    http_result = http_request("deposit", data)

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

  test "Post deposit error" do
    data = %{invalid_data: 123}

    http_result = http_request("deposit", data)

    assert Map.get(http_result, :success) === false
    assert Map.get(http_result, :message) !== nil
  end

  test "Post withdraw success" do
    add_funds(1, 1000)

    data = %{amount: 700, custom_meta_data: "custom value"}

    http_result = http_request("withdraw", data)

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
    add_funds(1, 100)

    data = %{amount: 700, custom_meta_data: "custom value"}

    http_result = http_request("withdraw", data)

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

  test "Post withdraw error" do
    data = %{invalid_data: 123}

    http_result = http_request("withdraw", data)

    assert Map.get(http_result, :success) === false
    assert Map.get(http_result, :message) !== nil
  end

  test "Post card transaction success" do
    add_funds(1, 1000)

    data = %{amount: 700, card_id: 1, custom_meta_data: "custom value"}

    http_result = http_request("card/transaction", data)

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
    add_funds(1, 100)

    data = %{amount: 700, card_id: 1, custom_meta_data: "custom value"}

    http_result = http_request("card/transaction", data)

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

  test "Post card transaction error" do
    data = %{invalid_data: 123}

    http_result = http_request("card/transaction", data)

    assert Map.get(http_result, :success) === false
    assert Map.get(http_result, :message) !== nil
  end

  test "Post refund success" do
    add_funds(1, 1000)
    create_card_operation(1, 300, 1)

    data = %{operation_to_refund_id: 2, custom_meta_data: "custom value"}

    http_result = http_request("refund", data)

    response = Map.get(http_result, :response)
    operation = Map.get(response, :operation)
    operation_data = Map.get(operation, :data)

    assert Map.get(http_result, :success) === true
    assert Map.get(response, :approved) === true
    assert Map.get(response, :new_balance) === 1000
    assert Map.get(operation, :id) === 3
    assert Map.get(operation, :type) === "refund"
    assert Map.get(operation, :status) === "done"
    assert Map.get(operation_data, :amount) === 300
    assert Map.get(operation_data, :operation_to_refund_id) === 2
    assert Map.get(operation_data, :custom_meta_data) === "custom value"
  end

  test "Post refund error" do
    data = %{invalid_data: 123}

    http_result = http_request("refund", data)

    assert Map.get(http_result, :success) === false
    assert Map.get(http_result, :message) !== nil
  end
end
