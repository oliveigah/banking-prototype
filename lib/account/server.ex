defmodule Account.Server do
  @moduledoc """
    Generic server process that keeps track of an `Account` module as it's state

    - Results of types like `:ok` and `:denied` will be registered on the `Account` operations list
    - Results of types like `:error` will NOT BE registered on the `Account` operations list

  """
  use GenServer, restart: :temporary

  @database_folder "accounts"
  @idle_timeout :timer.seconds(240)

  @impl GenServer
  def init(%{id: account_id} = args) do
    send(self(), {:real_init, account_id, args})
    {:ok, nil}
  end

  @spec start_link(%{id: number}) :: :ignore | {:error, any} | {:ok, pid}
  @doc """
  Start the `Account.Server` server

  - Should not be called directly, instead use `Account.Cache.server_process/2`
  - The initial state of non persisted non args `Account.Server` processes is the result of `Account.new/0`

  ## Examples
      iex> server_pid = Account.Cache.server_process(1)
      iex> is_pid(server_pid)
      true

      iex> server_pid = Account.Cache.server_process(1, %{balance: 5000, limit: -1000})
      iex> Account.Server.balance(server_pid)
      5000
  """
  def start_link(%{id: account_id} = args) do
    # IO.puts("Starting Account.Server #{account_id} linked to #{inspect(self())}")
    GenServer.start_link(Account.Server, args, name: via_tuple(account_id))
  end

  defp via_tuple(account_id) do
    Account.ProcessRegistry.via_tuple({__MODULE__, account_id})
  end

  @spec withdraw(pid, %{amount: number}) :: {:ok, number, number} | {:denied, String.t(), number}
  @doc """
  Withdraw from the account balance

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balance: 3000})
      iex> Account.Server.withdraw(server_pid, %{amount: 2000})
      {:ok, 1000, 1}

      iex> server_pid = Account.Cache.server_process(1, %{balance: 500})
      iex> Account.Server.withdraw(server_pid, %{amount: 2000})
      {:denied, "No funds", 500, 1}
  """
  def withdraw(account_server, %{amount: _amount} = data) do
    GenServer.call(account_server, {:withdraw, data})
  end

  @spec deposit(pid, %{amount: any}) :: {:ok, number, number}
  @doc """
  Deposit into the account balance

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balance: 3000})
      iex> Account.Server.deposit(server_pid, %{amount: 2000})
      {:ok, 5000, 1}
  """
  def deposit(account_server, %{amount: _amount} = data) do
    GenServer.call(account_server, {:deposit, data})
  end

  @spec transfer_in(pid, %{amount: number, sender_account_id: number}) :: {:ok, number, number}
  @doc """
  Deposit into the account balance

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balance: 3000})
      iex> Account.Server.transfer_in(server_pid, %{amount: 2000, sender_account_id: 2})
      {:ok, 5000, 1}
  """
  def transfer_in(account_server, %{amount: _amount, sender_account_id: _sender} = data) do
    GenServer.call(account_server, {:transfer_in, data})
  end

  @spec transfer_out(pid, %{amount: number, recipient_account_id: number}) ::
          {:ok, number, number | {:denied, String.t(), number}}
  @doc """
  Transfer resources to another account from the account balance

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balance: 3000})
      iex> Account.Server.transfer_out(server_pid, %{amount: 2000, recipient_account_id: 2})
      {:ok, 1000, 1}

      iex> server_pid = Account.Cache.server_process(1, %{balance: 500})
      iex> Account.Server.transfer_out(server_pid, %{amount: 2000, recipient_account_id: 2})
      {:denied, "No funds", 500, 1}
  """
  def transfer_out(account_server, %{amount: _amount, recipient_account_id: _recipient} = data) do
    GenServer.call(account_server, {:transfer_out, data})
  end

  @spec card_transaction(pid, %{amount: number, card_id: number}) ::
          {:ok, number, number | {:denied, String.t(), number}}
  @doc """
  Debit card operation that uses resources from the account balance

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balance: 3000})
      iex> Account.Server.card_transaction(server_pid, %{amount: 2000, card_id: 1})
      {:ok, 1000, 1}

      iex> server_pid = Account.Cache.server_process(1, %{balance: 500})
      iex> Account.Server.card_transaction(server_pid, %{amount: 2000, card_id: 1})
      {:denied, "No funds", 500, 1}
  """
  def card_transaction(account_server, %{amount: _amount, card_id: _card} = data) do
    GenServer.call(account_server, {:card_transaction, data})
  end

  @spec refund(pid, %{operation_to_refund_id: any}) ::
          {:ok, number, number()} | {:error, String.t(), number}
  @doc """
  Refund operation that get a not denied card transaction operation and refunds it

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balance: 3000})
      iex> Account.Server.card_transaction(server_pid, %{amount: 2000, card_id: 1})
      iex> Account.Server.refund(server_pid, %{operation_to_refund_id: 1})
      {:ok, 3000, 2}

      iex> server_pid = Account.Cache.server_process(1, %{balance: 3000})
      iex> Account.Server.card_transaction(server_pid, %{amount: 5000, card_id: 1})
      iex> Account.Server.refund(server_pid, %{operation_to_refund_id: 1})
      {:error,"Unrefundable operation", 3000}

      iex> server_pid = Account.Cache.server_process(1, %{balance: 3000})
      iex> Account.Server.withdraw(server_pid, %{amount: 2000})
      iex> Account.Server.refund(server_pid, %{operation_to_refund_id: 1})
      {:error,"Unrefundable operation", 1000}

      iex> server_pid = Account.Cache.server_process(1, %{balance: 3000})
      iex> Account.Server.refund(server_pid, %{operation_to_refund_id: 1})
      {:error,"Operation do not exists", 3000}

  """
  def refund(account_server, %{operation_to_refund_id: _operation} = data) do
    GenServer.call(account_server, {:refund, data})
  end

  @spec balance(pid) :: any
  @doc """
  Get the current balance of the Account

  ## Examples
      iex> server_pid = Account.Cache.server_process(1, %{balance: 3000})
      iex> Account.Server.balance(server_pid)
      3000
  """
  def balance(account_server) do
    GenServer.call(account_server, :balance)
  end

  @spec operations(pid, Date.t()) :: [Operation.t()]
  @doc """
  Get the list of operations that occur in a specific date

  ## Examples
      iex> server_pid = Account.Cache.server_process(1)
      iex> Account.Server.operations(server_pid, ~D[2020-07-24])
      []

      iex> server_pid = Account.Cache.server_process(1, %{balance: 2000})
      iex> Account.Server.withdraw(server_pid, %{amount: 700, date_time: ~U[2020-07-24 10:00:00Z]})
      iex> Account.Server.deposit(server_pid, %{amount: 1000, date_time: ~U[2020-07-24 10:00:00Z]})
      iex> oop = Account.Server.operations(server_pid, ~D[2020-07-24])
      iex> match?([
      ...>  %Operation{type: :withdraw, data: %{amount: 700}, status: :done},
      ...>  %Operation{type: :deposit, data: %{amount: 1000}, status: :done}
      ...> ], oop)
      true

      iex> server_pid = Account.Cache.server_process(1, %{balance: 2000})
      iex> Account.Server.withdraw(server_pid, %{amount: 300, date_time: ~U[2020-07-23 10:00:00Z]})
      iex> Account.Server.withdraw(server_pid, %{amount: 700, date_time: ~U[2020-07-24 10:00:00Z]})
      iex> Account.Server.withdraw(server_pid, %{amount: 1900, date_time: ~U[2020-07-24 10:00:00Z]})
      iex> oop = Account.Server.operations(server_pid, ~D[2020-07-24])
      iex> match?([
      ...>  %Operation{type: :withdraw, data: %{amount: 700}, status: :done},
      ...>  %Operation{type: :withdraw, data: %{amount: 1900}, status: :denied}
      ...> ], oop)
      true
  """
  def operations(account_server, date) do
    GenServer.call(account_server, {:operations, date})
  end

  @spec operations(pid, Date.t(), Date.t()) :: any
  @doc """
  Get the list of operations that occur betweem 2 dates

  ## Examples
      iex> server_pid = Account.Cache.server_process(1)
      iex> Account.Server.operations(server_pid, ~D[2020-07-24], ~D[2020-07-25])
      []

      iex> server_pid = Account.Cache.server_process(1, %{balance: 2000})
      iex> Account.Server.withdraw(server_pid, %{amount: 700, date_time: ~U[2020-07-24 10:00:00Z]})
      iex> Account.Server.deposit(server_pid, %{amount: 1000, date_time: ~U[2020-07-25 10:00:00Z]})
      iex> oop = Account.Server.operations(server_pid, ~D[2020-07-24], ~D[2020-07-25])
      iex> match?([
      ...>  %Operation{type: :withdraw, data: %{amount: 700}, status: :done},
      ...>  %Operation{type: :deposit, data: %{amount: 1000}, status: :done}
      ...> ], oop)
      true

      iex> server_pid = Account.Cache.server_process(1, %{balance: 2000})
      iex> Account.Server.withdraw(server_pid, %{amount: 300, date_time: ~U[2020-07-23 10:00:00Z]})
      iex> Account.Server.withdraw(server_pid, %{amount: 700, date_time: ~U[2020-07-24 10:00:00Z]})
      iex> Account.Server.withdraw(server_pid, %{amount: 1900, date_time: ~U[2020-07-25 10:00:00Z]})
      iex> oop = Account.Server.operations(server_pid, ~D[2020-07-23], ~D[2020-07-24])
      iex> match?([
      ...>  %Operation{type: :withdraw, data: %{amount: 300}, status: :done},
      ...>  %Operation{type: :withdraw, data: %{amount: 700}, status: :done}
      ...> ], oop)
      true
  """
  def operations(account_server, date_ini, date_fin) do
    GenServer.call(account_server, {:operations, date_ini, date_fin})
  end

  @spec account_id(pid) :: number()
  @doc """
  Get the account id of a specific account

  ## Examples
      iex> server_pid = Account.Cache.server_process(123)
      iex> Account.Server.account_id(server_pid)
      123
  """
  def account_id(account_server) do
    GenServer.call(account_server, :account_id)
  end

  defp persist_data(%Account{} = account_data) do
    Database.store_sync(Map.get(account_data, :id), account_data, @database_folder)
  end

  defp operation_id(%Account{} = account_data) do
    account_data.operations_auto_id - 1
  end

  @impl GenServer
  def handle_call(:account_id, _from, %Account{} = current_state) do
    {:reply, Map.get(current_state, :id), current_state, @idle_timeout}
  end

  @impl GenServer
  def handle_call(:balance, _from, %Account{} = current_state) do
    {:reply, Account.balance(current_state), current_state, @idle_timeout}
  end

  @impl GenServer
  def handle_call({:operations, date}, _from, %Account{} = current_state) do
    {:reply, Account.operations(current_state, date), current_state, @idle_timeout}
  end

  @impl GenServer
  def handle_call({:operations, date_ini, date_fin}, _from, %Account{} = current_state) do
    {:reply, Account.operations(current_state, date_ini, date_fin), current_state, @idle_timeout}
  end

  @impl GenServer
  def handle_call({:withdraw, %{amount: _amount} = data}, _from, %Account{} = current_state) do
    case Account.withdraw(current_state, data) do
      {:ok, new_state} ->
        persist_data(new_state)
        {:reply, {:ok, new_state.balance, operation_id(new_state)}, new_state, @idle_timeout}

      {:denied, reason, new_state} ->
        persist_data(new_state)

        {
          :reply,
          {:denied, reason, new_state.balance, operation_id(new_state)},
          new_state,
          @idle_timeout
        }
    end
  end

  @impl GenServer
  def handle_call({:deposit, %{amount: _amount} = data}, _from, %Account{} = current_state) do
    {:ok, new_state} = Account.deposit(current_state, data)
    persist_data(new_state)
    {:reply, {:ok, new_state.balance, operation_id(new_state)}, new_state, @idle_timeout}
  end

  @impl GenServer
  def handle_call(
        {:transfer_in, %{amount: _amount, sender_account_id: _sender} = data},
        _from,
        %Account{} = current_state
      ) do
    {:ok, new_state} = Account.transfer_in(current_state, data)
    persist_data(new_state)
    {:reply, {:ok, new_state.balance, operation_id(new_state)}, new_state, @idle_timeout}
  end

  @impl GenServer
  def handle_call(
        {:transfer_out, %{amount: _amount, recipient_account_id: _recipient} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.transfer_out(current_state, data) do
      {:ok, new_state} ->
        persist_data(new_state)
        {:reply, {:ok, new_state.balance, operation_id(new_state)}, new_state, @idle_timeout}

      {:denied, reason, new_state} ->
        persist_data(new_state)

        {
          :reply,
          {:denied, reason, new_state.balance, operation_id(new_state)},
          new_state,
          @idle_timeout
        }
    end
  end

  @impl GenServer
  def handle_call(
        {:card_transaction, %{amount: _amount, card_id: _card} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.card_transaction(current_state, data) do
      {:ok, new_state} ->
        persist_data(new_state)
        {:reply, {:ok, new_state.balance, operation_id(new_state)}, new_state, @idle_timeout}

      {:denied, reason, new_state} ->
        persist_data(new_state)

        {
          :reply,
          {:denied, reason, new_state.balance, operation_id(new_state)},
          new_state,
          @idle_timeout
        }
    end
  end

  @impl GenServer
  def handle_call(
        {:refund, %{operation_to_refund_id: _operation} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.refund(current_state, data) do
      {:ok, new_state} ->
        persist_data(new_state)
        {:reply, {:ok, new_state.balance, operation_id(new_state)}, new_state, @idle_timeout}

      {:error, reason, new_state} ->
        {:reply, {:error, reason, new_state.balance}, new_state, @idle_timeout}
    end
  end

  @impl GenServer
  def handle_info({:real_init, account_id, args}, _state) do
    case Database.get(account_id, @database_folder) do
      nil ->
        account = Account.new(args)
        persist_data(account)
        {:noreply, account, @idle_timeout}

      data ->
        {:noreply, data, @idle_timeout}
    end
  end

  @impl GenServer
  def handle_info(:timeout, %Account{} = state) do
    {:stop, :normal, state}
  end
end
