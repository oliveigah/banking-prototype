defmodule Account.Cache do
  @moduledoc """
  A generic server process used to keep track of all the `Account.Server` processes currently running on the system

  TODO: Implement a time based clean up function to prevent the indefinetely grow of the process
  """
  use GenServer

  def init(_) do
    {:ok, %{}}
  end

  @spec start :: :ignore | {:error, any} | {:ok, pid}
  @doc """
  Start the `Account.Cache` server

  ## Examples
      iex> {:ok, cache_server_pid} = Account.Cache.start()
      iex> is_pid(cache_server_pid)
      true
  """
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

  @spec account_server_process(pid, number) :: pid
  @doc """
  Get the `pid` of a specific `Account.Server` if the server isn't running it is initialized

  TODO: Implement data persistance to keep track of the data even when server processes are terminated

  ## Examples
      iex> {:ok, cache_server_pid} = Account.Cache.start()
      iex> bob_account_pid = Account.Cache.account_server_process(cache_server_pid, 1)
      iex> is_pid(bob_account_pid)
      true
  """
  def account_server_process(cache_server_pid, account_id) do
    GenServer.call(cache_server_pid, {:account_process, account_id})
  end
end
