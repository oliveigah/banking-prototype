defmodule Account.Cache do
  use GenServer

  def init(_) do
    {:ok, %{}}
  end

  def start() do
    GenServer.start(Account.Cache, nil)
  end

  def handle_call({:account_process, account_id}, _, current_state) do
    case(Map.fetch(current_state, account_id)) do
      {:ok, account_server} ->
        {:reply, account_server, current_state}

      :error ->
        {:ok, new_account_server} = Account.Server.start()

        {
          :reply,
          new_account_server,
          Map.put(current_state, account_id, new_account_server)
        }
    end
  end

  def account_server_process(cache_server_pid, account_id) do
    GenServer.call(cache_server_pid, {:account_process, account_id})
  end
end
