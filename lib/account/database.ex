defmodule Account.Database do
  @moduledoc """
    Supervisor that manages `Database.Worker` processes, responsible for data persistence functionality

    - `Database.worker` are used to perform kind of connection pools, spliting the real computational work between all processes
    - This module works as a connection pool manager, just forwarding the request for a selected worker
    - This module guarantee that requests of a same account will always be handled by the same `Database.worker` process, resulting in no race conditions, because worker processes receives messages sequentially
  """
  @workers_count 3
  @db_folder "./persist/accounts"
  @spec start_link() :: :ignore | {:error, any} | {:ok, pid}
  @doc """
  Start the server
  """
  def start_link() do
    IO.puts("Starting Account.Database linked to #{inspect(self())}")

    Enum.map(1..@workers_count, &worker_spec/1)
    |> Supervisor.start_link(strategy: :one_for_one)
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  defp worker_spec(worker_id) do
    default_spec = Database.Worker.child_spec({worker_id, @db_folder})

    Supervisor.child_spec(
      default_spec,
      id: {Database.Worker, worker_id}
    )
  end

  defp choose_worker(key) do
    :erlang.phash2(key, @workers_count) + 1
  end

  @spec store_async(number(), Account.t()) :: :ok
  @doc """
  Persist an account data asynchronously
  """
  def store_async(account_id, %Account{} = account) do
    account_id
    |> choose_worker()
    |> Database.Worker.store_async(account_id, account)
  end

  @spec store_sync(number(), Account.t()) :: :ok
  @doc """
  Persist an account data synchronously
  """
  def store_sync(account_id, %Account{} = account) do
    account_id
    |> choose_worker()
    |> Database.Worker.store_sync(account_id, account)
  end

  @spec get(number()) :: Account.t() | nil
  @doc """
  Get the persisted data of an Account
  """
  def get(account_id) do
    account_id
    |> choose_worker()
    |> Database.Worker.get(account_id)
  end

  def folder_path do
    @db_folder
  end
end
