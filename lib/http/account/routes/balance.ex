defmodule Http.Account.Balance do
  @spec execute(number()) :: {number(), map()}
  def execute(account_id) do
    account_id
    |> execute_operation()
    |> generate_http_response()
  end

  defp execute_operation(account_id) do
    account_id
    |> Account.Cache.server_process()
    |> Account.Server.balance()
  end

  defp generate_http_response(operation_response) do
    case operation_response do
      balance ->
        {200,
         %{
           success: true,
           response: %{balance: balance}
         }}
    end
  end
end
