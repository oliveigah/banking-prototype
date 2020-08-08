defmodule Http.Account do
  use Plug.Router

  def child_spec(_arg) do
    Plug.Adapters.Cowboy.child_spec(
      scheme: :http,
      options: [port: 3000],
      plug: __MODULE__
    )
  end

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)
  plug(:dispatch)

  post("account/deposit") do
    {status, result_body} =
      conn.body_params
      |> Http.Account.Deposit.execute()

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Poison.encode!(result_body))
  end

  post("account/withdraw") do
    {status, result_body} =
      conn.body_params
      |> Http.Account.Deposit.execute()

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Poison.encode!(result_body))
  end
end
