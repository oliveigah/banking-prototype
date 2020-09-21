defmodule Database do
  @moduledoc """
    `Supervisor` that manages `Database.Worker` processes, responsible for data persistence functionality and workers pooling

    - `Database.worker` are used to perform kind of connection pools, spliting the real computational work between all processes
    - This module works as a connection pool manager, just forwarding the request for a selected worker
    - This module guarantee that requests that manipulate the same key will always be handled by the same `Database.worker` process, resulting in no race conditions, because worker processes receives messages sequentially
    - Internally, all the real computation is on `Database.Worker` processes

  """
  @workers_count 3
  @base_folder Application.compile_env!(:banking, :database_base_folder)
  @spec start_link() :: :ignore | {:error, any} | {:ok, pid}
  @doc """
  Start the server
  """
  def start_link() do
    workers_spec_list = Enum.map(1..@workers_count, &worker_spec/1)

    [Database.ProcessRegistry.child_spec(nil) | workers_spec_list]
    |> Supervisor.start_link(strategy: :one_for_one, name: __MODULE__)
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  defp worker_spec(worker_id) do
    default_spec = Database.Worker.child_spec(worker_id)

    Supervisor.child_spec(
      default_spec,
      id: {Database.Worker, worker_id}
    )
  end

  defp choose_worker(key) do
    :erlang.phash2(key, @workers_count) + 1
  end

  defp concatenate_folder(folder) do
    "#{@base_folder}#{folder}"
  end

  @spec store_local_async(any(), any(), String.t()) :: :ok
  @doc """
  Persist data asynchronously under the given folder with the given key
  """
  def store_local_async(key, value, folder) do
    final_folder = concatenate_folder(folder)

    key
    |> choose_worker()
    |> Database.Worker.store_async(key, value, final_folder)
  end

  def store_async(key, value, folder) do
    nodes = Node.list([:this, :visible])

    Enum.each(
      nodes,
      &:rpc.cast(&1, __MODULE__, :store_local_async, [key, value, folder])
    )

    :ok
  end

  @spec store_local_sync(any(), any(), String.t()) :: :ok
  @doc """
  Persist data synchronously under the given folder with the given key
  """
  def store_local_sync(key, value, folder) do
    final_folder = concatenate_folder(folder)

    key
    |> choose_worker()
    |> Database.Worker.store_sync(key, value, final_folder)
  end

  def store_sync(key, value, folder) do
    {_results, fail_nodes} =
      :rpc.multicall(
        __MODULE__,
        :store_local_sync,
        [key, value, folder],
        :timer.seconds(5)
      )

    Enum.each(fail_nodes, &IO.puts("Store failed on node #{&1}"))

    :ok
  end

  @spec get(any(), String.t()) :: any() | nil
  @doc """
  Get the persisted data registered under the given folder with the given key
  """
  def get(key, folder) do
    final_folder = concatenate_folder(folder)

    key
    |> choose_worker()
    |> Database.Worker.get(key, final_folder)
  end
end
