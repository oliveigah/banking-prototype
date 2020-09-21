defmodule Account.Cache do
  @moduledoc """
  `DynamicSupervisor` that manages all `Account.Server` processes currently running on the system

  - This module is used as an `Account.Server` dicover, always that some part of the system needs to issue requests to an `Account.Server`,
  it first asks if some process containing the data of a specific account is already running

  """

  @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  @doc false
  def start_link() do
    DynamicSupervisor.start_link(name: __MODULE__, strategy: :one_for_one)
  end

  @doc false
  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  defp start_child(account_id, %{} = args) do
    server_parameters = Map.merge(%{id: account_id}, args)
    DynamicSupervisor.start_child(__MODULE__, Account.Server.child_spec(server_parameters))
  end

  defp is_already_running?(account_pid) do
    case Registry.lookup(Account.ProcessRegistry, {Account.Server, account_pid}) do
      [] ->
        false

      [{pid, _value}] ->
        {true, pid}
    end
  end

  @spec server_process(number) :: pid
  @doc """
  Get the `pid` of a `Account.Server` process that is running with the account's data that has the given id.

  If the server isn't running it is initialized with the data persisted on database.
  If no data is already persisted, the server is initialized with the given args

  ## Examples
      iex> bob_account_pid = Account.Cache.server_process(1)
      iex> is_pid(bob_account_pid)
      true
  """
  def run_server_process(account_id, args \\ %{}) do
    case(is_already_running?(account_id)) do
      false ->
        {:ok, pid} = start_child(account_id, args)
        pid

      {true, pid} ->
        pid
    end
  end

  def server_process(account_id, args \\ %{}) do
    :rpc.call(
      find_node(account_id),
      __MODULE__,
      :run_server_process,
      [account_id, args]
    )
  end

  defp find_node(account_id) do
    nodes = Enum.sort(Node.list([:this, :visible]))

    node_index =
      :erlang.phash2(
        account_id,
        length(nodes)
      )

    Enum.at(nodes, node_index)
  end
end
