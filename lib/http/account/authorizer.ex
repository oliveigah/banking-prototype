defmodule Http.Account.Authorizer do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    {:ok, account_id} =
      get_req_header(conn, "authorization")
      |> List.first()
      |> authorize!()

    Plug.Conn.assign(conn, :account_id, account_id)
  end

  def authorize!(token) do
    try do
      {:ok, String.to_integer(token)}
    rescue
      _ -> raise Http.Account.Authorizer.AuthorizationError
    end
  end

  defmodule AuthorizationError do
    defexception message: "AuthorizationError", details: "Invalid Token", status_code: 401
  end
end
