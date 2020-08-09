defmodule Http.Account do
  use Plug.Router
  use Plug.ErrorHandler

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)
  plug(:dispatch)

  def child_spec(_arg) do
    Plug.Adapters.Cowboy.child_spec(
      scheme: :http,
      options: [port: 3000],
      plug: __MODULE__
    )
  end

  defp send_http_response({status, result_body}, conn) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Poison.encode!(result_body))
  end

  defp send_authorization_error(conn) do
    send_http_response({401, %{success: false, message: "Authorization Error"}}, conn)
  end

  defp authorizer(token) do
    try do
      {:ok, String.to_integer(token)}
    rescue
      _ -> :denied
    end
  end

  def handle_errors(conn, %{kind: kind, reason: _reason, stack: _stack}) do
    send_http_response({500, %{success: false, message: kind}}, conn)
  end

  post("account/deposit") do
    authorization_result =
      Plug.Conn.get_req_header(conn, "authorization")
      |> List.first()
      |> authorizer()

    case authorization_result do
      {:ok, account} ->
        conn.body_params
        |> Http.Account.Deposit.execute(account)
        |> send_http_response(conn)

      :denied ->
        send_authorization_error(conn)
    end
  end

  post("account/withdraw") do
    authorization_result =
      Plug.Conn.get_req_header(conn, "authorization")
      |> List.first()
      |> authorizer()

    case authorization_result do
      {:ok, account} ->
        conn.body_params
        |> Http.Account.Withdraw.execute(account)
        |> send_http_response(conn)

      :denied ->
        send_authorization_error(conn)
    end
  end

  post("account/transfer") do
    authorization_result =
      Plug.Conn.get_req_header(conn, "authorization")
      |> List.first()
      |> authorizer()

    case authorization_result do
      {:ok, account} ->
        conn.body_params
        |> Http.Account.Transfer.execute(account)
        |> send_http_response(conn)

      :denied ->
        send_authorization_error(conn)
    end
  end

  post("account/card/transaction") do
    authorization_result =
      Plug.Conn.get_req_header(conn, "authorization")
      |> List.first()
      |> authorizer()

    case authorization_result do
      {:ok, account} ->
        conn.body_params
        |> Http.Account.Card.Transaction.execute(account)
        |> send_http_response(conn)

      :denied ->
        send_authorization_error(conn)
    end
  end

  post("account/refund") do
    authorization_result =
      Plug.Conn.get_req_header(conn, "authorization")
      |> List.first()
      |> authorizer()

    case authorization_result do
      {:ok, account} ->
        conn.body_params
        |> Http.Account.Refund.execute(account)
        |> send_http_response(conn)

      :denied ->
        send_authorization_error(conn)
    end
  end

  get("account/operations") do
    authorization_result =
      Plug.Conn.get_req_header(conn, "authorization")
      |> List.first()
      |> authorizer()

    case authorization_result do
      {:ok, account} ->
        conn.params
        |> Http.Account.Operations.execute(account)
        |> send_http_response(conn)

      :denied ->
        send_authorization_error(conn)
    end
  end

  get("account/operation") do
    authorization_result =
      Plug.Conn.get_req_header(conn, "authorization")
      |> List.first()
      |> authorizer()

    case authorization_result do
      {:ok, account} ->
        conn.params
        |> Http.Account.Operation.execute(account)
        |> send_http_response(conn)

      :denied ->
        send_authorization_error(conn)
    end
  end

  get("account/balance") do
    authorization_result =
      Plug.Conn.get_req_header(conn, "authorization")
      |> List.first()
      |> authorizer()

    case authorization_result do
      {:ok, account} ->
        Http.Account.Balance.execute(account)
        |> send_http_response(conn)

      :denied ->
        send_authorization_error(conn)
    end
  end
end
