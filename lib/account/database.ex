defmodule Account.Database do
  @moduledoc """
    Its a named generic server process used to persist account data on binary files, all accounts are persisted under the folder "./persist/account" in a file named with the account id

    - `Database.worker` are used to perform kind of connection pools, spliting the real computational work between all processes
    - This module works as a connection pool manager, just forwarding the request for a selected worker
    - This module guarantee that requests of a same account will always be handled by the same `Database.worker` process, resulting in no race conditions, because worker processes receives messages sequentially

    - TODO: Implement a specific get worker. Since `store/2` function is a cast it runs async, but the message overload could make the `get/1` function that is a call have to wait until all the casts are solved internally, blocking the caller
  """
  use GenServer

  @workers_count 3
  @db_folder "./persist/accounts"
  @spec start :: :ignore | {:error, any} | {:ok, pid}
  @doc """
  Start the server
  """
  def start do
    GenServer.start(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Persist an account data
  """
  def store(account_id, %Account{} = account) do
    account_id
    |> choose_worker()
    |> Database.Worker.store(account_id, account)
  end

  @doc """
  Get the persisted data of an Account
  """
  def get(account_id) do
    account_id
    |> choose_worker()
    |> Database.Worker.get(account_id)
  end

  def init(_) do
    workers =
      for index <- 1..@workers_count, into: %{} do
        {:ok, worker_pid} = Database.Worker.start(@db_folder)
        {index - 1, worker_pid}
      end

    {:ok, workers}
  end

  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  @spec choose_worker(any) :: any
  def choose_worker(key) do
    GenServer.call(__MODULE__, {:choose_worker, key})
  end

  def handle_call({:choose_worker, key}, _, workers) do
    hash_key = :erlang.phash2(key, @workers_count)
    {:reply, Map.get(workers, hash_key), workers}
  end

  def handle_call(:reset, _, workers) do
    {:reply, File.rm_rf(@db_folder), workers}
  end
end
