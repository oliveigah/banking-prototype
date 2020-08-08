defmodule Http.Account.Withdraw do
  def execute(entry_body) do
    Helpers.map_keys_string_to_atom(entry_body)
    |> execute_operation()
    |> generate_http_response()
  end

  defp execute_operation(parsed_body) do
    parsed_body
    |> Map.get(:id)
    |> Account.Cache.server_process()
    |> Account.Server.withdraw(Map.get(parsed_body, :data))
  end

  defp generate_http_response(operation_response) do
    case operation_response do
      {:ok, new_balance, operation_id} ->
        {200, %{success: true, new_balance: new_balance, operation_id: operation_id}}
    end
  end
end
