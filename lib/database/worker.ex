defmodule Database.Worker do
  @moduledoc false
  use GenServer

  defp via_tuple(worker_id) do
    Account.ProcessRegistry.via_tuple({__MODULE__, worker_id})
  end

  @spec start_link({number(), String.t()}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link({worker_id, folder_path}) do
    IO.puts("Starting Database.Worker #{worker_id} linked to #{inspect(self())}")
    GenServer.start_link(__MODULE__, folder_path, name: via_tuple(worker_id))
  end

  @spec store_async(number(), any, any) :: :ok
  def store_async(worker_id, key, data) do
    GenServer.cast(via_tuple(worker_id), {:store, key, data})
  end

  @spec store_sync(number(), any, any) :: any
  def store_sync(worker_id, key, data) do
    GenServer.call(via_tuple(worker_id), {:store, key, data})
  end

  @spec get(number(), any) :: any
  def get(worker_id, key) do
    GenServer.call(via_tuple(worker_id), {:get, key})
  end

  def init(folder_path) do
    File.mkdir_p!(folder_path)
    {:ok, folder_path}
  end

  defp file_name(folder_path, key) do
    Path.join(folder_path, to_string(key))
  end

  def handle_cast({:store, key, value}, folder_path) do
    file_name(folder_path, key)
    |> File.write!(:erlang.term_to_binary(value))

    {:noreply, folder_path}
  end

  def handle_call({:get, key}, _from, folder_path) do
    response =
      case File.read(file_name(folder_path, key)) do
        {:ok, data} -> :erlang.binary_to_term(data)
        _ -> nil
      end

    {:reply, response, folder_path}
  end

  def handle_call({:store, key, value}, _from, folder_path) do
    result =
      file_name(folder_path, key)
      |> File.write!(:erlang.term_to_binary(value))

    {:reply, result, folder_path}
  end
end
