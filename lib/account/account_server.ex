defmodule Account.Server do
  @moduledoc """
    Generic server process that keeps track of an `Account` module as it's state

    - Results of types like `:ok` and `:denied` will be registered on the `Account` operations list
    - Results of types like `:error` will NOT BE registered on the `Account` operations list

    TODO: Implement data persistance to keep track of the account's data even when the process stop
    TODO: Define a way to interact with the `recipient_id` and `sender_id` in a proper way:
          - Separate trustfull caller module ?
          - send message directly to other `Account.Server` processes within this module ?
  """
  use GenServer

  @impl GenServer
  def init(args) do
    {:ok, Account.new(args)}
  end

  @spec start :: :ignore | {:error, any} | {:ok, pid}
  @doc """
  Start the `Account.Server` server

  - The initial state of non persisted non args `Account.Server` processes is the result of `Account.new/0`

  TODO: Implement data persistance to keep track of the account's data even when the process stop

  ## Examples
      iex> {:ok, server_pid} = Account.Server.start()
      iex> is_pid(server_pid)
      true

      iex> {:ok, server_pid} = Account.Server.start(%{balance: 5000, limit: -1000})
      iex> Account.Server.balance(server_pid)
      5000
  """
  def start(args \\ nil) do
    GenServer.start(Account.Server, args)
  end

  @spec withdraw(pid, %{amount: number}) :: {:ok, number} | {:denied, String.t(), number}
  @doc """
  Withdraw from the account balance

  - Sucess: {:ok, new_balance}
  - Failure: {:denied, reason, current_balance}

  ## Examples
      iex> {:ok, server_pid} = Account.Server.start(%{balance: 3000})
      iex> Account.Server.withdraw(server_pid, %{amount: 2000})
      {:ok, 1000}

      iex> {:ok, server_pid} = Account.Server.start(%{balance: 500})
      iex> Account.Server.withdraw(server_pid, %{amount: 2000})
      {:denied, "No funds", 500}
  """
  def withdraw(account_server, %{amount: _amount} = data) do
    GenServer.call(account_server, {:withdraw, data})
  end

  @spec deposit(pid, %{amount: any}) :: {:ok, number}
  @doc """
  Deposit into the account balance

  - Sucess: {:ok, new_balance}

  ## Examples
      iex> {:ok, server_pid} = Account.Server.start(%{balance: 3000})
      iex> Account.Server.deposit(server_pid, %{amount: 2000})
      {:ok, 5000}
  """
  def deposit(account_server, %{amount: _amount} = data) do
    GenServer.call(account_server, {:deposit, data})
  end

  @spec transfer_in(pid, %{amount: number, sender_account_id: number}) :: {:ok, number}
  @doc """
  Deposit into the account balance

  - Sucess: {:ok, new_balance}

  ## Examples
      iex> {:ok, server_pid} = Account.Server.start(%{balance: 3000})
      iex> Account.Server.transfer_in(server_pid, %{amount: 2000, sender_account_id: 1})
      {:ok, 5000}
  """
  def transfer_in(account_server, %{amount: _amount, sender_account_id: _sender} = data) do
    GenServer.call(account_server, {:transfer_in, data})
  end

  @spec transfer_out(pid, %{amount: number, recipient_account_id: number}) ::
          {:ok, number | {:denied, String.t(), number}}
  @doc """
  Transfer resources to another account from the account balance

  - Sucess: {:ok, new_balance}
  - Failure: {:denied, reason, current_balance}

  TODO: Define a way to interact with the `recipient_id` and `sender_id` in a proper way:
      - Separate trustfull caller module?
      - send message directly to other `Account.Server` processes within this module ?

  ## Examples
      iex> {:ok, server_pid} = Account.Server.start(%{balance: 3000})
      iex> Account.Server.transfer_out(server_pid, %{amount: 2000, recipient_account_id: 1})
      {:ok, 1000}

      iex> {:ok, server_pid} = Account.Server.start(%{balance: 500})
      iex> Account.Server.transfer_out(server_pid, %{amount: 2000, recipient_account_id: 1})
      {:denied, "No funds", 500}
  """
  def transfer_out(account_server, %{amount: _amount, recipient_account_id: _recipient} = data) do
    GenServer.call(account_server, {:transfer_out, data})
  end

  @spec card_transaction(pid, %{amount: number, card_id: number}) ::
          {:ok, number | {:denied, String.t(), number}}
  @doc """
  Debit card operation that uses resources from the account balance

  - Sucess: {:ok, new_balance}
  - Failure: {:denied, reason, current_balance}

  ## Examples
      iex> {:ok, server_pid} = Account.Server.start(%{balance: 3000})
      iex> Account.Server.card_transaction(server_pid, %{amount: 2000, card_id: 1})
      {:ok, 1000}

      iex> {:ok, server_pid} = Account.Server.start(%{balance: 500})
      iex> Account.Server.card_transaction(server_pid, %{amount: 2000, card_id: 1})
      {:denied, "No funds", 500}
  """
  def card_transaction(account_server, %{amount: _amount, card_id: _card} = data) do
    GenServer.call(account_server, {:card_transaction, data})
  end

  @spec refund(pid, %{operation_to_refund_id: any}) ::
          {:ok, number} | {:error, String.t(), number}
  @doc """
  Refund operation that get a not denied card transaction operation and refunds it

  - Sucess: {:ok, new_balance}
  - Failure: {:error, reason, current_balance}

  ## Examples
      iex> {:ok, server_pid} = Account.Server.start(%{balance: 3000})
      iex> Account.Server.card_transaction(server_pid, %{amount: 2000, card_id: 1})
      iex> Account.Server.refund(server_pid, %{operation_to_refund_id: 1})
      {:ok, 3000}

      iex> {:ok, server_pid} = Account.Server.start(%{balance: 3000})
      iex> Account.Server.card_transaction(server_pid, %{amount: 5000, card_id: 1})
      iex> Account.Server.refund(server_pid, %{operation_to_refund_id: 1})
      {:error,"Unrefundable operation", 3000}

      iex> {:ok, server_pid} = Account.Server.start(%{balance: 3000})
      iex> Account.Server.withdraw(server_pid, %{amount: 2000})
      iex> Account.Server.refund(server_pid, %{operation_to_refund_id: 1})
      {:error,"Unrefundable operation", 1000}

      iex> {:ok, server_pid} = Account.Server.start(%{balance: 3000})
      iex> Account.Server.refund(server_pid, %{operation_to_refund_id: 1})
      {:error,"Operation do not exists", 3000}

  """
  def refund(account_server, %{operation_to_refund_id: _operation} = data) do
    GenServer.call(account_server, {:refund, data})
  end

  def balance(account_server) do
    GenServer.call(account_server, :balance)
  end

  def operations_date(account_server, date) do
    GenServer.call(account_server, {:operations, date})
  end

  def operations_between_dates(account_server, date_ini, date_fin) do
    GenServer.call(account_server, {:operations, date_ini, date_fin})
  end

  @impl GenServer
  def handle_call(:balance, _from, %Account{} = current_state) do
    {:reply, Account.balance(current_state), current_state}
  end

  @impl GenServer
  def handle_call({:operations, date}, _from, %Account{} = current_state) do
    {:reply, Account.operations(current_state, date), current_state}
  end

  @impl GenServer
  def handle_call({:operations, date_ini, date_fin}, _from, %Account{} = current_state) do
    {:reply, Account.operations(current_state, date_ini, date_fin), current_state}
  end

  @impl GenServer
  def handle_call({:withdraw, %{amount: _amount} = data}, _from, %Account{} = current_state) do
    case Account.withdraw(current_state, data) do
      {:ok, new_state} ->
        {:reply, {:ok, new_state.balance}, new_state}

      {:denied, reason, new_state} ->
        {:reply, {:denied, reason, new_state.balance}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:deposit, %{amount: _amount} = data}, _from, %Account{} = current_state) do
    {:ok, new_state} = Account.deposit(current_state, data)
    {:reply, {:ok, new_state.balance}, new_state}
  end

  @impl GenServer
  def handle_call(
        {:transfer_in, %{amount: _amount, sender_account_id: _sender} = data},
        _from,
        %Account{} = current_state
      ) do
    {:ok, new_state} = Account.transfer_in(current_state, data)
    {:reply, {:ok, new_state.balance}, new_state}
  end

  @impl GenServer
  def handle_call(
        {:transfer_out, %{amount: _amount, recipient_account_id: _recipient} = data},
        _from,
        %Account{} = current_state
      ) do
    case Account.transfer_out(current_state, data) do
      {:ok, new_state} ->
        {:reply, {:ok, new_state.balance}, new_state}

      {:denied, reason, new_state} ->
        {:reply, {:denied, reason, new_state.balance}, new_state}
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
        {:reply, {:ok, new_state.balance}, new_state}

      {:denied, reason, new_state} ->
        {:reply, {:denied, reason, new_state.balance}, new_state}
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
        {:reply, {:ok, new_state.balance}, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason, new_state.balance}, new_state}
    end
  end
end
