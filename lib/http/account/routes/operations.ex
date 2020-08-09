defmodule Http.Account.Operations do
  @spec execute(map(), number()) :: {number(), map()}
  def execute(%{} = entry_params, account_id) do
    entry_params
    |> execute_operation(account_id)
    |> generate_http_response()
  end

  defp string_to_date(string) do
    [year, month, day] =
      String.split(string, "-")
      |> Enum.map(&String.to_integer/1)

    Date.new(year, month, day)
  end

  defp execute_operation(entry_params, account_id) do
    case map_size(entry_params) do
      1 ->
        {:ok, date} = string_to_date(Map.get(entry_params, "date"))

        account_id
        |> Account.Cache.server_process()
        |> Account.Server.operations(date)

      2 ->
        {:ok, ini} = string_to_date(Map.get(entry_params, "ini"))
        {:ok, fin} = string_to_date(Map.get(entry_params, "fin"))

        account_id
        |> Account.Cache.server_process()
        |> Account.Server.operations(ini, fin)
    end
  end

  defp generate_http_response(operation_response) do
    case operation_response do
      list ->
        {200,
         %{
           success: true,
           response: list
         }}
    end
  end
end
