defmodule Http.Account.Deposit do
  @required_body %{
    id: &is_number/1,
    data: %{
      amount: &is_number/1
    }
  }
  def execute(entry_body) do
    parsed_body = Helpers.map_keys_string_to_atom(entry_body)

    error_list = Helpers.validate_body(@required_body, parsed_body)

    case error_list do
      [] ->
        parsed_body
        |> execute_operation()
        |> generate_http_response()

      non_empty ->
        {400, %{success: false, message: non_empty}}
    end
  end

  defp execute_operation(parsed_body) do
    parsed_body
    |> Map.get(:id)
    |> Account.Cache.server_process()
    |> Account.Server.deposit(Map.get(parsed_body, :data))
  end

  defp generate_http_response(operation_response) do
    case operation_response do
      {:ok, new_balance, operation_id} ->
        {200,
         %{
           success: true,
           data: %{
             approved: true,
             new_balance: new_balance,
             operation_id: operation_id
           }
         }}
    end
  end
end
