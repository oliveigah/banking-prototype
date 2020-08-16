defmodule Account.Http.Account.Operation do
  @moduledoc false
  @spec execute(map(), number()) :: {number(), map()}
  def execute(%{} = entry_params, account_id) do
    entry_params
    |> execute_operation(account_id)
    |> generate_http_response()
  end

  defp execute_operation(entry_params, account_id) do
    operation_id =
      Map.get(entry_params, "operation")
      |> String.to_integer()

    account_id
    |> Account.Cache.server_process()
    |> Account.Server.operation(operation_id)
  end

  defp generate_http_response(operation_response) do
    case operation_response do
      nil ->
        {404,
         %{
           success: false,
           message: "Operation not found"
         }}

      operation ->
        {200,
         %{
           success: true,
           response: operation
         }}
    end
  end
end
