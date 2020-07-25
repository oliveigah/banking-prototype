defmodule Database.Worker do
  use GenServer

  @spec start(any) :: :ignore | {:error, any} | {:ok, pid}
  def start(folder_path) do
    GenServer.start(Database.Worker, folder_path)
  end

  @spec store(pid, any, any) :: :ok
  def store(worker_pid, key, data) do
    GenServer.cast(worker_pid, {:store, key, data})
  end

  @spec get(pid, any) :: any
  def get(worker_pid, key) do
    GenServer.call(worker_pid, {:get, key})
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
end
