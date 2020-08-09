defmodule Database do
  @moduledoc """
    Supervisor that manages `Database.Worker` processes, responsible for data persistence functionality

    - `Database.worker` are used to perform kind of connection pools, spliting the real computational work between all processes
    - This module works as a connection pool manager, just forwarding the request for a selected worker
    - This module guarantee that requests that manipulate the same key will always be handled by the same `Database.worker` process, resulting in no race conditions, because worker processes receives messages sequentially

    TODO: Segregate get and put workers
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

  @spec store_async(any(), any(), String.t()) :: :ok
  @doc """
  Persist data asynchronously
  """
  def store_async(key, value, folder) do
    final_folder = concatenate_folder(folder)

    key
    |> choose_worker()
    |> Database.Worker.store_async(key, value, final_folder)
  end

  @spec store_sync(any(), any(), String.t()) :: :ok
  @doc """
  Persist data synchronously
  """
  def store_sync(key, value, folder) do
    final_folder = concatenate_folder(folder)

    key
    |> choose_worker()
    |> Database.Worker.store_sync(key, value, final_folder)
  end

  @spec get(any(), String.t()) :: any() | nil
  @doc """
  Get the persisted data
  """
  def get(key, folder) do
    final_folder = concatenate_folder(folder)

    key
    |> choose_worker()
    |> Database.Worker.get(key, final_folder)
  end
end
