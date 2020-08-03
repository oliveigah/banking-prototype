defmodule Account.Cache do
  @moduledoc """
  `DynamicSupervisor` that manages all `Account.Server` processes currently running on the system

  TODO: Implement a time based clean up function to prevent the indefinetely grow of the process
  """

  @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  @doc """
  Start the `Account.Cache` server
  """
  def start_link() do
    IO.puts("Starting Account.Cache linked to #{inspect(self())}")
    DynamicSupervisor.start_link(name: __MODULE__, strategy: :one_for_one)
  end

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

  @spec server_process(number) :: pid
  @doc """
  Get the `pid` of a `Account.Server` process that is running the data of an account with the given id. If the server isn't running it is initialized with the data persisted on database or with the given args

  - The `args` will be used to fill the account data ONLY IF the given id does not have any data persisted on the database
  - If the given id already have persited data on database, args will be ignored

  ## Examples
      iex> bob_account_pid = Account.Cache.server_process(1)
      iex> is_pid(bob_account_pid)
      true
  """
  def server_process(account_id, args \\ %{}) do
    case(start_child(account_id, args)) do
      {:ok, account_server_pid} ->
        account_server_pid

      {:error, {:already_started, account_server_pid}} ->
        account_server_pid
    end
  end
end
