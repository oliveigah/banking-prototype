defmodule Account.Http.Index do
  @moduledoc false
  use Plug.Router
  use Plug.ErrorHandler

  plug(Account.Http.Authorizer)
  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)
  plug(:dispatch)

  def child_spec(_arg) do
    port = Application.fetch_env!(:banking, :account_http_port)
    IO.puts("Account HTTP server listening to: port #{port}")

    Plug.Adapters.Cowboy.child_spec(
      scheme: :http,
      options: [port: port],
      plug: __MODULE__
    )
  end

  defp send_http_response({status, result_body}, conn) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Poison.encode!(result_body))
  end

  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    send_http_response(
      {Map.get(reason, :status_code, 500),
       %{
         success: false,
         message: Map.get(reason, :message, "Unkown"),
         details: Map.get(reason, :details, "Unkown")
       }},
      conn
    )
  end

  post("account/deposit") do
    account = conn.assigns[:account_id]

    conn.body_params
    |> Account.Http.Deposit.execute(account)
    |> send_http_response(conn)
  end

  post("account/withdraw") do
    account = conn.assigns[:account_id]

    conn.body_params
    |> Account.Http.Withdraw.execute(account)
    |> send_http_response(conn)
  end

  post("account/transfer") do
    account = conn.assigns[:account_id]

    conn.body_params
    |> Account.Http.Transfer.execute(account)
    |> send_http_response(conn)
  end

  post("account/multi-transfer") do
    account = conn.assigns[:account_id]

    conn.body_params
    |> Account.Http.MultiTransfer.execute(account)
    |> send_http_response(conn)
  end

  post("account/card/transaction") do
    account = conn.assigns[:account_id]

    conn.body_params
    |> Account.Http.Card.Transaction.execute(account)
    |> send_http_response(conn)
  end

  post("account/refund") do
    account = conn.assigns[:account_id]

    conn.body_params
    |> Account.Http.Refund.execute(account)
    |> send_http_response(conn)
  end

  post("account/exchange") do
    account = conn.assigns[:account_id]

    conn.body_params
    |> Account.Http.Exchange.execute(account)
    |> send_http_response(conn)
  end

  get("account/operations") do
    account = conn.assigns[:account_id]

    conn.params
    |> Account.Http.Operations.execute(account)
    |> send_http_response(conn)
  end

  get("account/operation") do
    account = conn.assigns[:account_id]

    conn.params
    |> Account.Http.Account.Operation.execute(account)
    |> send_http_response(conn)
  end

  get("account/balances") do
    account = conn.assigns[:account_id]

    Account.Http.Balances.execute(account)
    |> send_http_response(conn)
  end

  defmodule ValidationError do
    @moduledoc false
    defexception [:details, message: "ValidationError", status_code: 400]

    @impl true
    def exception(missing_fields) do
      %Account.Http.Index.ValidationError{details: missing_fields}
    end
  end
end
